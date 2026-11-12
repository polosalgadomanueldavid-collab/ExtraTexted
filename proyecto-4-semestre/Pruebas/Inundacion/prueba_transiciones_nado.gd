extends SceneTree
## --headless --fixed-fps 60 --script res://Pruebas/Inundacion/prueba_transiciones_nado.gd
## -- --capturas guarda una secuencia de movimiento real a 60 fps (un PNG cada 2 frames).
## Añadir --detalle para una cámara que sigue las brazadas de cerca.

var oficina: Node3D
var jugador
var evento
var errores := 0
var brazadas := 0
var _rotaciones: Dictionary = {}
var _mayor_salto := 0.0
var _captura := 0
var _fase_anterior := 0.0
var _fase_valida := true
var _seguir_fase := false
var _camara: Camera3D


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 640)
	root.get_node("MenuGlobal").omitir_tutorial_siguiente_partida = true
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	await _frames(45)
	root.get_node("MenuGlobal").cerrar_ayuda()
	oficina.temporizador_denuncias.stop()
	oficina.temporizador_bloqueos.stop()
	oficina.temporizador_eventos.stop()
	oficina.computador.timer_nuevo_problema.stop()
	oficina.sistema_despacho.set_process(false)
	jugador = oficina.jugador
	evento = oficina.evento_inundacion
	jugador.global_position = Vector3(-1.3, 0.38, 8.8)
	jugador.visual.rotation.y = 0.0
	await _frames(12)
	# Un reloj avanzado reproduce el antiguo salto al cambiar la frecuencia.
	jugador.fase_nado = 123.0
	_fase_anterior = jugador.fase_nado
	_seguir_fase = true
	jugador.gestos.modification_processed.connect(_medir_pose)
	jugador.brazada_agua.connect(func(_lado: String) -> void: brazadas += 1)
	oficina.bloqueos_iniciados = true
	_verificar(oficina._iniciar_inundacion(), "Inicia la prueba de agua y poses")
	await _frames(270)
	_verificar(jugador.peso_nado == 1.0 and _mayor_salto < 0.30, "Subir el agua mezcla caminar con flotación sin saltos de pose")
	_camara = Camera3D.new()
	oficina.add_child(_camara)
	_camara.cull_mask = 524287
	_camara.fov = 48
	_camara.global_position = Vector3(1.7, 2.75, 11.8)
	_camara.look_at(Vector3(-0.6, 0.98, 8.8))
	_camara.make_current()
	oficina.get_node("CanvasLayer").hide()
	await _frames(60, true)
	_verificar(jugador.avance_nado < 0.01, "Flotación en reposo sin brazadas de avance")
	Input.action_press(jugador.RIGHT)
	await _frames(1, true)
	_verificar(jugador.avance_nado < 0.15, "Arrancar mezcla gradualmente hacia las brazadas")
	await _frames(125, true)
	_verificar(jugador.avance_nado > 0.9 and brazadas > 0, "La velocidad real alimenta las brazadas y sus salpicaduras")
	Input.action_release(jugador.RIGHT)
	await _frames(1, true)
	_verificar(jugador.avance_nado > 0.75, "Soltar movimiento conserva la inercia de la pose")
	await _frames(65, true)
	_verificar(jugador.avance_nado < 0.03, "El frenado termina en remadas suaves de flotación")
	# Dos impactos grandes permiten inspeccionar corona, rebote y disipación.
	evento.salpicar(Vector3(-1.35, 0, 9.0), 1.0)
	await _frames(12, true)
	evento.salpicar(Vector3(-0.4, 0, 8.0), 0.85)
	await _frames(85, true)
	_verificar(_fase_valida, "La fase avanza sin reinicios al acelerar o frenar")
	_verificar(_mayor_salto < 0.30, "Hombros, codos y piernas no saltan entre poses (máx. %.3f rad)" % _mayor_salto)
	var fase_pausa: float = jugador.fase_nado
	var edad_pausa: float = evento.tiempo
	paused = true
	await _frames(12)
	_verificar(jugador.fase_nado == fase_pausa and evento.tiempo == edad_pausa, "Pausar congela la fase del personaje y las ondas")
	paused = false
	Input.action_press(jugador.LEFT)
	evento.drenando = true
	await _frames(300, true)
	Input.action_release(jugador.LEFT)
	_verificar(not jugador.nadando and jugador.peso_nado == 0.0, "El vaciado funde la pose de nado hasta caminar")
	_verificar(_mayor_salto < 0.30 and _fase_valida, "Salir del agua en movimiento mantiene la continuidad del esqueleto")
	_verificar(jugador.get_node("Visual/Modelo").transform.is_equal_approx(jugador._pose_modelo), "Se recupera la transformación exacta del modelo")
	_verificar(evento._efectos.get_child_count() == 0 and evento._impactos.is_empty(), "Las coronas, estelas e impulsos se liberan al terminar")
	print("[TRANSICIONES NADO] %d errores · %d brazadas · salto máximo %.3f rad" % [errores, brazadas, _mayor_salto])
	oficina.queue_free()
	await process_frame
	quit(1 if errores else 0)


func _medir_pose() -> void:
	var esqueleto: Skeleton3D = jugador.gestos.get_skeleton()
	for hueso: String in ["upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R", "thigh.L", "shin.R"]:
		var rotacion := esqueleto.get_bone_pose_rotation(esqueleto.find_bone(hueso))
		if _rotaciones.has(hueso):
			_mayor_salto = maxf(_mayor_salto, rotacion.angle_to(_rotaciones[hueso]))
		_rotaciones[hueso] = rotacion
	if _seguir_fase:
		var diferencia: float = jugador.fase_nado - _fase_anterior
		_fase_valida = _fase_valida and diferencia >= 0 and diferencia < 0.16
		_fase_anterior = jugador.fase_nado


func _frames(cantidad: int, capturar := false) -> void:
	for i in cantidad:
		await physics_frame
		await process_frame
		if capturar and DisplayServer.get_name() != "headless" and "--capturas" in OS.get_cmdline_user_args():
			var detalle := "--detalle" in OS.get_cmdline_user_args()
			if detalle:
				_camara.fov = 35
				_camara.global_position = jugador.global_position + Vector3(-1.4, 1.6, 1.6)
				_camara.look_at(jugador.global_position + Vector3(0, 0.68, 0))
			await RenderingServer.frame_post_draw
			if _captura % 2 == 0:
				var carpeta := "res://.godot/nado_secuencia_detalle" if detalle else "res://.godot/nado_secuencia"
				DirAccess.make_dir_recursive_absolute(carpeta)
				root.get_texture().get_image().save_png(carpeta.path_join("%04d.png" % (_captura / 2)))
			_captura += 1


func _verificar(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("[OK] " + mensaje)
	else:
		errores += 1
		push_error(mensaje)
