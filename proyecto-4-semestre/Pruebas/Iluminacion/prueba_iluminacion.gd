extends "res://Pruebas/Menus/perfil_rendimiento.gd"
## Comparación visual reproducible sin guardar preferencias del usuario.
## --script res://Pruebas/Iluminacion/prueba_iluminacion.gd -- --etiqueta=despues --calidad=2
## Añadir --referencia para medir la escena anterior sin exigir el nuevo presupuesto.

var _etiqueta := "despues"
var _referencia := false
var _fallos := 0
var _comprobaciones := 0
var _oficina: Node
var _camara: Camera3D
var _salida: String


func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	segundos = 3.0
	var calidad := root.get_node("CalidadVisual")
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--etiqueta="):
			_etiqueta = argumento.get_slice("=", 1).validate_filename()
		elif argumento.begins_with("--calidad="):
			calidad.nivel = clampi(argumento.get_slice("=", 1).to_int(), 0, calidad.ULTRA)
		elif argumento.begins_with("--segundos="):
			segundos = maxf(1.0, argumento.get_slice("=", 1).to_float())
		elif argumento == "--referencia":
			_referencia = true
	root.scaling_3d_scale = calidad.ESCALAS[calidad.nivel]
	_salida = "res://.godot/qa_iluminacion/" + _etiqueta
	DirAccess.make_dir_recursive_absolute(_salida)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	root.get_node("MenuGlobal").omitir_tutorial_siguiente_partida = true
	if not await _cargar("res://Mundo/Oficina.tscn"):
		return
	_oficina = current_scene
	_oficina.temporizador_denuncias.stop()
	_oficina.temporizador_bloqueos.stop()
	_oficina.temporizador_eventos.stop()
	_oficina.anuncios.detener()
	_oficina._limpiar_bloqueos_temporales()
	_oficina.jugador.set_physics_process(false)
	_oficina.jugador.global_position = Vector3(-1, 0.38, 3.6)
	_camara = _oficina.get_node("Gameplay/Camera3D")
	_camara.set_physics_process(false)
	_camara.fov = 70
	await _vista("trabajo", Vector3(-1, 5.8, 7), Vector3(-1, 0.9, 3.4))
	await _vista("descanso", Vector3(-1, 5.8, 12.1), Vector3(-1, 0.9, 8.6))
	await _vista("frontal", Vector3(-1, 3.1, 6.2), Vector3(-1, 1.1, 1.8))
	var luces: Array[Light3D] = []
	for nodo in _oficina.get_node("Pared, suelo, techo").get_children():
		if nodo is Light3D:
			luces.append(nodo)
	for nodo in _oficina.get_children():
		if nodo is Light3D:
			luces.append(nodo)
	for nombre in ["LuzAcceso", "LuzPasillo"]:
		luces.append(_oficina.get_node("PuertaRelevo/" + nombre))
	var sombras := 0
	for luz in luces:
		if luz.shadow_enabled:
			sombras += 1
	if not _referencia:
		_verificar(luces.size() <= 10, "Presupuesto de hasta diez luces fijas, incluida la puerta")
		_verificar(sombras == 0, "La iluminación fija no añade pasadas de sombras")
		for luz in luces:
			_verificar(_oficina.evento_apagon.luces.has(luz), "Apagón conectado a " + str(luz.get_path()))
	_oficina.tutoriales_vistos[&"apagon"] = true
	_verificar(_oficina.evento_apagon.iniciar_apagon(), "Se inicia el apagón")
	if not _referencia:
		for luz in luces:
			_verificar(not luz.visible, "Apagado: " + luz.name)
	await _registrar("apagon")
	_oficina.evento_apagon.resolver_con_avatar()
	if not _referencia:
		for luz in luces:
			_verificar(luz.visible, "Restaurado: " + luz.name)
	await _registrar("restaurada")
	# Material del piso y luces también se ejercitan con efectos reales.
	for nombre in ["lava", "inundacion"]:
		_oficina.tutoriales_vistos[StringName(nombre)] = true
		var evento: Node = _oficina.get("evento_" + nombre)
		_verificar(evento.iniciar(), "Se inicia " + nombre)
		await _registrar(nombre)
		evento.resolver_con_avatar()
		_oficina.temporizador_eventos.stop()
		_oficina.temporizador_bloqueos.stop()
		await create_timer(0.2).timeout
	if not _referencia:
		await _comprobar_calidad_y_calentamiento(luces, calidad)
	var reporte := {"version": Engine.get_version_info(), "render": DisplayServer.get_name(),
		"adaptador": RenderingServer.get_video_adapter_name(), "cpu": OS.get_processor_name(),
		"resolucion": [root.size.x, root.size.y], "calidad": calidad.nivel,
		"luces_fijas": luces.size(), "sombras_fijas": sombras, "fallos": _fallos,
		"comprobaciones": _comprobaciones,
		"gpu_cero_significa_no_disponible": true, "resultados": resultados}
	var archivo := FileAccess.open(_salida + "/mediciones.json", FileAccess.WRITE)
	archivo.store_string(JSON.stringify(reporte, "\t"))
	archivo.close()
	print("[ILUMINACION] ", _etiqueta, ": ", _comprobaciones, " comprobaciones; ", _fallos, " fallos; ", luces.size(), " luces; ", sombras, " sombras")
	_oficina.queue_free()
	await process_frame
	quit(1 if _fallos else 0)


func _vista(nombre: String, posicion: Vector3, destino: Vector3) -> void:
	_camara.position = posicion
	_camara.look_at(destino)
	await _registrar(nombre)


func _registrar(nombre: String) -> void:
	await create_timer(0.5).timeout
	await _medir(nombre)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_salida + "/" + nombre + ".png")


func _verificar(condicion: bool, mensaje: String) -> void:
	_comprobaciones += 1
	if not condicion:
		_fallos += 1
		push_error("[ILUMINACION] " + mensaje)


func _comprobar_calidad_y_calentamiento(luces: Array[Light3D], calidad: Node) -> void:
	var nivel_original: int = calidad.nivel
	for nivel in [0, 1, 2, 3]:
		calidad.establecer(nivel, false)
		for luz in luces:
			var esperada: bool = nivel >= 2 and bool(luz.get_meta("sombra_original"))
			_verificar(luz.shadow_enabled == esperada, "Sombras al cambiar calidad en " + luz.name)
	calidad.establecer(nivel_original, false)
	if DisplayServer.get_name() == "headless":
		return
	var calentamiento := preload("res://UI/Menus/calentamiento_visual.gd").new()
	root.add_child(calentamiento)
	var transformacion := _camara.global_transform
	var apertura := _camara.fov
	paused = true
	await calentamiento._preparar_luces_oficina(_oficina)
	await calentamiento._preparar_vision_apagon(_oficina)
	_verificar(_camara.global_transform.is_equal_approx(transformacion) and is_equal_approx(_camara.fov, apertura), "El calentamiento restaura encuadre y apertura")
	_verificar(not _oficina.evento_apagon.mascara.visible and not _oficina.evento_apagon.luz_jugador.visible, "El calentamiento deja apagadas la máscara y la luz de emergencia")
	for luz in luces:
		_verificar(luz.visible, "El calentamiento restaura " + luz.name)
	paused = false
	calentamiento.queue_free()
