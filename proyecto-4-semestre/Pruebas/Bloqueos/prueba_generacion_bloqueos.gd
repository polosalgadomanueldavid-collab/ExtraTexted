extends SceneTree
## --headless --path <proyecto> --script res://Pruebas/Bloqueos/prueba_generacion_bloqueos.gd
## Regresión: un borde físicamente libre no debe dejar la oficina sin cajones.

var _oficina: Node3D
var _jugador: CharacterBody3D
var _grafo: GrafoPiso
var _errores: Array[String] = []
var _comprobaciones: int = 0


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	_oficina = (load("res://Oficina.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_oficina)
	await _fisicas(3)
	(_oficina.get("temporizador_denuncias") as Timer).stop()
	(_oficina.get("temporizador_bloqueos") as Timer).stop()
	(_oficina.get("computador").get("timer_nuevo_problema") as Timer).stop()
	await _fisicas(60)
	_jugador = _oficina.get("jugador") as CharacterBody3D
	_grafo = _oficina.get("grafo_piso") as GrafoPiso
	_verificar(_jugador.is_on_floor(), "El personaje se apoya en el suelo real de Oficina")
	var altura := _jugador.global_position.y + 0.02
	_jugador.set_physics_process(false)
	(_oficina.get_node("Gameplay/Camera3D") as Camera3D).set_physics_process(false)
	var despacho := _oficina.get("sistema_despacho") as SistemaDespacho
	despacho.set_process(false)
	var caso := Denuncia.new()
	caso.id = "REGRESION-CAJONES"
	caso.protocolo_estaciones = ["bienestar"]
	despacho.recibir_denuncia(caso)
	despacho.iniciar_denuncia_prioritaria()

	# Estos bordes admiten físicamente al personaje, pero su celda completa
	# está bloqueada por el AABB de las mesas. Antes generaban cero cajones.
	var bordes: Array[Vector2] = [
		Vector2(-3.5, 0.7), Vector2(-1.6, 0.9), Vector2(0.4, 5.4),
		Vector2(-2.4, 5.7), Vector2(-2.5, 6.8)
	]
	for borde: Vector2 in bordes:
		await _probar_posicion(Vector3(borde.x, altura, borde.y), true)
	for celda: Vector2i in [Vector2i(7, 6), Vector2i(7, 20), Vector2i(12, 16)]:
		var posicion := _grafo.celda_a_posicion(celda)
		posicion.y = altura
		await _probar_posicion(posicion, false)

	despacho.resolver_denuncia(caso.id)
	await _probar_espacio_limitado()
	_oficina.queue_free()
	await process_frame
	print("[BLOQUEOS] %d comprobaciones, %d errores." % [_comprobaciones, _errores.size()])
	quit(0 if _errores.is_empty() else 1)


func _probar_posicion(posicion: Vector3, borde: bool) -> void:
	_oficina.call("_limpiar_bloqueos_temporales")
	await _fisicas(2)
	_jugador.global_position = posicion
	_jugador.velocity = Vector3.ZERO
	_verificar(_posicion_libre(), "La posición de prueba %s es físicamente libre" % posicion)
	var celda_original := _grafo.posicion_a_celda(posicion)
	_verificar(_grafo.es_transitable(celda_original) != borde, "La posición %s tiene la ocupación lógica esperada" % posicion)
	for semilla: int in [927, 951, 1307]:
		(_oficina.get("generador_aleatorio") as RandomNumberGenerator).seed = semilla
		_oficina.call("_cambiar_bloqueo_temporal")
		await _fisicas(2)
		var cantidad := _grafo.bloqueos_temporales.size()
		_verificar(cantidad > 0 and cantidad <= 30, "%s / %d coloca cajones sin superar el objetivo" % [posicion, semilla])
		_verificar((_oficina.get("bloqueos_visuales") as Dictionary).size() == cantidad, "Los cajones físicos coinciden con el grafo")
		_verificar(_posicion_libre(), "Ningún cajón invade el cuerpo real del jugador")
		var alcanzables := _grafo.celdas_alcanzables(GrafoPiso.DESTINOS["computador"])
		for destino: Vector2i in GrafoPiso.DESTINOS.values():
			_verificar(alcanzables.has(destino), "Se conserva acceso a la estación %s" % destino)
		for celda: Vector2i in _grafo.bloqueos_temporales:
			_verificar(not _grafo.es_zona_segura(celda), "La zona de descanso queda libre")
		var ruta: Array[Vector2i] = _oficina.get("ruta_actual")
		_verificar(not ruta.is_empty() and ruta.back() == GrafoPiso.DESTINOS["bienestar"], "La denuncia activa conserva una ruta desde el borde del jugador")
		if borde:
			_verificar(not _grafo.es_transitable(celda_original), "La proyección de acceso no abre la celda ocupada por la mesa")


func _probar_espacio_limitado() -> void:
	_oficina.call("_limpiar_bloqueos_temporales")
	await _fisicas(2)
	# Mapa controlado: un pasillo protegido y solo tres huecos de generación.
	var limitado := GrafoPiso.new()
	var libres: Array[Vector2i] = [Vector2i(7, 15)]
	for x: int in range(4, 11):
		libres.append(Vector2i(x, 14))
	var huecos: Array[Vector2i] = [Vector2i(5, 13), Vector2i(7, 13), Vector2i(9, 13)]
	libres.append_array(huecos)
	limitado.bloqueos_fijos.clear()
	for fila: int in range(GrafoPiso.FILAS):
		for columna: int in range(GrafoPiso.COLUMNAS):
			var celda := Vector2i(columna, fila)
			if not libres.has(celda):
				limitado.bloqueos_fijos[celda] = true
	limitado.construir_adyacencia()
	_oficina.set("grafo_piso", limitado)
	(_oficina.get("depurador_grafo") as GrafoDebugVisual).grafo = limitado
	_jugador.global_position = limitado.celda_a_posicion(Vector2i(7, 15)) + Vector3.UP * _jugador.global_position.y
	_oficina.call("_cambiar_bloqueo_temporal")
	_verificar(limitado.bloqueos_temporales.size() == 3, "Si solo caben tres cajones, conserva los tres en vez de vaciar el mapa")
	_verificar(not limitado.calcular_ruta(Vector2i(7, 15), Vector2i(4, 14)).is_empty(), "La distribución parcial conserva el pasillo de salida")
	_oficina.call("_limpiar_bloqueos_temporales")
	for celda: Vector2i in huecos:
		limitado.bloqueos_fijos[celda] = true
	_oficina.call("_cambiar_bloqueo_temporal")
	_verificar(limitado.bloqueos_temporales.is_empty(), "Sin ningún hueco disponible no invade la zona segura para forzar una mesa")
	_oficina.set("grafo_piso", _grafo)
	(_oficina.get("depurador_grafo") as GrafoDebugVisual).grafo = _grafo


func _posicion_libre() -> bool:
	var colision := _jugador.get_node("Colision") as CollisionShape3D
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = colision.shape
	consulta.transform = colision.global_transform
	consulta.collision_mask = 1
	consulta.exclude = [_jugador.get_rid()]
	return _jugador.get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty()


func _fisicas(cantidad: int) -> void:
	for i: int in range(cantidad):
		await physics_frame
		await process_frame


func _verificar(condicion: bool, descripcion: String) -> void:
	_comprobaciones += 1
	if not condicion:
		_errores.append(descripcion)
		push_error("[BLOQUEOS] " + descripcion)
