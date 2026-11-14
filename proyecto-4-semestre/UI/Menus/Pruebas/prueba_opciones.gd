extends Node
## Audio y navegación de Opciones, sin ejercitar las mecánicas de la partida.

var _errores := 0
var _archivo_existia := false
var _contenido_original: PackedByteArray


func _ready() -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	call_deferred("_probar")


func _probar() -> void:
	_archivo_existia = FileAccess.file_exists(AjustesAccesibilidad.ARCHIVO)
	if _archivo_existia:
		_contenido_original = FileAccess.get_file_as_bytes(AjustesAccesibilidad.ARCHIVO)
	get_tree().current_scene = null
	get_tree().change_scene_to_file(MenuGlobal.ESCENA_MENU)
	await get_tree().scene_changed
	await _layout()
	MenuGlobal.abrir_opciones()
	await _layout()
	_probar_audio()
	for dimensiones: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1024, 768), Vector2i(1920, 1080)]:
		get_window().size = dimensiones
		await _layout()
		await _capturar("opciones", MenuGlobal.panel_opciones)
		MenuGlobal.get_node("%VolverOpciones").grab_focus()
		_tecla(KEY_TAB)
		await _layout()
		_verificar(MenuGlobal.control_volumen_general.has_focus(), "El ciclo de Opciones comienza en General")
		_tecla(KEY_TAB)
		await _layout()
		_verificar(MenuGlobal.control_volumen_musica.has_focus(), "El segundo control es Música")
		_tecla(KEY_TAB)
		await _layout()
		_verificar(MenuGlobal.control_volumen_interacciones.has_focus(), "El tercer control es Efectos de sonido")
		MenuGlobal.control_volumen_general.value = 0
		_clic(MenuGlobal.control_volumen_general)
		await _layout()
		_verificar(absf(MenuGlobal.control_volumen_general.value - 50) < 3, "El clic sobre General coincide con la barra escalada")
		var anterior := MenuGlobal.control_volumen_general.value
		_tecla(KEY_RIGHT)
		await _layout()
		_verificar(MenuGlobal.control_volumen_general.value > anterior, "General responde a las flechas")
		MenuGlobal.control_volumen_general.value = 76
		_clic(MenuGlobal.get_node("%AccesibilidadOpciones"))
		await _layout()
		_verificar(MenuGlobal.panel_accesibilidad.is_visible_in_tree(), "El ratón abre Accesibilidad")
		await _capturar("accesibilidad", MenuGlobal.panel_accesibilidad)
		MenuGlobal.get_node("%VolverAccesibilidad").grab_focus()
		_tecla(KEY_TAB)
		await _layout()
		_verificar(MenuGlobal.selector_filtro.has_focus(), "El foco permanece dentro de Accesibilidad")
		# Evita que el ratón de la acción anterior seleccione una fila al abrir la lista.
		var raton_fuera := InputEventMouseMotion.new()
		raton_fuera.position = Vector2(4, 4)
		raton_fuera.global_position = raton_fuera.position
		Input.parse_input_event(raton_fuera)
		_tecla(KEY_SPACE)
		await _layout()
		var lista := MenuGlobal.selector_filtro.get_popup()
		_verificar(lista.visible, "El desplegable de filtros abre con teclado")
		_tecla(KEY_DOWN, lista.get_window_id())
		await _layout()
		_tecla(KEY_ENTER, lista.get_window_id())
		await _layout()
		_verificar(MenuGlobal.selector_filtro.selected == 1 and not lista.visible, "El desplegable permite elegir Deuteranopia")
		MenuGlobal.control_intensidad.value = 65
		MenuGlobal.control_brillo.value = 80
		_clic(MenuGlobal.control_brillo)
		await _layout()
		_verificar(absf(MenuGlobal.control_brillo.value - 100) < 3, "El clic de Brillo coincide con su barra escalada")
		MenuGlobal.control_brillo.value = 113
		MenuGlobal.selector_balanceo.select(1)
		MenuGlobal.selector_balanceo.item_selected.emit(1)
		_tecla(KEY_ESCAPE)
		await _layout()
		_verificar(MenuGlobal.panel_opciones.is_visible_in_tree() and MenuGlobal.get_node("%AccesibilidadOpciones").has_focus(), "Esc devuelve el foco a Accesibilidad en Opciones")
		_clic(MenuGlobal.get_node("%ControlesOpciones"))
		await _layout()
		_verificar(MenuGlobal.panel_ayuda.leyenda.is_visible_in_tree() and MenuGlobal.panel_ayuda.leyenda.pagina_actual == 0, "Controles conserva su manual existente")
		_tecla(KEY_ESCAPE)
		await _layout()
		_verificar(MenuGlobal.panel_opciones.visible and MenuGlobal.get_node("%ControlesOpciones").has_focus(), "Volver del manual restaura su botón")
		AjustesAccesibilidad.restablecer()
	MenuGlobal.cerrar_opciones()
	await _layout()
	_verificar(not MenuGlobal.capa.visible and not get_tree().paused, "Volver desde Opciones regresa al menú principal")

	# Entrada directa a la oficina: el tutorial inicial conserva la partida pausada.
	AjustesAccesibilidad.establecer_modo(2)
	AjustesAccesibilidad.establecer_intensidad(0.65)
	AjustesAccesibilidad.establecer_brillo(1.13)
	get_tree().change_scene_to_file(MenuGlobal.ESCENA_JUEGO)
	await get_tree().scene_changed
	for cuadro: int in range(40):
		await get_tree().process_frame
	if MenuGlobal.panel_ayuda.visible:
		MenuGlobal.cerrar_ayuda()
	MenuGlobal.abrir_pausa()
	MenuGlobal.abrir_opciones()
	await _layout()
	_verificar(get_tree().paused and MenuGlobal.panel_opciones.is_visible_in_tree(), "Opciones se abre desde la pausa real")
	_verificar(MenuGlobal.control_volumen_general.value == 76 and MenuGlobal.control_volumen_musica.value == 42 and MenuGlobal.control_volumen_interacciones.value == 63, "La pausa comparte los tres volúmenes del menú")
	MenuGlobal.control_volumen_general.value = 58
	MenuGlobal.abrir_accesibilidad()
	await _layout()
	_verificar(MenuGlobal.selector_filtro.selected == 2 and MenuGlobal.control_brillo.value == 113, "Accesibilidad comparte filtro y brillo desde la pausa")
	_clic(MenuGlobal.get_node("%Restablecer"))
	await _layout()
	_verificar(AjustesAccesibilidad.modo == 0 and AjustesAccesibilidad.brillo == 1 and not MenuGlobal.filtro_pantalla.visible, "Restablecer deja la imagen neutra")
	_verificar(MenuGlobal.control_volumen_general.value == 58, "Restablecer no modifica el audio")
	await _capturar("accesibilidad_pausa", MenuGlobal.panel_accesibilidad)
	_tecla(KEY_ESCAPE)
	await _layout()
	await _capturar("opciones_pausa", MenuGlobal.panel_opciones)
	_tecla(KEY_ESCAPE)
	await _layout()
	_verificar(MenuGlobal.panel_pausa.visible and get_tree().paused, "Esc desde Opciones vuelve a Pausa")
	MenuGlobal.volver_al_menu()
	await get_tree().scene_changed
	await _layout()
	MenuGlobal.abrir_opciones()
	_verificar(MenuGlobal.control_volumen_general.value == 58, "El menú principal recibe el cambio de audio hecho en pausa")
	MenuGlobal.cerrar_opciones()
	AjustesAccesibilidad.guardar()
	if _archivo_existia:
		var archivo := FileAccess.open(AjustesAccesibilidad.ARCHIVO, FileAccess.WRITE)
		archivo.store_buffer(_contenido_original)
		archivo.close()
	else:
		DirAccess.remove_absolute(AjustesAccesibilidad.ARCHIVO)
	print("PRUEBA OPCIONES: %d errores" % _errores)
	get_tree().quit(0 if _errores == 0 else 1)


func _probar_audio() -> void:
	var general := AudioServer.get_bus_index(&"Master")
	var musica := AudioServer.get_bus_index(AjustesAccesibilidad.BUS_MUSICA)
	var efectos := AudioServer.get_bus_index(AjustesAccesibilidad.BUS_INTERACCIONES)
	MenuGlobal.control_volumen_general.value = 76.0
	MenuGlobal.control_volumen_musica.value = 42.0
	MenuGlobal.control_volumen_interacciones.value = 63.0
	_verificar(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(general)), 0.76), "General modifica el volumen maestro")
	_verificar(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(musica)), 0.42) and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(efectos)), 0.63), "Música y efectos conservan niveles independientes")
	_verificar(AudioServer.get_bus_send(musica) == &"Master" and AudioServer.get_bus_send(efectos) == &"Master", "General controla la salida de música y efectos")
	MenuGlobal.control_volumen_general.value = 0.0
	_verificar(AudioServer.is_bus_mute(general) and not AudioServer.is_bus_mute(musica) and not AudioServer.is_bus_mute(efectos), "General en cero silencia la salida sin borrar los ajustes individuales")
	MenuGlobal.control_volumen_general.value = 76.0
	MenuGlobal.control_volumen_musica.value = 0.0
	_verificar(AudioServer.is_bus_mute(musica) and not AudioServer.is_bus_mute(efectos) and not AudioServer.is_bus_mute(general), "Silenciar Música conserva los efectos")
	MenuGlobal.control_volumen_musica.value = 42.0
	MenuGlobal.control_volumen_interacciones.value = 0.0
	_verificar(AudioServer.is_bus_mute(efectos) and not AudioServer.is_bus_mute(musica), "Silenciar Efectos conserva la música")
	MenuGlobal.control_volumen_interacciones.value = 63.0
	AjustesAccesibilidad.guardar()
	var config := ConfigFile.new()
	_verificar(config.load(AjustesAccesibilidad.ARCHIVO) == OK and is_equal_approx(config.get_value("audio", "general", -1.0), 0.76), "Se guarda el volumen General")
	# Los archivos anteriores conservan sus dos volúmenes y estrenan General al 100 %.
	config.erase_section_key("audio", "general")
	config.save(AjustesAccesibilidad.ARCHIVO)
	AjustesAccesibilidad.cargar()
	_verificar(MenuGlobal.control_volumen_general.value == 100.0 and MenuGlobal.control_volumen_musica.value == 42.0 and MenuGlobal.control_volumen_interacciones.value == 63.0, "Los ajustes de audio anteriores se recuperan sin perder sus niveles")
	MenuGlobal.control_volumen_general.value = 76.0
	AjustesAccesibilidad.guardar()
	AjustesAccesibilidad.volumen_general = 1.0
	AjustesAccesibilidad.cargar()
	_verificar(MenuGlobal.control_volumen_general.value == 76.0 and not AudioServer.is_bus_mute(general), "General se recupera del disco y vuelve a sonar")
	AjustesAccesibilidad.restablecer()
	_verificar(MenuGlobal.control_volumen_general.value == 76.0 and MenuGlobal.control_volumen_musica.value == 42.0 and MenuGlobal.control_volumen_interacciones.value == 63.0, "Restablecer Accesibilidad conserva los tres ajustes de audio")



func _layout() -> void:
	for cuadro: int in range(8):
		await get_tree().process_frame


func _tecla(codigo: Key, ventana: int = 0) -> void:
	for pulsada: bool in [true, false]:
		var evento := InputEventKey.new()
		evento.keycode = codigo
		evento.physical_keycode = codigo
		evento.pressed = pulsada
		evento.window_id = ventana
		Input.parse_input_event(evento)


func _clic(control: Control) -> void:
	var centro := control.get_global_rect().get_center()
	var movimiento := InputEventMouseMotion.new()
	movimiento.position = centro
	movimiento.global_position = centro
	Input.parse_input_event(movimiento)
	for pulsado: bool in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.position = centro
		evento.global_position = centro
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.pressed = pulsado
		Input.parse_input_event(evento)


func _capturar(nombre: String, panel: Control) -> void:
	var pantalla := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	_verificar(pantalla.encloses(panel.get_global_rect()), "Panel completo dentro de %s: %s" % [pantalla.size, nombre])
	for boton: Control in [MenuGlobal.get_node("%VolverOpciones"), MenuGlobal.get_node("%VolverAccesibilidad")]:
		if boton.is_visible_in_tree():
			_verificar(pantalla.encloses(boton.get_global_rect()), "Volver siempre visible")
	if DisplayServer.get_name() == "headless" or not "--capturas" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var carpeta := "res://.godot/opciones_qa"
	DirAccess.make_dir_recursive_absolute(carpeta)
	get_viewport().get_texture().get_image().save_png(carpeta.path_join("%s_%dx%d.png" % [nombre, pantalla.size.x, pantalla.size.y]))


func _verificar(condicion: bool, descripcion: String) -> void:
	if condicion:
		print("OK: ", descripcion)
	else:
		_errores += 1
		push_error("FALLO: " + descripcion)
