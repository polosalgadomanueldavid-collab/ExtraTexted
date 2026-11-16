extends Control

func _ready() -> void:
	CargaEscenas.cargar.call_deferred("res://UI/Menus/MainMenu.tscn")
