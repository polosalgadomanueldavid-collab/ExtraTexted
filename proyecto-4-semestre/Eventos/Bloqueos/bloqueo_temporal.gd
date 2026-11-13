extends StaticBody3D

signal impacto_agua(posicion: Vector3)
signal impacto_lava(posicion: Vector3)

@export_range(0.5, 5.0, 0.1) var altura_caida: float = 2.5
@export_range(0.1, 2.0, 0.05) var duracion_caida: float = 0.55
@export_range(0.0, 0.3, 0.01) var altura_rebote: float = 0.08

@onready var diseño_cajon: Node3D = $Diseño_Cajon

var _activa := true
var _altura_final := 0.0
var _animacion: Tween
var _reposo: Transform3D
var _flotacion: Node3D
var _nivel_agua := -INF
var _lava_activa := false
var es_ceniza := false
var _cenizas: Node3D
var _polvo_ceniza: CPUParticles3D
var _hollin: StandardMaterial3D
var _polvo_lanzado := false
var _capas_originales: Dictionary[MeshInstance3D, Material] = {}
const DURACION_CARBONIZACION := 1.1


func _enter_tree() -> void:
	add_to_group("bloqueos_temporales")


func _ready() -> void:
	_flotacion = Node3D.new()
	_flotacion.name = "FlotacionVisual"
	add_child(_flotacion)
	diseño_cajon.reparent(_flotacion, false)
	_reposo = diseño_cajon.transform
	_altura_final = diseño_cajon.position.y
	if _activa:
		_animar_caida()


func preparar_para_pool() -> void:
	_activa = false
	visible = false
	collision_layer = 0
	collision_mask = 0


func activar_en(posicion: Vector3) -> void:
	_restaurar_aspecto()
	global_position = posicion
	_activa = true
	visible = true
	collision_layer = 1
	collision_mask = 1
	_animar_caida()


func desactivar() -> void:
	actualizar_agua(-INF, 0)
	actualizar_lava(false)
	_activa = false
	if _animacion != null and _animacion.is_valid():
		_animacion.kill()
	$Polvo.emitting = false
	_restaurar_aspecto()
	diseño_cajon.transform = _reposo
	collision_layer = 0
	collision_mask = 0
	visible = false


func caer_en_grieta(destino: Vector2) -> void:
	if es_ceniza:
		return
	if _animacion != null and _animacion.is_valid():
		_animacion.kill()
	collision_layer = 0
	collision_mask = 0
	$Polvo.emitting = false
	var hacia := Vector3(destino.x - global_position.x, 0, destino.y - global_position.z)
	var eje := Vector3.UP.cross(hacia.normalized())
	if eje.is_zero_approx():
		eje = Vector3.RIGHT
	var vuelco := diseño_cajon.transform.rotated_local(eje, 1.22)
	vuelco.origin = _reposo.origin + hacia.limit_length(0.65) + Vector3.DOWN * 1.8
	_animacion = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_animacion.tween_property(diseño_cajon, "transform", vuelco, 0.72)
	_animacion.tween_callback(desactivar)


func _animar_caida() -> void:
	if _animacion != null and _animacion.is_valid():
		_animacion.kill()
	$Polvo.emitting = false
	diseño_cajon.position.y = _altura_final + altura_caida
	_animacion = create_tween()
	_animacion.tween_property(
		diseño_cajon,
		"position:y",
		_altura_final,
		duracion_caida
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_animacion.tween_callback(_activar_polvo)
	_animacion.tween_property(
		diseño_cajon,
		"position:y",
		_altura_final + altura_rebote,
		0.08
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_animacion.tween_property(
		diseño_cajon,
		"position:y",
		_altura_final,
		0.312
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _activar_polvo() -> void:
	if _activa:
		if _lava_activa:
			impacto_lava.emit(global_position)
		elif _nivel_agua > 0.422:
			impacto_agua.emit(global_position)
		else:
			$Polvo.emitting = true
			$Polvo.restart()


func actualizar_lava(activa: bool) -> void:
	_lava_activa = activa
	if activa:
		$Polvo.emitting = false
		# Retira también las motas emitidas justo antes del inicio del evento.
		$Polvo.restart()
		$Polvo.emitting = false


func actualizar_agua(altura: float, reloj: float) -> void:
	_nivel_agua = altura
	if not is_instance_valid(_flotacion):
		return
	if altura == -INF:
		_flotacion.transform = Transform3D.IDENTITY
		return
	$Polvo.emitting = false
	var peso := smoothstep(0.4, 0.9, altura)
	var fase := reloj * 1.8 + global_position.x * 1.3 + global_position.z * 0.8
	_flotacion.position.y = maxf(0.0, altura - 0.60) + sin(fase) * 0.018 * peso
	_flotacion.rotation = Vector3(cos(fase * 0.78) * 0.025, 0, sin(fase) * 0.03) * peso


func convertir_en_ceniza() -> void:
	if es_ceniza:
		return
	es_ceniza = true
	_polvo_lanzado = false
	if _animacion != null and _animacion.is_valid():
		_animacion.kill()
	$Polvo.emitting = false
	if not is_instance_valid(_cenizas):
		_crear_cenizas()
	_hollin = StandardMaterial3D.new()
	_hollin.albedo_color = Color(0.035, 0.025, 0.02, 0.0)
	_hollin.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hollin.roughness = 1.0
	for pieza: MeshInstance3D in diseño_cajon.find_children("*", "MeshInstance3D", true, false):
		_capas_originales[pieza] = pieza.material_overlay
		pieza.material_overlay = _hollin
	_animar_carbonizacion(0.0)
	_animacion = create_tween()
	_animacion.tween_method(_animar_carbonizacion, 0.0, 1.0, DURACION_CARBONIZACION)
	_animacion.tween_callback(diseño_cajon.hide)


func _animar_carbonizacion(progreso: float) -> void:
	# La geometría se oscurece, tiembla y colapsa; el cuerpo físico sigue estable.
	var hundir := smoothstep(0.20, 0.95, progreso)
	_hollin.albedo_color.a = smoothstep(0.0, 0.34, progreso) * 0.98
	var pose := _reposo
	pose.basis = pose.basis.scaled_local(Vector3(1.0 - hundir * 0.15, maxf(0.025, 1.0 - hundir * 0.975), 1.0 - hundir * 0.15))
	pose.basis = pose.basis.rotated(Vector3.UP, sin(progreso * 66.0) * sin(progreso * PI) * 0.07)
	pose.origin.y = lerpf(_reposo.origin.y, 0.09, hundir)
	pose.origin.x += sin(progreso * 80.0) * sin(progreso * PI) * 0.018
	diseño_cajon.transform = pose
	var aparecer := smoothstep(0.32, 0.92, progreso)
	_cenizas.visible = aparecer > 0.0
	_cenizas.scale = Vector3(lerpf(0.65, 1.0, aparecer), maxf(0.025, aparecer), lerpf(0.65, 1.0, aparecer))
	if progreso >= 0.42 and not _polvo_lanzado:
		_polvo_lanzado = true
		_polvo_ceniza.restart()
		_polvo_ceniza.emitting = true


func _restaurar_aspecto() -> void:
	es_ceniza = false
	for pieza in _capas_originales:
		if is_instance_valid(pieza):
			pieza.material_overlay = _capas_originales[pieza]
	_capas_originales.clear()
	_hollin = null
	diseño_cajon.show()
	diseño_cajon.transform = _reposo
	if is_instance_valid(_cenizas):
		_cenizas.hide()
	if is_instance_valid(_polvo_ceniza):
		_polvo_ceniza.emitting = false


func _crear_cenizas() -> void:
	_cenizas = Node3D.new()
	_cenizas.name = "RestosCarbonizados"
	add_child(_cenizas)
	# Restos apilados de la misma altura: la silueta explica la colisión conservada.
	for i in 11:
		var piedra := MeshInstance3D.new()
		var malla := SphereMesh.new()
		malla.radius = 0.20
		malla.height = 0.30
		malla.radial_segments = 5
		malla.rings = 2
		piedra.mesh = malla
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("3f4248").lightened(float(i % 4) * 0.065)
		material.roughness = 1.0
		piedra.material_override = material
		piedra.position = Vector3(sin(i * 2.4) * 0.09, 0.12 + (i / 3) * 0.21, cos(i * 2.4) * 0.09)
		piedra.rotation = Vector3(i * 0.31, i * 1.8, i * 0.23)
		_cenizas.add_child(piedra)
	_polvo_ceniza = CPUParticles3D.new()
	_polvo_ceniza.name = "PolvoCarbonizacion"
	_polvo_ceniza.emitting = false
	_polvo_ceniza.one_shot = true
	_polvo_ceniza.amount = 24
	_polvo_ceniza.lifetime = 0.65
	_polvo_ceniza.explosiveness = 1.0
	_polvo_ceniza.direction = Vector3.UP
	_polvo_ceniza.spread = 65.0
	_polvo_ceniza.initial_velocity_min = 0.35
	_polvo_ceniza.initial_velocity_max = 0.8
	_polvo_ceniza.gravity = Vector3(0, -0.3, 0)
	_polvo_ceniza.position.y = 0.3
	var polvo := SphereMesh.new()
	polvo.radius = 0.045
	polvo.height = 0.09
	polvo.radial_segments = 6
	polvo.rings = 3
	var material_polvo := StandardMaterial3D.new()
	material_polvo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_polvo.vertex_color_use_as_albedo = true
	polvo.material = material_polvo
	_polvo_ceniza.mesh = polvo
	var colores := Gradient.new()
	colores.set_color(0, Color(0.30, 0.28, 0.25, 0.65))
	colores.set_color(1, Color(0.30, 0.28, 0.25, 0.0))
	_polvo_ceniza.color_ramp = colores
	add_child(_polvo_ceniza)
