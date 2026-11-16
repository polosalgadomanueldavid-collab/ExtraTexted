extends SceneTree
## Herramienta de desarrollo. Conserva posiciones, normales, materiales y LOD
## importados; el marco sin UV usa una base tangente ortogonal determinista.
func _initialize() -> void:
	var escena := load("res://Furniture Pack/MarcoFoto/MarcoFoto.glb").instantiate() as Node3D
	var origen: ArrayMesh = escena.find_child("mesh_node", true, false).mesh
	var salida := ArrayMesh.new()
	var superficies: Array = origen.get("_surfaces")
	for i in origen.get_surface_count():
		var arrays := origen.surface_get_arrays(i)
		var normales: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		if normales.is_empty():
			# Base auxiliar para el GLB sin NORMAL. No sustituir sus normales
			# por normales de caras: cambiaría el acabado del modelo original.
			normales.resize(arrays[Mesh.ARRAY_VERTEX].size())
			normales.fill(Vector3.BACK)
		var tangentes := PackedFloat32Array()
		tangentes.resize(normales.size() * 4)
		for v in normales.size():
			var normal := normales[v].normalized()
			var referencia := Vector3.UP if absf(normal.y) < 0.99 else Vector3.RIGHT
			var tangente := referencia.cross(normal).normalized()
			tangentes[v * 4] = tangente.x
			tangentes[v * 4 + 1] = tangente.y
			tangentes[v * 4 + 2] = tangente.z
			tangentes[v * 4 + 3] = 1.0
		arrays[Mesh.ARRAY_TANGENT] = tangentes
		var lods := {}
		var niveles: Array = superficies[i].get("lods", [])
		var bytes_indice := 2 if normales.size() <= 65536 else 4
		for nivel in range(0, niveles.size(), 2):
			var bytes: PackedByteArray = niveles[nivel + 1]
			var indices := PackedInt32Array()
			indices.resize(bytes.size() / bytes_indice)
			for n in indices.size():
				indices[n] = bytes.decode_u16(n * 2) if bytes_indice == 2 else bytes.decode_u32(n * 4)
			lods[float(niveles[nivel])] = indices
		salida.add_surface_from_arrays(origen.surface_get_primitive_type(i), arrays, [], lods)
		salida.surface_set_material(i, origen.surface_get_material(i))
		salida.surface_set_name(i, origen.surface_get_name(i))
		assert(salida.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] == arrays[Mesh.ARRAY_VERTEX])
		assert(salida.surface_get_arrays(i)[Mesh.ARRAY_INDEX] == arrays[Mesh.ARRAY_INDEX])
	salida.shadow_mesh = origen.shadow_mesh
	var error := ResourceSaver.save(salida, "res://Objetos/MarcoFoto/MarcoConTangentes.res", ResourceSaver.FLAG_COMPRESS)
	escena.free()
	print("[MARCO] posiciones e indices intactos; tangentes y LOD guardados: ", error_string(error))
	quit(error)
