extends Control
## Rayo volumétrico anclado al taco, visible sobre la máscara del apagón.

const INDICADOR_3D := preload("res://MarcadoresEstaciones/indicador_proxima_estacion.gd")
const FUENTE := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const TINTA := Color("173b50")
const CREMA := Color("fff1d8")
const DORADO := Color("ffc969")
const TURQUESA := Color("16b6b6")
const TAMANO := Vector2(192, 134)
const MARGEN := 18.0
const LARGO_FLECHA := 12.0

var contenido: Control
var rotulo: Label
var fuera_de_vista: bool = false
var direccion := Vector2.DOWN
var _vista: SubViewport
var _indicador_3d: IndicadorProximaEstacion


func _ready() -> void:
	name = "IndicadorLuz"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	set_process(false)
	contenido = Control.new()
	contenido.size = TAMANO
	contenido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(contenido)
	_crear_vista_3d()
	rotulo = Label.new()
	rotulo.text = "Activar Luz"
	rotulo.position = Vector2(0, 98)
	rotulo.size = Vector2(TAMANO.x, 36)
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo.add_theme_font_override("font", FUENTE)
	rotulo.add_theme_font_size_override("font_size", 24)
	rotulo.add_theme_color_override("font_color", TINTA)
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = CREMA
	fondo.border_color = TINTA
	fondo.set_border_width_all(2)
	fondo.set_corner_radius_all(10)
	rotulo.add_theme_stylebox_override("normal", fondo)
	contenido.add_child(rotulo)


func _crear_vista_3d() -> void:
	# Un mundo pequeño permite dibujar el volumen por encima de la oscuridad.
	_vista = SubViewport.new()
	_vista.size = Vector2i(224, 224)
	_vista.transparent_bg = true
	_vista.own_world_3d = true
	_vista.msaa_3d = Viewport.MSAA_4X
	_vista.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vista)
	var camara := Camera3D.new()
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.size = 0.88
	camara.position = Vector3(0, 0.136, 3.0)
	camara.environment = Environment.new()
	camara.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	camara.environment.ambient_light_color = CREMA
	camara.environment.ambient_light_energy = 0.65
	_vista.add_child(camara)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-25, -35, 0)
	luz.light_energy = 1.2
	_vista.add_child(luz)
	_indicador_3d = INDICADOR_3D.new()
	# El límite ocupa el viewport del icono, cuyo tamaño en pantalla es fijo.
	_indicador_3d.alto_maximo_pantalla = 1.0
	_indicador_3d.configurar("luz", "Activar Luz")
	_vista.add_child(_indicador_3d)
	_indicador_3d.get_node("OrientacionCamara/Puntero").hide()
	var imagen := TextureRect.new()
	imagen.position = Vector2(40, -4)
	imagen.size = Vector2(112, 112)
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagen.texture = _vista.get_texture()
	imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenido.add_child(imagen)


func actualizar(camara: Camera3D, ancla: Vector3, barra_despacho: Control, activo: bool, interactuable: bool = false) -> void:
	visible = activo and is_instance_valid(camara)
	_indicador_3d.establecer_activo(visible)
	_indicador_3d.establecer_interactuable(interactuable)
	_vista.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if visible else SubViewport.UPDATE_DISABLED
	if not visible:
		return
	var factor := clampf(minf(size.x / 1280.0, size.y / 720.0), 0.6, 1.35)
	contenido.scale = Vector2.ONE * factor
	var mitad := TAMANO * factor * 0.5
	var area := Rect2(Vector2.ONE * MARGEN, size - Vector2.ONE * MARGEN * 2.0)
	if is_instance_valid(barra_despacho) and barra_despacho.is_visible_in_tree():
		area.end.x = minf(area.end.x, barra_despacho.get_global_rect().position.x - MARGEN)
	var reserva := mitad + Vector2.ONE * LARGO_FLECHA * factor
	var limite := Rect2(area.position + reserva, area.size - reserva * 2.0)
	if not limite.has_area():
		hide()
		_indicador_3d.establecer_activo(false)
		return
	var centro := limite.get_center()
	var rumbo: Vector2
	if camara.is_position_behind(ancla):
		var hacia := ancla - camara.global_position
		hacia.y = 0.0
		rumbo = Vector2(hacia.dot(camara.global_basis.x), hacia.dot(camara.global_basis.z))
		fuera_de_vista = true
	else:
		var proyeccion := camara.unproject_position(ancla)
		fuera_de_vista = not area.has_point(proyeccion)
		if not fuera_de_vista:
			centro = (proyeccion - Vector2(0, mitad.y + LARGO_FLECHA * factor)).clamp(limite.position, limite.end)
		rumbo = proyeccion - centro
	if rumbo.is_zero_approx():
		rumbo = Vector2.DOWN
	if fuera_de_vista:
		centro += _hasta_borde(rumbo, limite.size * 0.5)
	direccion = rumbo.normalized()
	contenido.position = centro - mitad
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(rotulo):
		return
	draw_set_transform(contenido.position + rotulo.position * contenido.scale, 0.0, contenido.scale)
	var mitad := rotulo.size * 0.5
	var base := mitad + _hasta_borde(direccion, mitad - Vector2.ONE * 12.0)
	var punta := mitad + _hasta_borde(direccion, mitad) + direccion * LARGO_FLECHA
	var lateral := direccion.orthogonal() * 10.0
	var vertices := PackedVector2Array([base + lateral, punta, base - lateral])
	draw_colored_polygon(vertices, TURQUESA if _indicador_3d.interactuable else DORADO)
	draw_polyline(vertices, TINTA, 2.0, true)


func _hasta_borde(rumbo: Vector2, mitad: Vector2) -> Vector2:
	return rumbo / maxf(absf(rumbo.x) / mitad.x, absf(rumbo.y) / mitad.y)
