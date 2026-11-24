extends "res://Pruebas/Menus/perfil_rendimiento.gd"
## Diagnóstico gráfico secuencial; no guarda las preferencias del usuario.
## -- --reporte=res://.godot/comparar_tirones.json

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	segundos = 8.0
	capturas = false
	ruta_reporte = "res://.godot/comparar_tirones.json"
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--reporte="):
			ruta_reporte = argumento.trim_prefix("--reporte=")
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var calidad := root.get_node("CalidadVisual")
	calidad.nivel = 2
	root.scaling_3d_scale = calidad.ESCALAS[2]
	if not await _cargar("res://UI/Menus/MainMenu.tscn"):
		return
	var menu := root.get_node("MenuGlobal")
	menu._clasificacion = ClasificacionLocal.new("user://comparar_tirones_%d.json" % OS.get_process_id())
	await create_timer(1.0).timeout
	await _medir("menu_alta")
	_calidad_sin_guardar(0)
	await create_timer(1.0).timeout
	await _medir("menu_baja")
	# Experimento causal: conservar colores y energía, retirar solo sombras.
	_calidad_sin_guardar(2)
	var sombras: Array[Light3D] = []
	for nodo in current_scene.find_children("*", "Light3D", true, false):
		if nodo.shadow_enabled:
			sombras.append(nodo)
			nodo.shadow_enabled = false
	await create_timer(1.0).timeout
	await _medir("menu_alta_sin_sombras")
	for luz in sombras:
		luz.shadow_enabled = true
	await create_timer(1.0).timeout
	await _medir("menu_alta_repetida")
	for nivel in [2, 0]:
		_calidad_sin_guardar(nivel)
		menu.omitir_tutorial_siguiente_partida = true
		if not await _cargar("res://Mundo/Oficina.tscn"):
			return
		var oficina := current_scene
		var sufijo: String = "alta" if nivel == 2 else "baja"
		_oficina_detener_relojes(oficina)
		oficina.temporizador_denuncias.stop()
		oficina.bloqueos_iniciados = true
		await create_timer(1.0).timeout
		await _medir("oficina_" + sufijo)
		oficina.generador_aleatorio.seed = 8762
		var inicio := Time.get_ticks_usec()
		oficina._cambiar_bloqueo_temporal()
		resultados["cajones_" + sufijo + "_inicio_ms"] = (Time.get_ticks_usec() - inicio) / 1000.0
		await _medir("cajones_" + sufijo)
		oficina._limpiar_bloqueos_temporales()
		oficina.grafo_piso.construir_adyacencia()
		await create_timer(1.0).timeout
		for nombre in ["terremoto", "lava"]:
			oficina.tutoriales_vistos[StringName(nombre)] = true
			var evento: Node = oficina.get("evento_" + nombre)
			if nombre == "terremoto":
				evento._azar.seed = 8762
			oficina.generador_aleatorio.seed = 8762
			inicio = Time.get_ticks_usec()
			var activado: bool
			if nombre == "terremoto":
				activado = evento.iniciar(oficina.grafo_piso, oficina.jugador, {}, Rect2())
			else:
				activado = evento.iniciar()
			var etiqueta: String = nombre + "_" + sufijo
			resultados[etiqueta + "_inicio_ms"] = (Time.get_ticks_usec() - inicio) / 1000.0
			resultados[etiqueta + "_activado"] = activado
			print("[INICIO] ", etiqueta, " activo=", activado, " ms=", resultados[etiqueta + "_inicio_ms"])
			if nombre == "terremoto": evento_preparandose = evento
			# Incluye preparación, ruptura (8 s), derrumbes y cierre (24 s).
			await _medir(etiqueta, 26.0 if nombre == "terremoto" and activado else 0.0)
			evento.resolver_con_avatar()
			_oficina_detener_relojes(oficina)
			await create_timer(1.0).timeout
	if not await _cargar("res://UI/Menus/MainMenu.tscn"):
		return
	menu.musica_menu.stop()
	_guardar_comparacion()
	quit()


func _calidad_sin_guardar(nivel: int) -> void:
	# Compatible con el ajuste original y el selector ampliado; sin escribir cfg.
	var calidad := root.get_node("CalidadVisual")
	calidad.nivel = nivel
	root.scaling_3d_scale = calidad.ESCALAS[nivel]
	calidad._recorrer(root)
	if calidad.has_signal("nivel_cambiado"):
		calidad.emit_signal("nivel_cambiado", nivel)


func _medir(nombre: String, minimo_segundos := 0.0) -> void:
	await super._medir(nombre, minimo_segundos)
	_guardar_comparacion()


func _guardar_comparacion() -> void:
	var reporte := {"version": Engine.get_version_info(), "render": DisplayServer.get_name(),
		"adaptador": RenderingServer.get_video_adapter_name(), "cpu": OS.get_processor_name(),
		"resolucion": [root.size.x, root.size.y], "segundos_por_escenario": segundos,
		"cargas": cargas, "resultados": resultados}
	var archivo := FileAccess.open(ruta_reporte, FileAccess.WRITE)
	if archivo == null:
		push_error("No se pudo guardar la comparación: " + ruta_reporte)
		quit(1)
		return
	archivo.store_string(JSON.stringify(reporte, "\t"))
