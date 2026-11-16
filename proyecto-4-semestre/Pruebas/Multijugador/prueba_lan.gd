extends SceneTree

func _initialize() -> void:
	_iniciar.call_deferred()

func _iniciar() -> void:
	var conductor := load("res://Pruebas/Multijugador/conductor_lan.gd").new() as Node
	if conductor == null:
		quit(1)
		return
	conductor.name = "PruebaLAN"
	root.add_child.call_deferred(conductor)
