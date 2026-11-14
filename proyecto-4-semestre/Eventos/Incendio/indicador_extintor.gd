extends Control
## Propuesta C: icono libre, halo abierto, puntero y distancia hasta el extintor.

const FUENTE := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const DETALLE := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
const TINTA := Color("173b50")
const CREMA := Color("fff1d8")
const CORAL := Color("ff785f")
const ORO := Color("ffce67")

var distancia := 0.0
var rotulo := "EXTINTOR"
var interactuable := false
var fuera_de_pantalla := false
var ancla := Vector2.ZERO
var direccion := Vector2.DOWN
var _tiempo := 0.0


func _ready() -> void:
	name = "IndicadorExtintor"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()


func actualizar(camara: Camera3D, posicion: Vector3, posicion_jugador: Vector3, cerca: bool, disponible: bool) -> void:
	visible = disponible and is_instance_valid(camara)
	if not visible:
		return
	distancia = Vector2(posicion.x - posicion_jugador.x, posicion.z - posicion_jugador.z).length()
	interactuable = cerca
	var pantalla := get_viewport_rect().size
	var factor := minf(pantalla.x / 1280.0, pantalla.y / 720.0)
	# La franja derecha pertenece a las denuncias; deja libre la barra superior.
	var region := Rect2(Vector2(76, 224) * factor, Vector2(maxf(1.0, pantalla.x - 466 * factor), maxf(1.0, pantalla.y - 356 * factor)))
	var detras := camara.is_position_behind(posicion)
	var proyectada := camara.unproject_position(posicion)
	fuera_de_pantalla = detras or not region.has_point(proyectada)
	if fuera_de_pantalla:
		var centro := region.get_center()
		if detras:
			var local := camara.to_local(posicion)
			direccion = Vector2(local.x, -local.y)
		else:
			direccion = proyectada - centro
		if direccion.length_squared() < 0.001:
			direccion = Vector2.DOWN
		direccion = direccion.normalized()
		var mitad := region.size * 0.5
		var avance := minf(mitad.x / maxf(0.001, absf(direccion.x)), mitad.y / maxf(0.001, absf(direccion.y)))
		ancla = centro + direccion * avance
	else:
		ancla = proyectada
	queue_redraw()


func _process(delta: float) -> void:
	if visible:
		_tiempo += delta
		queue_redraw()


func _draw() -> void:
	var pantalla := get_viewport_rect().size
	var factor := minf(pantalla.x / 1280.0, pantalla.y / 720.0)
	var escala := factor * lerpf(1.0, 0.78, smoothstep(2.0, 9.0, distancia))
	var flotacion := Vector2.UP * sin(_tiempo * 2.2) * 3.0 * factor
	draw_set_transform(ancla + flotacion, 0.0, Vector2.ONE * escala)
	draw_circle(Vector2.ZERO, 48, Color(CORAL, 0.08), true, -1.0, true)
	var giro := sin(_tiempo * 1.4) * 0.10
	draw_arc(Vector2.ZERO, 45, 0.2 + giro, 2.5 + giro, 40, CORAL, 3.0, true)
	draw_arc(Vector2.ZERO, 45, 3.4 + giro, 5.6 + giro, 40, CORAL, 3.0, true)
	_dibujar_extintor()
	_caja(Rect2(-65, 49, 130, 29), CREMA, TINTA, 7)
	_texto(rotulo, Vector2(0, 70), FUENTE, 17, TINTA)
	if fuera_de_pantalla:
		var punta := direccion * 74.0
		var lado := direccion.orthogonal() * 8.0
		draw_colored_polygon(PackedVector2Array([punta + direccion * 10.0, punta - direccion * 6.0 + lado, punta - direccion * 6.0 - lado]), CORAL)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-8, 83), Vector2(8, 83), Vector2(0, 94)]), CORAL)
	var metros := "%d m" % maxi(1, ceili(distancia))
	var ancho := DETALLE.get_string_size(metros, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string_outline(DETALLE, Vector2(-ancho * 0.5, 117), metros, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, TINTA)
	_texto(metros, Vector2(0, 117), DETALLE, 18, CREMA)
	if interactuable:
		_caja(Rect2(-18, -78, 36, 37), TINTA, TINTA, 8)
		_caja(Rect2(-18, -82, 36, 35), ORO, TINTA, 8)
		_texto("E", Vector2(0, -56), FUENTE, 25, TINTA)
	draw_set_transform(Vector2.ZERO)


func _dibujar_extintor() -> void:
	# El mismo depósito rojo y banda crema del objeto que se recoge.
	_caja(Rect2(-17, -30, 34, 57), TINTA, CREMA, 11)
	_caja(Rect2(-13, -27, 26, 52), CORAL, TINTA, 9)
	_caja(Rect2(-13, -8, 26, 19), CREMA, Color.TRANSPARENT, 1)
	_caja(Rect2(-3, -4, 6, 11), CORAL, Color.TRANSPARENT, 1)
	_caja(Rect2(-5, -40, 10, 12), TINTA, CREMA, 2)
	_caja(Rect2(-19, -43, 38, 7), TINTA, CREMA, 2)
	var manguera := PackedVector2Array([Vector2(18, -34), Vector2(27, -24), Vector2(29, -9), Vector2(25, 5), Vector2(24, 17)])
	draw_polyline(manguera, CREMA, 8, true)
	draw_polyline(manguera, TINTA, 5, true)
	_caja(Rect2(19, 12, 10, 19), TINTA, CREMA, 2)
	draw_circle(Vector2(3, -30), 5, TINTA, true, -1.0, true)
	draw_circle(Vector2(3, -30), 3, CREMA, true, -1.0, true)


func _texto(valor: String, posicion: Vector2, fuente: Font, tamano: int, color: Color) -> void:
	posicion.x -= fuente.get_string_size(valor, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x * 0.5
	draw_string(fuente, posicion, valor, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, color)


func _caja(rectangulo: Rect2, color: Color, borde: Color, radio: int) -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.border_color = borde
	estilo.set_border_width_all(2 if borde.a > 0 else 0)
	estilo.set_corner_radius_all(radio)
	draw_style_box(estilo, rectangulo)
