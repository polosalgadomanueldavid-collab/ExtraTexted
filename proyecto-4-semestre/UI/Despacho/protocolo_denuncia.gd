extends Control
## Lista de estaciones independientes: pendiente o completada, en cualquier orden.

var estaciones: Array[String] = []
var completadas: Array[String] = []
const TINTA := Color("173b50")
const ICONO := preload("res://UI/Despacho/icono_despacho.gd")
var compacto := false


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
	var radio := minf(12.0 if compacto else 20.0, ancho_paso * 0.34)
	var y := 15.0 if compacto else 24.0
	for indice: int in range(estaciones.size()):
		var centro := Vector2(ancho_paso * (indice + 0.5), y)
		var completada := completadas.has(estaciones[indice])
		var caja := StyleBoxFlat.new()
		caja.bg_color = Color("d7e2bd") if completada else Color("f4e4c5")
		caja.border_color = Color("507b65") if completada else Color("b5a482")
		caja.set_border_width_all(2 if completada else 1)
		caja.set_corner_radius_all(6)
		draw_style_box(caja, Rect2(centro - Vector2.ONE * radio, Vector2.ONE * radio * 2.0))
		var id := estaciones[indice]
		ICONO.dibujar_estacion(self, ICONO.tipo_estacion(id), centro, radio * 1.4, Color("3e6855") if completada else TINTA)
		if completada:
			var marca := centro + Vector2(0.78, 0.72) * radio
			draw_circle(marca, 5 if compacto else 7, Color("507b65"), true, -1.0, true)
			draw_polyline(PackedVector2Array([
				marca + Vector2(-3, 0), marca + Vector2(-1, 2), marca + Vector2(3, -2)
			]), Color("fff1d8"), 1.8, true)
