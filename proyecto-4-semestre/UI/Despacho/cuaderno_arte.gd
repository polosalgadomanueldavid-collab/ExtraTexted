extends Control
## Papel impreso; cubierta, cantos y espiral pertenecen al modelo 3D.

const PAPEL := Color("f6f3e8")
const CUADRICULA := Color(0.38, 0.48, 0.46, 0.13)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(1280, 720)
	queue_redraw()


func _draw() -> void:
	for rect: Rect2 in [Rect2(70, 43, 556, 611), Rect2(654, 43, 556, 611)]:
		var papel := StyleBoxFlat.new()
		papel.bg_color = PAPEL
		papel.set_corner_radius_all(11)
		papel.corner_detail = 8
		draw_style_box(papel, rect)
		for x: int in range(int(rect.position.x) + 20, int(rect.end.x) - 8, 37):
			draw_line(Vector2(x, 55), Vector2(x, 645), CUADRICULA, 0.8, true)
		for y: int in range(69, 645, 37):
			draw_line(Vector2(rect.position.x + 5, y), Vector2(rect.end.x - 5, y), CUADRICULA, 0.8, true)
		# Variación muy tenue de las fibras, determinista y sin texturas externas.
		for i: int in range(135):
			var x := rect.position.x + 12 + fmod(float(i * 137), rect.size.x - 24)
			var y := 58.0 + fmod(float(i * 73), 578.0)
			draw_line(Vector2(x, y), Vector2(x + 2.5, y + 0.5), Color(0.42, 0.40, 0.32, 0.065), 0.7, true)
	for indice: int in range(32):
		var y := 75.0 + indice * 18.5
		for x: int in [619, 661]:
			draw_circle(Vector2(x, y), 4.4, Color("394c51"))
			draw_arc(Vector2(x, y), 5.4, 0.0, PI, 10, Color(0.46, 0.46, 0.40, 0.25), 1.0, true)
