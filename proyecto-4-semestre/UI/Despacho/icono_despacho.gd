extends Control
## Símbolos vectoriales del HUD. Solo el reloj activo procesa animación.

enum Tipo { ARENA, ALERTA, EVIDENCIAS, VERIFICACION, PRIVACIDAD, REPORTE, BIENESTAR }

@export var tipo: Tipo = Tipo.ARENA
@export var tinta: Color = Color("173b50")
@export var acento: Color = Color("ff785f")
@export var circular: bool = false
@export var informativo: bool = false

var proporcion_restante: float = 0.65
var animado: bool = false
var fase_arena: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	resized.connect(queue_redraw)


func sincronizar_tiempo(restante: float, total: float, activo: bool) -> void:
	# La arena no reinicia al aceptar un caso que ya consumió tiempo en espera.
	var proporcion := clampf(restante / maxf(total, 0.001), 0.0, 1.0)
	var debe_animar := activo and restante > 0.0 and is_visible_in_tree()
	if not is_equal_approx(proporcion_restante, proporcion) or animado != debe_animar:
		proporcion_restante = proporcion
		animado = debe_animar
		queue_redraw()
	set_process(animado)


func _process(delta: float) -> void:
	fase_arena = fmod(fase_arena + delta * 1.6, 1.0)
	queue_redraw()


func _draw() -> void:
	var base := Vector2(40, 56) if tipo == Tipo.ARENA else Vector2(40, 40)
	var factor := minf(size.x / base.x, size.y / base.y)
	draw_set_transform((size - base * factor) * 0.5, 0.0, Vector2.ONE * factor)
	if tipo == Tipo.ARENA:
		_dibujar_arena()
		return
	draw_set_transform((size - Vector2(40, 40) * factor) * 0.5, 0.0, Vector2.ONE * factor)
	match tipo:
		Tipo.ALERTA:
			_dibujar_alerta()
		Tipo.VERIFICACION:
			draw_arc(Vector2(16, 16), 12, 0, TAU, 40, tinta, 3.8, true)
			draw_line(Vector2(25, 25), Vector2(36, 37), tinta, 4.5, true)
		Tipo.EVIDENCIAS:
			_linea([Vector2(3, 11), Vector2(3, 33), Vector2(37, 33), Vector2(37, 13), Vector2(19, 13), Vector2(15, 8), Vector2(3, 8), Vector2(3, 11)], tinta, 3)
		Tipo.PRIVACIDAD:
			draw_arc(Vector2(20, 16), 10, PI, TAU, 24, tinta, 3.5, true)
			draw_style_box(_caja_cerradura(), Rect2(6, 16, 28, 21))
			draw_circle(Vector2(20, 25), 3, Color("fff1d8"))
			draw_line(Vector2(20, 25), Vector2(20, 31), Color("fff1d8"), 2.5, true)
		Tipo.REPORTE:
			_linea([Vector2(8, 3), Vector2(27, 3), Vector2(34, 10), Vector2(34, 37), Vector2(8, 37), Vector2(8, 3)], tinta, 3)
			for y: int in [15, 23, 31]:
				draw_line(Vector2(14, y), Vector2(28, y), tinta, 2.5, true)
		Tipo.BIENESTAR:
			_linea([Vector2(20, 35), Vector2(5, 21), Vector2(4, 13), Vector2(9, 7), Vector2(16, 7), Vector2(20, 12), Vector2(24, 7), Vector2(31, 7), Vector2(36, 13), Vector2(35, 21), Vector2(20, 35)], tinta, 3)


func _dibujar_arena() -> void:
	# Volumen superior proporcional al tiempo; el inferior acumula la arena caída.
	var altura := 18.0 * sqrt(proporcion_restante)
	if altura > 0.05:
		draw_colored_polygon(PackedVector2Array([Vector2(20 - altura * 0.56, 27 - altura), Vector2(20 + altura * 0.56, 27 - altura), Vector2(20, 27)]), tinta)
	var altura_acumulada := 17.0 * (1.0 - proporcion_restante)
	if altura_acumulada > 0.05:
		draw_colored_polygon(PackedVector2Array([Vector2(9, 47), Vector2(31, 47), Vector2(20, 47 - altura_acumulada)]), tinta)
	if animado:
		for grano: int in range(3):
			var avance := fmod(fase_arena + float(grano) / 3.0, 1.0)
			draw_circle(Vector2(20, lerpf(28.0, 46.0 - altura_acumulada, avance)), 0.9, tinta)
	_linea([Vector2(8, 8), Vector2(8, 14), Vector2(19, 27), Vector2(19, 29), Vector2(8, 42), Vector2(8, 48)], tinta, 2.8)
	_linea([Vector2(32, 8), Vector2(32, 14), Vector2(21, 27), Vector2(21, 29), Vector2(32, 42), Vector2(32, 48)], tinta, 2.8)
	draw_line(Vector2(5, 5), Vector2(35, 5), tinta, 5, true)
	draw_line(Vector2(5, 51), Vector2(35, 51), tinta, 5, true)


func _dibujar_alerta() -> void:
	var crema := Color("fff1d8")
	if circular or informativo:
		draw_circle(Vector2(20, 20), 19, acento)
	if informativo:
		draw_circle(Vector2(20, 10), 2, crema)
		draw_line(Vector2(20, 17), Vector2(20, 30), crema, 4, true)
		return
	var triangulo := PackedVector2Array([Vector2(20, 6), Vector2(36, 33), Vector2(4, 33)])
	draw_colored_polygon(triangulo, crema if circular else acento)
	var color_signo := acento if circular else crema
	draw_line(Vector2(20, 15), Vector2(20, 23), color_signo, 3.2, true)
	draw_circle(Vector2(20, 28), 1.8, color_signo)


func _linea(puntos: Array[Vector2], color: Color, ancho: float) -> void:
	draw_polyline(PackedVector2Array(puntos), color, ancho, true)


func _caja_cerradura() -> StyleBoxFlat:
	var caja := StyleBoxFlat.new()
	caja.bg_color = tinta
	caja.set_corner_radius_all(3)
	return caja
