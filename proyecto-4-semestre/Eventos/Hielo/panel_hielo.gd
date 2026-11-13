extends Control

const TITULO := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const TEXTO := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
var proxima := 4.0
var congelado := false
var descongelando := false
var entrada := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	hide()


func _ajustar() -> void:
	var pantalla := get_viewport_rect().size
	var factor := minf(pantalla.x / 1920.0, pantalla.y / 1080.0)
	size = Vector2(610, 144)
	scale = Vector2.ONE * factor
	position = Vector2(pantalla.x * 0.5 - 305 * factor, 18 * factor)
	queue_redraw()


func actualizar(segundos: float, helado: bool, derritiendo: bool, iniciando: bool) -> void:
	proxima = segundos
	congelado = helado
	descongelando = derritiendo
	entrada = iniciando
	queue_redraw()


func _draw() -> void:
	var caja := StyleBoxFlat.new()
	caja.bg_color = Color("142b50")
	caja.border_color = Color("a6d3ff")
	caja.set_border_width_all(2)
	caja.set_corner_radius_all(18)
	draw_style_box(caja, Rect2(Vector2.ZERO, size))
	# Copo de seis puntas, el mismo lenguaje del cristal alrededor del jugador.
	for i in 6:
		var d := Vector2.from_angle(i * TAU / 6.0)
		var p := Vector2(37, 36)
		draw_line(p, p + d * 20, Color("bfe7ff"), 3, true)
		for signo: float in [-1.0, 1.0]:
			draw_line(p + d * 12, p + d * 7 + d.orthogonal() * signo * 6, Color("bfe7ff"), 2, true)
	draw_string(TITULO, Vector2(72, 46), "¡HIELO!", HORIZONTAL_ALIGNMENT_LEFT, -1, 33, Color("e8f5ff"))
	var estado := "Te congelas en %.1f s" % proxima
	if congelado:
		estado = "CONGELADO · %.1f s" % proxima
	if descongelando:
		estado = "Descongelando…"
	draw_string(TEXTO, Vector2(300, 43), estado, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("bfe7ff"))
	var detalle := "La inercia continúa. Las tareas siguen disponibles." if congelado else "¡Cuidado al frenar! El piso resbala mucho."
	if entrada:
		detalle = "Una fuga de nitrógeno está congelando la oficina…"
	elif descongelando:
		detalle = "Fuga sellada. El hielo y la nieve se están retirando."
	draw_string(TEXTO, Vector2(24, 79), detalle, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("e8f5ff"))
	draw_string(TEXTO, Vector2(24, 109), "E · Repara el nitrógeno en la zona de descanso", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("a6d3ff"))
	draw_line(Vector2(24, 128), Vector2(586, 128), Color("304d77"), 6, true)
	if not descongelando:
		draw_line(Vector2(24, 128), Vector2(24 + 562 * clampf(proxima / (1.25 if congelado else 4.0), 0, 1), 128), Color("e8f5ff") if congelado else Color("83baff"), 6, true)
