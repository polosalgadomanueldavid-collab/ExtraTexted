extends RefCounted
## Ilustración del expediente físico que lleva el jugador, sin rótulos.

const TINTA := Color("173b50")
const CREMA := Color("fff1d8")
const VERDE := Color("507b65")

static func caja(c: CanvasItem, rect: Rect2, color: Color, radio := 3.0) -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.set_corner_radius_all(roundi(radio))
	c.draw_style_box(estilo, rect)

static func resultado(c: CanvasItem, id: String, centro: Vector2, lado: float, obtenido: bool, sellado := true) -> void:
	c.draw_set_transform(centro - Vector2.ONE * lado * .5, 0, Vector2.ONE * lado / 64.0)
	var tinta := TINTA if obtenido else Color("98794f")
	var papel := CREMA if obtenido else Color("e6cea0")
	if id == "bienestar":
		c.draw_circle(Vector2(32, 32), 23, Color("efd1a0") if obtenido else papel)
		c.draw_circle(Vector2(24, 27), 2.5, tinta)
		c.draw_circle(Vector2(40, 27), 2.5, tinta)
		c.draw_arc(Vector2(32, 30), 12, .2, PI-.2, 24, VERDE if obtenido else tinta, 2.5, true)
	elif id == "evidencias":
		caja(c, Rect2(12, 15, 42, 36), tinta, 2)
		caja(c, Rect2(15, 11, 31, 34), papel, 1)
		caja(c, Rect2(10, 24, 46, 30), Color("d7ac69") if obtenido else papel, 2)
		caja(c, Rect2(11, 19, 18, 9), Color("d7ac69") if obtenido else papel, 1)
		c.draw_line(Vector2(17, 35), Vector2(45, 35), tinta, 2, true)
		c.draw_line(Vector2(17, 41), Vector2(37, 41), tinta, 2, true)
	else:
		caja(c, Rect2(14, 5, 38, 53), tinta, 2)
		caja(c, Rect2(16, 7, 34, 49), Color("dce6cd") if obtenido and id == "privacidad" else papel, 1)
		if id == "verificacion":
			c.draw_circle(Vector2(29, 20), 6, tinta)
			caja(c, Rect2(22, 27, 14, 9), tinta)
		elif id == "privacidad":
			c.draw_arc(Vector2(29, 20), 6, 0, TAU, 20, tinta, 2.5, true)
			c.draw_line(Vector2(33, 25), Vector2(42, 34), tinta, 3, true)
			c.draw_line(Vector2(37, 29), Vector2(40, 26), tinta, 3, true)
		else:
			caja(c, Rect2(22, 14, 19, 6), tinta, 1)
		for y in [40, 46]: c.draw_line(Vector2(22, y), Vector2(44, y), tinta, 2, true)
	if obtenido and sellado and id != "bienestar":
		c.draw_circle(Vector2(48, 49), 8, Color("d7e2bd"))
		c.draw_arc(Vector2(48, 49), 7, 0, TAU, 24, VERDE, 1.6, true)
		c.draw_polyline(PackedVector2Array([Vector2(44, 49), Vector2(47, 52), Vector2(52, 45)]), VERDE, 2, true)
	c.draw_set_transform(Vector2.ZERO)
