extends Control
## Cronómetro compacto con la cuenta regresiva del evento.

const FUENTE := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const DIMENSIONES := Vector2(168, 190)
const CENTRO := Vector2(84, 104)
const TAMANO_NUMEROS := 36
const TINTA := Color("251a17")
const ESFERA := Color("2e2320")
const MARCAS := Color("fff1d8")
const AMBAR := Color("ffb34f")
const URGENTE := Color("ff7258")

var restante := 60.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	hide()


func _ajustar() -> void:
	var pantalla := get_viewport().get_visible_rect().size
	var factor := minf(pantalla.x / 1920.0, pantalla.y / 1080.0)
	size = DIMENSIONES
	scale = Vector2.ONE * factor
	position = Vector2((pantalla.x - size.x * factor) * 0.5, 18.0 * factor)
	queue_redraw()


func actualizar(segundos: float) -> void:
	var anterior := ceili(restante)
	restante = maxf(0.0, segundos)
	if ceili(restante) != anterior:
		queue_redraw()


func _draw() -> void:
	var segundos := ceili(maxf(0.0, restante))
	var acento := AMBAR if segundos > 10 else URGENTE
	# Pulsadores y cuello: la silueta del cronómetro sustituye al panel rectangular.
	draw_rect(Rect2(77, 16, 14, 20), TINTA)
	draw_style_box(_pulsador(acento), Rect2(64, 1, 40, 20))
	draw_set_transform(Vector2(140, 39), PI * 0.25)
	draw_style_box(_pulsador(acento), Rect2(-13, -7, 26, 14))
	draw_set_transform(Vector2.ZERO)
	# Contorno con sombra corta y esfera opaca para leer sobre el magma.
	draw_circle(CENTRO + Vector2(0, 7), 75.0, Color(0.0, 0.0, 0.0, 0.22), true, -1.0, true)
	draw_circle(CENTRO + Vector2(0, 4), 75.0, TINTA, true, -1.0, true)
	draw_circle(CENTRO, 75.0, TINTA, true, -1.0, true)
	draw_circle(CENTRO, 71.0, acento, true, -1.0, true)
	draw_circle(CENTRO, 62.0, ESFERA, true, -1.0, true)
	for direccion: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(CENTRO + direccion * 51.0, CENTRO + direccion * 57.0, MARCAS, 3.0, true)
	# Tipografía del diseño Digital, reducida y centrada dentro de la esfera.
	var cuenta := "%02d:%02d" % [segundos / 60, segundos % 60]
	var ancho := FUENTE.get_string_size(cuenta, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANO_NUMEROS).x
	var base := (FUENTE.get_ascent(TAMANO_NUMEROS) - FUENTE.get_descent(TAMANO_NUMEROS)) * 0.5
	var origen := CENTRO + Vector2(-ancho * 0.5, base)
	draw_string_outline(FUENTE, origen + Vector2(0, 2), cuenta, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANO_NUMEROS, 5, TINTA)
	draw_string_outline(FUENTE, origen, cuenta, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANO_NUMEROS, 3, TINTA)
	draw_string(FUENTE, origen, cuenta, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANO_NUMEROS, acento)


func _pulsador(color: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.border_color = TINTA
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(4)
	return estilo
