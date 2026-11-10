extends Control

const ESCENA_MENU := "res://UI/Menus/MainMenu.tscn"
const DURACION_MINIMA := 0.35

var _inicio: float
var _abriendo := false


func _ready() -> void:
	_inicio = Time.get_ticks_msec() / 1000.0


func _process(_delta: float) -> void:
	if _abriendo:
		return
	if Time.get_ticks_msec() / 1000.0 - _inicio < DURACION_MINIMA:
		return
	_abriendo = true
	# El menú contiene escenas y scripts anidados que Godot debe preparar en el hilo principal.
	var menu := load(ESCENA_MENU) as PackedScene
	if menu == null or get_tree().change_scene_to_packed(menu) != OK:
		_abriendo = false
		push_error("No se pudo abrir el menú principal.")
