class_name EventoApagon
extends Node
## Evento optativo. La escena que lo instancia decide cuándo iniciar el apagón.

signal estado_cambiado(nuevo_estado: Estado)
signal apagon_iniciado(tipo: int)
signal luz_restaurada

enum Estado { RESTAURADO, APAGADO, REPARANDO }

const PANEL_CIRCUITOS := preload("res://UI/Apagon/panel_circuitos.gd")
const TIPOS_DISPONIBLES := PANEL_CIRCUITOS.TIPOS_DISPONIBLES
const TACO_LUZ := preload("res://Eventos/Apagon/taco_luz.gd")
const VISION_APAGON := preload("res://Eventos/Apagon/vision_apagon.gdshader")
const INDICADOR_LUZ := preload("res://UI/Apagon/indicador_luz.gd")

@export var jugador: Player
@export var camara: Camera3D
@export var taco: TACO_LUZ
@export var luces: Array[Light3D] = []
@export var barra_despacho: Control
@export_range(1.0, 5.0, 0.01) var radio_vision: float = 2.4

var estado: Estado = Estado.RESTAURADO
var tipo_circuito: int = -1
var semilla_circuito: int = 0
var panel: PANEL_CIRCUITOS
var mascara: ColorRect
var luz_jugador: OmniLight3D
var indicador_luz: INDICADOR_LUZ

var _azar := RandomNumberGenerator.new()
var _visibilidad_luces: Dictionary = {}
var _interaccion_abierta: bool = false
var _bloqueo_anterior: bool = false
var _raton_anterior: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	if jugador == null or camara == null or taco == null:
		push_error("EventoApagon necesita jugador, cámara y taco de luz.")
		set_process(false)
		return
	_azar.randomize()
	_crear_vision()
	var capa_indicador := CanvasLayer.new()
	capa_indicador.layer = 25
	add_child(capa_indicador)
	indicador_luz = INDICADOR_LUZ.new()
	capa_indicador.add_child(indicador_luz)
	var capa_panel := CanvasLayer.new()
	capa_panel.layer = 40
	add_child(capa_panel)
	panel = PANEL_CIRCUITOS.new()
	capa_panel.add_child(panel)
	panel.circuito_resuelto.connect(_al_resolver_circuito)
	panel.cerrado.connect(_al_cerrar_panel)
	taco.connect("interaccion_solicitada", _al_interactuar_taco)
	taco.establecer_apagon(false)


func _crear_vision() -> void:
	var capa_vision := CanvasLayer.new()
	capa_vision.layer = 20
	add_child(capa_vision)
	mascara = ColorRect.new()
	mascara.name = "VisionLimitada"
	mascara.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mascara.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material_vision := ShaderMaterial.new()
	material_vision.shader = VISION_APAGON
	mascara.material = material_vision
	mascara.hide()
	capa_vision.add_child(mascara)
	luz_jugador = OmniLight3D.new()
	luz_jugador.name = "LuzDeEmergencia"
	luz_jugador.light_color = Color(0.85, 0.93, 1.0)
	luz_jugador.light_energy = 1.3
	luz_jugador.omni_range = radio_vision * 1.7
	luz_jugador.hide()
	add_child(luz_jugador)


func iniciar_apagon() -> bool:
	if not is_node_ready() or mascara == null or estado != Estado.RESTAURADO:
		return false
	if get_tree().paused or jugador.input_locked:
		return false
	tipo_circuito = TIPOS_DISPONIBLES[_azar.randi_range(0, TIPOS_DISPONIBLES.size() - 1)]
	semilla_circuito = _azar.randi()
	_visibilidad_luces.clear()
	for luz: Light3D in luces:
		if is_instance_valid(luz):
			_visibilidad_luces[luz] = luz.visible
			luz.hide()
	taco.establecer_apagon(true)
	luz_jugador.show()
	_actualizar_vision()
	_cambiar_estado(Estado.APAGADO)
	apagon_iniciado.emit(tipo_circuito)
	return true


func _process(_delta: float) -> void:
	if estado != Estado.RESTAURADO:
		_actualizar_vision()
		_actualizar_indicador()


func _actualizar_indicador() -> void:
	indicador_luz.actualizar(
		camara, taco.to_global(Vector3(0, 1.8, 0)), barra_despacho,
		estado == Estado.APAGADO and get_viewport().get_camera_3d() == camara,
		jugador.obtener_objetivo_interaccion() == taco
	)


func _actualizar_vision() -> void:
	luz_jugador.global_position = jugador.global_position + Vector3.UP * 1.4
	# El primer plano de la PC usa su propia cámara y conserva la interfaz legible.
	mascara.visible = get_viewport().get_camera_3d() == camara
	if not mascara.visible:
		return
	var centro_mundo := jugador.global_position + Vector3.UP * 0.4
	var centro := camara.unproject_position(centro_mundo)
	var extremo := camara.unproject_position(centro_mundo + camara.global_basis.x * radio_vision)
	var tamano := get_viewport().get_visible_rect().size
	var material_vision := mascara.material as ShaderMaterial
	material_vision.set_shader_parameter("centro_uv", centro / tamano)
	material_vision.set_shader_parameter("radio_pixeles", centro.distance_to(extremo))


func _al_interactuar_taco(quien: Player) -> void:
	if quien != jugador or estado != Estado.APAGADO or jugador.input_locked or get_tree().paused:
		return
	_bloqueo_anterior = jugador.input_locked
	_raton_anterior = Input.mouse_mode
	_interaccion_abierta = true
	jugador.input_locked = true
	jugador.velocity.x = 0.0
	jugador.velocity.z = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	taco.establecer_abierto(true)
	_cambiar_estado(Estado.REPARANDO)
	panel.abrir(tipo_circuito, semilla_circuito)


func _al_cerrar_panel() -> void:
	if not _interaccion_abierta:
		return
	_interaccion_abierta = false
	jugador.input_locked = _bloqueo_anterior
	Input.mouse_mode = _raton_anterior
	taco.establecer_abierto(false)
	if estado == Estado.REPARANDO:
		_cambiar_estado(Estado.APAGADO)


func _al_resolver_circuito() -> void:
	if estado != Estado.REPARANDO:
		return
	_restaurar_luces()
	mascara.hide()
	luz_jugador.hide()
	taco.establecer_apagon(false)
	_cambiar_estado(Estado.RESTAURADO)
	panel.cerrar()
	luz_restaurada.emit()


func _restaurar_luces() -> void:
	for luz: Light3D in _visibilidad_luces:
		if is_instance_valid(luz):
			luz.visible = _visibilidad_luces[luz]
	_visibilidad_luces.clear()


func _cambiar_estado(nuevo_estado: Estado) -> void:
	estado = nuevo_estado
	_actualizar_indicador()
	estado_cambiado.emit(estado)


func _exit_tree() -> void:
	_restaurar_luces()
	if _interaccion_abierta and is_instance_valid(jugador):
		jugador.input_locked = _bloqueo_anterior
		Input.mouse_mode = _raton_anterior
	if is_instance_valid(taco) and taco.is_inside_tree():
		taco.establecer_apagon(false)
		taco.establecer_abierto(false)
