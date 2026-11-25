extends RefCounted
## El mezclador de audio usa tiempo real, incluso con --fixed-fps acelerado.
## Cerrar las escenas y detener las voces antes de terminar el proceso de prueba.

static func cerrar(arbol: SceneTree) -> void:
	for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		for reproductor: Node in arbol.root.find_children("*", tipo, true, false):
			reproductor.stop()
	if is_instance_valid(arbol.current_scene) and not arbol.current_scene.is_queued_for_deletion():
		arbol.current_scene.queue_free()
	await arbol.process_frame
	var limite := Time.get_ticks_msec() + 300
	while Time.get_ticks_msec() < limite:
		OS.delay_msec(4)
		await arbol.process_frame
