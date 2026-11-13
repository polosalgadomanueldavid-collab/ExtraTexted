@tool
extends PanelContainer
## Marco exclusivo de Opciones y Accesibilidad; el contenido sigue siendo nativo.

const TINTA := Color("173b50")
const CREMA := Color("fff1d8")

@export var portapapeles: bool = false:
	set(valor):
		portapapeles = valor
		_actualizar_margenes()
		queue_redraw()


func _ready() -> void:
	_actualizar_margenes()
	resized.connect(queue_redraw)


func _actualizar_margenes() -> void:
	var margenes := StyleBoxEmpty.new()
	margenes.content_margin_left = 64.0
	margenes.content_margin_right = 64.0
	margenes.content_margin_top = 112.0 if portapapeles else 52.0
	margenes.content_margin_bottom = 40.0
	add_theme_stylebox_override("panel", margenes)


func _draw() -> void:
	var alto_pinza := 36.0 if portapapeles else 0.0
	var marco := Rect2(0, alto_pinza, size.x, size.y - alto_pinza)
	var sombra := _estilo(Color("061f2d80"), Color.TRANSPARENT, 36, 0)
	draw_style_box(sombra, Rect2(marco.position + Vector2(8, 10), marco.size))
	draw_style_box(_estilo(Color("244c5d"), Color("102f40"), 36, 4), marco)
	draw_style_box(_estilo(Color("3b6675"), Color.TRANSPARENT, 30, 0), marco.grow(-7.0))
	var papel := marco.grow(-18.0)
	draw_style_box(_estilo(TINTA, Color.TRANSPARENT, 22, 0), Rect2(papel.position + Vector2(0, 5), papel.size))
	draw_style_box(_estilo(CREMA, TINTA, 22, 3), papel)
	if portapapeles:
		_dibujar_pinza()


func _dibujar_pinza() -> void:
	var puntos := PackedVector2Array([
		Vector2(-112, 80), Vector2(-120, 74), Vector2(-120, 66),
		Vector2(-98, 36), Vector2(-90, 32), Vector2(-42, 32),
		Vector2(-34, 25), Vector2(-32, 16), Vector2(-26, 7),
		Vector2(-15, 1), Vector2(0, 0), Vector2(15, 1),
		Vector2(26, 7), Vector2(32, 16), Vector2(34, 25),
		Vector2(42, 32), Vector2(90, 32), Vector2(98, 36),
		Vector2(120, 66), Vector2(120, 74), Vector2(112, 80),
	])
	for indice: int in range(puntos.size()):
		puntos[indice].x += size.x * 0.5
	draw_colored_polygon(puntos, Color("b7b6ad"))
	puntos.append(puntos[0])
	draw_polyline(puntos, TINTA, 4.0, true)
	draw_line(Vector2(size.x * 0.5 - 108, 72), Vector2(size.x * 0.5 + 108, 72), Color("93978f"), 5.0, true)
	draw_circle(Vector2(size.x * 0.5, 21), 10.0, TINTA, true, -1.0, true)
	draw_circle(Vector2(size.x * 0.5, 21), 6.0, Color("e4e0d3"), true, -1.0, true)


func _estilo(color: Color, borde: Color, radio: int, grosor: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.border_color = borde
	estilo.set_border_width_all(grosor)
	estilo.set_corner_radius_all(radio)
	return estilo
