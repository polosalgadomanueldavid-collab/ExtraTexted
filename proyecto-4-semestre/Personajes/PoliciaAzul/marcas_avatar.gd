extends Node3D
## Marcas y gorra del Avatar; accesorios independientes de las coreografías.
## Observa el reloj del gesto; no modifica el esqueleto, los clips ni los poderes.
const TINTA := preload("res://Personajes/PoliciaAzul/marcas_avatar.gdshader")
var rig: Skeleton3D
var marcas: Array[MeshInstance3D] = []
var materiales: Array[ShaderMaterial] = []
var altura := 0.0
var presencia := 0.0
var originales: Array[Dictionary] = []
var ancla: BoneAttachment3D
var gorra: Node3D
var reposo: Transform3D

func _ready() -> void:
	for zona in 2:
		var tinta := ShaderMaterial.new()
		tinta.shader = TINTA
		tinta.set_shader_parameter("zona", zona)
		materiales.append(tinta)
	reposo = rig.get_bone_global_rest(rig.find_bone("head"))
	ancla = BoneAttachment3D.new()
	ancla.name = "AnclaMarcasAvatar"
	ancla.bone_name = "head"
	rig.add_child(ancla)
	gorra = Node3D.new()
	ancla.add_child(gorra)
	for hijo in rig.get_children():
		if hijo is MeshInstance3D and ("gorra" in String(hijo.name).to_lower() or hijo.name == "Visera"):
			_copiar(hijo, reposo.affine_inverse() * hijo.transform, true)
	var acabado := rig.get_node_or_null("AcabadoUniforme")
	if acabado:
		for hijo in acabado.get_children():
			if hijo.name == "RibeteGorra" or String(hijo.name).begins_with("TrazoPlaca"):
				_copiar(hijo.get_node("Detalle"), hijo.get_node("Detalle").transform, false)
	for hijo in rig.get_children():
		if hijo is MeshInstance3D and hijo.name in ["Cabeza sin rostro", "Chaqueta", "Manga L", "Manga R", "Mano L", "Mano R", "Pantalón continuo", "Cuello trasero", "Cinturón"]:
			_marcar(hijo, Transform3D.IDENTITY, 0 if hijo.name == "Cabeza sin rostro" else 1)
	if acabado:
		for hijo in acabado.get_children():
			if String(hijo.name).begins_with("Botin") or String(hijo.name).begins_with("RibetePuno"):
				var pieza: MeshInstance3D = hijo.get_node("Detalle")
				var espacio := rig.get_bone_global_rest(rig.find_bone(hijo.bone_name)) * pieza.transform
				_marcar(pieza, espacio, 1)
	aplicar(-1.0)

func _copiar(origen: MeshInstance3D, pose: Transform3D, quitar_skin: bool) -> void:
	var copia := MeshInstance3D.new()
	copia.name = origen.name
	if quitar_skin:
		var malla := ArrayMesh.new()
		for i in origen.mesh.get_surface_count():
			var arrays := origen.mesh.surface_get_arrays(i)
			arrays[Mesh.ARRAY_BONES] = null
			arrays[Mesh.ARRAY_WEIGHTS] = null
			malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			malla.surface_set_material(i, origen.get_active_material(i))
		copia.mesh = malla
	else:
		copia.mesh = origen.mesh
		copia.material_override = origen.material_override
	gorra.add_child(copia)
	copia.transform = pose
	originales.append({"nodo": origen, "visible": origen.visible})

func aplicar(fase: float) -> void:
	var activo := fase >= 0.0 and fase < 1.0
	var subida := smoothstep(0.015, 0.145, fase) if activo else 0.0
	var bajada := 1.0 - smoothstep(0.83, 1.0, fase) if activo else 0.0
	var peso := subida * bajada
	altura = peso * (0.64 + sin(fase * TAU * 2.0) * 0.022)
	gorra.position = reposo.basis.inverse() * Vector3.UP * altura
	gorra.visible = activo
	for dato in originales:
		if is_instance_valid(dato.nodo):
			dato.nodo.visible = dato.visible and not activo
	presencia = smoothstep(0.06, 0.17, fase) * (1.0 - smoothstep(0.82, 0.96, fase)) if activo else 0.0
	for marca in marcas:
		marca.visible = presencia > 0.001
	for mat in materiales:
		mat.set_shader_parameter("presencia", presencia)
		mat.set_shader_parameter("pulso", 0.5 + 0.5 * sin(fase * TAU * 2.0))

func _marcar(origen: MeshInstance3D, espacio: Transform3D, zona: int) -> void:
	var copia := MeshInstance3D.new()
	copia.name = "MarcaAvatar"
	# CUSTOM0 conserva la posición de reposo incluso al girar la cabeza o doblar el codo.
	# Las posiciones, índices y pesos importados siguen gobernando la silueta.
	var malla := ArrayMesh.new()
	for superficie in origen.mesh.get_surface_count():
		var arrays := origen.mesh.surface_get_arrays(superficie)
		var puntos: PackedVector3Array = espacio * (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)
		arrays[Mesh.ARRAY_CUSTOM0] = puntos.to_byte_array().to_float32_array()
		malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	copia.mesh = malla
	copia.skin = origen.skin
	copia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	origen.add_child(copia)
	copia.skeleton = copia.get_path_to(rig)
	copia.material_override = materiales[zona]
	marcas.append(copia)

func _exit_tree() -> void:
	for dato in originales:
		if is_instance_valid(dato.nodo):
			dato.nodo.visible = dato.visible
	if is_instance_valid(ancla):
		ancla.queue_free()
	for marca in marcas:
		if is_instance_valid(marca): marca.queue_free()
