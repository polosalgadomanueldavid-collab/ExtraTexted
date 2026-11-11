class_name FilaCalmaJugador
extends Control

const ANCHO: float = 365.0
const ALTO: float = 72.0
const PETROLEO := Color("173b50")
const CREMA := Color("fff1d8")
const CORAL := Color("ff785f")
const CELESTE := Color("82c9d6")
const DURACION_CAMBIO: float = 0.45
const RETRATO: Texture2D = preload("res://UI/Despacho/retrato_policia.png")
const RETRATO_RELEVO: Texture2D = preload("res://UI/Despacho/retrato_policia_relevo.png")
const MASCARA: Shader = preload("res://UI/Despacho/retrato_circular.gdshader")
const FUENTE: Font = preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")

var indice_jugador: int = 1
var calma: int = 100
var _retrato: TextureRect
var _nombre: Label
var _valor: Label
var _subtitulo: Label
var _estado: Label
var _fondo: StyleBoxFlat
var _riel: StyleBoxFlat
var _segmento_vacio: StyleBoxFlat
var _segmento_lleno: StyleBoxFlat
var _segmento_critico: StyleBoxFlat
var _calma_mostrada: float = 100.0
var _calma_inicial: float = 100.0
var _tiempo_cambio: float = DURACION_CAMBIO
var _destello: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(ANCHO, ALTO)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func _ready() -> void:
	_fondo = _estilo_segmento(Color("0b2634ed"), 15)
	_fondo.border_color = Color("a5d1d2a6")
	_fondo.set_border_width_all(1)
	_riel = _estilo_segmento(Color("061a28d9"), 7)
	_segmento_vacio = _estilo_segmento(Color("3d6070ca"))
	_segmento_lleno = _estilo_segmento(CREMA)
	_segmento_critico = _estilo_segmento(CORAL)
	_retrato = TextureRect.new()
	_retrato.position = Vector2.ZERO
	_retrato.size = Vector2(ALTO, ALTO)
	establecer_retrato(null)
	_retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_retrato.stretch_mode = TextureRect.STRETCH_SCALE
	_retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = MASCARA
	_retrato.material = material
	add_child(_retrato)
	_nombre = _crear_etiqueta(Vector2(87, 3), Vector2(110, 31), HORIZONTAL_ALIGNMENT_LEFT, 26)
	_valor = _crear_etiqueta(Vector2(218, 3), Vector2(139, 31), HORIZONTAL_ALIGNMENT_RIGHT, 23)
	_subtitulo = _crear_etiqueta(Vector2(88, 31), Vector2(172, 15), HORIZONTAL_ALIGNMENT_LEFT, 12)
	_subtitulo.text = "CALMA OPERATIVA"
	_subtitulo.add_theme_color_override("font_color", CELESTE)
	_estado = _crear_etiqueta(Vector2(258, 31), Vector2(99, 15), HORIZONTAL_ALIGNMENT_RIGHT, 12)
	actualizar(indice_jugador, calma)


func actualizar(indice: int, nueva_calma: int) -> void:
	if indice_jugador != indice:
		indice_jugador = indice
		establecer_retrato(null)
	var objetivo := clampi(nueva_calma, 0, 100)
	if objetivo != calma and is_inside_tree():
		_calma_inicial = _calma_mostrada
		_tiempo_cambio = 0.0
		_destello = 1.0
		set_process(true)
	elif not is_processing():
		_calma_mostrada = float(objetivo)
	calma = objetivo
	if is_instance_valid(_nombre):
		_nombre.text = "J%d" % indice_jugador
		_actualizar_etiquetas()
	queue_redraw()


func _process(delta: float) -> void:
	_tiempo_cambio = minf(_tiempo_cambio + delta, DURACION_CAMBIO)
	var avance := _tiempo_cambio / DURACION_CAMBIO
	var suavizado := avance * avance * (3.0 - 2.0 * avance)
	_calma_mostrada = lerpf(_calma_inicial, float(calma), suavizado)
	_destello = maxf(0.0, _destello - delta / 0.65)
	_actualizar_etiquetas()
	queue_redraw()
	if avance >= 1.0 and _destello <= 0.0:
		set_process(false)


func _actualizar_etiquetas() -> void:
	_valor.text = "%d / 100" % roundi(_calma_mostrada)
	_estado.text = "CRITICA" if calma < 30 else "ESTABLE" if calma >= 70 else "ATENCION"
	_estado.add_theme_color_override("font_color", CORAL if calma < 30 else CELESTE)


func establecer_retrato(textura: Texture2D) -> void:
	if is_instance_valid(_retrato):
		var predeterminado := RETRATO_RELEVO if indice_jugador == 2 else RETRATO
		_retrato.texture = textura if textura != null else predeterminado


func _draw() -> void:
	var centro := Vector2(ALTO * 0.5, ALTO * 0.5)
	if _fondo == null:
		return
	# La base sigue siendo pequeña y deja espacio para una segunda fila debajo.
	draw_style_box(_fondo, Rect2(58, 4, 307, 64))
	draw_line(Vector2(84, 7), Vector2(347, 7), Color("d6f3ef24"), 1.0)
	draw_rect(Rect2(81, 65, 50, 2), CORAL if calma < 30 else CELESTE)
	draw_style_box(_riel, Rect2(83, 45, 276, 20))
	# El retrato conserva el centro del círculo y gana un aro doble.
	draw_circle(centro + Vector2(1, 2), 37.0, Color("04121bb0"))
	draw_circle(centro, 36.0, CORAL if indice_jugador > 1 or calma < 30 else CREMA)
	draw_circle(centro, 33.5, PETROLEO)
	draw_circle(centro, 32.5, CELESTE.darkened(0.3))
	if _destello > 0.0:
		draw_arc(centro, 35.0, -PI * 0.78, PI * 0.28, 32, Color(1, 1, 1, _destello * 0.85), 2.5, true)
	var estilo_activo := _segmento_critico if _calma_mostrada < 30.0 else _segmento_lleno
	for indice: int in range(10):
		var rectangulo := Rect2(88.0 + indice * 27.0, 49.0, 24.0, 12.0)
		draw_style_box(_segmento_vacio, rectangulo)
		var proporcion := clampf((_calma_mostrada - indice * 10.0) / 10.0, 0.0, 1.0)
		if proporcion > 0.0:
			rectangulo.size.x *= proporcion
			draw_style_box(estilo_activo, rectangulo)
			var luz := Color("ffffff8c") if calma >= 30 else Color("ffd2c28c")
			draw_line(rectangulo.position + Vector2(3, 2), rectangulo.position + Vector2(maxf(3.0, rectangulo.size.x - 3.0), 2), luz, 1.0)
	if _destello > 0.0:
		draw_rect(Rect2(83, 45, 276, 20), Color(1, 1, 1, _destello * 0.10))


func _crear_etiqueta(posicion: Vector2, tamano: Vector2, alineacion: HorizontalAlignment, fuente_tamano: int) -> Label:
	var etiqueta := Label.new()
	etiqueta.position = posicion
	etiqueta.size = tamano
	etiqueta.horizontal_alignment = alineacion
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_override("font", FUENTE)
	etiqueta.add_theme_font_size_override("font_size", fuente_tamano)
	etiqueta.add_theme_color_override("font_color", CREMA)
	etiqueta.add_theme_color_override("font_shadow_color", Color("031923b3"))
	etiqueta.add_theme_constant_override("shadow_offset_x", 1)
	etiqueta.add_theme_constant_override("shadow_offset_y", 2)
	etiqueta.add_theme_constant_override("shadow_outline_size", 3)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(etiqueta)
	return etiqueta


func _estilo_segmento(color: Color, radio: int = 4) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.set_corner_radius_all(radio)
	return estilo
