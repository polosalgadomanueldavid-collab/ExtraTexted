extends StaticBody3D

@export_range(0.5, 5.0, 0.1) var altura_caida: float = 2.5
@export_range(0.1, 2.0, 0.05) var duracion_caida: float = 0.55
@export_range(0.0, 0.3, 0.01) var altura_rebote: float = 0.08

@onready var diseño_cajon: Node3D = $Diseño_Cajon

var _activa := true
var _altura_final := 0.0
var _animacion: Tween
var _reposo: Transform3D


func _ready() -> void:
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
	global_position = posicion
	_activa = true
	visible = true
	collision_layer = 1
	collision_mask = 1
	_animar_caida()


func desactivar() -> void:
	_activa = false
	if _animacion != null and _animacion.is_valid():
		_animacion.kill()
	$Polvo.emitting = false
	diseño_cajon.transform = _reposo
	collision_layer = 0
	collision_mask = 0
	visible = false


func caer_en_grieta(destino: Vector2) -> void:
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
		$Polvo.emitting = true
		$Polvo.restart()
