extends Control

const TAMANO_DISENO := Vector2(1920, 1080)

@onready var play_button: Button = %PlayButton
@onready var presentacion: Control = $CenterContainer


func _ready() -> void:
	resized.connect(_ajustar_escala)
	_ajustar_escala()
	play_button.grab_focus()


func _ajustar_escala() -> void:
	# Escala solo este menú: las pantallas de juego conservan sus coordenadas.
	var factor := minf(size.x / TAMANO_DISENO.x, size.y / TAMANO_DISENO.y)
	presentacion.scale = Vector2.ONE * factor
	presentacion.position = (size - TAMANO_DISENO * factor) * 0.5


func _on_play_button_pressed() -> void:
	MenuGlobal.pedir_nombre_partida()


func _on_options_button_pressed() -> void:
	MenuGlobal.abrir_opciones()


func _on_tutorial_button_pressed() -> void:
	MenuGlobal.abrir_tutorial()


func _on_ranking_button_pressed() -> void:
	MenuGlobal.abrir_clasificacion()


func _on_quit_button_pressed() -> void:
	AjustesAccesibilidad.guardar()
	get_tree().quit()
