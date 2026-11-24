extends RefCounted
## Contorno independiente del árbol y de recursos gráficos; conserva el ancho del salto.
const TRAMOS := 8
const SEPARACION_ENTRE_BORDES := 0.25
var centro: Vector2
var contorno := PackedVector2Array()
var limites: Rect2
var saltable := false
var _izquierda := PackedVector2Array()
var _derecha := PackedVector2Array()
var _margen_entre_bordes: Array[PackedVector2Array] = []

func trazar(origen: Vector2, largo: float, ancho: float, angulo: float, azar: RandomNumberGenerator) -> void:
	centro = origen
	limites = Rect2(centro, Vector2.ZERO)
	var desvio := minf(0.14, ancho * 0.11)
	for i in range(TRAMOS + 1):
		var t := float(i) / TRAMOS
		var eje := Vector2(azar.randf_range(-desvio, desvio), (t - 0.5) * largo)
		# Las puntas terminan en cuña y el tramo central conserva su anchura.
		var radio := ancho * 0.5 * minf(1.0, minf(t, 1.0 - t) * 6.8)
		var izq := centro + (eje - Vector2.RIGHT * radio * azar.randf_range(0.96, 1.08)).rotated(angulo)
		var der := centro + (eje + Vector2.RIGHT * radio * azar.randf_range(0.96, 1.08)).rotated(angulo)
		_izquierda.append(izq)
		_derecha.append(der)
		limites = limites.expand(izq).expand(der)
	contorno.append_array(_izquierda)
	for i in range(TRAMOS - 1, 0, -1):
		contorno.append(_derecha[i])


func toca_cuadro(punto: Vector2, radio: float) -> bool:
	var caja := Rect2(punto - Vector2.ONE * radio, Vector2.ONE * radio * 2.0)
	if not limites.intersects(caja):
		return false
	var cuadro := PackedVector2Array([caja.position, Vector2(caja.end.x, caja.position.y),
		caja.end, Vector2(caja.position.x, caja.end.y)])
	return not Geometry2D.intersect_polygons(contorno, cuadro).is_empty()


func invade_borde(poligono: PackedVector2Array, caja: Rect2) -> bool:
	if not limites.grow(SEPARACION_ENTRE_BORDES).intersects(caja):
		return false
	if _margen_entre_bordes.is_empty():
		_margen_entre_bordes = Geometry2D.offset_polygon(contorno, SEPARACION_ENTRE_BORDES)
	for margen in _margen_entre_bordes:
		if not Geometry2D.intersect_polygons(poligono, margen).is_empty():
			return true
	return false


func serializar() -> Dictionary:
	return {"centro": centro, "contorno": contorno, "limites": limites, "saltable": saltable, "izquierda": _izquierda, "derecha": _derecha}
