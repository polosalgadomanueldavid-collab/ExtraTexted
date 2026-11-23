extends SceneTree
## --script res://Pruebas/Iluminacion/prueba_ultra.gd [-- --medir]
## A/B alternado, misma sesión y cámara. No guarda preferencias del usuario.
var _fallos := 0
var _pruebas := 0
var _oficina: Node
var _calidad: Node
var _luces: Array[Light3D] = []
var _camara: Camera3D
var _piso: ShaderMaterial
var _base: Dictionary
var _resultados := {}
var _medir := false
const SALIDA := "res://.godot/qa_ultra"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_medir = "--medir" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute(SALIDA)
	_calidad = root.get_node("CalidadVisual")
	var preferencias := FileAccess.get_file_as_bytes(_calidad.ARCHIVO) if FileAccess.file_exists(_calidad.ARCHIVO) else PackedByteArray()
	_calidad.establecer(2, false)
	root.get_node("MenuGlobal").omitir_tutorial_siguiente_partida = true
	var carga := root.get_node("CargaEscenas")
	carga.cargar("res://Mundo/Oficina.tscn")
	var limite := Time.get_ticks_msec() + 65000
	while carga.activa and Time.get_ticks_msec() < limite:
		await process_frame
	if carga.activa or current_scene == null or current_scene.scene_file_path != "res://Mundo/Oficina.tscn":
		push_error("[ULTRA] No terminó la carga de oficina")
		quit(1)
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
	_piso = _oficina.get_node("Pared, suelo, techo/PisoTerremoto/Suelo").material
	for nodo in _oficina.get_node("Pared, suelo, techo").get_children():
		if nodo is Light3D:
			_luces.append(nodo)
	_base = _estado()
	_verificar(is_equal_approx(_camara.environment.ambient_light_energy, 0.36), "Alta conserva el ambiente aprobado")
	_verificar(is_equal_approx(_piso.get_shader_parameter("rugosidad"), 0.74), "Alta conserva el piso aprobado")
	var selector := root.get_node("MenuGlobal").panel_opciones.find_child("CalidadVisual", true, false) as OptionButton
	_verificar(selector != null and selector.item_count == 4 and selector.get_item_text(3) == "Ultra", "Ultra aparece en Opciones")
	var nodos := get_node_count()
	var id_piso := _piso.get_instance_id()
	var id_ambiente := _camara.environment.get_instance_id()
	# Simular también cambiar desde el menú de pausa.
	paused = true
	for nivel in [3, 2, 3, 1, 3, 0, 3, 2]:
		_calidad.establecer(nivel, false)
		_verificar(selector.selected == nivel, "El selector refleja calidad %d" % nivel)
		if nivel < 3:
			_verificar(_estado_equivalente(_base, _estado()), "Volver de Ultra restaura exactamente el aspecto base")
		else:
			_verificar(not _estado_equivalente(_base, _estado()), "Ultra tiene una iluminación distinta")
		_verificar(get_node_count() == nodos, "Cambiar calidad no crea nodos")
		_verificar(_piso.get_instance_id() == id_piso and _camara.environment.get_instance_id() == id_ambiente, "Cambiar calidad reutiliza recursos")
		for luz in _luces:
			_verificar(not luz.shadow_enabled and luz.visible, "El perfil mantiene focos sin sombras y visibles")
	paused = false
	_verificar(_calidad.ESCALAS[3] == _calidad.ESCALAS[2] and _calidad.PARTICULAS[3] == _calidad.PARTICULAS[2], "Ultra conserva píxeles y partículas de Alta")
	# La máscara del terremoto y su material sobreviven al cambio de acabado.
	_piso.set_shader_parameter("usar_mascara_huecos", true)
	_calidad.establecer(3, false)
	_calidad.establecer(2, false)
	_verificar(_piso.get_shader_parameter("usar_mascara_huecos") == true and _oficina.evento_terremoto._material_piso == _piso, "Se conserva el material y la máscara del terremoto")
	_piso.set_shader_parameter("usar_mascara_huecos", false)
	_oficina.tutoriales_vistos[&"apagon"] = true
	_verificar(_oficina.evento_apagon.iniciar_apagon(), "Comienza el apagón")
	_calidad.establecer(3, false)
	_verificar(_estado_equivalente(_base, _estado()), "Ultra se aplaza durante el apagón")
	for luz in _luces:
		_verificar(not luz.visible, "Cambiar a Ultra no enciende una luz apagada")
	_oficina.evento_apagon.resolver_con_avatar()
	_verificar(not _estado_equivalente(_base, _estado()), "Reparar aplica el Ultra pendiente")
	_verificar(_oficina.evento_apagon.iniciar_apagon(), "Comienza el segundo apagón")
	_oficina.evento_apagon.resolver_con_avatar(Vector3(-1, 0.5, 3))
	_calidad.establecer(2, false)
	var fin_avatar := Time.get_ticks_msec() + 10000
	while _oficina.evento_apagon.estado != 0 and Time.get_ticks_msec() < fin_avatar:
		await process_frame
	_verificar(_oficina.evento_apagon.estado == 0 and _estado_equivalente(_base, _estado()), "La restauración elemental termina con el perfil solicitado")
	if _medir:
		await _comparar()
	await _recargar_ultra()
	var despues := FileAccess.get_file_as_bytes(_calidad.ARCHIVO) if FileAccess.file_exists(_calidad.ARCHIVO) else PackedByteArray()
	_verificar(preferencias == despues, "La prueba no escribe preferencias de calidad")
	FileAccess.open(SALIDA + "/resultado.json", FileAccess.WRITE).store_string(JSON.stringify({"pruebas": _pruebas, "fallos": _fallos, "adaptador": RenderingServer.get_video_adapter_name(), "resolucion": [1280, 720], "muestras": _resultados}, "\t"))
	print("[ULTRA] %d comprobaciones; %d fallos" % [_pruebas, _fallos])
	if is_instance_valid(_oficina):
		_oficina.queue_free()
	await process_frame
	quit(1 if _fallos else 0)


func _recargar_ultra() -> void:
	_oficina.queue_free()
	await process_frame
	_calidad.establecer(3, false)
	root.get_node("MenuGlobal").omitir_tutorial_siguiente_partida = true
	var carga := root.get_node("CargaEscenas")
	carga.cargar("res://Mundo/Oficina.tscn")
	var limite := Time.get_ticks_msec() + 65000
	while carga.activa and Time.get_ticks_msec() < limite:
		await process_frame
	var cargada: bool = not carga.activa and is_instance_valid(current_scene) and current_scene.scene_file_path == "res://Mundo/Oficina.tscn"
	_verificar(cargada, "Se puede reiniciar con Ultra elegido")
	if not cargada:
		return
	_oficina = current_scene
	var camara := _oficina.get_node("Gameplay/Camera3D") as Camera3D
	var piso := _oficina.get_node("Pared, suelo, techo/PisoTerremoto/Suelo").material as ShaderMaterial
	_verificar(is_equal_approx(camara.environment.ambient_light_energy, 0.26), "Una oficina nueva aplica Ultra al entrar")
	_calidad.establecer(2, false)
	_verificar(is_equal_approx(camara.environment.ambient_light_energy, 0.36) and is_equal_approx(piso.get_shader_parameter("rugosidad"), 0.74), "Reiniciar en Ultra no contamina los recursos del aspecto base")


func _estado() -> Dictionary:
	var estado := {"ambiente": _camara.environment.ambient_light_color,
		"energia_ambiente": _camara.environment.ambient_light_energy,
		"exposicion": _camara.environment.tonemap_exposure,
		"contraste": _camara.environment.adjustment_contrast,
		"saturacion": _camara.environment.adjustment_saturation,
		"rugosidad": _piso.get_shader_parameter("rugosidad"),
		"especular": _piso.get_shader_parameter("especular")}
	for luz in _luces:
		estado[String(luz.name) + "_color"] = luz.light_color
		estado[String(luz.name) + "_energia"] = luz.light_energy
	return estado


func _estado_equivalente(a: Dictionary, b: Dictionary) -> bool:
	for clave in a:
		if a[clave] is Color:
			if not (a[clave] as Color).is_equal_approx(b[clave]): return false
		elif not is_equal_approx(float(a[clave]), float(b[clave])):
			return false
	return true


func _comparar() -> void:
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for zona in ["trabajo", "descanso"]:
		_camara.position = Vector3(-1, 5.8, 7 if zona == "trabajo" else 12.1)
		_camara.look_at(Vector3(-1, 0.9, 3.4 if zona == "trabajo" else 8.6))
		var pasada := 0
		# A/B/B/A reduce el sesgo por calentamiento/carga externa entre procesos.
		for nivel in [2, 3, 3, 2]:
			_calidad.establecer(nivel, false)
			await create_timer(1.0).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(SALIDA + "/%s_%d.png" % [zona, nivel])
			await create_timer(0.5).timeout
			var cuadros: Array[float] = []
			var dibujos: Array[float] = []
			var gpu: Array[float] = []
			var fin := Time.get_ticks_usec() + 4000000
			var previo := Time.get_ticks_usec()
			while Time.get_ticks_usec() < fin:
				await process_frame
				var ahora := Time.get_ticks_usec()
				cuadros.append((ahora - previo) / 1000.0)
				previo = ahora
				dibujos.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			var nombre := "%s_%d_%d" % [zona, nivel, pasada]
			_resultados[nombre] = {"cuadro_ms": _resumen(cuadros), "draw_calls": _resumen(dibujos), "gpu_ms": _resumen(gpu)}
			print("[ULTRA PERFIL] ", nombre, " ", JSON.stringify(_resultados[nombre]))
			pasada += 1
	_calidad.establecer(2, false)


func _resumen(valores: Array[float]) -> Dictionary:
	valores.sort()
	return {"p50": valores[int((valores.size() - 1) * 0.50)], "p95": valores[int((valores.size() - 1) * 0.95)], "p99": valores[int((valores.size() - 1) * 0.99)], "max": valores[-1]}


func _verificar(condicion: bool, mensaje: String) -> void:
	_pruebas += 1
	if not condicion:
		_fallos += 1
		push_error("[ULTRA] " + mensaje)
