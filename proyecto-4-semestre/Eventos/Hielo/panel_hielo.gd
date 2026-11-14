extends Control
## Copo sin panel ni texto: seis cristales muestran el tiempo de la fase actual.

const DIMENSIONES := Vector2(96, 96)
const CENTRO := DIMENSIONES * 0.5
const AZUL := Color("8bdcff")
const HELADO := Color("f2fcff")
const APAGADO := Color(0.55, 0.86, 1.0, 0.18)
const SOMBRA := Color(0.03, 0.10, 0.16, 0.45)
var progreso := 1.0
var congelado := false
var descongelando := false
var _halo: GradientTexture2D
var _cristal := PackedVector2Array([
	Vector2(0, -8), Vector2(4.5, 0), Vector2(0, 8), Vector2(-4.5, 0),
])


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradiente := Gradient.new()
	gradiente.colors = PackedColorArray([Color(AZUL, 0.30), Color(AZUL, 0.0)])
	_halo = GradientTexture2D.new()
	_halo.gradient = gradiente
	_halo.width = 128
	_halo.height = 128
	_halo.fill = GradientTexture2D.FILL_RADIAL
	_halo.fill_from = Vector2(0.5, 0.5)
	_halo.fill_to = Vector2(1.0, 0.5)
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	hide()


func _ajustar() -> void:
	var pantalla := get_viewport_rect().size
	var factor := minf(pantalla.x / 1920.0, pantalla.y / 1080.0)
	size = DIMENSIONES
	scale = Vector2.ONE * factor
	position = Vector2((pantalla.x - size.x * factor) * 0.5, 24 * factor)
	queue_redraw()


func actualizar(segundos: float, helado: bool, derritiendo: bool, duracion: float) -> void:
	progreso = clampf(segundos / maxf(duracion, 0.001), 0.0, 1.0)
	congelado = helado
	descongelando = derritiendo
	queue_redraw()


func _draw() -> void:
	if descongelando:
		return
	var color := HELADO if congelado else AZUL
	var grosor := 3.8 if congelado else 3.0
	draw_texture_rect(_halo, Rect2(CENTRO - Vector2(64, 64), Vector2(128, 128)), false,
		Color(1, 1, 1, 1.0 if congelado else 0.35))
	# El último cristal se vacía primero; la corona vuelve a llenarse al cambiar de fase.
	for i in 6:
		var angulo := -PI * 0.5 + i * TAU / 6.0
		var centro := CENTRO + Vector2.from_angle(angulo) * 39.0
		_dibujar_cristal(centro, angulo + PI * 0.5, clampf(progreso * 6.0 - i, 0.0, 1.0), color)
	_dibujar_copo(CENTRO + Vector2(0, 2), SOMBRA, grosor + 2.5)
	_dibujar_copo(CENTRO, color, grosor)


func _dibujar_copo(centro: Vector2, color: Color, grosor: float) -> void:
	for i in 6:
		var d := Vector2.from_angle(-PI * 0.5 + i * TAU / 6.0)
		var punta := centro + d * 21.0
		draw_line(centro, punta, color, grosor, true)
		draw_circle(punta, grosor * 0.5, color, true, -1.0, true)
		for signo: float in [-1.0, 1.0]:
			var rama := centro + d * 17.0 + d.orthogonal() * signo * 5.5
			draw_line(centro + d * 11.0, rama, color, grosor, true)
			draw_circle(rama, grosor * 0.5, color, true, -1.0, true)
	draw_circle(centro, grosor * 0.5, color, true, -1.0, true)


func _dibujar_cristal(centro: Vector2, angulo: float, carga: float, color: Color) -> void:
	draw_set_transform(centro + Vector2(0, 2), angulo)
	draw_colored_polygon(_cristal, SOMBRA)
	draw_set_transform(centro, angulo)
	draw_colored_polygon(_cristal, APAGADO)
	if carga >= 1.0:
		draw_colored_polygon(_cristal, color)
	elif carga > 0.0:
		# Recorta el rombo desde su punta exterior para mostrar también fracciones de tiempo.
		var corte := 8.0 - 16.0 * carga
		var ancho := 4.5 * (1.0 - absf(corte) / 8.0)
		var relleno := PackedVector2Array([Vector2(-ancho, corte), Vector2(ancho, corte)])
		if corte < 0.0:
			relleno.append(Vector2(4.5, 0))
		relleno.append(Vector2(0, 8))
		if corte < 0.0:
			relleno.append(Vector2(-4.5, 0))
		draw_colored_polygon(relleno, color)
	draw_set_transform(Vector2.ZERO)
