extends "res://Eventos/Incendio/indicador_extintor.gd"


func _ready() -> void:
	super._ready()
	name = "IndicadorNitrogeno"
	rotulo = "NITRÓGENO"


func _dibujar_extintor() -> void:
	_caja(Rect2(-10, -38, 20, 78), Color("86b6ed"), TINTA, 5)
	for y: float in [-30.0, 23.0]:
		_caja(Rect2(-15, y, 30, 8), Color("e4f5ff"), TINTA, 3)
	var hexagono := PackedVector2Array()
	for i in 6:
		hexagono.append(Vector2.from_angle(i * TAU / 6.0) * 28)
	draw_colored_polygon(hexagono, Color("bfe7ff"))
	hexagono.append(hexagono[0])
	draw_polyline(hexagono, TINTA, 4, true)
	draw_circle(Vector2.ZERO, 15, TINTA, true, -1, true)
	for i in 6:
		var d := Vector2.from_angle(i * TAU / 6.0)
		draw_line(Vector2.ZERO, d * 12, Color("e4f5ff"), 2, true)
		draw_line(d * 8, d * 4 + d.orthogonal() * 4, Color("e4f5ff"), 2, true)
