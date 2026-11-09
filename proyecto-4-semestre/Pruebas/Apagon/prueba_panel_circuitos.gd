extends "res://Pruebas/Apagon/prueba_apagon_smoke.gd"
## Entrada real de ratón y teclado, escalado, persistencia, animación y audio.
## Ejecutar con --headless --fixed-fps 60 --script res://Pruebas/Apagon/prueba_panel_circuitos.gd.

const RESOLUCIONES := [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1024, 768), Vector2i(1680, 720)]

var _resueltos_panel: int = 0
var _cierres_panel: int = 0
var _posicion_raton := Vector2.ZERO


func _probar() -> void:
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i.ZERO
	_escena = Node3D.new()
	_escena.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.add_child(_escena)
	current_scene = _escena
	_panel = load("res://UI/Apagon/panel_circuitos.gd").new() as Control
	_escena.add_child(_panel)
	_panel.connect("circuito_resuelto", _contar_solucion_panel)
	_panel.connect("cerrado", _contar_cierre_panel)
	for indice: int in range(RESOLUCIONES.size()):
		root.size = RESOLUCIONES[indice]
		await _cuadros(3)
		for tipo: int in TIPOS_CIRCUITO:
			await _probar_raton(tipo, 8900 + indice * 10 + tipo)
	root.size = Vector2i(1280, 720)
	await _cuadros(3)
	await _probar_teclado()
	await _probar_entrada()
	await _probar_pausa_y_audio()
	await _probar_cierre_durante_exito()
	paused = false
	_escena.queue_free()
	await process_frame
	await _esperar_audio_al_salir()
	print("[PANEL CIRCUITOS] %d comprobaciones, %d errores." % [_comprobaciones, _errores.size()])
	quit(0 if _errores.is_empty() else 1)


func _abrir_panel(tipo: int, semilla: int) -> void:
	_panel.call("abrir", tipo, semilla)
	await _esperar_entrada()
	await _cuadros(2)
	_verificar(_panel.is_visible_in_tree(), "El circuito %d abre en %s" % [tipo, root.size])
	_validar_textos()
	var controles: Array = (_panel.get("interruptores") as Array).duplicate()
	controles += _panel.get("botones_anillos") as Array
	controles += _panel.get("origenes_cables") as Array
	controles += _panel.get("destinos_cables") as Array
	for control: Button in controles:
		var limites := control.get_global_rect()
		_verificar(limites.has_area() and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(limites), "La zona de interacción %s cabe dentro de %s" % [control.name, root.size])


func _probar_raton(tipo: int, semilla: int) -> void:
	var resueltos_antes := _resueltos_panel
	await _abrir_panel(tipo, semilla)
	var estado: Dictionary = _panel.call("obtener_estado")
	match tipo:
		0:
			var interruptores: Array = _panel.get("interruptores")
			await _clic(interruptores[0] as Button)
			await create_timer(0.25).timeout
			_verificar(bool((_panel.call("obtener_estado") as Dictionary).interruptores[0]) != bool(estado.interruptores[0]), "Un clic real conmuta la palanca en %s" % root.size)
			await _reabrir_mismo(tipo, semilla)
			interruptores = _panel.get("interruptores")
			for indice: int in range(interruptores.size()):
				if not bool((_panel.call("obtener_estado") as Dictionary).interruptores[indice]):
					await _clic(interruptores[indice] as Button)
					await create_timer(0.25).timeout
		2:
			var botones: Array = _panel.get("botones_anillos")
			await _esperar_anillo(0, false)
			await _clic(botones[0] as Button)
			_verificar(not bool((_panel.call("obtener_estado") as Dictionary).fijados[0]) and _resueltos_panel == resueltos_antes, "El anillo rechaza el clic fuera del arco sin emitir éxito")
			for indice: int in range(botones.size()):
				await _esperar_anillo(indice, true)
				await _clic(botones[indice] as Button)
		3:
			var origenes: Array = _panel.get("origenes_cables")
			var destinos: Array = _panel.get("destinos_cables")
			var correcta: int = estado.destinos.find(0)
			await _arrastrar(origenes[0] as Button, destinos[(correcta + 1) % 4] as Button)
			_verificar(int((_panel.call("obtener_estado") as Dictionary).conexiones[0]) == -1 and _resueltos_panel == resueltos_antes, "El arrastre a otro color rechaza el cable sin emitir éxito")
			await _arrastrar(origenes[0] as Button, destinos[correcta] as Button)
			_verificar(int((_panel.call("obtener_estado") as Dictionary).conexiones[0]) == correcta, "El arrastre real conecta el primer cable en %s" % root.size)
			await create_timer(0.25).timeout
			await _reabrir_mismo(tipo, semilla)
			origenes = _panel.get("origenes_cables")
			destinos = _panel.get("destinos_cables")
			for indice: int in range(1, 4):
				await _arrastrar(origenes[indice] as Button, destinos[int(estado.destinos.find(indice))] as Button)
				await create_timer(0.25).timeout
	await create_timer(0.95).timeout
	_verificar(bool((_panel.call("obtener_estado") as Dictionary).resuelto), "El ratón completa el circuito %d en %s" % [tipo, root.size])
	_verificar(_resueltos_panel == resueltos_antes + 1, "El circuito %d emite éxito una sola vez" % tipo)
	_panel.call("cerrar")
	await _cuadros(2)


func _reabrir_mismo(tipo: int, semilla: int) -> void:
	var anterior: Dictionary = _panel.call("obtener_estado")
	_panel.call("cerrar")
	await _cuadros(2)
	_panel.call("abrir", tipo, semilla)
	_verificar((_panel.call("obtener_estado") as Dictionary) == anterior, "Reabrir el mismo circuito conserva su progreso")
	await _esperar_entrada()
	await _cuadros(2)


func _probar_teclado() -> void:
	await _abrir_panel(0, 9901)
	var anterior: Dictionary = _panel.call("obtener_estado")
	await _pulsar_tecla(KEY_E)
	_verificar(bool((_panel.call("obtener_estado") as Dictionary).interruptores[0]) != bool(anterior.interruptores[0]), "E conmuta la palanca seleccionada")
	await _pulsar_tecla(KEY_D)
	await _pulsar_tecla(KEY_E)
	_verificar(bool((_panel.call("obtener_estado") as Dictionary).interruptores[1]) != bool(anterior.interruptores[1]), "D selecciona la siguiente palanca y E la conmuta")
	await _pulsar_tecla(KEY_A)
	await _pulsar_tecla(KEY_E)
	_verificar(bool((_panel.call("obtener_estado") as Dictionary).interruptores[0]) == bool(anterior.interruptores[0]), "A regresa a la palanca anterior")
	_panel.call("cerrar")
	await _abrir_panel(2, 9902)
	await _pulsar_tecla(KEY_D)
	await _esperar_anillo(1, true)
	await _pulsar_tecla(KEY_E)
	_verificar(bool((_panel.call("obtener_estado") as Dictionary).fijados[1]), "D y E permiten sincronizar el anillo seleccionado")
	_panel.call("cerrar")
	await _abrir_panel(3, 9903)
	var estado: Dictionary = _panel.call("obtener_estado")
	var correcta: int = estado.destinos.find(0)
	var incorrecta := (correcta + 1) % 4
	await _pulsar_tecla(KEY_E)
	var visual: Dictionary = (_panel.get("_arte") as Control).get("_visual")
	_verificar(int(visual.cable_arrastrado) == -1, "El cable de teclado sigue el destino seleccionado sin usar la posición del ratón")
	for paso: int in range(incorrecta):
		await _pulsar_tecla(KEY_D)
	await _pulsar_tecla(KEY_E)
	_verificar(int((_panel.call("obtener_estado") as Dictionary).conexiones[0]) == -1, "El teclado rechaza un destino de otro color")
	for paso: int in range(posmod(correcta - incorrecta, 4)):
		await _pulsar_tecla(KEY_D)
	await _pulsar_tecla(KEY_E)
	_verificar(int((_panel.call("obtener_estado") as Dictionary).conexiones[0]) == correcta, "E selecciona origen y destino y conecta el cable correcto")
	_panel.call("cerrar")


func _probar_pausa_y_audio() -> void:
	_panel.call("abrir", 2, 9910)
	await create_timer(0.1).timeout
	var entrada: float = _panel.get("_entrada_restante")
	paused = true
	await create_timer(0.15).timeout
	_verificar(is_equal_approx(float(_panel.get("_entrada_restante")), entrada), "La pausa congela la entrada del gabinete")
	paused = false
	await _esperar_entrada()
	var audio: Node = _panel.get("_sonidos")
	var motor := audio.get("motor") as AudioStreamPlayer
	_verificar(motor.playing, "Los anillos reproducen su motor mientras giran")
	var fases: Dictionary = _panel.call("obtener_estado")
	paused = true
	await create_timer(0.15).timeout
	_verificar((_panel.call("obtener_estado") as Dictionary).fases == fases.fases and motor.stream_paused, "La pausa congela las fases y su sonido")
	paused = false
	await _cuadros(2)
	_verificar(not motor.stream_paused, "Reanudar continúa el motor")
	_panel.call("cerrar")
	_verificar(not motor.playing, "Cerrar el panel detiene el motor de los anillos")
	await _abrir_panel(3, 9912)
	var estado_cables: Dictionary = _panel.call("obtener_estado")
	var origenes: Array = _panel.get("origenes_cables")
	var destinos: Array = _panel.get("destinos_cables")
	await _arrastrar(origenes[0] as Button, destinos[int(estado_cables.destinos.find(0))] as Button)
	await create_timer(0.04).timeout
	var conexiones: Array = (_panel.get("_conexiones_visuales") as Array).duplicate()
	var cable := audio.get("cable") as AudioStreamPlayer
	paused = true
	await create_timer(0.15).timeout
	_verificar((_panel.get("_conexiones_visuales") as Array) == conexiones and cable.stream_paused, "La pausa congela el encaje visual y el sonido del cable")
	paused = false
	_panel.call("cerrar")
	await _abrir_panel(0, 9911)
	var interruptores: Array = _panel.get("interruptores")
	(interruptores[0] as Button).button_pressed = true
	await create_timer(0.05).timeout
	var palancas: Array = (_panel.get("_palancas") as Array).duplicate()
	paused = true
	await create_timer(0.15).timeout
	_verificar((_panel.get("_palancas") as Array) == palancas, "La pausa congela la animación de la palanca")
	paused = false
	await create_timer(0.25).timeout
	for boton: Button in interruptores:
		boton.button_pressed = true
	var restantes: float = _panel.get("_fin_restante")
	var emitidos := _resueltos_panel
	paused = true
	await create_timer(0.2).timeout
	_verificar(is_equal_approx(float(_panel.get("_fin_restante")), restantes) and _resueltos_panel == emitidos, "La pausa congela la animación final y retrasa la señal de éxito")
	paused = false
	await create_timer(0.95).timeout
	_verificar(_resueltos_panel == emitidos + 1, "La animación final emite una vez al reanudarse")
	_panel.call("cerrar")


func _probar_entrada() -> void:
	for tipo: int in TIPOS_CIRCUITO:
		_panel.call("abrir", tipo, 9905 + tipo)
		var anterior: Dictionary = _panel.call("obtener_estado")
		for grupo: String in ["interruptores", "botones_anillos", "origenes_cables", "destinos_cables"]:
			for boton: Button in _panel.get(grupo):
				_verificar(boton.disabled, "El control %s no acepta clics mientras entra el gabinete" % boton.name)
		await _pulsar_tecla(KEY_E)
		_verificar((_panel.call("obtener_estado") as Dictionary) == anterior, "La E de apertura conserva intacto el circuito %d durante la entrada" % tipo)
		await _esperar_entrada()
		_panel.call("cerrar")


func _probar_cierre_durante_exito() -> void:
	await _abrir_panel(0, 9920)
	var resueltos_antes := _resueltos_panel
	var cierres_antes := _cierres_panel
	for boton: Button in _panel.get("interruptores"):
		boton.button_pressed = true
	_verificar(bool((_panel.call("obtener_estado") as Dictionary).resuelto) and _resueltos_panel == resueltos_antes, "La solución espera su animación antes de emitir éxito")
	_panel.call("cerrar")
	_panel.call("cerrar")
	await create_timer(0.95).timeout
	_verificar(_resueltos_panel == resueltos_antes + 1 and _cierres_panel == cierres_antes + 1, "Cerrar durante el final conserva un único éxito y un único cierre")


func _validar_textos() -> void:
	for nodo: Node in _panel.find_children("*", "", true, false):
		if nodo is Label or nodo is Button or nodo is RichTextLabel:
			_verificar(str(nodo.get("text")).strip_edges().is_empty(), "El gabinete conserva sus controles sin textos ni números")
		if nodo is ProgressBar:
			_verificar(not (nodo as ProgressBar).show_percentage, "La barra visual oculta los porcentajes numéricos")


func _clic(boton: Button) -> void:
	var punto := boton.get_global_transform_with_canvas() * (boton.size * 0.5)
	await _mover_raton(punto, false)
	_enviar_boton(punto, true)
	await process_frame
	_enviar_boton(punto, false)
	await process_frame


func _arrastrar(origen: Button, destino: Button) -> void:
	var inicio := origen.get_global_transform_with_canvas() * (origen.size * 0.5)
	var fin := destino.get_global_transform_with_canvas() * (destino.size * 0.5)
	await _mover_raton(inicio, false)
	_enviar_boton(inicio, true)
	await process_frame
	var visual: Dictionary = (_panel.get("_arte") as Control).get("_visual")
	_verificar(int(visual.cable_arrastrado) >= 0, "El cable arrastrado sigue el ratón al sujetar su origen")
	for paso: int in range(1, 5):
		await _mover_raton(inicio.lerp(fin, float(paso) / 4.0), true)
	_enviar_boton(fin, false)
	await process_frame


func _mover_raton(posicion: Vector2, pulsado: bool) -> void:
	var movimiento := InputEventMouseMotion.new()
	movimiento.position = posicion
	movimiento.global_position = posicion
	movimiento.relative = posicion - _posicion_raton
	movimiento.button_mask = MOUSE_BUTTON_MASK_LEFT if pulsado else 0
	Input.parse_input_event(movimiento)
	_posicion_raton = posicion
	await process_frame


func _enviar_boton(posicion: Vector2, pulsado: bool) -> void:
	var evento := InputEventMouseButton.new()
	evento.position = posicion
	evento.global_position = posicion
	evento.button_index = MOUSE_BUTTON_LEFT
	evento.button_mask = MOUSE_BUTTON_MASK_LEFT if pulsado else 0
	evento.pressed = pulsado
	Input.parse_input_event(evento)


func _contar_solucion_panel() -> void:
	_resueltos_panel += 1


func _contar_cierre_panel() -> void:
	_cierres_panel += 1
