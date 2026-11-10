extends PanelContainer

const FUENTE := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
var _titulo: Label
var _detalle: Label
var _barra: ProgressBar

func _ready() -> void:
	name = "AvisoDescanso"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color("173b50f0")
	fondo.border_color = Color("79d693")
	fondo.border_width_left = 4
	fondo.set_corner_radius_all(10)
	fondo.content_margin_left = 16
	fondo.content_margin_right = 16
	fondo.content_margin_top = 12
	fondo.content_margin_bottom = 12
	add_theme_stylebox_override("panel", fondo)
	var columna := VBoxContainer.new()
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columna.add_theme_constant_override("separation", 6)
	add_child(columna)
	_titulo = Label.new()
	_titulo.add_theme_font_override("font", FUENTE)
	_titulo.add_theme_font_size_override("font_size", 20)
	_titulo.add_theme_color_override("font_color", Color("fff1d8"))
	columna.add_child(_titulo)
	_detalle = Label.new()
	_detalle.add_theme_font_size_override("font_size", 16)
	_detalle.add_theme_color_override("font_color", Color("dce9df"))
	columna.add_child(_detalle)
	_barra = ProgressBar.new()
	_barra.custom_minimum_size.y = 6
	_barra.max_value = 1.0
	_barra.show_percentage = false
	var vacio := StyleBoxFlat.new()
	vacio.bg_color = Color("0b2634")
	vacio.set_corner_radius_all(3)
	var lleno := StyleBoxFlat.new()
	lleno.bg_color = Color("36dec8")
	lleno.set_corner_radius_all(3)
	_barra.add_theme_stylebox_override("background", vacio)
	_barra.add_theme_stylebox_override("fill", lleno)
	columna.add_child(_barra)
	hide()

func presentar(titulo: String, detalle: String, progreso: float = -1.0, desplazamiento: Vector2 = Vector2.ZERO) -> void:
	_titulo.text = titulo
	_detalle.text = detalle
	_barra.visible = progreso >= 0.0
	_barra.value = clampf(progreso, 0.0, 1.0)
	var pantalla := get_viewport().get_visible_rect().size
	var factor := maxf(0.1, minf(pantalla.x / 1280.0, pantalla.y / 720.0))
	scale = Vector2.ONE * factor
	size = Vector2(450, 0)
	position = Vector2(24, pantalla.y / factor - 116) * factor + desplazamiento * factor
	show()
