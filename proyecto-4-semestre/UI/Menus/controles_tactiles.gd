extends Control
## Entrada táctil local. No cambia las reglas ni los mensajes de la partida LAN.

const IZQUIERDA := &"policia_prueba_izquierda"
const DERECHA := &"policia_prueba_derecha"
const ARRIBA := &"policia_prueba_adelante"
const ABAJO := &"policia_prueba_atras"
const SALTAR := &"policia_prueba_saltar"
const CORRER := &"policia_prueba_correr"
const GESTOS := &"policia_menu_emotes"
const INTERACTUAR := &"Interactuar"

var jugador: Player
var oficina: Node3D
var _dedo_palanca := -1
var _dedos_botones: Dictionary = {}
var _palanca := Vector2.ZERO
var _habilitado := false
var _duelo := false
var _modo_panel := false
var _escala := 1.0
var _centro_palanca := Vector2.ZERO
var _botones: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_recalcular)
	_recalcular()


func _exit_tree() -> void:
	_liberar_todo()


func _process(_delta: float) -> void:
	var red: Node = oficina.get("red") if is_instance_valid(oficina) else null
	var en_duelo: bool = is_instance_valid(red) and (red.get("_duelo") as Dictionary).get("fase", "") == "choque"
	var disponible: bool = is_instance_valid(jugador) and not get_tree().paused and not MenuGlobal.capa.visible and not oficina.ruleta_emotes.visible
	var modo_panel: bool = disponible and jugador.input_locked and not en_duelo
	if disponible != _habilitado or en_duelo != _duelo or modo_panel != _modo_panel:
		_habilitado = disponible
		_duelo = en_duelo
		_modo_panel = modo_panel
		if not disponible or modo_panel:
			_liberar_todo()
		_recalcular()
	visible = disponible


func _recalcular() -> void:
	_escala = maxf(0.55, minf(size.x / 1920.0, size.y / 1080.0))
	var s := _escala
	_centro_palanca = Vector2(170.0 * s, size.y - 175.0 * s)
	if _modo_panel:
		_botones = [
			{"nombre": "VOLVER", "accion": &"Cancel", "centro": Vector2(size.x - 80.0 * s, size.y - 85.0 * s), "radio": 57.0 * s},
			{"nombre": "‹", "accion": &"movil_izquierda", "centro": Vector2(90.0 * s, size.y - 90.0 * s), "radio": 54.0 * s},
			{"nombre": "USAR", "accion": &"movil_elegir", "centro": Vector2(210.0 * s, size.y - 90.0 * s), "radio": 54.0 * s},
			{"nombre": "›", "accion": &"movil_derecha", "centro": Vector2(330.0 * s, size.y - 90.0 * s), "radio": 54.0 * s},
		]
		queue_redraw()
		return
	if _duelo:
		_botones = [{"nombre": "¡PULSA!", "accion": SALTAR, "centro": Vector2(size.x - 170.0 * s, size.y - 180.0 * s), "radio": 88.0 * s}]
		queue_redraw()
		return
	_botones = [
		{"nombre": "USAR" if not _duelo else "¡PULSA!", "accion": INTERACTUAR if not _duelo else SALTAR, "centro": Vector2(size.x - 150.0 * s, size.y - 190.0 * s), "radio": 72.0 * s},
		{"nombre": "SALTAR", "accion": SALTAR, "centro": Vector2(size.x - 295.0 * s, size.y - 120.0 * s), "radio": 62.0 * s},
		{"nombre": "CORRER", "accion": CORRER, "centro": Vector2(size.x - 445.0 * s, size.y - 145.0 * s), "radio": 58.0 * s},
		{"nombre": "GESTOS", "accion": GESTOS, "centro": Vector2(size.x - 315.0 * s, size.y - 280.0 * s), "radio": 60.0 * s},
		{"nombre": "PAUSA", "accion": &"Cancel", "centro": Vector2(size.x - 75.0 * s, size.y - 390.0 * s), "radio": 46.0 * s},
		{"nombre": "CÁMARA", "accion": &"CambiarCamara", "centro": Vector2(size.x - 190.0 * s, size.y - 425.0 * s), "radio": 46.0 * s},
		{"nombre": "TABLA", "accion": &"VerClasificacion", "centro": Vector2(size.x - 305.0 * s, size.y - 460.0 * s), "radio": 46.0 * s},
	]
	queue_redraw()


func _draw() -> void:
	if not _habilitado:
		return
	var s := _escala
	if not _modo_panel and not _duelo:
		draw_circle(_centro_palanca, 112.0 * s, Color(0.04, 0.13, 0.19, 0.58), true)
		draw_arc(_centro_palanca, 109.0 * s, 0.0, TAU, 64, Color(0.55, 0.86, 0.89, 0.85), 4.0 * s, true)
		draw_circle(_centro_palanca + _palanca * 66.0 * s, 48.0 * s, Color(0.12, 0.57, 0.67, 0.88), true)
	var fuente := ThemeDB.fallback_font
	for boton: Dictionary in _botones:
		var centro: Vector2 = boton.centro
		var radio: float = boton.radio
		var pulsado := _dedos_botones.values().has(boton.accion)
		draw_circle(centro, radio, Color(0.97, 0.42, 0.32, 0.9) if pulsado else Color(0.04, 0.15, 0.21, 0.76), true)
		draw_arc(centro, radio - 2.0 * s, 0.0, TAU, 48, Color(1.0, 0.94, 0.82, 0.9), 3.0 * s, true)
		var texto: String = boton.nombre
		var tamano := roundi((17.0 if texto.length() > 6 else 22.0) * s)
		draw_string(fuente, centro + Vector2(-radio, tamano * 0.35), texto, HORIZONTAL_ALIGNMENT_CENTER, radio * 2.0, tamano, Color.WHITE)


func _input(evento: InputEvent) -> void:
	if not _habilitado:
		return
	if evento is InputEventScreenTouch:
		if evento.pressed:
			if not _modo_panel and not _duelo and _dedo_palanca < 0 and evento.position.distance_to(_centro_palanca) <= 130.0 * _escala:
				_dedo_palanca = evento.index
				_mover_palanca(evento.position)
				get_viewport().set_input_as_handled()
				return
			for boton: Dictionary in _botones:
				if evento.position.distance_to(boton.centro) <= boton.radio:
					_dedos_botones[evento.index] = boton.accion
					_enviar_accion(boton.accion, true)
					queue_redraw()
					get_viewport().set_input_as_handled()
					return
		else:
			if evento.index == _dedo_palanca:
				_dedo_palanca = -1
				_mover_palanca(_centro_palanca)
				get_viewport().set_input_as_handled()
			elif _dedos_botones.has(evento.index):
				var accion: StringName = _dedos_botones[evento.index]
				_dedos_botones.erase(evento.index)
				if not _dedos_botones.values().has(accion):
					_enviar_accion(accion, false)
				queue_redraw()
				get_viewport().set_input_as_handled()
	elif evento is InputEventScreenDrag and evento.index == _dedo_palanca:
		_mover_palanca(evento.position)
		get_viewport().set_input_as_handled()


func _mover_palanca(posicion: Vector2) -> void:
	_palanca = ((posicion - _centro_palanca) / (95.0 * _escala)).limit_length()
	for dato: Dictionary in [
		{"accion": IZQUIERDA, "fuerza": maxf(0.0, -_palanca.x)},
		{"accion": DERECHA, "fuerza": maxf(0.0, _palanca.x)},
		{"accion": ARRIBA, "fuerza": maxf(0.0, -_palanca.y)},
		{"accion": ABAJO, "fuerza": maxf(0.0, _palanca.y)},
	]:
		if dato.fuerza >= 0.18:
			Input.action_press(dato.accion, dato.fuerza)
		else:
			Input.action_release(dato.accion)
	queue_redraw()


func _enviar_accion(accion: StringName, pulsada: bool) -> void:
	if accion in [&"Cancel", &"movil_izquierda", &"movil_elegir", &"movil_derecha"]:
		var tecla := InputEventKey.new()
		match accion:
			&"Cancel": tecla.keycode = KEY_ESCAPE
			&"movil_izquierda": tecla.keycode = KEY_LEFT
			&"movil_elegir": tecla.keycode = KEY_E
			&"movil_derecha": tecla.keycode = KEY_RIGHT
		tecla.physical_keycode = tecla.keycode
		tecla.pressed = pulsada
		Input.parse_input_event(tecla)
		return
	var evento := InputEventAction.new()
	evento.action = accion
	evento.pressed = pulsada
	evento.strength = 1.0 if pulsada else 0.0
	Input.parse_input_event(evento)


func _liberar_todo() -> void:
	_dedo_palanca = -1
	_mover_palanca(_centro_palanca)
	for accion: StringName in _dedos_botones.values():
		_enviar_accion(accion, false)
	_dedos_botones.clear()
	queue_redraw()
