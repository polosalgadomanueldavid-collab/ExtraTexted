extends SceneTree
## --headless --fixed-fps 60 --script res://Pruebas/Lava/prueba_lava.gd

var oficina: Node3D
var jugador
var lava: Node3D
var errores := 0


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	var menu := root.get_node("MenuGlobal")
	menu.omitir_tutorial_siguiente_partida = true
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	await _fisicas(70)
	menu.cerrar_ayuda()
	jugador = oficina.jugador
	lava = oficina.evento_lava
	oficina.generador_aleatorio.seed = 9526
	oficina._recibir_denuncia_aleatoria()
	oficina.temporizador_denuncias.stop()
	oficina.computador.timer_nuevo_problema.stop()
	oficina.sistema_despacho.set_process(false)
	oficina.temporizador_bloqueos.stop()
	oficina.temporizador_eventos.stop()
	oficina.anuncios.detener()
	oficina._limpiar_bloqueos_temporales()
	jugador.global_position = Vector3(-1.5, 0.38, 3.2)
	jugador.velocity = Vector3.ZERO
	await _fisicas(10)
	var salto_original: float = jugador.jump_velocity
	var mascara_original: int = jugador.collision_mask
	_verificar(jugador.is_on_floor(), "El policía comienza apoyado en el piso real")
	jugador.input_locked = true
	_verificar(not oficina._iniciar_lava(), "Una interacción aplaza el inicio de lava")
	jugador.input_locked = false
	oficina._evento_aleatorio_pendiente = 4
	oficina._intentar_evento_aleatorio()
	_verificar(lava.activo and jugador.lava_activa, "El sorteo compartido inicia lava y activa el salto alto")
	_verificar(lava.charcos.size() == 6 and lava.panel.visible, "Aparecen seis charcos y el reloj visible")
	_verificar(is_equal_approx(lava.tiempo_restante, 60.0), "El reloj comienza en un minuto")
	_verificar(oficina.temporizador_bloqueos.wait_time == 4.0, "Los bloqueos cambian cada cuatro segundos")
	_verificar(not oficina._puede_iniciar_evento() and not oficina.evento_inundacion.iniciar() and not oficina.evento_incendio.iniciar(oficina.bloqueos_visuales) and not oficina.evento_apagon.iniciar_apagon(), "Los otros eventos rechazan solaparse con lava")
	lava.set_physics_process(false)
	oficina.temporizador_bloqueos.stop()
	var calma: int = oficina.sistema_despacho.calma_operativa
	lava._physics_process(1.5)
	_verificar(oficina.sistema_despacho.calma_operativa == calma and not jugador.quemandose_pies and is_equal_approx(lava._material.get_shader_parameter("presencia"), 0.5), "La entrada revela el magma gradualmente y da tiempo para reaccionar sin daño")
	lava._physics_process(1.5)
	_verificar(oficina.sistema_despacho.calma_operativa == calma and is_equal_approx(lava._material.get_shader_parameter("presencia"), 1.0), "La propagación dura tres segundos antes de comenzar el daño")
	lava._physics_process(2.0)
	_verificar(oficina.sistema_despacho.calma_operativa == calma - 1 and jugador.quemandose_pies, "Dos segundos sobre magma quitan cordura y activan los pies quemados")
	await _fisicas(20)
	_verificar(jugador.gestos._peso_quemadura > 0.9, "La pose de pies quemados se mezcla sobre el esqueleto")
	var diferencia_pies := 0.0
	for i in 30:
		await _fisicas(1)
		diferencia_pies = maxf(diferencia_pies, absf(jugador.gestos.posicion_pie("L").y - jugador.gestos.posicion_pie("R").y))
	_verificar(diferencia_pies > 0.08, "Las rodillas alternan con una elevación visible de los pies")
	lava._physics_process(0.0)
	_verificar(lava._llamas_pies[0].global_position.distance_to(jugador.gestos.posicion_pie("L") + Vector3.DOWN * 0.025) < 0.001, "Las llamas siguen la pose final del pie y no se quedan pegadas al piso")
	var charco: Vector3 = lava.charcos[0]
	jugador.global_position = Vector3(charco.x, 0.38, charco.y)
	jugador.velocity = Vector3.ZERO
	await _fisicas(10)
	calma = oficina.sistema_despacho.calma_operativa
	lava._perdida_acumulada = 0.0
	lava._physics_process(2.0)
	_verificar(oficina.sistema_despacho.calma_operativa == calma - 2, "El charco quita más cordura que el piso en el mismo tiempo")
	var forma: Dictionary = lava._patron.formas[0]
	_verificar(forma.placas.size() == 3 and forma.islas.size() == 3, "El núcleo funde tres placas del piso y conserva tres islas de costra")
	var dano_ramal := false
	var borde_ramal := false
	for tramo: Dictionary in forma.ramales:
		var medio: Vector2 = tramo.a.lerp(tramo.b, 0.5)
		var en_nucleo := false
		for placa: PackedVector2Array in forma.placas:
			en_nucleo = en_nucleo or Geometry2D.is_point_in_polygon(medio, placa)
		if en_nucleo or (tramo.ancho_a + tramo.ancho_b) * 0.5 < 0.025:
			continue
		var perpendicular: Vector2 = (tramo.b - tramo.a).normalized().orthogonal()
		var lado: Vector2 = medio + perpendicular * ((tramo.ancho_a + tramo.ancho_b) * 0.5 + 0.07)
		dano_ramal = dano_ramal or lava.en_charco(Vector3(medio.x, 0.38, medio.y))
		borde_ramal = borde_ramal or not lava.en_charco(Vector3(lado.x, 0.38, lado.y))
	_verificar(dano_ramal and borde_ramal, "Los ramales queman fuera del núcleo, y la roca junto a ellos no recibe daño extra")
	var costra_caliente := true
	for isla: PackedVector2Array in forma.islas:
		var centro_isla := Vector2.ZERO
		for vertice in isla:
			centro_isla += vertice / float(isla.size())
		costra_caliente = costra_caliente and lava.en_charco(Vector3(centro_isla.x, 0.38, centro_isla.y))
	_verificar(costra_caliente, "Las islas de costra son parte del charco caliente; solo los bloqueos ofrecen refugio")
	jugador.global_position = Vector3(-1.5, 2.5, 3.2)
	jugador.velocity = Vector3.ZERO
	await _fisicas(2)
	calma = oficina.sistema_despacho.calma_operativa
	lava._physics_process(1.0)
	_verificar(oficina.sistema_despacho.calma_operativa == calma and not jugador.quemandose_pies, "En el aire no se pierde cordura ni se queman los pies")
	_verificar(jugador.gestos._peso_quemadura > 0.1, "La pose de quemadura no se corta de golpe al despegar")
	await _fisicas(45)
	_verificar(jugador.gestos._peso_quemadura < 0.02, "La reacción se desvanece suavemente al dejar de quemarse")
	# Salto real desde el suelo hacia un cajón con la entrada normal del jugador.
	var celda := Vector2i(6, 6)
	oficina._mostrar_bloqueo_temporal(celda)
	var cajon: StaticBody3D = oficina.bloqueos_visuales[celda]
	var direccion: Vector3 = jugador._camera_relative_direction(Vector2.RIGHT)
	jugador.global_position = cajon.global_position - direccion * 0.66 + Vector3.UP * 0.01
	jugador.velocity = Vector3.ZERO
	await _fisicas(10)
	Input.action_press(jugador.JUMP)
	Input.action_press(jugador.RIGHT)
	await _fisicas(2)
	Input.action_release(jugador.JUMP)
	var altura_maxima: float = jugador.global_position.y
	for i in 29:
		await physics_frame
		altura_maxima = maxf(altura_maxima, jugador.global_position.y)
	Input.action_release(jugador.RIGHT)
	await _fisicas(36)
	_verificar(altura_maxima > cajon.global_position.y + 0.91, "El salto supera la altura física del bloqueo")
	_verificar(absf(altura_maxima - (0.3717 + 0.91 * 1.10)) < 0.012, "La cima real del salto es la altura del bloqueo más un diez por ciento")
	_verificar(lava.sobre_bloqueo_temporal(), "El policía aterriza y permanece sobre el bloqueo temporal")
	calma = oficina.sistema_despacho.calma_operativa
	lava._physics_process(3.0)
	_verificar(oficina.sistema_despacho.calma_operativa == calma and lava.panel.seguro, "El bloqueo protege la cordura y el HUD confirma el refugio")
	# La barrera ocupa el espacio por encima de una mesa real; solo capa de jugador.
	await _fisicas(2)
	var barrera := lava._barreras.get_child(0) as StaticBody3D
	var caja := barrera.get_child(0) as CollisionShape3D
	var centro := barrera.global_position
	var origen := centro + Vector3(caja.shape.size.x * 0.5 + 0.6, 0, 0)
	var consulta := PhysicsRayQueryParameters3D.create(origen, centro, 128)
	_verificar(not jugador.get_world_3d().direct_space_state.intersect_ray(consulta).is_empty(), "Una mesa lateral bloquea el paso incluso por encima de su tablero")
	jugador.global_position = Vector3(origen.x, 0.38, origen.z)
	jugador.velocity = Vector3.ZERO
	await _fisicas(10)
	Input.action_press(jugador.JUMP)
	Input.action_press(jugador.LEFT)
	await _fisicas(2)
	Input.action_release(jugador.JUMP)
	var choco_barrera := false
	for i in 65:
		await physics_frame
		for j in jugador.get_slide_collision_count():
			var cuerpo: Node = jugador.get_slide_collision(j).get_collider()
			if cuerpo.collision_layer == 128:
				choco_barrera = true
	Input.action_release(jugador.LEFT)
	_verificar(choco_barrera and jugador.global_position.x > centro.x + caja.shape.size.x * 0.5, "Un salto real choca con la barrera y no permite subir a la mesa lateral")
	var mesas_accesibles := true
	for foco: Node3D in oficina.evento_incendio.focos:
		if foco.estacion_id.is_empty() or foco.estacion_id == "computador":
			continue
		var encontrada := false
		for desplazamiento: float in [0.0, 0.5, -0.5]:
			jugador.global_position = foco.acceso.global_position
			jugador.velocity = Vector3.ZERO
			var hacia: Vector3 = foco.cuerpo.to_global(Vector3(desplazamiento, 0, 0)) - jugador.global_position
			hacia.y = 0.0
			jugador.visual.rotation.y = atan2(hacia.x, hacia.z)
			for paso in 80:
				jugador.move_and_collide(hacia.normalized() * 0.015)
				if jugador.obtener_objetivo_interaccion() == foco.cuerpo:
					encontrada = true
					break
			if encontrada:
				break
		mesas_accesibles = mesas_accesibles and encontrada
	_verificar(mesas_accesibles, "Las barreras conservan la interacción con las estaciones desde sus accesos")
	jugador.global_position = cajon.global_position + Vector3.UP * 0.92
	jugador.velocity = Vector3.ZERO
	await _fisicas(5)
	# Reciclaje real: retirar el apoyo debe dejar caer al policía, sin cajón nuevo dentro.
	oficina._cambiar_bloqueo_temporal()
	await _fisicas(60)
	_verificar(jugador.is_on_floor() and jugador.global_position.y < 0.5 and lava.tocando_suelo(), "Al cambiar los bloqueos se pierde el refugio y se vuelve al piso")
	var reloj: float = lava.tiempo_restante
	lava.set_physics_process(true)
	paused = true
	await _fisicas(60)
	_verificar(is_equal_approx(lava.tiempo_restante, reloj), "La pausa congela la cuenta regresiva y el daño")
	paused = false
	lava.tiempo_restante = 0.05
	await _fisicas(6)
	_verificar(not lava.activo and not jugador.lava_activa and not lava.panel.visible, "El evento termina automáticamente y retira el HUD")
	_verificar(oficina.anuncios.detalle.is_empty(), "El anuncio final no muestra el subtítulo sobre salto e intervalo")
	_verificar(jugador.jump_velocity == salto_original and jugador.collision_mask == mascara_original, "Se recuperan exactamente el salto y las capas originales")
	_verificar(oficina.temporizador_bloqueos.wait_time == 10.0 and oficina.temporizador_bloqueos.is_stopped(), "Se restaura el intervalo original y el estado detenido previo")
	_verificar(oficina.temporizador_eventos.time_left >= 39.0, "El final programa la espera compartida del siguiente evento")
	_verificar(lava.charcos.is_empty() and lava.get_child_count() == 0, "No quedan magma, partículas ni barreras tras terminar")
	# Medir el minuto completo y el reciclaje automático, sin adelantar el reloj.
	oficina.temporizador_bloqueos.start(10.0)
	_verificar(oficina._iniciar_lava(), "El evento puede repetirse limpiamente")
	var cambios: Array[int] = [0]
	var contar := func() -> void: cambios[0] += 1
	oficina.temporizador_bloqueos.timeout.connect(contar)
	await _fisicas(235)
	_verificar(cambios[0] == 0, "La distribución se conserva antes de cumplir cuatro segundos")
	var espera_bloqueos: float = oficina.temporizador_bloqueos.time_left
	reloj = lava.tiempo_restante
	calma = oficina.sistema_despacho.calma_operativa
	paused = true
	await _fisicas(60)
	_verificar(is_equal_approx(espera_bloqueos, oficina.temporizador_bloqueos.time_left) and is_equal_approx(reloj, lava.tiempo_restante) and calma == oficina.sistema_despacho.calma_operativa, "La pausa congela juntos el minuto, los cuatro segundos y la cordura")
	paused = false
	await _fisicas(10)
	_verificar(cambios[0] == 1, "El temporizador redistribuye realmente los bloqueos a los cuatro segundos")
	await _fisicas(3345)
	_verificar(lava.activo and lava.tiempo_restante < 0.3 and cambios[0] == 14, "El evento sigue activo justo antes del minuto con catorce cambios")
	await _fisicas(20)
	_verificar(not lava.activo and not oficina.temporizador_bloqueos.is_stopped() and oficina.temporizador_bloqueos.wait_time == 10.0, "A los sesenta segundos termina y vuelve a cambiar bloqueos cada diez segundos")
	oficina.temporizador_bloqueos.timeout.disconnect(contar)
	# Final por calor: una señal, sin denuncias vencidas falsas ni recuperación posterior.
	_verificar(oficina._iniciar_lava(), "Un tercer inicio funciona después del minuto completo")
	lava._physics_process(3.0)
	oficina.sistema_despacho.calma_operativa = 1
	lava._perdida_acumulada = 0.0
	lava._physics_process(2.0)
	_verificar(oficina.partida_finalizada and oficina.sistema_despacho.terminada and not lava.activo, "La pérdida de cordura puede terminar la partida y limpia el evento")
	_verificar(oficina.final_partida._datos.causa.get("lava", false) and oficina.sistema_despacho.recuperar_calma(15) == 0, "El final identifica la lava y no permite revivir con calma")
	paused = false
	oficina.queue_free()
	await process_frame
	print("[LAVA] %d errores" % errores)
	quit(1 if errores else 0)


func _fisicas(cantidad: int) -> void:
	for i in cantidad:
		await physics_frame


func _verificar(condicion: bool, texto: String) -> void:
	if condicion:
		print("[OK] " + texto)
	else:
		errores += 1
		push_error(texto)
