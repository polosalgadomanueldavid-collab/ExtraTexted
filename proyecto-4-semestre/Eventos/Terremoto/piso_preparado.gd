extends Node3D
## Superficie exacta por barrido horizontal. Sin booleanos CSG durante el evento.
## Cada franja termina en una coordenada Z de un vértice: sus bordes son rectos
## y los trapecios cubren solo suelo firme, incluso junto a puntas cóncavas.
var _suelo: CSGBox3D
var _combinador: CSGCombiner3D
var _entero: StaticBody3D
var _roto: StaticBody3D
var _visual: MeshInstance3D
var _limites: Rect2
var _altura: float

func configurar(suelo: CSGBox3D) -> void:
	_suelo = suelo
	_combinador = suelo.get_parent() as CSGCombiner3D
	_altura = suelo.to_global(Vector3.UP * suelo.size.y * .5).y
	var minimo := suelo.to_global(-suelo.size * .5)
	var maximo := suelo.to_global(suelo.size * .5)
	_limites = Rect2(Vector2(minimo.x, minimo.z), Vector2(maximo.x - minimo.x, maximo.z - minimo.z))
	_entero = StaticBody3D.new()
	_entero.name = "PisoEntero"
	var forma := BoxShape3D.new()
	forma.size = suelo.size * suelo.global_basis.get_scale()
	var colision := CollisionShape3D.new()
	colision.shape = forma
	_entero.add_child(colision)
	add_child(_entero)
	_entero.global_position = suelo.global_position
	# La malla CSG intacta se conserva como decorado; su física se prepara
	# una sola vez al cargar. Activar/cerrar solo intercambia capas y dibujo.
	_combinador.use_collision = false

func preparar(grietas: Array, presupuesto: RefCounted) -> void:
	limpiar()
	var contornos: Array[PackedVector2Array] = []
	var niveles: Array[float] = [_limites.position.y, _limites.end.y]
	for grieta in grietas:
		var contorno: PackedVector2Array = grieta._contorno_exterior()
		contornos.append(contorno)
		for punto: Vector2 in contorno: niveles.append(clampf(punto.y, _limites.position.y, _limites.end.y))
	niveles.sort()
	var caras := PackedVector3Array()
	for i in range(niveles.size() - 1):
		await presupuesto.paso()
		if presupuesto.cancelado: return
		var z0 := niveles[i]
		var z1 := niveles[i + 1]
		if z1 - z0 < .000001: continue
		var medio := (z0 + z1) * .5
		var cruces: Array[Vector2] = []
		for contorno in contornos:
			for j in contorno.size():
				var a := contorno[j]
				var b := contorno[(j + 1) % contorno.size()]
				if medio <= minf(a.y, b.y) or medio >= maxf(a.y, b.y): continue
				cruces.append(Vector2(lerpf(a.x, b.x, (z0 - a.y) / (b.y - a.y)), lerpf(a.x, b.x, (z1 - a.y) / (b.y - a.y))))
		cruces.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x + a.y < b.x + b.y)
		var izquierda := Vector2.ONE * _limites.position.x
		for j in range(0, cruces.size(), 2):
			_agregar_trapecio(caras, izquierda, cruces[j], z0, z1)
			izquierda = cruces[j + 1]
		_agregar_trapecio(caras, izquierda, Vector2.ONE * _limites.end.x, z0, z1)
	await presupuesto.paso(2500)
	if presupuesto.cancelado: return
	var datos := SurfaceTool.new()
	datos.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertice: Vector3 in caras:
		datos.set_normal(Vector3.UP)
		datos.add_vertex(vertice)
	_visual = MeshInstance3D.new()
	_visual.mesh = datos.commit()
	_visual.material_override = _suelo.material
	_visual.hide()
	var forma := ConcavePolygonShape3D.new()
	forma.set_faces(caras)
	_roto = StaticBody3D.new()
	_roto.name = "PisoFracturadoPreparado"
	_roto.collision_layer = 0
	_roto.collision_mask = 0
	var colision := CollisionShape3D.new()
	colision.shape = forma
	_roto.add_child(colision)
	_roto.add_child(_visual)
	add_child(_roto)

func _agregar_trapecio(caras: PackedVector3Array, izq: Vector2, der: Vector2, z0: float, z1: float) -> void:
	var a := Vector3(izq.x, _altura, z0)
	var b := Vector3(der.x, _altura, z0)
	var c := Vector3(der.y, _altura, z1)
	var d := Vector3(izq.y, _altura, z1)
	if (b - a).cross(c - a).length_squared() > 1e-14: caras.append_array(PackedVector3Array([a, b, c]))
	if (c - a).cross(d - a).length_squared() > 1e-14: caras.append_array(PackedVector3Array([a, c, d]))

func abrir() -> void:
	_combinador.hide()
	_entero.collision_layer = 0
	_roto.collision_layer = 1
	_visual.show()

func cerrar() -> void:
	_entero.collision_layer = 1
	_combinador.show()
	limpiar()

func limpiar() -> void:
	if is_instance_valid(_roto):
		_roto.collision_layer = 0
		_roto.hide()
		_roto.queue_free()
	_roto = null
	_visual = null
