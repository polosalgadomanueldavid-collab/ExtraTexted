extends Node
## Vincula la navegación global de la interfaz al primer mando conectado.
## La palanca derecha queda libre para la ruleta y para desplazar listas.
signal mando_cambiado(dispositivo: int)

var dispositivo_mando := -1
var _escena_scroll: Node
var _scroll_predeterminado: ScrollContainer
var _reloj_busqueda_scroll := 0.0
var _reloj_navegacion := 0.0
var _direccion_analogica := Vector2.ZERO

const ACCIONES_UI: Array[StringName] = [
	&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_accept", &"ui_cancel",
	&"ui_focus_next", &"ui_focus_prev", &"Cancel",
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_al_cambio_conexion)
	_actualizar_mando()


func _al_cambio_conexion(_dispositivo: int, _conectado: bool) -> void:
	call_deferred("_actualizar_mando")


func _process(delta: float) -> void:
	if dispositivo_mando < 0:
		return
	for panel in get_tree().get_nodes_in_group("cursor_mando"):
		if panel.cursor_mando_activo():
			panel.procesar_cursor_mando(delta, dispositivo_mando)
			_direccion_analogica = Vector2.ZERO
			return
	_navegar_con_palanca(delta)
	_reloj_busqueda_scroll = maxf(0.0, _reloj_busqueda_scroll - delta)
	var foco := _viewport_foco().gui_get_focus_owner()
	var scroll := _buscar_scroll(foco)
	if scroll == null:
		return
	var y := Input.get_joy_axis(dispositivo_mando, JOY_AXIS_RIGHT_Y)
	if absf(y) > 0.18 and scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page:
		var velocidad := signf(y) * pow(absf(y), 1.5) * 820.0 * delta
		scroll.scroll_vertical = clampi(scroll.scroll_vertical + roundi(velocidad), 0, roundi(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page))
	var x := Input.get_joy_axis(dispositivo_mando, JOY_AXIS_RIGHT_X)
	if absf(x) > 0.18 and scroll.get_h_scroll_bar().max_value > scroll.get_h_scroll_bar().page:
		var velocidad_x := signf(x) * pow(absf(x), 1.5) * 820.0 * delta
		scroll.scroll_horizontal = clampi(scroll.scroll_horizontal + roundi(velocidad_x), 0, roundi(scroll.get_h_scroll_bar().max_value - scroll.get_h_scroll_bar().page))


func _navegar_con_palanca(delta: float) -> void:
	_reloj_navegacion = maxf(0.0, _reloj_navegacion - delta)
	var eje := Vector2(Input.get_joy_axis(dispositivo_mando, JOY_AXIS_LEFT_X), Input.get_joy_axis(dispositivo_mando, JOY_AXIS_LEFT_Y))
	var nueva_direccion := Vector2.ZERO
	# Histéresis: una pequeña oscilación junto al umbral no cuenta como
	# soltar y volver a pulsar. La primera repetición permite leer cada opción.
	var umbral := 0.20 if _direccion_analogica == Vector2.ZERO else 0.12
	if eje.length() >= umbral:
		if absf(eje.x) > absf(eje.y):
			nueva_direccion.x = signf(eje.x)
		else:
			nueva_direccion.y = signf(eje.y)
	if nueva_direccion == Vector2.ZERO:
		_direccion_analogica = Vector2.ZERO
		_reloj_navegacion = 0.0
		return
	if nueva_direccion != _direccion_analogica:
		_direccion_analogica = nueva_direccion
		_reloj_navegacion = 0.40
		_mover_foco(nueva_direccion)
	elif _reloj_navegacion <= 0.0:
		_reloj_navegacion = 0.20
		_mover_foco(nueva_direccion)


func _viewport_foco() -> Viewport:
	for panel in get_tree().get_nodes_in_group("foco_mando_interno"):
		var interno: Viewport = panel.viewport_mando()
		if interno != null:
			return interno
	return get_viewport()


func _mover_foco(direccion: Vector2) -> void:
	var foco := _viewport_foco().gui_get_focus_owner() as Control
	if foco == null or not foco.is_visible_in_tree():
		return
	var lado := SIDE_TOP
	if direccion.y < 0.0:
		lado = SIDE_TOP
	elif direccion.y > 0.0:
		lado = SIDE_BOTTOM
	elif direccion.x < 0.0:
		lado = SIDE_LEFT
	else:
		lado = SIDE_RIGHT
	var siguiente := foco.find_valid_focus_neighbor(lado)
	if siguiente == null:
		siguiente = foco.find_next_valid_focus()
	if siguiente != null and siguiente != foco:
		siguiente.grab_focus()


func _actualizar_mando() -> void:
	var conectados := Input.get_connected_joypads()
	var nuevo := int(conectados[0]) if not conectados.is_empty() else -1
	if nuevo == dispositivo_mando:
		return
	_quitar_eventos_mando()
	dispositivo_mando = nuevo
	if dispositivo_mando >= 0:
		_registrar_eventos_mando()
	mando_cambiado.emit(dispositivo_mando)


func _quitar_eventos_mando() -> void:
	for accion: StringName in ACCIONES_UI:
		if not InputMap.has_action(accion):
			continue
		for evento: InputEvent in InputMap.action_get_events(accion).duplicate():
			if evento is InputEventJoypadButton or evento is InputEventJoypadMotion:
				InputMap.action_erase_event(accion, evento)


func _registrar_eventos_mando() -> void:
	# Las acciones globales aceptan un solo dispositivo para que dos mandos no
	# muevan simultáneamente el foco en una misma instancia de la partida.
	_agregar_boton(&"ui_up", JOY_BUTTON_DPAD_UP)
	_agregar_boton(&"ui_down", JOY_BUTTON_DPAD_DOWN)
	_agregar_boton(&"ui_left", JOY_BUTTON_DPAD_LEFT)
	_agregar_boton(&"ui_right", JOY_BUTTON_DPAD_RIGHT)
	_agregar_boton(&"ui_accept", JOY_BUTTON_A)
	_agregar_boton(&"ui_cancel", JOY_BUTTON_B)
	_agregar_boton(&"Cancel", JOY_BUTTON_B)
	_agregar_boton(&"ui_cancel", JOY_BUTTON_START)
	_agregar_boton(&"Cancel", JOY_BUTTON_START)
	_agregar_boton(&"ui_focus_prev", JOY_BUTTON_LEFT_SHOULDER)
	_agregar_boton(&"ui_focus_next", JOY_BUTTON_RIGHT_SHOULDER)
	for accion: StringName in [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]:
		if InputMap.has_action(accion):
			InputMap.action_set_deadzone(accion, 0.16)


func _agregar_boton(accion: StringName, boton: JoyButton) -> void:
	var evento := InputEventJoypadButton.new()
	evento.device = dispositivo_mando
	evento.button_index = boton
	InputMap.action_add_event(accion, evento)


func _agregar_eje(accion: StringName, eje: JoyAxis, valor: float) -> void:
	var evento := InputEventJoypadMotion.new()
	evento.device = dispositivo_mando
	evento.axis = eje
	evento.axis_value = valor
	InputMap.action_add_event(accion, evento)


func _buscar_scroll(foco: Control) -> ScrollContainer:
	var actual: Node = foco
	while actual != null:
		if actual.is_in_group(&"ruleta_emotes"):
			return null
		if actual is ScrollContainer and actual.is_visible_in_tree():
			return actual as ScrollContainer
		actual = actual.get_parent()
	if get_tree().current_scene == null:
		return null
	if _escena_scroll != get_tree().current_scene:
		_escena_scroll = get_tree().current_scene
		_scroll_predeterminado = null
		_reloj_busqueda_scroll = 0.0
	if is_instance_valid(_scroll_predeterminado) and _scroll_predeterminado.is_visible_in_tree():
		return _scroll_predeterminado
	if _reloj_busqueda_scroll > 0.0:
		return null
	var candidatos := get_tree().current_scene.find_children("*", "ScrollContainer", true, false)
	for indice: int in range(candidatos.size() - 1, -1, -1):
		var candidato := candidatos[indice] as ScrollContainer
		if candidato.is_visible_in_tree() and (candidato.get_v_scroll_bar().max_value > candidato.get_v_scroll_bar().page or candidato.get_h_scroll_bar().max_value > candidato.get_h_scroll_bar().page):
			_scroll_predeterminado = candidato
			_reloj_busqueda_scroll = 0.35
			return _scroll_predeterminado
	_reloj_busqueda_scroll = 0.35
	return null
