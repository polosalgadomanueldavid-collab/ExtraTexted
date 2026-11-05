extends Control
## Proyecta la estación en el HUD para que los muebles no tapen la guía.

const ICONO := preload("res://UI/Despacho/icono_despacho.gd")
const TINTA := Color("173b50")
const CORAL := Color("ff785f")
const TURQUESA := Color("16b6b6")
const MARGEN := 18.0
const LARGO_FLECHA := 12.0
const SEMIANCHO_FLECHA := 10.0
const SOLAPE_FLECHA := 12.0

@onready var tarjeta: PanelContainer = $TarjetaDestino
@onready var icono: Control = $TarjetaDestino/Contenido/IconoEstacion
@onready var rotulo: Label = $TarjetaDestino/Contenido/NombreEstacion

var objetivo: IndicadorProximaEstacion
var fuera_de_vista: bool = false
var direccion := Vector2.DOWN
var _sombra_tarjeta: StyleBoxFlat


func _ready() -> void:
	var estilo := tarjeta.get_theme_stylebox("panel") as StyleBoxFlat
	# La sombra queda debajo de la flecha; el panel tapa el arranque de la flecha.
	_sombra_tarjeta = estilo.duplicate() as StyleBoxFlat
	_sombra_tarjeta.draw_center = false
	_sombra_tarjeta.set_border_width_all(0)
	var panel := estilo.duplicate() as StyleBoxFlat
	panel.shadow_size = 0
	tarjeta.add_theme_stylebox_override("panel", panel)


func establecer_objetivo(nuevo_objetivo: IndicadorProximaEstacion) -> void:
	if objetivo == nuevo_objetivo:
		return
	objetivo = nuevo_objetivo
	if not is_instance_valid(objetivo):
		hide()
		return
	icono.tipo = ICONO.tipo_estacion(objetivo.estacion_id)
	icono.queue_redraw()
	rotulo.text = ICONO.nombre_estacion(objetivo.estacion_id)


func actualizar(barra_despacho: Control, usando_computador: bool) -> void:
	var camara := get_viewport().get_camera_3d()
	if not is_instance_valid(objetivo) or not is_instance_valid(camara) or usando_computador:
		hide()
		return

	var factor := clampf(minf(size.x / 1280.0, size.y / 720.0), 0.6, 1.35)
	tarjeta.scale = Vector2.ONE * factor
	tarjeta.size = tarjeta.get_combined_minimum_size()
	var mitad := tarjeta.size * factor * 0.5
	var area := Rect2(Vector2.ONE * MARGEN, size - Vector2.ONE * MARGEN * 2.0)
	if barra_despacho.is_visible_in_tree():
		area.end.x = minf(area.end.x, barra_despacho.get_global_rect().position.x - MARGEN)
	var reserva := mitad + Vector2.ONE * LARGO_FLECHA * factor
	var limite := Rect2(area.position + reserva, area.size - reserva * 2.0)
	if not limite.has_area():
		hide()
		return

	var ancla := objetivo.global_position
	var detras := camara.is_position_behind(ancla)
	var centro := limite.get_center()
	var rumbo: Vector2
	if detras:
		# Usa el plano de movimiento. La proyección de un punto detrás se invierte.
		var hacia := ancla - camara.global_position
		hacia.y = 0.0
		rumbo = Vector2(hacia.dot(camara.global_basis.x), hacia.dot(camara.global_basis.z))
		fuera_de_vista = true
	else:
		var proyeccion := camara.unproject_position(ancla)
		fuera_de_vista = not area.has_point(proyeccion)
		if not fuera_de_vista:
			# Deja sitio al objeto 3D; si llega al margen superior, coloca la tarjeta debajo.
			var borde_modelo := camara.unproject_position(ancla + camara.global_basis.y * 0.45)
			var alto_modelo := minf(absf(proyeccion.y - borde_modelo.y), size.y * 0.08)
			var separacion := alto_modelo + mitad.y + LARGO_FLECHA * factor
			var posicion_anclada := proyeccion + Vector2.UP * separacion
			if posicion_anclada.y < limite.position.y:
				posicion_anclada.y = proyeccion.y + separacion
			centro = posicion_anclada.clamp(limite.position, limite.end)
		rumbo = proyeccion - centro

	if rumbo.is_zero_approx():
		rumbo = Vector2.DOWN
	if fuera_de_vista:
		centro += _hasta_borde(rumbo, limite.size * 0.5)
	direccion = rumbo.normalized()
	tarjeta.position = centro - mitad
	show()
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(objetivo) or _sombra_tarjeta == null:
		return
	draw_set_transform(tarjeta.position, 0.0, tarjeta.scale)
	draw_style_box(_sombra_tarjeta, Rect2(Vector2.ZERO, tarjeta.size))
	var mitad := tarjeta.size * 0.5
	var base := mitad + _hasta_borde(direccion, mitad - Vector2.ONE * SOLAPE_FLECHA)
	var punta := mitad + _hasta_borde(direccion, mitad) + direccion * LARGO_FLECHA
	var lateral := direccion.orthogonal() * SEMIANCHO_FLECHA
	var vertices := PackedVector2Array([base + lateral, punta, base - lateral])
	draw_colored_polygon(vertices, TURQUESA if objetivo.interactuable else CORAL)
	draw_polyline(vertices, TINTA, 2.0, true)


func _hasta_borde(rumbo: Vector2, mitad: Vector2) -> Vector2:
	var factor := maxf(absf(rumbo.x) / mitad.x, absf(rumbo.y) / mitad.y)
	return rumbo / factor
