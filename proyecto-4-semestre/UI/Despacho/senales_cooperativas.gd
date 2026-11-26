extends Control
## Radio local sin pausa global. Solo presenta señales confirmadas por el anfitrión.
const FUENTE := preload("res://UI/Menus/fuente_lectura.tres")
const SONIDO := preload("res://Audios/Apagon/fase_fijar.wav")
const TINTA := Color("173b50")
const CREMA := Color("fff1d8")
const DURACION := 6.0
var red: Node
var marcas: Dictionary = {}
var _ultimo_numero := 0
var _panel: PanelContainer
var _opciones: VBoxContainer
var _abrir: Button
var _sonido: AudioStreamPlayer
var _botones: Array[Button] = []
var _estaciones := false
var _mouse_previo: Input.MouseMode
var _factor := 1.0
var _estilos: Dictionary = {}


func _ready() -> void:
	name = "RadioCooperativa"
	add_to_group("radio_cooperativa")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_abrir = Button.new()
	_abrir.text = "R · RADIO"
	_abrir.tooltip_text = "Señales para tu compañero · R / B en mando"
	_abrir.pressed.connect(alternar)
	_abrir.focus_mode = Control.FOCUS_NONE
	add_child(_abrir)
	_panel = PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = TINTA
	estilo.border_color = CREMA
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(16)
	estilo.content_margin_left = 18
	estilo.content_margin_right = 18
	estilo.content_margin_top = 14
	estilo.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", estilo)
	_panel.add_theme_font_override("font", FUENTE)
	_panel.add_theme_color_override("font_color", CREMA)
	add_child(_panel)
	_opciones = VBoxContainer.new()
	_opciones.add_theme_constant_override("separation", 8)
	_panel.add_child(_opciones)
	_panel.hide()
	_sonido = AudioStreamPlayer.new()
	_sonido.stream = SONIDO
	_sonido.bus = "Interacciones"
	_sonido.volume_db = -15
	add_child(_sonido)
	resized.connect(_ajustar)
	_ajustar()


func disponible() -> bool:
	return red._listo and SesionLAN.en_partida and not get_tree().paused \
		and not red.oficina.partida_finalizada and red.despacho.esta_activo(SesionLAN.id_local()) \
		and not MenuGlobal.capa.visible and not red.oficina.jugador.input_locked \
		and not red.oficina.jugador.realizando_gesto() and not red.oficina.ruleta_emotes.visible \
		and not red.oficina.clasificacion_partida.visible


func alternar() -> void:
	if _panel.visible:
		cerrar()
	elif disponible():
		_mouse_previo = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		red.oficina.jugador.radio_abierta = true
		_estaciones = false
		_construir_opciones()
		_panel.show()
		_ajustar()
		_botones[0].grab_focus()


func cerrar() -> void:
	if not is_instance_valid(_panel) or not _panel.visible: return
	_panel.hide()
	red.oficina.jugador.radio_abierta = false
	# A confirma el botón y también es saltar: consumirlo hasta que se suelte.
	red.oficina.jugador.esperar_soltar_salto_radio = Input.is_action_pressed(red.oficina.jugador.JUMP)
	var foco := get_viewport().gui_get_focus_owner()
	if foco != null and _panel.is_ancestor_of(foco): foco.release_focus()
	# Una pantalla que abre sobre la radio conserva su propio cursor.
	if not MenuGlobal.capa.visible and not red.oficina.partida_finalizada:
		Input.mouse_mode = _mouse_previo


func _construir_opciones() -> void:
	for hijo in _opciones.get_children():
		_opciones.remove_child(hijo)
		hijo.queue_free()
	_botones.clear()
	var titulo := Label.new()
	titulo.text = "SEÑALAR ESTACIÓN" if _estaciones else "RADIO DEL EQUIPO"
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_opciones.add_child(titulo)
	if _estaciones:
		for id: String in red.ESTACIONES_RADIO:
			_boton(str(red.ESTACIONES_RADIO[id]), enviar.bind("estacion", id))
		_boton("Volver", _volver)
	else:
		_boton("Marcar estación", _elegir_estacion)
		_boton("Necesito ayuda", enviar.bind("ayuda", ""))
		_boton("Recoge esta hoja", enviar.bind("hoja", ""))
		_boton("Voy a reparar", enviar.bind("reparar", ""))
		_boton("Cerrar · B" if ControladorInterfaz.dispositivo_mando >= 0 else "Cerrar · R / Esc", cerrar)
	for i in _botones.size():
		_botones[i].focus_neighbor_top = _botones[posmod(i - 1, _botones.size())].get_path()
		_botones[i].focus_neighbor_bottom = _botones[(i + 1) % _botones.size()].get_path()


func _boton(texto: String, accion: Callable) -> void:
	var boton := Button.new()
	boton.text = "%d · %s" % [_botones.size() + 1, texto]
	boton.custom_minimum_size = Vector2(310, 42)
	boton.add_theme_font_size_override("font_size", 18)
	boton.pressed.connect(accion)
	_opciones.add_child(boton)
	_botones.append(boton)


func _elegir_estacion() -> void:
	_estaciones = true
	_construir_opciones()
	_ajustar.call_deferred()
	_botones[0].grab_focus()


func _volver() -> void:
	_estaciones = false
	_construir_opciones()
	_ajustar.call_deferred()
	_botones[0].grab_focus()


func enviar(tipo: String, objetivo := "") -> void:
	if not disponible():
		cerrar()
		return
	cerrar()
	SesionLAN.solicitar("senal", {"tipo": tipo, "objetivo": objetivo})


func recibir(datos: Dictionary) -> void:
	var numero := int(datos.get("numero", 0))
	var id := int(datos.get("jugador", 0))
	if numero <= _ultimo_numero or not red.jugadores.has(id): return
	_ultimo_numero = numero
	marcas[id] = datos.duplicate()
	marcas[id]["restante"] = DURACION
	_sonido.play()
	queue_redraw()


func _input(evento: InputEvent) -> void:
	var abrir: bool = evento is InputEventKey and evento.pressed and not evento.echo and evento.physical_keycode == KEY_R
	if evento is InputEventJoypadButton and evento.device == ControladorInterfaz.dispositivo_mando:
		abrir = evento.pressed and evento.button_index == JOY_BUTTON_B
	if abrir and (disponible() or _panel.visible):
		get_viewport().set_input_as_handled()
		alternar()
		return
	if not _panel.visible: return
	if evento.is_action_pressed("Cancel"):
		get_viewport().set_input_as_handled()
		cerrar()
	elif evento is InputEventKey and evento.pressed and not evento.echo:
		var tecla: int = evento.physical_keycode if evento.physical_keycode != 0 else evento.keycode
		var indice := tecla - KEY_1
		if indice >= 0 and indice < _botones.size():
			get_viewport().set_input_as_handled()
			_botones[indice].pressed.emit()


func _process(delta: float) -> void:
	var habia_marcas := not marcas.is_empty()
	var activa := disponible()
	_abrir.visible = activa
	_abrir.text = "B · RADIO" if ControladorInterfaz.dispositivo_mando >= 0 else "R · RADIO"
	if _panel.visible and not activa: cerrar()
	if not get_tree().paused:
		for id: int in marcas.keys():
			marcas[id].restante -= delta
			if marcas[id].restante <= 0.0 or not red.despacho.esta_activo(id):
				marcas.erase(id)
	if habia_marcas: queue_redraw()


func _ajustar() -> void:
	_factor = clampf(minf(size.x / 1280.0, size.y / 720.0), .55, 1.5)
	_abrir.scale = Vector2.ONE * _factor
	_abrir.size = Vector2(125, 38)
	_abrir.position = Vector2(size.x * .5 - 62.5 * _factor, size.y - 54 * _factor)
	_panel.scale = Vector2.ONE * _factor
	_panel.size = _panel.get_combined_minimum_size()
	_panel.position = (size - _panel.size * _factor) * .5


func _draw() -> void:
	if get_tree().paused or red.oficina.partida_finalizada or MenuGlobal.capa.visible: return
	var camara := get_viewport().get_camera_3d()
	if camara == null: return
	for id: int in marcas:
		var dato: Dictionary = marcas[id]
		var punto: Vector3 = dato.posicion
		if dato.tipo == "ayuda": punto = red.jugadores[id].global_position
		if dato.tipo == "hoja":
			var papel = red.papeles.get(str(dato.caso))
			if not is_instance_valid(papel) or papel.portador != null: continue
			punto = papel.global_position
		punto.y += .8
		var destino := camara.unproject_position(punto)
		if camara.is_position_behind(punto):
			var direccion := (destino - size * .5).normalized()
			destino = size * .5 - direccion * size.length()
		var ancho := minf(300 * _factor, size.x - 24)
		var centro := Vector2(clampf(destino.x, ancho * .5 + 12, size.x - ancho * .5 - 12), clampf(destino.y, 100 * _factor, size.y - 145 * _factor))
		var color := Color("83e0ed") if id == 1 else Color("ffd28e")
		var caja := Rect2(centro - Vector2(ancho * .5, 27 * _factor), Vector2(ancho, 54 * _factor))
		draw_style_box(_estilo_marca(color), caja)
		var alias_jugador := str(SesionLAN.participantes.get(id, {}).get("alias", "Agente"))
		draw_string(FUENTE, caja.position + Vector2(10, 19) * _factor, alias_jugador, HORIZONTAL_ALIGNMENT_LEFT, ancho - 20 * _factor, roundi(14 * _factor), color)
		var simbolo := {"estacion": "[>]", "ayuda": "[!]", "hoja": "[=]", "reparar": "[+]"}
		draw_string(FUENTE, caja.position + Vector2(10, 40) * _factor, str(simbolo.get(dato.tipo, "[!]")) + " " + str(dato.texto), HORIZONTAL_ALIGNMENT_LEFT, ancho - 20 * _factor, roundi(16 * _factor), CREMA)
		var pie := Vector2(caja.get_center().x, caja.end.y)
		var direccion := (destino - centro).normalized() if destino.distance_to(centro) > 1.0 else Vector2.DOWN
		var mitad := caja.size * .5
		var distancia := 1.0 / maxf(absf(direccion.x) / mitad.x, absf(direccion.y) / mitad.y)
		pie = centro + direccion * distancia
		var lado := direccion.orthogonal() * 6 * _factor
		draw_colored_polygon(PackedVector2Array([pie - lado, pie + lado, pie + direccion * 8 * _factor]), color)


func _estilo_marca(color: Color) -> StyleBoxFlat:
	if _estilos.has(color): return _estilos[color]
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("102c3df2")
	estilo.border_color = color
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	_estilos[color] = estilo
	return estilo


func _exit_tree() -> void:
	if is_instance_valid(red) and is_instance_valid(red.oficina.jugador):
		red.oficina.jugador.radio_abierta = false
