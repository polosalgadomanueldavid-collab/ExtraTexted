extends SceneTree
## -- --segundos=10 --rondas=5 --calidad=2
## Guarda muestras de cuadros reales y recursos; headless no mide GPU/FPS visuales.
var muestras: Array = []
var resultados := {}
var anterior := 0
var midiendo := false
var segundos := 10.0
var rondas := 5

func _initialize() -> void:
	process_frame.connect(_muestrear)
	_run.call_deferred()

func _muestrear() -> void:
	var ahora := Time.get_ticks_usec()
	if midiendo and anterior > 0:
		muestras.append({"cuadro_ms": (ahora - anterior) / 1000.0,
			"cpu_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000,
			"fisica_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000,
			"gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"ram_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
			"vram_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
			"nodos": Performance.get_monitor(Performance.OBJECT_NODE_COUNT)})
	anterior = ahora

func _medir(nombre: String) -> void:
	muestras.clear()
	midiendo = true
	await create_timer(segundos).timeout
	midiendo = false
	var resumen := {}
	for clave in muestras[0]:
		var valores: Array = muestras.map(func(m): return m[clave])
		valores.sort()
		resumen[clave] = {"p50": valores[int((valores.size() - 1) * 0.50)], "p95": valores[int((valores.size() - 1) * 0.95)], "p99": valores[int((valores.size() - 1) * 0.99)], "max": valores[-1]}
	resultados[nombre] = resumen
	print("[PERFIL] ", nombre, " ", JSON.stringify(resumen))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/perfil_%s.png" % nombre)

func _cargar(ruta: String) -> void:
	var carga := root.get_node("CargaEscenas")
	carga.cargar(ruta)
	await carga.terminada
	await process_frame

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--segundos="):
			segundos = maxf(1, argumento.get_slice("=", 1).to_float())
		elif argumento.begins_with("--rondas="):
			rondas = maxi(1, argumento.get_slice("=", 1).to_int())
	# No guardar preferencias del usuario desde una medición automatizada.
	var calidad := root.get_node("CalidadVisual")
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--calidad="):
			calidad.nivel = clampi(argumento.get_slice("=", 1).to_int(), 0, 2)
	root.scaling_3d_scale = calidad.ESCALAS[calidad.nivel]
	await _cargar("res://UI/Menus/MainMenu.tscn")
	await create_timer(1.0).timeout
	await _medir("menu")
	var menu := root.get_node("MenuGlobal")
	for ronda in rondas:
		menu.omitir_tutorial_siguiente_partida = true
		await _cargar("res://Mundo/Oficina.tscn")
		var oficina := current_scene
		oficina.temporizador_denuncias.stop()
		oficina.temporizador_bloqueos.stop()
		oficina.temporizador_eventos.stop()
		await create_timer(1.0).timeout
		await _medir("oficina_%d" % ronda)
		if ronda != 0:
			continue
		for nombre in ["apagon", "terremoto", "incendio", "inundacion", "lava", "hielo"]:
			oficina.tutoriales_vistos[StringName(nombre)] = true
			oficina.bloqueos_iniciados = true
			var evento: Node = oficina.get("evento_" + nombre)
			var inicio := Time.get_ticks_usec()
			if nombre == "apagon":
				evento.iniciar_apagon()
			elif nombre == "terremoto":
				evento.iniciar(oficina.grafo_piso, oficina.jugador, {}, Rect2())
			elif nombre == "incendio":
				evento.iniciar({})
			else:
				evento.iniciar()
			resultados[nombre + "_inicio_ms"] = (Time.get_ticks_usec() - inicio) / 1000.0
			await _medir(nombre)
			evento.resolver_con_avatar()
			oficina.temporizador_eventos.stop()
			oficina.temporizador_bloqueos.stop()
			await create_timer(1.0).timeout
	var reporte := {"version": Engine.get_version_info(), "render": DisplayServer.get_name(), "adaptador": RenderingServer.get_video_adapter_name(), "calidad": calidad.nivel, "segundos_por_escenario": segundos, "gpu_cero_significa_no_disponible": true, "resultados": resultados}
	var archivo := FileAccess.open("res://.godot/perfil_rendimiento.json", FileAccess.WRITE)
	archivo.store_string(JSON.stringify(reporte, "\t"))
	archivo.close()
	await _cargar("res://UI/Menus/MainMenu.tscn")
	menu.musica_menu.stop()
	quit()
