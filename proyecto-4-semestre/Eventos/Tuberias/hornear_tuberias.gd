extends SceneTree
## Herramienta de autoría: extrae la compuerta abierta y separa el tramo que se rompe.
## Godot --headless --path <proyecto> --script res://Eventos/Tuberias/hornear_tuberias.gd
## Los originales GLB se conservan. Las mallas se preparan una vez, nunca al jugar.

func _initialize() -> void:
	for nitrogeno: bool in [false, true]:
		_hornear(nitrogeno)
	quit()


func _hornear(nitrogeno: bool) -> void:
	var archivo := "TuberiaNitrogeno" if nitrogeno else "CompuertaAzulTuberias"
	var original: Node3D = load("res://Furniture Pack/Compuertas/" + archivo + ".glb").instantiate()
	var fuente := original.find_child("*", true, false) as MeshInstance3D
	var escala := 0.66 if nitrogeno else 1.32
	var centro := Vector3(-0.003, -0.002, -0.510) if nitrogeno else Vector3(-0.524, -0.009, -0.439)
	var pivote := Vector3(0.08, -0.015, 0.25) if nitrogeno else Vector3(-0.55, -0.01, -0.13)
	var salida := Vector3(0.08, -0.015, 0.15) if nitrogeno else Vector3(-0.55, 0.13, -0.12)
	var escena := Node3D.new()
	escena.name = "ModeloNitrogeno" if nitrogeno else "ModeloAgua"
	var tramo := Node3D.new()
	tramo.name = "Tramo"
	tramo.position = (pivote - centro) * escala
	escena.add_child(tramo)
	tramo.owner = escena
	var marcador := Marker3D.new()
	marcador.name = "Salida"
	marcador.position = (salida - centro) * escala
	escena.add_child(marcador)
	marcador.owner = escena
	# La puerta llega abierta y fusionada con el gabinete. Guardarla cerrada,
	# alrededor de una bisagra real, permite animarla igual que el taco de luz.
	var bisagra_original := Vector3(-0.735, 0, -0.045)
	var bisagra_cerrada := Vector3(-0.755, 0, 0.015)
	var deshacer_apertura := Basis(Vector3.UP, deg_to_rad(112.0))
	var puerta: Node3D
	var constructores: Array[SurfaceTool] = [SurfaceTool.new(), SurfaceTool.new()]
	if not nitrogeno:
		puerta = Node3D.new()
		puerta.name = "PuertaPivot"
		puerta.position = (bisagra_cerrada - centro) * escala
		escena.add_child(puerta)
		puerta.owner = escena
		constructores.append(SurfaceTool.new())
	for st in constructores:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(fuente.mesh.surface_get_material(0))
	var arrays := fuente.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normales: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for t in range(0, indices.size(), 3):
		var p := (vertices[indices[t]] + vertices[indices[t + 1]] + vertices[indices[t + 2]]) / 3.0
		if not nitrogeno and p.x > 0.0:
			continue # La otra mitad del archivo es una variante cerrada independiente.
		var movil := (p.x > -0.15 and p.x < 0.35 and p.y > -0.23 and p.y < 0.23 and p.z > 0.10) if nitrogeno else (p.x > -0.64 and p.x < -0.46 and p.y > -0.16 and p.y < 0.14 and p.z > -0.24)
		var poligono: Array[Dictionary] = []
		for k in 3:
			var i := indices[t + k]
			poligono.append({"p": vertices[i], "n": normales[i], "uv": uv[i]})
		if not nitrogeno and p.x < -0.69:
			# Corte exacto en el plano de la bisagra: evita dientes y huecos
			# producidos al repartir triángulos completos por su centro.
			_agregar(constructores[2], _cortar_z(poligono, true), bisagra_original, escala, deshacer_apertura, true)
			_agregar(constructores[0], _cortar_z(poligono, false), centro, escala)
		else:
			_agregar(constructores[1 if movil else 0], poligono, pivote if movil else centro, escala)

	for i in constructores.size():
		var st := constructores[i]
		st.generate_tangents()
		st.index()
		var mesh := MeshInstance3D.new()
		mesh.name = "Puerta" if i == 2 else ("Pieza" if i == 1 else "Cuerpo")
		mesh.mesh = st.commit()
		(puerta if i == 2 else (tramo if i == 1 else escena)).add_child(mesh)
		mesh.owner = escena
	if not nitrogeno:
		var metal := StandardMaterial3D.new()
		metal.albedo_color = Color("315e77")
		metal.metallic = 0.55
		metal.roughness = 0.65
		for y: float in [-0.27, 0.27]:
			var bisagra := MeshInstance3D.new()
			bisagra.name = "BisagraBaja" if y < 0 else "BisagraAlta"
			var eje := CylinderMesh.new()
			eje.top_radius = 0.017 * escala
			eje.bottom_radius = eje.top_radius
			eje.height = 0.12 * escala
			eje.radial_segments = 10
			bisagra.mesh = eje
			bisagra.material_override = metal
			bisagra.position = (bisagra_cerrada + Vector3(0, y, 0.01) - centro) * escala
			escena.add_child(bisagra)
			bisagra.owner = escena
	var packed := PackedScene.new()
	packed.pack(escena)
	var ruta := "res://Eventos/Tuberias/" + ("Nitrogeno" if nitrogeno else "Agua") + ".scn"
	var error := ResourceSaver.save(packed, ruta, ResourceSaver.FLAG_COMPRESS)
	print("HORNEADO ", ruta, " ", error_string(error))
	escena.free()
	original.free()


func _cortar_z(poligono: Array[Dictionary], delante: bool) -> Array[Dictionary]:
	var salida: Array[Dictionary] = []
	for i in poligono.size():
		var a := poligono[i]
		var b := poligono[(i + 1) % poligono.size()]
		var dentro_a: bool = a.p.z >= 0.0 if delante else a.p.z <= 0.0
		var dentro_b: bool = b.p.z >= 0.0 if delante else b.p.z <= 0.0
		if dentro_a:
			salida.append(a)
		if dentro_a != dentro_b:
			var peso: float = -a.p.z / (b.p.z - a.p.z)
			salida.append({"p": a.p.lerp(b.p, peso), "n": a.n.lerp(b.n, peso).normalized(), "uv": a.uv.lerp(b.uv, peso)})
	return salida


func _agregar(st: SurfaceTool, poligono: Array[Dictionary], origen: Vector3, escala: float,
		rotacion := Basis.IDENTITY, tapa := false) -> void:
	for triangulo in range(1, poligono.size() - 1):
		for i: int in [0, triangulo, triangulo + 1]:
			var dato := poligono[i]
			var vertice: Vector3 = dato.p - origen
			var normal: Vector3 = dato.n
			if tapa:
				vertice = rotacion * vertice
				vertice.x *= 1.30
				vertice.y = (vertice.y - 0.035) * 1.20
				normal = rotacion * normal
				normal.x /= 1.30
				normal.y /= 1.20
			st.set_normal(normal.normalized())
			st.set_uv(dato.uv)
			st.add_vertex(vertice * escala)
