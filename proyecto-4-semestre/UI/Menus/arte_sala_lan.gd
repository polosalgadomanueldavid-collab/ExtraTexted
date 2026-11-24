extends Control
## Trazos planos del panel LAN, sin texturas ni recursos de carga adicionales.
enum Tipo { FONDO, CINTA, SILUETA }
var tipo := Tipo.FONDO
const LINEA := Color("153743")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	match tipo:
		Tipo.FONDO: _oficina()
		Tipo.CINTA: _cinta()
		Tipo.SILUETA: _silueta()


func _trazo(puntos: PackedVector2Array, ancho := 4.0) -> void:
	draw_polyline(puntos, LINEA, ancho, true)


func _oficina() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(1600, 900))
	# Ventana izquierda: el centro permanece libre detrás del panel.
	draw_rect(Rect2(-20, 44, 244, 364), LINEA, false, 5)
	draw_rect(Rect2(-8, 60, 216, 330), LINEA, false, 3)
	for x in [64, 136]:
		_trazo(PackedVector2Array([Vector2(x, 60), Vector2(x, 390)]), 3)
	for y in [170, 280]:
		_trazo(PackedVector2Array([Vector2(0, y), Vector2(208, y)]), 3)
	# Mesa, taza y lámpara a la derecha.
	_trazo(PackedVector2Array([Vector2(1440, 520), Vector2(1630, 520)]), 6)
	_trazo(PackedVector2Array([Vector2(1454, 521), Vector2(1454, 832)]))
	_trazo(PackedVector2Array([Vector2(1580, 520), Vector2(1580, 832)]))
	_trazo(PackedVector2Array([Vector2(1488, 500), Vector2(1572, 500), Vector2(1534, 488), Vector2(1534, 338), Vector2(1502, 310)]))
	_trazo(PackedVector2Array([Vector2(1476, 286), Vector2(1510, 312), Vector2(1516, 350), Vector2(1444, 316), Vector2(1476, 286)]))
	draw_rect(Rect2(1428, 468, 34, 47), LINEA, false, 3)
	draw_arc(Vector2(1463, 487), 13, -PI / 2, PI / 2, 18, LINEA, 3, true)
	# Planta y libros: pequeñas referencias a la oficina del juego.
	_trazo(PackedVector2Array([Vector2(0, 708), Vector2(200, 708), Vector2(200, 830)]))
	_trazo(PackedVector2Array([Vector2(64, 695), Vector2(54, 642), Vector2(130, 642), Vector2(120, 695), Vector2(64, 695)]), 3)
	_trazo(PackedVector2Array([Vector2(92, 642), Vector2(92, 562)]), 3)
	_trazo(PackedVector2Array([Vector2(92, 610), Vector2(58, 600), Vector2(40, 572), Vector2(68, 573), Vector2(92, 610)]), 3)
	_trazo(PackedVector2Array([Vector2(92, 587), Vector2(117, 548), Vector2(143, 544), Vector2(132, 572), Vector2(92, 587)]), 3)
	for i in 3:
		draw_rect(Rect2(1476 + i * 28, 574 - i * 8, 22, 105 + i * 8), LINEA, false, 3)
	_trazo(PackedVector2Array([Vector2(1460, 684), Vector2(1600, 684)]))


func _cinta() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(140, 42))
	var puntos := PackedVector2Array([Vector2(2, 12), Vector2(134, 1), Vector2(138, 30), Vector2(6, 41), Vector2(2, 12)])
	draw_colored_polygon(puntos, Color("e8d5a3"))
	_trazo(puntos, 2)


func _silueta() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(132, 186))
	var contorno := PackedVector2Array()
	for i in 22:
		var angulo := PI * 2.0 / 3.0 + PI * 5.0 / 3.0 * float(i) / 21.0
		contorno.append(Vector2(66, 52) + Vector2(cos(angulo) * 36, sin(angulo) * 39))
	contorno.append_array(PackedVector2Array([Vector2(84, 99), Vector2(112, 117), Vector2(124, 163), Vector2(8, 163), Vector2(20, 117), Vector2(48, 99), contorno[0]]))
	for i in contorno.size() - 1:
		draw_dashed_line(contorno[i], contorno[i + 1], LINEA, 2, 6, true, true)
