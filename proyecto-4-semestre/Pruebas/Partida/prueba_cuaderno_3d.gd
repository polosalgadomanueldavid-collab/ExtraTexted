extends Node
## F6: vista interactiva. CLI: -- --verificar [--capturas].

var final: FinalPartida
var fallos := 0
var reinicios := 0
var menus := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	_probar.call_deferred()


func _probar() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color("344a54")
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	final = FinalPartida.new()
	add_child(final)
	final.reiniciar_solicitado.connect(func() -> void: reinicios += 1)
	final.menu_solicitado.connect(func() -> void: menus += 1)
	_verificar(final._cuaderno._vista.render_target_update_mode == SubViewport.UPDATE_DISABLED, "La libreta oculta no renderiza")
	var casos: Array = []
	for i: int in range(16):
		casos.append({"titulo": "Suplantación de identidad en una cuenta de servicios %02d" % (i + 1), "completadas": ["evidencias", "privacidad"], "pendientes": ["verificacion", "reporte", "bienestar"]})
	final.presentar({"duracion": 427.0, "puntos_ganados": 2400, "saldo": 1850, "resueltas": casos, "vencidas": [casos[0]], "pendientes": [casos[1]], "causa": casos[0]})
	final._abrir_cuaderno()
	_verificar(final._fase == 1, "No se puede saltar el relevo")
	final.finalizar_relevo()
	final._abrir_cuaderno()
	get_tree().paused = true
	await final._cuaderno.apertura_terminada
	await _esperar(0.15)
	_verificar(final._estadisticas.text == "Cerraste 16 de 18 denuncias recibidas.", "El balance conserva los datos originales")
	await _capturar("01_balance")
	if not "--verificar" in OS.get_cmdline_user_args():
		return
	for punto: Vector2 in [Vector2(180, 180), Vector2(720, 460), Vector2(1250, 240)]:
		var pantalla: Vector2 = final._cuaderno.proyectar_papel(punto)
		var vuelta: Vector2 = final._cuaderno._posicion_en_papel(pantalla)
		_verificar(vuelta.distance_to(punto) < 0.5, "El puntero coincide con la hoja curvada: " + str(punto))
	_click_papel(final._siguiente.position + final._siguiente.size * 0.5)
	await _esperar(0.22)
	_verificar(final._pasando_pagina and final._cuaderno._hoja_movil.visible, "El clic proyectado levanta una hoja 3D")
	final._ir_a_pagina(2)
	_verificar(final._pagina_actual == 1, "Los clics repetidos no interrumpen el giro")
	await _capturar("02_giro")
	await _esperar(0.22)
	await _capturar("02b_reverso")
	await _esperar(0.43)
	_verificar(not final._pasando_pagina and final._paginas[0].titulo.text == "Lo que hiciste", "Termina el giro mientras el juego está pausado")
	await _capturar("03_casos")
	var scroll := final._paginas[0].scroll as ScrollContainer
	var previo := scroll.scroll_vertical
	for i: int in range(8):
		_click_papel(Vector2(350, 420), MOUSE_BUTTON_WHEEL_DOWN)
	await _esperar(0.12)
	_verificar(scroll.scroll_vertical > previo, "La rueda desplaza las listas sobre el papel 3D")
	_click_papel(Vector2(370, 280), MOUSE_BUTTON_RIGHT)
	await _esperar(0.4)
	_verificar(final._cuaderno.acercado and final._cuaderno._zoom > 0.99, "El clic derecho acerca la zona elegida")
	previo = scroll.scroll_vertical
	_click_papel(Vector2(350, 420), MOUSE_BUTTON_WHEEL_DOWN)
	await _esperar(0.1)
	_verificar(scroll.scroll_vertical > previo, "La rueda también coincide con el papel ampliado")
	await _capturar("04_zoom")
	_tecla(KEY_ESCAPE)
	await _esperar(0.4)
	_verificar(not final._cuaderno.acercado, "Escape vuelve al encuadre completo")
	_click_papel(final._pestanas[2].position + final._pestanas[2].size * 0.5)
	await _esperar(0.85)
	_verificar(final._pagina_actual == 2 and final._siguiente.disabled, "La pestaña lleva a estadísticas y respeta el límite")
	await _capturar("05_estadisticas")
	_tecla(KEY_LEFT)
	await _esperar(0.26)
	await _capturar("06_giro_inverso")
	await _esperar(0.55)
	_verificar(final._pagina_actual == 1, "El teclado permite girar hacia atrás")
	_click_papel(final._pestanas[0].position + final._pestanas[0].size * 0.5)
	await _esperar(0.85)
	_verificar(final._pagina_actual == 0 and final._anterior.disabled, "Las pestañas trasladadas a la izquierda siguen funcionando")
	for resolucion: Vector2i in [Vector2i(960, 540), Vector2i(1600, 900), Vector2i(1024, 768), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
		get_window().size = resolucion
		await _esperar(0.2)
		var esquina: Vector2 = final._cuaderno.proyectar_papel(Vector2(1252, 654))
		_verificar(Rect2(Vector2.ZERO, Vector2(resolucion)).has_point(esquina), "El libro cabe en " + str(resolucion))
		await _capturar("07_%dx%d" % [resolucion.x, resolucion.y])
	get_window().size = Vector2i(1280, 720)
	await _esperar(0.2)
	_click_papel(Vector2(930, 630))
	_click_papel(Vector2(1070, 630))
	_verificar(reinicios == 1 and menus == 1, "Reintentar y Menú responden a clics proyectados")
	final._siguiente.grab_focus()
	_tecla(KEY_ENTER)
	await _esperar(0.85)
	_verificar(final._pagina_actual == 1, "Enter activa el botón enfocado dentro del papel")
	await _probar_mvp()
	final.hide()
	_verificar(final._cuaderno._vista.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Ocultar el final detiene ambos renderizados")
	print("CUADERNO 3D: ", fallos, " fallos")
	get_tree().paused = false
	final._musica_derrota.stop()
	await _esperar(0.15)
	final.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if fallos else 0)


func _probar_mvp() -> void:
	var originales := final._datos.duplicate(true)
	final._pagina_actual = 0
	final._poblar_paginas()
	_verificar(not _textos(final._contenido_libro).contains("MVP del equipo"), "El modo individual conserva su balance sin MVP")
	final._datos["multijugador"] = true
	final._datos["equipo"] = [
		{"id": 1, "nombre": "Ana", "misiones": 4, "tareas": 6},
		{"id": 2, "nombre": "Luis", "misiones": 2, "tareas": 9}
	]
	final._poblar_paginas()
	await _esperar(0.12)
	var misiones := final._cuerpo(1).get_node("Distincion_misiones")
	var tareas := final._cuerpo(1).get_node("Distincion_tareas")
	_verificar(_textos(misiones).contains("Ana") and _textos(tareas).contains("Luis"), "Más misiones y mayor aporte pueden reconocer a jugadores distintos")
	_verificar(_textos(final._cuerpo(1)).contains("El caso final"), "El MVP conserva debajo el caso final")
	await _capturar("08_mvp")
	for pagina: int in [1, 2]:
		final._pagina_actual = pagina
		final._poblar_paginas()
		_verificar(not _textos(final._contenido_libro).contains("MVP del equipo"), "El MVP solo aparece en la primera apertura")
	final._pagina_actual = 0
	final._datos.equipo[1].misiones = 4
	final._poblar_paginas()
	var empate := _textos(final._cuerpo(1).get_node("Distincion_misiones"))
	_verificar(empate.contains("EMPATE") and empate.contains("Ana y Luis"), "El empate reconoce a ambos participantes")
	for jugador: Dictionary in final._datos.equipo:
		jugador.misiones = 0
		jugador.tareas = 0
	final._poblar_paginas()
	_verificar(_textos(final._cuerpo(1).get_node("Distincion_misiones")).contains("Sin asignar") and not _textos(final._cuerpo(1).get_node("Distincion_tareas")).contains("EMPATE"), "Una ronda sin actividad no inventa ganadores")
	await _esperar(0.1)
	await _capturar("09_mvp_sin_actividad")
	final._datos = originales
	final._poblar_paginas()


func _textos(nodo: Node) -> String:
	var texto: String = nodo.text if nodo is Label else ""
	for hijo: Node in nodo.get_children():
		texto += "\n" + _textos(hijo)
	return texto


func _click_papel(punto: Vector2, boton: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var pantalla: Vector2 = final._cuaderno.proyectar_papel(punto)
	var mover := InputEventMouseMotion.new()
	mover.position = pantalla
	get_viewport().push_input(mover, true)
	for pulsado: bool in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.position = pantalla
		evento.button_index = boton
		evento.pressed = pulsado
		get_viewport().push_input(evento, true)


func _tecla(codigo: Key) -> void:
	for pulsado: bool in [true, false]:
		var evento := InputEventKey.new()
		evento.keycode = codigo
		evento.pressed = pulsado
		get_viewport().push_input(evento, true)


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos, true, false, true).timeout


func _capturar(nombre: String) -> void:
	if "--capturas" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/cuaderno_3d_qa")
	get_viewport().get_texture().get_image().save_png("res://.godot/cuaderno_3d_qa/" + nombre + ".png")


func _verificar(condicion: bool, descripcion: String) -> void:
	if condicion:
		print("OK: ", descripcion)
	else:
		fallos += 1
		push_error("FALLO: " + descripcion)
