extends Camera3D

signal vista_cambiada(vista: int)

enum Vista { ACTUAL, FRONTAL, GOD }

@export var objetivo: Node3D
@export var offset: Vector3 = Vector3(0, 3, 2)
@export_range(0.1, 20.0, 0.1) var suavizado: float = 5.0

@export_group("Vistas de cámara")
@export var vista_actual: Vista = Vista.ACTUAL
@export var offset_frontal := Vector3(0, 2.7, 3.8)
@export_range(-80.0, -10.0, 1.0) var inclinacion_frontal: float = -28.0
@export var offset_god := Vector3(0, 7, 0)
@export_range(0.1, 20.0, 0.1) var suavizado_giro: float = 4.0

@export_group("Balanceo ambiental")
@export var balanceo_activo: bool = true
@export var amplitud_balanceo := Vector2(0.12, 0.06)
@export_range(4.0, 30.0, 0.5) var periodo_balanceo: float = 10.0

@export_group("Límites de Cámara")
@export var limite_min_x: float = -4.592
@export var limite_max_x: float = 2.415
@export var limite_min_z: float = -0.153
@export var limite_max_z: float = 12.473

var _orientacion_original: Quaternion
var _orientacion: Quaternion
var _posicion_seguimiento: Vector3
var _fase_balanceo: float = 0.0
var _peso_balanceo: float = 1.0


func _ready() -> void:
	_orientacion_original = global_basis.orthonormalized().get_rotation_quaternion()
	_orientacion = _orientacion_original
	_posicion_seguimiento = global_position
	_peso_balanceo = 1.0 if balanceo_activo else 0.0


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_echo() or not is_current() or get_tree().paused or not is_instance_valid(objetivo):
		return
	if bool(objetivo.get("input_locked")):
		return
	if evento.is_action_pressed("CambiarCamara"):
		establecer_vista((int(vista_actual) + 1) % Vista.size())
	elif evento.is_action_pressed("CamaraActual"):
		establecer_vista(Vista.ACTUAL)
	elif evento.is_action_pressed("CamaraFrontal"):
		establecer_vista(Vista.FRONTAL)
	elif evento.is_action_pressed("CamaraGod"):
		establecer_vista(Vista.GOD)
	elif evento.is_action_pressed("AlternarBalanceoCamara"):
		balanceo_activo = not balanceo_activo
	else:
		return
	get_viewport().set_input_as_handled()


func establecer_vista(vista: int) -> void:
	var siguiente := clampi(vista, Vista.ACTUAL, Vista.GOD) as Vista
	if vista_actual == siguiente:
		return
	vista_actual = siguiente
	vista_cambiada.emit(vista_actual)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(objetivo):
		return
	# Los límites originales delimitan el seguimiento; cada vista añade su distancia.
	# Así el encuadre se conserva también al cambiar de vista junto a una pared.
	var ancla := objetivo.global_position + offset
	ancla.x = clampf(ancla.x, limite_min_x, limite_max_x)
	ancla.z = clampf(ancla.z, limite_min_z, limite_max_z)
	ancla -= offset
	var desfase := offset
	var orientacion_deseada := _orientacion_original
	if vista_actual == Vista.FRONTAL:
		desfase = offset_frontal
		orientacion_deseada = Quaternion(Vector3.RIGHT, deg_to_rad(inclinacion_frontal))
	elif vista_actual == Vista.GOD:
		desfase = offset_god
		orientacion_deseada = Quaternion(Vector3.RIGHT, -PI / 2.0)
	var avance := 1.0 - exp(-suavizado * delta)
	_posicion_seguimiento = _posicion_seguimiento.lerp(ancla + desfase, avance)
	_orientacion = _orientacion.slerp(orientacion_deseada, 1.0 - exp(-suavizado_giro * delta))
	global_basis = Basis(_orientacion)

	# Dos senos a frecuencias 1:2 dibujan un infinito en el plano de la pantalla.
	# Se aplica después del seguimiento para evitar deriva o acumulación del balanceo.
	_fase_balanceo = fposmod(_fase_balanceo + TAU * delta / periodo_balanceo, TAU)
	_peso_balanceo = lerpf(_peso_balanceo, 1.0 if balanceo_activo else 0.0, avance)
	var balanceo := Vector2(sin(_fase_balanceo), sin(2.0 * _fase_balanceo)) * amplitud_balanceo * _peso_balanceo
	global_position = _posicion_seguimiento + global_basis.x * balanceo.x + global_basis.y * balanceo.y
