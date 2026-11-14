extends SceneTree
## --headless --fixed-fps 60 --script res://Pruebas/Inundacion/prueba_inundacion.gd
## Sin --headless, añadir -- --capturas para revisar oficina, nado y puzzle.

const Red := preload("res://Eventos/Inundacion/red_tuberias.gd")
var oficina: Node3D
var errores := 0
var rechazos: Array[String] = []


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	var redes_validas := true
	for semilla in 500:
		var red := Red.new()
		red.generar(semilla)
		redes_validas = redes_validas and not red.resuelta and red.piezas.size() == 20
		for i in red.piezas.size():
			for giro in 4:
				if red.piezas[i] == red.solucion[i]:
					break
				red.girar(i)
		redes_validas = redes_validas and red.comprobar()
		# Romper cualquiera de los extremos invalida el circuito.
		red.piezas[0] = 5
		redes_validas = redes_validas and not red.comprobar()
	_verificar(redes_validas, "500 puzzles comienzan mezclados, se resuelven por giros y rechazan una entrada rota")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var menu := root.get_node("MenuGlobal")
	menu.omitir_tutorial_siguiente_partida = true
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	await _cuadros(45)
	menu.cerrar_ayuda()
	oficina.tutoriales_vistos[&"inundacion"] = true
	oficina.temporizador_denuncias.stop()
	oficina.computador.timer_nuevo_problema.stop()
	oficina.sistema_despacho.set_process(false)
	var jugador = oficina.jugador
	jugador.emote_rechazado.connect(func(mensaje: String) -> void: rechazos.append(mensaje))
	var caso := Denuncia.new()
	caso.id = "QA-INUNDACION"
	caso.tiempo_limite_segundos = 600
	caso.protocolo_estaciones.assign(["bienestar", "reporte"])
	oficina.sistema_despacho.recibir_denuncia(caso)
	oficina.bloqueos_iniciados = true
	oficina._cambiar_bloqueo_temporal()
	oficina._entregar_papel(jugador)
	await _cuadros(70)
	oficina.temporizador_bloqueos.stop()
	oficina.temporizador_eventos.stop()
	var evento: Node3D = oficina.evento_inundacion
	var mesa: Node3D = get_first_node_in_group("mesas_incendiables")
	var pose_mesa := mesa.transform
	var cuerpo := mesa.get_node("StaticBody3D") as StaticBody3D
	var pose_cuerpo := cuerpo.global_transform
	jugador.global_position = Vector3(-1.3, 0.38, 8.3)
	await _cuadros(12)
	var inicio: bool = oficina._iniciar_inundacion()
	_verificar(inicio, "Inicia la inundación en la oficina real")
	if not inicio:
		quit(1)
		return
	_verificar(oficina.anuncios.titulo == "¡INUNDACIÓN!", "Se presenta el aviso del evento")
	_verificar(not oficina.evento_apagon.iniciar_apagon() and not oficina._iniciar_incendio(), "El coordinador impide eventos simultáneos")
	await _cuadros(42)
	await _capturar("01_aviso")
	await _cuadros(240)
	_verificar(is_equal_approx(evento.nivel, evento.NIVEL_MAXIMO) and jugador.nadando, "Agua alta y estado de natación tras la subida")
	_verificar(evento._ambiente.playing, "La inundación reproduce su ambiente de agua")
	_verificar(mesa.position.y > pose_mesa.origin.y + 0.4 and cuerpo.global_transform.is_equal_approx(pose_cuerpo), "Mesas flotando con colisión horizontal estable")
	_verificar(jugador.current_animation == &"swim_idle" and not jugador.sonido_pasos.playing, "Reposo acuático sin pasos terrestres")
	await _capturar("02_oficina_inundada")
	for tipo: StringName in [&"kamehameha", &"genkidama", &"rasengan"]:
		_verificar(not jugador.ejecutar_gesto(tipo), "Emote bloqueado: " + tipo)
	jugador.play_wave()
	var tecla := InputEventAction.new()
	tecla.action = jugador.EMOTE_MENU
	tecla.pressed = true
	jugador._input(tecla)
	_verificar(rechazos.size() == 5 and rechazos[0] == "No se pueden usar emotes en este momento" and not jugador._emote_menu_active, "Saludo, menú y poderes muestran el mensaje solicitado")
	Input.action_press(jugador.RIGHT)
	Input.action_press(jugador.RUN)
	await _cuadros(30)
	var rapidez := Vector2(jugador.velocity.x, jugador.velocity.z).length()
	_verificar(absf(rapidez - jugador.walk_speed * jugador.FACTOR_NADO) < 0.05, "Correr no evita la ralentización al nadar")
	_verificar(jugador.current_animation == &"swim", "Nado activo durante el desplazamiento")
	await _capturar("03_nadando")
	await _capturar("03_nadando_detalle", true)
	Input.action_release(jugador.RIGHT)
	Input.action_release(jugador.RUN)
	await _cuadros(20)
	# Las mismas acciones de trabajo siguen efectuando sus efectos con la hoja.
	await _usar_estacion("bienestar")
	_verificar(caso.estaciones_completadas.has("bienestar"), "Se completa una estación mientras se nada")
	jugador.global_position = Vector3(-1.3, 0.38, 8.3)
	await _cuadros(10)
	var papel = jugador.papel_en_mano
	jugador.ejecutar_gesto(&"lanzar", papel.lanzar)
	await _cuadros(180)
	_verificar(papel.portador == null and papel.global_position.y > evento.nivel - 0.08, "La hoja lanzada flota y sigue disponible")
	jugador.global_position = Vector3(papel.global_position.x, 0.38, papel.global_position.z - 0.3)
	jugador.visual.rotation.y = 0
	await _cuadros(8)
	_verificar(jugador.obtener_objetivo_interaccion() == papel, "El papel flotante puede seleccionarse con la interacción normal")
	papel.interactuar(jugador)
	await _cuadros(85)
	_verificar(jugador.papel_en_mano == papel, "Recoger conserva la denuncia durante la inundación")
	oficina.probabilidad_atasco_reporte = 0.0
	await _usar_estacion("reporte")
	_verificar(oficina.sistema_despacho.obtener_denuncia_activa() == null and evento.activo, "Un caso completo se resuelve sin reparar primero la inundación")
	var siguiente := Denuncia.new()
	siguiente.id = "QA-TUBERIAS"
	siguiente.tiempo_limite_segundos = 600
	siguiente.protocolo_estaciones.assign(["bienestar"])
	oficina.sistema_despacho.recibir_denuncia(siguiente)
	oficina._entregar_papel(jugador)
	await _cuadros(70)
	papel = jugador.papel_en_mano
	# Reutilizar cajones en el agua conserva el grafo y produce salpicaduras reales.
	oficina._cambiar_bloqueo_temporal()
	await _cuadros(38)
	_verificar(evento._efectos.get_child_count() >= 30, "Los nuevos cajones salpican al caer al agua")
	var origen: Vector2i = oficina.grafo_piso.celda_de_acceso(jugador.global_position)
	var destino: Vector2i = oficina.grafo_piso.celda_de_acceso(evento.acceso.global_position)
	_verificar(not oficina.grafo_piso.calcular_ruta(origen, destino).is_empty(), "Los bloqueos mantienen el acceso a las tuberías")
	var posiciones: Dictionary = {}
	var forma := jugador.get_node("Colision") as CollisionShape3D
	var limites := forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
	var huella := Rect2(Vector2(limites.position.x, limites.position.z), Vector2(limites.size.x, limites.size.z))
	var seguros := true
	for bloqueo: Node3D in oficina.bloqueos_visuales.values():
		posiciones[bloqueo] = bloqueo.global_position
		seguros = seguros and not Rect2(Vector2(bloqueo.global_position.x, bloqueo.global_position.z) - Vector2.ONE * 0.25, Vector2.ONE * 0.5).intersects(huella)
	await _cuadros(60)
	for bloqueo: Node3D in posiciones:
		seguros = seguros and bloqueo.global_position.is_equal_approx(posiciones[bloqueo])
	_verificar(seguros, "Los cajones no caen sobre el personaje ni derivan entre celdas")
	jugador.global_position = evento.acceso.global_position
	jugador.visual.rotation.y = PI * 0.5
	await _cuadros(8)
	_verificar(jugador.obtener_objetivo_interaccion() == evento, "Las tuberías se alcanzan desde descanso")
	evento.interactuar(jugador)
	await _cuadros(8)
	_verificar(evento.panel.visible and jugador.input_locked, "E abre el puzzle y bloquea solo el movimiento")
	evento.panel._girar(4)
	var piezas: Array = evento.panel.red.piezas.duplicate()
	evento.panel.cerrar()
	_verificar(not jugador.input_locked and evento.activo and not evento.drenando, "Salir sin resolver libera al jugador y mantiene la inundación")
	evento.interactuar(jugador)
	_verificar(evento.panel.red.piezas == piezas, "Reabrir conserva los giros")
	await _capturar("04_puzzle")
	var nivel_anterior: float = evento.nivel
	var reloj_anterior: float = evento.tiempo
	paused = true
	await _cuadros(30)
	_verificar(evento.tiempo == reloj_anterior and evento.nivel == nivel_anterior, "La pausa congela agua y animaciones")
	_verificar(evento._ambiente.stream_paused, "El sonido del agua también respeta la pausa")
	paused = false
	for i in evento.panel.red.piezas.size():
		for giro in 4:
			if evento.panel.red.piezas[i] == evento.panel.red.solucion[i]:
				break
			evento.panel._girar(i)
	await _cuadros(60)
	await _capturar("05_flujo")
	await _cuadros(45)
	_verificar(evento.drenando and not jugador.input_locked and not evento.panel.visible, "Conectar el flujo inicia el vaciado y devuelve el control")
	await _cuadros(270)
	_verificar(not evento.activo and not jugador.nadando and not evento.superficie.visible, "La inundación termina al bajar toda el agua")
	_verificar(not evento._ambiente.playing, "Al terminar no queda el ambiente de agua")
	_verificar(mesa.transform.is_equal_approx(pose_mesa) and cuerpo.global_transform.is_equal_approx(pose_cuerpo) and not cuerpo.top_level, "Se restauran muebles y colisiones exactamente")
	_verificar(papel.nivel_agua == -INF and oficina.temporizador_eventos.time_left > 35, "Se retira la flotación y se programa el próximo evento")
	await _capturar("06_restaurado")
	_verificar(jugador.ejecutar_gesto(&"kamehameha"), "Los emotes vuelven después del agua")
	jugador.cancelar_gesto()
	await _cuadros(5)
	# Repetición y final de partida con un modal abierto no dejan bloqueos de control.
	oficina._evento_aleatorio_pendiente = 3
	oficina._intentar_evento_aleatorio()
	_verificar(evento.activo, "La cuarta elección aleatoria inicia otra inundación")
	await _cuadros(260)
	evento.interactuar(jugador)
	oficina._al_terminar_partida()
	_verificar(evento.activo and not evento.reparando and not evento.panel.visible and jugador.input_locked, "El final cierra la reparación y conserva el agua para el relevo")
	oficina.queue_free()
	await process_frame
	print("[INUNDACION] %d errores" % errores)
	quit(1 if errores else 0)


func _usar_estacion(id: String) -> void:
	for foco in oficina.evento_incendio.focos:
		if foco.estacion_id != id:
			continue
		var jugador = oficina.jugador
		# Las mesas tienen colisiones cóncavas: buscar el borde y las patas reales,
		# igual que en la prueba existente de interacción con marcadores.
		var acceso: Vector3 = foco.acceso.global_position
		acceso.y = 0.38
		var encontrada := false
		for desplazamiento: float in [0.0, 0.5, -0.5]:
			var centro: Vector3 = foco.cuerpo.to_global(Vector3(desplazamiento, 0, 0))
			centro.y = 0.38
			var direccion := centro - acceso
			jugador.visual.rotation.y = atan2(direccion.x, direccion.z)
			for paso in 81:
				jugador.global_position = acceso.lerp(centro, paso / 80.0)
				if jugador.obtener_objetivo_interaccion() == foco.cuerpo:
					encontrada = true
					break
			if encontrada:
				break
		jugador.velocity = Vector3.ZERO
		await _cuadros(10)
		_verificar(jugador.obtener_objetivo_interaccion() == foco.cuerpo, "La mesa flotante conserva su alcance de interacción: " + id)
		var tecla := InputEventAction.new()
		tecla.action = jugador.interaction_action
		tecla.pressed = true
		jugador._input(tecla)
		await _cuadros(65)
		return
	_verificar(false, "Existe la estación: " + id)


func _cuadros(cantidad: int) -> void:
	for i in cantidad:
		await physics_frame
		await process_frame


func _capturar(nombre: String, detalle := false) -> void:
	if DisplayServer.get_name() == "headless" or not "--capturas" in OS.get_cmdline_user_args():
		return
	var anterior := root.get_camera_3d()
	var camara: Camera3D
	if detalle:
		camara = Camera3D.new()
		oficina.add_child(camara)
		camara.cull_mask = 524287
		camara.fov = 43
		camara.global_position = oficina.jugador.global_position + Vector3(1.2, 1.45, 1.5)
		camara.look_at(oficina.jugador.global_position + Vector3.UP * 0.70)
		camara.make_current()
		oficina.get_node("CanvasLayer").hide()
		await process_frame
	await RenderingServer.frame_post_draw
	var carpeta := "res://.godot/inundacion_qa"
	DirAccess.make_dir_recursive_absolute(carpeta)
	root.get_texture().get_image().save_png(carpeta.path_join(nombre + ".png"))
	if detalle:
		camara.queue_free()
		anterior.make_current()
		oficina.get_node("CanvasLayer").show()


func _verificar(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("[OK] " + mensaje)
	else:
		errores += 1
		push_error(mensaje)
