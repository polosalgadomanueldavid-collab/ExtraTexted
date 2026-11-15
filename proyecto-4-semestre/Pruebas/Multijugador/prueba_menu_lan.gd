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
