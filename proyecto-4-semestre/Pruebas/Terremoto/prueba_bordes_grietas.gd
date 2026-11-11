extends SceneTree
## Cruces con el cuerpo y los controles reales, en una losa sin muebles.

const Grieta := preload("res://Eventos/Terremoto/grieta.gd")
var suelo: CSGBox3D
var jugador: CharacterBody3D
var errores := 0


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	var sala := Node3D.new()
	root.add_child(sala)
	current_scene = sala
	suelo = CSGBox3D.new()
	suelo.size = Vector3(8, 1, 8)
	suelo.position.y = -0.5
	suelo.material = StandardMaterial3D.new()
	suelo.use_collision = true
	sala.add_child(suelo)
	jugador = load("res://Personajes/PoliciaAzul/Policia.tscn").instantiate()
	jugador.position = Vector3(2, 0.02, 2)
	sala.add_child(jugador)
	var evento := load("res://Eventos/Terremoto/evento_terremoto.gd") as Script
	for indice in range(1, evento.ANCHOS.size()):
		for angulo: float in [0.0, PI / 4.0, PI / 2.0]:
			var azar := RandomNumberGenerator.new()
			azar.seed = 114 + indice
			var grieta := Grieta.new()
			grieta.saltable = true
			grieta.trazar(Vector2.ZERO, evento.LARGOS[indice], evento.ANCHOS[indice], angulo, azar)
			sala.add_child(grieta)
			grieta.abrir(suelo)
			await _fisicas(60)
			var direccion := Vector2.RIGHT.rotated(angulo)
			await _cruzar(grieta, direccion, false, false)
			await _cruzar(grieta, -direccion, true, false)
			await _cruzar(grieta, direccion, true, true)
			var borde := grieta.contorno[3].lerp(grieta.contorno[4], 0.5)
			var exterior := grieta._contorno_exterior()
			var sobre_bisel := borde.lerp(exterior[3].lerp(exterior[4], 0.5), 0.3)
			var golpe := _pisar(sobre_bisel)
			if golpe.is_empty() or golpe.collider != grieta.get_node("BordeFracturado") or golpe.position.y >= -0.01:
				errores += 1
				push_error("El canto visible debe sostener los pies a la altura del bisel")
			grieta.cerrar()
			await _fisicas(4)
			golpe = _pisar(sobre_bisel)
			if golpe.is_empty() or golpe.collider != suelo or absf(golpe.position.y) > 0.003:
				errores += 1
				push_error("Al recomponerse el piso vuelve a tener una superficie plana")
	sala.queue_free()
	await process_frame
	var fin_audio := Time.get_ticks_msec() + 250
	while Time.get_ticks_msec() < fin_audio:
		OS.delay_msec(4)
		await process_frame
	print("[BORDES DE GRIETAS] %d errores" % errores)
	quit(1 if errores else 0)


func _cruzar(grieta: Grieta, sentido: Vector2, correr: bool, saltar: bool) -> void:
	var cerca := 0.0
	var lejos := 0.0
	while grieta.contiene(sentido * cerca):
		cerca -= 0.005
	while grieta.contiene(sentido * lejos):
		lejos += 0.005
	var eje := Vector3(sentido.x, 0, sentido.y)
	jugador.global_position = eje * (cerca - 0.72) + Vector3.UP * 0.025
	jugador.velocity = Vector3.ZERO
	await _fisicas(12)
	var horizontal := &"policia_prueba_derecha" if sentido.x >= 0.0 else &"policia_prueba_izquierda"
	var vertical := &"policia_prueba_atras" if sentido.y >= 0.0 else &"policia_prueba_adelante"
	Input.action_press(horizontal, absf(sentido.x))
	Input.action_press(vertical, absf(sentido.y))
	if correr:
		Input.action_press(&"policia_prueba_correr")
	var salto := false
	var cayo := false
	var cruzo := false
	for i in range(150):
		var avance := jugador.global_position.dot(eje)
		if saltar and not salto and avance >= cerca - 0.05:
			Input.action_press(&"policia_prueba_saltar")
			salto = true
		else:
			Input.action_release(&"policia_prueba_saltar")
		await physics_frame
		if jugador.global_position.y < -0.55:
			cayo = true
			break
		if jugador.global_position.dot(eje) > lejos + 0.12 and jugador.is_on_floor():
			cruzo = true
			break
	Input.action_release(horizontal)
	Input.action_release(vertical)
	Input.action_release(&"policia_prueba_correr")
	Input.action_release(&"policia_prueba_saltar")
	var correcto := (cruzo and salto) if saltar else cayo
	if not correcto:
		errores += 1
		push_error("Cruce %s, carrera=%s, salto=%s: cayó=%s, cruzó=%s, pies=%s" % [
			sentido, correr, saltar, cayo, cruzo, jugador.global_position])


func _pisar(punto: Vector2) -> Dictionary:
	var origen := Vector3(punto.x, 0.25, punto.y)
	var rayo := PhysicsRayQueryParameters3D.create(origen, origen + Vector3.DOWN * 0.5, 1)
	return suelo.get_world_3d().direct_space_state.intersect_ray(rayo)


func _fisicas(cantidad: int) -> void:
	for i in range(cantidad):
		await physics_frame
