extends RefCounted

const TINTA := Color("173b50")
const CREMA := Color("fff1d8")


static func dibujar_placa(lienzo: CanvasItem, caja: Rect2, color: Color, radio: float = 8.0, profundidad: float = 5.0) -> void:
	for paso: int in range(4, 0, -1):
		var sombra := caja.grow(float(paso) * 1.4)
		sombra.position += Vector2(3, profundidad + 3)
		dibujar_rectangulo_redondeado(lienzo, sombra, Color(0.015, 0.04, 0.055, 0.055), radio + paso)
	dibujar_rectangulo_redondeado(lienzo, Rect2(caja.position + Vector2(0, profundidad), caja.size), color.darkened(0.57), radio)
	dibujar_rectangulo_redondeado(lienzo, caja, TINTA.darkened(0.3), radio)
	dibujar_gradiente(lienzo, caja.grow(-1.5), color.lightened(0.42), color.darkened(0.38), maxf(1.0, radio - 1))
	dibujar_gradiente(lienzo, caja.grow(-4), color.lightened(0.10), color.darkened(0.12), maxf(1.0, radio - 3))


static func dibujar_disco(lienzo: CanvasItem, centro: Vector2, radio: float, color: Color, sombra: bool = true) -> void:
	if sombra:
		lienzo.draw_circle(centro + Vector2(3, 5), radio + 2, Color(0.01, 0.04, 0.05, 0.35), true, -1, true)
	lienzo.draw_circle(centro, radio, TINTA.darkened(0.2), true, -1, true)
	for paso: int in range(ceili(radio - 1), 0, -1):
		var fraccion := float(paso) / radio
		var luz := color.darkened(0.35).lerp(color.lightened(0.35), 1.0 - fraccion)
		var desplazamiento := Vector2(-radio * 0.08, -radio * 0.12) * (1.0 - fraccion)
		lienzo.draw_circle(centro + desplazamiento, float(paso), luz, true, -1, true)
	lienzo.draw_arc(centro, radio - 2, PI * 1.03, PI * 1.78, 28, Color(CREMA, 0.43), 1.5, true)


static func dibujar_tornillo(lienzo: CanvasItem, centro: Vector2, radio: float = 8, giro: float = -0.7) -> void:
	dibujar_disco(lienzo, centro, radio, Color("9ba9a5"))
	var direccion := Vector2.from_angle(giro) * radio * 0.57
	lienzo.draw_line(centro - direccion + Vector2(0, 1), centro + direccion + Vector2(0, 1), Color(CREMA, 0.5), 2.5, true)
	lienzo.draw_line(centro - direccion, centro + direccion, TINTA.darkened(0.2), 2.4, true)


static func dibujar_cable(lienzo: CanvasItem, puntos: PackedVector2Array, color: Color, grosor: float = 9.0) -> void:
	var sombra := PackedVector2Array()
	var brillo := PackedVector2Array()
	for punto: Vector2 in puntos:
		sombra.append(punto + Vector2(3, 5))
		brillo.append(punto + Vector2(-0.8, -1.2))
	lienzo.draw_polyline(sombra, Color(0.01, 0.03, 0.04, 0.27), grosor + 7, true)
	lienzo.draw_polyline(sombra, Color(0.01, 0.03, 0.04, 0.25), grosor + 2, true)
	lienzo.draw_polyline(puntos, color.darkened(0.55), grosor + 2, true)
	lienzo.draw_polyline(puntos, color.darkened(0.10), grosor, true)
	lienzo.draw_polyline(brillo, color.lightened(0.24), grosor * 0.36, true)


static func dibujar_rectangulo_redondeado(lienzo: CanvasItem, caja: Rect2, color: Color, radio: float) -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.set_corner_radius_all(roundi(radio))
	lienzo.draw_style_box(estilo, caja)


static func dibujar_gradiente(lienzo: CanvasItem, caja: Rect2, arriba: Color, abajo: Color, radio: float) -> void:
	var alto := maxi(1, ceili(caja.size.y))
	var r := minf(radio, minf(caja.size.x, caja.size.y) * 0.5)
	for fila: int in range(alto):
		var y := float(fila) + 0.5
		var distancia := minf(y, caja.size.y - y)
		var margen := 0.0
		if distancia < r:
			margen = r - sqrt(maxf(0.0, r * r - pow(r - distancia, 2)))
		var tono := arriba.lerp(abajo, float(fila) / maxf(1.0, alto - 1.0))
		lienzo.draw_line(caja.position + Vector2(margen, y), caja.position + Vector2(caja.size.x - margen, y), tono, 1.1)
