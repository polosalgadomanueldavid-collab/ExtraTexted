extends Node
## F6: oficina real con el incendio preparado tras cerrar la ayuda inicial.


func _ready() -> void:
	_preparar.call_deferred()


func _preparar() -> void:
	var oficina := load("res://Mundo/Oficina.tscn").instantiate() as Node3D
	get_tree().root.add_child(oficina)
	get_tree().current_scene = oficina
	# Mantener la oficina real como escena actual conserva ayuda, pausa y reinicio.
	reparent(oficina)
	await get_tree().create_timer(5.0, false).timeout
	while not oficina._iniciar_incendio():
		await get_tree().create_timer(0.5, false).timeout
	queue_free()
