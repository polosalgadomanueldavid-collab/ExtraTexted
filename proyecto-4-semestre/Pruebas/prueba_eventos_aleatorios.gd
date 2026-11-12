extends SceneTree
## --headless --fixed-fps 60 --script res://Pruebas/prueba_eventos_aleatorios.gd

var oficina: Node3D
var errores := 0


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	var menu := root.get_node("MenuGlobal")
	menu.omitir_tutorial_siguiente_partida = true
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	await _fisicas(6)
	menu.cerrar_ayuda()
	# El tutorial automático se comprueba en la integración; aquí medir el reloj.
	oficina._tutorial_apagon_mostrado = true
	oficina.generador_aleatorio.seed = 1414
	oficina.evento_terremoto._azar.seed = 8762
	oficina._recibir_denuncia_aleatoria()
	oficina.temporizador_denuncias.stop()
	oficina.temporizador_bloqueos.stop()
	oficina.computador.timer_nuevo_problema.stop()
	oficina.sistema_despacho.set_process(false)
	var reloj: Timer = oficina.temporizador_eventos
	var terremoto: Node3D = oficina.evento_terremoto
	var apagon: Node = oficina.evento_apagon
	_verificar(reloj.time_left >= 40.0 and reloj.time_left <= 65.0, "La primera espera aleatoria es de 40 a 65 segundos")
	_verificar(not terremoto.sonidos.retumbo.playing and not apagon.sonidos.ambiente.playing, "No suenan eventos inactivos")
	# Probar el límite mínimo con tiempo simulado de la partida, sin esperar tiempo real.
	reloj.start(40.0)
	oficina._evento_aleatorio_pendiente = 1
	await _fisicas(2390)
	_verificar(apagon.estado == apagon.Estado.RESTAURADO and not terremoto.activo, "No hay eventos antes de cumplir cuarenta segundos")
	var restante := reloj.time_left
	paused = true
	await _fisicas(60)
	_verificar(is_equal_approx(restante, reloj.time_left), "La pausa no consume el cooldown")
	paused = false
	await _fisicas(20)
	_verificar(apagon.estado == apagon.Estado.APAGADO and reloj.is_stopped(), "El reloj inicia un apagón sin pulsar B y se detiene")
	_verificar(apagon.sonidos.corte.playing and apagon.sonidos.ambiente.playing, "El apagón reproduce el corte y el ambiente en bucle")
	_verificar(not terremoto.iniciar(oficina.grafo_piso, oficina.jugador, oficina.bloqueos_visuales, Rect2()), "El evento de terremoto rechaza el inicio directo durante el apagón")
	await _fisicas(2460)
	_verificar(not terremoto.activo and reloj.is_stopped(), "Un apagón largo no deja vencer un segundo reloj")
	apagon._al_interactuar_taco(oficina.jugador)
	_verificar(apagon.estado == apagon.Estado.REPARANDO, "El apagón entra en reparación")
	oficina._iniciar_terremoto()
	_verificar(not terremoto.activo, "La reparación también bloquea el terremoto")
	apagon._al_cerrar_panel()
	_verificar(reloj.is_stopped(), "Cerrar el panel sin reparar no inicia el cooldown")
	apagon._al_interactuar_taco(oficina.jugador)
	apagon._al_resolver_circuito()
	_verificar(not apagon.sonidos.ambiente.playing and not apagon.sonidos.corte.playing, "Restaurar la luz detiene el ambiente del apagón")
	_verificar(reloj.time_left >= 40.0 and reloj.time_left <= 65.0, "La reparación inicia una espera nueva y completa")
	reloj.start(40.0)
	oficina._evento_aleatorio_pendiente = 0
	await _fisicas(2390)
	_verificar(not terremoto.activo, "El terremoto espera cuarenta segundos desde la restauración")
	await _fisicas(20)
	_verificar(terremoto.activo and reloj.is_stopped(), "El mismo reloj también inicia el terremoto aleatorio")
	_verificar(terremoto.sonidos.retumbo.playing and terremoto.sonidos.crujidos.playing, "El terremoto inicia retumbo y crujidos")
	_verificar(not apagon.iniciar_apagon(), "El apagón rechaza el inicio directo durante un terremoto")
	paused = true
	await _fisicas(2)
	_verificar(terremoto.sonidos.retumbo.stream_paused and terremoto.sonidos.crujidos.stream_paused, "El audio del terremoto se pausa con el juego")
	paused = false
	await _fisicas(480)
	_verificar(terremoto.etapa == terremoto.Etapa.RUPTURA and terremoto.sonidos.impacto.playing, "La rotura del suelo tiene su impacto sincronizado")
	await _fisicas(240)
	var volumen_pico: float = terremoto.sonidos.retumbo.volume_db
	await _fisicas(600)
	_verificar(terremoto.sonidos.retumbo.volume_db < volumen_pico, "El retumbo disminuye durante la recuperación")
	await _fisicas(150)
	_verificar(not terremoto.activo and not terremoto.sonidos.retumbo.playing and not terremoto.sonidos.crujidos.playing, "Al terminar el terremoto no quedan bucles activos")
	_verificar(reloj.time_left > 39.0 and reloj.time_left <= 65.0, "El fin del terremoto vuelve a programar el descanso compartido")
	# Una interacción pospone el evento elegido sin sortear otro ni empezar audio.
	reloj.stop()
	oficina._evento_aleatorio_pendiente = 1
	oficina.jugador.input_locked = true
	oficina._intentar_evento_aleatorio()
	_verificar(apagon.estado == apagon.Estado.RESTAURADO and oficina._evento_aleatorio_pendiente == 1 and not reloj.is_stopped(), "Una interacción aplaza el evento conservando la elección")
	oficina.jugador.input_locked = false
	oficina._intentar_evento_aleatorio()
	_verificar(apagon.estado == apagon.Estado.APAGADO, "El evento pendiente inicia al quedar libre el jugador")
	paused = true
	await _fisicas(2)
	_verificar(apagon.sonidos.ambiente.stream_paused, "El ambiente del apagón respeta la pausa")
	paused = false
	oficina.queue_free()
	await process_frame
	print("[EVENTOS ALEATORIOS] %d errores" % errores)
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
