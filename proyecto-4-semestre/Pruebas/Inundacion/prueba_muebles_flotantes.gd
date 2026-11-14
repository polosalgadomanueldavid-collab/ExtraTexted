extends SceneTree
## --headless --fixed-fps 60 --script res://Pruebas/Inundacion/prueba_muebles_flotantes.gd
## Sin --headless, añadir -- --capturas para revisar los tres muebles.

var oficina: Node3D
var errores := 0
var poses: Dictionary = {}
const RUTAS := ["MaquinaExpendedora/Modelo", "AlfombraCentro", "PlantaEsquinaCuadranteInferior"]


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var menu := root.get_node("MenuGlobal")
	menu.omitir_tutorial_siguiente_partida = true
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	await _cuadros(60)
	menu.cerrar_ayuda()
	oficina.tutoriales_vistos[&"inundacion"] = true
	oficina.temporizador_denuncias.stop()
	oficina.temporizador_eventos.stop()
	oficina.temporizador_bloqueos.stop()
	oficina.computador.timer_nuevo_problema.stop()
	oficina.sistema_despacho.set_process(false)
	oficina.bloqueos_iniciados = true
	var jugador: CharacterBody3D = oficina.jugador
	jugador.global_position = Vector3(0.9, 0.38, 9.1)
	await _cuadros(12)
	var evento: Node3D = oficina.evento_inundacion
	var maquina: Node3D = oficina.get_node("MaquinaExpendedora")
	var pose_maquina := maquina.global_transform
	for ruta: String in RUTAS:
		poses[ruta] = oficina.get_node(ruta).transform
	await _capturar("01_sin_agua")
	_verificar(_puede_cruzar_tapete(), "El tapete seco no añade obstáculos al suelo")
	var inicio: bool = oficina._iniciar_inundacion()
	_verificar(inicio, "Inicia la inundación real")
	if not inicio:
		quit(1)
		return
	await _cuadros(270)
	for ruta: String in RUTAS:
		_verificar(oficina.get_node(ruta).position.y > poses[ruta].origin.y + 0.5, "Flota: " + ruta)
	_verificar(maquina.global_transform.is_equal_approx(pose_maquina), "La expendedora conserva su obstáculo y punto de interacción")
	var tapete: Node3D = oficina.get_node("AlfombraCentro")
	_verificar(tapete.global_position.y > evento.nivel, "El tapete permanece visible sobre el agua")
	await _capturar("02_muebles_flotando")
	jugador.set_physics_process(false)
	var posicion_jugador := jugador.global_position
	var lados := [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	var bloquea := true
	var sigue_malla := true
	# Probar lados y fases del cabeceo con el cuerpo real del jugador.
	for fase in 12:
		await _cuadros(20)
		var cuerpo: AnimatableBody3D = evento._colision_alfombra
		var forma := cuerpo.get_child(0) as CollisionShape3D
		var limites := forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
		sigue_malla = sigue_malla and absf(limites.end.y - tapete.to_global(evento._centro_alfombra).y - 0.02) < 0.001
		for lado: Vector3 in lados:
			var borde := limites.size.x * 0.5 if lado.x != 0.0 else limites.size.z * 0.5
			jugador.global_position = limites.get_center() + lado * (borde + 0.4)
			jugador.global_position.y = evento.PISO + 0.003
			var choque := jugador.move_and_collide(-lado * 0.9)
			var acierto := choque != null and choque.get_collider() == cuerpo
			if not acierto:
				print("FALLO LADO ", lado, " fase=", fase, " colision=", choque.get_collider() if choque else null)
			bloquea = bloquea and acierto
	_verificar(bloquea, "El jugador no atraviesa ninguno de los cuatro lados durante el balanceo")
	_verificar(sigue_malla, "La colisión acompaña al tapete en cada paso de física")
	jugador.global_position = posicion_jugador
	jugador.velocity = Vector3.ZERO
	jugador.set_physics_process(true)
	evento.drenando = true
	await _cuadros(270)
	_verificar(not evento.activo and _puede_cruzar_tapete(), "El vaciado permite volver a caminar sobre el tapete")
	_verificar(_poses_restauradas(), "Los tres objetos recuperan su posición y orientación exactas")
	_verificar(oficina._iniciar_inundacion(), "El evento puede repetirse")
	await _cuadros(270)
	_verificar(evento._colision_alfombra.collision_layer == 1 and tapete.position.y > poses["AlfombraCentro"].origin.y + 0.5, "El tapete vuelve a flotar con colisión")
	evento.resolver_con_avatar()
	await _cuadros(2)
	_verificar(_poses_restauradas() and _puede_cruzar_tapete(), "Resolver con Avatar también restaura objetos y colisión")
	await _capturar("03_restaurados")
	oficina.queue_free()
	await process_frame
	print("[MUEBLES FLOTANTES] %d errores" % errores)
	quit(1 if errores else 0)


func _poses_restauradas() -> bool:
	for ruta: String in RUTAS:
		if not oficina.get_node(ruta).transform.is_equal_approx(poses[ruta]):
			return false
	return true


func _puede_cruzar_tapete() -> bool:
	var jugador: CharacterBody3D = oficina.jugador
	var desde := jugador.global_transform
	desde.origin = oficina.get_node("AlfombraCentro").global_position + Vector3.FORWARD * 1.6
	desde.origin.y = oficina.evento_inundacion.PISO + 0.003
	return not jugador.test_move(desde, Vector3.BACK * 3.2)


func _cuadros(cantidad: int) -> void:
	for i in cantidad:
		await physics_frame
		await process_frame


func _capturar(nombre: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--capturas" in OS.get_cmdline_user_args():
		return
	var anterior := root.get_camera_3d()
	var camara := Camera3D.new()
	oficina.add_child(camara)
	camara.cull_mask = 524287
	camara.fov = 70
	camara.global_position = Vector3(-1.2, 4.2, 11.7)
	camara.look_at(Vector3(-1.1, 0.9, 8.7))
	camara.make_current()
	await _cuadros(4)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/muebles_flotantes_qa")
	root.get_texture().get_image().save_png("res://.godot/muebles_flotantes_qa/%s.png" % nombre)
	anterior.make_current()
	camara.queue_free()


func _verificar(condicion: bool, mensaje: String) -> void:
	print("[OK] " if condicion else "[ERROR] ", mensaje)
	if not condicion:
		errores += 1
