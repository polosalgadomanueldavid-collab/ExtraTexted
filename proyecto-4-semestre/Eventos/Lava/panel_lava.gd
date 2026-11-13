extends Control
## Reloj persistente, estado del apoyo y aviso del próximo cambio de cajones.

const TITULO := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const TEXTO := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
var restante := 60.0
var cambio := 4.0
var estado := "¡Suelo caliente! Pierdes cordura"
var seguro := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	hide()


func _ajustar() -> void:
	var pantalla := get_viewport().get_visible_rect().size
	var factor := minf(pantalla.x / 1920.0, pantalla.y / 1080.0)
	size = Vector2(600, 172)
	scale = Vector2.ONE * factor
	position = Vector2(pantalla.x * 0.5 - 300.0 * factor, 18.0 * factor)
	queue_redraw()


func actualizar(segundos: float, proximo: float, mensaje: String, refugio: bool) -> void:
	restante = segundos
	cambio = proximo
	estado = mensaje
	seguro = refugio
	queue_redraw()


func _draw() -> void:
	var borde := Color("ffb34f") if restante > 10.0 else Color("ff7258")
	var caja := StyleBoxFlat.new()
	caja.bg_color = Color("241a17")
	caja.border_color = borde
	caja.set_border_width_all(2)
	caja.set_corner_radius_all(18)
	draw_style_box(caja, Rect2(Vector2.ZERO, size))
	draw_string(TITULO, Vector2(24, 38), "¡EL PISO ES LAVA!", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("ffd48a"))
	var segundos := ceili(maxf(0.0, restante))
	draw_string(TEXTO, Vector2(449, 48), "%02d:%02d" % [segundos / 60, segundos % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color("fff1d8"))
	draw_arc(Vector2(422, 32), 16.0, -PI * 0.5, TAU - PI * 0.5, 48, Color("594052"), 4.0, true)
	draw_arc(Vector2(422, 32), 16.0, -PI * 0.5, TAU * clampf(restante / 60.0, 0.0, 1.0) - PI * 0.5, 48, borde, 4.0, true)
	draw_line(Vector2(422, 32), Vector2(422, 21), Color("fff1d8"), 2.0, true)
	draw_line(Vector2(422, 32), Vector2(429, 36), Color("fff1d8"), 2.0, true)
	draw_string(TEXTO, Vector2(24, 74), "ESPACIO · Salta a los bloqueos temporales", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("fff1d8"))
	draw_string(TEXTO, Vector2(24, 103), estado, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("a8e4c3") if seguro else Color("ffb195"))
	draw_string(TEXTO, Vector2(24, 134), "Los bloqueos cambian en %.1f s" % maxf(0.0, cambio), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("dac0a5"))
	draw_style_box(_barra(Color("5b3c2b")), Rect2(24, 147, 552, 7))
	draw_style_box(_barra(borde), Rect2(24, 147, maxf(0.1, 552.0 * cambio / 4.0), 7))


func _barra(color: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.set_corner_radius_all(3)
	return estilo
