extends Node3D
## Llave ajustable de silueta abierta, acero facetado y empuñadura de goma.
## Se comparte entre la herramienta recogible y el gesto de reparación.

func _ready() -> void:
	var acero := _material(Color("b7d1dc"), 0.72, 0.28)
	var oscuro := _material(Color("254452"), 0.25, 0.65)
	var coral := _material(Color("f17a60"), 0.05, 0.55)
	var brillo := _material(Color("ecf5ee"), 0.55, 0.25)
	# El hueco de la boca forma parte del contorno, no es una mancha pintada.
	_prisma(PackedVector2Array([
		Vector2(-0.037, 0.06), Vector2(0.037, 0.06),
		Vector2(0.041, 0.29), Vector2(0.108, 0.35),
		Vector2(0.122, 0.44), Vector2(0.096, 0.53),
		Vector2(0.058, 0.55), Vector2(0.043, 0.51),
		Vector2(0.066, 0.43), Vector2(-0.012, 0.405),
		Vector2(-0.045, 0.485), Vector2(-0.084, 0.48),
		Vector2(-0.107, 0.44), Vector2(-0.106, 0.37),
		Vector2(-0.067, 0.32), Vector2(-0.04, 0.29)
	]), 0.064, acero)
	var mango := CapsuleMesh.new()
	mango.radius = 0.047
	mango.height = 0.245
	mango.radial_segments = 12
	mango.rings = 4
	_pieza(mango, Vector3(0, 0.18, 0), oscuro).scale.z = 0.76
	for i in 5:
		_caja(Vector3(0, 0.10 + i * 0.035, 0), Vector3(0.086, 0.009, 0.073), coral)
	# Ojal en el extremo y casquillo de unión al cabezal.
	var aro := TorusMesh.new()
	aro.inner_radius = 0.024
	aro.outer_radius = 0.046
	aro.rings = 16
	aro.ring_segments = 8
	_pieza(aro, Vector3(0, 0.035, 0), acero).rotation.x = PI / 2.0
	_caja(Vector3(0, 0.30, 0), Vector3(0.084, 0.021, 0.075), brillo)
	_caja(Vector3(0.012, 0.361, 0), Vector3(0.10, 0.046, 0.073), oscuro)
	var tornillo := CylinderMesh.new()
	tornillo.top_radius = 0.021
	tornillo.bottom_radius = 0.021
	tornillo.height = 0.07
	tornillo.radial_segments = 12
	for lado in [-1.0, 1.0]:
		_pieza(tornillo, Vector3(0.012, 0.362, lado * 0.04), acero).rotation.z = PI / 2.0
		for i in 5:
			_caja(Vector3(-0.014 + i * 0.013, 0.362, lado * 0.04), Vector3(0.004, 0.045, 0.047), brillo)
	# Dos caras decoradas para que la pieza se lea al girar en la mano.
	for lado in [-1.0, 1.0]:
		_caja(Vector3(0, 0.22, lado * 0.038), Vector3(0.037, 0.071, 0.004), coral)
		_caja(Vector3(0, 0.22, lado * 0.041), Vector3(0.009, 0.039, 0.003), brillo)

func _material(color: Color, metal: float, rugosidad: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = rugosidad
	return material

func _pieza(malla: Mesh, posicion: Vector3, material: Material) -> MeshInstance3D:
	var pieza := MeshInstance3D.new()
	pieza.mesh = malla
	pieza.position = posicion
	pieza.material_override = material
	add_child(pieza)
	return pieza

func _caja(posicion: Vector3, tamano: Vector3, material: Material) -> void:
	var malla := BoxMesh.new()
	malla.size = tamano
	_pieza(malla, posicion, material)

func _prisma(contorno: PackedVector2Array, grosor: float, material: Material) -> void:
	var triangulos := Geometry2D.triangulate_polygon(contorno)
	var superficie := SurfaceTool.new()
	superficie.begin(Mesh.PRIMITIVE_TRIANGLES)
	superficie.set_smooth_group(-1)
	for lado in [-1.0, 1.0]:
		for i in range(0, triangulos.size(), 3):
			for paso in ([0, 1, 2] if lado < 0 else [2, 1, 0]):
				var p := contorno[triangulos[i + paso]]
				superficie.add_vertex(Vector3(p.x, p.y, lado * grosor * 0.5))
	for i in contorno.size():
		var a := contorno[i]
		var b := contorno[(i + 1) % contorno.size()]
		var vertices := [Vector3(a.x, a.y, -grosor / 2), Vector3(b.x, b.y, -grosor / 2), Vector3(b.x, b.y, grosor / 2), Vector3(a.x, a.y, grosor / 2)]
		for indice in [0, 2, 1, 0, 3, 2]:
			superficie.add_vertex(vertices[indice])
	superficie.generate_normals()
	_pieza(superficie.commit(), Vector3.ZERO, material)
