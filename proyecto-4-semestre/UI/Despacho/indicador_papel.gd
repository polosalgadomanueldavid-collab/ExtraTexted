extends Control
## Medallón aprobado, a escala 1:1 en 1280×720. No captura clics ni la tecla E.

const PAPEL := preload("res://UI/Despacho/Arte/papel_medallon.png")
const FUENTE := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const TINTA := Color("173b50")
const CREMA := Color("fff1d8")
const CORAL := Color("ff785f")
const TAMANO := Vector2(140, 158)
const REFERENCIA := Vector2(1280, 720)
const MARGEN := 24.0

var rotulo: Label
var _fondo_leyenda: StyleBoxFlat
var _sombra_leyenda: StyleBoxFlat


func _ready() -> void:
	name = "IndicadorPapel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	size = TAMANO
	hide()
	_fondo_leyenda = StyleBoxFlat.new()
	_fondo_leyenda.bg_color = TINTA
	_fondo_leyenda.border_color = CREMA
	_fondo_leyenda.set_border_width_all(2)
	_fondo_leyenda.set_corner_radius_all(12)
	_sombra_leyenda = StyleBoxFlat.new()
	_sombra_leyenda.bg_color = Color("0d27369c")
	_sombra_leyenda.set_corner_radius_all(12)
	rotulo = Label.new()
	rotulo.name = "LeyendaSoltar"
	rotulo.text = "E - soltar"
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo.position = Vector2(5, 115)
	rotulo.size = Vector2(130, 34)
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var fuente := FontVariation.new()
	fuente.base_font = FUENTE
	fuente.baseline_offset = 0.14
	rotulo.add_theme_font_override("font", fuente)
	rotulo.add_theme_font_size_override("font_size", 20)
	rotulo.add_theme_color_override("font_color", CREMA)
	add_child(rotulo)


func ajustar_pantalla(tamano_pantalla: Vector2) -> void:
	var factor := minf(tamano_pantalla.x / REFERENCIA.x, tamano_pantalla.y / REFERENCIA.y)
	scale = Vector2.ONE * factor
	position = Vector2(MARGEN * factor, tamano_pantalla.y - (MARGEN + TAMANO.y) * factor)


func _draw() -> void:
	draw_circle(Vector2(70, 67), 51, Color("0d2736b3"), true, -1.0, true)
	draw_circle(Vector2(70, 61), 51, TINTA, true, -1.0, true)
	draw_circle(Vector2(70, 61), 47, CORAL, true, -1.0, true)
	draw_circle(Vector2(70, 58), 44, CREMA, true, -1.0, true)
	draw_circle(Vector2(70, 60), 37, Color("eddec5"), true, -1.0, true)
	draw_arc(Vector2(70, 58), 42, PI * 1.10, PI * 1.72, 48, Color("fff9ee"), 2.5, true)
	draw_texture_rect(PAPEL, Rect2(24, 12, 92, 92), false)
	draw_style_box(_sombra_leyenda, Rect2(5, 119, 130, 34))
	draw_style_box(_fondo_leyenda, Rect2(5, 115, 130, 34))
