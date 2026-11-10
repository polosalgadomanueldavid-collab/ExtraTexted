extends SceneTree
## Herramienta de edición: --headless --script res://Objetos/ZonaDescanso/Editor/hornear_sofa_l.gd
## Hornea únicamente las dos mallas del sofá; no se ejecuta durante la partida.

const CARPETA := "res://Objetos/ZonaDescanso/"
const PRECISION := 1000000.0
const POSICION_RETORNO := Vector3(0.3312, 0.0004, 0.331)
var _puntos_esquina: Array[Dictionary] = []
var _distancia_esquina: float = 0.0

func _initialize() -> void:
	_hornear.call_deferred()

func _hornear() -> void:
	var pack := (load("res://Furniture Pack/Furniture Pack.glb") as PackedScene).instantiate()
	var fuente := (pack.get_node("Couch_007") as MeshInstance3D).mesh
	var material := load(CARPETA + "MaterialFurniture.tres") as Material
	var tramo := _preparar_malla(fuente, 1.0, material)
	var retorno := _preparar_malla(fuente, -1.0, material)
	var remate := SurfaceTool.new()
	remate.begin(Mesh.PRIMITIVE_TRIANGLES)
	remate.set_material(material)
	remate.append_from(tramo, 0, Transform3D.IDENTITY)
	_cerrar_corte(remate, _puntos_esquina, Vector3(1, 0, -1), _distancia_esquina)
	remate.index()
	tramo = remate.commit()
	for datos: Array in [["SofaTramo", tramo], ["SofaRetorno", retorno]]:
		var malla := datos[1] as ArrayMesh
		malla.resource_name = str(datos[0])
		var ruta := CARPETA + "Mallas/" + str(datos[0]) + ".res"
		var resultado := ResourceSaver.save(malla, ruta, ResourceSaver.FLAG_COMPRESS)
		assert(resultado == OK, "No se pudo guardar " + ruta)
		print("SOFA HORNEADO ", datos[0], ": ", malla.get_surface_count(), " superficie(s)")
	pack.free()
	quit(0)

func _preparar_malla(fuente: Mesh, lado: float, material: Material) -> ArrayMesh:
	var resultado := ArrayMesh.new()
	for superficie: int in range(fuente.get_surface_count()):
		var arrays := fuente.surface_get_arrays(superficie)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for indice: int in range(vertices.size()):
				indices.append(indice)
		var componentes := _componentes(vertices, indices)
		var bisel_esquina := 0.0
		for limites: AABB in componentes.values():
			if limites.position.y > 0.16 and limites.size.y > 0.20:
				bisel_esquina = POSICION_RETORNO.x - 2.0 * limites.position.z
				_distancia_esquina = bisel_esquina
				break
		var herramienta := SurfaceTool.new()
		herramienta.begin(Mesh.PRIMITIVE_TRIANGLES)
		herramienta.set_material(material)
		var tapas: Dictionary = {}
		for triangulo: int in range(0, indices.size(), 3):
			var limites: AABB = componentes[indices[triangulo]]
			var estructura := limites.position.y < 0.01
			var cojin := limites.position.y > 0.16 and limites.size.y < 0.12 and limites.size.x < 0.20
			var respaldo := limites.position.y > 0.16 and limites.size.y > 0.20
			if cojin and limites.get_center().x * lado > 0.0:
				continue
			var poligono: Array[Dictionary] = []
			for esquina: int in range(3):
				var indice := indices[triangulo + esquina]
				var punto := vertices[indice]
				if respaldo and punto.x * lado > 0.44:
					# Prolonga el extremo biselado hasta el encuentro de los respaldos.
					if lado > 0.0:
						punto.x += POSICION_RETORNO.x - limites.position.z - limites.end.x
					else:
						punto.x += limites.position.z - POSICION_RETORNO.z - limites.position.x
				if lado < 0.0:
					punto.y -= POSICION_RETORNO.y
				poligono.append({"posicion": punto, "normal": arrays[Mesh.ARRAY_NORMAL][indice], "uv": arrays[Mesh.ARRAY_TEX_UV][indice]})
			if estructura:
				var corte_base := POSICION_RETORNO.x if lado > 0.0 else POSICION_RETORNO.z
				poligono = _recortar(poligono, Vector3(lado, 0, 1), corte_base)
				var corte_esquina := bisel_esquina if lado > 0.0 else bisel_esquina - POSICION_RETORNO.x + POSICION_RETORNO.z
				poligono = _recortar(poligono, Vector3(lado, 0, -1), corte_esquina)
				_emitir(herramienta, poligono)
				for vertice: Dictionary in poligono:
					if absf(Vector3(lado, 0, -1).dot(vertice.posicion) - corte_esquina) < 0.000001:
						var punto_remate := vertice.duplicate()
						if lado < 0.0:
							punto_remate.posicion = Basis(Vector3.UP, -PI * 0.5) * (vertice.posicion as Vector3) + POSICION_RETORNO
						_puntos_esquina.append(punto_remate)
				continue
			# Las mitades se encuentran en inglete, sin tapones superpuestos.
			var distancia := POSICION_RETORNO.x if lado > 0.0 else POSICION_RETORNO.z
			poligono = _recortar(poligono, Vector3(lado, 0, 1), distancia)
			_emitir(herramienta, poligono)
			_registrar_tapa(tapas, str(limites.get_center()), poligono, Vector3(lado, 0, 1), distancia)
		for tapa: Dictionary in tapas.values():
			_cerrar_corte(herramienta, tapa.puntos, tapa.normal, tapa.distancia)
		herramienta.index()
		herramienta.commit(resultado)
	return resultado

func _registrar_tapa(tapas: Dictionary, clave: String, poligono: Array[Dictionary], normal: Vector3, distancia: float) -> void:
	for vertice: Dictionary in poligono:
		if absf(normal.dot(vertice.posicion) - distancia) > 0.000001:
			continue
		if not tapas.has(clave):
			tapas[clave] = {"puntos": [], "normal": normal, "distancia": distancia}
		(tapas[clave].puntos as Array).append(vertice)

func _cerrar_corte(herramienta: SurfaceTool, puntos: Array, normal: Vector3, distancia: float) -> void:
	if puntos.size() < 3:
		return
	var n := normal.normalized()
	var eje_x := n.cross(Vector3.UP).normalized() if absf(n.y) < 0.9 else Vector3.RIGHT
	var eje_y := n.cross(eje_x).normalized()
	var proyeccion := PackedVector2Array()
	for punto: Dictionary in puntos:
		var posicion: Vector3 = punto.posicion
		proyeccion.append(Vector2(posicion.dot(eje_x), posicion.dot(eje_y)))
	var contorno := Geometry2D.convex_hull(proyeccion)
	if contorno.size() < 4:
		return
	contorno.remove_at(contorno.size() - 1)
	var origen := normal * (distancia / normal.length_squared())
	var poligono: Array[Dictionary] = []
	for punto: Vector2 in contorno:
		poligono.append({"posicion": origen + eje_x * punto.x + eje_y * punto.y, "normal": n, "uv": puntos[0].uv})
	_emitir(herramienta, poligono)

func _componentes(vertices: PackedVector3Array, indices: PackedInt32Array) -> Dictionary:
	var padres: Array[int] = []
	var posiciones: Dictionary = {}
	for indice: int in range(vertices.size()):
		padres.append(indice)
		var punto := vertices[indice]
		var clave := Vector3i(roundi(punto.x * PRECISION), roundi(punto.y * PRECISION), roundi(punto.z * PRECISION))
		if posiciones.has(clave):
			_unir(padres, indice, int(posiciones[clave]))
		else:
			posiciones[clave] = indice
	for triangulo: int in range(0, indices.size(), 3):
		_unir(padres, indices[triangulo], indices[triangulo + 1])
		_unir(padres, indices[triangulo], indices[triangulo + 2])
	var cajas: Dictionary = {}
	for indice: int in range(vertices.size()):
		var raiz := _raiz(padres, indice)
		cajas[raiz] = (cajas[raiz] as AABB).expand(vertices[indice]) if cajas.has(raiz) else AABB(vertices[indice], Vector3.ZERO)
	var resultado: Dictionary = {}
	for indice: int in range(vertices.size()):
		resultado[indice] = cajas[_raiz(padres, indice)]
	return resultado

func _raiz(padres: Array[int], indice: int) -> int:
	while padres[indice] != indice:
		padres[indice] = padres[padres[indice]]
		indice = padres[indice]
	return indice

func _unir(padres: Array[int], primero: int, segundo: int) -> void:
	padres[_raiz(padres, primero)] = _raiz(padres, segundo)

func _recortar(poligono: Array[Dictionary], normal: Vector3, distancia: float) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	if poligono.is_empty():
		return resultado
	var anterior: Dictionary = poligono[-1]
	var distancia_anterior := normal.dot(anterior.posicion) - distancia
	for actual: Dictionary in poligono:
		var distancia_actual := normal.dot(actual.posicion) - distancia
		if (distancia_anterior <= 0.0) != (distancia_actual <= 0.0):
			var t := distancia_anterior / (distancia_anterior - distancia_actual)
			resultado.append({"posicion": (anterior.posicion as Vector3).lerp(actual.posicion, t), "normal": (anterior.normal as Vector3).lerp(actual.normal, t).normalized(), "uv": (anterior.uv as Vector2).lerp(actual.uv, t)})
		if distancia_actual <= 0.0:
			resultado.append(actual)
		anterior = actual
		distancia_anterior = distancia_actual
	return resultado

func _emitir(herramienta: SurfaceTool, poligono: Array[Dictionary]) -> void:
	for indice: int in range(1, poligono.size() - 1):
		var a: Vector3 = poligono[0].posicion
		var b: Vector3 = poligono[indice].posicion
		var c: Vector3 = poligono[indice + 1].posicion
		if (b - a).cross(c - a).length_squared() < 0.000000000001:
			continue
		for vertice: Dictionary in [poligono[0], poligono[indice], poligono[indice + 1]]:
			herramienta.set_normal(vertice.normal)
			herramienta.set_uv(vertice.uv)
			herramienta.add_vertex(vertice.posicion)
