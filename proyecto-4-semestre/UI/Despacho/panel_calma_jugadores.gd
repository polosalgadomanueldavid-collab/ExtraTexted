class_name PanelCalmaJugadores
extends VBoxContainer

const FilaCalma := preload("res://UI/Despacho/fila_calma_jugador.gd")

var filas: Dictionary[int, FilaCalmaJugador] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)
	actualizar_jugador(1, 100)


func actualizar_jugador(indice: int, calma: int) -> void:
	if indice < 1:
		return
	if not filas.has(indice):
		var fila := FilaCalma.new() as FilaCalmaJugador
		fila.name = "Jugador%d" % indice
		filas[indice] = fila
		add_child(fila)
		_ordenar_filas()
	filas[indice].actualizar(indice, calma)


func quitar_jugador(indice: int) -> void:
	if indice == 1 or not filas.has(indice):
		return
	filas[indice].queue_free()
	filas.erase(indice)


func _ordenar_filas() -> void:
	var indices := filas.keys()
	indices.sort()
	for indice: int in indices:
		move_child(filas[indice], get_child_count() - 1)
