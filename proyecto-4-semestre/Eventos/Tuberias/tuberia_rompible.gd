extends Node3D
## Modelo, rotura y emisión comparten coordenadas locales de la misma instalación.
## Hereda la pausa y la congelación temporal; no modifica las reglas de cada evento.

const AGUA := preload("res://Eventos/Tuberias/Agua.scn")
const NITROGENO := preload("res://Eventos/Tuberias/Nitrogeno.scn")
enum Estado { SANA, ROMPIENDO, ROTA, SELLANDO }
const ANGULO_PUERTA := -105.0

var nitrogeno := false
var estado := Estado.SANA
var salida: Marker3D
var chorro: CPUParticles3D
var nube: CPUParticles3D
var estallido: CPUParticles3D
var modelo: Node3D
var tramo: Node3D
var apertura := 0.0
var nivel_agua := -100.0
var abierto := false
var puerta: Node3D
var cuerpo: StaticBody3D
var _animacion_puerta: Tween
var _emisiones: Node3D
var _pose: Transform3D
var _boca: MeshInstance3D
var _flujo: MeshInstance3D
var _material_flujo: ShaderMaterial
var _reloj := 0.0
var _apertura_inicial := 0.0


func _ready() -> void:
	modelo = (NITROGENO if nitrogeno else AGUA).instantiate()
	add_child(modelo)
	tramo = modelo.get_node("Tramo")
	_pose = tramo.transform
	salida = modelo.get_node("Salida")
	puerta = modelo.get_node_or_null("PuertaPivot")
	# La caja permanece sólida incluso durante la vibración y la rotura.
	cuerpo = _crear_colision(self, _limites_modelo(modelo, puerta), false)
	if is_instance_valid(puerta):
		_crear_colision(puerta, _limites_modelo(puerta), true)
	_crear_boca()
	_crear_emisiones()
	if not nitrogeno:
		_crear_flujo()
	restablecer()


func _limites_modelo(raiz: Node3D, excluir: Node3D = null) -> AABB:
	var limites := AABB()
	var primero := true
	for malla: MeshInstance3D in raiz.find_children("*", "MeshInstance3D", true, false):
		if is_instance_valid(excluir) and excluir.is_ancestor_of(malla):
			continue
		var relativo := raiz.global_transform.affine_inverse() * malla.global_transform
		var caja: AABB = relativo * malla.get_aabb()
		limites = caja if primero else limites.merge(caja)
		primero = false
	return limites


func _crear_colision(padre: Node3D, limites: AABB, movil: bool) -> StaticBody3D:
	var solido: StaticBody3D = AnimatableBody3D.new() if movil else StaticBody3D.new()
	solido.name = "ColisionPuerta" if movil else "ColisionGabinete"
	solido.collision_layer = 1
	solido.collision_mask = 0
	if movil:
		# La bisagra es la que mueve la tapa; no debe resincronizar su pose anterior.
		(solido as AnimatableBody3D).sync_to_physics = false
	solido.position = limites.get_center()
	padre.add_child(solido)
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = limites.size.max(Vector3.ONE * 0.02)
	forma.shape = caja
	solido.add_child(forma)
	if not movil:
		forma.add_to_group("obstaculos_navegacion")
	return solido


func romper() -> void:
	restablecer()
	estado = Estado.ROMPIENDO
	for emisor in [chorro, nube, estallido]:
		emisor.show()
	set_process(true)


func sellar() -> void:
	establecer_abierto(false)
	if estado == Estado.SANA or estado == Estado.SELLANDO:
		return
	estado = Estado.SELLANDO
	_reloj = 0.0
	_apertura_inicial = apertura
	chorro.emitting = false
	nube.emitting = false
	estallido.emitting = false
	set_process(true)


func restablecer() -> void:
	establecer_abierto(false, true)
	estado = Estado.SANA
	apertura = 0.0
	_reloj = 0.0
	modelo.position = Vector3.ZERO
	tramo.transform = _pose
	_boca.hide()
	if is_instance_valid(_flujo):
		_flujo.hide()
	for emisor in [chorro, nube, estallido]:
		emisor.emitting = false
		emisor.hide()
	set_process(false)


func establecer_abierto(nuevo_estado: bool, inmediato := false) -> void:
	abierto = nuevo_estado if is_instance_valid(puerta) else false
	if not is_instance_valid(puerta):
		return
	if _animacion_puerta != null:
		_animacion_puerta.kill()
	var angulo := deg_to_rad(ANGULO_PUERTA if abierto else 0.0)
	if inmediato:
		_mover_puerta(angulo)
		return
	_animacion_puerta = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_animacion_puerta.tween_method(_mover_puerta, puerta.rotation.y, angulo, 0.35)


func _mover_puerta(angulo: float) -> void:
	puerta.rotation.y = angulo
	# Cerrada, el agua escapa por la junta de la tapa; abierta se ve la rotura.
	# El origen sigue unido al gabinete y nunca atraviesa su cara metálica.
	var apertura_puerta := smoothstep(0.0, deg_to_rad(70.0), absf(angulo))
	_emisiones.position = Vector3(-0.29, 0, 0.19) * (1.0 - apertura_puerta)


func _process(delta: float) -> void:
	_reloj += delta
	match estado:
		Estado.ROMPIENDO:
			# Presión, fractura y retroceso; el chorro empieza cuando se abre la junta.
			apertura = ease(clampf((_reloj - 0.22) / 0.48, 0.0, 1.0), 0.35)
			modelo.position = Vector3(sin(_reloj * 95.0), sin(_reloj * 71.0), 0) * 0.008 * (1.0 - apertura)
			if apertura > 0.08 and not chorro.emitting:
				chorro.emitting = true
				nube.emitting = true
				estallido.restart()
				estallido.emitting = true
			if _reloj >= 0.70:
				estado = Estado.ROTA
				modelo.position = Vector3.ZERO
		Estado.ROTA:
			apertura = 1.0
		Estado.SELLANDO:
			apertura = _apertura_inicial * (1.0 - smoothstep(0.0, 0.85, _reloj))
			modelo.position = Vector3.ZERO
			if _reloj >= 1.5:
				restablecer()
				return
	_boca.visible = apertura > 0.08
	if is_instance_valid(_flujo):
		_flujo.visible = apertura > 0.08
		_material_flujo.set_shader_parameter("reloj", _reloj)
		_material_flujo.set_shader_parameter("nivel", nivel_agua)
		_material_flujo.set_shader_parameter("presion", apertura * (1.0 - smoothstep(0.0, 0.3, _reloj) if estado == Estado.SELLANDO else 1.0))
	var oscilacion := sin(_reloj * 15.0) * exp(-maxf(0.0, _reloj - 0.7) * 3.0) * 0.035
	var desplazamiento := Vector3(0.035, -0.12, 0.23) if nitrogeno else Vector3(0.06, -0.20, 0.22)
	tramo.position = _pose.origin + desplazamiento * apertura
	tramo.rotation = Vector3(-0.22, 0.10, -0.38 + oscilacion) * apertura


func _crear_boca() -> void:
	_boca = MeshInstance3D.new()
	_boca.name = "InteriorFractura"
	var disco := CylinderMesh.new()
	disco.top_radius = 0.042 if nitrogeno else 0.058
	disco.bottom_radius = disco.top_radius
	disco.height = 0.012
	disco.radial_segments = 12
	var oscuro := StandardMaterial3D.new()
	oscuro.albedo_color = Color("10242f")
	disco.material = oscuro
	_boca.mesh = disco
	if nitrogeno:
		_boca.rotation.x = PI * 0.5
	salida.add_child(_boca)


func _crear_emisiones() -> void:
	_emisiones = Node3D.new()
	_emisiones.name = "Emisiones"
	salida.add_child(_emisiones)
	chorro = _particulas(100 if nitrogeno else 110, nitrogeno)
	chorro.name = "FugaNitrogeno" if nitrogeno else "ChorroAgua"
	chorro.lifetime = 0.75 if nitrogeno else 0.70
	chorro.direction = Vector3(0, -0.25, 1) if nitrogeno else Vector3(0, -0.30, 1)
	chorro.spread = 13.0 if nitrogeno else 9.0
	chorro.initial_velocity_min = 1.2 if nitrogeno else 1.0
	chorro.initial_velocity_max = 2.0 if nitrogeno else 1.6
	chorro.gravity = Vector3(0, -0.40, 0) if nitrogeno else Vector3(0, -3.3, 0)
	_emisiones.add_child(chorro)
	nube = _particulas(40 if nitrogeno else 45, nitrogeno)
	nube.name = "NieblaFria" if nitrogeno else "Rocio"
	nube.lifetime = 1.45 if nitrogeno else 0.55
	nube.direction = Vector3(0, -0.8, 1)
	nube.spread = 38
	nube.initial_velocity_min = 0.3
	nube.initial_velocity_max = 0.8
	nube.gravity = Vector3(0, -0.4, 0) if nitrogeno else Vector3(0, -2.2, 0)
	nube.scale_amount_min = 0.8 if nitrogeno else 0.3
	nube.scale_amount_max = 1.8 if nitrogeno else 0.7
	_emisiones.add_child(nube)
	estallido = _particulas(28, nitrogeno)
	estallido.name = "DescargaInicial"
	estallido.one_shot = true
	estallido.explosiveness = 1.0
	estallido.lifetime = 0.45
	estallido.direction = Vector3(0, 0.1, 1)
	estallido.spread = 65
	estallido.initial_velocity_min = 1.0
	estallido.initial_velocity_max = 2.2
	estallido.gravity = Vector3(0, -2, 0)
	_emisiones.add_child(estallido)


func _particulas(cantidad: int, vapor: bool) -> CPUParticles3D:
	var emisor := CPUParticles3D.new()
	emisor.emitting = false
	emisor.amount = cantidad
	emisor.local_coords = true
	emisor.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emisor.emission_sphere_radius = 0.018
	emisor.scale_amount_min = 0.4
	emisor.scale_amount_max = 0.9
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if vapor:
		# Motas suaves con expansión: el nitrógeno se lee como gas frío, no como agua.
		var gradiente := Gradient.new()
		gradiente.set_color(0, Color.WHITE)
		gradiente.set_color(1, Color(1, 1, 1, 0))
		var textura := GradientTexture2D.new()
		textura.width = 32
		textura.height = 32
		textura.gradient = gradiente
		textura.fill = GradientTexture2D.FILL_RADIAL
		textura.fill_from = Vector2(0.5, 0.5)
		textura.fill_to = Vector2(1.0, 0.5)
		material.albedo_texture = textura
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * 0.18
		quad.material = material
		emisor.mesh = quad
		var expansion := Curve.new()
		expansion.add_point(Vector2(0, 0.25))
		expansion.add_point(Vector2(1, 1.0))
		emisor.scale_amount_curve = expansion
	else:
		var gota := SphereMesh.new()
		gota.radius = 0.012
		gota.height = 0.045
		gota.radial_segments = 6
		gota.rings = 2
		gota.material = material
		emisor.mesh = gota
	var color := Color(0.72, 0.86, 1.0, 0.65) if vapor else Color(0.50, 0.88, 1.0, 0.9)
	var rampa := Gradient.new()
	rampa.set_color(0, Color(color, 0.0))
	rampa.add_point(0.08, color)
	rampa.add_point(0.6, color)
	rampa.set_color(1, Color(color, 0.0))
	emisor.color_ramp = rampa
	emisor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return emisor


func _crear_flujo() -> void:
	# Núcleo continuo parabólico acompañado por gotas y rocío independientes.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for anillo in 24:
		for lado in 8:
			for indice: Vector2i in [Vector2i(anillo, lado), Vector2i(anillo + 1, lado), Vector2i(anillo, lado + 1), Vector2i(anillo, lado + 1), Vector2i(anillo + 1, lado), Vector2i(anillo + 1, lado + 1)]:
				var v := indice.x / 24.0
				var t := v * 0.72
				var angulo := indice.y * TAU / 8.0
				var tangente := Vector3(0, -0.3 - 3.3 * t, 1.3).normalized()
				var radial := Vector3.RIGHT * cos(angulo) + tangente.cross(Vector3.RIGHT) * sin(angulo)
				st.set_normal(radial)
				st.set_uv(Vector2(indice.y / 8.0, v))
				st.add_vertex(Vector3(0, -0.3 * t - 1.65 * t * t, 1.3 * t) + radial * lerpf(0.020, 0.008, v))
	st.index()
	_flujo = MeshInstance3D.new()
	_flujo.name = "FlujoContinuo"
	_flujo.mesh = st.commit()
	_material_flujo = ShaderMaterial.new()
	_material_flujo.shader = preload("res://Eventos/Tuberias/chorro.gdshader")
	_flujo.material_override = _material_flujo
	_flujo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_emisiones.add_child(_flujo)
