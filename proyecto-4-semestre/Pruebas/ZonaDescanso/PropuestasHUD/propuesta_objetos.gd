extends Control
## Boceto visual aislado. No conectado al inventario ni a los controles reales.
const TITULO := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const TEXTO := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
const TINTA := Color("173b50")
const CREMA := Color("fff1d8")
const CORAL := Color("ff785f")
const SOMBRA := Color("0d2736aa")
const MENTA := Color("8fd4ba")
const TECLAS := ["Z", "X", "V", "N"]
const NOMBRES := ["CHOCOLATE", "DONA", "PAPA TIEMPO", "EL AVATAR"]
var alternativa := 0
var activo := false
var iconos: Array[Texture2D] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func caja(r: Rect2, color: Color, radio: int = 12, borde: Color = TINTA, grosor: int = 3) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = borde
	s.set_border_width_all(grosor)
	s.set_corner_radius_all(radio)
	draw_style_box(s, r)

func texto(s: String, p: Vector2, tam: int = 18, color: Color = CREMA, ancho: float = -1, cuerpo: bool = false) -> void:
	draw_string(TEXTO if cuerpo else TITULO, p, s, HORIZONTAL_ALIGNMENT_CENTER if ancho > 0 else HORIZONTAL_ALIGNMENT_LEFT, ancho, tam, color)

func icono(i: int, r: Rect2, opacidad: float = 1) -> void:
	if iconos.size() == 4:
		draw_texture_rect(iconos[i], r, false, Color(1, 1, 1, opacidad))

func medallon(i: int, centro: Vector2, radio: float, encendido: bool = false) -> void:
	draw_circle(centro + Vector2(0, 5), radio + 4, SOMBRA, true, -1, true)
	draw_circle(centro, radio + 4, TINTA, true, -1, true)
	draw_circle(centro, radio, MENTA if encendido else CORAL, true, -1, true)
	draw_circle(centro - Vector2(0, 2), radio - 4, CREMA, true, -1, true)
	draw_circle(centro, radio - 10, Color("eddec5"), true, -1, true)
	draw_arc(centro - Vector2(0, 2), radio - 6, PI * 1.1, PI * 1.72, 32, Color("fffaf0"), 2, true)
	icono(i, Rect2(centro - Vector2.ONE * radio * .90, Vector2.ONE * radio * 1.8))
	if encendido:
		draw_arc(centro, radio + 3, -PI/2, -PI/2 + TAU * .68, 64, MENTA, 4, true)

func tecla(i: int, p: Vector2, w: float, etiqueta: String = "") -> void:
	caja(Rect2(p + Vector2(0, 4), Vector2(w, 28)), SOMBRA, 9, SOMBRA, 0)
	caja(Rect2(p, Vector2(w, 28)), TINTA, 9, CREMA, 2)
	texto(TECLAS[i] + " · USAR" if etiqueta.is_empty() else etiqueta, p + Vector2(0, 21), 16, CREMA, w)

func _draw() -> void:
	match alternativa:
		0: _medallones()
		1: _destacado()
		2: _bandeja()

func _medallones() -> void:
	# Cuatro piezas independientes a la derecha del medallón de la hoja.
	for i in 4:
		var x := 192.0 + i * 96
		medallon(i, Vector2(x + 40, 588), 35, activo and i == 0)
		tecla(i, Vector2(x, 635), 80, "17 s" if activo and i == 0 else "")
		if not (activo and i == 0):
			caja(Rect2(x + 54, 550, 24, 22), CREMA, 8, TINTA, 2)
			texto("1", Vector2(x + 54, 567), 15, TINTA, 24)
	texto("REFUERZOS", Vector2(192, 535), 20)
	texto("VELOCIDAD ACTIVA" if activo else "LISTOS PARA USAR", Vector2(192, 685), 13, MENTA if activo else CREMA, -1, true)

func _destacado() -> void:
	# Hero principal y reserva: mismos atajos, sin introducir selección obligatoria.
	medallon(0, Vector2(244, 598), 49, activo)
	tecla(0, Vector2(190, 657), 108, "17 s · ACTIVO" if activo else "Z · USAR")
	caja(Rect2(306, 594, 202, 48), SOMBRA, 10, SOMBRA, 0)
	caja(Rect2(302, 590, 202, 48), CREMA, 10)
	texto("CHOCOLATE", Vector2(314, 611), 20, TINTA)
	texto("Velocidad ×1,65 · 25 s", Vector2(314, 630), 14, TINTA, -1, true)
	for i in range(1, 4):
		var x := 327.0 + (i - 1) * 67
		medallon(i, Vector2(x, 547), 23)
		caja(Rect2(x + 11, 559, 23, 23), TINTA, 7, CREMA, 2)
		texto(TECLAS[i], Vector2(x + 11, 577), 15, CREMA, 23)
	texto("EN TU BOLSILLO", Vector2(306, 663), 14)
	texto("3 reservas", Vector2(306, 683), 14, CREMA, -1, true)

func _bandeja() -> void:
	caja(Rect2(188, 550, 340, 137), SOMBRA, 18, SOMBRA, 0)
	caja(Rect2(184, 544, 340, 137), CREMA, 18, TINTA, 4)
	caja(Rect2(200, 530, 148, 29), CORAL, 9, TINTA, 3)
	texto("MI BOLSILLO", Vector2(200, 553), 19, TINTA, 148)
	for i in 4:
		var x := 201.0 + i * 79
		caja(Rect2(x, 568, 68, 68), MENTA if activo and i == 0 else Color("eadbc3"), 12, Color("c9bda9"), 1)
		icono(i, Rect2(x + 1, 569, 66, 66))
		tecla(i, Vector2(x, 643), 68, "17 s" if activo and i == 0 else "")
		if activo and i == 0:
			caja(Rect2(x + 5, 629, 58, 4), TINTA, 2, TINTA, 0)
			caja(Rect2(x + 5, 629, 39, 4), MENTA.lightened(.3), 2, MENTA, 0)
