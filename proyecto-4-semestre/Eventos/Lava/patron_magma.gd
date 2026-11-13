extends RefCounted
## Una sola red de placas para el suelo, los charcos y su daño.

const ESCALA := 2.4
const LIMITES := Rect2(-4.45, -0.10, 6.86, 12.48)
const RESOLUCION := Vector2i(512, 932)
const SUAVIZADO := 0.018

var semillas: ImageTexture
var origen: Vector2i
var tamano: Vector2i
var mascara: Image
var textura: ImageTexture
var formas: Array[Dictionary] = []
var _centros: Dictionary = {}
var _placas: Dictionary = {}
var _uniones: Dictionary = {}
var _aristas: Dictionary = {}


func _init() -> void:
	origen = Vector2i((LIMITES.position * ESCALA).floor()) - Vector2i(3, 3)
	tamano = Vector2i((LIMITES.end * ESCALA).ceil()) - origen + Vector2i(3, 3)
	var imagen := Image.create(tamano.x, tamano.y, false, Image.FORMAT_RGF)
	var azar := RandomNumberGenerator.new()
	azar.seed = 6812
	for y in tamano.y:
		for x in tamano.x:
			var celda := origen + Vector2i(x, y)
			var desfase := Vector2(azar.randf_range(0.18, 0.82), azar.randf_range(0.18, 0.82))
			_centros[celda] = (Vector2(celda) + desfase) / ESCALA
			imagen.set_pixel(x, y, Color(desfase.x, desfase.y, 0.0))
	semillas = ImageTexture.create_from_image(imagen)
	for y in range(2, tamano.y - 2):
		for x in range(2, tamano.x - 2):
			var celda := origen + Vector2i(x, y)
			var centro: Vector2 = _centros[celda]
			var poligono := PackedVector2Array([centro + Vector2(-1, -1), centro + Vector2(1, -1), centro + Vector2(1, 1), centro + Vector2(-1, 1)])
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if dx == 0 and dy == 0:
						continue
					var vecino: Vector2 = _centros[celda + Vector2i(dx, dy)]
					poligono = _recortar(poligono, vecino - centro, (vecino.length_squared() - centro.length_squared()) * 0.5)
			_placas[celda] = poligono
			_registrar_aristas(celda, poligono)
	reiniciar()


func reiniciar() -> void:
	formas.clear()
	mascara = Image.create(RESOLUCION.x, RESOLUCION.y, false, Image.FORMAT_RGBA8)
	mascara.fill(Color(0, 0, 0, 0))


func aplicar(material: ShaderMaterial) -> void:
	textura = ImageTexture.create_from_image(mascara)
	material.set_shader_parameter("semillas", semillas)
	material.set_shader_parameter("origen_semillas", Vector2(origen))
	material.set_shader_parameter("tamano_semillas", Vector2(tamano))
	material.set_shader_parameter("escala_placas", ESCALA)
	material.set_shader_parameter("zonas_fundidas", textura)
	material.set_shader_parameter("limites_suelo", Vector4(LIMITES.position.x, LIMITES.position.y, LIMITES.size.x, LIMITES.size.y))


func cruce_cercano(punto: Vector2) -> Vector2:
	var mejor := Vector2.INF
	var distancia := INF
	for union: Dictionary in _uniones.values():
		var posicion: Vector2 = union.punto
		if union.aristas.size() != 3 or union.placas.size() != 3 or not LIMITES.grow(-0.5).has_point(posicion):
			continue
		var nueva := posicion.distance_squared_to(punto)
		if nueva < distancia:
			distancia = nueva
			mejor = posicion
	return mejor


func agregar_charco(centro: Vector2, extension: float) -> void:
	var union: Dictionary = _uniones[_clave(centro)]
	var forma := {"centro": centro, "placas": [], "islas": [], "ramales": []}
	var nucleo := PackedVector2Array()
	for celda: Vector2i in union.placas:
		var poligono: PackedVector2Array = _placas[celda]
		forma.placas.append(poligono)
		if nucleo.is_empty():
			nucleo = poligono
		else:
			var unidos := Geometry2D.merge_polygons(nucleo, poligono)
			if unidos.size() == 1:
				nucleo = unidos[0]
			else:
				_pintar_poligono(poligono, false)
		var centro_isla: Vector2 = centro.lerp(_centros[celda], 1.10)
		var escala := 0.26 + float(posmod(celda.x + celda.y, 3)) * 0.055
		var isla := PackedVector2Array()
		for vertice in poligono:
			isla.append(centro_isla.lerp(vertice, escala))
		forma.islas.append(isla)
		_pintar_poligono(isla, true)
	_pintar_poligono(nucleo, false)
	for primera: String in union.aristas:
		var arista: Dictionary = _aristas[primera]
		var anterior := centro
		var recorrido := 0.0
		var visitadas := {}
		while recorrido < extension:
			var siguiente: Vector2 = arista.b if anterior.distance_to(arista.a) < 0.002 else arista.a
			var longitud := anterior.distance_to(siguiente)
			if longitud < 0.001:
				break
			var final := anterior.lerp(siguiente, minf(1.0, (extension - recorrido) / longitud))
			var ancho_a := 0.010 + 0.12 * pow(1.0 - smoothstep(0.0, extension, recorrido), 1.3)
			var ancho_b := 0.010 + 0.12 * pow(1.0 - smoothstep(0.0, extension, minf(extension, recorrido + longitud)), 1.3)
			var tramo := {"a": anterior, "b": final, "ancho_a": ancho_a, "ancho_b": ancho_b}
			forma.ramales.append(tramo)
			_pintar_ramal(tramo)
			recorrido += longitud
			visitadas[arista.id] = true
			var direccion := (siguiente - anterior).normalized()
			var siguiente_arista := ""
			var alineacion := -2.0
			for candidata: String in _uniones[_clave(siguiente)].aristas:
				if visitadas.has(candidata):
					continue
				var datos: Dictionary = _aristas[candidata]
				var extremo: Vector2 = datos.b if siguiente.distance_to(datos.a) < 0.002 else datos.a
				var producto := direccion.dot((extremo - siguiente).normalized())
				if producto > alineacion:
					alineacion = producto
					siguiente_arista = candidata
			if siguiente_arista.is_empty():
				break
			anterior = siguiente
			arista = _aristas[siguiente_arista]
	formas.append(forma)


func contiene(punto: Vector2) -> bool:
	if not LIMITES.has_point(punto) or formas.is_empty():
		return false
	# Mismo muestreo bilineal que el shader: incluye ramales, no un radio invisible.
	var pixel := (punto - LIMITES.position) / LIMITES.size * Vector2(RESOLUCION) - Vector2(0.5, 0.5)
	var base := Vector2i(pixel.floor())
	var f := pixel - Vector2(base)
	var a := lerpf(_valor(base), _valor(base + Vector2i.RIGHT), f.x)
	var b := lerpf(_valor(base + Vector2i.DOWN), _valor(base + Vector2i.ONE), f.x)
	return lerpf(a, b, f.y) >= 0.5


func _valor(pixel: Vector2i) -> float:
	return mascara.get_pixel(clampi(pixel.x, 0, RESOLUCION.x - 1), clampi(pixel.y, 0, RESOLUCION.y - 1)).r


func _recortar(poligono: PackedVector2Array, normal: Vector2, limite: float) -> PackedVector2Array:
	var resultado := PackedVector2Array()
	for i in poligono.size():
		var a := poligono[i]
		var b := poligono[(i + 1) % poligono.size()]
		var da := a.dot(normal) - limite
		var db := b.dot(normal) - limite
		if da <= 0.0:
			resultado.append(a)
		if (da < 0.0) != (db < 0.0):
			resultado.append(a.lerp(b, da / (da - db)))
	return resultado


func _clave(punto: Vector2) -> Vector2i:
	return Vector2i((punto * 1000.0).round())


func _registrar_aristas(celda: Vector2i, poligono: PackedVector2Array) -> void:
	for i in poligono.size():
		var a := poligono[i]
		var b := poligono[(i + 1) % poligono.size()]
		var ka := _clave(a)
		var kb := _clave(b)
		var claves := [str(ka), str(kb)]
		claves.sort()
		var id: String = claves[0] + "/" + claves[1]
		if not _aristas.has(id):
			_aristas[id] = {"id": id, "a": a, "b": b}
		for vertice in [a, b]:
			var clave := _clave(vertice)
			if not _uniones.has(clave):
				_uniones[clave] = {"punto": vertice, "aristas": [], "placas": []}
			var union: Dictionary = _uniones[clave]
			if not union.aristas.has(id):
				union.aristas.append(id)
			if not union.placas.has(celda):
				union.placas.append(celda)


func _pixeles(rectangulo: Rect2) -> Rect2i:
	var desde := Vector2i(((rectangulo.position - LIMITES.position) / LIMITES.size * Vector2(RESOLUCION)).floor())
	var hasta := Vector2i(((rectangulo.end - LIMITES.position) / LIMITES.size * Vector2(RESOLUCION)).ceil())
	return Rect2i(desde, hasta - desde).intersection(Rect2i(Vector2i.ZERO, RESOLUCION))


func _punto_pixel(x: int, y: int) -> Vector2:
	return LIMITES.position + (Vector2(x, y) + Vector2(0.5, 0.5)) / Vector2(RESOLUCION) * LIMITES.size


func _pintar_poligono(poligono: PackedVector2Array, isla: bool) -> void:
	var rectangulo := Rect2(poligono[0], Vector2.ZERO)
	for p in poligono:
		rectangulo = rectangulo.expand(p)
	var pixeles := _pixeles(rectangulo.grow(SUAVIZADO * 2.0))
	# La distancia exacta solo hace falta en el borde. El interior y el exterior
	# se resuelven con polígonos desplazados, evitando recorrer todas las aristas
	# por cada píxel del núcleo al comenzar el evento.
	var interiores := Geometry2D.offset_polygon(poligono, -SUAVIZADO)
	var exteriores := Geometry2D.offset_polygon(poligono, SUAVIZADO * 2.0)
	for y in range(pixeles.position.y, pixeles.end.y):
		for x in range(pixeles.position.x, pixeles.end.x):
			var punto := _punto_pixel(x, y)
			if not _en_poligonos(punto, exteriores):
				continue
			var distancia := SUAVIZADO
			if not _en_poligonos(punto, interiores):
				distancia = INF
				for i in poligono.size():
					var cercano := Geometry2D.get_closest_point_to_segment(punto, poligono[i], poligono[(i + 1) % poligono.size()])
					distancia = minf(distancia, punto.distance_to(cercano))
				if not Geometry2D.is_point_in_polygon(punto, poligono):
					distancia = -distancia
			var cobertura := smoothstep(-SUAVIZADO, SUAVIZADO, distancia)
			var color := mascara.get_pixel(x, y)
			if isla:
				color.b = maxf(color.b, cobertura)
				color.a = maxf(color.a, smoothstep(-SUAVIZADO * 2.0, 0.0, distancia))
			else:
				color.r = maxf(color.r, cobertura)
				color.g = maxf(color.g, cobertura)
			mascara.set_pixel(x, y, color)


func _en_poligonos(punto: Vector2, poligonos: Array[PackedVector2Array]) -> bool:
	for poligono in poligonos:
		if Geometry2D.is_point_in_polygon(punto, poligono):
			return true
	return false


func _pintar_ramal(tramo: Dictionary) -> void:
	var a: Vector2 = tramo.a
	var b: Vector2 = tramo.b
	var segmento := b - a
	var longitud := segmento.length_squared()
	if longitud < 0.000001:
		return
	var pixeles := _pixeles(Rect2(a, Vector2.ZERO).expand(b).grow(tramo.ancho_a + SUAVIZADO))
	for y in range(pixeles.position.y, pixeles.end.y):
		for x in range(pixeles.position.x, pixeles.end.x):
			var punto := _punto_pixel(x, y)
			var t := clampf((punto - a).dot(segmento) / longitud, 0.0, 1.0)
			var ancho := lerpf(tramo.ancho_a, tramo.ancho_b, t)
			var cobertura := smoothstep(-SUAVIZADO, SUAVIZADO, ancho - punto.distance_to(a + segmento * t))
			var color := mascara.get_pixel(x, y)
			color.r = maxf(color.r, cobertura)
			mascara.set_pixel(x, y, color)
