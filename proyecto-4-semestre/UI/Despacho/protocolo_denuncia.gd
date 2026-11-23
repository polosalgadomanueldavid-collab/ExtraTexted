extends Control
## Estaciones independientes con los mismos símbolos que los marcadores 3D.

const ICONO := preload("res://UI/Despacho/icono_despacho.gd")
const TINTA := Color("173b50")
var estaciones: Array[String] = []
var completadas: Array[String] = []
var compacto := false
var _entregas: Dictionary = {}
var _recordatorio := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_process(false)

func configurar(requeridas: Array[String], hechas: Array[String]) -> void:
	if estaciones == requeridas and completadas == hechas: return
	estaciones = requeridas.duplicate()
	completadas = hechas.duplicate()
	if estaciones.is_empty(): limpiar_entregas()
	queue_redraw()

func iniciar_entrega(id: String) -> void:
	_entregas[id] = .62
	set_process(true)
	queue_redraw()

func limpiar_entregas() -> void:
	_entregas.clear()
	_recordatorio = 0.0
	set_process(false)
	queue_redraw()

func recordar_requisitos() -> void:
	_recordatorio = .45
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_recordatorio = maxf(0, _recordatorio-delta)
	for id: String in _entregas.keys():
		_entregas[id] -= delta
		if _entregas[id] <= 0.0: _entregas.erase(id)
	if _entregas.is_empty() and is_zero_approx(_recordatorio): set_process(false)
	queue_redraw()

func centro_resultado(id: String) -> Vector2:
	var indice := estaciones.find(id)
	if indice < 0: return get_global_rect().get_center()
	var punto := Vector2(size.x / estaciones.size() * (indice + .5), 15 if compacto else 24)
	return get_global_transform_with_canvas() * punto

func _draw() -> void:
	if estaciones.is_empty(): return
	var ancho := size.x / estaciones.size()
	var radio := minf(12.0 if compacto else 20.0, ancho * .34)
	for i in estaciones.size():
		var id := estaciones[i]
		var obtenido := completadas.has(id) and not _entregas.has(id)
		var centro := Vector2(ancho * (i+.5), 15 if compacto else 24)
		var caja := StyleBoxFlat.new()
		caja.bg_color = Color("d7e2bd") if obtenido else Color("f4e4c5")
		caja.border_color = Color("507b65") if obtenido else (Color("ff785f") if _recordatorio > 0.0 else Color("b5a482"))
		caja.set_border_width_all(2 if obtenido or _recordatorio > 0.0 else 1)
		caja.set_corner_radius_all(6)
		draw_style_box(caja, Rect2(centro-Vector2.ONE*radio, Vector2.ONE*radio*2))
		ICONO.dibujar_estacion(self, ICONO.tipo_estacion(id), centro, radio*1.4, Color("3e6855") if obtenido else TINTA)
		if obtenido:
			var marca := centro + Vector2(.78, .72)*radio
			draw_circle(marca, 5 if compacto else 7, Color("507b65"), true, -1.0, true)
			draw_polyline(PackedVector2Array([marca+Vector2(-3,0), marca+Vector2(-1,2), marca+Vector2(3,-2)]), Color("fff1d8"), 1.8, true)
