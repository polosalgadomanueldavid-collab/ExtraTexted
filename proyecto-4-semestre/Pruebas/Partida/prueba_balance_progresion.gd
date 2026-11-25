extends "res://Pruebas/ZonaDescanso/prueba_interacciones_descanso.gd"
## --headless --fixed-fps 60 --script res://Pruebas/Partida/prueba_balance_progresion.gd

func _probar() -> void:
	root.get_node("MenuGlobal").omitir_tutorial_siguiente_partida = true
	await _cargar()
	_oficina.temporizador_eventos.stop()
	_despacho.set_process(false)
	_oficina.set_process(false)
	_verificar(_oficina.cantidad_mesas_objetivo() == 5, "La partida comienza con cinco mesas")
	_oficina._cambiar_bloqueo_temporal()
	_verificar(_oficina.bloqueos_visuales.size() == 5, "Se colocan físicamente cinco mesas")
	_oficina.tiempo_progresion_mesas = 250.0
	_verificar(_oficina.cantidad_mesas_objetivo() == 15, "Diez intervalos añaden diez mesas")
	_oficina._cambiar_bloqueo_temporal()
	_verificar(_oficina.bloqueos_visuales.size() == 15, "La distribución crece con la partida")
	_oficina.agregar_mesas_debug(100)
	_verificar(_oficina.cantidad_mesas_objetivo() == 30 and _oficina.bloqueos_visuales.size() <= 30, "El debugger respeta el máximo original")
	var alcanzables: Dictionary = _oficina.grafo_piso.celdas_alcanzables(_oficina.grafo_piso.celda_de_acceso(_jugador.global_position))
	for destino: Vector2i in GrafoPiso.DESTINOS.values():
		_verificar(alcanzables.has(destino), "El máximo conserva acceso a %s" % destino)
	_oficina.tiempo_progresion_mesas = 0.0
	_oficina.mesas_extra_debug = 0
	var pendiente := Denuncia.new()
	pendiente.id = "QA-COLA"
	pendiente.tiempo_limite_segundos = 600.0
	_despacho.recibir_denuncia(pendiente)
	_probar_ritmo(1.0, "Normal")
	_oficina.evento_apagon.estado = _oficina.evento_apagon.Estado.APAGADO
	_probar_ritmo(0.25, "Apagón")
	_oficina.evento_apagon.estado = _oficina.evento_apagon.Estado.RESTAURADO
	_oficina.evento_terremoto.etapa = _oficina.evento_terremoto.Etapa.AVISO
	_probar_ritmo(0.5, "Terremoto")
	_oficina.evento_terremoto.etapa = _oficina.evento_terremoto.Etapa.INACTIVO
	for evento: Node in [_oficina.evento_incendio, _oficina.evento_inundacion, _oficina.evento_lava, _oficina.evento_hielo]:
		evento.activo = true
		_probar_ritmo(0.25 if evento == _oficina.evento_incendio else 0.5, str(evento.name))
		evento.activo = false
	_despacho.tiempo_detenido = true
	var antes: float = _despacho.obtener_tiempo_restante(_caso.id)
	_despacho.actualizar_tiempos(60.0)
	_verificar(is_equal_approx(antes, _despacho.obtener_tiempo_restante(_caso.id)), "Papa Tiempo sigue deteniendo todo el plazo")
	_despacho.tiempo_detenido = false
	for i in 30:
		_oficina._programar_siguiente_denuncia()
		_verificar(_oficina.temporizador_denuncias.wait_time >= 15.0 and _oficina.temporizador_denuncias.wait_time <= 23.0, "La cadencia solo aumenta tres segundos")
	_oficina.temporizador_denuncias.stop()
	_oficina._recibir_denuncia_aleatoria()
	var nuevo: Denuncia
	for caso: Denuncia in _despacho.obtener_denuncias_ordenadas():
		if caso.id != _caso.id and caso.id != pendiente.id:
			nuevo = caso
	_verificar(nuevo != null and nuevo.tiempo_limite_segundos >= 150.0, "El nuevo caso incluye margen por la cola")
	await _finalizar()


func _probar_ritmo(ritmo: float, contexto: String) -> void:
	var activo := _despacho.obtener_tiempo_restante(_caso.id)
	var pendiente := _despacho.obtener_tiempo_restante("QA-COLA")
	_despacho.actualizar_tiempos(20.0)
	_verificar(is_equal_approx(activo - _despacho.obtener_tiempo_restante(_caso.id), 20.0 * ritmo), contexto + " aplica el ritmo del evento")
	_verificar(is_equal_approx(pendiente - _despacho.obtener_tiempo_restante("QA-COLA"), 10.0 * ritmo), contexto + " protege la espera en cola")
