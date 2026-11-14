extends SceneTree
## --headless --fixed-fps 60 --script res://Pruebas/ZonaDescanso/prueba_expendedora.gd
var oficina: Node3D
var jugador
var maquina: Node3D
var despacho: SistemaDespacho
var errores := 0
var comprobaciones := 0
var origen: Vector3

func _initialize() -> void:
	_probar.call_deferred()

func _probar() -> void:
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	await _cuadros(8)
	root.get_node("MenuGlobal").cerrar_ayuda()
	paused = false
	jugador = oficina.jugador
	maquina = oficina.get_node("MaquinaExpendedora")
	despacho = oficina.sistema_despacho
	for nombre: StringName in [&"apagon", &"terremoto", &"incendio", &"inundacion", &"lava", &"hielo"]:
		oficina.tutoriales_vistos[nombre] = true
	_parar_relojes()
	oficina.anuncios.detener()
	await _cuadros(65)
	origen = jugador.global_position
	await _compras()
	await _consumibles()
	await _tiempo()
	await _avatar()
	await _mesa_con_dona()
	await _limpieza()
	oficina.queue_free()
	await _cuadros(8)
	print("[EXPENDEDORA] %d comprobaciones, %d errores" % [comprobaciones, errores])
	quit(0 if errores == 0 else 1)

func _compras() -> void:
	var encontrada := false
	for i in 100:
		jugador.global_position = maquina.global_position + Vector3(1.6 - i * 0.01, 0.01, 0)
		jugador.visual.rotation.y = -PI / 2.0
		if jugador.obtener_objetivo_interaccion() == maquina:
			encontrada = true
			break
	await _cuadros(5)
	_verificar(encontrada and jugador.obtener_objetivo_interaccion() == maquina, "La máquina se alcanza desde el pasillo real")
	_tecla(KEY_E)
	await _cuadros(2)
	_verificar(maquina.panel.visible and jugador.input_locked, "E abre la tienda y fija al comprador")
	_verificar(not maquina.comprar(0) and despacho.puntuacion.puntos == 0, "Saldo insuficiente no entrega productos")
	for i in 40:
		var premio := Denuncia.new()
		premio.id = "PREMIO-%d" % i
		premio.estado = Denuncia.Estado.RESUELTA
		despacho.puntuacion.registrar_resolucion(premio)
	var saldo := despacho.puntuacion.puntos
	for i in 4:
		_verificar(maquina.comprar(i), "Compra del producto %d" % i)
	_verificar(despacho.puntuacion.puntos == saldo - 525, "Cobra una vez los cuatro precios")
	saldo = despacho.puntuacion.puntos
	_verificar(not maquina.comprar(0) and despacho.puntuacion.puntos == saldo, "No cobra duplicados")
	_tecla(KEY_ESCAPE)
	await _cuadros(2)
	_verificar(not maquina.panel.visible and not jugador.input_locked and not paused, "Escape cierra sin abrir la pausa")
	jugador.global_position = origen
	await _cuadros(5)

func _consumibles() -> void:
	_verificar(maquina.usar(0), "Chocolate inicia un bocado")
	_verificar(not maquina.usar(0) and jugador.chocolate_restante == 0.0, "No duplica ni aplica antes del bocado")
	jugador.cancelar_gesto()
	await _cuadros(3)
	_verificar(maquina.inventario[0] == 1 and jugador.chocolate_restante == 0, "Cancelar antes de comer conserva el objeto")
	_tecla(KEY_Z)
	await _cuadros(55)
	_verificar(jugador.chocolate_restante > 24.8 and jugador.chocolate_restante <= 25.0 and maquina.inventario[0] == 0, "Chocolate concede 25 s desde el contacto")
	await _cuadros(45)
	# Medir velocidad física real, sin depender de la constante del efecto.
	Input.action_press(jugador.RIGHT)
	Input.action_press(jugador.RUN)
	var maxima := 0.0
	for i in 45:
		await process_frame
		maxima = maxf(maxima, Vector2(jugador.velocity.x, jugador.velocity.z).length())
	_verificar(maxima > jugador.run_speed * 1.4, "Chocolate aumenta la velocidad real de carrera")
	Input.action_release(jugador.RIGHT)
	Input.action_release(jugador.RUN)
	jugador.global_position = origen
	jugador.velocity = Vector3.ZERO
	await _cuadros(8)
	_verificar(maquina.usar(1), "Dona inicia su animación")
	await _cuadros(60)
	_verificar(jugador.dona_restante > 9.7 and jugador.dona_restante <= 10.0, "Dona concede 10 s desde el contacto")
	await _cuadros(45)
	_verificar(jugador.get_node("Visual/Modelo").scale.x > 1.35, "La dona ensancha el modelo sin cambiar su cuerpo de colisión")
	var altura: float = jugador.global_position.y
	Input.action_press(jugador.JUMP)
	await _cuadros(1)
	Input.action_release(jugador.JUMP)
	var cima := altura
	for i in 65:
		await process_frame
		cima = maxf(cima, jugador.global_position.y)
	_verificar(cima - altura > 1.5, "Salto con dona supera la altura de las mesas")
	await _cuadros(560)
	_verificar(jugador.dona_restante == 0.0 and jugador.get_node("Visual/Modelo").scale.x < 1.02, "La dona caduca y devuelve la silueta normal")
	await _cuadros(900)
	_verificar(jugador.chocolate_restante == 0.0, "El chocolate caduca sin acumular velocidad permanente")
	jugador.global_position = origen
	jugador.velocity = Vector3.ZERO
	await _cuadros(8)

func _tiempo() -> void:
	var caso := Denuncia.new()
	caso.id = "CASO-TIEMPO"
	caso.tiempo_limite_segundos = 100.0
	caso.protocolo_estaciones.assign(["bienestar"])
	despacho.recibir_denuncia(caso)
	despacho.iniciar_denuncia_prioritaria()
	_verificar(oficina.evento_inundacion.iniciar(), "Inundación real para comprobar la detención")
	await _cuadros(80)
	oficina.anuncios.detener()
	_verificar(maquina.usar(2), "Papa inicia ZA WARUDO")
	await _cuadros(67)
	_verificar(despacho.tiempo_detenido and not paused, "El mundo se detiene sin pausar el árbol")
	_verificar(maquina.poderes._sonido_detener.playing and not maquina.poderes._sonido_reanudar.playing, "La parada reproduce el MP3 solicitado al iniciar la burbuja")
	_verificar(not maquina.poderes.SONIDO_DETENER.loop and not maquina.poderes.SONIDO_REANUDAR.loop, "Los dos audios se importan sin bucle")
	var tiempo := despacho.obtener_tiempo_restante(caso.id)
	var agua: float = oficina.evento_inundacion.tiempo
	var nivel: float = oficina.evento_inundacion.nivel
	var duracion: float = oficina._duracion_partida
	var restante: float = maquina.poderes.restante
	_verificar(oficina.evento_inundacion._chorro.speed_scale == 0.0 and oficina.evento_inundacion._ambiente.stream_paused, "La papa congela las partículas y el sonido ambiental")
	paused = true
	await _cuadros(60)
	_verificar(is_equal_approx(restante, maquina.poderes.restante), "La pausa normal suspende los 12 segundos")
	paused = false
	await _cuadros(90)
	_verificar(is_equal_approx(tiempo, despacho.obtener_tiempo_restante(caso.id)) and is_equal_approx(agua, oficina.evento_inundacion.tiempo) and is_equal_approx(nivel, oficina.evento_inundacion.nivel), "Se congelan denuncias, nivel y animación del agua")
	_verificar(is_equal_approx(duracion, oficina._duracion_partida), "Se congela la duración del turno")
	_verificar(jugador.is_on_floor(), "Suelo y muebles mantienen sus colisiones durante ZA WARUDO")
	var posicion: Vector3 = jugador.global_position
	Input.action_press(jugador.LEFT)
	await _cuadros(20)
	Input.action_release(jugador.LEFT)
	_verificar(jugador.global_position.distance_to(posicion) > 0.1, "El jugador puede moverse en el mundo detenido")
	# Entrega e interacción usan los mismos gestos y callbacks de la partida.
	oficina._entregar_papel(jugador)
	await _cuadros(55)
	_verificar(is_instance_valid(jugador.papel_en_mano), "Se puede recibir una denuncia durante la detención")
	oficina.interactuar_estacion_con_papel(jugador, "bienestar")
	await _cuadros(70)
	_verificar(caso.estado == Denuncia.Estado.RESUELTA and despacho.tiempo_detenido, "Se completa una denuncia con el reloj detenido")
	await _cuadros(500)
	_verificar(not despacho.tiempo_detenido and maquina.poderes.restante == 0.0, "La detención termina al consumir los 12 segundos")
	_verificar(oficina.evento_inundacion.tiempo > agua and jugador.is_on_floor(), "El mundo reanuda física y eventos")
	_verificar(oficina.evento_inundacion._chorro.speed_scale == 1.0 and not oficina.evento_inundacion._ambiente.stream_paused, "Se restauran partículas y sonido tras los 12 segundos")
	oficina.evento_inundacion.resolver_con_avatar()
	_parar_relojes()
	await _cuadros(45)

func _avatar() -> void:
	_verificar(not maquina.usar(3) and maquina.inventario[3] == 1, "Avatar sin evento conserva la carga")
	for nombre: String in ["inundacion", "incendio", "terremoto", "hielo", "lava", "apagon"]:
		jugador.cancelar_gesto()
		jugador.global_position = origen
		jugador.velocity = Vector3.ZERO
		jugador.input_locked = false
		await _cuadros(10)
		var evento: Node = oficina.get("evento_" + nombre)
		if nombre == "apagon":
			evento.iniciar_apagon()
		elif nombre == "terremoto":
			evento.iniciar(oficina.grafo_piso, jugador, oficina.bloqueos_visuales, Rect2())
		elif nombre == "incendio":
			evento.iniciar(oficina.bloqueos_visuales)
		else:
			evento.iniciar()
		oficina.anuncios.detener()
		await _cuadros(3)
		_verificar(maquina.poderes.evento_actual() == evento, "Se inicia " + nombre)
		maquina.inventario[3] = 1
		_verificar(maquina.usar(3), "Avatar inicia el gesto para " + nombre)
		await _cuadros(90)
		_verificar(maquina.poderes.evento_actual() == evento and maquina.inventario[3] == 1, "El evento espera la animación: " + nombre)
		await _cuadros(145)
		_verificar(maquina.poderes.evento_actual() == null and maquina.inventario[3] == 0, "Avatar resuelve y consume una carga: " + nombre)
		_verificar(not jugador.input_locked and not jugador.nadando and not jugador.hielo_activo and not jugador.lava_activa, "Se restauran controles y estados: " + nombre)
		if nombre == "incendio":
			for foco in evento.focos:
				_verificar(not foco.mesa.get_meta("en_llamas") and foco.apagado == 1.0, "Mesa recuperada por fuego control")
		if nombre == "terremoto":
			_verificar(evento.grietas.is_empty() and evento.escombros.is_empty() and oficina.grafo_piso.grietas.is_empty(), "Tierra control limpia grietas, escombros y navegación")
		_parar_relojes()

func _mesa_con_dona() -> void:
	jugador.global_position = Vector3(-1.5, 0.38, 3.2)
	jugador.velocity = Vector3.ZERO
	await _cuadros(10)
	_verificar(oficina.evento_lava.iniciar(), "Lava permite comprobar la dona sobre una mesa real")
	var lava: Node = oficina.evento_lava
	oficina.anuncios.detener()
	lava.set_physics_process(false)
	_parar_relojes()
	await _cuadros(2)
	var barrera := lava._barreras.get_child(0) as StaticBody3D
	var forma := barrera.get_child(0) as CollisionShape3D
	var centro := barrera.global_position
	var inicio := centro + Vector3(forma.shape.size.x * 0.5 + 0.6, 0, 0)
	jugador.global_position = Vector3(inicio.x, 0.38, inicio.z)
	jugador.velocity = Vector3.ZERO
	jugador.dona_restante = 10.0
	await _cuadros(10)
	Input.action_press(jugador.JUMP)
	Input.action_press(jugador.LEFT)
	await _cuadros(2)
	Input.action_release(jugador.JUMP)
	var sobre_mesa := false
	for i in 65:
		await process_frame
		if jugador.global_position.x <= centro.x + forma.shape.size.x * 0.25:
			Input.action_release(jugador.LEFT)
		if jugador.is_on_floor() and jugador.global_position.y > 0.7:
			sobre_mesa = true
	Input.action_release(jugador.LEFT)
	_verificar(sobre_mesa and not jugador.get_collision_mask_value(8), "La dona permite aterrizar encima de una mesa durante lava")
	jugador.dona_restante = 0.0
	await _cuadros(12)
	_verificar(jugador.is_on_floor() and jugador.global_position.y > 0.7, "Caducar sobre la mesa no introduce una barrera dentro del jugador")
	jugador.global_position = Vector3(-1.5, 0.38, 3.2)
	jugador.velocity = Vector3.ZERO
	await _cuadros(10)
	_verificar(jugador.get_collision_mask_value(8), "Al bajar se restaura la restricción habitual de lava")
	lava.resolver_con_avatar()
	_parar_relojes()
	await _cuadros(5)

func _limpieza() -> void:
	maquina.poderes.detener_tiempo()
	await _cuadros(3)
	maquina.poderes.reanudar_tiempo()
	_verificar(maquina.poderes._sonido_reanudar.playing and not maquina.poderes._sonido_detener.playing, "Reanudar reproduce su MP3 y retira el audio de parada")
	maquina.poderes.limpiar()
	_verificar(not maquina.poderes._sonido_reanudar.playing, "Limpiar silencia los audios sin reproducir una falsa reanudación")
	maquina.poderes.detener_tiempo()
	await _cuadros(5)
	jugador.reset_to_spawn()
	await _cuadros(3)
	_verificar(not despacho.tiempo_detenido and not jugador.tiempo_detenido and jugador.can_process(), "Reiniciar restaura procesos y tiempo")
	_verificar(not maquina.poderes._sonido_detener.playing and not maquina.poderes._sonido_reanudar.playing, "Reiniciar durante la parada silencia ambos efectos")
	maquina.poderes.detener_tiempo()
	await _cuadros(3)
	maquina.queue_free()
	await _cuadros(4)
	_verificar(not despacho.tiempo_detenido and not jugador.tiempo_detenido, "Retirar la máquina no deja el mundo congelado")

func _parar_relojes() -> void:
	for reloj: Timer in [oficina.temporizador_denuncias, oficina.temporizador_bloqueos, oficina.temporizador_eventos, oficina.computador.timer_nuevo_problema]:
		reloj.stop()

func _tecla(tecla: Key) -> void:
	for pulsada: bool in [true, false]:
		var evento := InputEventKey.new()
		evento.physical_keycode = tecla
		evento.pressed = pulsada
		Input.parse_input_event(evento)

func _cuadros(cantidad: int) -> void:
	for i in cantidad:
		await process_frame

func _verificar(condicion: bool, mensaje: String) -> void:
	comprobaciones += 1
	if not condicion:
		errores += 1
		push_error("[EXPENDEDORA] " + mensaje)
	else:
		print("OK: " + mensaje)
