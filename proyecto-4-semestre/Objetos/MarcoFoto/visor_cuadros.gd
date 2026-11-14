extends Control

@onready var _foto: TextureRect = $Foto
@onready var _titulo: Label = $Titulo
@onready var _cerrar: Button = $Cerrar

var _jugador: Player
var _bloqueo_previo := false
var _raton_previo := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"visor_cuadros")
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cerrar.pressed.connect(cerrar)
	hide()


func mostrar(imagen: Texture2D, titulo: String, jugador: Player) -> void:
	if imagen == null:
		return
	_jugador = jugador
	_bloqueo_previo = jugador.input_locked
	_raton_previo = Input.mouse_mode
	_foto.texture = imagen
	_titulo.text = titulo
	jugador.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	_cerrar.grab_focus()


func cerrar() -> void:
	if not visible:
		return
	hide()
	if is_instance_valid(_jugador):
		_jugador.input_locked = _bloqueo_previo
	Input.mouse_mode = _raton_previo
	_jugador = null


func _input(evento: InputEvent) -> void:
	if visible and evento.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cerrar()


func _exit_tree() -> void:
	if visible:
		cerrar()
