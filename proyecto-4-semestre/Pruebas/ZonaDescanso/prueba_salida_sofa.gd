extends "res://Pruebas/ZonaDescanso/prueba_interacciones_descanso.gd"
## Godot --headless --fixed-fps 60 --script res://Pruebas/ZonaDescanso/prueba_salida_sofa.gd
## Mantiene la física y la tecla de movimiento activas al sentarse contra el mueble.

func _probar() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	await _cargar()
	_saldo_y_calma(200, 50)
	var tramos: Dictionary = {}
	for z: float in [7.55, 7.65, 7.85]:
		await _probar_contacto_sostenido(z, tramos)
	_verificar(tramos.has("AsientoTramo") and tramos.has("AsientoRetorno"), "La regresión cubre ambos tramos del sofá en L")
	await _probar_salida_local_bloqueada()
	await _probar_pulsaciones_rapidas()
	print("[SALIDA SOFA] %d comprobaciones, %d errores." % [_comprobaciones, _errores.size()])
	await _finalizar()


func _probar_contacto_sostenido(z: float, tramos: Dictionary) -> void:
	_jugador.global_position = Vector3(-2.7, _altura + 0.02, z)
	_jugador.velocity = Vector3.ZERO
	_jugador.set_physics_process(true)
	Input.action_press(&"policia_prueba_izquierda")
	await _fisicas(80)
	var entrada := _jugador.global_position
	_jugador.visual.rotation.y = -PI / 2.0
	_verificar(_jugador.obtener_objetivo_interaccion() == _sofa, "Caminar contra el sofá permite alcanzarlo en z=%.2f" % z)
	# No soltar antes: la recuperación física posterior al contacto ocultaba el fallo.
	await _tecla(KEY_E)
	Input.action_release(&"policia_prueba_izquierda")
	await _esperar_estado("sentado", true, 2.0)
	_verificar(_estado().sentado, "E sienta al jugador mientras empuja el sofá en z=%.2f" % z)
	if not _estado().sentado:
		return
	for nombre: String in ["AsientoTramo", "AsientoRetorno"]:
		var marcador := _zona.get_node("SofaL/" + nombre) as Marker3D
		if _jugador.global_position.distance_to(marcador.global_position) < 0.01:
			tramos[nombre] = true
	var asiento := _jugador.global_position
	await _tecla(KEY_E)
	await _esperar_estado("sentado", false, 2.0)
	await _fisicas(30)
	var final := _jugador.global_position
	_verificar(not _estado().sentado and not _jugador.input_locked, "Levantarse devuelve el control con la física activa en z=%.2f" % z)
	_verificar(final.distance_to(entrada) < 0.20, "Levantarse cerca del borde vuelve junto al punto de entrada en z=%.2f (desplazamiento %.3f m)" % [z, final.distance_to(entrada)])
	_verificar(final.distance_to(asiento) < 0.80, "La salida permanece junto al asiento en z=%.2f (distancia %.3f m)" % [z, final.distance_to(asiento)])
	_verificar(_cabe_jugador(final), "La salida local queda fuera de las colisiones en z=%.2f" % z)
	_verificar(_jugador.is_on_floor() and _jugador.velocity.length() < 0.01, "Tras levantarse el jugador queda estable sobre el suelo en z=%.2f" % z)


func _probar_salida_local_bloqueada() -> void:
	_jugador.global_position = Vector3(-2.7, _altura + 0.02, 7.65)
	_jugador.velocity = Vector3.ZERO
	Input.action_press(&"policia_prueba_izquierda")
	await _fisicas(80)
	_jugador.visual.rotation.y = -PI / 2.0
	await _tecla(KEY_E)
	Input.action_release(&"policia_prueba_izquierda")
	await _esperar_estado("sentado", true, 2.0)
	var asiento := _jugador.global_position
	# Ocupa únicamente el entorno del sofá. El marcador distante sigue libre;
	# usarlo como salida sería precisamente el salto que se quiere evitar.
	var obstaculo := StaticBody3D.new()
	var colision := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(3.0, 1.2, 2.0)
	colision.shape = caja
	obstaculo.add_child(colision)
	obstaculo.position = Vector3(-3.55, _altura + 0.6, 7.45)
	_oficina.add_child(obstaculo)
	await _fisicas(2)
	_verificar(not _zona.levantarse(), "Sin espacio local, levantarse rechaza la salida en vez de usar un destino lejano")
	await _fisicas(30)
	_verificar(_estado().sentado and _jugador.input_locked and _jugador.global_position.distance_to(asiento) < 0.01, "La salida ocupada mantiene al personaje sentado y estable")
	obstaculo.queue_free()
	await _fisicas(2)
	if _estado().sentado:
		await _tecla(KEY_E)
		await _esperar_estado("sentado", false, 2.0)
	await _fisicas(30)
	_verificar(not _estado().sentado and not _jugador.input_locked and _cabe_jugador(_jugador.global_position), "Despejar la salida permite levantarse normalmente")


func _probar_pulsaciones_rapidas() -> void:
	_jugador.global_position = Vector3(-2.7, _altura + 0.02, 7.65)
	_jugador.velocity = Vector3.ZERO
	var capa := _jugador.collision_layer
	var mascara := _jugador.collision_mask
	Input.action_press(&"policia_prueba_izquierda")
	await _fisicas(80)
	var entrada := _jugador.global_position
	_jugador.visual.rotation.y = -PI / 2.0
	await _tecla(KEY_E)
	Input.action_release(&"policia_prueba_izquierda")
	_verificar(_jugador.esta_sentado() and not _estado().sentado, "La segunda E se prueba antes de completar la entrada al asiento")
	await _tecla(KEY_E)
	# Repetir E durante el movimiento de salida no puede lanzar otro tween.
	await _tecla(KEY_E)
	await _tecla(KEY_E)
	await _esperar_estado("sentado", false, 2.0)
	await _fisicas(30)
	_verificar(not _jugador.esta_sentado() and not _jugador.input_locked, "Pulsar E rápidamente no deja bloqueado al personaje en la transición")
	_verificar(_jugador.global_position.distance_to(entrada) < 0.20, "Cancelar la entrada al asiento mantiene la salida junto al punto de origen")
	_verificar(_jugador.collision_layer == capa and _jugador.collision_mask == mascara and _cabe_jugador(_jugador.global_position), "Las pulsaciones rápidas restauran las colisiones sin dejar al personaje dentro del sofá")
