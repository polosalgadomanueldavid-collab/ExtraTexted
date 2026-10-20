extends Control
## Secuencia plana de estaciones: completada, actual y pendiente.

var estaciones: Array[String] = []
var indice_actual: int = 0
const TINTA := Color("173b50")
const CORAL := Color("ff785f")
const COMPLETADA := Color("16b6b6")
const PENDIENTE := Color("819cb0")
const NOMBRES := {
	"evidencias": "Evidencias", "verificacion": "Verificación",
	"privacidad": "Privacidad", "reporte": "Reporte", "bienestar": "Bienestar"
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func configurar(nuevas_estaciones: Array[String], nuevo_indice: int) -> void:
	if estaciones == nuevas_estaciones and indice_actual == nuevo_indice:
		return
	estaciones = nuevas_estaciones.duplicate()
	indice_actual = nuevo_indice
	queue_redraw()


func _draw() -> void:
	if estaciones.is_empty():
		return
	var ancho_paso := size.x / estaciones.size()
	var radio := minf(17, ancho_paso * 0.2)
	var y := 21.0
	if estaciones.size() > 1:
		draw_line(Vector2(ancho_paso * 0.5, y), Vector2(size.x - ancho_paso * 0.5, y), TINTA, 2, true)
	var fuente := get_theme_font("font", "Label")
	for indice: int in range(estaciones.size()):
		var centro := Vector2(ancho_paso * (indice + 0.5), y)
		var completada := indice < indice_actual
		var actual := indice == indice_actual
		var color := COMPLETADA if completada else (CORAL if actual else PENDIENTE)
		draw_circle(centro, radio, color)
		draw_arc(centro, radio, 0, TAU, 40, TINTA, 1.8, true)
		if completada:
			draw_polyline(PackedVector2Array([centro + Vector2(-8, 0), centro + Vector2(-2, 6), centro + Vector2(8, -6)]), Color("fff1d8"), 3, true)
		var texto: String = NOMBRES.get(estaciones[indice], estaciones[indice].capitalize())
		var tamano := 14 if estaciones.size() <= 3 else 12
		while tamano > 9 and fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x > ancho_paso - 12:
			tamano -= 1
		var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
		draw_string(fuente, Vector2(centro.x - ancho * 0.5, 62), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, TINTA)
