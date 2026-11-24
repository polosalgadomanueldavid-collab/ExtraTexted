extends "res://Pruebas/ZonaDescanso/prueba_expendedora.gd"
## --headless --fixed-fps 60 --script res://Pruebas/Lava/prueba_mesas_no_trepables.gd

func _probar() -> void:
	root.get_node("MenuGlobal").omitir_tutorial_siguiente_partida = true
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	await _cuadros(70)
	root.get_node("MenuGlobal").cerrar_ayuda()
	paused = false
	jugador = oficina.jugador
	despacho = oficina.sistema_despacho
	despacho.set_process(false)
	oficina.tutoriales_vistos[&"lava"] = true
	_parar_relojes()
	oficina.anuncios.detener()
	oficina._limpiar_bloqueos_temporales()
	var lava: Node = oficina.evento_lava
	var barreras: Node3D = lava._barreras
	var cantidad := barreras.get_child_count()
	_verificar(cantidad > 0, "Las barreras existen antes del primer evento de lava")
	for modo: String in ["dona", "lava", "lava y dona", "dona después de lava"]:
		jugador.global_position = Vector3(-1.5, 0.38, 3.2)
		jugador.velocity = Vector3.ZERO
		if modo == "lava":
			_verificar(lava.iniciar(), "Se inicia lava para comprobar el salto")
			lava.set_physics_process(false)
			oficina.anuncios.detener()
			_parar_relojes()
		elif modo == "dona después de lava":
			lava.detener()
			_parar_relojes()
		for foco: Node3D in oficina.evento_incendio.focos:
			if foco.estacion_id.is_empty() or foco.estacion_id == "computador":
				continue
			await _saltar_hacia_estacion(foco, modo)
		_verificar(lava._barreras == barreras and barreras.get_child_count() == cantidad, "No se duplican ni retiran barreras: " + modo)
	await _saltar_a_cajon()
	jugador.dona_restante = 0.0
	jugador.reset_to_spawn()
	await _cuadros(3)
	_verificar(jugador.get_collision_mask_value(8), "Reiniciar conserva la protección de las mesas")
	oficina.queue_free()
	await _cuadros(4)
	print("[MESAS NO TREPABLES] %d comprobaciones, %d errores" % [comprobaciones, errores])
	quit(0 if errores == 0 else 1)


func _saltar_hacia_estacion(foco: Node3D, modo: String) -> void:
	var forma := foco.cuerpo.get_node("CollisionShape3D") as CollisionShape3D
	var limites: AABB = forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
	var centro := limites.get_center()
	var acceso: Vector3 = foco.acceso.global_position - centro
	var exterior := Vector3(signf(acceso.x), 0, 0) if absf(acceso.x) > absf(acceso.z) else Vector3(0, 0, signf(acceso.z))
	var distancia: float = absf(exterior.x) * limites.size.x * 0.5 + absf(exterior.z) * limites.size.z * 0.5 + 0.6
	var inicio := centro + exterior * distancia
	jugador.global_position = Vector3(inicio.x, 0.38, inicio.z)
	jugador.velocity = Vector3.ZERO
	jugador.dona_restante = 10.0 if modo != "lava" else 0.0
	await _cuadros(10)
	var accion: StringName = jugador.RIGHT
	var alineacion := -INF
	var direcciones := {jugador.RIGHT: Vector2.RIGHT, jugador.LEFT: Vector2.LEFT, jugador.FORWARD: Vector2.UP, jugador.BACK: Vector2.DOWN}
	for candidata: StringName in direcciones:
		var producto: float = jugador._camera_relative_direction(direcciones[candidata]).dot(-exterior)
		if producto > alineacion:
			alineacion = producto
			accion = candidata
	Input.action_press(jugador.JUMP)
	Input.action_press(accion)
	await _cuadros(2)
	Input.action_release(jugador.JUMP)
	var choco := false
	var aterrizo := false
	for paso in 70:
		await process_frame
		for i in jugador.get_slide_collision_count():
			var cuerpo = jugador.get_slide_collision(i).get_collider()
			if cuerpo is StaticBody3D and cuerpo.get_collision_layer_value(8):
				choco = true
		if jugador.is_on_floor() and jugador.global_position.y > 0.7:
			aterrizo = true
		# Caducar durante el salto tampoco debe abrir la barrera.
		if paso == 16 and modo == "dona después de lava":
			jugador.dona_restante = 0.0
	Input.action_release(accion)
	_verificar(choco and not aterrizo and jugador.global_position.y < 0.5, "%s no permite quedarse en la estación %s" % [modo, foco.estacion_id])
	jugador.visual.rotation.y = atan2(-exterior.x, -exterior.z)
	await _cuadros(2)
	_verificar(jugador.obtener_objetivo_interaccion() == foco.cuerpo, "La estación %s sigue accesible con E: %s" % [foco.estacion_id, modo])


func _saltar_a_cajon() -> void:
	var celda := Vector2i(6, 6)
	oficina._mostrar_bloqueo_temporal(celda)
	var cajon: StaticBody3D = oficina.bloqueos_visuales[celda]
	var direccion: Vector3 = jugador._camera_relative_direction(Vector2.RIGHT)
	jugador.global_position = cajon.global_position - direccion * 0.66 + Vector3.UP * 0.01
	jugador.velocity = Vector3.ZERO
	jugador.dona_restante = 10.0
	await _cuadros(10)
	Input.action_press(jugador.JUMP)
	Input.action_press(jugador.RIGHT)
	await _cuadros(2)
	Input.action_release(jugador.JUMP)
	await _cuadros(29)
	Input.action_release(jugador.RIGHT)
	await _cuadros(50)
	_verificar(oficina.evento_lava.sobre_bloqueo_temporal(), "La dona conserva el salto y el apoyo sobre cajones temporales")
