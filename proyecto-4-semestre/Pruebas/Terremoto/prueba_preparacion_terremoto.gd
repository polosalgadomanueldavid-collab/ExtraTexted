extends SceneTree
## --headless --fixed-fps 60 --script res://Pruebas/Terremoto/prueba_preparacion_terremoto.gd

var errores := 0
var oficina: Node3D
var evento: Node3D


func _initialize() -> void:
	_probar.call_deferred()


func _esperar_preparacion(objetivo: Node3D) -> void:
	var limite := Time.get_ticks_msec() + 20000
	while objetivo.preparando and not objetivo.plan_preparado and Time.get_ticks_msec() < limite:
		await process_frame
	_verificar(objetivo.plan_preparado, "La preparación termina con un plan válido")


func _esperar_cancelacion() -> void:
	for i in range(100):
		if not evento.preparando: break
		await process_frame
	_verificar(not evento.preparando and evento._trazado.is_empty() and evento.escombros.is_empty(), "Cancelar retira todos los nodos preparados")


func _probar() -> void:
	var menu := root.get_node("MenuGlobal")
	menu.omitir_tutorial_siguiente_partida = true
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	for i in range(5): await physics_frame
	menu.cerrar_ayuda()
	oficina.tutoriales_vistos[&"terremoto"] = true
	oficina.temporizador_eventos.stop()
	oficina.temporizador_denuncias.stop()
	oficina.temporizador_bloqueos.start(30.0)
	var plazo_bloqueos: float = oficina.temporizador_bloqueos.time_left
	evento = oficina.evento_terremoto
	var jugador: CharacterBody3D = oficina.jugador
	jugador.set_physics_process(false)
	var posicion := jugador.global_position
	var grafo: GrafoPiso = oficina.grafo_piso
	var bloqueos: Dictionary = oficina.bloqueos_visuales.duplicate()
	evento._azar.seed = 8762
	var inicio := Time.get_ticks_usec()
	_verificar(evento.iniciar(grafo, jugador, oficina.bloqueos_visuales, Rect2(), true), "Se acepta la preparación")
	print("[PREPARACION] solicitar: %d us" % (Time.get_ticks_usec() - inicio))
	_verificar(evento.preparando and not evento.activo and evento._trazado.is_empty() and evento.escombros.is_empty(), "Solicitar no planifica ni monta visuales de forma síncrona")
	_verificar(not evento.iniciar(grafo, jugador, oficina.bloqueos_visuales, Rect2()), "Se rechaza una solicitud duplicada")
	_verificar(not oficina._puede_iniciar_evento() and not oficina.evento_inundacion.iniciar(), "La preparación impide solapar eventos")
	oficina._cambiar_bloqueo_temporal()
	_verificar(oficina.bloqueos_visuales == bloqueos, "Las mesas permanecen estables durante la preparación")
	await process_frame
	paused = true
	# Dejar que el lote en curso alcance su punto de cesión y comprobar la pausa.
	await process_frame
	var cuadros: int = evento._presupuesto.cuadros
	for i in range(4): await process_frame
	_verificar(evento._presupuesto.cuadros == cuadros and not evento.activo and evento.tiempo == 0.0, "La pausa detiene la preparación sin consumir el aviso")
	paused = false
	await _esperar_preparacion(evento)
	if not evento.plan_preparado:
		quit(1)
		return
	print("[PREPARACION] %d lotes, mayor lote: %d us" % [evento._presupuesto.cuadros, evento._presupuesto.maximo_lote_usec])
	print("[PREPARACION] lote medio: %.1f us, lotes >4 ms: %d" % [float(evento._presupuesto.total_lotes_usec) / evento._presupuesto.cuadros, evento._presupuesto.lotes_sobre_4ms])
	_verificar(evento._presupuesto.cuadros > 1, "La planificación y el montaje ceden entre cuadros")
	_verificar(not evento.activo and evento.tiempo == 0.0 and evento._aviso_gigante == null and grafo.grietas.is_empty(), "Montar no inicia el aviso ni abre el suelo antes de autorizar")
	_verificar(oficina.temporizador_bloqueos.paused and is_equal_approx(oficina.temporizador_bloqueos.time_left, plazo_bloqueos), "La preparación conserva el tiempo restante de los cajones")
	var plan: Dictionary = evento.exportar_trazado_red()
	var forma: Dictionary = plan.formas[0]
	jugador.global_position = Vector3(forma.centro.x, posicion.y, forma.centro.y)
	_verificar(not evento.autorizar_plan() and evento.preparando, "Moverse a una grieta pendiente impide autorizar el plan")
	jugador.global_position = posicion
	var inicio_validacion := Time.get_ticks_usec()
	_verificar(evento.validar_plan_actual(), "La posición segura conserva el plan")
	print("[PREPARACION] validación final: %d us" % (Time.get_ticks_usec() - inicio_validacion))
	evento.actualizar_contexto = Callable()
	evento.hojas_red.append(Vector3(forma.centro.x, posicion.y, forma.centro.y))
	_verificar(not evento.validar_plan_actual(), "Una hoja recién llegada a la grieta invalida el plan")
	evento.hojas_red.clear()
	evento.posiciones_red.append(Vector3(forma.centro.x, posicion.y, forma.centro.y))
	_verificar(not evento.validar_plan_actual(), "Se revalida también la posición actual de los jugadores LAN")
	evento.posiciones_red.clear()
	var espacio: Rect2i = plan.espacios[0]
	var punto := grafo.celda_a_posicion(espacio.position)
	jugador.global_position = Vector3(punto.x, posicion.y, punto.z)
	_verificar(not evento.validar_plan_actual(), "La huella del derrumbe protege la posición actual")
	jugador.global_position = posicion
	var celda := grafo.celda_de_acceso(posicion)
	grafo.escombros[celda] = true
	_verificar(not evento.validar_plan_actual(), "Cambiar la ocupación del grafo invalida el plan")
	grafo.escombros.erase(celda)
	var replica := load("res://Eventos/Terremoto/evento_terremoto.gd").new() as Node3D
	replica.suelo = evento.suelo
	replica.techo = evento.techo
	oficina.add_child(replica)
	_verificar(replica.importar_trazado_red(plan, grafo, jugador, oficina.bloqueos_visuales), "El cliente acepta exclusivamente el plan recibido")
	await _esperar_preparacion(replica)
	_verificar(replica.exportar_trazado_red() == plan and not replica.activo, "La réplica monta el mismo plan y espera autorización")
	for i in range(evento.escombros.size()):
		var original: Node3D = evento.escombros[i]
		var copia: Node3D = replica.escombros[i]
		_verificar(original._poses == copia._poses and original._tamano == copia._tamano, "La semilla visual conserva las piezas y huellas del anfitrión")
	replica.cancelar_preparacion()
	_verificar(not replica.preparando and replica.escombros.is_empty(), "Cancelar un plan importado listo limpia el montaje")
	replica.queue_free()
	_verificar(evento.autorizar_plan() and evento.activo and evento.tiempo == 0.0, "La autorización inicia el aviso desde cero")
	evento._cerrar()
	await process_frame
	_verificar(evento.iniciar(grafo, jugador, oficina.bloqueos_visuales, Rect2(), true), "Se puede solicitar otro plan")
	evento.cancelar_preparacion()
	await _esperar_cancelacion()
	_verificar(not oficina.temporizador_bloqueos.paused, "Cancelar restaura el reloj de cajones")
	_verificar(evento.iniciar(grafo, jugador, oficina.bloqueos_visuales, Rect2(), true), "Se puede reintentar después de cancelar")
	while evento.preparando and evento.escombros.is_empty(): await process_frame
	_verificar(not evento.plan_preparado, "Se alcanza un montaje parcial antes del final")
	_verificar(not evento.escombros[0]._restos.visible, "Las piezas parciales permanecen ocultas durante el montaje")
	evento.cancelar_preparacion()
	await _esperar_cancelacion()
	_verificar(evento.iniciar(grafo, jugador, oficina.bloqueos_visuales, Rect2(), true), "Se prepara al salir de la escena")
	await process_frame
	oficina.queue_free()
	for i in range(5): await process_frame
	print("[PREPARACION TERREMOTO] %d errores" % errores)
	quit(1 if errores else 0)


func _verificar(correcto: bool, detalle: String) -> void:
	if not correcto:
		errores += 1
		push_error(detalle)
