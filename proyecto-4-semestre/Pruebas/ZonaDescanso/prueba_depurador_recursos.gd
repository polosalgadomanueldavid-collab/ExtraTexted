extends "res://Pruebas/ZonaDescanso/prueba_interacciones_descanso.gd"

func _probar() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.get_node("MenuGlobal").omitir_tutorial_siguiente_partida = true
	await _cargar()
	_oficina.temporizador_eventos.stop()
	_oficina.anuncios.detener()
	_saldo_y_calma(200, 80)
	var panel: CanvasLayer = _oficina.depurador_recursos
	_verificar(not panel.visible, "El depurador temporal comienza oculto")
	await _tecla(KEY_F4)
	_verificar(not panel.visible, "F4 no abre sin activar F3")
	await _tecla(KEY_F3)
	await _tecla(KEY_F4)
	_verificar(panel.visible and _jugador.input_locked, "F3 y F4 abren el panel y bloquean el personaje")
	panel.cantidad_mesas.get_line_edit().text = "7"
	panel.boton_mesas.pressed.emit()
	_verificar(_oficina.cantidad_mesas_objetivo() == 12 and _oficina.bloqueos_visuales.size() == 12, "Añadir mesas aplica la cantidad escrita")
	panel.cantidad_mesas.get_line_edit().text = "30"
	panel.boton_mesas.pressed.emit()
	_verificar(_oficina.cantidad_mesas_objetivo() == 30 and panel.boton_mesas.disabled, "El depurador limita las mesas al máximo original")
	var ganados := _despacho.puntuacion.puntos_ganados
	panel.cantidad_puntos.get_line_edit().text = "12345"
	panel.boton_puntos.pressed.emit()
	_verificar(_despacho.puntuacion.puntos == 12545, "El valor escrito se añade exactamente al saldo")
	_verificar(_despacho.puntuacion.puntos_ganados == ganados, "Los puntos de prueba no alteran la clasificación")
	panel.cantidad_dano.get_line_edit().text = "23"
	panel.boton_dano.pressed.emit()
	_verificar(_despacho.calma_operativa == 57, "El daño escrito descuenta la calma real")
	panel.cantidad_dano.get_line_edit().text = "18"
	panel.boton_vida.pressed.emit()
	_verificar(_despacho.calma_operativa == 75, "Añadir vida aplica la cantidad escrita al jugador local")
	panel.cantidad_dano.get_line_edit().text = "100"
	panel.boton_vida.pressed.emit()
	_verificar(_despacho.calma_operativa == 100 and panel.boton_vida.disabled, "La recuperación se limita a 100 y muestra la vida completa")
	var maquina = _oficina.get_node("MaquinaExpendedora")
	panel.botones_items[2].pressed.emit()
	_verificar(maquina.inventario == [0, 0, 1, 0], "Elegir Papa tiempo solo entrega ese ítem")
	panel.dar_item(2)
	panel.dar_item(-1)
	panel.dar_item(4)
	_verificar(maquina.inventario == [0, 0, 1, 0], "No duplica cargas ni acepta índices inválidos")
	panel.boton_todos.pressed.emit()
	_verificar(maquina.inventario == [1, 1, 1, 1] and panel.boton_todos.disabled, "Añadir todos completa el bolsillo y actualiza los botones")
	_verificar(_despacho.puntuacion.puntos == 12545 and _despacho.puntuacion.puntos_ganados == ganados, "Los ítems de prueba no cuestan saldo ni alteran la clasificación")
	paused = true
	maquina.inventario[0] = 0
	panel.dar_todos()
	_verificar(maquina.inventario[0] == 0, "El depurador no entrega objetos durante una pausa")
	paused = false
	_probar_bolsillo_lan(panel, maquina)
	panel.dar_todos()
	for dimensiones: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1024, 768)]:
		root.size = dimensiones
		await _cuadros(4)
		var caja: Rect2 = panel.panel.get_global_rect()
		_verificar(root.get_visible_rect().encloses(caja), "El depurador cabe en %s" % dimensiones)
		if "--capturas" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/depurador_recursos_%dx%d.png" % [dimensiones.x, dimensiones.y])
	await _tecla(KEY_ESCAPE)
	_verificar(not panel.visible and not _jugador.input_locked and not paused, "Escape devuelve control sin pausar")
	maquina.inventario[0] = 0
	panel.dar_item(0)
	_verificar(maquina.inventario[0] == 0, "El depurador cerrado no entrega ítems")
	await _tecla(KEY_F4)
	panel.dar_item(0)
	await _tecla(KEY_ESCAPE)
	_verificar(maquina.usar(0), "El chocolate obtenido desde el depurador se puede usar al salir")
	await _cuadros(100)
	_verificar(maquina.inventario[0] == 0 and _jugador.chocolate_restante > 0, "El ítem de prueba activa su efecto y se consume normalmente")
	await _tecla(KEY_F4)
	await _tecla(KEY_F3)
	_verificar(not panel.visible and not _oficina.depurador_grafo.visible_debug, "F3 cierra ambos depuradores")
	await _tecla(KEY_F3)
	await _tecla(KEY_F4)
	panel.cantidad_dano.get_line_edit().text = "100"
	panel.quitar_vida()
	await _cuadros(4)
	_verificar(_despacho.terminada and _despacho.calma_operativa == 0 and not panel.visible, "Llegar a cero termina la partida y cierra el depurador")
	var saldo := _despacho.puntuacion.puntos
	panel.dar_puntos()
	_verificar(_despacho.puntuacion.puntos == saldo, "El depurador cerrado no añade puntos")
	panel.dar_vida()
	panel.dar_todos()
	_verificar(_despacho.calma_operativa == 0 and maquina.inventario == [0, 0, 0, 0], "El depurador no revive ni entrega ítems después del final")
	await _finalizar()


func _probar_bolsillo_lan(panel: CanvasLayer, maquina: Node) -> void:
	var sesion := root.get_node("SesionLAN")
	var puente = load("res://Scripts/Red/partida_lan.gd").new()
	puente.oficina = _oficina
	puente.despacho = _despacho
	puente.bolsillos = {1: [0, 0, 0, 0], 2: [0, 0, 0, 0]}
	sesion.puente = puente
	sesion.en_partida = true
	panel.dar_item(0)
	_verificar(maquina.inventario[0] == 0, "La sesión sin autoridad de anfitrión no concede ítems")
	sesion.activa = true
	panel.dar_item(0)
	_verificar(maquina.inventario[0] == 1 and puente.bolsillos[1] == [1, 0, 0, 0], "El regalo del anfitrión se registra en su bolsillo de LAN")
	_verificar(puente.bolsillos[2] == [0, 0, 0, 0], "Regalarse un ítem no modifica el bolsillo del compañero")
	_verificar(puente._consumir(1, 0, -1).ok and puente.bolsillos[1][0] == 0, "La autoridad de LAN acepta consumir el ítem concedido")
	sesion.en_partida = false
	sesion.activa = false
	sesion.puente = null
	puente.free()
