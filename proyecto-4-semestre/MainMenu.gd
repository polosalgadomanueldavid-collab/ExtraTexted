extends Control

const OFFICE_SCENE := "res://Oficina.tscn"

@onready var play_button: Button = %PlayButton


func _ready() -> void:
	play_button.grab_focus()


func _on_play_button_pressed() -> void:
	var error := get_tree().change_scene_to_file(OFFICE_SCENE)
	if error != OK:
		push_error("No se pudo abrir la oficina: %s" % error)


func _on_options_button_pressed() -> void:
	MenuGlobal.abrir_opciones()


func _on_quit_button_pressed() -> void:
	AjustesAccesibilidad.guardar()
	get_tree().quit()
