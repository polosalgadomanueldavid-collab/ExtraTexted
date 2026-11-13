extends Control

const FUENTE := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const DETALLE := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
const TINTA := Color("173b50")
const CREMA := Color("fff1d8")
const CORAL := Color("ff785f")
var progreso := 0.0
var completadas := 0
var total := 0
var instruccion := "Busca el extintor en la zona de descanso"
var nombre_mesa := ""
var progreso_mesa := 0.0
var apagando_mesa := false
var estado_cordura := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	hide()


func _draw() -> void:
	var factor := minf(size.x / 1280.0, size.y / 720.0)
	# Entre la calma del jugador (izquierda) y las denuncias (derecha).
	draw_set_transform(Vector2(size.x * 0.48, 24.0 * factor), 0.0, Vector2.ONE * factor)
	_caja(Rect2(-214, 7, 428, 78), TINTA, TINTA, 25)
	_caja(Rect2(-214, 0, 428, 78), CREMA, TINTA, 25)
	_dibujar_llama(Vector2(-183, 34))
	draw_string(FUENTE, Vector2(-151, 31), "INCENDIO", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, TINTA)
	var porcentaje := "%d%%" % floori(progreso * 100.0)
	var ancho_porcentaje := FUENTE.get_string_size(porcentaje, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_string(FUENTE, Vector2(193 - ancho_porcentaje, 35), porcentaje, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, TINTA)
	_caja(Rect2(-150, 47, 336, 10), Color("d7d0b9"), Color.TRANSPARENT, 5, 0)
	if progreso > 0.0:
		_caja(Rect2(-150, 47, 336 * clampf(progreso, 0.0, 1.0), 10), CORAL, Color.TRANSPARENT, 5, 0)
	var cuenta := "%d de %d mesas" % [completadas, total]
	var ancho_cuenta := DETALLE.get_string_size(cuenta, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	var origen_cuenta := Vector2(-ancho_cuenta * 0.5, 110)
	draw_string_outline(DETALLE, origen_cuenta, cuenta, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, 5, TINTA)
	draw_string(DETALLE, origen_cuenta, cuenta, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, CREMA)
	if not estado_cordura.is_empty():
		var ancho_estado := DETALLE.get_string_size(estado_cordura, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		var origen_estado := Vector2(-ancho_estado * 0.5, 135)
		draw_string_outline(DETALLE, origen_estado, estado_cordura, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, TINTA)
		draw_string(DETALLE, origen_estado, estado_cordura, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, CREMA)
	if not nombre_mesa.is_empty():
		draw_set_transform(Vector2(size.x * 0.5, size.y - 86.0 * factor), 0.0, Vector2.ONE * factor)
		_dibujar_arco_mesa(factor)
	draw_set_transform(Vector2.ZERO)


func _dibujar_arco_mesa(factor: float) -> void:
	const RADIO := 43.0
	const GROSOR := 3.0
	const INICIO := PI * 0.75
	const RECORRIDO := PI * 1.5
	var avance := clampf(progreso_mesa, 0.0, 1.0)
	# El cuarto inferior queda abierto para el porcentaje; sin placa de fondo.
	draw_arc(Vector2.ZERO, RADIO, INICIO, INICIO + RECORRIDO, 96, Color(CREMA, 0.18), GROSOR, true)
	if avance > 0.0:
		var fin := INICIO + RECORRIDO * avance
		var color := Color("86efac") if avance >= 1.0 else CORAL
		draw_arc(Vector2.ZERO, RADIO, INICIO, fin, maxi(2, ceili(96 * avance)), color, GROSOR, true)
		# Extremos redondos del propio trazo de progreso.
		draw_circle(Vector2.from_angle(INICIO) * RADIO, GROSOR * 0.5, color, true, -1.0, true)
		draw_circle(Vector2.from_angle(fin) * RADIO, GROSOR * 0.5, color, true, -1.0, true)
	_dibujar_mesa()
	var porcentaje := "%d%%" % floori(avance * 100.0)
	var ancho := DETALLE.get_string_size(porcentaje, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var posicion := Vector2(-ancho * 0.5, 36)
	draw_string_outline(DETALLE, posicion, porcentaje, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, TINTA)
	draw_string(DETALLE, posicion, porcentaje, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, CREMA)
	var pista := "Apagando…" if apagando_mesa else "Mantén para apagar"
	var tamano_pista := maxi(13, ceili(11.0 / maxf(0.001, factor)))
	var ancho_pista := DETALLE.get_string_size(pista, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano_pista).x
	var izquierda := -(ancho_pista + 30.0) * 0.5
	_caja(Rect2(izquierda, 47, 22, 22), Color(TINTA, 0.7), Color(CREMA, 0.45), 5, 1)
	draw_string(FUENTE, Vector2(izquierda + 6, 63), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, CREMA)
	draw_string_outline(DETALLE, Vector2(izquierda + 30, 63), pista, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano_pista, 3, TINTA)
	draw_string(DETALLE, Vector2(izquierda + 30, 63), pista, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano_pista, Color(CREMA, 0.87))


func _dibujar_mesa() -> void:
	# Mesa procedural con tablero, dos patas y cajón, como el diseño aprobado.
	_caja(Rect2(-20, -8, 5, 25), TINTA, Color.TRANSPARENT, 1, 0)
	_caja(Rect2(17, -11, 5, 25), TINTA, Color.TRANSPARENT, 1, 0)
	_caja(Rect2(-19, -10, 4, 25), CREMA, Color.TRANSPARENT, 1, 0)
	_caja(Rect2(17, -13, 4, 25), CREMA, Color.TRANSPARENT, 1, 0)
	_caja(Rect2(4, -10, 14, 13), Color("cf9a60"), Color.TRANSPARENT, 1, 0)
	_caja(Rect2(8, -5, 6, 2), CREMA, Color.TRANSPARENT, 1, 0)
	draw_colored_polygon(PackedVector2Array([Vector2(-24, -15), Vector2(20, -18), Vector2(25, -11), Vector2(25, -6), Vector2(-20, -3), Vector2(-24, -8)]), TINTA)
	draw_colored_polygon(PackedVector2Array([Vector2(-23, -14), Vector2(20, -17), Vector2(24, -11), Vector2(-19, -8)]), CREMA)
	draw_colored_polygon(PackedVector2Array([Vector2(-19, -8), Vector2(24, -11), Vector2(24, -7), Vector2(-19, -4)]), Color("bf8850"))


func _dibujar_llama(centro: Vector2) -> void:
	var contorno := PackedVector2Array([Vector2(-9, 16), Vector2(-15, 6), Vector2(-13, -4), Vector2(-7, -14), Vector2(-5, -3), Vector2(3, -24), Vector2(7, -13), Vector2(15, 1), Vector2(14, 12), Vector2(6, 17)])
	var interior := PackedVector2Array([Vector2(-4, 16), Vector2(-8, 7), Vector2(0, -5), Vector2(2, 5), Vector2(7, 10), Vector2(4, 17)])
	for i in contorno.size():
		contorno[i] += centro
	for i in interior.size():
		interior[i] += centro
	draw_colored_polygon(contorno, CORAL)
	draw_colored_polygon(interior, Color("ffce67"))


func _caja(rectangulo: Rect2, color: Color, borde := Color.TRANSPARENT, radio := 8, grosor := 2) -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.border_color = borde
	estilo.set_border_width_all(grosor)
	estilo.set_corner_radius_all(radio)
	draw_style_box(estilo, rectangulo)
