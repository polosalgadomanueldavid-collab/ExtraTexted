extends SceneTree
## Coste CPU medio de actualizar la capa, sin renderizado.
## Ejecutar con --headless --script res://Pruebas/PersonajePolicia/medir_capa_avatar.gd
func _initialize() -> void:
	medir.call_deferred()
func medir() -> void:
	var jugador = load("res://Personajes/PoliciaAzul/Policia.tscn").instantiate()
	root.add_child(jugador)
	jugador.set_physics_process(false)
	for i in 3:
		await process_frame
	var capa = jugador.gestos.capa_avatar
	var inicio := Time.get_ticks_usec()
	for i in 40:
		capa.actualizar(i / 12.0)
	print("CAPA_CPU_MS=", (Time.get_ticks_usec() - inicio) / 40000.0)
	jugador.queue_free()
	for i in 3:
		await process_frame
	quit()
