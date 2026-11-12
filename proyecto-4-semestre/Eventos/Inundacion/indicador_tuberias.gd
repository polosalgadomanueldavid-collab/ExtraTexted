extends "res://Eventos/Incendio/indicador_extintor.gd"


func _ready() -> void:
	super._ready()
	name = "IndicadorTuberias"
	rotulo = "TUBERÍAS"


func _dibujar_extintor() -> void:
	draw_polyline(PackedVector2Array([Vector2(-29, 25), Vector2(-29, -13), Vector2(26, -13), Vector2(26, 25)]), TINTA, 22, true)
	draw_polyline(PackedVector2Array([Vector2(-29, 25), Vector2(-29, -13), Vector2(26, -13), Vector2(26, 25)]), Color("53c9d8"), 14, true)
	draw_circle(Vector2(0, -13), 17, TINTA, true, -1, true)
	draw_arc(Vector2(0, -13), 13, 0, TAU, 32, ORO, 4, true)
	for i in 4:
		var direccion_valvula := Vector2.from_angle(i * PI * 0.5 + _tiempo * 0.3)
		draw_line(Vector2(0, -13), Vector2(0, -13) + direccion_valvula * 13, ORO, 3, true)
