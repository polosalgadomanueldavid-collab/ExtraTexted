extends SceneTree

func _initialize() -> void:
	_iniciar.call_deferred()

func _iniciar() -> void:
	root.add_child(load("res://Pruebas/Multijugador/conductor_conexion.gd").new())
