extends Node3D
## Frente de restauración desde el actor. Cada evento transforma sus objetos
## reales; este nodo aporta un reloj cancelable, el frente y sus residuos.
const DURACION := 2.6
const PISO := .372
const LIMITES := Rect2(-4.40, -.05, 6.76, 12.38)
var tiempo := 0.0
var alcance := 1.0
var origen := Vector3.ZERO
var tipo: StringName
var _paso: Callable
var _fin: Callable
var _material: ShaderMaterial
var _particulas: MultiMeshInstance3D
var _color: Color

static func crear(padre: Node, punto: Vector3, elemento: StringName, paso: Callable, fin: Callable) -> Node3D:
	var efecto = load("res://Objetos/ZonaDescanso/resolucion_avatar.gd").new()
	efecto.origen = punto
	efecto.tipo = elemento
	efecto._paso = paso
	efecto._fin = fin
	padre.add_child(efecto)
	return efecto

func _ready() -> void:
	process_physics_priority = -150
	top_level = true
	global_transform = Transform3D.IDENTITY
	for esquina: Vector2 in [LIMITES.position, LIMITES.end, Vector2(LIMITES.position.x, LIMITES.end.y), Vector2(LIMITES.end.x, LIMITES.position.y)]:
		alcance = maxf(alcance, Vector2(origen.x, origen.z).distance_to(esquina))
	_color = {&"agua": Color("79dbe7"), &"vapor": Color("d7e3e0"), &"fuego": Color("ffb45e"), &"tierra": Color("d9b482"), &"aire": Color("e0f6ff"), &"luz": Color("ffde98")}[tipo]
	var frente := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = LIMITES.size
	frente.mesh = plano
	frente.position = Vector3(LIMITES.get_center().x, PISO + .035, LIMITES.get_center().y)
	frente.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = preload("res://Objetos/ZonaDescanso/resolucion_avatar.gdshader")
	_material.set_shader_parameter("tinte", _color)
	frente.material_override = _material
	add_child(frente)
	aplicar_material(_material)
	_particulas = MultiMeshInstance3D.new()
	var malla := SphereMesh.new()
	malla.radius = 1.0
	malla.height = 2.0
	malla.radial_segments = 6
	malla.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	malla.material = mat
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = malla
	multi.instance_count = 100
	_particulas.multimesh = multi
	_particulas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_particulas)
	_actualizar_residuos()

func peso_en(punto: Vector3) -> float:
	var llegada := Vector2(punto.x - origen.x, punto.z - origen.z).length() / alcance * 1.4
	return smoothstep(llegada, llegada + .85, tiempo)

func aplicar_material(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("avatar_activo", true)
	mat.set_shader_parameter("avatar_origen", Vector2(origen.x, origen.z))
	mat.set_shader_parameter("avatar_alcance", alcance)
	mat.set_shader_parameter("avatar_tiempo", tiempo)

func _physics_process(delta: float) -> void:
	tiempo = minf(tiempo + delta, DURACION)
	aplicar_material(_material)
	_actualizar_residuos()
	_paso.call(self)
	if tiempo >= DURACION and not is_queued_for_deletion():
		set_physics_process(false)
		_fin.call()
		queue_free()

func cancelar() -> void:
	set_physics_process(false)
	_paso = Callable()
	_fin = Callable()
	hide()
	queue_free()

func _actualizar_residuos() -> void:
	for i in 100:
		# Una distribución determinista por el suelo: cada residuo responde
		# al frente local, sin volver a emitir ni depender de TIME del shader.
		var punto := Vector3(lerpf(LIMITES.position.x, LIMITES.end.x, fposmod(i * .618034, 1.0)), PISO, lerpf(LIMITES.position.y, LIMITES.end.y, (i + .5) / 100.0))
		var peso := peso_en(punto)
		var vida := sin(peso * PI)
		var direccion := (punto - Vector3(origen.x, PISO, origen.z)).normalized()
		var tamano := .012 + (i % 4) * .006
		if tipo == &"vapor":
			tamano = .06 + peso * .15
			punto.y += peso * .7
		elif tipo == &"aire":
			punto += direccion * peso * .55
			punto.y += .08 + sin(peso * PI) * .4
		elif tipo == &"agua":
			punto += direccion * peso * .20
			punto.y += vida * .16
		else:
			punto.y += vida * .25
		var escala := Vector3.ONE * maxf(.0001, tamano * vida)
		_particulas.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(escala), punto))
		_particulas.multimesh.set_instance_color(i, Color(_color, vida * (.24 if tipo == &"vapor" else .65)))
