extends SceneTree

const CAPTURAS := "res://output/multijugador_implementado/"

func _initialize() -> void:
	_probar.call_deferred()

func _probar() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var menu: Control = load("res://UI/Menus/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await create_timer(1.2).timeout
	menu.play_button.pressed.emit()
	await process_frame
	var sesion: Node = root.get_node("SesionLAN")
	if "--sala-host" in OS.get_cmdline_user_args() or "--sala-client" in OS.get_cmdline_user_args():
		await _probar_sala_real(menu, sesion)
		return
	var sala: CanvasLayer = menu.panel_lan
	assert(sala.fondo.visible and sala.individual.is_visible_in_tree())
	assert(sala.alias_jugador.has_focus() and not sala.direccion.is_visible_in_tree())
	sala.alias_jugador.text = "Andrés"
	_tecla(KEY_TAB)
	await process_frame
	assert(sala.crear.has_focus(), "Tab evita los controles ocultos de Unirse")
	await _capturar("01_multijugador")
	await _clic(sala._elegir_unirse)
	assert(sala.direccion.is_visible_in_tree() and not sala.crear.is_visible_in_tree())
	assert(sala.direccion.has_focus())
	sala.direccion.text = "192.168.1.10"
	await _capturar("02_unirse")
	sala.direccion.text = "direccion incorrecta"
	await _clic(sala.unir)
	assert(not sesion.activa)
	assert(sala.estado.visible and sala.estado.text == "Escribe una IP válida.")
	assert(sala.alias_jugador.text == "Andrés" and sala.direccion.text == "direccion incorrecta")
	await _capturar("05_ip_invalida")
	_tecla(KEY_ESCAPE)
	await process_frame
	assert(sala.fondo.visible and sala.crear.is_visible_in_tree(), "Escape vuelve al selector, no cierra el panel")
	await _clic(sala._elegir_unirse)
	assert(sala.direccion.text == "direccion incorrecta")
	sala.direccion.text = "127.0.0.1"
	sala.unir.pressed.emit()
	assert(sesion.activa and sala.unir.disabled and sala.unir.text == "Conectando…")
	assert(sala._volver.has_focus() and not sala._sala.visible)
	sala._volver.pressed.emit()
	await process_frame
	await process_frame
	assert(not sesion.activa and sala._vista_unirse and sala.unir.is_visible_in_tree())
	assert(sala.alias_jugador.editable and sala.direccion.editable)
	sala._volver.pressed.emit()
	await _clic(sala.crear)
	assert(sesion.activa and sesion.participantes.size() == 1)
	await process_frame
	assert(sala.iniciar.disabled and sala._plazas.text == "1/2")
	assert(sala._tarjetas[1].silueta.visible and not sala._tarjetas[1].foto.visible)
	await _capturar("03_sala_esperando")
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD) and not sala._copiar.disabled:
		var anterior := DisplayServer.clipboard_get()
		await _clic(sala._copiar)
		var copiada := DisplayServer.clipboard_get()
		DisplayServer.clipboard_set(anterior)
		assert(copiada == sala._ip and sala._copiar.text == "Copiada")
	await _clic(sala.listo)
	assert(sesion.participantes[1].listo and sala.iniciar.disabled)
	await _clic(sala.listo)
	assert(not sesion.participantes[1].listo)
	await _comprobar_tamanos(sala, "esperando")
	sala.cerrar()
	await process_frame
	assert(not sesion.activa)
	assert(sesion.crear("Otra sala") == OK)
	assert(sesion.ronda == 0 and sesion.participantes.size() == 1)
	assert(sala._copiar.text == "Copiar", "La nueva sala restablece la confirmación de copia")
	sesion.cerrar()
	await process_frame
	print("[MENU LAN] Navegación, IP inválida, cancelación, datos conservados, sala, listo, escalado y nueva sesión: OK")
	root.get_node("MenuGlobal").musica_menu.stop()
	await create_timer(0.3).timeout
	quit()

func _probar_sala_real(menu: Control, sesion: Node) -> void:
	var anfitrion := "--sala-host" in OS.get_cmdline_user_args()
	var sala: CanvasLayer = menu.panel_lan
	sala.alias_jugador.text = "Andrés" if anfitrion else "Luna"
	if anfitrion:
		sala.crear.pressed.emit()
	else:
		await create_timer(0.7).timeout
		sala._elegir_unirse.pressed.emit()
		sala.direccion.text = "127.0.0.1"
		sala.unir.pressed.emit()
	var limite := Time.get_ticks_msec() + 20000
	while sesion.participantes.size() < 2 and Time.get_ticks_msec() < limite:
		await create_timer(0.1).timeout
	if sesion.participantes.size() != 2:
		push_error("La sala visual no pudo conectar ambos equipos")
		quit(1)
		return
	assert(sala._sala.visible and not sala._conexion.visible)
	assert(sala._tarjetas[0].nombre.text == "Andrés" and sala._tarjetas[1].nombre.text == "Luna")
	assert(sala._tarjetas[0].retrato.texture.resource_path == "res://UI/Despacho/retrato_policia.png")
	assert(sala._tarjetas[1].retrato.texture.resource_path == "res://UI/Despacho/retrato_policia_relevo.png")
	assert(sala._tarjetas[0 if anfitrion else 1].rol.text.begins_with("Tú · "))
	assert(sala.iniciar.disabled, "No se puede iniciar sin confirmar ambos jugadores")
	sala.listo.button_pressed = true
	while not sesion.participantes.values().all(func(j): return j.listo) and Time.get_ticks_msec() < limite:
		await create_timer(0.1).timeout
	assert(sesion.participantes.values().all(func(j): return j.listo))
	assert(sala._plazas.text == "2/2")
	assert(sala.iniciar.is_visible_in_tree() == anfitrion)
	assert(sala.iniciar.disabled != anfitrion)
	if anfitrion: assert(not sala.iniciar.disabled)
	else: assert(sala._ayuda_inicio.text == "Esperando al anfitrión")
	if anfitrion:
		sala.listo.button_pressed = false
		assert(sala.iniciar.disabled, "Retirar la confirmación vuelve a bloquear el inicio")
		sala.listo.button_pressed = true
		assert(not sala.iniciar.disabled)
	await _capturar("04_sala_lista" if anfitrion else "06_sala_invitado")
	await _comprobar_tamanos(sala, "host" if anfitrion else "client")
	await create_timer(1.0 if anfitrion else 1.5).timeout
	sala.cerrar()
	await create_timer(0.3).timeout
	assert(not sesion.activa)
	root.get_node("MenuGlobal").musica_menu.stop()
	await create_timer(0.3).timeout
	print("[SALA VISUAL LAN] Dos fichas, ambos listos, inicio solo del anfitrión y salida: OK")
	quit()


func _capturar(nombre: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(CAPTURAS)
	root.get_texture().get_image().save_png(CAPTURAS + nombre + ".png")


func _comprobar_tamanos(sala: CanvasLayer, nombre: String) -> void:
	for dimensiones in [Vector2i(960, 540), Vector2i(1024, 768), Vector2i(1920, 1080)]:
		root.size = dimensiones
		await create_timer(0.15).timeout
		var pantalla := Rect2(Vector2.ZERO, Vector2(root.size))
		assert(pantalla.encloses(sala.panel.get_global_rect()), "El panel cabe en la ventana")
		for control in sala._lienzo.find_children("*", "Control", true, false):
			if control.is_visible_in_tree() and (control is Button or control is LineEdit):
				assert(pantalla.encloses(control.get_global_rect()), "Control completo: " + str(control.text))
		await _capturar("tamano_%s_%dx%d" % [nombre, dimensiones.x, dimensiones.y])
	root.size = Vector2i(1280, 720)
	await process_frame


func _tecla(codigo: Key) -> void:
	var evento := InputEventKey.new()
	evento.keycode = codigo
	evento.physical_keycode = codigo
	evento.pressed = true
	Input.parse_input_event(evento)
	var soltar := evento.duplicate() as InputEventKey
	soltar.pressed = false
	Input.parse_input_event(soltar)


func _clic(control: Control) -> void:
	var punto := control.get_global_rect().get_center()
	var movimiento := InputEventMouseMotion.new()
	movimiento.position = punto
	movimiento.global_position = punto
	Input.parse_input_event(movimiento)
	for pulsado in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.position = punto
		evento.global_position = punto
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.pressed = pulsado
		Input.parse_input_event(evento)
		await process_frame
