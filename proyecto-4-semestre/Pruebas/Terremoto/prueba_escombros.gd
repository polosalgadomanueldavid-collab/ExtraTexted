extends SceneTree
## --headless --fixed-fps 60 --script res://Pruebas/Terremoto/prueba_escombros.gd
## Añadir -- --capturas para guardar el aviso, la caída y el bloqueo con renderizado.

const Escombro := preload("res://Eventos/Terremoto/escombro.gd")
var oficina: Node3D
var evento: Node3D
var grafo: GrafoPiso
var jugador: CharacterBody3D
var errores := 0
var impactos := 0


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
	evento = oficina.evento_terremoto
	grafo = oficina.grafo_piso
	jugador = oficina.jugador
	jugador.set_physics_process(false)
	oficina.temporizador_denuncias.stop()
	oficina.computador.timer_nuevo_problema.stop()
	evento.escombros_actualizados.connect(func() -> void: impactos += 1)
	var inicio := jugador.global_position
	for semilla: int in [8762, 14, 927, 951, 1307, 2026, 13, 114]:
		jugador.global_position = inicio
		oficina.generador_aleatorio.seed = semilla
		oficina._cambiar_bloqueo_temporal()
		await _fisicas(70)
		oficina.temporizador_bloqueos.stop()
		oficina.temporizador_eventos.stop()
		evento._azar.seed = semilla
		var reloj := Time.get_ticks_msec()
		var inicio_correcto: bool = evento.iniciar(grafo, jugador, oficina.bloqueos_visuales, Rect2())
		print("[DISTRIBUCION] %d: %d grietas, %d escombros, %d ms" % [semilla, evento._trazado.size(), evento.escombros.size(), Time.get_ticks_msec() - reloj])
		_verificar(inicio_correcto, "El terremoto puede empezar con la distribución %d" % semilla)
		if not inicio_correcto:
			continue
		evento.set_physics_process(false)
		_verificar(evento._trazado.size() >= 10, "Se abren al menos diez grietas")
		_verificar(evento.escombros.size() >= 14, "Se preparan varios derrumbes entre las grietas")
		if evento.escombros.is_empty():
			evento._cerrar()
			continue
		var superiores := 0
		var pasos_cerrados := 0
		for escombro in evento.escombros:
			if escombro.global_position.z < 6.9:
				superiores += 1
				for celda in escombro.celdas:
					if grafo.es_transitable(celda):
						pasos_cerrados += 1
		print("[ZONAS] arriba=%d descanso=%d pasos cerrados=%d" % [superiores, evento.escombros.size() - superiores, pasos_cerrados])
		_verificar(superiores >= 14 and superiores <= 20 and evento.escombros.size() - superiores <= 3, "Hay entre 14 y 20 derrumbes arriba y como máximo tres en descanso")
		_verificar(pasos_cerrados >= 4, "Los escombros bloquean varios pasos nuevos de la oficina")
		var anchos := 0
		for escombro in evento.escombros:
			if escombro.celdas.size() > 1:
				anchos += 1
		_verificar(anchos >= 2, "Varios montones ocupan dos casillas y obligan a rodearlos")
		if "--solo-distribuciones" in OS.get_cmdline_user_args():
			evento._cerrar()
			continue
		var gigante: Node3D = evento.grieta_gigante
		_verificar(gigante != null and not gigante.saltable and gigante.limites.get_area() > 7.0, "Hay una grieta gigante que ocupa buena parte de descanso")
		_verificar(is_instance_valid(evento._aviso_gigante) and evento._aviso_gigante.visible, "El contorno de la grieta gigante avisa antes de abrirse")
		_verificar(grafo.es_zona_segura(grafo.posicion_a_celda(Vector3(gigante.centro.x, 0, gigante.centro.y))), "La gigante está dentro de la antigua zona segura")
		for escombro in evento.escombros:
			_verificar(escombro.collision_layer == 0 and not escombro._restos.visible, "Antes de la rotura no hay escombros ni colisiones invisibles")
		var aplastados: Dictionary = {}
		for escombro in evento.escombros:
			for celda in escombro.celdas:
				if oficina.bloqueos_visuales.has(celda) and not evento._celdas_caidas.has(celda):
					aplastados[celda] = oficina.bloqueos_visuales[celda]
					_verificar(escombro._aviso.position.y > 0.91, "El aviso se ve sobre el cajón que será aplastado")
		_verificar(grafo.escombros.is_empty(), "El aviso inicial no bloquea el grafo")
		await _fisicas(150)
		evento._abrir_suelo()
		_verificar(not is_instance_valid(evento._aviso_gigante), "La rotura retira el contorno de aviso")
		await _fisicas(60)
		var primero: Escombro = evento.escombros[0]
		evento._actualizar_escombros(0.5)
		_verificar(primero._aviso.visible and not primero._restos.visible and primero.collision_layer == 0, "La marca advierte antes de caer y deja pasar")
		await _capturar("escombros_aviso", semilla)
		# Reanudar el proceso real solo para comprobar que hereda la pausa.
		evento.tiempo = 8.5
		evento.set_physics_process(true)
		paused = true
		var instante := primero._tiempo
		var progreso: float = primero._material_aviso.get_shader_parameter("progreso")
		await _fisicas(8)
		_verificar(primero._tiempo == instante, "La pausa congela avisos y caídas")
		_verificar(primero._material_aviso.get_shader_parameter("progreso") == progreso, "El indicador de impacto también se congela al pausar")
		paused = false
		evento.set_physics_process(false)
		evento._actualizar_escombros(1.0)
		_verificar(primero._material_aviso.get_shader_parameter("progreso") > progreso, "El borde de cuenta atrás avanza durante el aviso y la caída")
		_verificar(primero._restos.visible and primero._restos.position.y > 0.5 and primero.collision_layer == 0, "Los restos descienden desde el techo antes de convertirse en obstáculo")
		await _capturar("escombros_caida", semilla)
		# Entrar en el punto de impacto no puede dejar al personaje atrapado.
		jugador.global_position = primero.global_position
		impactos = 0
		evento._actualizar_escombros(2.5)
		_verificar(impactos < evento.escombros.size(), "Las últimas oleadas aún no han impactado")
		evento._actualizar_escombros(4.0)
		await _fisicas(3)
		_verificar(impactos == evento.escombros.size(), "Cada caída actualiza las rutas exactamente una vez")
		_verificar(grafo.es_transitable(grafo.posicion_a_celda(jugador.global_position)), "El impacto devuelve al jugador a una celda libre")
		for celda in aplastados:
			_verificar(not oficina.bloqueos_visuales.has(celda) and not grafo.bloqueos_temporales.has(celda) and grafo.escombros.has(celda), "El derrumbe sustituye al cajón sin liberar su casilla")
			_verificar(aplastados[celda].collision_layer == 0 and evento.caidos.has(aplastados[celda]), "El cajón aplastado queda listo para volver al pool")
		var destinos: Array = GrafoPiso.DESTINOS.values()
		for acceso: Node3D in get_nodes_in_group("accesos_navegacion"):
			destinos.append(grafo.posicion_a_celda(acceso.global_position))
		var rutas := grafo.celdas_alcanzables(grafo.celda_de_acceso(jugador.global_position))
		for destino: Vector2i in destinos:
			_verificar(rutas.has(destino), "Los derrumbes conservan acceso a %s" % destino)
		var montones: Array = evento.escombros.duplicate()
		for escombro: Escombro in montones:
			_verificar(escombro.asentado and not escombro._aviso.visible, "Al impactar desaparece la marca de aviso")
			for celda in escombro.celdas:
				_verificar(grafo.escombros.has(celda) and not grafo.es_transitable(celda), "Todas las celdas del montón bloquean las rutas")
			for grieta in evento.grietas:
				for celda in escombro.celdas:
					var p := grafo.celda_a_posicion(celda)
					_verificar(not grieta.toca_cuadro(Vector2(p.x, p.z), Escombro.RADIO), "Toda la huella del escombro se sostiene entre grietas")
			var desde := escombro.global_position + Vector3(0.0, 0.4, escombro.huella().size.y * 0.5 + 0.06)
			var rayo := PhysicsRayQueryParameters3D.create(desde, escombro.global_position + Vector3.UP * 0.4, 1)
			var golpe := escombro.get_world_3d().direct_space_state.intersect_ray(rayo)
			_verificar(not golpe.is_empty() and golpe.collider == escombro, "Una colisión real impide atravesar el montón")
		evento._actualizar_escombros(1.0)
		_verificar(impactos == montones.size(), "Un montón asentado no repite el impacto")
		await _capturar("escombros_bloqueo", semilla)
		await _capturar_descanso(semilla)
		evento._cerrar()
		_verificar(grafo.escombros.is_empty() and evento.escombros.is_empty(), "El final retira todos los bloqueos de escombros")
		for escombro: Escombro in montones:
			_verificar(escombro.collision_layer == 0, "Se quita la colisión antes de liberar el nodo")
		await _fisicas(3)
		# Cerrar durante el aviso también tiene que liberar el trazado preparado.
		jugador.global_position = inicio
		evento._azar.seed = semilla
		if evento.iniciar(grafo, jugador, oficina.bloqueos_visuales, Rect2()):
			if semilla == 8762:
				evento._abrir_suelo()
				evento._actualizar_escombros(1.5)
			evento._cerrar()
			_verificar(evento._trazado.is_empty() and evento.escombros.is_empty() and grafo.grietas.is_empty() and grafo.escombros.is_empty(), "Se puede interrumpir el aviso o la caída sin residuos")
		await _fisicas(2)
	# Más distribuciones, protegiendo también una hoja suelta junto al jugador.
	for semilla in range(30, 54):
		jugador.global_position = inicio
		oficina.generador_aleatorio.seed = semilla
		oficina._cambiar_bloqueo_temporal()
		evento._azar.seed = semilla
		var huella := Rect2(Vector2(inicio.x, inicio.z) + Vector2(0.3, -0.1), Vector2(0.2, 0.2))
		var aceptado: bool = evento.iniciar(grafo, jugador, oficina.bloqueos_visuales, huella)
		_verificar(aceptado, "Se encuentra un trazado con hoja protegida para la semilla %d" % semilla)
		if aceptado:
			for escombro in evento.escombros:
				_verificar(not escombro.huella().intersects(huella), "Los escombros respetan la hoja suelta")
			evento._cerrar()
		await _fisicas(2)
	oficina.queue_free()
	await process_frame
	# El mezclador termina de liberar las voces en tiempo real con --fixed-fps.
	var fin_audio := Time.get_ticks_msec() + 250
	while Time.get_ticks_msec() < fin_audio:
		OS.delay_msec(4)
		await process_frame
	print("[ESCOMBROS] %d errores" % errores)
	quit(1 if errores else 0)


func _capturar(nombre: String, semilla: int) -> void:
	if semilla != 8762 or DisplayServer.get_name() == "headless" or not "--capturas" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var carpeta := "res://.godot/terremoto_qa"
	DirAccess.make_dir_recursive_absolute(carpeta)
	root.get_texture().get_image().save_png(carpeta.path_join(nombre + ".png"))


func _capturar_descanso(semilla: int) -> void:
	if semilla != 8762 or DisplayServer.get_name() == "headless" or not "--capturas" in OS.get_cmdline_user_args():
		return
	var camara := Camera3D.new()
	oficina.add_child(camara)
	camara.global_position = Vector3(-0.8, 14.5, 9.5)
	camara.look_at(Vector3(-0.8, 0.4, 8.8))
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.size = 8.5
	camara.cull_mask = (oficina.get_node("Gameplay/Camera3D") as Camera3D).cull_mask
	camara.make_current()
	await _capturar("grieta_gigante", semilla)
	var escombro: Escombro = evento.escombros.back()
	for candidato: Escombro in evento.escombros:
		if candidato.celdas.size() > 1 and candidato.global_position.z < 6.0:
			escombro = candidato
			break
	camara.projection = Camera3D.PROJECTION_PERSPECTIVE
	camara.global_position = escombro.global_position + Vector3(-0.6, 1.0, 0.9)
	camara.look_at(escombro.global_position + Vector3.UP * 0.3)
	await _capturar("escombros_detalle", semilla)
	camara.queue_free()
	(oficina.get_node("Gameplay/Camera3D") as Camera3D).make_current()


func _fisicas(cantidad: int) -> void:
	for i in range(cantidad):
		await physics_frame


func _verificar(condicion: bool, mensaje: String) -> void:
	if not condicion:
		errores += 1
		push_error(mensaje)
