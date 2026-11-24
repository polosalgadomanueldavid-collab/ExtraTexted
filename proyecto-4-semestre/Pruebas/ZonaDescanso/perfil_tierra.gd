extends "res://Pruebas/Menus/perfil_rendimiento.gd"
## Comparación gráfica: primera activación, repetición y restauración del terremoto.
## -- --reporte=res://.godot/tierra_antes.json (o tierra_despues.json)
var efecto_anterior: Script

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("El perfil de tierra requiere renderizado real")
		quit(1)
		return
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	capturas = false
	segundos = 3.9
	var nivel_medicion := 2
	ruta_reporte = "res://.godot/tierra_despues.json"
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--reporte="):
			ruta_reporte = argumento.trim_prefix("--reporte=")
		elif argumento.begins_with("--efecto-anterior="):
			efecto_anterior = load(argumento.trim_prefix("--efecto-anterior="))
		elif argumento.begins_with("--calidad="):
			nivel_medicion = clampi(argumento.get_slice("=", 1).to_int(), 0, 3)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	root.get_node("MenuGlobal").omitir_tutorial_siguiente_partida = true
	var oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	await create_timer(.3).timeout
	root.get_node("MenuGlobal").cerrar_ayuda()
	paused = false
	oficina.temporizador_denuncias.stop()
	_oficina_detener_relojes(oficina)
	oficina.bloqueos_iniciados = true
	oficina.tutoriales_vistos[&"terremoto"] = true
	var jugador = oficina.jugador
	var origen_inicial: Vector3 = jugador.global_position
	jugador.global_position = Vector3(-1, .38, 3)
	jugador.visual.rotation.y = 0
	jugador.set_process_input(false)
	await create_timer(1.0).timeout
	# Fija el mismo encuadre/apoyo en ambas versiones; la caída aleatoria no
	# debe cancelar la animación que se está midiendo. El esqueleto sigue activo.
	jugador.set_physics_process(false)
	var camara := Camera3D.new()
	oficina.add_child(camara)
	camara.global_position = Vector3(1.5, 4.6, 8.0)
	camara.look_at(Vector3(-1, 1.25, 3.6))
	camara.fov = 70
	camara.current = true
	var calidad := root.get_node("CalidadVisual")
	var poderes = oficina.get_node("MaquinaExpendedora").poderes
	# Cada calidad arranca en un proceso/oficina nuevos para no heredar
	# muebles, casos ni temporizadores que cambian al restaurar un terremoto.
	for nivel in [nivel_medicion]:
		calidad.establecer(nivel, false)
		if OS.get_cmdline_user_args().has("--calentamiento"):
			var calentamiento := preload("res://UI/Menus/calentamiento_visual.gd").new()
			root.add_child(calentamiento)
			await calentamiento.preparar(oficina)
			calentamiento.queue_free()
			camara.current = true
		await create_timer(1.0).timeout
		await _medir("reposo_%d" % nivel)
		for repeticion in 2:
			var inicio := Time.get_ticks_usec()
			if not jugador.ejecutar_gesto(&"control_tierra"):
				push_error("No inició el gesto medido")
				quit(1)
				return
			_animar(poderes, jugador, oficina)
			resultados["crear_%d_%d_ms" % [nivel, repeticion]] = (Time.get_ticks_usec() - inicio) / 1000.0
			await _medir("gesto_%d_%d" % [nivel, repeticion])
		var terremoto = oficina.evento_terremoto
		# La distribución validada se solicita desde el apoyo inicial del mapa,
		# igual que en la prueba de consumo real (el encuadre de VFX está aparte).
		jugador.global_position = origen_inicial
		jugador.velocity = Vector3.ZERO
		jugador.set_physics_process(true)
		await create_timer(.3).timeout
		jugador.set_physics_process(false)
		terremoto._azar.seed = 8762
		var aceptado: bool = terremoto.iniciar(oficina.grafo_piso, jugador, {}, Rect2())
		resultados["terremoto_aceptado_%d" % nivel] = aceptado
		if aceptado:
			if terremoto.preparando:
				await terremoto.preparacion_terminada
			if not terremoto.activo:
				push_error("Preparación rechazada: " + terremoto.rechazo_preparacion)
				quit(1)
				return
			# Esperar al reloj físico del evento: un tirón de compilación puede
			# desacoplarlo del temporizador de pared y dejar intacto el suelo.
			var limite := Time.get_ticks_msec() + 45000
			while terremoto.tiempo < 8.4 and Time.get_ticks_msec() < limite:
				await physics_frame
			if terremoto.tiempo < 8.4:
				push_error("El terremoto no alcanzó la ruptura para el perfil")
				quit(1)
				return
			resultados["fase_terremoto_%d" % nivel] = terremoto.tiempo
			resultados["grietas_terremoto_%d" % nivel] = terremoto.grietas.size()
			if not jugador.ejecutar_gesto(&"control_tierra", terremoto.resolver_con_avatar.bind(jugador.global_position)):
				push_error("No inició el gesto de restauración")
				quit(1)
				return
			_animar(poderes, jugador, oficina)
			await _medir("restauracion_%d" % nivel, 6.0)
			resultados["restauracion_completa_%d" % nivel] = not terremoto.activo and not terremoto.resolviendo_avatar
			print("RESTAURACION_COMPLETA: ", resultados["restauracion_completa_%d" % nivel])
			terremoto.resolver_con_avatar()
			await create_timer(.8).timeout
		else:
			push_error("No se pudo iniciar el terremoto para medir su restauración")
			quit(1)
			return
		_oficina_detener_relojes(oficina)
	var reporte := {"render": DisplayServer.get_name(), "adaptador": RenderingServer.get_video_adapter_name(), "resolucion": [1280, 720], "gpu_cero_significa_no_disponible": true, "resultados": resultados}
	var archivo := FileAccess.open(ruta_reporte, FileAccess.WRITE)
	archivo.store_string(JSON.stringify(reporte, "\t"))
	archivo.close()
	print("TIERRA_PERFIL: ", ruta_reporte)
	oficina.queue_free()
	await process_frame
	quit()

func _animar(poderes: Node, jugador: Node3D, oficina: Node3D) -> void:
	if efecto_anterior == null:
		poderes.animar_elemento(&"control_tierra")
		return
	if is_instance_valid(poderes._elemento):
		poderes._elemento.queue_free()
	var efecto = efecto_anterior.new()
	efecto.tipo = &"control_tierra"
	efecto.jugador = jugador
	oficina.add_child(efecto)
	efecto.global_position = jugador.global_position
	efecto.rotation.y = jugador.visual.global_rotation.y
	poderes._elemento = efecto
