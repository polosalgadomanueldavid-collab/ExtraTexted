extends SceneTree
## -- --segundos=10 --rondas=5 --calidad=2
## Guarda muestras de cuadros reales y recursos; headless no mide GPU/FPS visuales.
var muestras: Array = []
var resultados := {}
var anterior := 0
var midiendo := false
var segundos := 10.0
var rondas := 5
var cargas: Array = []
var ruta_reporte := "res://.godot/perfil_rendimiento.json"
var capturas := true
var cargando := false
var intervalo_carga_ms := 0.0
var vistas_medidas: Array[SubViewport] = []
var inicio_escenario_usec := 0
var picos: Array = []

func _initialize() -> void:
	process_frame.connect(_muestrear)
	_run.call_deferred()

func _muestrear() -> void:
	var ahora := Time.get_ticks_usec()
	if cargando and anterior > 0:
		intervalo_carga_ms = maxf(intervalo_carga_ms, (ahora - anterior) / 1000.0)
	if midiendo and anterior > 0:
		var intervalo_ms := (ahora - anterior) / 1000.0
		if intervalo_ms > 1000.0 / 30.0 and picos.size() < 64:
			picos.append({"desde_inicio_ms": (ahora - inicio_escenario_usec) / 1000.0, "cuadro_ms": intervalo_ms})
		var gpu_subvistas := 0.0
		for vista in vistas_medidas:
			if is_instance_valid(vista):
				gpu_subvistas += RenderingServer.viewport_get_measured_render_time_gpu(vista.get_viewport_rid())
		muestras.append({"cuadro_ms": (ahora - anterior) / 1000.0,
			"cpu_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000,
			"fisica_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000,
			"gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),
			"gpu_subviewports_ms": gpu_subvistas,
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"ram_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
			"vram_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
			"nodos": Performance.get_monitor(Performance.OBJECT_NODE_COUNT)})
	anterior = ahora

func _medir(nombre: String, minimo_segundos := 0.0) -> void:
	vistas_medidas.clear()
	if is_instance_valid(current_scene):
		for nodo in current_scene.find_children("*", "SubViewport", true, false):
			vistas_medidas.append(nodo)
			RenderingServer.viewport_set_measure_render_time(nodo.get_viewport_rid(), true)
	muestras.clear()
	picos.clear()
	inicio_escenario_usec = anterior
	midiendo = true
	await create_timer(maxf(segundos, minimo_segundos)).timeout
	midiendo = false
	if muestras.is_empty():
		push_error("No se recibieron cuadros para " + nombre)
		quit(1)
		return
	var resumen := {}
	for clave in muestras[0]:
		var valores: Array = muestras.map(func(m): return m[clave])
		valores.sort()
		resumen[clave] = {"p50": valores[int((valores.size() - 1) * 0.50)], "p95": valores[int((valores.size() - 1) * 0.95)], "p99": valores[int((valores.size() - 1) * 0.99)], "max": valores[-1]}
	var duracion_ms := 0.0
	var mayores_33 := 0
	var mayores_50 := 0
	var mayores_100 := 0
	for muestra in muestras:
		duracion_ms += muestra.cuadro_ms
		mayores_33 += int(muestra.cuadro_ms > 1000.0 / 30.0)
		mayores_50 += int(muestra.cuadro_ms > 50.0)
		mayores_100 += int(muestra.cuadro_ms > 100.0)
	resumen["muestreo"] = {"cuadros": muestras.size(), "duracion_ms": duracion_ms,
		"fps_medio": muestras.size() * 1000.0 / duracion_ms,
		"mayores_33_ms": mayores_33, "mayores_50_ms": mayores_50, "mayores_100_ms": mayores_100}
	resumen["primeros_64_picos"] = picos.duplicate(true)
	resultados[nombre] = resumen
	print("[PERFIL] ", nombre, " ", JSON.stringify(resumen))
	if capturas and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/perfil_%s.png" % nombre)

func _cargar(ruta: String) -> bool:
	var carga := root.get_node("CargaEscenas")
	intervalo_carga_ms = 0.0
	cargando = true
	carga.cargar(ruta)
	var limite := Time.get_ticks_msec() + 70000
	while carga.activa and Time.get_ticks_msec() < limite:
		await process_frame
	cargando = false
	if carga.activa or not is_instance_valid(current_scene) or current_scene.scene_file_path != ruta:
		push_error("No terminó la carga del perfil: " + ruta + " (" + carga.fase + ")")
		quit(1)
		return false
	cargas.append({"ruta": ruta, "fases_ms": carga.mediciones.duplicate(true), "intervalo_max_ms": intervalo_carga_ms})
	await process_frame
	return true

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--segundos="):
			segundos = maxf(1, argumento.get_slice("=", 1).to_float())
		elif argumento.begins_with("--rondas="):
			rondas = maxi(1, argumento.get_slice("=", 1).to_int())
		elif argumento.begins_with("--reporte="):
			ruta_reporte = argumento.trim_prefix("--reporte=")
		elif argumento == "--sin-capturas":
			capturas = false
	# No guardar preferencias del usuario desde una medición automatizada.
	var calidad := root.get_node("CalidadVisual")
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--calidad="):
			calidad.nivel = clampi(argumento.get_slice("=", 1).to_int(), 0, calidad.ESCALAS.size() - 1)
	root.scaling_3d_scale = calidad.ESCALAS[calidad.nivel]
	if not await _cargar("res://UI/Menus/MainMenu.tscn"):
		return
	await create_timer(1.0).timeout
	await _medir("menu")
	var menu := root.get_node("MenuGlobal")
	menu._clasificacion = ClasificacionLocal.new("user://perfil_rendimiento_%d.json" % OS.get_process_id())
	for ronda in rondas:
		menu.omitir_tutorial_siguiente_partida = true
		if not await _cargar("res://Mundo/Oficina.tscn"):
			return
		var oficina := current_scene
		oficina.temporizador_denuncias.stop()
		oficina.temporizador_bloqueos.stop()
		oficina.temporizador_eventos.stop()
		await create_timer(1.0).timeout
		await _medir("oficina_%d" % ronda)
		if ronda != 0:
			continue
		for pasada in 2:
			for nombre in ["apagon", "terremoto", "incendio", "inundacion", "lava", "hielo"]:
				oficina.tutoriales_vistos[StringName(nombre)] = true
				oficina.bloqueos_iniciados = true
				var evento: Node = oficina.get("evento_" + nombre)
				var escenario: String = nombre if pasada == 0 else nombre + "_segunda"
				if nombre == "terremoto":
					evento._azar.seed = 8762
				var inicio := Time.get_ticks_usec()
				var activado: bool
				if nombre == "apagon":
					activado = evento.iniciar_apagon()
				elif nombre == "terremoto":
					activado = evento.iniciar(oficina.grafo_piso, oficina.jugador, {}, Rect2())
				elif nombre == "incendio":
					activado = evento.iniciar({})
				else:
					activado = evento.iniciar()
				resultados[escenario + "_inicio_ms"] = (Time.get_ticks_usec() - inicio) / 1000.0
				resultados[escenario + "_activado"] = activado
				await _medir(escenario)
				evento.resolver_con_avatar()
				oficina.temporizador_eventos.stop()
				oficina.temporizador_bloqueos.stop()
				await create_timer(1.0).timeout
			# Medir las animaciones y efectos a través del consumo real del bolsillo.
			var maquina: Node = oficina.get_node("MaquinaExpendedora")
			for indice in 4:
				oficina.anuncios.detener()
				if indice == 3:
					oficina.evento_inundacion.iniciar()
					await create_timer(0.2).timeout
					_oficina_detener_relojes(oficina)
				maquina.inventario[indice] = 1
				var nombre_poder: String = ["chocolate", "dona", "papa_tiempo", "avatar_agua"][indice]
				if pasada == 1:
					nombre_poder += "_segunda"
				resultados[nombre_poder + "_activado"] = maquina.usar(indice)
				await _medir(nombre_poder, 4.5)
				maquina.poderes.reanudar_tiempo(false)
				oficina.jugador.chocolate_restante = 0.0
				oficina.jugador.dona_restante = 0.0
				if indice == 3:
					oficina.evento_inundacion.resolver_con_avatar()
				_oficina_detener_relojes(oficina)
				await create_timer(1.0).timeout
	var reporte := {"version": Engine.get_version_info(), "render": DisplayServer.get_name(), "adaptador": RenderingServer.get_video_adapter_name(), "cpu": OS.get_processor_name(), "resolucion": [root.size.x, root.size.y], "exportado": OS.has_feature("standalone"), "calidad": calidad.nivel, "segundos_por_escenario": segundos, "gpu_cero_significa_no_disponible": true, "cargas": cargas, "resultados": resultados}
	var archivo := FileAccess.open(ruta_reporte, FileAccess.WRITE)
	if archivo == null:
		push_error("No se pudo guardar el perfil: " + ruta_reporte)
		quit(1)
		return
	archivo.store_string(JSON.stringify(reporte, "\t"))
	archivo.close()
	if not await _cargar("res://UI/Menus/MainMenu.tscn"):
		return
	menu.musica_menu.stop()
	quit()

func _oficina_detener_relojes(oficina: Node) -> void:
	oficina.anuncios.detener()
	oficina.temporizador_eventos.stop()
	oficina.temporizador_bloqueos.stop()
