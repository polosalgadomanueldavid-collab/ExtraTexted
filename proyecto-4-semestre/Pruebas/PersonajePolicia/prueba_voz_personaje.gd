extends SceneTree
## Integración de la voz seleccionada con acciones reales, prioridades y pausa.

var errores: int = 0


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	var oficina := (load("res://Mundo/Oficina.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(oficina)
	current_scene = oficina
	await _cuadros(4)
	root.get_node("MenuGlobal").call("cerrar_ayuda")
	paused = false
	(oficina.get("temporizador_denuncias") as Timer).stop()
	(oficina.get("temporizador_bloqueos") as Timer).stop()
	var sistema := oficina.get("sistema_despacho") as SistemaDespacho
	sistema.set_process(false)
	await _cuadros(60)
	# Carga el controlador después de registrar los autoloads de la partida.
	var jugador = oficina.get_node("Gameplay/Node3D")
	var voz := jugador.get_node("VozPersonaje") as VozPersonaje
	_verificar(jugador.is_on_floor(), "El personaje inicia apoyado en la oficina real")
	_verificar(not voz.playing, "Aparecer y permanecer quieto no reproduce expresiones")
	for pista: AudioStream in [voz.saludo, voz.esfuerzo, voz.sorpresa, voz.alegria]:
		_verificar(pista != null and pista.resource_path.begins_with("res://Audios/VozPersonaje/Gomosa/"), "La expresión usa la opción 4 seleccionada")
		_verificar(pista is AudioStreamWAV and (pista as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED, "Las expresiones no tienen bucle")
	var reutilizable := (load("res://Personajes/PoliciaAzul/PoliciaAzul.tscn") as PackedScene).instantiate()
	_verificar(reutilizable.get_node_or_null("VozPersonaje") is VozPersonaje, "La escena del laboratorio también incorpora la voz")
	reutilizable.free()

	jugador.play_wave()
	_verificar(voz.playing and voz.stream == voz.saludo, "Saludar reproduce la expresión de saludo")
	_verificar(not jugador.reproducir_expresion(&"saludo"), "Repetir no reinicia la misma expresión")
	_verificar(not jugador.reproducir_expresion(&"esfuerzo") and voz.stream == voz.saludo, "Un esfuerzo no interrumpe el saludo")
	voz.detener()
	voz.tono_base = 1.12
	voz.variacion_tono = 0.0
	jugador.reproducir_expresion(&"esfuerzo")
	_verificar(is_equal_approx(voz.pitch_scale, 1.12), "El tono se puede ajustar sin regenerar los clips")
	await _cuadros(2)
	paused = true
	await create_timer(0.12).timeout
	_verificar(voz.stream_paused, "La voz se pausa con el juego")
	_verificar(not jugador.reproducir_expresion(&"alegria"), "La pausa no inicia expresiones nuevas")
	paused = false
	await _cuadros(2)
	_verificar(not voz.stream_paused, "Reanudar continúa la voz")
	voz.habilitada = false
	_verificar(not voz.playing and not jugador.reproducir_expresion(&"saludo"), "Desactivar la voz la silencia de inmediato")
	voz.habilitada = true
	voz.tono_base = 1.0

	jugador.reset_to_spawn()
	# El punto de aparición de la oficina está por encima del suelo.
	await _cuadros(60)
	_verificar(jugador.is_on_floor(), "El reinicio aterriza antes de probar otro salto")
	Input.action_press(&"policia_prueba_saltar")
	await _cuadros(3)
	Input.action_release(&"policia_prueba_saltar")
	_verificar(voz.playing and voz.stream == voz.esfuerzo, "Un salto real dispara el esfuerzo")
	voz.detener()
	Input.action_press(&"policia_prueba_saltar")
	await _cuadros(1)
	Input.action_release(&"policia_prueba_saltar")
	_verificar(not voz.playing, "Pulsar salto en el aire no produce otro esfuerzo")
	jugador.reset_to_spawn()
	await _cuadros(60)

	var evento = oficina.get_node("EventoApagon")
	_verificar(evento.iniciar_apagon(), "Se inicia el apagón real")
	_verificar(voz.playing and voz.stream == voz.sorpresa, "El inicio del apagón dispara sorpresa")
	_verificar(not evento.iniciar_apagon(), "Un apagón activo no vuelve a iniciar")
	var denuncia := Denuncia.new()
	denuncia.id = "VOZ-GOMOSA-INTEGRACION"
	denuncia.protocolo_estaciones = ["bienestar", "reporte"]
	sistema.recibir_denuncia(denuncia)
	sistema.iniciar_denuncia_prioritaria()
	_verificar(not sistema.interactuar_estacion("ajena") and voz.stream == voz.sorpresa, "Una estación incorrecta no celebra")
	_verificar(sistema.interactuar_estacion("bienestar"), "Se completa una estación válida del caso")
	_verificar(voz.playing and voz.stream == voz.alegria, "La tarea completada dispara alegría y sustituye la sorpresa")
	_verificar(not sistema.interactuar_estacion("bienestar"), "La tarea repetida no vuelve a completarse")
	await voz.finished
	_verificar(not jugador.reproducir_expresion(&"alegria"), "Al terminar hay una pausa breve entre expresiones")
	await create_timer(0.20).timeout
	_verificar(jugador.reproducir_expresion(&"saludo"), "Después de la pausa se puede volver a hablar")
	jugador.reset_to_spawn()
	_verificar(not voz.playing and voz.expresion_actual == &"", "Volver al centro detiene la expresión anterior")

	oficina.queue_free()
	await _cuadros(2)
	await create_timer(0.12).timeout
	print("PRUEBA VOZ PERSONAJE: %d errores" % errores)
	quit(0 if errores == 0 else 1)


func _cuadros(cantidad: int) -> void:
	for cuadro: int in cantidad:
		await physics_frame
		await process_frame


func _verificar(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("OK: " + mensaje)
	else:
		errores += 1
		push_error(mensaje)
