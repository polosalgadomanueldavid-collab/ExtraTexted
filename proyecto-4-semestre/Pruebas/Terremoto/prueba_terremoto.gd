extends SceneTree
## --headless --fixed-fps 60 --script res://Pruebas/Terremoto/prueba_terremoto.gd

const Grieta := preload("res://Eventos/Terremoto/grieta.gd")
var oficina: Node3D
var evento: Node3D
var jugador: CharacterBody3D
var grafo: GrafoPiso
var errores := 0
var intensidad := 0.0
var instante_rotura := -1.0


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	var menu := root.get_node("MenuGlobal")
	menu.omitir_tutorial_siguiente_partida = true
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	await _fisicas(5)
	menu.cerrar_ayuda()
	oficina.tutoriales_vistos[&"terremoto"] = true
	jugador = oficina.jugador
	evento = oficina.evento_terremoto
	grafo = oficina.grafo_piso
	evento.temblor_actualizado.connect(func(_t: float, valor: float) -> void: intensidad = valor)
	evento.suelo_roto.connect(func() -> void: instante_rotura = evento.tiempo)
	evento._azar.seed = 8762
	oficina.generador_aleatorio.seed = 1414
	oficina._recibir_denuncia_aleatoria()
	# Acortar solo la espera de esta prueba; el reloj compartido se cubre aparte.
	oficina._evento_aleatorio_pendiente = 0
	oficina.temporizador_eventos.start(1.0)
	oficina.temporizador_denuncias.stop()
	oficina.computador.timer_nuevo_problema.stop()
	var antes: Dictionary = oficina.bloqueos_visuales.duplicate()
	var mesa_fija := oficina.get_node("Mesas verticales IZQ/Table_017") as Node3D
	var original := mesa_fija.global_transform
	await _fisicas(65)
	_verificar(evento.activo and evento.etapa == evento.Etapa.AVISO, "El reloj aleatorio inicia el aviso")
	if not evento.activo:
		quit(1)
		return
	_verificar(jugador.voz.stream == jugador.voz.estres, "El policía expresa estrés al primer temblor")
	var plazo_evento: float = evento.tiempo
	paused = true
	await _fisicas(12)
	_verificar(is_equal_approx(plazo_evento, evento.tiempo), "El terremoto respeta la pausa de la partida")
	paused = false
	_verificar(intensidad > 0.0 and intensidad < 0.2, "La cámara empieza con un temblor leve")
	var iniciales: float = oficina.temporizador_bloqueos.time_left
	await _hasta(4.0)
	_verificar(intensidad > 0.5 and intensidad < 0.65, "A mitad del aviso aumenta el tambaleo")
	var camara := oficina.get_node("Gameplay/Camera3D") as Camera3D
	var desplazamiento: Vector2 = camara._temblor
	await _fisicas(2)
	_verificar(not desplazamiento.is_zero_approx() and not desplazamiento.is_equal_approx(camara._temblor),
		"La cámara recibe el movimiento continuo durante el aviso")
	await _hasta(7.95)
	_verificar(intensidad > 0.99 and grafo.grietas.is_empty() and evento.grietas.is_empty(), "El suelo sigue entero hasta el pico")
	_verificar(antes == oficina.bloqueos_visuales and is_equal_approx(iniciales, oficina.temporizador_bloqueos.time_left),
		"Las mesas y su reloj se congelan desde el aviso")
	for trazada in evento._trazado:
		var p := Vector3(trazada.centro.x, evento._altura, trazada.centro.y)
		_verificar(not _suelo_bajo(p).is_empty(), "El futuro hueco aún soporta al jugador")
	await _hasta(8.10)
	_verificar(is_equal_approx(instante_rotura, 8.0) and evento.etapa == evento.Etapa.RUPTURA and evento.grietas.size() >= 4,
		"Se abren al menos cuatro rasgaduras juntas en el segundo ocho")
	for celda in grafo.grietas:
		_verificar(grafo.es_celda_valida(celda) and not grafo.es_zona_segura(celda), "La rasgadura está en el área de juego")
	var congelado: Dictionary = oficina.bloqueos_visuales.duplicate()
	var restantes: float = oficina.temporizador_bloqueos.time_left
	_verificar(restantes > 0.0 and oficina.temporizador_bloqueos.paused, "Se pausa el reloj de bloqueos")
	var caidas := 0
	for celda: Vector2i in antes:
		var p := grafo.celda_a_posicion(celda)
		var toca := false
		for grieta in evento.grietas:
			toca = toca or grieta.toca_cuadro(Vector2(p.x, p.z), 0.31)
		var bloque: StaticBody3D = antes[celda]
		if toca:
			caidas += 1
			_verificar(bloque.collision_layer == 0 and not congelado.has(celda), "Cae el bloqueo colindante")
		else:
			_verificar(bloque.collision_layer == 1 and congelado.get(celda) == bloque, "Permanece el bloqueo apartado")
	_verificar(caidas > 0 and mesa_fija.global_transform == original, "Solo se derriban bloqueos aleatorios")
	oficina._on_temporizador_bloqueos_timeout()
	await _fisicas(48)
	_verificar(congelado == oficina.bloqueos_visuales and is_equal_approx(restantes, oficina.temporizador_bloqueos.time_left), "La distribución y su plazo permanecen congelados")
	var rutas := grafo.celdas_alcanzables(grafo.celda_de_acceso(jugador.global_position))
	for destino: Vector2i in GrafoPiso.DESTINOS.values():
		_verificar(rutas.has(destino), "Se puede rodear las rasgaduras para llegar a %s" % destino)
	var grande: Grieta = evento.grietas[0]
	var centro := Vector3(grande.centro.x, evento._altura, grande.centro.y)
	for grieta in evento.grietas:
		var p := Vector3(grieta.centro.x, evento._altura, grieta.centro.y)
		_verificar(_suelo_bajo(p).is_empty(), "La colisión del suelo tiene un agujero real en %s" % p)
	var despacho: SistemaDespacho = oficina.sistema_despacho
	var caso := despacho.iniciar_denuncia_prioritaria()
	var calma := despacho.calma_operativa
	var papel := load("res://Scripts/Despacho/papel_denuncia.gd").new() as RigidBody3D
	papel.denuncia_id = caso.id
	oficina.add_child(papel)
	oficina.papel_actual = papel
	papel.tomar(jugador)
	# La denuncia se pierde al entrar en la grieta, antes del rescate del personaje.
	jugador.global_position = centro + Vector3.UP * 0.03
	for i in range(20):
		await _fisicas(1)
		if caso.estado == Denuncia.Estado.VENCIDA:
			break
	_verificar(caso.motivo_perdida == Denuncia.MotivoPerdida.TERREMOTO and jugador.global_position.y < evento._altura - 0.025 and jugador.global_position.y > evento._altura - 0.55,
		"Caer con la hoja pierde el caso en cuanto entra en la grieta, antes de regresar a tierra")
	_verificar(jugador.papel_en_mano == null and oficina.papel_actual == null and despacho.obtener_denuncia_activa() == null,
		"La caída retira la hoja de la mano y cierra la denuncia activa")
	await _fisicas(43)
	_verificar(jugador.is_on_floor() and despacho.calma_operativa == calma - caso.penalidad_calma,
		"El rescate devuelve al jugador a tierra y aplica una sola penalización por el caso perdido")
	caso = _recibir_caso_con_hoja("TERREMOTO-HOJA-LANZADA")
	papel = oficina.papel_actual
	calma = despacho.calma_operativa
	jugador.global_position = Vector3(centro.x, evento._altura + 0.01, _borde_sur(grande) + 0.09)
	jugador.visual.rotation.y = PI
	await _fisicas(3)
	# Mismo gesto, anclaje e impulso que usa el jugador al pulsar E.
	jugador.ejecutar_gesto(&"lanzar", papel.lanzar)
	await _fisicas(90)
	_verificar(caso.motivo_perdida == Denuncia.MotivoPerdida.TERREMOTO and despacho.obtener_denuncia_activa() == null,
		"La hoja suelta que cae pierde su caso por terremoto")
	_verificar(oficina.papel_actual == null and despacho.calma_operativa == calma - caso.penalidad_calma,
		"Se descarta la hoja y se aplica una sola pérdida de calma")
	await _hasta(15.95)
	_verificar(intensidad == 1.0 and evento.etapa == evento.Etapa.RUPTURA, "La segunda etapa mantiene el temblor fuerte")
	await _hasta(16.04)
	_verificar(intensidad > 0.99 and evento.etapa == evento.Etapa.RECUPERACION, "La tercera etapa comienza sin salto de intensidad")
	await _hasta(20.0)
	_verificar(absf(intensidad - 0.5) < 0.01, "El tambaleo disminuye durante los últimos ocho segundos")
	await _hasta(23.85)
	_verificar(evento._cerrando and intensidad < 0.01 and oficina.temporizador_bloqueos.paused, "El suelo se recompone al apagarse el temblor")
	await _fisicas(14)
	_verificar(is_equal_approx(evento.tiempo, 24.0) and is_zero_approx(intensidad), "El sismo termina en el segundo veinticuatro")
	_verificar(not evento.activo and evento.grietas.is_empty() and grafo.grietas.is_empty(), "Se retiran las grietas físicas y lógicas")
	_verificar(not _suelo_bajo(centro).is_empty(), "El piso vuelve a soportar cuerpos")
	_verificar(not oficina.temporizador_bloqueos.paused and oficina.temporizador_bloqueos.time_left < restantes, "Se reanuda el reloj de bloqueos")
	oficina.temporizador_bloqueos.start(0.1)
	await _fisicas(12)
	_verificar(oficina.bloqueos_visuales != congelado and oficina._bloqueos_pool.size() == 30, "El turno siguiente reutiliza los bloqueos caídos")
	oficina.temporizador_bloqueos.stop()
	oficina._limpiar_bloqueos_temporales()
	var origen := jugador.global_position
	jugador.global_position = grafo.celda_a_posicion(Vector2i(7, 19)) + Vector3.UP * evento._altura
	await _pulsar(KEY_F3)
	await _pulsar(KEY_T)
	_verificar(not evento.activo, "No se inicia un terremoto desde la zona segura")
	jugador.global_position = origen
	await _pulsar(KEY_T)
	_verificar(evento.activo, "F3 y T inician un segundo terremoto desde la partida")
	if evento.activo:
		jugador.global_position = grafo.celda_a_posicion(Vector2i(7, 19)) + Vector3.UP * evento._altura
		await _hasta(8.85)
		_verificar(intensidad == 0.0 and evento.grietas.size() >= 4, "La zona segura queda tranquila mientras se rompe el suelo de juego")
		_verificar(camara._temblor.is_zero_approx() and not _suelo_bajo(jugador.global_position).is_empty(),
			"El jugador conserva suelo firme y cámara sin sacudidas en la zona segura")
		var caso_seguro := _recibir_caso_con_hoja("TERREMOTO-HOJA-A-SALVO")
		var hoja_segura: RigidBody3D = oficina.papel_actual
		hoja_segura.lanzar()
		await _intentar_salto(evento.grietas[0], false)
		_verificar(despacho.obtener_denuncia_activa() == caso_seguro and is_instance_valid(hoja_segura),
			"Caer con las manos vacías conserva la hoja que quedó en tierra firme")
		hoja_segura.tomar(jugador)
		await _intentar_salto(evento.grietas[2], true)
		_verificar(despacho.obtener_denuncia_activa() == caso_seguro and jugador.papel_en_mano == hoja_segura,
			"Saltar por encima de una grieta con la hoja conserva el caso")
	oficina.queue_free()
	await process_frame
	# El mezclador libera las voces de pasos y salto en tiempo real con --fixed-fps.
	var fin_audio := Time.get_ticks_msec() + 250
	while Time.get_ticks_msec() < fin_audio:
		OS.delay_msec(4)
		await process_frame
	print("[TERREMOTO] %d errores" % errores)
	quit(1 if errores else 0)


func _recibir_caso_con_hoja(id: String) -> Denuncia:
	var caso := Denuncia.new()
	caso.id = id
	caso.tiempo_limite_segundos = 300.0
	caso.protocolo_estaciones = ["bienestar"]
	var despacho: SistemaDespacho = oficina.sistema_despacho
	_verificar(despacho.recibir_denuncia(caso) and despacho.iniciar_denuncia_prioritaria() == caso,
		"Se activa el caso " + id)
	var papel := load("res://Scripts/Despacho/papel_denuncia.gd").new() as RigidBody3D
	papel.denuncia_id = caso.id
	oficina.add_child(papel)
	oficina.papel_actual = papel
	papel.tomar(jugador)
	return caso


func _suelo_bajo(posicion: Vector3) -> Dictionary:
	var rayo := PhysicsRayQueryParameters3D.create(posicion + Vector3.UP * 0.02, posicion + Vector3.DOWN * 0.8, 1)
	return jugador.get_world_3d().direct_space_state.intersect_ray(rayo)


func _borde_sur(grieta: Grieta) -> float:
	var z := grieta.centro.y
	while grieta.contiene(Vector2(grieta.centro.x, z)):
		z += 0.01
	return z


func _intentar_salto(grieta: Grieta, saltable: bool) -> void:
	# Cruzar el ancho real de esta boca, aunque el terremoto la haya girado.
	var mitad := Grieta.TRAMOS >> 1
	var borde := grieta._izquierda[mitad]
	var destino := grieta._derecha[mitad]
	var direccion := borde.direction_to(destino)
	var pies := borde - direccion * 0.21
	jugador.global_position = Vector3(pies.x, evento._altura + 0.02, pies.y)
	jugador.velocity = Vector3.ZERO
	await _fisicas(8)
	pies = borde - direccion * 0.04
	jugador.global_position = Vector3(pies.x, evento._altura + 0.002, pies.y)
	await _fisicas(2)
	_verificar(jugador.is_on_floor(), "El salto parte con los pies apoyados en el borde")
	var horizontal := &"policia_prueba_derecha" if direccion.x >= 0 else &"policia_prueba_izquierda"
	var vertical := &"policia_prueba_atras" if direccion.y >= 0 else &"policia_prueba_adelante"
	Input.action_press(horizontal, absf(direccion.x))
	Input.action_press(vertical, absf(direccion.y))
	Input.action_press(&"policia_prueba_correr")
	jugador.velocity = Vector3(direccion.x, 0, direccion.y) * jugador.run_speed
	Input.action_press(&"policia_prueba_saltar")
	await _fisicas(3)
	_verificar(jugador.global_position.y > evento._altura + 0.014, "El personaje despega a velocidad de carrera")
	Input.action_release(&"policia_prueba_saltar")
	var cayo := false
	for i in range(32 if saltable else 47):
		await physics_frame
		if jugador.global_position.y < evento._altura - 0.20:
			cayo = true
	Input.action_release(horizontal)
	Input.action_release(vertical)
	Input.action_release(&"policia_prueba_correr")
	var llegada := Vector2(jugador.global_position.x, jugador.global_position.z)
	var cruzo := llegada.distance_to(destino) < 0.65 and (llegada - destino).dot(direccion) >= -0.10 and jugador.is_on_floor()
	_verificar((cruzo and not cayo) if saltable else (cayo and not cruzo),
		"Se cruza la pequeña de un salto" if saltable else "El salto en carrera no cruza la grieta grande")


func _fisicas(cantidad: int) -> void:
	for i in range(cantidad):
		await physics_frame


func _hasta(segundo: float) -> void:
	while evento.activo and evento.tiempo + 0.00001 < segundo:
		await physics_frame


func _pulsar(tecla: Key) -> void:
	var entrada := InputEventKey.new()
	entrada.keycode = tecla
	entrada.physical_keycode = tecla
	entrada.pressed = true
	Input.parse_input_event(entrada)
	await _fisicas(2)
	var soltar := entrada.duplicate() as InputEventKey
	soltar.pressed = false
	Input.parse_input_event(soltar)
	await _fisicas(2)


func _verificar(ok: bool, detalle: String) -> void:
	if not ok:
		errores += 1
		push_error(detalle)
