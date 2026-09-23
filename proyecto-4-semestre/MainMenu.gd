extends Control

const OFFICE_SCENE := "res://Oficina.tscn"

@onready var play_button: Button = %PlayButton


func _ready() -> void:
	play_button.grab_focus()


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file(OFFICE_SCENE)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
