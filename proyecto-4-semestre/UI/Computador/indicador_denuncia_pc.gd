extends Control
## Sobre urgente anclado al monitor, con la tecla E encima.

const FUENTE := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const TINTA := Color("172f3b")
const CREMA := Color("fff1d4")
const CORAL := Color("ff8266")
const AMARILLO := Color("ffdc78")

var pendientes: Array[String] = []
var puede_recoger := false
var interactuable := false
var tiempo_llegada := 1.0
var ancla_pantalla := Vector2.ZERO


func _ready() -> void:
	name = "IndicadorDenunciaPC"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()


func establecer_denuncias(denuncias: Array[Denuncia]) -> void:
	var nuevos: Array[String] = []
	for denuncia: Denuncia in denuncias:
		if denuncia.estado == Denuncia.Estado.PENDIENTE:
			nuevos.append(denuncia.id)
			if not pendientes.has(denuncia.id):
				tiempo_llegada = 0.0
	pendientes = nuevos
	if pendientes.is_empty():
		hide()


func actualizar(camara: Camera3D, ancla: Vector3, disponible: bool, cerca: bool, oculto: bool) -> void:
	puede_recoger = disponible
	interactuable = cerca and disponible
	visible = not pendientes.is_empty() and not oculto and is_instance_valid(camara) and not camara.is_position_behind(ancla)
	if not visible:
		return
	ancla_pantalla = camara.unproject_position(ancla)
	# Un marcador fuera de cámara no debe parecer anclado a otro objeto en el borde.
	visible = get_viewport_rect().has_point(ancla_pantalla)
	queue_redraw()


func _process(delta: float) -> void:
	tiempo_llegada = minf(tiempo_llegada + delta, 1.0)


func _draw() -> void:
	var factor := minf(size.x / 1280.0, size.y / 720.0)
	var ancla := ancla_pantalla
	draw_set_transform(ancla, 0.0, Vector2.ONE * factor)
	var avance := clampf(tiempo_llegada / 0.55, 0.0, 1.0)
	var rebote := float(Tween.interpolate_value(0.45, 0.55, avance, 1.0, Tween.TRANS_BACK, Tween.EASE_OUT))
	# El sobre y el contador comunican la cola sin una frase flotante.
	var etiqueta := str(pendientes.size())
	var ancho := 36.0
	_caja(Rect2(-18, -39, ancho, 27), CREMA, TINTA)
	_texto(etiqueta, Vector2(-18, -19), 19, TINTA, ancho)
	draw_colored_polygon(PackedVector2Array([Vector2(-7, -6), Vector2(7, -6), Vector2(0, 3)]), CORAL)
	var desplazamiento := Vector2(0, -61.0)
	draw_set_transform(ancla + desplazamiento * factor, -0.12, Vector2.ONE * factor * rebote)
	_caja(Rect2(-26, -16, 52, 34), CORAL, TINTA)
	draw_polyline(PackedVector2Array([Vector2(-24, -14), Vector2(0, 5), Vector2(24, -14)]), TINTA, 2.5, true)
	draw_circle(Vector2(25, -15), 10, TINTA, true, -1.0, true)
	draw_circle(Vector2(25, -15), 8, CREMA, true, -1.0, true)
	_texto("!", Vector2(15, -9), 17, TINTA, 20)
	draw_set_transform(ancla, 0.0, Vector2.ONE * factor)
	if interactuable:
		var tecla := Rect2(-20, -127, 40, 36)
		_caja(tecla.grow(3), CREMA, TINTA)
		_caja(tecla, AMARILLO, TINTA)
		_texto("X" if ControladorInterfaz.dispositivo_mando >= 0 else "E", Vector2(-20, -100), 28, TINTA, 40)
	draw_set_transform(Vector2.ZERO)


func _texto(texto: String, posicion: Vector2, tamano: int, color: Color, ancho: float) -> void:
	draw_string(FUENTE, posicion, texto, HORIZONTAL_ALIGNMENT_CENTER, ancho, tamano, color)


func _caja(rectangulo: Rect2, color: Color, borde: Color) -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.border_color = borde
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(6)
	draw_style_box(estilo, rectangulo)
