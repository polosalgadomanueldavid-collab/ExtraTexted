extends SceneTree

func _initialize() -> void:
	var conductor: Node = load("res://Pruebas/Multijugador/resistencia_lan.gd").new()
	conductor.name = "ResistenciaLAN"
	root.add_child.call_deferred(conductor)
