class_name TacoLuz
extends StaticBody3D

signal interaccion_solicitada(jugador: Player)

const COLOR_CON_LUZ := Color("69d8cd")
const COLOR_SIN_LUZ := Color("ffc969")
const ANGULO_ABIERTO := -105.0
const POSICION_BISAGRA := Vector3(-1.013955, 0.0, -0.20)

@export var montado_en_pared: bool = false

var apagon_activo: bool = false
var abierto: bool = false
var _animacion_tapa: Tween

@onready var _tapa_pivot: Node3D = $Modelo/TacoLuz/TapaPivot
@onready var _testigo: MeshInstance3D = $Testigo
@onready var _luz_testigo: OmniLight3D = $Testigo/Luz


func _ready() -> void:
	$Base.visible = not montado_en_pared
	$Soporte.visible = not montado_en_pared
	# El GLB trae la tapa apartada. El rebaje de la tapa entra en el marco al cerrar.
	_tapa_pivot.position = POSICION_BISAGRA
	_tapa_pivot.rotation.y = deg_to_rad(ANGULO_ABIERTO if abierto else 0.0)
	_actualizar_estado()


func interactuar(jugador: Player) -> void:
	interaccion_solicitada.emit(jugador)


func establecer_apagon(activo: bool) -> void:
	apagon_activo = activo
	if is_node_ready():
		_actualizar_estado()


func establecer_abierto(nuevo_estado: bool) -> void:
	abierto = nuevo_estado
	if not is_node_ready():
		return
	if _animacion_tapa != null:
		_animacion_tapa.kill()
	_animacion_tapa = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_animacion_tapa.tween_property(
		_tapa_pivot, "rotation:y", deg_to_rad(ANGULO_ABIERTO if abierto else 0.0), 0.35
	)


func _actualizar_estado() -> void:
	var color := COLOR_SIN_LUZ if apagon_activo else COLOR_CON_LUZ
	var material := _testigo.material_override as StandardMaterial3D
	material.albedo_color = color
	material.emission = color
	_luz_testigo.light_color = color
	_luz_testigo.light_energy = 0.35 if apagon_activo else 0.15
