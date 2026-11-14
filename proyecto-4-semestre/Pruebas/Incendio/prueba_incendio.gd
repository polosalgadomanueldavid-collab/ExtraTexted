extends SceneTree
## --headless --fixed-fps 60 --script res://Pruebas/Incendio/prueba_incendio.gd
## Sin headless, añadir -- --capturas para verificar oficina, pose y cenizas.

var oficina: Node3D
var evento: Node3D
var jugador
var errores := 0
var recuperadas: Array[String] = []


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	root.size = Vector2i(1280, 720)
	var menu := root.get_node("MenuGlobal")
	menu.omitir_tutorial_siguiente_partida = true
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	await _fisicas(12)
	menu.cerrar_ayuda()
	oficina.tutoriales_vistos[&"incendio"] = true
	paused = false
	jugador = oficina.jugador
	evento = oficina.evento_incendio
	evento.mesa_recuperada.connect(func(id: String) -> void: recuperadas.append(id))
	_probar_vecindad()
	oficina.generador_aleatorio.seed = 1414
	oficina._recibir_denuncia_aleatoria()
	oficina.temporizador_denuncias.stop()
	oficina.computador.timer_nuevo_problema.stop()
	oficina.sistema_despacho.set_process(false)
	await _fisicas(70)
	var caso = oficina.sistema_despacho.iniciar_denuncia_prioritaria()
	caso.protocolo_estaciones.assign(["privacidad", "bienestar"])
	oficina.interactuar_estacion("privacidad")
	var pendiente_seguridad: float = oficina.temporizador_seguridad.time_left
	_verificar(evento.focos.size() == 17, "Se registran exactamente las 17 mesas del perímetro, incluidas las estaciones y el PC")
	var iniciales: Dictionary = oficina.bloqueos_visuales.duplicate()
	# Usa el mismo selector que dispara los eventos de la partida.
	oficina._evento_aleatorio_pendiente = 2
	oficina._intentar_evento_aleatorio()
	_verificar(evento.activo and oficina.temporizador_eventos.is_stopped(), "El selector aleatorio inicia INCENDIO y detiene su reloj")
	_verificar(oficina.anuncios.titulo == "¡INCENDIO!" and jugador.voz.stream == jugador.voz.estres, "Panel de inicio y expresión de estrés")
	_verificar(evento._ambiente.playing, "El incendio tiene crepitar ambiental")
	_verificar(evento.indicador_extintor.visible and evento.indicador_extintor.distancia > 1.0, "El extintor se señala a distancia desde el inicio del incendio")
	var camara_marcador := Camera3D.new()
	oficina.add_child(camara_marcador)
	camara_marcador.global_position = evento.extintor.global_position + Vector3(0, 1.0, 2.0)
	camara_marcador.look_at(camara_marcador.global_position + Vector3.BACK)
	evento.indicador_extintor.actualizar(camara_marcador, evento.extintor.global_position + Vector3.UP, jugador.global_position, false, true)
	_verificar(evento.indicador_extintor.visible and evento.indicador_extintor.fuera_de_pantalla and evento.indicador_extintor.ancla.is_finite(), "El indicador conserva una dirección visible cuando el extintor queda detrás de la cámara")
	camara_marcador.queue_free()
	evento._actualizar_indicador_extintor()
	_verificar(oficina.temporizador_seguridad.paused and not oficina.sonidos_mesas.seguridad.playing, "Seguridad interrumpe su tarea y audio mientras arde")
	_verificar(not oficina.evento_apagon.iniciar_apagon(), "No se solapa con apagón")
	oficina._iniciar_terremoto()
	_verificar(not oficina.evento_terremoto.activo, "No se solapa con terremoto")
	var alcanzables: Dictionary = oficina.grafo_piso.celdas_alcanzables(oficina.grafo_piso.celda_de_acceso(jugador.global_position))
	for foco in evento.focos:
		var celda: Vector2i = oficina.grafo_piso.posicion_a_celda(foco.acceso.global_position)
		_verificar(alcanzables.has(celda), "Hay camino al fuego de " + str(foco.mesa.name))
	var primero = evento.focos[0]
	await _aproximar(primero)
	_pulsar_e()
	await _fisicas(15)
	_soltar_e()
	_verificar(primero.apagado == 0.0, "E sin extintor no apaga ni utiliza una estación en llamas")
	oficina.interactuar_estacion("bienestar")
	_verificar(caso.estaciones_completadas.is_empty(), "Una estación en llamas rechaza completar el caso incluso por la API de partida")
	oficina._entregar_papel(jugador)
	_verificar(oficina.papel_actual == null, "El PC en llamas no imprime")
	await _capturar("01_oficina_en_llamas")
	jugador.global_position = evento.extintor.global_position + Vector3(0, 0.02, 0.65)
	_mirar(evento.extintor.global_position)
	await _fisicas(8)
	_verificar(jugador.obtener_objetivo_interaccion() == evento.extintor, "El extintor se puede alcanzar desde descanso")
	_verificar(evento.indicador_extintor.interactuable, "La tecla E aparece cuando el extintor se puede recoger")
	await _capturar("06_marcador_extintor")
	_pulsar_e()
	await _fisicas(8)
	_soltar_e()
	_verificar(jugador.realizando_gesto() and not evento.equipado, "Recoger espera el contacto de la animación")
	await _fisicas(70)
	_verificar(evento.equipado and evento.extintor.recogido, "La E equipa el extintor tras recogerlo")
	_verificar(not evento.indicador_extintor.visible, "El marcador desaparece al recoger el extintor")
	var papel = load("res://Scripts/Despacho/papel_denuncia.gd").new()
	papel.denuncia_id = caso.id
	oficina.add_child(papel)
	oficina.papel_actual = papel
	papel.tomar(jugador)
	var pose_papel: Transform3D = papel.transform
	await _aproximar(primero)
	_verificar(jugador.obtener_objetivo_interaccion() == primero, "Se selecciona la mesa cercana hacia la que mira el jugador")
	var obstaculo := StaticBody3D.new()
	var colision := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(0.12, 0.7, 0.7)
	colision.shape = caja
	obstaculo.add_child(colision)
	oficina.add_child(obstaculo)
	var origen: Vector3 = jugador.global_position + Vector3.UP * 0.42
	var borde := Vector3(primero.limites.end.x, origen.y, origen.z)
	obstaculo.global_position = origen.lerp(borde, 0.5)
	await _fisicas(2)
	_verificar(evento.obtener_objetivo(jugador) != primero, "El extintor no atraviesa otros cuerpos para alcanzar una mesa")
	obstaculo.queue_free()
	await _fisicas(2)
	_pulsar_e()
	await _fisicas(50)
	var avance: float = primero.apagado
	_verificar(avance > 0.20 and avance < 0.4 and evento.rociando and jugador.usando_extintor, "Mantener E rocía y acumula progreso continuo")
	_verificar(_foco("Table_018").apagado == 0.0 and _foco("Table_013").apagado == 0.0 and recuperadas.is_empty(), "El progreso parcial no apaga las vecinas ni emite recuperaciones")
	_verificar(evento._chorro.playing and evento.extintor.espuma.emitting and jugador.gestos.rociando_extintor, "Chorro, sonido y animación se sincronizan")
	_verificar(jugador.papel_en_mano == papel and papel.portador == jugador and evento._papel_guardado == papel, "El personaje guarda su denuncia sin perderla al usar las dos manos")
	await _capturar("02_extintor", true)
	# Las capturas dejan avanzar cuadros mientras E sigue pulsada.
	avance = primero.apagado
	_soltar_e()
	await _fisicas(20)
	_verificar(is_equal_approx(primero.apagado, avance) and not evento.rociando and not evento._chorro.playing, "Soltar E conserva avance y detiene el chorro")
	_verificar(papel.transform.is_equal_approx(pose_papel), "La hoja vuelve a su pose de mano al soltar el extintor")
	# La orientación y la distancia se vuelven a comprobar durante el chorro.
	_pulsar_e()
	await _fisicas(2)
	jugador.visual.rotation.y += PI
	await _fisicas(2)
	avance = primero.apagado
	await _fisicas(5)
	_verificar(not evento.rociando and is_equal_approx(primero.apagado, avance), "Mirar en otra dirección interrumpe el apagado")
	_soltar_e()
	_mirar(primero.global_position)
	_pulsar_e()
	await _fisicas(8)
	paused = true
	var tiempo: float = evento.tiempo
	avance = primero.apagado
	await _fisicas(20)
	_verificar(is_equal_approx(tiempo, evento.tiempo) and is_equal_approx(avance, primero.apagado), "La pausa congela fuego, cenizas y progreso")
	_verificar(not evento.rociando and evento._ambiente.stream_paused, "Pausar cancela el chorro y pausa el ambiente")
	paused = false
	await _fisicas(10)
	_verificar(is_equal_approx(avance, primero.apagado), "Reanudar exige volver a pulsar E")
	_soltar_e()
	_pulsar_e()
	for i in 200:
		if primero.apagado >= 1.0:
			break
		await _fisicas(1)
	_soltar_e()
	_verificar(primero.apagado == 1.0 and not evento.arde_estacion(primero.estacion_id) and evento.activo, "Una estación apagada se recupera mientras el resto sigue ardiendo")
	var vecina := _foco("Table_018")
	_verificar(vecina.apagando_adyacente and vecina.apagado < 0.01 and vecina.fuego.visible and recuperadas.size() == 1, "Las vecinas empiezan su transición sin desaparecer ni recuperarse de golpe")
	await _fisicas(20)
	var apagado_vecina: float = vecina.apagado
	_verificar(apagado_vecina > 0.0 and apagado_vecina < 1.0 and vecina.fuego.intensidad > 0.0 and vecina.fuego.intensidad < 1.0, "El fuego vecino se contrae gradualmente antes de apagarse")
	paused = true
	await _fisicas(20)
	_verificar(is_equal_approx(vecina.apagado, apagado_vecina), "La animación de apagado vecino respeta la pausa")
	paused = false
	await _capturar("07_apagado_adyacentes", true)
	await _fisicas(50)
	_verificar(_foco("Table_018").apagado == 1.0 and _foco("Table_013").apagado == 1.0 and evento.panel.completadas == 3, "Apagar Bienestar recupera exactamente sus dos vecinas, incluida la esquina")
	_verificar(not _foco("Table_013").mesa.get_meta("en_llamas") and not _foco("Table_018").fuego.visible and recuperadas.size() == 3, "Las vecinas apagan sus llamas, desbloquean la mesa y emiten su recuperación")
	while evento.tiempo < 9.95:
		await _fisicas(1)
	_verificar(not evento.bloqueos_fijos, "Los cajones todavía no son ceniza antes de diez segundos")
	await _fisicas(10)
	_verificar(evento.bloqueos_fijos and evento._fuegos_cajones.is_empty(), "A los diez segundos los cajones dejan de arder")
	var muestra: StaticBody3D = iniciales.values()[0]
	_verificar(muestra.es_ceniza and muestra.diseño_cajon.visible and muestra._animacion.is_running(), "La carbonización comienza con el cajón visible, sin sustituirlo de golpe")
	await _fisicas(25)
	_verificar(muestra._cenizas.visible and muestra.diseño_cajon.visible and muestra.diseño_cajon.transform != muestra._reposo, "El cajón se hunde y deja aparecer restos durante la transición")
	await _capturar("05_carbonizacion")
	var pose_colapso: Transform3D = muestra.diseño_cajon.transform
	paused = true
	await _fisicas(15)
	_verificar(muestra.diseño_cajon.transform == pose_colapso, "La animación de ceniza se congela al pausar")
	paused = false
	await _fisicas(50)
	_verificar(not muestra.diseño_cajon.visible and muestra._cenizas.visible and muestra._polvo_lanzado, "El colapso termina con ceniza y una ráfaga de polvo")
	_verificar(is_equal_approx(pendiente_seguridad, oficina.temporizador_seguridad.time_left) and not oficina._seguridad_lista, "Una tarea no termina automáticamente dentro de una mesa en llamas")
	for cajon: StaticBody3D in iniciales.values():
		_verificar(cajon.es_ceniza and cajon.collision_layer == 1 and cajon.visible, "La ceniza conserva un bloqueo físico y visible")
	oficina._on_temporizador_bloqueos_timeout()
	_verificar(iniciales == oficina.bloqueos_visuales, "La distribución de ceniza no cambia durante el incendio")
	await _capturar("03_cenizas")
	for foco in evento.focos:
		if foco.apagado >= 1.0:
			continue
		await _aproximar(foco)
		var apagadas_antes: int = evento.panel.completadas
		var avisos_antes := recuperadas.size()
		_verificar(jugador.obtener_objetivo_interaccion() == foco, "Se alcanza y selecciona " + str(foco.mesa.name))
		_pulsar_e()
		await _fisicas(45)
		if foco == evento.focos[1]:
			await _capturar("04_extintor_entre_cenizas", true)
		await _fisicas(140)
		_soltar_e()
		_verificar(foco.apagado == 1.0, "Se apaga por completo " + str(foco.mesa.name))
		if foco == _foco("Table_024"):
			_verificar(_foco("Table_025").apagando_adyacente and _foco("Table_027").apagado == 0.0 and _foco("Table_028").apagado == 0.0, "El tramo inferior izquierdo no apaga mesas al otro lado del hueco")
		if foco == _foco("Table_027"):
			_verificar(evento.activo and evento.panel.completadas < 17, "El evento espera a que termine la última animación vecina")
		await _fisicas(70)
		_verificar(evento.panel.completadas - apagadas_antes <= 3 and recuperadas.size() - avisos_antes == evento.panel.completadas - apagadas_antes, "El apagado no se propaga ni vuelve a notificar mesas ya recuperadas")
	_verificar(not evento.activo and evento.panel.progreso == 1.0 and evento.panel.completadas == 17, "100% y fin solo al apagar todas las mesas")
	var calma_final: int = oficina.sistema_despacho.calma_operativa
	evento._physics_process(120.0)
	_verificar(oficina.sistema_despacho.calma_operativa == calma_final, "Resolver el incendio detiene por completo el desgaste de cordura")
	_verificar(not oficina.temporizador_seguridad.paused, "Seguridad reanuda la tarea después de extinguir su mesa")
	_verificar(not evento.equipado and not evento._ambiente.playing and not evento._chorro.playing, "El final retira el extintor y detiene los sonidos")
	_verificar(oficina.temporizador_eventos.time_left >= 39.0 and oficina.temporizador_eventos.time_left <= 65.0, "El incendio comparte el descanso entre eventos")
	_verificar(not evento.bloqueos_fijos and not oficina.temporizador_bloqueos.is_stopped() and not oficina.temporizador_bloqueos.paused, "Terminar el incendio reactiva el reloj de bloqueos")
	for cajon: StaticBody3D in iniciales.values():
		_verificar(not cajon.es_ceniza and not cajon._cenizas.visible and cajon.diseño_cajon.visible and cajon._capas_originales.is_empty(), "Las cenizas y el hollín desaparecen al recuperar el cajón normal")
	_verificar(oficina.bloqueos_visuales.size() == 30 and oficina._bloqueos_pool.size() == 30, "Se repone una distribución de treinta cajones reutilizados")
	var distribucion_restaurada: Array = oficina.bloqueos_visuales.keys()
	await _fisicas(610)
	_verificar(distribucion_restaurada != oficina.bloqueos_visuales.keys(), "Los bloqueos vuelven a cambiar automáticamente diez segundos después")
	for foco in evento.focos:
		var rutas: Dictionary = oficina.grafo_piso.celdas_alcanzables(oficina.grafo_piso.celda_de_acceso(jugador.global_position))
		_verificar(rutas.has(oficina.grafo_piso.posicion_a_celda(foco.acceso.global_position)), "La nueva distribución conserva acceso a " + str(foco.mesa.name))
	_verificar(oficina._iniciar_incendio(), "Puede iniciarse otro incendio con los cajones restaurados")
	_verificar(evento.panel.progreso == 0.0 and evento._fuegos_cajones.size() == 30, "El nuevo incendio vuelve a prender los treinta cajones")
	_verificar(evento.tiempo == 0.0 and evento._perdida_acumulada == 0.0, "Cada incendio empieza con su gracia y sin daño pendiente")
	_verificar(evento.indicador_extintor.visible, "Un incendio posterior vuelve a mostrar la ubicación del extintor")
	_verificar(evento.extintor.deposito.transform == Transform3D.IDENTITY, "El extintor regresa al punto de recogida en el siguiente incendio")
	# Interrumpir un reciclaje en mitad de la animación no deja callbacks ni hollín.
	var reciclado: StaticBody3D = oficina.bloqueos_visuales.values()[0]
	reciclado.convertir_en_ceniza()
	await _fisicas(20)
	reciclado.desactivar()
	await _fisicas(75)
	_verificar(not reciclado.es_ceniza and not reciclado.visible and not reciclado._cenizas.visible and reciclado._capas_originales.is_empty(), "Desactivar durante el colapso cancela la animación y restaura los materiales")
	await _probar_desgaste()
	vecina.iniciar_apagado_adyacente()
	evento._physics_process(0.3)
	apagado_vecina = vecina.apagado
	evento.detener()
	_verificar(not evento.rociando and not evento.panel.visible and not evento._ambiente.playing, "Detener la partida limpia controles, panel y audio")
	calma_final = oficina.sistema_despacho.calma_operativa
	evento._physics_process(120.0)
	_verificar(oficina.sistema_despacho.calma_operativa == calma_final, "Un incendio detenido no sigue quitando cordura")
	_verificar(not vecina.apagando_adyacente and is_equal_approx(vecina.apagado, apagado_vecina), "Detener cancela el apagado vecino sin callbacks pendientes")
	vecina.encender()
	_verificar(not vecina.apagando_adyacente and vecina.apagado == 0.0 and vecina.fuego.intensidad == 1.0, "Reencender restablece también una llama interrumpida durante su transición")
	oficina.queue_free()
	await process_frame
	# La escena F6 carga la oficina auténtica, con pausa y tutorial disponibles.
	menu.omitir_tutorial_siguiente_partida = true
	var manual := load("res://Pruebas/Incendio/PruebaIncendio.tscn").instantiate() as Node
	root.add_child(manual)
	current_scene = manual
	await _fisicas(370)
	_verificar(is_instance_valid(current_scene) and current_scene.scene_file_path == "res://Mundo/Oficina.tscn" and current_scene.evento_incendio.activo, "F6 prepara el incendio dentro de la oficina real")
	current_scene.sistema_despacho.calma_operativa = 1
	current_scene.evento_incendio._physics_process(25.0)
	_verificar(current_scene.partida_finalizada and current_scene.sistema_despacho.terminada and current_scene.evento_incendio.activo, "Ignorar el incendio agota la cordura y el fuego continúa durante el relevo")
	_verificar(current_scene.final_partida._datos.causa.get("incendio", false) and current_scene.sistema_despacho.recuperar_calma(15) == 0, "La derrota identifica el incendio y no permite revivir recuperando calma")
	paused = false
	current_scene.queue_free()
	await process_frame
	print("[INCENDIO] %d errores" % errores)
	quit(1 if errores else 0)


func _foco(nombre: String) -> Node3D:
	for foco in evento.focos:
		if foco.mesa.name == nombre:
			return foco
	return null


func _probar_vecindad() -> void:
	# Orden espacial de la oficina, distinto del orden de los nodos de la escena.
	var nombres := ["Table_017", "Table_018", "Table_021", "Table_020", "Table_024", "Table_025", "Table_027", "Table_028", "Table_022", "Table_023", "Table_019", "Table_016", "Table_014", "Table_011", "Table_010", "Table_012", "Table_013"]
	var extremos := {"Table_020": "Table_021", "Table_024": "Table_025", "Table_025": "Table_024", "Table_027": "Table_028", "Table_028": "Table_027", "Table_022": "Table_023"}
	for i in nombres.size():
		var foco := _foco(nombres[i])
		var vecinas: Array = evento.obtener_adyacentes(foco)
		if extremos.has(nombres[i]):
			_verificar(vecinas.size() == 1 and vecinas.has(_foco(extremos[nombres[i]])), "El tramo se detiene ante el hueco o la esquina inferior en " + nombres[i])
		else:
			_verificar(vecinas.size() == 2 and vecinas.has(_foco(nombres[posmod(i - 1, nombres.size())])) and vecinas.has(_foco(nombres[(i + 1) % nombres.size()])), "Vecinas físicas correctas para " + nombres[i])


func _probar_desgaste() -> void:
	evento.set_physics_process(false)
	evento.tiempo = 0.0
	var calma: int = oficina.sistema_despacho.calma_operativa
	evento._physics_process(23.5)
	_verificar(oficina.sistema_despacho.calma_operativa == calma, "Antes de 24 segundos no hay desgaste por incendio")
	evento._physics_process(0.5)
	_verificar(oficina.sistema_despacho.calma_operativa == calma and evento._perdida_acumulada == 0.0, "A los 24 segundos exactos aún no se pierde cordura")
	evento._physics_process(0.5)
	_verificar(oficina.sistema_despacho.calma_operativa == calma and is_equal_approx(evento._perdida_acumulada, 0.5), "El desgaste conserva fracciones de segundo")
	evento._physics_process(0.5)
	_verificar(oficina.sistema_despacho.calma_operativa == calma - 1, "Un segundo después de la gracia se pierde el primer punto")
	paused = true
	evento.set_physics_process(true)
	await _fisicas(65)
	_verificar(evento.tiempo == 25.0 and oficina.sistema_despacho.calma_operativa == calma - 1, "La pausa congela también el desgaste activo de cordura")
	evento.set_physics_process(false)
	paused = false
	evento._physics_process(36.0)
	_verificar(oficina.sistema_despacho.calma_operativa == calma - 38, "Cruzar los 60 segundos aplica 1 punto/s antes y 2 después, sin daño retroactivo")
	oficina.sistema_despacho.recuperar_calma(100)
	evento._physics_process(30.0)
	_verificar(oficina.sistema_despacho.calma_operativa == 39, "Tras 90 segundos el desgaste sube a 3 puntos/s")
	evento._physics_process(2.0)
	_verificar(oficina.sistema_despacho.calma_operativa == 33 and evento.activo, "La presión se mantiene hasta resolver el incendio")
	evento.set_physics_process(true)


func _aproximar(foco: Node3D) -> void:
	_soltar_e()
	jugador.global_position = foco.acceso.global_position + Vector3.UP * 0.02
	jugador.velocity = Vector3.ZERO
	_mirar(foco.global_position)
	await _fisicas(10)


func _mirar(punto: Vector3) -> void:
	var delta: Vector3 = punto - jugador.global_position
	jugador.visual.rotation.y = atan2(delta.x, delta.z)


func _pulsar_e() -> void:
	var pulsacion := InputEventAction.new()
	pulsacion.action = &"Interactuar"
	pulsacion.pressed = true
	Input.parse_input_event(pulsacion)


func _soltar_e() -> void:
	var pulsacion := InputEventAction.new()
	pulsacion.action = &"Interactuar"
	pulsacion.pressed = false
	Input.parse_input_event(pulsacion)


func _fisicas(cantidad: int) -> void:
	for i in cantidad:
		await physics_frame
		await process_frame


func _verificar(condicion: bool, texto: String) -> void:
	if condicion:
		print("[OK] " + texto)
	else:
		errores += 1
		push_error(texto)


func _capturar(nombre: String, cerca := false) -> void:
	if not OS.get_cmdline_user_args().has("--capturas"):
		return
	if nombre == "06_marcador_extintor":
		oficina.anuncios.detener()
		await _fisicas(30)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/incendio_qa/" + nombre + ".png")
		return
	var anterior := root.get_camera_3d()
	var camara := Camera3D.new()
	oficina.add_child(camara)
	camara.cull_mask = 524287
	camara.environment = oficina.get_node("Gameplay/Camera3D").environment
	var hud: CanvasLayer = oficina.get_node("CanvasLayer")
	if cerca:
		hud.hide()
		camara.fov = 44.0
		camara.global_position = jugador.global_position + jugador.visual.global_basis.orthonormalized() * Vector3(-0.45, 1.65, -1.0)
		camara.look_at(jugador.global_position + Vector3.UP * 0.45)
	else:
		camara.fov = 75.0
		camara.global_position = Vector3(-1, 6.0, 7.6)
		camara.look_at(Vector3(-1, 0.4, 3.2))
	camara.current = true
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/incendio_qa")
	root.get_texture().get_image().save_png("res://.godot/incendio_qa/" + nombre + ".png")
	hud.show()
	camara.queue_free()
	if is_instance_valid(anterior):
		anterior.make_current()
