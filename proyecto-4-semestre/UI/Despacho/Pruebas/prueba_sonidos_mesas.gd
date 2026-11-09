extends Node
## Acciones reales de las cinco mesas, silencios, reintentos y pausa del audio.

var errores: int = 0
var oficina: Node3D
var sistema: SistemaDespacho


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_probar")


func _probar() -> void:
	oficina = (load("res://Mundo/Oficina.tscn") as PackedScene).instantiate()
	oficina.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(oficina)
	for cuadro: int in range(6):
		await get_tree().process_frame
	oficina.temporizador_denuncias.stop()
	oficina.temporizador_bloqueos.stop()
	sistema = oficina.sistema_despacho
	sistema.set_process(false)
	var audio: Node = oficina.sonidos_mesas
	var evidencias: Control = oficina.clasificador_evidencias
	var escaner: Control = oficina.escaner_verificacion
	_verificar(not audio.seguridad.playing and not audio.impresora.playing and not escaner.sonido_barrido.playing, "La oficina inicia en silencio")
	var denuncia := Denuncia.new()
	denuncia.id = "SONIDOS-MESAS"
	denuncia.titulo = "Prueba de sonidos de oficina"
	denuncia.protocolo_estaciones = ["evidencias", "verificacion", "privacidad", "reporte", "bienestar"]
	sistema.recibir_denuncia(denuncia)
	sistema.iniciar_denuncia_prioritaria()

	oficina.interactuar_estacion("evidencias")
	var seleccion_inicial: int = evidencias.seleccion
	_tecla(evidencias, KEY_D)
	_verificar(evidencias.seleccion == seleccion_inicial and not evidencias.sonido_hoja.playing, "La entrada del planillero no permite pasar hojas ni sonar")
	await get_tree().create_timer(0.54).timeout
	_tecla(evidencias, KEY_D)
	_verificar(evidencias.seleccion != seleccion_inicial and evidencias.sonido_hoja.playing, "Cambiar de hoja reproduce papel real")
	var primera_pista: AudioStream = evidencias.sonido_hoja.stream
	_tecla(evidencias, KEY_A)
	_verificar(evidencias.sonido_hoja.playing and evidencias.sonido_hoja.stream != primera_pista, "Los cambios alternan las grabaciones de papel")
	get_tree().paused = true
	await get_tree().create_timer(0.1).timeout
	_verificar(evidencias.sonido_hoja.stream_paused, "El papel se pausa con el juego")
	get_tree().paused = false
	var objetivo: int = evidencias.objetivos[0]
	evidencias.seleccion = (evidencias.papeles.find(objetivo) + 1) % evidencias.papeles.size()
	_tecla(evidencias, KEY_E)
	_verificar(evidencias.sonido_error.playing and evidencias.archivados == 0, "Una hoja incorrecta avisa sin dar progreso")
	for indice: int in range(2):
		evidencias.seleccion = evidencias.papeles.find(evidencias.objetivos[evidencias.archivados])
		_tecla(evidencias, KEY_E)
		_verificar(evidencias.sonido_archivar.playing and evidencias.archivados == indice + 1, "Archivar una hoja reproduce su golpe de papel")
	evidencias.sonido_hoja.stop()
	_tecla(evidencias, KEY_D)
	_verificar(evidencias.papeles.size() == 1 and not evidencias.sonido_hoja.playing, "Con una sola hoja no suena un cambio inexistente")
	_tecla(evidencias, KEY_ESCAPE)
	_verificar(not evidencias.visible and not evidencias.sonido_archivar.playing, "Salir del planillero corta sus sonidos")
	oficina.interactuar_estacion("evidencias")
	await get_tree().create_timer(0.54).timeout
	_tecla(evidencias, KEY_E)
	_verificar(not evidencias.visible and denuncia.estaciones_completadas.has("evidencias") and evidencias.sonido_archivar.playing, "La última hoja se oye y completa la tarea real")

	oficina.interactuar_estacion("verificacion")
	_verificar(not escaner.sonido_barrido.playing, "El motor espera a que aparezca el escáner")
	await get_tree().create_timer(0.55).timeout
	_verificar(escaner.marcador > 0 and escaner.sonido_barrido.playing, "El motor acompaña el movimiento de la luz")
	var pista_barrido := escaner.sonido_barrido.stream as AudioStreamWAV
	_verificar(pista_barrido.loop_mode == AudioStreamWAV.LOOP_FORWARD and absf(pista_barrido.get_length() - 2.0 / escaner.VELOCIDAD) < 0.001, "El bucle corresponde a una ida y vuelta completas")
	get_tree().paused = true
	var posicion_luz: float = escaner.marcador
	await get_tree().create_timer(0.1).timeout
	_verificar(escaner.marcador == posicion_luz and escaner.sonido_barrido.stream_paused, "Pausa congela luz y motor juntos")
	get_tree().paused = false
	escaner.marcador = 0.0
	_tecla(escaner, KEY_E)
	_verificar(not escaner.sonido_barrido.playing and escaner.sonido_error.playing and escaner.error_restante > 0, "Fallar detiene el motor y reproduce el aviso")
	await get_tree().create_timer(0.65).timeout
	_verificar(escaner.sonido_barrido.playing, "El motor vuelve al reiniciarse el barrido")
	_tecla(escaner, KEY_ESCAPE)
	_verificar(not escaner.visible and not escaner.sonido_barrido.playing and not escaner.sonido_error.playing, "Salir del escáner detiene todo su audio")
	oficina.interactuar_estacion("verificacion")
	await get_tree().create_timer(0.55).timeout
	escaner.marcador = escaner.zona_centro
	_tecla(escaner, KEY_E)
	_verificar(denuncia.estaciones_completadas.has("verificacion") and not escaner.sonido_barrido.playing, "Un acierto completa la tarea y apaga el motor")

	oficina.interactuar_estacion("privacidad")
	_verificar(audio.seguridad.playing, "Desencriptar inicia las teclas de seguridad")
	await get_tree().create_timer(0.1).timeout
	var restante: float = oficina.temporizador_seguridad.time_left
	oficina.interactuar_estacion("privacidad")
	_verificar(oficina.temporizador_seguridad.time_left == restante, "Repetir E no reinicia el desencriptado")
	get_tree().paused = true
	await get_tree().create_timer(0.1).timeout
	_verificar(audio.seguridad.stream_paused and oficina.temporizador_seguridad.time_left == restante, "Pausa conserva el desencriptado y sus teclas")
	get_tree().paused = false
	await oficina.temporizador_seguridad.timeout
	_verificar(not audio.seguridad.playing and audio.aviso_seguridad.playing and oficina._seguridad_lista, "Archivo listo reemplaza las teclas por dos pitidos")
	oficina.interactuar_estacion("privacidad")
	_verificar(denuncia.estaciones_completadas.has("privacidad") and not audio.seguridad.playing, "Recoger el archivo conserva el progreso y el silencio del bucle")

	oficina.probabilidad_atasco_reporte = 1.0
	oficina.interactuar_estacion("reporte")
	_verificar(audio.impresora.playing and audio.impresora.stream == audio.ATASCO and not denuncia.estaciones_completadas.has("reporte"), "Un atasco suena sin completar el reporte")
	oficina.recoger_herramienta_reporte(oficina.jugador)
	oficina.interactuar_estacion("reporte")
	_verificar(audio.impresora.playing and audio.impresora.stream == audio.REPARAR and denuncia.estaciones_completadas.has("reporte"), "Reparar suena y entrega el reporte")
	oficina.interactuar_estacion("bienestar")
	_verificar(audio.bienestar.playing and denuncia.estado == Denuncia.Estado.RESUELTA, "Bienestar tiene su toque propio incluso al cerrar el caso")

	var siguiente := Denuncia.new()
	siguiente.id = "SONIDOS-CANCELACION"
	siguiente.protocolo_estaciones = ["reporte", "privacidad", "verificacion"]
	sistema.recibir_denuncia(siguiente)
	sistema.iniciar_denuncia_prioritaria()
	oficina.probabilidad_atasco_reporte = 0.0
	oficina.interactuar_estacion("reporte")
	_verificar(audio.impresora.playing and audio.impresora.stream == audio.IMPRESORA, "Una impresión sin atasco tiene sonido de rodillos")
	oficina.interactuar_estacion("privacidad")
	oficina.interactuar_estacion("verificacion")
	await get_tree().create_timer(0.55).timeout
	_verificar(audio.seguridad.playing and escaner.sonido_barrido.playing, "Cada mesa mantiene únicamente su actividad vigente")
	sistema.vencer_denuncia(siguiente.id)
	_verificar(not audio.seguridad.playing and not audio.aviso_seguridad.playing and not escaner.sonido_barrido.playing and not escaner.visible, "Vencer el caso cancela ambos bucles y cierra el escáner")
	oficina.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.12).timeout
	print("PRUEBA SONIDOS MESAS: %d errores" % errores)
	get_tree().quit(0 if errores == 0 else 1)


func _tecla(panel: Control, codigo: int) -> void:
	var evento := InputEventKey.new()
	evento.physical_keycode = codigo
	evento.pressed = true
	panel._input(evento)


func _verificar(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("OK: " + mensaje)
	else:
		errores += 1
		push_error(mensaje)
