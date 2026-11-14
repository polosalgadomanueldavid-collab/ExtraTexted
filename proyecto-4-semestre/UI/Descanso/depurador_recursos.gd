extends CanvasLayer
## Depurador temporal de recursos; solo se instancia en compilaciones de desarrollo.

var oficina: Node3D
var panel: PanelContainer
var cantidad_dano: SpinBox
var cantidad_puntos: SpinBox
var boton_dano: Button
var boton_puntos: Button
var _resumen: Label
var _fondo: ColorRect
var _raton_anterior: Input.MouseMode
var _bloqueo_anterior := false


func configurar(gestor: Node3D) -> void:
	oficina = gestor
	layer = 80
	_fondo = ColorRect.new()
	_fondo.color = Color(0, 0, 0, 0.38)
	add_child(_fondo)
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.name = "DepuradorVidaPuntos"
	panel.theme = oficina.panel_despacho.theme
	add_child(panel)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("173b50")
	estilo.border_color = Color("ffc969")
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(12)
	estilo.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", estilo)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 16)
	panel.add_child(columna)
	var titulo := Label.new()
	titulo.text = "DEPURADOR TEMPORAL · VIDA Y PUNTOS"
	titulo.add_theme_font_size_override("font_size", 20)
	columna.add_child(titulo)
	_resumen = Label.new()
	columna.add_child(_resumen)
	cantidad_dano = _cantidad(columna, "Vida / calma que quieres quitar", 10, 100)
	boton_dano = _boton(columna, "Quitar vida", quitar_vida)
	cantidad_puntos = _cantidad(columna, "Puntos que quieres añadir al saldo", 500, 1000000000)
	boton_puntos = _boton(columna, "Añadir puntos", dar_puntos)
	_boton(columna, "Cerrar · Esc / F4", cerrar)
	get_viewport().size_changed.connect(_ajustar)
	oficina.sistema_despacho.calma_actualizada.connect(_actualizar.unbind(1))
	oficina.sistema_despacho.puntuacion.puntos_actualizados.connect(_actualizar.unbind(1))
	oficina.sistema_despacho.partida_terminada.connect(cerrar)
	oficina.jugador.reset_performed.connect(cerrar)
	hide()
	_ajustar.call_deferred()


func _cantidad(columna: VBoxContainer, texto: String, valor: int, maximo: int) -> SpinBox:
	var etiqueta := Label.new()
	etiqueta.text = texto
	columna.add_child(etiqueta)
	var numero := SpinBox.new()
	numero.min_value = 1
	numero.max_value = maximo
	numero.step = 1
	numero.value = valor
	numero.custom_minimum_size.y = 42
	numero.get_line_edit().select_all_on_focus = true
	columna.add_child(numero)
	return numero


func _boton(columna: VBoxContainer, texto: String, accion: Callable) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size.y = 42
	boton.pressed.connect(accion)
	columna.add_child(boton)
	return boton


func abrir() -> void:
	if visible or not OS.is_debug_build() or not oficina.depurador_grafo.visible_debug:
		return
	if get_tree().paused or oficina.partida_finalizada or oficina.jugador.input_locked or MenuGlobal.capa.visible:
		return
	_bloqueo_anterior = oficina.jugador.input_locked
	_raton_anterior = Input.mouse_mode
	oficina.jugador.input_locked = true
	oficina.jugador.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_actualizar()
	show()
	_ajustar()
	cantidad_puntos.get_line_edit().grab_focus()


func cerrar() -> void:
	if not visible:
		return
	hide()
	if is_instance_valid(oficina) and is_instance_valid(oficina.jugador):
		if not oficina.partida_finalizada:
			oficina.jugador.input_locked = _bloqueo_anterior
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if oficina.partida_finalizada else _raton_anterior
	if is_instance_valid(panel) and panel.is_inside_tree():
		var foco := panel.get_viewport().gui_get_focus_owner()
		if foco != null and panel.is_ancestor_of(foco):
			foco.release_focus()


func quitar_vida() -> void:
	if not _puede_aplicar():
		return
	cantidad_dano.apply()
	oficina.sistema_despacho.perder_calma(int(cantidad_dano.value), &"debug")


func dar_puntos() -> void:
	if not _puede_aplicar():
		return
	cantidad_puntos.apply()
	oficina.sistema_despacho.puntuacion.sumar_puntos_debug(int(cantidad_puntos.value))


func _puede_aplicar() -> bool:
	return OS.is_debug_build() and visible and oficina.depurador_grafo.visible_debug and not get_tree().paused and not oficina.sistema_despacho.terminada and not MenuGlobal.capa.visible


func _actualizar() -> void:
	_resumen.text = "Vida / calma: %d / 100     ·     Saldo: %d pts" % [oficina.sistema_despacho.calma_operativa, oficina.sistema_despacho.puntuacion.puntos]


func _ajustar() -> void:
	if not is_instance_valid(panel):
		return
	var tamano := get_viewport().get_visible_rect().size
	panel.size = Vector2(520, 0)
	panel.reset_size()
	var factor := minf(1.0, minf((tamano.x - 32) / panel.size.x, (tamano.y - 32) / panel.size.y))
	panel.scale = Vector2.ONE * factor
	panel.position = (tamano - panel.size * factor) * 0.5


func _input(evento: InputEvent) -> void:
	if not visible or not evento is InputEventKey or not evento.pressed or evento.echo:
		return
	var tecla: int = evento.physical_keycode if evento.physical_keycode != 0 else evento.keycode
	if tecla in [KEY_ESCAPE, KEY_F4]:
		cerrar()
		get_viewport().set_input_as_handled()
	elif tecla == KEY_F3:
		cerrar()


func _exit_tree() -> void:
	cerrar()


func _unhandled_input(_evento: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()
