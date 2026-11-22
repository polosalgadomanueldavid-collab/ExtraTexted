extends Node3D
## Reloj compartido; cada evento conserva su propio acabado, sin anillo universal.
const DURACION := 2.6
const PISO := .372
const LIMITES := Rect2(-4.40, -.05, 6.76, 12.38)
# Tiempo de recorrido / tiempo de transformación local. Ambos terminan antes del cierre.
const RITMOS := {
	&"agua": Vector2(1.0, 1.15), &"vapor": Vector2(1.0, 1.35),
	&"fuego": Vector2(1.3, .95), &"tierra": Vector2(1.0, 1.45),
	&"aire": Vector2(1.25, .95), &"luz": Vector2(1.5, .65),
}
var tiempo := 0.0
var alcance := 1.0
var origen := Vector3.ZERO
var tipo: StringName
var ritmo := Vector2(1.4, .85)
var _paso: Callable
var _fin: Callable
var _particulas: MultiMeshInstance3D
var _puntos := PackedVector3Array()
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
	ritmo = RITMOS[tipo]
	for esquina: Vector2 in [LIMITES.position, LIMITES.end, Vector2(LIMITES.position.x, LIMITES.end.y), Vector2(LIMITES.end.x, LIMITES.position.y)]:
		alcance = maxf(alcance, Vector2(origen.x, origen.z).distance_to(esquina))
	_color = {&"agua": Color("79dbe7"), &"vapor": Color("d7e3e0"), &"fuego": Color("e6a263"), &"tierra": Color("b6aa94"), &"aire": Color("e0f0f5"), &"luz": Color("ffde98")}[tipo]
	# Solo las superficies continuas necesitan residuos repartidos por el suelo.
	# Fuego y tierra reciben anclajes reales; agua y apagón no añaden partículas.
	if tipo in [&"vapor", &"aire"]:
		var puntos := PackedVector3Array()
		var cantidad := 32 if tipo == &"vapor" else 24
		for i in cantidad:
			puntos.append(Vector3(lerpf(LIMITES.position.x, LIMITES.end.x, fposmod(i * .618034, 1.0)), PISO + .025, lerpf(LIMITES.position.y, LIMITES.end.y, (i + .5) / cantidad)))
		preparar_residuos(puntos)

func preparar_residuos(puntos: PackedVector3Array) -> void:
	_puntos = puntos
	if not is_instance_valid(_particulas):
		_particulas = MultiMeshInstance3D.new()
		var malla := QuadMesh.new()
		malla.size = Vector2.ONE
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://Objetos/ZonaDescanso/resolucion_avatar.gdshader")
		malla.material = mat
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = malla
		_particulas.multimesh = multi
		_particulas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_particulas)
	_particulas.multimesh.instance_count = _puntos.size()
	_actualizar_residuos()

func peso_en(punto: Vector3) -> float:
	var llegada := Vector2(punto.x - origen.x, punto.z - origen.z).length() / alcance * ritmo.x
	var t := clampf((tiempo - llegada) / ritmo.y, 0.0, 1.0)
	# Aceleración y frenado suaves también en los extremos.
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

func aplicar_material(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("avatar_activo", true)
	mat.set_shader_parameter("avatar_origen", Vector2(origen.x, origen.z))
	mat.set_shader_parameter("avatar_alcance", alcance)
	mat.set_shader_parameter("avatar_tiempo", tiempo)
	mat.set_shader_parameter("avatar_ritmo", ritmo)

func _physics_process(delta: float) -> void:
	tiempo = minf(tiempo + delta, DURACION)
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
	if not is_instance_valid(_particulas):
		return
	var camara := get_viewport().get_camera_3d()
	var orientacion := camara.global_basis.orthonormalized() if is_instance_valid(camara) else Basis.IDENTITY
	for i in _puntos.size():
		var punto := _puntos[i]
		var peso := peso_en(punto)
		# Residuos breves después del contacto; se desvanecen antes de la limpieza.
		var vida := smoothstep(.12, .38, peso) * (1.0 - smoothstep(.55, .96, peso))
		var direccion := (punto - Vector3(origen.x, punto.y, origen.z)).normalized()
		var ancho := .03
		var alto := .03
		var opacidad := .5
		match tipo:
			&"vapor":
				ancho = .16 + peso * .34
				alto = ancho * 1.6
				punto.y += peso * .45
				punto += direccion * peso * .10
				opacidad = .13
			&"aire":
				ancho = .035 + (i % 3) * .012
				alto = ancho * .45
				punto += direccion * peso * .65
				punto.y += sin(peso * PI) * .18
				opacidad = .36
			&"tierra":
				ancho = .18 + peso * .26
				alto = ancho * .45
				punto.y += sin(peso * PI) * .09
				opacidad = .16
			&"fuego":
				punto.y += peso * .32
				punto.x += sin(i * 2.4 + peso * 3.0) * .04
		var escala := Vector3(ancho, alto, 1.0)
		_particulas.multimesh.set_instance_transform(i, Transform3D(orientacion.scaled_local(escala), punto))
		_particulas.multimesh.set_instance_color(i, Color(_color, vida * opacidad))
