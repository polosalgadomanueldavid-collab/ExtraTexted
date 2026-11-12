extends RefCounted
## Marcos ilustrados con el centro extensible para listas de distinta altura.

const TINTA := Color("0d293e")
const CREMA := Color("efdab3")
const CORAL := Color("ed7158")
const VINETA := preload("res://UI/Menus/ArtePiloto/clasificacion_vineta.svg")
const EXPEDIENTE := preload("res://UI/Menus/ArtePiloto/clasificacion_expediente.svg")


static func margenes(izquierda: int, arriba: int, derecha: int, abajo: int) -> StyleBoxEmpty:
	var estilo := StyleBoxEmpty.new()
	estilo.content_margin_left = izquierda
	estilo.content_margin_top = arriba
	estilo.content_margin_right = derecha
	estilo.content_margin_bottom = abajo
	return estilo


static func caja(color: Color, borde: Color, grosor: int, radio: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.border_color = borde
	estilo.set_border_width_all(grosor)
	estilo.set_corner_radius_all(radio)
	return estilo


static func marco(lienzo: Control, textura: Texture2D, alto_arriba: int, alto_abajo: int) -> void:
	var origen := textura.get_size()
	var destino := lienzo.size
	# Sólo se estira la zona de las filas. Conserva las proporciones de la cabecera y del pie.
	var ys := PackedFloat32Array([0, alto_arriba, origen.y - alto_abajo, origen.y])
	var yd := PackedFloat32Array([0, alto_arriba, destino.y - alto_abajo, destino.y])
	for i in range(3):
		if yd[i + 1] > yd[i]:
			lienzo.draw_texture_rect_region(textura,
				Rect2(0, yd[i], destino.x, yd[i + 1] - yd[i]),
				Rect2(0, ys[i], origen.x, ys[i + 1] - ys[i]))


static func renglon(lienzo: Control) -> void:
	var y := lienzo.size.y - 1
	lienzo.draw_line(Vector2(1, y), Vector2(lienzo.size.x - 2, y), Color("aa9f89"), 1.4, true)


static func fila_expediente(lienzo: Control, propia: bool, puesto: int) -> void:
	var w := lienzo.size.x
	var h := lienzo.size.y
	if propia:
		lienzo.draw_style_box(caja(Color("ecac95"), Color.TRANSPARENT, 0, 13), Rect2(27,4,w-31,h-8))
		lienzo.draw_colored_polygon(PackedVector2Array([Vector2(0,h*0.22),
			Vector2(24,h*0.5), Vector2(1,h*0.79), Vector2(5,h*0.5)]), CORAL)
	lienzo.draw_line(Vector2(13,h-1), Vector2(w-9,h-1), Color("ae9c79"), 1.7, true)
	var rect := Rect2(39, 8, 98, h-16)
	var color := CREMA
	if propia:
		color = Color("f08c66")
	elif puesto == 1:
		color = Color("eaba63")
	lienzo.draw_style_box(caja(Color("ad9674"), Color.TRANSPARENT, 0, 16), Rect2(rect.position+Vector2(1,3),rect.size))
	lienzo.draw_style_box(caja(color, TINTA, 3, 16), rect)
	lienzo.draw_style_box(caja(Color.TRANSPARENT, color.lightened(0.23), 2, 12), rect.grow(-4))
