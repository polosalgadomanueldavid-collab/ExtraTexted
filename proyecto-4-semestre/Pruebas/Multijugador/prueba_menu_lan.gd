extends SceneTree

func _initialize() -> void:
	_probar.call_deferred()

func _probar() -> void:
	var menu: Control = load("res://UI/Menus/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await create_timer(1.0).timeout
	menu.play_button.pressed.emit()
	await process_frame
	var sesion: Node = root.get_node("SesionLAN")
	if "--sala-host" in OS.get_cmdline_user_args() or "--sala-client" in OS.get_cmdline_user_args():
		await _probar_sala_real(menu, sesion)
		return
	assert(menu.panel_lan.fondo.visible)
	assert(sesion.unirse("direccion incorrecta", "Prueba") == ERR_INVALID_PARAMETER)
	assert(not sesion.activa)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/lan_menu.png")
	menu.panel_lan.alias_jugador.text = "Anfitrión"
	menu.panel_lan.crear.pressed.emit()
	assert(sesion.activa and sesion.participantes.size() == 1)
	await process_frame
	assert(not menu.panel_lan.iniciar.visible or menu.panel_lan.iniciar.disabled)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/lan_sala.png")
	menu.panel_lan.cerrar()
	await process_frame
	assert(not sesion.activa)
	assert(sesion.crear("Otra sala") == OK)
	assert(sesion.ronda == 0 and sesion.participantes.size() == 1)
	sesion.cerrar()
	await process_frame
	print("[MENU LAN] IP inválida, sala, salida y nueva sesión: OK")
	quit()

func _probar_sala_real(menu: Control, sesion: Node) -> void:
	var anfitrion := "--sala-host" in OS.get_cmdline_user_args()
	var sala: CanvasLayer = menu.panel_lan
	sala.alias_jugador.text = "Anfitrión" if anfitrion else "Compañero"
	if anfitrion:
		sala.crear.pressed.emit()
	else:
		await create_timer(0.7).timeout
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
	assert(sala._tarjetas[0].nombre.text == "Anfitrión" and sala._tarjetas[1].nombre.text == "Compañero")
	sala.listo.button_pressed = true
	while sala._plazas.text != "2 / 2 LISTOS" and Time.get_ticks_msec() < limite:
		await create_timer(0.1).timeout
	assert(sala._plazas.text == "2 / 2 LISTOS")
	assert(sala.iniciar.disabled != anfitrion)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/lan_sala_%s.png" % ("host" if anfitrion else "client"))
		# Comprobar la composición a una resolución menor sin cambiar ajustes guardados.
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(960, 540))
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/lan_sala_%s_compacta.png" % ("host" if anfitrion else "client"))
	await create_timer(1.0 if anfitrion else 1.5).timeout
	sala.cerrar()
	await create_timer(0.3).timeout
	assert(not sesion.activa)
	root.get_node("MenuGlobal").musica_menu.stop()
	await create_timer(0.3).timeout
	print("[SALA VISUAL LAN] Dos fichas, ambos listos, inicio solo del anfitrión y salida: OK")
	quit()
