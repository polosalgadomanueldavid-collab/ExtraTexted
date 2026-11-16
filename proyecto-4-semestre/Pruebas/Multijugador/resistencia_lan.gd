extends Node
## Dos procesos ENet reales. --host / --client --segundos=1800
## Genera/resuelve casos para probar crecimiento del transporte; las reglas de
## estaciones, poderes y compras se verifican en conductor_lan.gd.
var duracion := 1800.0
var muestras: Array = []
var inicio := 0
var fallos := 0
var secuencia := 0
var ronda_medida := 0
var _ultimo := 0
var _total_enviado := 0.0
var _total_recibido := 0.0
var _terminando := false
var _host_prueba := false
var _final_confirmado := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout

func _run() -> void:
	MenuGlobal.omitir_tutorial_siguiente_partida = true
	MenuGlobal._clasificacion = ClasificacionLocal.new("user://resistencia_%d.json" % OS.get_process_id())
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--segundos="):
			duracion = maxf(10, arg.get_slice("=", 1).to_float())
	var host := "--host" in OS.get_cmdline_user_args()
	_host_prueba = host
	if host:
		if SesionLAN.crear("Resistencia") != OK:
			get_tree().quit(1)
			return
	else:
		await _esperar(1)
		SesionLAN.unirse("127.0.0.1", "Cliente")
	var limite := Time.get_ticks_msec() + 30000
	while SesionLAN.participantes.size() != 2:
		if Time.get_ticks_msec() > limite:
			get_tree().quit(1)
			return
		await _esperar(0.1)
	SesionLAN.establecer_listo(true)
	if host:
		while not SesionLAN.participantes.values().all(func(p): return p.listo):
			await _esperar(0.1)
		SesionLAN.iniciar()
	inicio = Time.get_ticks_msec()
	_ultimo = inicio
	while not _terminando and Time.get_ticks_msec() - inicio < (duracion + 90) * 1000:
		await _esperar(0.5)
		if not SesionLAN.en_partida or not is_instance_valid(SesionLAN.puente):
			continue
		var red: Node = SesionLAN.puente
		var oficina: Node = red.oficina
		if ronda_medida != SesionLAN.ronda:
			ronda_medida = SesionLAN.ronda
			oficina.temporizador_denuncias.stop()
			oficina.temporizador_bloqueos.stop()
			oficina.temporizador_eventos.stop()
		if host:
			secuencia += 1
			var caso := Denuncia.new()
			caso.id = "resistencia-%d" % secuencia
			caso.protocolo_estaciones.assign(["evidencias"])
			red.despacho.recibir_denuncia(caso)
			red.despacho.resolver_denuncia(caso.id)
			red.publicar()
		if Time.get_ticks_msec() - _ultimo >= 10000:
			_muestrear(red)
		var transcurrido := (Time.get_ticks_msec() - inicio) / 1000.0
		if host and transcurrido >= duracion:
			_comprobar_final.rpc(red.despacho.puntuacion.puntos, red._numero_final)
			var fin_espera := Time.get_ticks_msec() + 5000
			while not _final_confirmado and Time.get_ticks_msec() < fin_espera and SesionLAN.activa:
				await _esperar(0.05)
			if not _final_confirmado:
				fallos += 1
			_finalizar.rpc()
			_finalizar()
			return
		if host and transcurrido >= duracion * ronda_medida / 6.0:
			SesionLAN.reiniciar()
	if not _terminando:
		fallos += 1
		_finalizar()

func _muestrear(red: Node) -> void:
	var ahora := Time.get_ticks_msec()
	var segundos := (ahora - _ultimo) / 1000.0
	# Una suspensión del equipo no cuenta como tiempo de juego estable.
	if segundos > 30:
		fallos += 1
		push_warning("Interrupción de %.1f segundos en la prueba de resistencia." % segundos)
	_ultimo = ahora
	var host: ENetConnection = (multiplayer.multiplayer_peer as ENetMultiplayerPeer).host
	var enviados := host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
	var recibidos := host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)
	_total_enviado += enviados
	_total_recibido += recibidos
	var muestra := {"segundos": (ahora - inicio) / 1000.0, "ronda": SesionLAN.ronda,
		"enet_bytes_salida_s": enviados / segundos, "enet_bytes_entrada_s": recibidos / segundos,
		"casos_pendientes": red.despacho.obtener_denuncias_ordenadas().size(),
		"finales_sin_acuse": red._finales_pendientes.size(), "respuestas": SesionLAN._respuestas.size(),
		"nodos": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"objetos": Performance.get_monitor(Performance.OBJECT_COUNT),
		"memoria": Performance.get_monitor(Performance.MEMORY_STATIC)}
	if red._finales_pendientes.size() > 40 or SesionLAN._respuestas.size() > 1024:
		fallos += 1
	muestras.append(muestra)
	print("[RESISTENCIA] ", JSON.stringify(muestra))

@rpc("authority", "call_remote", "reliable", 2)
func _comprobar_final(saldo: int, numero: int) -> void:
	# Acuse por el mismo canal del estado; tolerar la última actualización en vuelo.
	var limite := Time.get_ticks_msec() + 1500
	while is_instance_valid(SesionLAN.puente) and SesionLAN.puente._ultimo_final < numero and Time.get_ticks_msec() < limite:
		await _esperar(0.05)
	if not is_instance_valid(SesionLAN.puente) or SesionLAN.puente.despacho.puntuacion.puntos != saldo or SesionLAN.puente._ultimo_final != numero:
		fallos += 1
	_confirmar_final.rpc_id(1, fallos == 0)

@rpc("any_peer", "call_remote", "reliable", 2)
func _confirmar_final(correcto: bool) -> void:
	if not _host_prueba or multiplayer.get_remote_sender_id() == 1:
		return
	_final_confirmado = true
	if not correcto:
		fallos += 1

@rpc("authority", "call_remote", "reliable")
func _finalizar() -> void:
	if _terminando:
		return
	_terminando = true
	var lado := "host" if _host_prueba else "client"
	var archivo := FileAccess.open("res://.godot/resistencia_%s.json" % lado, FileAccess.WRITE)
	archivo.store_string(JSON.stringify({"duracion_real_s": (Time.get_ticks_msec() - inicio) / 1000.0,
		"errores": fallos, "casos_generados": secuencia, "enet_total_enviado": _total_enviado,
		"enet_total_recibido": _total_recibido, "muestras": muestras}, "\t"))
	archivo.close()
	print("[RESISTENCIA RESULTADO] ", lado, " errores=", fallos)
	# Dar tiempo a entregar el RPC final antes de cerrar ENet.
	await _esperar(0.3)
	SesionLAN.cerrar()
	await _esperar(1)
	MenuGlobal.musica_menu.stop()
	get_tree().quit(0 if fallos == 0 else 1)
