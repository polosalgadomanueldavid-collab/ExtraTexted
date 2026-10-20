extends Node
## Ejecutar esta escena con --capturas para guardar también la revisión visual.

var _errores: int = 0


func _ready() -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	call_deferred("_probar")


func _probar() -> void:
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://MainMenu.tscn")
	await get_tree().scene_changed
	await _esperar_layout()
	var menu := get_tree().current_scene
	var titulo: TextureRect = menu.get_node("CenterContainer/MenuPanel/VBoxContainer/Title")
	_verificar(titulo.texture.resource_path.ends_with("extra_texted_logo.png"), "El título utiliza el logo transparente aprobado")
	var botones := menu.get_node("CenterContainer/MenuPanel/VBoxContainer/MenuButtons")
	var jugar: Button = botones.get_node("PlayButton")
	var opciones: Button = botones.get_node("OptionsButton")
	var salir: Button = botones.get_node("QuitButton")
	_verificar(jugar.has_focus(), "El foco inicial está en Jugar")
	await _capturar("01_menu_1280x720")
	_tecla(KEY_DOWN)
	await get_tree().process_frame
	_verificar(opciones.has_focus(), "Flecha abajo selecciona Opciones")
	_tecla(KEY_TAB)
	await get_tree().process_frame
	_verificar(salir.has_focus(), "Tab selecciona Salir")
	_tecla(KEY_DOWN)
	await get_tree().process_frame
	_verificar(jugar.has_focus(), "La navegación cierra el ciclo sin perder el foco")
	var centro := opciones.get_global_rect().get_center()
	var movimiento := InputEventMouseMotion.new()
	movimiento.position = centro
	movimiento.global_position = centro
	Input.parse_input_event(movimiento)
	await get_tree().create_timer(0.15).timeout
	_verificar(opciones.has_focus() and opciones.scale.x > 1.0, "El ratón selecciona y resalta el botón correcto")
	await _capturar("02_opciones_resaltado")
	_clic(centro, true)
	await get_tree().create_timer(0.15).timeout
	_verificar(opciones.is_pressed() and opciones.scale.x < 1.0, "Pulsar hunde el botón")
	await _capturar("03_opciones_pulsado")
	_clic(centro, false)
	await get_tree().process_frame
	_verificar(MenuGlobal.panel_opciones.visible, "El clic abre las opciones reales")
	MenuGlobal.cerrar_opciones()
	await get_tree().process_frame
	_verificar(opciones.has_focus(), "Cerrar Opciones restaura el foco del menú")
	for dimensiones: Vector2i in [Vector2i(1920, 1080), Vector2i(960, 540), Vector2i(1024, 768)]:
		get_window().size = dimensiones
		await _esperar_layout()
		var pantalla := Rect2(Vector2.ZERO, menu.size)
		var panel: Control = menu.get_node("CenterContainer/MenuPanel")
		_verificar(pantalla.encloses(panel.get_global_rect()), "Panel completo dentro de %s" % dimensiones)
		for boton: Button in [jugar, opciones, salir]:
			_verificar(pantalla.encloses(boton.get_global_rect()), "Botón %s visible en %s" % [boton.text, dimensiones])
		await _capturar("04_menu_%dx%d" % [dimensiones.x, dimensiones.y])
	print("PRUEBA MENU PILOTO: %d errores" % _errores)
	get_tree().quit(0 if _errores == 0 else 1)


func _esperar_layout() -> void:
	for cuadro: int in range(5):
		await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout


func _tecla(codigo: Key) -> void:
	var evento := InputEventKey.new()
	evento.keycode = codigo
	evento.physical_keycode = codigo
	evento.pressed = true
	Input.parse_input_event(evento)
	var soltar := evento.duplicate() as InputEventKey
	soltar.pressed = false
	Input.parse_input_event(soltar)


func _clic(posicion: Vector2, pulsado: bool) -> void:
	var evento := InputEventMouseButton.new()
	evento.position = posicion
	evento.global_position = posicion
	evento.button_index = MOUSE_BUTTON_LEFT
	evento.pressed = pulsado
	Input.parse_input_event(evento)


func _capturar(nombre: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--capturas" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var directorio := "res://.godot/piloto_qa"
	DirAccess.make_dir_recursive_absolute(directorio)
	get_viewport().get_texture().get_image().save_png(directorio.path_join(nombre + ".png"))


func _verificar(condicion: bool, descripcion: String) -> void:
	if condicion:
		print("OK: ", descripcion)
	else:
		_errores += 1
		push_error("FALLO: " + descripcion)
