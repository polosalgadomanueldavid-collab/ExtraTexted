extends Control
## Lista de estaciones independientes: pendiente o completada, en cualquier orden.

var estaciones: Array[String] = []
var completadas: Array[String] = []
const TINTA := Color("173b50")
const CORAL := Color("ff785f")
const COMPLETADA := Color("16b6b6")
const ICONO := preload("res://UI/Despacho/icono_despacho.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func configurar(nuevas_estaciones: Array[String], nuevas_completadas: Array[String]) -> void:
	if estaciones == nuevas_estaciones and completadas == nuevas_completadas:
		return
	estaciones = nuevas_estaciones.duplicate()
	completadas = nuevas_completadas.duplicate()
	queue_redraw()


func _draw() -> void:
	if estaciones.is_empty():
		return
	var ancho_paso := size.x / estaciones.size()
	var radio := minf(19, ancho_paso * 0.24)
	var y := 22.0
	var fuente := get_theme_font("font", "Label")
	for indice: int in range(estaciones.size()):
		var centro := Vector2(ancho_paso * (indice + 0.5), y)
		var completada := completadas.has(estaciones[indice])
		var color := COMPLETADA if completada else CORAL
		draw_circle(centro, radio, color)
		draw_arc(centro, radio, 0, TAU, 40, TINTA, 1.8, true)
		var id := estaciones[indice]
		ICONO.dibujar_estacion(self, ICONO.tipo_estacion(id), centro, radio * 1.4, TINTA)
		if completada:
			var marca := centro + Vector2(0.68, -0.68) * radio
			draw_circle(marca, 7, TINTA, true, -1.0, true)
			draw_polyline(PackedVector2Array([
				marca + Vector2(-3, 0), marca + Vector2(-1, 2), marca + Vector2(3, -2)
			]), Color("fff1d8"), 1.8, true)
		var texto := ICONO.nombre_estacion(id)
		var tamano := 14 if estaciones.size() <= 3 else 12
		while tamano > 9 and fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x > ancho_paso - 12:
			tamano -= 1
		var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
		draw_string(fuente, Vector2(centro.x - ancho * 0.5, 62), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, TINTA)
