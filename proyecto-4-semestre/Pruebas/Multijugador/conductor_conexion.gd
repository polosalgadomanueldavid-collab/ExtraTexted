extends Node
## Ejecutar servidor, incompatible, ocupante y tercero desde ejecutar_pruebas.ps1.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_probar.call_deferred()

func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout

func _probar() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--servidor"):
		assert(SesionLAN.crear("Servidor") == OK)
		await _esperar(23.0)
		SesionLAN.cerrar()
		await _esperar(0.1)
		get_tree().quit()
		return
	if args.has("--incompatible"):
		multiplayer.connected_to_server.disconnect(SesionLAN._conectado)
		multiplayer.connected_to_server.connect(func(): SesionLAN._registrar.rpc_id(1, "otra-version", "Prueba"))
	SesionLAN.unirse("127.0.0.1", "Prueba")
	var limite := Time.get_ticks_msec() + 13000
	if args.has("--ocupar"):
		while SesionLAN.participantes.size() < 2 and SesionLAN.activa and Time.get_ticks_msec() < limite:
			await _esperar(0.1)
		assert(SesionLAN.participantes.size() == 2)
		await _esperar(14.0)
		SesionLAN.cerrar()
	else:
		while SesionLAN.activa and Time.get_ticks_msec() < limite:
			await _esperar(0.1)
		var correcto := not SesionLAN.activa and SesionLAN.participantes.is_empty()
		if args.has("--incompatible"):
			correcto = correcto and SesionLAN.ultimo_aviso.contains("versión incompatible")
		print("[CONEXION LAN] %s: %s" % [str(args), "OK" if correcto else "FALLO"])
		if not correcto:
			get_tree().quit(1)
			return
	await _esperar(0.2)
	get_tree().quit()
