extends "res://Pruebas/ZonaDescanso/prueba_interacciones_descanso.gd"
## --headless --fixed-fps 60 --script res://Pruebas/Partida/prueba_balance_progresion.gd

func _probar() -> void:
	root.get_node("MenuGlobal").omitir_tutorial_siguiente_partida = true
	await _cargar()
	_oficina.temporizador_eventos.stop()
	_despacho.set_process(false)
	_oficina.set_process(false)
	_verificar(_oficina.cantidad_mesas_objetivo() == 10, "La partida comienza con diez mesas")
	_verificar(_oficina.bloqueos_visuales.size() == 10, "Hay diez mesas colocadas antes de la primera denuncia automática")
	_verificar(_oficina.contador_denuncias == 0, "La distribución inicial no espera ni genera una denuncia")
	_oficina.tiempo_progresion_mesas = 75.0
	_verificar(_oficina.cantidad_mesas_objetivo() == 15, "Cinco intervalos añaden cinco mesas")
	_oficina._cambiar_bloqueo_temporal()
	_verificar(_oficina.bloqueos_visuales.size() == 15, "La distribución crece con la partida")
	_oficina.agregar_mesas_debug(100)
	_verificar(_oficina.cantidad_mesas_objetivo() == 30 and _oficina.bloqueos_visuales.size() <= 30, "El debugger respeta el máximo original")
	var alcanzables: Dictionary = _oficina.grafo_piso.celdas_alcanzables(_oficina.grafo_piso.celda_de_acceso(_jugador.global_position))
	for destino: Vector2i in GrafoPiso.DESTINOS.values():
		_verificar(alcanzables.has(destino), "El máximo conserva acceso a %s" % destino)
	_oficina.tiempo_progresion_mesas = 0.0
	_oficina.mesas_extra_debug = 0
	_oficina._cambiar_bloqueo_temporal()
	var pendiente := Denuncia.new()
	pendiente.id = "QA-COLA"
	pendiente.tiempo_limite_segundos = 600.0
	_despacho.recibir_denuncia(pendiente)
	_probar_ritmo(1.0, "Normal")
	_oficina.evento_apagon.estado = _oficina.evento_apagon.Estado.APAGADO
	_probar_ritmo(1.0, "Apagón")
	_oficina.evento_apagon.estado = _oficina.evento_apagon.Estado.RESTAURADO
	_oficina.evento_terremoto.etapa = _oficina.evento_terremoto.Etapa.AVISO
	_probar_ritmo(1.0, "Terremoto")
	_oficina.evento_terremoto.etapa = _oficina.evento_terremoto.Etapa.INACTIVO
	for evento: Node in [_oficina.evento_incendio, _oficina.evento_inundacion, _oficina.evento_lava, _oficina.evento_hielo]:
		evento.activo = true
		_probar_ritmo(1.0, str(evento.name))
		evento.activo = false
	_despacho.tiempo_detenido = true
	var antes: float = _despacho.obtener_tiempo_restante(_caso.id)
	_despacho.actualizar_tiempos(60.0)
	_verificar(is_equal_approx(antes, _despacho.obtener_tiempo_restante(_caso.id)), "Papa Tiempo sigue deteniendo todo el plazo")
	_despacho.tiempo_detenido = false
	for i in 30:
		_oficina._programar_siguiente_denuncia()
		_verificar(_oficina.temporizador_denuncias.wait_time >= 11.0 and _oficina.temporizador_denuncias.wait_time <= 19.0, "La cadencia individual corresponde a diez mesas")
	_oficina.temporizador_denuncias.stop()
	_oficina.tiempo_progresion_mesas = 300.0
	_oficina._cambiar_bloqueo_temporal()
	_oficina._recibir_denuncia_aleatoria()
	var nuevo: Denuncia
	for caso: Denuncia in _despacho.obtener_denuncias_ordenadas():
		if caso.id != _caso.id and caso.id != pendiente.id:
			nuevo = caso
	var plazos := {"D-001": 140.0, "D-002": 120.0, "D-003": 100.0, "D-004": 85.0, "D-005": 70.0, "D-006": 120.0}
	for plantilla: Denuncia in _oficina.catalogo_denuncias:
		_verificar(is_equal_approx(plantilla.tiempo_limite_segundos, plazos[plantilla.id]), plantilla.id + " conserva el plazo original más treinta segundos")
	_verificar(nuevo != null and is_equal_approx(nuevo.tiempo_limite_segundos, plazos[nuevo.id.substr(0, 5)]), "Ni la cola ni treinta mesas añaden tiempo al caso")
	_probar_balance_duo(plazos)
	_probar_densidad_y_niveles()
	await _finalizar()


func _probar_balance_duo(plazos: Dictionary) -> void:
	_oficina.tiempo_progresion_mesas = 0.0
	_oficina._cambiar_bloqueo_temporal()
	var catalogo: Array[Denuncia] = _oficina.catalogo_denuncias.duplicate()
	_despacho.configurar_jugadores([1, 2], 1)
	_verificar(_despacho.hay_duo_activo() and _despacho.max_casos_en_proceso == 2, "Dos policías activos usan el balance dúo y pueden tramitar dos casos")
	for plantilla: Denuncia in catalogo:
		_oficina.catalogo_denuncias.assign([plantilla])
		_oficina._recibir_denuncia_aleatoria()
		var id := "%s-%03d" % [plantilla.id, _oficina.contador_denuncias]
		var caso := _despacho.arbol.buscar_por_id(id)
		_verificar(caso != null and is_equal_approx(caso.tiempo_limite_segundos, plazos[plantilla.id] - 15.0), plantilla.id + " usa original más quince segundos en dúo")
		_verificar(is_equal_approx(_despacho.obtener_tiempo_restante(id), plazos[plantilla.id] - 15.0), "El reloj real recibe el plazo del dúo")
		_verificar(is_equal_approx(plantilla.tiempo_limite_segundos, plazos[plantilla.id]), "El dúo conserva el recurso individual intacto")
		_despacho.resolver_denuncia(id)
	for i in 20:
		_oficina._programar_siguiente_denuncia()
		_verificar(_oficina.temporizador_denuncias.wait_time >= 7.0 and _oficina.temporizador_denuncias.wait_time <= 15.0, "El dúo recibe casos según las diez mesas iniciales")
	var tiempo_existente := _despacho.obtener_tiempo_restante(_caso.id)
	_despacho.perder_calma(100, &"prueba", 2)
	_verificar(not _despacho.hay_duo_activo() and not _despacho.terminada, "El superviviente vuelve al balance individual")
	_verificar(is_equal_approx(tiempo_existente, _despacho.obtener_tiempo_restante(_caso.id)), "El cambio de balance no reinicia relojes existentes")
	_oficina._recibir_denuncia_aleatoria()
	var id := "%s-%03d" % [catalogo.back().id, _oficina.contador_denuncias]
	var caso := _despacho.arbol.buscar_por_id(id)
	_verificar(caso != null and is_equal_approx(caso.tiempo_limite_segundos, plazos[catalogo.back().id]), "El superviviente recibe el plazo individual en el siguiente caso")
	_verificar(_oficina.temporizador_denuncias.wait_time >= 11.0 and _oficina.temporizador_denuncias.wait_time <= 19.0, "El superviviente recupera la cadencia individual")
	_oficina.catalogo_denuncias.assign(catalogo)
	_oficina.temporizador_denuncias.stop()
	_oficina.temporizador_eventos.stop()


func _probar_densidad_y_niveles() -> void:
	# Las comprobaciones anteriores dejan casos activos: liberar capacidad
	# para comprobar llegadas reales, sin que el máximo de cola las suprima.
	for caso: Denuncia in _despacho.obtener_denuncias_ordenadas():
		_despacho.resolver_denuncia(caso.id)
	var catalogo: Array[Denuncia] = _oficina.catalogo_denuncias.duplicate()
	for ids: Array in [[1], [1, 2]]:
		_despacho.configurar_jugadores(ids, 1)
		var anterior := 0.0
		for cantidad: int in [10, 15, 24, 25, 30]:
			_oficina.tiempo_progresion_mesas = (cantidad - 10) * 15.0
			_oficina._cambiar_bloqueo_temporal()
			_verificar(_oficina.bloqueos_visuales.size() == cantidad, "La prueba usa la densidad física de %d mesas" % cantidad)
			var balance: Dictionary = _oficina._balance_denuncias()
			var minimo := (4.0 if ids.size() == 2 else 8.0) + (cantidad - 5) * 0.6
			_verificar(is_equal_approx(balance.llegada_min, minimo) and is_equal_approx(balance.llegada_max, minimo + 8.0), "La cadencia se adapta a mesas y modo")
			_verificar(balance.llegada_min > anterior, "Más mesas reducen las misiones por minuto")
			anterior = balance.llegada_min
			_oficina._programar_siguiente_denuncia()
			_verificar(_oficina.temporizador_denuncias.wait_time >= minimo and _oficina.temporizador_denuncias.wait_time <= minimo + 8.0, "El temporizador usa el intervalo de la densidad real")
			var disponibles: Array[Denuncia] = _oficina._catalogo_denuncias_para_mesas()
			if cantidad <= 24:
				_verificar(disponibles.size() == catalogo.size(), "Hasta veinticuatro mesas siguen disponibles todos los niveles")
			else:
				_verificar(disponibles.size() == 3, "Desde veinticinco mesas solo quedan los tres casos de nivel alto")
				for plantilla: Denuncia in disponibles:
					_verificar(plantilla.nivel_riesgo >= 3, "El filtro excluye niveles uno y dos")
				for i in 10:
					_oficina._recibir_denuncia_aleatoria()
					var casos := _despacho.obtener_denuncias_ordenadas()
					_verificar(casos.size() == 1 and casos[0].nivel_riesgo >= 3, "La llegada real respeta el filtro de nivel")
					for caso: Denuncia in casos:
						_despacho.resolver_denuncia(caso.id)
	# Catálogo personalizado sin candidatos: no crear un caso prohibido ni fallar.
	_oficina.catalogo_denuncias.assign([catalogo[0]])
	var contador: int = _oficina.contador_denuncias
	_oficina._recibir_denuncia_aleatoria()
	_verificar(_oficina.contador_denuncias == contador and _despacho.obtener_denuncias_ordenadas().is_empty(), "Sin niveles admisibles no se generan casos prohibidos")
	_oficina.catalogo_denuncias.assign(catalogo)
	_oficina.temporizador_denuncias.stop()
	_oficina.temporizador_eventos.stop()


func _probar_ritmo(ritmo: float, contexto: String) -> void:
	var activo := _despacho.obtener_tiempo_restante(_caso.id)
	var pendiente := _despacho.obtener_tiempo_restante("QA-COLA")
	_despacho.actualizar_tiempos(20.0)
	_verificar(is_equal_approx(activo - _despacho.obtener_tiempo_restante(_caso.id), 20.0 * ritmo), contexto + " mantiene el reloj normal del caso activo")
	_verificar(is_equal_approx(pendiente - _despacho.obtener_tiempo_restante("QA-COLA"), 20.0 * ritmo), contexto + " mantiene el reloj normal en cola")
