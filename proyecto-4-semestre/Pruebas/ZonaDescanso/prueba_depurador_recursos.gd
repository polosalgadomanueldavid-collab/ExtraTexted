extends "res://Pruebas/ZonaDescanso/prueba_interacciones_descanso.gd"

func _probar() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
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
	var ganados := _despacho.puntuacion.puntos_ganados
	panel.cantidad_puntos.get_line_edit().text = "12345"
	panel.boton_puntos.pressed.emit()
	_verificar(_despacho.puntuacion.puntos == 12545, "El valor escrito se añade exactamente al saldo")
	_verificar(_despacho.puntuacion.puntos_ganados == ganados, "Los puntos de prueba no alteran la clasificación")
	panel.cantidad_dano.get_line_edit().text = "23"
	panel.boton_dano.pressed.emit()
	_verificar(_despacho.calma_operativa == 57, "El daño escrito descuenta la calma real")
	await _tecla(KEY_ESCAPE)
	_verificar(not panel.visible and not _jugador.input_locked and not paused, "Escape devuelve control sin pausar")
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
	await _finalizar()
