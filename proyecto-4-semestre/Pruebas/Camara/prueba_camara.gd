extends SceneTree
## Godot --headless --path <proyecto> --script res://Pruebas/Camara/prueba_camara.gd
## Sin --headless, añadir -- --capturas para guardar las tres vistas de la oficina.

const Camara := preload("res://Scripts/camera_3d.gd")

var _errores: int = 0
var _oficina: Node3D
var _camara: Camara
var _jugador: CharacterBody3D


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	_oficina = (load("res://Oficina.tscn") as PackedScene).instantiate()
	root.add_child(_oficina)
	current_scene = _oficina
	await _cuadros(3)
	var menu := root.get_node("MenuGlobal")
	menu.cerrar_ayuda()
	_camara = _oficina.get_node("Gameplay/Camera3D") as Camara
	_jugador = _oficina.get_node("Gameplay/Node3D") as CharacterBody3D
	await _fisicas(60)
	_jugador.set_physics_process(false)
	_camara.set_physics_process(false)
	_oficina.temporizador_denuncias.stop()
	_oficina.temporizador_bloqueos.stop()
	_oficina.computador.timer_nuevo_problema.stop()
	_oficina.depurador_grafo.hide()
	var orientacion_original := _camara.global_basis
	_camara.balanceo_activo = false
	_avanzar(6.0)
	_verificar(_camara.vista_actual == Camara.Vista.ACTUAL, "La partida empieza con la vista original")
	_verificar(_camara.global_basis.is_equal_approx(orientacion_original), "La vista actual conserva el ángulo de la escena")
	_verificar(_camara.global_position.distance_to(_jugador.global_position + _camara.offset) < 0.001, "Se conserva la distancia original")
	var techo := _oficina.get_node("Pared, suelo, techo/Techo") as CSGBox3D
	_verificar((techo.layers & _camara.cull_mask) == 0, "La cámara excluye el techo para despejar la vista cenital y las transiciones")
	var pared_posterior := _oficina.get_node("Pared, suelo, techo/Pared4") as CSGBox3D
	_verificar((pared_posterior.layers & _camara.cull_mask) != 0, "La pared posterior se dibuja también desde arriba")

	await _pulsar(KEY_C)
	_verificar(_camara.vista_actual == Camara.Vista.FRONTAL, "C cambia a la vista frontal")
	var antes := _camara.global_transform
	_camara._physics_process(1.0 / 60.0)
	_verificar(_camara.global_position.distance_to(antes.origin) < 0.2, "La transición comienza sin saltos de posición")
	_verificar(antes.basis.get_rotation_quaternion().angle_to(_camara.global_basis.get_rotation_quaternion()) < 0.05, "El ángulo cambia gradualmente")
	_avanzar(6.0)
	_verificar(absf(_camara.global_rotation_degrees.x - _camara.inclinacion_frontal) < 0.01, "La vista frontal mira más hacia enfrente")
	await _pulsar(KEY_C)
	_verificar(_camara.vista_actual == Camara.Vista.GOD, "C cambia a la vista God")
	_avanzar(6.0)
	_verificar((-_camara.global_basis.z).dot(Vector3.DOWN) > 0.9999, "God mira verticalmente desde arriba")
	_verificar(_camara.global_position.distance_to(_jugador.global_position + _camara.offset_god) < 0.001, "God se sitúa encima del personaje")
	_probar_direcciones()
	var posicion_inicial := _jugador.global_position
	_jugador.set_physics_process(true)
	Input.action_press(&"policia_prueba_adelante")
	await _fisicas(20)
	Input.action_release(&"policia_prueba_adelante")
	_jugador.set_physics_process(false)
	_verificar(_jugador.global_position.z < posicion_inicial.z - 0.1, "W desplaza realmente al personaje en vista cenital")
	_jugador.global_position = posicion_inicial
	_jugador.velocity = Vector3.ZERO
	await _pulsar(KEY_C)
	_verificar(_camara.vista_actual == Camara.Vista.ACTUAL, "C vuelve a la vista actual al completar el ciclo")
	await _pulsar(KEY_C, true)
	_verificar(_camara.vista_actual == Camara.Vista.ACTUAL, "Mantener C no repite el cambio")
	for tecla: Key in [KEY_3, KEY_1, KEY_2]:
		await _pulsar(tecla)
		_verificar(int(_camara.vista_actual) == int(tecla) - int(KEY_1), "Selección directa con la tecla %s" % OS.get_keycode_string(tecla))
	_jugador.input_locked = true
	await _pulsar(KEY_C)
	_verificar(_camara.vista_actual == Camara.Vista.FRONTAL, "Una interacción que bloquea al jugador conserva la cámara")
	_jugador.input_locked = false
	_camara.set_physics_process(true)
	menu.abrir_pausa()
	antes = _camara.global_transform
	var fase_anterior := _camara._fase_balanceo
	await _pulsar(KEY_3)
	await _cuadros(5)
	_verificar(_camara.vista_actual == Camara.Vista.FRONTAL and _camara.global_transform == antes and _camara._fase_balanceo == fase_anterior, "La pausa congela la cámara, el balanceo y los atajos")
	menu.reanudar_juego()
	_camara.set_physics_process(false)
	var otra_camara := Camera3D.new()
	root.add_child(otra_camara)
	otra_camara.make_current()
	await _pulsar(KEY_3)
	_verificar(_camara.vista_actual == Camara.Vista.FRONTAL, "Los atajos respetan otras cámaras activas")
	otra_camara.free()
	_camara.make_current()

	_probar_limites()
	await _probar_zona_segura()
	await _probar_balanceo()
	for vista: int in range(Camara.Vista.size()):
		_camara.establecer_vista(vista)
		_avanzar(6.0)
		await _capturar(["01_actual", "02_frontal", "03_god"][vista])
	_jugador.global_position.z = 11.3
	_camara.establecer_vista(Camara.Vista.GOD)
	_avanzar(6.0)
	await _capturar("04_god_fondo")
	_camara.establecer_vista(Camara.Vista.FRONTAL)
	_avanzar(6.0)
	await _capturar("04_frontal_fondo")
	await _probar_apagon()
	print("CÁMARA: %d errores" % _errores)
	_oficina.queue_free()
	await _cuadros(2)
	quit(0 if _errores == 0 else 1)


func _probar_direcciones() -> void:
	for entrada: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var direccion: Vector3 = _jugador._camera_relative_direction(entrada)
		var esperada := Vector3(entrada.x, 0, entrada.y).normalized()
		_verificar(direccion.is_finite() and direccion.dot(esperada) > 0.9999 and is_equal_approx(direccion.length(), 1.0), "Movimiento cenital correcto para %s" % entrada)


func _probar_limites() -> void:
	var origen := _jugador.global_position
	for esquina: Vector3 in [Vector3(-100, origen.y, -100), Vector3(100, origen.y, 100)]:
		_jugador.global_position = esquina
		for vista: int in range(Camara.Vista.size()):
			_camara.establecer_vista(vista)
			_avanzar(6.0)
			_verificar(_camara.recinto_visible.has_point(Vector2(_camara.global_position.x, _camara.global_position.z)), "La cámara permanece dentro de las paredes en esquina %s, vista %d" % [esquina, vista])
	_jugador.global_position = origen
	_camara.establecer_vista(Camara.Vista.ACTUAL)
	_avanzar(6.0)
	var antes := _camara.global_position
	_jugador.global_position.x += 1.0
	_camara._physics_process(1.0)
	_verificar(_camara.global_position.x >= antes.x and _camara.global_position.x <= _jugador.global_position.x, "Un cuadro lento no hace que el seguimiento sobrepase al jugador")
	_jugador.global_position = origen
	_avanzar(6.0)


func _probar_zona_segura() -> void:
	var origen := _jugador.global_position
	var tamano := root.size
	var balanceo := _camara.balanceo_activo
	_camara.balanceo_activo = true
	var esquinas: Array[Vector2] = [Vector2(-3.9, 0.6), Vector2(1.9, 0.6), Vector2(-3.9, 11.8), Vector2(1.9, 11.8)]
	for resolucion: Vector2i in [Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(2560, 1080), Vector2i(2560, 720)]:
		root.size = resolucion
		await _cuadros(2)
		for esquina: Vector2 in esquinas:
			_jugador.global_position = Vector3(esquina.x, origen.y, esquina.y)
			for vista: int in [Camara.Vista.ACTUAL, Camara.Vista.FRONTAL, Camara.Vista.GOD, Camara.Vista.FRONTAL, Camara.Vista.ACTUAL, Camara.Vista.GOD, Camara.Vista.ACTUAL]:
				_camara.establecer_vista(vista)
				var encuadre_cerrado := true
				for cuadro: int in range(180):
					_camara._physics_process(1.0 / 60.0)
					if cuadro % 15 == 0:
						encuadre_cerrado = _rayos_dentro_de_oficina() and encuadre_cerrado
				_verificar(encuadre_cerrado, "Sin exterior visible durante transición a vista %d en %s a %s" % [vista, esquina, resolucion])
				var punto := _camara.unproject_position(_jugador.global_position + Vector3.UP * 0.45)
				_verificar(not _camara.is_position_behind(_jugador.global_position) and Rect2(Vector2.ZERO, Vector2(root.size)).has_point(punto), "El personaje sigue en pantalla junto a la pared, vista %d a %s" % [vista, resolucion])
	root.size = tamano
	await _cuadros(2)
	_jugador.global_position = origen
	_camara.balanceo_activo = balanceo
	_camara.establecer_vista(Camara.Vista.ACTUAL)
	_avanzar(6.0)


func _rayos_dentro_de_oficina() -> bool:
	var pantalla := Vector2(root.size)
	var espacio := _oficina.get_world_3d().direct_space_state
	for uv: Vector2 in [Vector2(0.001, 0.001), Vector2(0.5, 0.001), Vector2(0.999, 0.001), Vector2(0.001, 0.5), Vector2(0.999, 0.5), Vector2(0.001, 0.999), Vector2(0.5, 0.999), Vector2(0.999, 0.999)]:
		var inicio := _camara.project_ray_origin(uv * pantalla)
		var consulta := PhysicsRayQueryParameters3D.create(inicio, inicio + _camara.project_ray_normal(uv * pantalla) * 150.0, 1)
		var impacto := espacio.intersect_ray(consulta)
		if impacto.is_empty():
			return false
		var punto: Vector3 = impacto["position"]
		if not _camara.recinto_visible.grow(0.18).has_point(Vector2(punto.x, punto.z)):
			return false
	return true


func _probar_balanceo() -> void:
	await _pulsar(KEY_M)
	_verificar(_camara.balanceo_activo, "M activa el balanceo")
	_avanzar(6.0)
	var centro := _camara._posicion_seguimiento
	var maximo := 0.0
	var cuadrantes: Dictionary = {}
	for cuadro: int in range(roundi(_camara.periodo_balanceo * 60.0) * 3):
		_camara._physics_process(1.0 / 60.0)
		var local := _camara.global_basis.inverse() * (_camara.global_position - centro)
		maximo = maxf(maximo, local.length())
		if absf(local.x) > 0.005 and absf(local.y) > 0.005:
			cuadrantes[Vector2i(int(signf(local.x)), int(signf(local.y)))] = true
	_verificar(maximo > 0.11 and maximo < 0.14, "El balanceo es visible y mantiene una amplitud moderada")
	_verificar(cuadrantes.size() == 4, "El infinito recorre los dos lóbulos por arriba y por abajo")
	_verificar(_camara._posicion_seguimiento.distance_to(centro) < 0.0001, "Tres ciclos de balanceo no acumulan deriva")
	await _pulsar(KEY_M)
	var antes := _camara.global_position
	_camara._physics_process(1.0 / 60.0)
	_verificar(_camara.global_position.distance_to(antes) < 0.015, "Desactivar el balanceo lo desvanece suavemente")
	_avanzar(6.0)
	_verificar(not _camara.balanceo_activo and _camara.global_position.distance_to(centro) < 0.0001, "M permite dejar la cámara completamente estable")


func _probar_apagon() -> void:
	var evento: Node = _oficina.get_node("EventoApagon")
	_verificar(evento.iniciar_apagon(), "El apagón de la oficina sigue disponible")
	for vista: int in range(Camara.Vista.size()):
		_camara.establecer_vista(vista)
		_avanzar(6.0)
		await _cuadros(2)
		var material := evento.mascara.material as ShaderMaterial
		var centro: Vector2 = material.get_shader_parameter("centro_uv")
		var esperado := _camara.unproject_position(_jugador.global_position + Vector3.UP * 0.4) / root.get_visible_rect().size
		var radio: float = material.get_shader_parameter("radio_pixeles")
		_verificar(evento.mascara.visible and centro.distance_to(esperado) < 0.001 and is_finite(radio) and radio > 0.0, "La visión del apagón sigue centrada en el jugador en vista %d" % vista)
	await _capturar("05_god_apagon")


func _avanzar(segundos: float) -> void:
	for cuadro: int in range(roundi(segundos * 60.0)):
		_camara._physics_process(1.0 / 60.0)


func _pulsar(tecla: Key, repetida: bool = false) -> void:
	var evento := InputEventKey.new()
	evento.physical_keycode = tecla
	evento.keycode = tecla
	evento.pressed = true
	evento.echo = repetida
	Input.parse_input_event(evento)
	await _cuadros(2)
	evento = InputEventKey.new()
	evento.physical_keycode = tecla
	evento.keycode = tecla
	Input.parse_input_event(evento)
	await _cuadros(2)


func _capturar(nombre: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--capturas" in OS.get_cmdline_user_args():
		return
	await _cuadros(2)
	await RenderingServer.frame_post_draw
	var directorio := "res://.godot/camara_qa"
	DirAccess.make_dir_recursive_absolute(directorio)
	root.get_texture().get_image().save_png(directorio.path_join(nombre + ".png"))


func _cuadros(cantidad: int) -> void:
	for cuadro: int in range(cantidad):
		await process_frame


func _fisicas(cantidad: int) -> void:
	for cuadro: int in range(cantidad):
		await physics_frame


func _verificar(condicion: bool, descripcion: String) -> void:
	if condicion:
		print("OK: ", descripcion)
	else:
		_errores += 1
		push_error(descripcion)
