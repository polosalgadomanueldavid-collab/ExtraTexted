extends Node

var _errores: int = 0
var _archivo_existia: bool
var _contenido_original: PackedByteArray
var _aperturas_pc: int = 0


func _ready() -> void:
	if "--compacto" in OS.get_cmdline_user_args():
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = Vector2i(960, 540)
	call_deferred("_probar")


func _probar() -> void:
	_archivo_existia = FileAccess.file_exists(AjustesAccesibilidad.ARCHIVO)
	if _archivo_existia:
		_contenido_original = FileAccess.get_file_as_bytes(AjustesAccesibilidad.ARCHIVO)
	# El ejecutor permanece vivo mientras se sustituyen las escenas de la partida.
	get_tree().current_scene = null
	get_tree().change_scene_to_file(MenuGlobal.ESCENA_MENU)
	await get_tree().scene_changed
	await get_tree().process_frame
	var menu := get_tree().current_scene
	menu.get_node("CenterContainer/MenuPanel/VBoxContainer/MenuButtons/OptionsButton").pressed.emit()
	await _capturar("01_opciones_menu")
	_verificar(MenuGlobal.panel_opciones.visible and not get_tree().paused, "Opciones desde el menu principal")
	MenuGlobal.get_node("%VolverOpciones").grab_focus()
	_pulsar_tecla(KEY_TAB)
	await get_tree().process_frame
	_verificar(MenuGlobal.selector_filtro.has_focus(), "Tab permanece dentro de las opciones")
	_pulsar_tecla(KEY_TAB, true)
	await get_tree().process_frame
	_verificar(MenuGlobal.get_node("%VolverOpciones").has_focus(), "Shift+Tab permanece dentro de las opciones")
	MenuGlobal.control_brillo.value = 80.0
	_clic_control(MenuGlobal.control_brillo)
	await get_tree().process_frame
	_verificar(absf(MenuGlobal.control_brillo.value - 100.0) < 3.0, "El clic coincide con el deslizador de brillo escalado")
	var brillo_con_raton := MenuGlobal.control_brillo.value
	_pulsar_tecla(KEY_RIGHT)
	await get_tree().process_frame
	_verificar(MenuGlobal.control_brillo.value > brillo_con_raton, "El brillo también responde al teclado")
	MenuGlobal.selector_filtro.grab_focus()
	_pulsar_tecla(KEY_SPACE)
	await get_tree().process_frame
	var lista := MenuGlobal.selector_filtro.get_popup()
	_verificar(lista.visible, "El selector abre la lista de filtros")
	if lista.visible:
		if DisplayServer.get_name() != "headless" and "--capturas" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			lista.get_texture().get_image().save_png("res://.godot/lista_filtros_qa.png")
		_pulsar_tecla(KEY_DOWN, false, lista.get_window_id())
		_pulsar_tecla(KEY_ENTER, false, lista.get_window_id())
		await get_tree().process_frame
		_verificar(not lista.visible and MenuGlobal.selector_filtro.selected == 1, "Se puede elegir un filtro con el teclado")
	MenuGlobal.control_brillo.value = 113.0
	MenuGlobal.selector_filtro.select(2)
	MenuGlobal.selector_filtro.item_selected.emit(2)
	MenuGlobal.control_intensidad.value = 65.0
	_verificar(is_equal_approx(AjustesAccesibilidad.brillo, 1.13), "El control de brillo actualiza el estado compartido")
	_verificar(AjustesAccesibilidad.modo == 2 and MenuGlobal.filtro_pantalla.visible, "El filtro queda activado")
	MenuGlobal.cerrar_opciones()
	var config := ConfigFile.new()
	_verificar(config.load(AjustesAccesibilidad.ARCHIVO) == OK, "Se guardan los ajustes")
	_verificar(config.get_value("accesibilidad", "modo", -1) == 2, "Se conserva el modo elegido")
	AjustesAccesibilidad.modo = 0
	AjustesAccesibilidad.brillo = 1.0
	AjustesAccesibilidad.cargar()
	_verificar(AjustesAccesibilidad.modo == 2 and is_equal_approx(AjustesAccesibilidad.brillo, 1.13), "Se recuperan los ajustes del disco")
	menu.get_node("CenterContainer/MenuPanel/VBoxContainer/MenuButtons/PlayButton").pressed.emit()
	await get_tree().scene_changed
	await get_tree().process_frame
	await get_tree().process_frame
	var oficina := get_tree().current_scene
	var jugador := oficina.get_node("Gameplay/Node3D") as Player
	var pc := oficina.get_node("Computer") as PCStatic
	var sistema: SistemaDespacho = oficina.sistema_despacho
	var denuncia := (load("res://Casos/Despacho/denuncia_uso_excesivo.tres") as Denuncia).duplicate(true) as Denuncia
	denuncia.id = "prueba-pausa"
	sistema.recibir_denuncia(denuncia)
	oficina._cambiar_bloqueo_temporal()
	oficina.temporizador_bloqueos.start()
	_pulsar_escape()
	await get_tree().process_frame
	_verificar(get_tree().paused and MenuGlobal.panel_pausa.visible, "ESC abre la pausa en la oficina")
	var repetido := InputEventKey.new()
	repetido.physical_keycode = KEY_ESCAPE
	repetido.keycode = KEY_ESCAPE
	repetido.pressed = true
	repetido.echo = true
	Input.parse_input_event(repetido)
	await get_tree().process_frame
	_verificar(get_tree().paused, "Mantener ESC no alterna la pausa")
	await _capturar("02_pausa_oficina")
	var tiempo_denuncia := sistema.obtener_tiempo_restante(denuncia.id)
	var tiempo_llegada: float = oficina.temporizador_denuncias.time_left
	var tiempo_bloqueo: float = oficina.temporizador_bloqueos.time_left
	var posicion := jugador.global_position
	var calma := sistema.calma_operativa
	var celda_bloqueo: Vector2i = oficina.bloqueo_temporal_actual
	var cajon: Node3D = oficina.bloqueo_visual_actual.get_node("Diseño_Cajon")
	var posicion_cajon := cajon.position
	await get_tree().create_timer(0.3).timeout
	_verificar(is_equal_approx(tiempo_denuncia, sistema.obtener_tiempo_restante(denuncia.id)), "No vence la denuncia durante la pausa")
	_verificar(is_equal_approx(tiempo_llegada, oficina.temporizador_denuncias.time_left), "No avanza la llegada de denuncias")
	_verificar(is_equal_approx(tiempo_bloqueo, oficina.temporizador_bloqueos.time_left), "No avanza el temporizador de bloqueos")
	_verificar(jugador.global_position.is_equal_approx(posicion) and sistema.calma_operativa == calma, "Se conservan posicion y calma")
	_verificar(oficina.bloqueo_temporal_actual == celda_bloqueo and cajon.position.is_equal_approx(posicion_cajon), "El bloqueo y su animacion quedan congelados")
	MenuGlobal.reanudar.grab_focus()
	_pulsar_tecla(KEY_TAB)
	await get_tree().process_frame
	_verificar(MenuGlobal.get_node("%OpcionesPausa").has_focus(), "Tab selecciona Opciones en la pausa")
	_clic_control(MenuGlobal.get_node("%OpcionesPausa"))
	await get_tree().process_frame
	_verificar(MenuGlobal.panel_opciones.visible and get_tree().paused, "El clic coincide con el botón escalado de la pausa")
	await _capturar("03_opciones_pausa")
	_verificar(is_equal_approx(MenuGlobal.control_brillo.value, 113.0) and MenuGlobal.selector_filtro.selected == 2, "La pausa comparte los ajustes del menu")
	MenuGlobal.control_brillo.value = 92.0
	_pulsar_escape()
	await get_tree().process_frame
	_verificar(MenuGlobal.panel_pausa.visible and get_tree().paused, "ESC en opciones vuelve a la pausa")
	_pulsar_escape()
	await get_tree().process_frame
	_verificar(not get_tree().paused and not MenuGlobal.capa.visible, "ESC reanuda el juego")
	await get_tree().create_timer(0.2).timeout
	_verificar(sistema.obtener_tiempo_restante(denuncia.id) < tiempo_denuncia, "Los tiempos continuan despues de reanudar")
	pc.computador_despacho_abierto.connect(func() -> void: _aperturas_pc += 1)
	var consulta := jugador.shape_cast_3d
	var transformacion_consulta := consulta.global_transform
	var destino_consulta := consulta.target_position
	# La consulta permanece sobre la PC para detectar una reapertura con el mismo evento.
	consulta.global_position = pc.get_node("CollisionShape3D").global_position
	consulta.target_position = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().process_frame
	_pulsar_tecla(KEY_E)
	await get_tree().process_frame
	_verificar(pc.is_using and jugador.input_locked and _aperturas_pc == 1, "E abre la PC una sola vez sin cerrarla con el mismo evento")
	var denuncia_activa := sistema.obtener_denuncia_activa()
	_verificar(denuncia_activa != null, "La PC inicia la denuncia")
	_pulsar_escape()
	await get_tree().process_frame
	_verificar(get_tree().paused and pc.is_using, "ESC pausa sin salir de la PC")
	_verificar(not MenuGlobal.has_node("%SalirComputador"), "La pausa no incluye Salir del computador")
	_verificar(pc.camera_3d.current and jugador.input_locked and not jugador.can_process(), "Se conserva la camara y el bloqueo del jugador")
	await _capturar("04_pausa_computador")
	MenuGlobal.reanudar_juego()
	_verificar(pc.is_using and jugador.input_locked and _aperturas_pc == 1 and sistema.obtener_denuncia_activa() == denuncia_activa, "Reanudar no vuelve a abrir ni aceptar una denuncia")
	_pulsar_tecla(KEY_E)
	await get_tree().process_frame
	_verificar(not pc.is_using and not get_tree().paused and not jugador.input_locked and jugador.is_physics_processing() and _aperturas_pc == 1, "E sale de la PC sin reabrirla y devuelve el control")
	_verificar(oficina.get_node("Gameplay/Camera3D").current, "Se recupera la camara de la oficina")
	_pulsar_tecla(KEY_E)
	await get_tree().process_frame
	_verificar(pc.is_using and jugador.input_locked and _aperturas_pc == 2, "Una nueva pulsacion de E vuelve a abrir la PC")
	var mantener_interaccion := InputEventKey.new()
	mantener_interaccion.physical_keycode = KEY_E
	mantener_interaccion.keycode = KEY_E
	mantener_interaccion.pressed = true
	mantener_interaccion.echo = true
	Input.parse_input_event(mantener_interaccion)
	await get_tree().process_frame
	_verificar(pc.is_using and _aperturas_pc == 2, "Mantener E no alterna el uso del computador")
	_pulsar_tecla(KEY_E)
	await get_tree().process_frame
	_verificar(not pc.is_using and not jugador.input_locked and jugador.is_processing_input() and jugador.is_physics_processing() and _aperturas_pc == 2, "E tambien sale correctamente en usos consecutivos")
	consulta.global_transform = transformacion_consulta
	consulta.target_position = destino_consulta
	_pulsar_escape()
	await get_tree().process_frame
	MenuGlobal.get_node("%MenuPrincipal").pressed.emit()
	_verificar(MenuGlobal.panel_confirmacion.visible and get_tree().paused, "Se confirma antes de abandonar la sesion")
	await _capturar("05_confirmacion")
	_pulsar_escape()
	await get_tree().process_frame
	_verificar(MenuGlobal.panel_pausa.visible and get_tree().paused, "Cancelar la salida mantiene la pausa")
	MenuGlobal.volver_al_menu()
	await get_tree().scene_changed
	await get_tree().process_frame
	_verificar(get_tree().current_scene.scene_file_path == MenuGlobal.ESCENA_MENU and not get_tree().paused and not MenuGlobal.capa.visible, "Regreso limpio al menu principal")
	await _capturar("06_menu_principal")
	MenuGlobal.abrir_opciones()
	_verificar(is_equal_approx(MenuGlobal.control_brillo.value, 92.0), "El menu recibe los cambios hechos en la pausa")
	AjustesAccesibilidad.restablecer()
	_verificar(not MenuGlobal.filtro_pantalla.visible and is_equal_approx(MenuGlobal.control_brillo.value, 100.0), "Restablecer deja la imagen neutra")
	for modo: int in range(1, 4):
		AjustesAccesibilidad.establecer_modo(modo)
		_verificar(MenuGlobal.filtro_pantalla.visible, "Modo de filtro %d" % modo)
		await _capturar("07_filtro_%d" % modo)
	AjustesAccesibilidad.establecer_intensidad(0.0)
	_verificar(not MenuGlobal.filtro_pantalla.visible, "Intensidad cero no altera la imagen")
	MenuGlobal.cerrar_opciones()
	get_tree().current_scene.get_node("CenterContainer/MenuPanel/VBoxContainer/MenuButtons/PlayButton").pressed.emit()
	await get_tree().scene_changed
	await get_tree().process_frame
	_verificar(not get_tree().paused and get_tree().current_scene.sistema_despacho.obtener_denuncia_activa() == null, "Jugar de nuevo inicia una partida sin pausa ni denuncia anterior")
	await _probar_pixeles()
	get_tree().change_scene_to_file(MenuGlobal.ESCENA_MENU)
	await get_tree().scene_changed
	_restaurar_archivo()
	print("PRUEBAS DE MENUS: %d errores" % _errores)
	if _errores == 0:
		get_tree().current_scene.get_node("CenterContainer/MenuPanel/VBoxContainer/MenuButtons/QuitButton").pressed.emit()
	else:
		get_tree().quit(1)


func _clic_control(control: Control) -> void:
	var centro := control.get_global_rect().get_center()
	var movimiento := InputEventMouseMotion.new()
	movimiento.position = centro
	movimiento.global_position = centro
	Input.parse_input_event(movimiento)
	for pulsado: bool in [true, false]:
		var clic := InputEventMouseButton.new()
		clic.position = centro
		clic.global_position = centro
		clic.button_index = MOUSE_BUTTON_LEFT
		clic.pressed = pulsado
		Input.parse_input_event(clic)


func _pulsar_escape() -> void:
	_pulsar_tecla(KEY_ESCAPE)


func _pulsar_tecla(tecla: Key, shift: bool = false, ventana: int = 0) -> void:
	var evento := InputEventKey.new()
	evento.window_id = ventana
	evento.physical_keycode = tecla
	evento.keycode = tecla
	evento.shift_pressed = shift
	evento.pressed = true
	Input.parse_input_event(evento)
	var soltar := evento.duplicate() as InputEventKey
	soltar.pressed = false
	Input.parse_input_event(soltar)


func _verificar(condicion: bool, descripcion: String) -> void:
	if condicion:
		print("OK: ", descripcion)
	else:
		_errores += 1
		push_error("FALLO: " + descripcion)


func _restaurar_archivo() -> void:
	AjustesAccesibilidad.guardar()
	if _archivo_existia:
		var archivo := FileAccess.open(AjustesAccesibilidad.ARCHIVO, FileAccess.WRITE)
		archivo.store_buffer(_contenido_original)
	else:
		DirAccess.remove_absolute(AjustesAccesibilidad.ARCHIVO)


func _capturar(nombre: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--capturas" in OS.get_cmdline_user_args():
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var directorio := "res://.godot/menu_qa/%dx%d" % [get_viewport().size.x, get_viewport().size.y]
	DirAccess.make_dir_recursive_absolute(directorio)
	get_viewport().get_texture().get_image().save_png(directorio.path_join(nombre + ".png"))
	var panel: Control
	for candidato: Control in [MenuGlobal.panel_pausa, MenuGlobal.panel_opciones, MenuGlobal.panel_confirmacion]:
		if candidato.is_visible_in_tree():
			panel = candidato
	if panel != null:
		var rectangulo := panel.get_global_rect()
		var scroll := panel.get_parent().get_parent() as ScrollContainer
		var pantalla := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
		_verificar(pantalla.encloses(scroll.get_global_rect()) and rectangulo.position.x >= 0.0 and rectangulo.end.x <= pantalla.end.x, "Panel visible o desplazable: " + nombre)


func _probar_pixeles() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var muestras := CanvasLayer.new()
	muestras.layer = 90
	add_child(muestras)
	for indice: int in range(4):
		var recuadro := ColorRect.new()
		recuadro.position = Vector2(20 + indice * 80, 20)
		recuadro.size = Vector2(60, 60)
		recuadro.color = [Color(0.6, 0.2, 0.1), Color(0.1, 0.6, 0.2), Color(0.1, 0.2, 0.6), Color(0.4, 0.4, 0.4)][indice]
		muestras.add_child(recuadro)
	AjustesAccesibilidad.restablecer()
	var original := await _leer_pixeles()
	MenuGlobal.filtro_pantalla.show()
	var neutro := await _leer_pixeles()
	_verificar(_diferencia(original, neutro) < 0.02, "Shader desactivado conserva los pixeles originales")
	AjustesAccesibilidad.establecer_brillo(0.8)
	var oscuro := await _leer_pixeles()
	AjustesAccesibilidad.establecer_brillo(1.2)
	var claro := await _leer_pixeles()
	_verificar(oscuro[3].r < original[3].r and claro[3].r > original[3].r, "Brillo modifica realmente la imagen renderizada")
	AjustesAccesibilidad.establecer_brillo(1.0)
	for modo: int in range(1, 4):
		AjustesAccesibilidad.establecer_modo(modo)
		var filtrado := await _leer_pixeles()
		_verificar(_diferencia(original, filtrado) > 0.02, "Filtro %d modifica los colores renderizados" % modo)
	AjustesAccesibilidad.establecer_intensidad(0.0)
	MenuGlobal.filtro_pantalla.show()
	var sin_intensidad := await _leer_pixeles()
	_verificar(_diferencia(original, sin_intensidad) < 0.02, "Intensidad cero conserva los pixeles originales")
	muestras.queue_free()


func _leer_pixeles() -> Array[Color]:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var imagen := get_viewport().get_texture().get_image()
	var colores: Array[Color] = []
	for indice: int in range(4):
		colores.append(imagen.get_pixel(50 + indice * 80, 50))
	return colores


func _diferencia(primero: Array[Color], segundo: Array[Color]) -> float:
	var diferencia := 0.0
	for indice: int in range(primero.size()):
		diferencia += absf(primero[indice].r - segundo[indice].r)
		diferencia += absf(primero[indice].g - segundo[indice].g)
		diferencia += absf(primero[indice].b - segundo[indice].b)
	return diferencia
