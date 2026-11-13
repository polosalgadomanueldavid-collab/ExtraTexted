extends Control
## Sello de apertura y anuncios breves de eventos con entrada de cómic.

const FUENTE := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const FUENTE_DETALLE := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
const TINTA := Color("172f3b")
const CREMA := Color("fff1d4")
const CORAL := Color("ff745c")
const SELLO := Color("9a3e31")
var _estallido := PackedVector2Array([
	Vector2(-290, 8), Vector2(-165, -14), Vector2(-267, -64),
	Vector2(-119, -46), Vector2(-166, -108), Vector2(-49, -65),
	Vector2(-11, -124), Vector2(36, -70), Vector2(127, -117),
	Vector2(102, -64), Vector2(274, -104), Vector2(195, -30),
	Vector2(300, -40), Vector2(204, 1), Vector2(282, 29),
	Vector2(143, 27), Vector2(225, 80), Vector2(75, 54),
	Vector2(113, 110), Vector2(30, 69), Vector2(-54, 112),
	Vector2(-44, 70), Vector2(-204, 102), Vector2(-150, 44),
	Vector2(-302, 72), Vector2(-169, 15)
])

var tiempo := 0.0
var es_inicio := false
var titulo := ""
var segunda_linea := ""
var detalle := ""
var _duracion := 2.6


func _ready() -> void:
	name = "AnuncioPartida"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 25
	resized.connect(queue_redraw)
	detener()


func mostrar_inicio() -> void:
	es_inicio = true
	titulo = "COMIENZO"
	segunda_linea = "DEL TURNO"
	detalle = ""
	_reproducir(2.6)


func mostrar_evento(primera: String, segunda: String = "", instruccion: String = "") -> void:
	es_inicio = false
	titulo = primera
	segunda_linea = segunda
	detalle = instruccion
	_reproducir(2.8)


func _reproducir(duracion: float) -> void:
	_duracion = duracion
	tiempo = 0.0
	modulate.a = 1.0
	show()
	set_process(true)
	queue_redraw()


func detener() -> void:
	hide()
	set_process(false)


func _process(delta: float) -> void:
	tiempo += delta
	if tiempo >= _duracion:
		detener()
		return
	modulate.a = clampf((_duracion - tiempo) / 0.3, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var factor := minf(size.x / 1280.0, size.y / 720.0)
	if es_inicio:
		_dibujar_sello(factor)
	else:
		_dibujar_comic(factor)
	draw_set_transform(Vector2.ZERO)


func _dibujar_sello(factor: float) -> void:
	var centro := Vector2(size.x * 0.5, size.y * 0.40)
	var entrada := clampf(tiempo / 0.28, 0.0, 1.0)
	var golpe := sin(clampf((tiempo - 0.33) / 0.16, 0.0, 1.0) * PI) * 4.0
	draw_set_transform(centro + Vector2(0, (1.0 - entrada) * 30.0 + golpe) * factor, -0.05, Vector2.ONE * factor)
	_caja(Rect2(-264, -116, 528, 244), Color("172f3b45"), 5.0)
	_caja(Rect2(-264, -126, 528, 244), Color("c9a66b"), 5.0)
	_caja(Rect2(-232, -143, 150, 23), Color("c9a66b"), 5.0)
	draw_set_transform(centro + Vector2(0, (1.0 - entrada) * 30.0 + golpe) * factor, 0.04, Vector2.ONE * factor)
	draw_rect(Rect2(-238, -123, 490, 244), Color("dcc69d"))
	draw_rect(Rect2(-242, -128, 490, 244), Color("f1dfb8"))
	for y: int in range(-97, 106, 23):
		draw_line(Vector2(-240, y), Vector2(246, y), Color("88908550"), 1.0, true)
	draw_line(Vector2(-207, -128), Vector2(-207, 116), Color("c56c5a80"), 2.0, true)
	for y: int in range(-105, 100, 29):
		draw_circle(Vector2(-226, y), 3.0, Color("a38760"), true, -1.0, true)
	if tiempo < 0.12:
		return
	var avance := clampf((tiempo - 0.12) / 0.38, 0.0, 1.0)
	var escala := float(Tween.interpolate_value(0.48, 0.52, avance, 1.0, Tween.TRANS_BACK, Tween.EASE_OUT))
	# La impresión desciende desde cerca de la cámara y queda sobre el expediente.
	escala = 2.0 - escala
	draw_set_transform(centro + Vector2(0, -42.0 * (1.0 - avance)) * factor, lerpf(-0.24, -0.14, avance), Vector2.ONE * factor * escala)
	_caja(Rect2(-204, -83, 408, 151), Color.TRANSPARENT, 8.0, SELLO, 5)
	_caja(Rect2(-196, -75, 392, 135), Color.TRANSPARENT, 3.0, SELLO, 2)
	_texto("COMIENZO", 62, -5, SELLO, false)
	draw_line(Vector2(-174, 7), Vector2(174, 7), SELLO, 2.0, true)
	_texto("DEL TURNO", 44, 49, SELLO, false)
	# Marcas deterministas de tinta gastada, sin ruido que parpadee entre cuadros.
	for i: int in range(90):
		var punto := Vector2(-184 + (i * 71 % 369), -68 + (i * 37 % 121))
		draw_circle(punto, 0.8 + (i % 3) * 0.35, Color("f1dfb8"), true, -1.0, true)


func _dibujar_comic(factor: float) -> void:
	var centro := Vector2(size.x * 0.48, size.y * 0.27)
	var avance := clampf(tiempo / 0.46, 0.0, 1.0)
	var escala := float(Tween.interpolate_value(0.25, 0.75, avance, 1.0, Tween.TRANS_BACK, Tween.EASE_OUT))
	draw_set_transform(centro + Vector2(4, 8) * factor, 0.0, Vector2.ONE * factor * escala)
	draw_colored_polygon(_estallido, TINTA)
	draw_set_transform(centro, 0.0, Vector2.ONE * factor * escala)
	var helado := segunda_linea.contains("HIELO") or segunda_linea.contains("DESCONGELADA") or titulo.contains("FUGA")
	draw_colored_polygon(_estallido, Color("83baff") if helado else Color("ffd078"))
	var deslizamiento := (1.0 - avance) * 70.0
	draw_set_transform(centro + Vector2(-deslizamiento, 0) * factor, -0.08, Vector2.ONE * factor * escala)
	var y := -5.0 if not segunda_linea.is_empty() else 24.0
	_texto(titulo, 64, y, CREMA, true)
	if not segunda_linea.is_empty() and tiempo > 0.12:
		var segundo := clampf((tiempo - 0.12) / 0.46, 0.0, 1.0)
		var rebote := float(Tween.interpolate_value(0.65, 0.35, segundo, 1.0, Tween.TRANS_BACK, Tween.EASE_OUT))
		draw_set_transform(centro + Vector2((1.0 - segundo) * 65.0, 0) * factor, -0.08, Vector2.ONE * factor * rebote)
		_texto(segunda_linea, 60, 51, Color("d8efff") if helado else CORAL, true)
	if not detalle.is_empty() and tiempo > 0.4:
		draw_set_transform(centro, 0.0, Vector2.ONE * factor)
		var ancho := FUENTE_DETALLE.get_string_size(detalle, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		_caja(Rect2(-ancho * 0.5 - 16, 121, ancho + 32, 34), TINTA, 8.0)
		draw_string(FUENTE_DETALLE, Vector2(-ancho * 0.5, 145), detalle, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, CREMA)


func _texto(texto: String, tamano: int, y: float, color: Color, contorno: bool) -> void:
	var ancho := FUENTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
	var ajuste := minf(1.0, 450.0 / maxf(1.0, ancho))
	tamano = roundi(tamano * ajuste)
	ancho = FUENTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
	var posicion := Vector2(-ancho * 0.5, y)
	if contorno:
		draw_string_outline(FUENTE, posicion + Vector2(2, 5), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, 12, TINTA)
		draw_string_outline(FUENTE, posicion, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, 9, TINTA)
	draw_string(FUENTE, posicion, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, color)


func _caja(rectangulo: Rect2, color: Color, radio: float, borde := Color.TRANSPARENT, grosor := 0) -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.border_color = borde
	estilo.set_border_width_all(grosor)
	estilo.set_corner_radius_all(roundi(radio))
	draw_style_box(estilo, rectangulo)
