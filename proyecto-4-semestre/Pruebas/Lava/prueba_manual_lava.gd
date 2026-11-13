extends Node
## F6: oficina jugable con evento de lava y sus casos normales.


func _ready() -> void:
	_preparar.call_deferred()


func _preparar() -> void:
	MenuGlobal.omitir_tutorial_siguiente_partida = true
	var oficina := load("res://Mundo/Oficina.tscn").instantiate() as Node3D
	get_tree().root.add_child(oficina)
	get_tree().current_scene = oficina
	reparent(oficina)
	await get_tree().create_timer(5.0, false).timeout
	while not oficina._iniciar_lava():
		await get_tree().create_timer(0.5, false).timeout
	queue_free()
