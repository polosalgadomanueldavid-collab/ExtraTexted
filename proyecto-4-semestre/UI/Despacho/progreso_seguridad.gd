extends Control
## Barra sobre la mesa de seguridad y estado breve en el borde inferior.

const FUENTE := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const TINTA := Color("173b50")
const CREMA := Color("fff1d8")
const CORAL := Color("ff785f")

var proporcion: float = 0.0
var ancla_pantalla := Vector2.ZERO
var barra_visible: bool = false
var listo_para_recoger: bool = false


func _ready() -> void:
	name = "ProgresoSeguridad"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func actualizar(valor: float, camara: Camera3D, ancla_mundo: Vector3) -> void:
	proporcion = clampf(valor, 0.0, 1.0)
	barra_visible = is_instance_valid(camara) and not camara.is_position_behind(ancla_mundo)
	if barra_visible:
		ancla_pantalla = camara.unproject_position(ancla_mundo)
	queue_redraw()


func _draw() -> void:
	var factor := minf(size.x / 1280.0, size.y / 720.0)
	if barra_visible:
		var ancho := 188.0 * factor
		var alto := 20.0 * factor
		var margen := 24.0 * factor
		var x := clampf(ancla_pantalla.x - ancho * 0.5, margen, maxf(margen, size.x - ancho - margen))
		var y := clampf(ancla_pantalla.y - 44.0 * factor, margen, size.y - 112.0 * factor)
		var base := Rect2(x, y, ancho, alto)
		_dibujar_pista(base.grow(3.0 * factor), TINTA)
		_dibujar_pista(base, CREMA)
		var relleno := Rect2(base.position + Vector2.ONE * 3.0 * factor, Vector2(maxf(0.0, ancho - 6.0 * factor) * proporcion, alto - 6.0 * factor))
		if relleno.size.x > 0.0:
			_dibujar_pista(relleno, CORAL)
	var texto := "LISTO · VUELVE A SEGURIDAD" if listo_para_recoger else "DESENCRIPTANDO"
	var tamano := maxi(10, roundi(21.0 * factor))
	var ancho_texto := FUENTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
	var ancho_fondo := ancho_texto + 36.0 * factor
	var fondo := Rect2((size.x - ancho_fondo) * 0.5, size.y - 73.0 * factor, ancho_fondo, 51.0 * factor)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = TINTA
	estilo.border_color = CORAL
	estilo.border_width_left = maxi(2, roundi(3.0 * factor))
	estilo.set_corner_radius_all(maxi(4, roundi(10.0 * factor)))
	draw_style_box(estilo, fondo)
	draw_string(FUENTE, Vector2((size.x - ancho_texto) * 0.5, fondo.position.y + 27.0 * factor), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, CREMA)
	var pista := Rect2(fondo.position + Vector2(12.0, 36.0) * factor, Vector2(fondo.size.x - 24.0 * factor, 6.0 * factor))
	_dibujar_pista(pista, CREMA.darkened(0.55))
	if proporcion > 0.0:
		_dibujar_pista(Rect2(pista.position, Vector2(pista.size.x * proporcion, pista.size.y)), CORAL)


func _dibujar_pista(rectangulo: Rect2, color: Color) -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.set_corner_radius_all(maxi(1, roundi(minf(rectangulo.size.x, rectangulo.size.y) * 0.5)))
	draw_style_box(estilo, rectangulo)
