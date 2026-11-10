extends Control

## Dibuja el cuaderno abierto detrás de las dos páginas de resultados.

const PAPEL := Color("f8f6ef")
const PAPEL_SOMBRA := Color("e6e2d8")
const CUADRICULA := Color(0.30, 0.43, 0.48, 0.16)
const METAL := Color("667887")
const METAL_LUZ := Color("d7e0e3")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(1280, 720)
	queue_redraw()


func _draw() -> void:
	# Cubierta y hojas vistas por debajo del papel.
	draw_colored_polygon(PackedVector2Array([
		Vector2(75, 41), Vector2(1195, 42), Vector2(1233, 681), Vector2(52, 683)
	]), Color(0.02, 0.05, 0.07, 0.46))
	draw_colored_polygon(PackedVector2Array([
		Vector2(85, 34), Vector2(1192, 39), Vector2(1221, 676), Vector2(58, 677)
	]), Color("dc8a47"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(84, 46), Vector2(625, 54), Vector2(624, 664), Vector2(64, 661)
	]), PAPEL_SOMBRA)
	draw_colored_polygon(PackedVector2Array([
		Vector2(655, 53), Vector2(1201, 47), Vector2(1217, 661), Vector2(656, 665)
	]), PAPEL_SOMBRA)
	draw_colored_polygon(PackedVector2Array([
		Vector2(84, 42), Vector2(625, 50), Vector2(624, 654), Vector2(64, 650)
	]), PAPEL)
	draw_colored_polygon(PackedVector2Array([
		Vector2(655, 50), Vector2(1201, 43), Vector2(1217, 650), Vector2(656, 655)
	]), PAPEL)

	# Cuadrícula tenue en ambas caras.
	for x: int in range(105, 614, 37):
		draw_line(Vector2(x, 62), Vector2(x, 642), CUADRICULA, 1.0, true)
	for x: int in range(677, 1200, 37):
		draw_line(Vector2(x, 60), Vector2(x, 642), CUADRICULA, 1.0, true)
	for y: int in range(69, 645, 37):
		draw_line(Vector2(82, y), Vector2(617, y), CUADRICULA, 1.0, true)
		draw_line(Vector2(664, y), Vector2(1204, y), CUADRICULA, 1.0, true)
	draw_circle(Vector2(93, 622), 15.0, Color("344c60"))
	draw_circle(Vector2(1183, 622), 15.0, Color("344c60"))

	# Sombra del pliegue y varilla metálica.
	draw_rect(Rect2(616, 49, 11, 606), Color(0.15, 0.19, 0.22, 0.16))
	draw_rect(Rect2(653, 49, 12, 606), Color(0.15, 0.19, 0.22, 0.17))
	draw_rect(Rect2(634, 18, 12, 663), Color("273a49"))
	draw_line(Vector2(637, 21), Vector2(637, 676), METAL_LUZ, 3.0, true)
	for y: int in range(75, 641, 31):
		var sombra := PackedVector2Array()
		var brillo := PackedVector2Array()
		for paso: int in range(25):
			var angulo := float(paso) / 24.0 * TAU
			sombra.append(Vector2(640.0 + cos(angulo) * 24.0, float(y) + sin(angulo) * 10.0 + 2.0))
			brillo.append(Vector2(640.0 + cos(angulo) * 24.0, float(y) + sin(angulo) * 10.0))
		draw_polyline(sombra, Color(0.06, 0.09, 0.12, 0.55), 6.0, true)
		draw_polyline(brillo, METAL, 4.0, true)
		draw_line(Vector2(619, y - 4), Vector2(627, y - 7), METAL_LUZ, 2.0, true)
