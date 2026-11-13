extends SceneTree
## --headless --fixed-fps 60 --script res://Pruebas/Hielo/prueba_hielo.gd
## Sin --headless, añadir -- --capturas para capturas en .godot/hielo_qa.

var oficina: Node3D
var jugador
var hielo: Node3D
var errores := 0


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var menu := root.get_node("MenuGlobal")
	menu.omitir_tutorial_siguiente_partida = true
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	await _cuadros(70)
	menu.cerrar_ayuda()
	jugador = oficina.jugador
	hielo = oficina.evento_hielo
	oficina.generador_aleatorio.seed = 1235
	oficina.temporizador_denuncias.stop()
	oficina.computador.timer_nuevo_problema.stop()
	oficina.sistema_despacho.set_process(false)
	var caso := Denuncia.new()
	caso.id = "QA-HIELO"
	caso.tiempo_limite_segundos = 600
	caso.protocolo_estaciones.assign(["bienestar", "reporte"])
	oficina.sistema_despacho.recibir_denuncia(caso)
	oficina.bloqueos_iniciados = true
	oficina._entregar_papel(jugador)
	await _cuadros(70)
	oficina.temporizador_bloqueos.stop()
	oficina.temporizador_eventos.stop()
	oficina._limpiar_bloqueos_temporales()
	jugador.global_position = Vector3(-1.3, 0.38, 8.3)
	jugador.velocity = Vector3.ZERO
	await _cuadros(8)
	var mascara: int = jugador.collision_mask
	var aceleracion: float = jugador.acceleration
	var frenado: float = jugador.braking
	jugador.input_locked = true
	_verificar(not oficina._iniciar_hielo(), "Una tarea abierta aplaza Hielo")
	jugador.input_locked = false
	oficina._evento_aleatorio_pendiente = 5
	oficina._intentar_evento_aleatorio()
	_verificar(hielo.activo and jugador.hielo_activo, "La sexta elección aleatoria inicia Hielo")
	if not hielo.activo:
		quit(1)
		return
	_verificar(oficina.anuncios.segunda_linea == "ES HIELO!" and hielo.aviso.visible, "El evento anuncia el hielo y muestra su HUD")
	_verificar(not oficina._puede_iniciar_evento() and not oficina.evento_apagon.iniciar_apagon() and not oficina._iniciar_inundacion() and not oficina._iniciar_lava() and not oficina._iniciar_incendio(), "Hielo impide solapamientos con otros eventos")
	var materiales: Array = hielo._recubiertos.duplicate()
	var luces: Array = hielo._luces.duplicate()
	_verificar(materiales.size() > 20 and luces.size() > 0, "Los muebles y el pool de cajones reciben escarcha")
	await _cuadros(60)
	await _capturar("01_inicio")
	_verificar(float(hielo._material.get_shader_parameter("presencia")) > 0.2 and float(hielo._material.get_shader_parameter("presencia")) < 0.8, "El hielo entra gradualmente desde la fuga")
	await _cuadros(120)
	_verificar(is_equal_approx(hielo._material.get_shader_parameter("presencia"), 1.0) and not jugador.congelado, "La oficina se congela antes del primer bloqueo de control")
	# Medir el frenado y la dirección real sobre un tramo despejado.
	jugador.global_position = Vector3(-1.3, 0.38, 4.0)
	jugador.velocity = Vector3(0, 0, 1.0)
	var posicion: Vector3 = jugador.global_position
	await _cuadros(30)
	_verificar(jugador.velocity.z > 0.75 and jugador.global_position.z > posicion.z + 0.35, "Al soltar el control el policía continúa resbalando")
	await _cuadros(31)
	_verificar(jugador.congelado and not jugador.input_locked, "A los cuatro segundos se congela sin bloquear la interacción")
	var velocidad := Vector2(jugador.velocity.x, jugador.velocity.z)
	posicion = jugador.global_position
	Input.action_press(jugador.LEFT)
	Input.action_press(jugador.JUMP)
	await _cuadros(25)
	Input.action_release(jugador.LEFT)
	Input.action_release(jugador.JUMP)
	_verificar(Vector2(jugador.velocity.x, jugador.velocity.z).distance_to(velocidad) < 0.01 and jugador.global_position.z > posicion.z + 0.15 and jugador.is_on_floor(), "Congelado ignora dirección y salto, pero conserva la inercia")
	_verificar(hielo.capsula.visible and hielo.capsula.peso > 0.9 and jugador.animation_player.speed_scale == 0.0, "El iceberg envuelve al policía y detiene su locomoción")
	await _capturar("02_congelado")
	await _capturar("03_cristal_detalle", true)
	await _cuadros(55)
	_verificar(not jugador.congelado and jugador.animation_player.speed_scale == 1.0, "Recupera control y animación tras 1,25 segundos")
	# Gravedad y choque físico durante un pulso, sin reloj automático para aislarlo.
	hielo.set_physics_process(false)
	hielo.tiempo = 8.1
	hielo._physics_process(0.0)
	jugador.global_position = Vector3(-1.3, 1.0, 4.0)
	jugador.velocity = Vector3(0.2, 0, 0)
	await _cuadros(4)
	_verificar(jugador.velocity.y < 0 and jugador.global_position.y < 1.0, "Congelarse no suspende la gravedad")
	var pared := StaticBody3D.new()
	var colision := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(2, 2, 0.1)
	colision.shape = caja
	pared.add_child(colision)
	oficina.add_child(pared)
	pared.global_position = Vector3(-1.3, 1, 4.9)
	jugador.global_position = Vector3(-1.3, 0.38, 4.0)
	jugador.velocity = Vector3(0, 0, 1)
	await _cuadros(75)
	_verificar(jugador.global_position.z < 4.8 and absf(jugador.velocity.z) < 0.01, "El iceberg choca con obstáculos sin atravesarlos")
	pared.queue_free()
	# La congelación no impide que E entregue una tarea real con su hoja.
	await _usar_estacion("bienestar")
	_verificar(caso.estaciones_completadas.has("bienestar") and hielo.activo and jugador.congelado, "Se completa una estación estando congelado")
	oficina.probabilidad_atasco_reporte = 0.0
	await _usar_estacion("reporte")
	_verificar(oficina.sistema_despacho.obtener_denuncia_activa() == null and hielo.activo, "Se resuelve un caso entero sin reparar primero Hielo")
	hielo.set_physics_process(true)
	jugador.global_position = Vector3(-1.3, 0.38, 8.3)
	jugador.velocity = Vector3.ZERO
	oficina._cambiar_bloqueo_temporal()
	await _cuadros(65)
	var origen: Vector2i = oficina.grafo_piso.celda_de_acceso(jugador.global_position)
	var destino: Vector2i = oficina.grafo_piso.posicion_a_celda(hielo.acceso.global_position)
	_verificar(not oficina.grafo_piso.calcular_ruta(origen, destino).is_empty(), "Los cajones conservan una ruta al nitrógeno")
	var todos_nevados := true
	for bloqueo: Node3D in oficina.bloqueos_visuales.values():
		for malla: Node in bloqueo.find_children("*", "MeshInstance3D", true, false):
			if malla.has_meta(&"nieve_acumulada"):
				continue
			todos_nevados = todos_nevados and malla.material_overlay == hielo._escarcha
	_verificar(todos_nevados, "Los cajones reciclados conservan la capa de nieve")
	await _capturar("04_oficina_nevada")
	# Puzzle: alcance, orden incorrecto, persistencia, pausa, entradas y final.
	jugador.global_position = hielo.acceso.global_position
	jugador.visual.rotation.y = PI * 0.5
	jugador.velocity = Vector3.ZERO
	await _cuadros(8)
	_verificar(jugador.obtener_objetivo_interaccion() == hielo, "La tubería se alcanza desde el acceso de descanso")
	_pulsar_e()
	await _cuadros(3)
	_verificar(hielo.reparando and hielo.panel.visible and jugador.input_locked, "E abre la reparación de nitrógeno")
	var panel = hielo.panel
	_verificar(not panel.apretar((panel.objetivo_actual() + 1) % 4) and panel.paso == 0, "Una tuerca fuera de orden no sella la fuga")
	for i in 5:
		panel.apretar(panel.objetivo_actual())
	panel.cerrar()
	_verificar(not jugador.input_locked and hielo.activo and panel.paso == 5, "Cerrar conserva progreso sin resolver el evento")
	hielo.interactuar(jugador)
	_verificar(panel.paso == 5 and panel.visible, "Reabrir continúa la misma reparación")
	await _capturar("05_puzzle")
	var reloj: float = hielo.tiempo
	var aprietes: Array = panel.aprietes.duplicate()
	paused = true
	await _cuadros(30)
	_verificar(hielo.tiempo == reloj and not panel.apretar(panel.objetivo_actual()) and panel.aprietes == aprietes, "La pausa detiene el ciclo y bloquea el puzzle")
	paused = false
	while not panel.resuelto:
		panel.seleccion = panel.objetivo_actual()
		var tecla := InputEventKey.new()
		tecla.physical_keycode = KEY_E
		tecla.pressed = true
		panel._input(tecla)
	panel.cerrar()
	await _cuadros(48)
	_verificar(hielo.descongelando and not hielo.reparando and not jugador.input_locked and not jugador.congelado, "Doce aprietes sellan la fuga aunque cierres durante la confirmación")
	await _cuadros(160)
	_verificar(not hielo.activo and not jugador.hielo_activo and not hielo.aviso.visible, "El deshielo retira el evento y el HUD")
	var restaurado := true
	for dato: Dictionary in materiales:
		restaurado = restaurado and dato.nodo.material_overlay == dato.material
	for dato: Dictionary in luces:
		restaurado = restaurado and dato.nodo.light_color.is_equal_approx(dato.color)
	_verificar(restaurado and jugador.acceleration == aceleracion and jugador.braking == frenado and jugador.collision_mask == mascara, "Materiales, luces y propiedades físicas se restauran exactamente")
	_verificar(oficina.temporizador_eventos.time_left > 35 and not is_instance_valid(hielo._visuales), "No quedan efectos transitorios y se programa otro evento")
	await _capturar("06_restaurada")
	_verificar(oficina._iniciar_hielo(), "Hielo puede comenzar otra vez sin restos del anterior")
	await _cuadros(4)
	hielo.interactuar(jugador)
	_verificar(hielo.panel.paso == 0 and hielo.reparando, "La siguiente fuga crea una reparación nueva")
	jugador.reset_to_spawn()
	_verificar(not hielo.reparando and not hielo.panel.visible and not jugador.input_locked, "Reiniciar al personaje cierra el panel sin atascar controles")
	jugador.global_position = hielo.acceso.global_position
	jugador.visual.rotation.y = PI * 0.5
	await _cuadros(8)
	hielo.interactuar(jugador)
	oficina._al_terminar_partida()
	_verificar(not hielo.activo and not hielo.reparando and not hielo.panel.visible and not jugador.hielo_activo and not jugador.congelado and jugador.input_locked, "El final de partida limpia la reparación y mantiene bloqueados los controles")
	paused = false
	oficina.queue_free()
	await process_frame
	print("[HIELO] %d errores" % errores)
	quit(1 if errores else 0)


func _pulsar_e() -> void:
	var tecla := InputEventAction.new()
	tecla.action = jugador.interaction_action
	tecla.pressed = true
	jugador._input(tecla)


func _usar_estacion(id: String) -> void:
	for foco in oficina.evento_incendio.focos:
		if foco.estacion_id != id:
			continue
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
		_verificar(jugador.obtener_objetivo_interaccion() == foco.cuerpo, "La nieve conserva la interacción con " + id)
		_pulsar_e()
		await _cuadros(70)
		return
	_verificar(false, "Existe la estación " + id)


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
		camara.global_position = jugador.global_position + Vector3(1.2, 1.45, 1.5)
		camara.look_at(jugador.global_position + Vector3.UP * 0.6)
		camara.make_current()
		oficina.get_node("CanvasLayer").hide()
		await process_frame
	await RenderingServer.frame_post_draw
	var carpeta := "res://.godot/hielo_qa"
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
