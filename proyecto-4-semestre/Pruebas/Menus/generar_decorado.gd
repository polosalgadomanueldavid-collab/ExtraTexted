extends SceneTree
## Generador de desarrollo: nunca se ejecuta al abrir el menú.
## Conserva transformaciones y recursos visibles, sin scripts ni física.
var destino: Node3D
var recursos := {}

func _initialize() -> void:
	var origen := load("res://Mundo/Oficina.tscn").instantiate() as Node3D
	destino = Node3D.new()
	destino.name = "DecoradoOficina"
	for hijo in origen.get_children():
		if hijo.name not in ["Gameplay", "CanvasLayer", "EventoApagon", "TacoLuz", "Computer"]:
			copiar(hijo, destino)
	var frontal := destino.get_node_or_null("Pared, suelo, techo/Pared4")
	if frontal != null:
		frontal.hide()
	var escena := PackedScene.new()
	escena.pack(destino)
	var error := ResourceSaver.save(escena, "res://UI/Menus/DecoradoOficina.scn", ResourceSaver.FLAG_COMPRESS)
	origen.free()
	destino.free()
	print("Decorado guardado: ", error_string(error))
	quit(error)

func recurso_visual(recurso: Resource) -> Resource:
	if recurso == null or not recurso.resource_path.begins_with("res://Mundo/Oficina.tscn"):
		return recurso
	if not recursos.has(recurso):
		var copia := recurso.duplicate(false)
		recursos[recurso] = copia
		for propiedad in copia.get_property_list():
			if int(propiedad.usage) & PROPERTY_USAGE_STORAGE:
				var valor: Variant = copia.get(propiedad.name)
				if valor is Resource:
					copia.set(propiedad.name, recurso_visual(valor))
		if copia is ArrayMesh:
			for i in copia.get_surface_count():
				copia.surface_set_material(i, recurso_visual(copia.surface_get_material(i)))
	return recursos[recurso]

func copiar(origen: Node, padre: Node3D) -> void:
	if not origen is Node3D or origen is CollisionShape3D or origen is Camera3D:
		return
	# Las escenas importadas son solo visuales: conservar su instancia permite
	# compartir mallas/texturas con la oficina, sin duplicarlas en el decorado.
	if origen.scene_file_path.get_extension() in ["glb", "gltf", "obj"]:
		var modelo := load(origen.scene_file_path).instantiate() as Node3D
		modelo.name = origen.name
		modelo.transform = origen.transform
		modelo.visible = origen.visible
		copiar_materiales(origen, modelo)
		padre.add_child(modelo)
		modelo.owner = destino
		return
	var nodo := Node3D.new()
	if origen is CSGShape3D or origen is Sprite3D or origen is Label3D:
		nodo.free()
		nodo = origen.duplicate(0)
		for hijo in nodo.get_children():
			hijo.free()
		nodo.set_script(null)
		if nodo is CSGShape3D:
			nodo.use_collision = false
			if nodo is CSGPrimitive3D:
				nodo.material = recurso_visual(nodo.material)
	elif origen is MeshInstance3D:
		nodo.free()
		nodo = MeshInstance3D.new()
		nodo.mesh = recurso_visual(origen.mesh)
		nodo.material_override = recurso_visual(origen.material_override)
		nodo.cast_shadow = origen.cast_shadow
		nodo.layers = origen.layers
		for i in origen.get_surface_override_material_count():
			nodo.set_surface_override_material(i, recurso_visual(origen.get_surface_override_material(i)))
	elif origen is Light3D:
		nodo.free()
		nodo = origen.duplicate(0)
		for hijo in nodo.get_children():
			hijo.free()
		nodo.set_script(null)
		nodo.shadow_enabled = false
	nodo.name = origen.name
	nodo.transform = origen.transform
	nodo.visible = origen.visible
	padre.add_child(nodo)
	nodo.owner = destino
	for hijo in origen.get_children():
		copiar(hijo, nodo)


func copiar_materiales(origen: Node, modelo: Node) -> void:
	if origen is MeshInstance3D and modelo is MeshInstance3D:
		modelo.material_override = recurso_visual(origen.material_override)
		modelo.layers = origen.layers
		for i in origen.get_surface_override_material_count():
			modelo.set_surface_override_material(i, recurso_visual(origen.get_surface_override_material(i)))
	for hijo in origen.get_children():
		var equivalente := modelo.get_node_or_null(NodePath(hijo.name))
		if equivalente != null:
			copiar_materiales(hijo, equivalente)
