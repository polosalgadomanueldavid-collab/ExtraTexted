extends SceneTree
## --headless --fixed-fps 60 --script res://Pruebas/Tuberias/prueba_tuberias.gd
const Tuberia := preload("res://Eventos/Tuberias/tuberia_rompible.gd")
var errores := 0


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	for nitrogeno: bool in [false, true]:
		var tubo := Tuberia.new()
		tubo.nitrogeno = nitrogeno
		root.add_child(tubo)
		var pose := tubo.tramo.transform
		_verificar(not tubo.chorro.emitting and tubo.estado == Tuberia.Estado.SANA, "Sin fuga antes del evento")
		if not nitrogeno:
			_verificar(not tubo.abierto and is_zero_approx(tubo.puerta.rotation.y), "La puerta de agua empieza cerrada")
			tubo.establecer_abierto(true)
			await _cuadros(6)
			var angulo := tubo.puerta.rotation.y
			_verificar(angulo < 0 and angulo > deg_to_rad(tubo.ANGULO_PUERTA), "La puerta gira gradualmente alrededor de la bisagra")
			paused = true
			await _cuadros(12)
			_verificar(tubo.puerta.rotation.y == angulo, "La pausa detiene la puerta")
			paused = false
			await _cuadros(24)
			_verificar(is_equal_approx(tubo.puerta.rotation.y, deg_to_rad(tubo.ANGULO_PUERTA)), "La tapa abre completamente sin mover el gabinete")
			tubo.establecer_abierto(false)
			await _cuadros(24)
			_verificar(is_zero_approx(tubo.puerta.rotation.y) and not tubo.abierto, "La tapa vuelve a cerrar")
		tubo.romper()
		await _cuadros(8)
		_verificar(not tubo.chorro.emitting and tubo.apertura == 0.0, "La presión precede a la fractura")
		await _cuadros(15)
		_verificar(tubo.chorro.emitting and tubo.nube.emitting and tubo.apertura > 0.0 and tubo.apertura < 1.0, "Apertura gradual con descarga desde la junta")
		var apertura_pausa := tubo.apertura
		var pose_pausa := tubo.tramo.transform
		paused = true
		await _cuadros(10)
		_verificar(tubo.apertura == apertura_pausa and tubo.tramo.transform == pose_pausa, "La pausa detiene la fractura")
		paused = false
		await _cuadros(40)
		_verificar(tubo.estado == Tuberia.Estado.ROTA and not tubo.tramo.transform.is_equal_approx(pose), "El tramo queda visiblemente separado")
		var origen := tubo.salida.global_position
		var origen_emision := tubo.chorro.global_position
		tubo.position += Vector3(1, 0.2, 2)
		_verificar(tubo.salida.global_position.is_equal_approx(origen + Vector3(1, 0.2, 2)) and tubo.chorro.global_position.is_equal_approx(origen_emision + Vector3(1, 0.2, 2)), "Mover la tubería arrastra la boca y el emisor")
		tubo.sellar()
		_verificar(not tubo.chorro.emitting and not tubo.nube.emitting, "Reparar corta ambos emisores")
		await _cuadros(25)
		_verificar(tubo.apertura > 0 and tubo.apertura < 1, "La reparación devuelve el tramo gradualmente")
		await _cuadros(75)
		_verificar(tubo.estado == Tuberia.Estado.SANA and tubo.tramo.transform.is_equal_approx(pose) and not tubo.chorro.visible, "La reparación restaura exactamente la pose y limpia los efectos")
		tubo.romper()
		await _cuadros(5)
		tubo.sellar()
		await _cuadros(100)
		_verificar(tubo.estado == Tuberia.Estado.SANA and not tubo.chorro.emitting, "Reparar antes de la descarga no deja una emisión pendiente")
		tubo.romper()
		await _cuadros(20)
		tubo.restablecer()
		await _cuadros(60)
		_verificar(tubo.tramo.transform.is_equal_approx(pose) and not tubo.chorro.emitting, "Cancelar durante la rotura no deja animaciones pendientes")
		tubo.queue_free()
		await process_frame
	# El origen del frente de hielo debe salir del modelo, incluso si cambia de lugar.
	var menu := root.get_node("MenuGlobal")
	menu.omitir_tutorial_siguiente_partida = true
	var oficina: Node3D = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	await _cuadros(80)
	menu.cerrar_ayuda()
	oficina.tutoriales_vistos[&"hielo"] = true
	oficina.tutoriales_vistos[&"inundacion"] = true
	oficina.temporizador_denuncias.stop()
	oficina.temporizador_eventos.stop()
	oficina.temporizador_bloqueos.stop()
	await _probar_colisiones(oficina)
	var hielo = oficina.evento_hielo
	for i in 2400:
		if hielo.nieve_preparada:
			break
		await _cuadros(1)
	hielo.tuberia.position.z -= 0.15
	_verificar(hielo.iniciar(), "Inicia Hielo en la oficina real")
	var origen_real: Vector3 = hielo.tuberia.salida.global_position
	var origen_shader: Vector2 = hielo._material.get_shader_parameter("origen")
	_verificar(origen_shader.is_equal_approx(Vector2(origen_real.x, origen_real.z)), "El frente de congelación nace en la boca actual, sin coordenadas antiguas")
	await _cuadros(60)
	_verificar(hielo._fuga.emitting, "La fuga acompaña al evento de congelación")
	hielo.resolver_con_avatar()
	_verificar(not hielo.activo and hielo.tuberia.estado == Tuberia.Estado.SANA and not hielo._fuga.emitting, "La resolución alternativa también restaura la instalación")
	# Ejecutar la ruta receptora real sin abrir sockets ni una segunda partida.
	var puente := load("res://Scripts/Red/partida_lan.gd").new() as Node
	puente.oficina = oficina
	for tipo: String in ["inundacion", "hielo"]:
		var evento: Node = oficina.get("evento_" + tipo)
		var iniciado: bool = evento.iniciar()
		_verificar(iniciado, "Reinicia " + tipo + " para comprobar reparación remota")
		if not iniciado:
			continue
		await _cuadros(50)
		oficina.jugador.global_position = evento.acceso.global_position
		oficina.jugador.velocity = Vector3.ZERO
		oficina.jugador.visual.rotation.y = PI * 0.5
		await _cuadros(8)
		_verificar(oficina.jugador.obtener_objetivo_interaccion() == evento, "La hitbox permite interactuar con " + tipo)
		if tipo == "inundacion":
			evento.interactuar(oficina.jugador)
			await _cuadros(24)
			_verificar(evento.reparando and evento.tuberias.abierto, "Entrar al puzzle abre la puerta de agua")
			evento.panel.cerrar()
			await _cuadros(24)
			_verificar(not evento.reparando and not evento.tuberias.abierto and is_zero_approx(evento.tuberias.puerta.rotation.y), "Salir del puzzle cierra la puerta sin detener la inundación")
		puente.aplicar_evento("reparado", {"objetivo": tipo})
		var visual: Node = evento.tuberias if tipo == "inundacion" else evento.tuberia
		_verificar(visual.estado == Tuberia.Estado.SELLANDO and not visual.chorro.emitting and not visual.nube.emitting, "La reparación recibida por LAN sella " + tipo)
		evento.detener()
	puente.free()
	oficina.queue_free()
	await _cuadros(3)
	print("[TUBERIAS] %d errores" % errores)
	quit(1 if errores else 0)


func _probar_colisiones(oficina: Node3D) -> void:
	var jugador: CharacterBody3D = oficina.jugador
	var posicion_original := jugador.global_position
	jugador.set_physics_process(false)
	var pared: CSGBox3D = oficina.get_node("Pared, suelo, techo/Pared3")
	var limites_pared: AABB = pared.global_transform * AABB(-pared.size * 0.5, pared.size)
	for tubo: Node3D in [oficina.evento_inundacion.tuberias, oficina.evento_hielo.tuberia]:
		var forma: CollisionShape3D = tubo.cuerpo.get_child(0)
		var limites: AABB = forma.global_transform * AABB(-forma.shape.size * 0.5, forma.shape.size)
		_verificar(absf(limites.end.x - limites_pared.position.x) < 0.005, "El respaldo queda pegado a la pared: " + tubo.name)
		for fase: String in ["sana", "rota", "reparada"]:
			if fase == "rota":
				tubo.romper()
				await _cuadros(50)
			elif fase == "reparada":
				tubo.sellar()
				await _cuadros(100)
			jugador.global_position = Vector3(1.25, 0.38, tubo.global_position.z)
			var choque: KinematicCollision3D
			for paso in 90:
				await physics_frame
				choque = jugador.move_and_collide(Vector3(0.025, 0, 0))
				if choque != null:
					break
			_verificar(choque != null and tubo.is_ancestor_of(choque.get_collider()) and jugador.global_position.x < limites.position.x, "El jugador real choca de frente con la caja " + fase + ": " + tubo.name)
		# Intento lateral junto a la pared, equivalente al paso de las capturas del usuario.
		jugador.global_position = Vector3(limites.get_center().x, 0.38, limites.end.z + 0.3)
		var lateral: KinematicCollision3D
		for paso in 30:
			await physics_frame
			lateral = jugador.move_and_collide(Vector3(0, 0, -0.025))
			if lateral != null:
				break
		_verificar(lateral != null and tubo.is_ancestor_of(lateral.get_collider()), "La caja también bloquea el paso lateral junto a la pared: " + tubo.name)
		if is_instance_valid(tubo.puerta):
			tubo.establecer_abierto(true, true)
			await physics_frame
			var tapa: StaticBody3D = tubo.puerta.get_node("ColisionPuerta")
			var centro := tapa.global_position
			var normal := tapa.global_basis.z.normalized()
			var rayo := PhysicsRayQueryParameters3D.create(centro + normal * 0.3, centro - normal * 0.3, 1, [jugador.get_rid()])
			var impacto := tubo.get_world_3d().direct_space_state.intersect_ray(rayo)
			_verificar(not impacto.is_empty() and impacto.collider == tapa, "La colisión de la tapa acompaña su apertura")
			tubo.establecer_abierto(false, true)
	jugador.global_position = posicion_original
	jugador.velocity = Vector3.ZERO
	jugador.set_physics_process(true)


func _cuadros(cantidad: int) -> void:
	for i in cantidad:
		await process_frame


func _verificar(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("[OK] ", mensaje)
	else:
		errores += 1
		push_error(mensaje)
