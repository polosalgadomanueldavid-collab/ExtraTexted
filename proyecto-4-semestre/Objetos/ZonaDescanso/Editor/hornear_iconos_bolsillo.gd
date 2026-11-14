extends SceneTree
## Ejecutar con renderizador: genera cinco PNG transparentes sin cargar la oficina.
const DESTINO := "res://UI/Descanso/Arte/"

func _initialize() -> void:
	_hornear.call_deferred()

func _hornear() -> void:
	var fabrica = load("res://UI/Descanso/panel_expendedora.gd").new()
	var nombres := ["chocolate", "dona", "papa_tiempo", "avatar", "cafe"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DESTINO))
	for i in 5:
		var vista := SubViewport.new()
		vista.size = Vector2i(256, 256)
		vista.own_world_3d = true
		vista.transparent_bg = true
		vista.msaa_3d = Viewport.MSAA_4X
		vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vista)
		var producto: Node3D
		if i < 4:
			producto = fabrica._crear_producto(i)
			producto.rotation_degrees = Vector3(-6, -15, -12 if i == 0 else 8)
		else:
			producto = Node3D.new()
			var taza := MeshInstance3D.new()
			taza.mesh = load("res://Objetos/ZonaDescanso/Mallas/TazaBlanca.res")
			producto.add_child(taza)
			var liquido := MeshInstance3D.new()
			var cilindro := CylinderMesh.new()
			cilindro.top_radius = .028
			cilindro.bottom_radius = .028
			cilindro.height = .002
			liquido.mesh = cilindro
			liquido.position.y = .068
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("49291c")
			liquido.material_override = material
			producto.add_child(liquido)
			producto.scale = Vector3.ONE * 5.5
			producto.position.y = -.20
			producto.rotation_degrees = Vector3(14, -30, -8)
		vista.add_child(producto)
		var camara := Camera3D.new()
		vista.add_child(camara)
		camara.projection = Camera3D.PROJECTION_ORTHOGONAL
		camara.size = .82
		camara.position = Vector3(0, .08, 2)
		camara.look_at(Vector3.ZERO)
		camara.current = true
		var entorno := WorldEnvironment.new()
		entorno.environment = Environment.new()
		entorno.environment.background_mode = Environment.BG_CLEAR_COLOR
		entorno.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		entorno.environment.ambient_light_color = Color("fff1d8")
		entorno.environment.ambient_light_energy = .65
		vista.add_child(entorno)
		var luz := DirectionalLight3D.new()
		luz.rotation_degrees = Vector3(-30, -30, 0)
		luz.light_energy = 1.4
		vista.add_child(luz)
		for cuadro in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		vista.get_texture().get_image().save_png(DESTINO + nombres[i] + ".png")
		vista.queue_free()
	fabrica.free()
	await process_frame
	print("ICONOS_BOLSILLO: 5 PNG generados")
	quit()
