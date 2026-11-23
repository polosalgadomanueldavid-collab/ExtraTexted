extends SceneTree
## --headless --script res://Pruebas/Despacho/prueba_controles_y_guia.gd
var errores := 0
var pruebas := 0
var completados := 0
var cierres := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.get_node("MenuGlobal").capa.hide()
	var controlador = root.get_node("ControladorInterfaz")
	controlador.dispositivo_mando = 0
	controlador._registrar_eventos_mando()
	var panel = load("res://UI/Despacho/clasificador_evidencias.gd").new()
	root.add_child(panel)
	panel.set_process(false)
	panel.terminado.connect(func(_id): completados += 1)
	panel.cerrado.connect(func(): cierres += 1)
	for mando: bool in [false, true]:
		panel.iniciar("entrada_%s" % mando, true)
		var previos := completados
		panel._input(_evento(mando, KEY_E, JOY_BUTTON_A))
		panel._input(_evento(mando, KEY_D, JOY_BUTTON_DPAD_RIGHT))
		_verificar(panel.visible and completados == previos and panel.seleccion == 1, "La entrada bloquea confirmar y navegar: %s" % mando)
		panel._process(panel.DURACION_ENTRADA)
		panel._input(_evento(mando, KEY_E, JOY_BUTTON_A))
		_verificar(not panel.visible and completados == previos + 1, "Confirmar funciona al terminar la entrada: %s" % mando)
		panel.iniciar("salida_%s" % mando, true)
		panel.sonido_hoja.play()
		var cerrados := cierres
		panel._input(_evento(mando, KEY_ESCAPE, JOY_BUTTON_B))
		_verificar(not panel.visible and cierres == cerrados + 1 and not panel.sonido_hoja.playing and panel.entrada_restante == 0, "Salir durante la entrada cierra y detiene el sonido: %s" % mando)
		panel.iniciar("salida_%s" % mando, true)
		_verificar(panel.objetivos == [0] and panel.papeles == [1, 0, 2], "Reabrir conserva la tarea cancelada: %s" % mando)
		panel.cancelar()
	panel.queue_free()
	controlador._actualizar_mando()
	await process_frame
	await _probar_guia()
	print("[CONTROLES Y GUIA] %d comprobaciones, %d errores" % [pruebas, errores])
	quit(1 if errores else 0)

func _probar_guia() -> void:
	var radio = load("res://UI/Despacho/radio_practica.gd").new()
	var barra := Control.new()
	root.add_child(barra)
	root.add_child(radio)
	radio.barra_despacho = barra
	radio.set_process(false)
	for resolucion: Vector2i in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
		root.size = resolucion
		await process_frame
		var factor := minf(resolucion.x / 1920.0, resolucion.y / 1080.0)
		barra.position = Vector2(resolucion.x - 436*factor, 28*factor)
		barra.size = Vector2(408*factor, resolucion.y - 56*factor)
		radio._process(0.0)
		var area: Rect2 = radio._area_objetivo()
		var pantalla := Rect2(Vector2.ZERO, Vector2(resolucion))
		for destino: Vector2 in [Vector2(-1000, 300), Vector2(resolucion.x + 1000, 300), Vector2(400, -1000), Vector2(400, resolucion.y + 1000), Vector2(-1000, -1000)]:
			for detras: bool in [false, true]:
				radio._ubicar_objetivo(destino, detras, area)
				var caja: Rect2 = radio._caja_objetivo.grow(10 * radio._factor)
				var direccion: Vector2 = -(destino - Vector2(resolucion)*.5) if detras else destino - radio._caja_objetivo.get_center()
				_verificar(radio._direccion_objetivo.dot(direccion.normalized()) > .99, "La flecha apunta al destino, incluso detrás de cámara: %s" % resolucion)
				_verificar(pantalla.encloses(caja) and not caja.intersects(barra.get_global_rect()) and caja.end.y < radio._caja.position.y * radio._factor, "Tarjeta y flecha respetan pantalla, casos y radio: %s" % resolucion)
		radio._ubicar_objetivo(area.get_center() + Vector2(0, 48)*radio._factor, false, area)
		_verificar(radio._caja_objetivo.get_center().is_equal_approx(area.get_center()) and radio._direccion_objetivo == Vector2.DOWN, "Un destino visible mantiene el marcador sobre el objeto")
	radio.queue_free()
	barra.queue_free()
	await process_frame

func _evento(mando: bool, tecla: Key, boton: JoyButton) -> InputEvent:
	if mando:
		var evento := InputEventJoypadButton.new()
		evento.device = 0
		evento.button_index = boton
		evento.pressed = true
		return evento
	var evento := InputEventKey.new()
	evento.physical_keycode = tecla
	evento.pressed = true
	return evento

func _verificar(condicion: bool, mensaje: String) -> void:
	pruebas += 1
	if not condicion:
		errores += 1
		push_error(mensaje)
