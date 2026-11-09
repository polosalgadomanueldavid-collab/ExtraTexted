extends SceneTree
## Pisadas reales al caminar/correr y silencio al parar, saltar o chocar.

var errores: int = 0
var indices: Array[int] = []
var cuadros: Array[int] = []


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	var laboratorio := (load("res://Pruebas/PersonajePolicia/PruebaPoliciaAzul.tscn") as PackedScene).instantiate()
	root.add_child(laboratorio)
	current_scene = laboratorio
	await _cuadros(60)
	var jugador = laboratorio.get_node("PoliciaAzul")
	var pasos := jugador.get_node("SonidosPasos") as SonidosPasos
	pasos.paso_reproducido.connect(_registrar)
	_verificar(jugador.is_on_floor() and not pasos.playing, "El personaje aparece en el suelo y sin pisadas")
	_verificar(pasos.pasos.size() == 6, "Se cargan las seis variaciones de la opción 3")
	for pista: AudioStream in pasos.pasos:
		_verificar(pista.resource_path.begins_with("res://Audios/Pasos/SuelaGoma/") and (pista as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED, "Suela de goma se reproduce como pisada individual")
	var principal := (load("res://Personajes/PoliciaAzul/Policia.tscn") as PackedScene).instantiate()
	_verificar(principal.get_node_or_null("SonidosPasos") is SonidosPasos, "La escena de la oficina usa el mismo sistema de pasos")
	principal.free()

	var inicio: Vector3 = jugador.global_position
	Input.action_press(&"policia_prueba_adelante")
	await _cuadros(64)
	var direccion: Vector3 = (jugador.global_position - inicio).normalized()
	_verificar(indices.size() >= 3, "Caminar de verdad produce pisadas sucesivas")
	var intervalo_caminar := cuadros[1] - cuadros[0] if cuadros.size() > 1 else 0
	_verificar(intervalo_caminar >= 26 and intervalo_caminar <= 28, "Caminar separa las pisadas aproximadamente 0.45 s")
	var desde_correr := cuadros.size()
	Input.action_press(&"policia_prueba_correr")
	await _cuadros(50)
	_verificar(cuadros.size() >= desde_correr + 2, "Correr sigue produciendo pisadas")
	var intervalo_correr := cuadros[-1] - cuadros[-2] if cuadros.size() >= desde_correr + 2 else 100
	_verificar(intervalo_correr >= 17 and intervalo_correr <= 19 and intervalo_correr < intervalo_caminar, "Correr acelera la cadencia a aproximadamente 0.30 s")
	var sin_repetir := true
	for i: int in range(1, indices.size()):
		sin_repetir = sin_repetir and indices[i] != indices[i - 1]
	_verificar(sin_repetir, "Las pisadas consecutivas alternan las muestras")
	Input.action_release(&"policia_prueba_adelante")
	Input.action_release(&"policia_prueba_correr")
	await _cuadros(25)
	var cantidad := indices.size()
	await _cuadros(20)
	_verificar(not pasos.playing and indices.size() == cantidad, "Parar detiene las pisadas")

	jugador.reset_to_spawn()
	await _cuadros(4)
	Input.action_press(&"policia_prueba_adelante")
	await _cuadros(3)
	_verificar(pasos.playing, "Volver a caminar inicia una pisada sin esperar un bucle")
	paused = true
	cantidad = indices.size()
	await create_timer(0.15).timeout
	_verificar(pasos.stream_paused and indices.size() == cantidad, "La pausa congela sonido y cadencia")
	paused = false
	jugador.input_locked = true
	await _cuadros(3)
	_verificar(not pasos.playing and indices.size() == cantidad, "Bloquear los controles detiene los pasos")
	Input.action_release(&"policia_prueba_adelante")
	jugador.input_locked = false

	jugador.reset_to_spawn()
	await _cuadros(4)
	cantidad = indices.size()
	Input.action_press(&"policia_prueba_adelante")
	Input.action_press(&"policia_prueba_saltar")
	await _cuadros(12)
	Input.action_release(&"policia_prueba_saltar")
	Input.action_release(&"policia_prueba_adelante")
	_verificar(not jugador.is_on_floor() and not pasos.playing and indices.size() == cantidad, "Desplazarse en un salto no produce pisadas en el aire")
	jugador.reset_to_spawn()
	await _cuadros(4)
	_verificar(not pasos.playing, "Reiniciar silencia los pasos")

	var pared := StaticBody3D.new()
	var colision := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(8, 3, 0.4)
	colision.shape = caja
	pared.add_child(colision)
	laboratorio.add_child(pared)
	pared.global_position = jugador.global_position + direccion * 0.8 + Vector3.UP * 0.4
	pared.rotation.y = atan2(direccion.x, direccion.z)
	await _cuadros(2)
	Input.action_press(&"policia_prueba_adelante")
	await _cuadros(45)
	cantidad = indices.size()
	await _cuadros(35)
	_verificar(indices.size() == cantidad and not pasos.playing, "Empujar contra una pared no mantiene pasos ficticios")
	Input.action_release(&"policia_prueba_adelante")
	laboratorio.queue_free()
	await _cuadros(2)
	await create_timer(0.12).timeout
	print("PRUEBA PASOS PERSONAJE: %d errores" % errores)
	quit(0 if errores == 0 else 1)


func _registrar(indice: int) -> void:
	indices.append(indice)
	cuadros.append(Engine.get_physics_frames())


func _cuadros(cantidad: int) -> void:
	for cuadro: int in cantidad:
		await physics_frame
		await process_frame


func _verificar(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("OK: " + mensaje)
	else:
		errores += 1
		push_error(mensaje)
