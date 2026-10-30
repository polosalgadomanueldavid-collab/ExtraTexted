extends RefCounted
## Objetos volumétricos opacos. El indicador controla orientación y movimiento.

const CREMA := Color("fff1d8")
const PETROLEO := Color("173b50")
const CORAL := Color("ff785f")

static var _materiales: Dictionary = {}


static func crear(estacion_id: String) -> Node3D:
	var modelo := Node3D.new()
	modelo.name = "ModeloEstacion"
	modelo.set_meta("estacion_id", estacion_id)
	match estacion_id:
		"evidencias":
			_crear_carpeta(modelo)
		"verificacion":
			_crear_lupa(modelo)
		"privacidad":
			_crear_candado(modelo)
		"reporte":
			_crear_documento(modelo)
		"bienestar":
			_crear_corazon(modelo)
		_:
			modelo.set_meta("fallback", true)
			_crear_documento(modelo)
	return modelo


static func crear_puntero() -> MeshInstance3D:
	var contorno := PackedVector2Array([
		Vector2(-0.10, 0.07), Vector2(0.10, 0.07), Vector2(0.0, -0.07)
	])
	return _pieza("Puntero", _redondear(contorno, 0.025, 7), 0.065, CORAL, 0.014)


static func _crear_carpeta(modelo: Node3D) -> void:
	var silueta := PackedVector2Array([
		Vector2(-0.315, -0.25), Vector2(0.315, -0.25),
		Vector2(0.315, 0.16), Vector2(-0.015, 0.16),
		Vector2(-0.055, 0.28), Vector2(-0.245, 0.28),
		Vector2(-0.285, 0.16), Vector2(-0.315, 0.16)
	])
	var trasera := _pieza("CarpetaTrasera", _redondear(silueta, 0.035), 0.10, PETROLEO, 0.020)
	trasera.position = Vector3(-0.012, 0.0, -0.025)
	modelo.add_child(trasera)
	var pestana := PackedVector2Array([
		Vector2(-0.256, 0.145), Vector2(-0.226, 0.269),
		Vector2(-0.068, 0.269), Vector2(-0.022, 0.145)
	])
	var pestana_coral := _pieza("PestanaCoral", _redondear(pestana, 0.018), 0.045, CORAL, 0.010)
	pestana_coral.position.z = 0.017
	modelo.add_child(pestana_coral)
	var frente := PackedVector2Array([
		Vector2(-0.292, -0.27), Vector2(0.310, -0.27),
		Vector2(0.310, 0.165), Vector2(0.095, 0.165),
		Vector2(0.051, 0.132), Vector2(-0.292, 0.165)
	])
	var cara := _pieza("CarpetaFrente", _redondear(frente, 0.042, 8), 0.095, CREMA, 0.024)
	cara.position = Vector3(0.009, 0.0, 0.033)
	modelo.add_child(cara)


static func _crear_lupa(modelo: Node3D) -> void:
	var centro := Vector3(-0.065, 0.075, 0.0)
	# Dos aros cerrados mantienen un hueco real, sin vidrio ni transparencia.
	var respaldo := _toro("LupaAroPetroleo", 0.139, 0.231, PETROLEO)
	respaldo.position = centro + Vector3(0.0, 0.0, -0.029)
	modelo.add_child(respaldo)
	var aro := _toro("LupaAroCrema", 0.146, 0.224, CREMA)
	aro.position = centro + Vector3(0.0, 0.0, 0.028)
	modelo.add_child(aro)
	var inicio := Vector3(0.083, -0.073, -0.012)
	var fin := Vector3(0.230, -0.221, -0.012)
	var mango := _capsula_entre("LupaMango", inicio, fin, 0.055, PETROLEO)
	modelo.add_child(mango)
	var direccion := (fin - inicio).normalized()
	var banda := _pieza("LupaBandaCoral", _circulo(0.068, 40), 0.065, CORAL, 0.010)
	banda.position = inicio + direccion * 0.047
	banda.quaternion = Quaternion(Vector3.BACK, direccion)
	modelo.add_child(banda)


static func _crear_candado(modelo: Node3D) -> void:
	var recorrido: Array[Vector3] = [Vector3(-0.145, -0.015, -0.018)]
	for indice: int in range(29):
		var angulo := PI - PI * float(indice) / 28.0
		recorrido.append(Vector3(cos(angulo) * 0.145, 0.105 + sin(angulo) * 0.145, -0.018))
	recorrido.append(Vector3(0.145, -0.015, -0.018))
	modelo.add_child(_tubo("CandadoArco", recorrido, 0.046, CREMA))
	var cuerpo := _pieza("CandadoCuerpo", _rectangulo_redondeado(Vector2(0.52, 0.36), 0.065), 0.145, PETROLEO, 0.027)
	cuerpo.position.y = -0.115
	modelo.add_child(cuerpo)
	var ojo := PackedVector2Array()
	# El cuello y la base forman una sola silueta, sin superficies coplanares.
	for indice: int in range(33):
		var angulo := -PI * 0.25 + PI * 1.5 * float(indice) / 32.0
		ojo.append(Vector2(cos(angulo), sin(angulo)) * 0.044 + Vector2(0.0, 0.024))
	ojo.append(Vector2(-0.048, -0.102))
	ojo.append(Vector2(0.048, -0.102))
	var cerradura := _pieza("CandadoCerradura", _redondear(ojo, 0.006, 3), 0.022, CORAL, 0.005)
	cerradura.position = Vector3(0.0, -0.067, 0.079)
	modelo.add_child(cerradura)


static func _crear_documento(modelo: Node3D) -> void:
	var silueta := PackedVector2Array([
		Vector2(-0.245, -0.31), Vector2(0.245, -0.31),
		Vector2(0.245, 0.145), Vector2(0.085, 0.31), Vector2(-0.245, 0.31)
	])
	var respaldo := _pieza("DocumentoCanto", _redondear(silueta, 0.034, 7), 0.11, PETROLEO, 0.019)
	respaldo.position = Vector3(-0.012, -0.003, -0.023)
	modelo.add_child(respaldo)
	var cara := _pieza("DocumentoPapel", _redondear(silueta, 0.029, 7), 0.095, CREMA, 0.018)
	cara.scale = Vector3(0.94, 0.96, 1.0)
	cara.position.z = 0.028
	modelo.add_child(cara)
	var esquina := PackedVector2Array([
		Vector2(0.080, 0.291), Vector2(0.080, 0.139), Vector2(0.230, 0.139)
	])
	var pliegue := _pieza("DocumentoEsquinaDoblada", _redondear(esquina, 0.015, 5), 0.030, PETROLEO, 0.007)
	pliegue.position.z = 0.076
	modelo.add_child(pliegue)
	var datos: Array[Dictionary] = [
		{"nombre": "DocumentoLineaCoral", "ancho": 0.205, "x": -0.046, "y": 0.095, "color": CORAL},
		{"nombre": "DocumentoLineaDos", "ancho": 0.300, "x": 0.0, "y": -0.014, "color": PETROLEO},
		{"nombre": "DocumentoLineaTres", "ancho": 0.300, "x": 0.0, "y": -0.119, "color": PETROLEO}
	]
	for dato: Dictionary in datos:
		var color_linea: Color = dato["color"]
		var linea := _pieza(str(dato["nombre"]), _rectangulo_redondeado(Vector2(float(dato["ancho"]), 0.042), 0.021), 0.025, color_linea, 0.007)
		linea.position = Vector3(float(dato["x"]), float(dato["y"]), 0.080)
		modelo.add_child(linea)


static func _crear_corazon(modelo: Node3D) -> void:
	var silueta := PackedVector2Array()
	# Curva continua: lóbulos suaves, hendidura y punta reconocibles a distancia.
	for indice: int in range(96):
		var t := TAU * float(indice) / 96.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		silueta.append(Vector2(x / 16.0 * 0.315, (y + 2.55) / 14.45 * 0.30))
	var canto := _pieza("CorazonCantoPetroleo", silueta, 0.105, PETROLEO, 0.025)
	canto.position.z = -0.020
	modelo.add_child(canto)
	var frente := _pieza("CorazonFrenteCoral", silueta, 0.062, CORAL, 0.025)
	frente.scale = Vector3(0.974, 0.974, 1.0)
	frente.position.z = 0.045
	modelo.add_child(frente)


static func _material(color: Color) -> StandardMaterial3D:
	var clave := color.to_html()
	if _materiales.has(clave):
		return _materiales[clave] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.4
	material.metallic_specular = 0.45
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.2
	material.no_depth_test = false
	_materiales[clave] = material
	return material


static func _instancia(nombre: String, malla: Mesh, color: Color) -> MeshInstance3D:
	var pieza := MeshInstance3D.new()
	pieza.name = nombre
	pieza.mesh = malla
	pieza.material_override = _material(color)
	pieza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return pieza


static func _pieza(nombre: String, contorno: PackedVector2Array, profundidad: float, color: Color, bisel: float) -> MeshInstance3D:
	return _instancia(nombre, _extruir_biselado(contorno, profundidad, bisel), color)


static func _toro(nombre: String, interior: float, exterior: float, color: Color) -> MeshInstance3D:
	var malla := TorusMesh.new()
	malla.inner_radius = interior
	malla.outer_radius = exterior
	malla.rings = 64
	malla.ring_segments = 20
	var aro := _instancia(nombre, malla, color)
	aro.rotation.x = PI * 0.5
	return aro


static func _capsula_entre(nombre: String, inicio: Vector3, fin: Vector3, radio: float, color: Color) -> MeshInstance3D:
	var malla := CapsuleMesh.new()
	malla.radius = radio
	malla.height = inicio.distance_to(fin) + 2.0 * radio
	malla.radial_segments = 32
	malla.rings = 12
	var pieza := _instancia(nombre, malla, color)
	pieza.position = (inicio + fin) * 0.5
	pieza.quaternion = Quaternion(Vector3.UP, (fin - inicio).normalized())
	return pieza


static func _circulo(radio: float, segmentos: int) -> PackedVector2Array:
	var puntos := PackedVector2Array()
	for indice: int in range(segmentos):
		var angulo := TAU * float(indice) / float(segmentos)
		puntos.append(Vector2(cos(angulo), sin(angulo)) * radio)
	return puntos


static func _rectangulo_redondeado(tamano: Vector2, radio: float) -> PackedVector2Array:
	var mitad := tamano * 0.5
	return _redondear(PackedVector2Array([
		Vector2(-mitad.x, -mitad.y), Vector2(mitad.x, -mitad.y),
		Vector2(mitad.x, mitad.y), Vector2(-mitad.x, mitad.y)
	]), radio, 8)


static func _redondear(poligono: PackedVector2Array, radio: float, pasos: int = 6) -> PackedVector2Array:
	var puntos := PackedVector2Array()
	for indice: int in range(poligono.size()):
		var esquina := poligono[indice]
		var anterior := poligono[(indice - 1 + poligono.size()) % poligono.size()]
		var siguiente := poligono[(indice + 1) % poligono.size()]
		var distancia := minf(radio, minf(esquina.distance_to(anterior), esquina.distance_to(siguiente)) * 0.45)
		var entrada := esquina.move_toward(anterior, distancia)
		var salida := esquina.move_toward(siguiente, distancia)
		for paso: int in range(pasos + 1):
			var t := float(paso) / float(pasos)
			puntos.append(entrada * pow(1.0 - t, 2.0) + esquina * 2.0 * (1.0 - t) * t + salida * t * t)
	return puntos


static func _extruir_biselado(contorno: PackedVector2Array, profundidad: float, bisel: float) -> ArrayMesh:
	var puntos := _contorno_antihorario(contorno)
	var triangulos := Geometry2D.triangulate_polygon(puntos)
	if triangulos.is_empty():
		push_error("No fue posible triangular el modelo de marcador.")
		return ArrayMesh.new()
	var minimo := puntos[0]
	var maximo := puntos[0]
	var centro := Vector2.ZERO
	for punto: Vector2 in puntos:
		minimo = minimo.min(punto)
		maximo = maximo.max(punto)
		centro += punto
	# El promedio mantiene el centro de bisel por debajo de la hendidura del corazón.
	centro /= float(puntos.size())
	var semieje := minf(maximo.x - minimo.x, maximo.y - minimo.y) * 0.5
	var reduccion := clampf(bisel / maxf(semieje, 0.001), 0.02, 0.28)
	var bisel_z := minf(bisel, profundidad * 0.45)
	var perfiles: Array[Vector3] = [
		Vector3(1.0 - reduccion, -profundidad * 0.5, -1.0),
		Vector3(1.0 - reduccion * 0.293, -profundidad * 0.5 + bisel_z * 0.293, -0.707),
		Vector3(1.0, -profundidad * 0.5 + bisel_z, 0.0),
		Vector3(1.0, profundidad * 0.5 - bisel_z, 0.0),
		Vector3(1.0 - reduccion * 0.293, profundidad * 0.5 - bisel_z * 0.293, 0.707),
		Vector3(1.0 - reduccion, profundidad * 0.5, 1.0)
	]
	var superficie := SurfaceTool.new()
	superficie.begin(Mesh.PRIMITIVE_TRIANGLES)
	for indice: int in range(0, triangulos.size(), 3):
		var a := centro + (puntos[triangulos[indice]] - centro) * perfiles[0].x
		var b := centro + (puntos[triangulos[indice + 1]] - centro) * perfiles[0].x
		var c := centro + (puntos[triangulos[indice + 2]] - centro) * perfiles[0].x
		_triangulo(superficie, Vector3(a.x, a.y, profundidad * 0.5), Vector3(b.x, b.y, profundidad * 0.5), Vector3(c.x, c.y, profundidad * 0.5), Vector3.BACK, Vector3.BACK, Vector3.BACK)
		_triangulo(superficie, Vector3(a.x, a.y, -profundidad * 0.5), Vector3(b.x, b.y, -profundidad * 0.5), Vector3(c.x, c.y, -profundidad * 0.5), Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD)
	for nivel: int in range(perfiles.size() - 1):
		for indice: int in range(puntos.size()):
			var siguiente := (indice + 1) % puntos.size()
			var a := _vertice_perfil(puntos[indice], centro, perfiles[nivel])
			var b := _vertice_perfil(puntos[siguiente], centro, perfiles[nivel])
			var c := _vertice_perfil(puntos[siguiente], centro, perfiles[nivel + 1])
			var d := _vertice_perfil(puntos[indice], centro, perfiles[nivel + 1])
			var na := _normal_perfil(puntos, indice, perfiles[nivel].z)
			var nb := _normal_perfil(puntos, siguiente, perfiles[nivel].z)
			var nc := _normal_perfil(puntos, siguiente, perfiles[nivel + 1].z)
			var nd := _normal_perfil(puntos, indice, perfiles[nivel + 1].z)
			_triangulo(superficie, a, b, c, na, nb, nc)
			_triangulo(superficie, a, c, d, na, nc, nd)
	return superficie.commit()


static func _contorno_antihorario(contorno: PackedVector2Array) -> PackedVector2Array:
	var puntos := PackedVector2Array()
	for punto: Vector2 in contorno:
		if puntos.is_empty() or not punto.is_equal_approx(puntos[-1]):
			puntos.append(punto)
	if puntos.size() > 1 and puntos[0].is_equal_approx(puntos[-1]):
		puntos.remove_at(puntos.size() - 1)
	var area := 0.0
	for indice: int in range(puntos.size()):
		var siguiente := puntos[(indice + 1) % puntos.size()]
		area += puntos[indice].cross(siguiente)
	if area < 0.0:
		puntos.reverse()
	return puntos


static func _vertice_perfil(punto: Vector2, centro: Vector2, perfil: Vector3) -> Vector3:
	var posicion := centro + (punto - centro) * perfil.x
	return Vector3(posicion.x, posicion.y, perfil.y)


static func _normal_perfil(puntos: PackedVector2Array, indice: int, componente_z: float) -> Vector3:
	var anterior := puntos[(indice - 1 + puntos.size()) % puntos.size()]
	var siguiente := puntos[(indice + 1) % puntos.size()]
	var tangente := (siguiente - anterior).normalized()
	var normal := Vector3(tangente.y, -tangente.x, 0.0)
	return normal * sqrt(maxf(0.0, 1.0 - componente_z * componente_z)) + Vector3.BACK * componente_z


static func _tubo(nombre: String, recorrido: Array[Vector3], radio: float, color: Color) -> MeshInstance3D:
	const SEGMENTOS := 20
	var superficie := SurfaceTool.new()
	superficie.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tangentes: Array[Vector3] = []
	for indice: int in range(recorrido.size()):
		var anterior := recorrido[maxi(0, indice - 1)]
		var siguiente := recorrido[mini(recorrido.size() - 1, indice + 1)]
		tangentes.append((siguiente - anterior).normalized())
	for tramo: int in range(recorrido.size() - 1):
		for segmento: int in range(SEGMENTOS):
			var angulo_a := TAU * float(segmento) / float(SEGMENTOS)
			var angulo_b := TAU * float(segmento + 1) / float(SEGMENTOS)
			var na := _normal_tubo(tangentes[tramo], angulo_a)
			var nb := _normal_tubo(tangentes[tramo], angulo_b)
			var nc := _normal_tubo(tangentes[tramo + 1], angulo_b)
			var nd := _normal_tubo(tangentes[tramo + 1], angulo_a)
			var a := recorrido[tramo] + na * radio
			var b := recorrido[tramo] + nb * radio
			var c := recorrido[tramo + 1] + nc * radio
			var d := recorrido[tramo + 1] + nd * radio
			_triangulo(superficie, a, b, c, na, nb, nc)
			_triangulo(superficie, a, c, d, na, nc, nd)
	for extremo: int in [0, recorrido.size() - 1]:
		var normal := -tangentes[extremo] if extremo == 0 else tangentes[extremo]
		for segmento: int in range(SEGMENTOS):
			var a := recorrido[extremo] + _normal_tubo(tangentes[extremo], TAU * float(segmento) / float(SEGMENTOS)) * radio
			var b := recorrido[extremo] + _normal_tubo(tangentes[extremo], TAU * float(segmento + 1) / float(SEGMENTOS)) * radio
			_triangulo(superficie, recorrido[extremo], a, b, normal, normal, normal)
	return _instancia(nombre, superficie.commit(), color)


static func _normal_tubo(tangente: Vector3, angulo: float) -> Vector3:
	return Vector3(-tangente.y, tangente.x, 0.0) * cos(angulo) + Vector3.BACK * sin(angulo)


static func _triangulo(superficie: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	# Godot considera frontal el orden horario; las normales siguen hacia afuera.
	if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
		_vertice(superficie, a, na)
		_vertice(superficie, c, nc)
		_vertice(superficie, b, nb)
	else:
		_vertice(superficie, a, na)
		_vertice(superficie, b, nb)
		_vertice(superficie, c, nc)


static func _vertice(superficie: SurfaceTool, posicion: Vector3, normal: Vector3) -> void:
	superficie.set_normal(normal.normalized())
	superficie.add_vertex(posicion)
