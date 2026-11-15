extends "res://Pruebas/ZonaDescanso/prueba_expendedora.gd"
## Comprueba entrada real, botones de carcasa, caída y recogida. -- --capturas para QA visual.

func _probar() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	await _cuadros(8)
	root.get_node("MenuGlobal").cerrar_ayuda()
	paused = false
	jugador = oficina.jugador
	maquina = oficina.get_node("MaquinaExpendedora")
	despacho = oficina.sistema_despacho
	_parar_relojes()
	oficina.anuncios.detener()
	await _cuadros(65)
	for i in 100:
		jugador.global_position = maquina.global_position + Vector3(1.6 - i * 0.01, 0.01, 0)
		jugador.visual.rotation.y = -PI / 2.0
		if jugador.obtener_objetivo_interaccion() == maquina:
			break
	await _cuadros(5)
	origen = jugador.global_position
	despacho.puntuacion.sumar_puntos_debug(1000)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var modo := Input.mouse_mode
	_tecla(KEY_E)
	await _cuadros(5)
	var panel: Control = maquina.panel
	_verificar(panel.visible and jugador.input_locked, "E abre la expendedora 3D")
	_verificar(panel.vista.transparent_bg and panel.vista.own_world_3d, "El modelo no tiene fondo ni escenario propios")
	_verificar(despacho.puntuacion.puntos == 1000 and maquina.producto_en_entrega == -1, "Abrir no compra ni dispensa")
	var rotulos := ""
	for letrero in panel._modelo.find_children("*", "Label3D", true, false):
		rotulos += letrero.text
	_verificar(not "REFUERZOS DE TURNO" in rotulos and not "RECOGE AQUÍ" in rotulos and not "SALIR" in rotulos, "La expendedora conserva solo los rótulos de uso")
	_verificar(not panel.boton_retirar.visible and not panel.boton_recoger.visible, "Las dos recogidas están ocultas sin producto listo")
	_verificar(not "VELOCIDAD" in rotulos and not "SALTO ALTO" in rotulos and not "DETIENE EL TIEMPO" in rotulos and not "RESUELVE UN EVENTO" in rotulos, "Los efectos se explican en la guía, no en la máquina")
	_verificar(panel._etiquetas[0].text == "A1 · 50 PTS", "La etiqueta inicial conserva código y precio")
	await _captura("01_abierta")
	await _clic(panel.botones[0])
	_verificar(maquina.producto_en_entrega == 0 and not maquina.producto_listo, "Pulsar A1 inicia la caída")
	_verificar(not maquina.comprar(1) and not maquina.recoger_producto(), "No permite comprar otro ni recoger antes de caer")
	await _cuadros(38)
	await _captura("02_cayendo")
	paused = true
	var tiempo: float = maquina._tiempo_entrega
	await _cuadros(10)
	_verificar(is_equal_approx(tiempo, maquina._tiempo_entrega), "Pausa congela la entrega")
	paused = false
	_tecla(KEY_ESCAPE)
	await _cuadros(100)
	_verificar(not panel.visible and not jugador.input_locked and not paused, "Escape cancela sin abrir pausa")
	_verificar(despacho.puntuacion.puntos == 1000 and maquina.inventario[0] == 0, "Cancelar no cobra ni entrega tarde")
	_verificar(Input.mouse_mode == modo, "Cerrar restaura el ratón")
	_tecla(KEY_E)
	await _cuadros(3)
	await _clic(panel.botones[0])
	await _cuadros(100)
	_verificar(maquina.producto_listo and panel.boton_recoger.visible and panel.boton_retirar.visible, "El producto en la bandeja habilita ambas recogidas")
	_verificar(despacho.puntuacion.puntos == 1000 and maquina.inventario[0] == 0, "La bandeja espera la recogida sin cobrar")
	await _captura("03_bandeja")
	await _clic(panel.boton_recoger)
	_verificar(maquina.inventario[0] == 1 and despacho.puntuacion.puntos == 950, "Recoger guarda y cobra exactamente el chocolate")
	_verificar(panel._etiquetas[0].text == "A1 · COMPRADO", "COMPRADO aparece junto al código interior")
	await _captura("03_comprado")
	_verificar(not maquina.recoger_producto() and not maquina.comprar(0) and despacho.puntuacion.puntos == 950, "Recogidas y compras repetidas no duplican cobros")
	_verificar(not panel.boton_retirar.visible and not panel.boton_recoger.visible, "Recoger oculta las dos zonas de recogida")
	_verificar(not maquina.usar(0), "El consumo espera salir de la máquina")
	await _clic(panel.botones[1])
	await _cuadros(100)
	_tecla(KEY_E)
	await _cuadros(3)
	_verificar(not panel.visible and maquina.inventario[1] == 0 and despacho.puntuacion.puntos == 950, "E cancela un producto listo sin cobrar")
	_tecla(KEY_E)
	await _cuadros(3)
	_tecla(KEY_3)
	await _cuadros(100)
	_verificar(maquina.producto_listo and maquina.producto_en_entrega == 2, "Atajo 3 acciona B1")
	await _clic(panel.boton_retirar)
	_verificar(maquina.inventario[2] == 1 and despacho.puntuacion.puntos == 800, "RETIRA entrega la papa y cobra una sola vez")
	await _clic(panel.botones[3])
	await _cuadros(100)
	despacho.puntuacion.gastar_puntos(800)
	await _clic(panel.boton_recoger)
	_verificar(not panel.visible and maquina.inventario[3] == 0 and despacho.puntuacion.puntos == 0, "Perder el saldo pendiente no regala el producto")
	despacho.puntuacion.sumar_puntos_debug(500)
	_tecla(KEY_E)
	await _cuadros(5)
	for dimensiones: Vector2i in [Vector2i(960, 540), Vector2i(1024, 768)]:
		root.size = dimensiones
		await _cuadros(5)
		for boton: Button in panel.botones:
			_verificar(panel.get_global_rect().encloses(boton.get_global_rect()), "Botón físico accesible a %s" % dimensiones)
		_verificar(panel.get_global_rect().encloses(panel.boton_retirar.get_global_rect()), "RETIRA accesible a %s" % dimensiones)
		await _captura("04_%dx%d" % [dimensiones.x, dimensiones.y])
	await _clic(panel.botones[1])
	jugador.reset_to_spawn()
	await _cuadros(100)
	_verificar(not panel.visible and not jugador.input_locked and despacho.puntuacion.puntos == 500, "Reinicio cancela la entrega y libera el control")
	_verificar(maquina.inventario[0] == 1 and maquina.inventario[2] == 1, "Reinicio conserva las compras ya recogidas")
	jugador.global_position = origen
	jugador.visual.rotation.y = -PI / 2.0
	await _cuadros(5)
	_tecla(KEY_E)
	await _cuadros(5)
	await _clic(panel.botones[1])
	jugador.global_position += Vector3.RIGHT * 5.0
	await _cuadros(5)
	_verificar(not panel.visible and despacho.puntuacion.puntos == 500, "Alejarse cancela sin cobrar")
	jugador.global_position = origen
	await _cuadros(5)
	_tecla(KEY_E)
	await _cuadros(5)
	await _clic(panel.botones[1])
	despacho.terminada = true
	despacho.partida_terminada.emit()
	await _cuadros(5)
	_verificar(not panel.visible and maquina.producto_en_entrega == -1 and maquina.inventario == [0, 0, 0, 0], "Final limpia la entrega y el inventario")
	paused = false
	oficina.queue_free()
	await _cuadros(8)
	print("[PANEL EXPENDEDORA] %d comprobaciones, %d errores" % [comprobaciones, errores])
	quit(0 if errores == 0 else 1)


func _clic(boton: Button) -> void:
	await _cuadros(3)
	var centro := boton.get_global_rect().get_center()
	Input.warp_mouse(centro)
	await _cuadros(3)
	var mover := InputEventMouseMotion.new()
	mover.position = centro
	mover.global_position = centro
	Input.parse_input_event(mover)
	Input.flush_buffered_events()
	await _cuadros(2)
	for pulsado: bool in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.position = centro
		evento.global_position = centro
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.pressed = pulsado
		Input.parse_input_event(evento)
		Input.flush_buffered_events()
		await _cuadros(2)


func _captura(nombre: String) -> void:
	if not "--capturas" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	await _cuadros(4)
	await RenderingServer.frame_post_draw
	var carpeta := "res://.godot/expendedora_panel_qa"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta))
	root.get_texture().get_image().save_png(carpeta.path_join(nombre + ".png"))
