extends RefCounted
## Montículos sobre las caras superiores reales, sin colisiones adicionales.
## La malla queda unida al mueble para acompañar la caída de los cajones.

const PASO := 0.075
const MARCA := &"nieve_acumulada"
var _plantillas: Dictionary = {}
var _caras: Dictionary = {}
var _superficies: Dictionary = {}
var _extracciones: Dictionary = {}

## Conserva el cursor dentro de cada superficie: una malla grande también
## respeta el presupuesto, en lugar de ceder solo entre muebles completos.
class ExtraccionCaras:
	extends RefCounted
	var malla: Mesh
	var normal_base: Basis
	var caras := PackedVector3Array()
	var superficie := 0
	var indice := 0
	var vertices := PackedVector3Array()
	var normales := PackedVector3Array()
	var indices := PackedInt32Array()
	var cantidad := 0

	func _init(origen: MeshInstance3D) -> void:
		malla = origen.mesh
		normal_base = origen.global_basis.inverse().transposed()

	func avanzar(presupuesto_usec: int) -> bool:
		var limite := Time.get_ticks_usec() + presupuesto_usec
		while superficie < malla.get_surface_count():
			if vertices.is_empty():
				if malla is ArrayMesh and malla.surface_get_primitive_type(superficie) != Mesh.PRIMITIVE_TRIANGLES:
					superficie += 1
					continue
				var datos := malla.surface_get_arrays(superficie)
				vertices = datos[Mesh.ARRAY_VERTEX]
				normales = datos[Mesh.ARRAY_NORMAL] if datos[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
				indices = datos[Mesh.ARRAY_INDEX] if datos[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				cantidad = indices.size() if not indices.is_empty() else vertices.size()
			while indice < cantidad - 2:
				var ia := indices[indice] if not indices.is_empty() else indice
				var ib := indices[indice + 1] if not indices.is_empty() else indice + 1
				var ic := indices[indice + 2] if not indices.is_empty() else indice + 2
				var a := vertices[ia]
				var b := vertices[ib]
				var c := vertices[ic]
				var normal := (normales[ia] + normales[ib] + normales[ic]).normalized() if not normales.is_empty() else (c - a).cross(b - a).normalized()
				if (normal_base * normal).normalized().y >= 0.82:
					caras.append(a)
					caras.append(b)
					caras.append(c)
					caras.append(normal)
				indice += 3
				if presupuesto_usec > 0 and indice % 288 == 0 and Time.get_ticks_usec() >= limite:
					return false
			superficie += 1
			indice = 0
			vertices = PackedVector3Array()
		return true


func preparar_lote(origen: MeshInstance3D, presupuesto_usec := 3000) -> bool:
	if origen.mesh == null or origen.has_meta(MARCA):
		return true
	var limites := Transform3D(origen.global_basis, Vector3.ZERO) * origen.mesh.get_aabb()
	if minf(limites.size.x, limites.size.z) < 0.18 or limites.size.x * limites.size.z < 0.065:
		return true
	var clave := _clave_caras(origen)
	if _caras.has(clave):
		return true
	if not _extracciones.has(clave):
		_extracciones[clave] = ExtraccionCaras.new(origen)
	var trabajo: ExtraccionCaras = _extracciones[clave]
	if not trabajo.avanzar(presupuesto_usec):
		return false
	_caras[clave] = trabajo.caras
	_extracciones.erase(clave)
	return true


func crear(origen: MeshInstance3D, material: Material, solo_preparar := false) -> MeshInstance3D:
	if origen.mesh == null or origen.has_meta(MARCA):
		return null
	var base := origen.global_basis
	var limites := Transform3D(base, Vector3.ZERO) * origen.mesh.get_aabb()
	var ancho := limites.size.x
	var fondo := limites.size.z
	if minf(ancho, fondo) < 0.18 or ancho * fondo < 0.065:
		return null
	# Cuatro siluetas por modelo: los treinta cajones comparten geometría preparada.
	var variante := posmod(hash(String(origen.get_path())), 4)
	var clave := "%d:%s:%d" % [origen.mesh.get_instance_id(), str(base), variante]
	if _plantillas.has(clave):
		return null if solo_preparar else _instanciar(origen, material, _plantillas[clave])
	var azar := RandomNumberGenerator.new()
	azar.seed = 5819 + variante * 103
	var ruido := FastNoiseLite.new()
	ruido.seed = azar.randi()
	ruido.frequency = 2.4
	ruido.fractal_octaves = 2
	var acumulaciones: Array[Vector4] = []
	var alturas: Array[float] = []
	var cantidad := clampi(ceili(ancho * fondo * 2.3), 2, 4)
	var altura := clampf(minf(ancho, fondo) * 0.20, 0.025, 0.13)
	for i in cantidad:
		var esquina := Vector2(0.22 if i % 2 == 0 else 0.76, 0.25 if i < 2 else 0.76)
		esquina += Vector2(azar.randf_range(-0.12, 0.12), azar.randf_range(-0.12, 0.12))
		acumulaciones.append(Vector4(limites.position.x + ancho * esquina.x, limites.position.z + fondo * esquina.y,
			ancho * azar.randf_range(0.27, 0.46), fondo * azar.randf_range(0.32, 0.57)))
		alturas.append(altura * azar.randf_range(0.65, 1.25))
	var constructor := SurfaceTool.new()
	constructor.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangulos := 0
	var soporte := _superficie_superior(origen, limites)
	var puntos: PackedVector3Array = soporte.puntos
	var normales: PackedVector3Array = soporte.normales.duplicate()
	var espesores := PackedFloat32Array()
	espesores.resize(puntos.size())
	for i in puntos.size():
		var p := puntos[i]
		if not p.is_finite():
			continue
		espesores[i] = _altura(p, acumulaciones, alturas, ruido)
		var dx := (_altura(p - Vector3(0.012, 0, 0), acumulaciones, alturas, ruido) - _altura(p + Vector3(0.012, 0, 0), acumulaciones, alturas, ruido)) / 0.024
		var dz := (_altura(p - Vector3(0, 0, 0.012), acumulaciones, alturas, ruido) - _altura(p + Vector3(0, 0, 0.012), acumulaciones, alturas, ruido)) / 0.024
		normales[i] = (normales[i] + Vector3(dx, 0, dz)).normalized()
	for fila: int in soporte.filas:
		for columna: int in soporte.columnas:
			var i: int = fila * (soporte.columnas + 1) + columna
			var j: int = i + soporte.columnas + 1
			triangulos += _triangulo(constructor, [i, i + 1, j], puntos, normales, espesores)
			triangulos += _triangulo(constructor, [i + 1, j + 1, j], puntos, normales, espesores)
	if triangulos == 0:
		_plantillas[clave] = null
		return null
	constructor.index()
	var malla := constructor.commit()
	_plantillas[clave] = malla
	return null if solo_preparar else _instanciar(origen, material, malla)


func _superficie_superior(origen: MeshInstance3D, limites: AABB) -> Dictionary:
	var base := origen.global_basis
	var clave := "%d:%s" % [origen.mesh.get_instance_id(), str(base)]
	if _superficies.has(clave):
		return _superficies[clave]
	var columnas := clampi(ceili(limites.size.x / PASO), 2, 40)
	var filas := clampi(ceili(limites.size.z / PASO), 2, 40)
	var paso := Vector2(limites.size.x / columnas, limites.size.z / filas)
	var esquina := Vector2(limites.position.x, limites.position.z)
	var puntos := PackedVector3Array()
	var normales := PackedVector3Array()
	puntos.resize((columnas + 1) * (filas + 1))
	normales.resize(puntos.size())
	puntos.fill(Vector3(0, -INF, 0))
	var caras := _caras_superiores(origen)
	var normal_base := base.inverse().transposed()
	# Proyectar solo las caras de arriba sobre una rejilla: la complejidad de la
	# nieve no depende de los miles de polígonos del modelo importado.
	for i in range(0, caras.size(), 4):
		var a := base * caras[i]
		var b := base * caras[i + 1]
		var c := base * caras[i + 2]
		var normal := (normal_base * caras[i + 3]).normalized()
		if normal.y < 0.82 or minf(a.y, minf(b.y, c.y)) < limites.end.y - 0.04:
			continue
		var pa := Vector2(a.x, a.z)
		var ab := Vector2(b.x, b.z) - pa
		var ac := Vector2(c.x, c.z) - pa
		var determinante := ab.cross(ac)
		if absf(determinante) < 0.000001:
			continue
		var minimo := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z)))
		var maximo := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z)))
		var desde := Vector2i(((minimo - esquina) / paso).floor())
		var hasta := Vector2i(((maximo - esquina) / paso).ceil())
		for fila in range(maxi(0, desde.y), mini(filas, hasta.y) + 1):
			for columna in range(maxi(0, desde.x), mini(columnas, hasta.x) + 1):
				var p := esquina + Vector2(columna, fila) * paso
				var u := (p - pa).cross(ac) / determinante
				var v := ab.cross(p - pa) / determinante
				if u < -0.001 or v < -0.001 or u + v > 1.001:
					continue
				var altura := a.y + (b.y - a.y) * u + (c.y - a.y) * v
				var indice := fila * (columnas + 1) + columna
				if altura > puntos[indice].y:
					puntos[indice] = Vector3(p.x, altura, p.y)
					normales[indice] = normal
	var resultado := {"columnas": columnas, "filas": filas, "puntos": puntos, "normales": normales}
	_superficies[clave] = resultado
	return resultado


func _clave_caras(origen: MeshInstance3D) -> String:
	var normal_base := origen.global_basis.inverse().transposed()
	var eje := Vector3(normal_base.x.y, normal_base.y.y, normal_base.z.y).normalized().snapped(Vector3.ONE * 0.001)
	return "%d:%s" % [origen.mesh.get_instance_id(), str(eje)]


func _caras_superiores(origen: MeshInstance3D) -> PackedVector3Array:
	var clave := _clave_caras(origen)
	if _caras.has(clave):
		return _caras[clave]
	var trabajo := ExtraccionCaras.new(origen)
	trabajo.avanzar(0)
	_caras[clave] = trabajo.caras
	return trabajo.caras


static func _instanciar(origen: MeshInstance3D, material: Material, malla: Mesh) -> MeshInstance3D:
	if malla == null:
		return null
	var nieve := MeshInstance3D.new()
	nieve.name = "MonticulosNieve"
	nieve.set_meta(MARCA, true)
	nieve.mesh = malla
	nieve.material_override = material
	origen.add_child(nieve)
	# Vértices en metros y ejes del mundo; conservar el anclaje al modelo original.
	nieve.basis = origen.global_basis.inverse()
	return nieve


static func _altura(p: Vector3, monticulos: Array[Vector4], alturas: Array[float], ruido: FastNoiseLite) -> float:
	var altura := 0.0
	var variacion := ruido.get_noise_2d(p.x, p.z)
	for i in monticulos.size():
		var m := monticulos[i]
		var radio := Vector2((p.x - m.x) / m.z, (p.z - m.y) / m.w).length_squared()
		var perfil := maxf(0.0, exp(-radio * 1.65) * (1.0 + variacion * 0.12) - 0.18) / 0.82
		altura = maxf(altura, pow(perfil, 1.20) * alturas[i])
	return altura


static func _triangulo(constructor: SurfaceTool, indices: Array, puntos: PackedVector3Array,
		normales: PackedVector3Array, espesores: PackedFloat32Array) -> int:
	for i: int in indices:
		if not puntos[i].is_finite():
			return 0
	if maxf(espesores[indices[0]], maxf(espesores[indices[1]], espesores[indices[2]])) < 0.002:
		return 0
	for i: int in indices:
		var p: Vector3 = puntos[i]
		constructor.set_normal(normales[i])
		constructor.set_uv(Vector2(p.x, p.z))
		constructor.set_uv2(Vector2(p.y + 0.002, espesores[i]))
		constructor.add_vertex(p + Vector3.UP * (espesores[i] + 0.002))
	return 1
