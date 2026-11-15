extends SceneTree
## Vista del modelo compartido. Sin --headless guarda .godot/vista_llave.png.

func _initialize() -> void:
	_mostrar.call_deferred()

func _mostrar() -> void:
	root.size = Vector2i(1000, 750)
	var mundo := Node3D.new()
	root.add_child(mundo)
	current_scene = mundo
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_COLOR
	ambiente.environment.background_color = Color("173b50")
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color("c8dfed")
	ambiente.environment.ambient_light_energy = 0.7
	mundo.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-35, -30, 0)
	luz.light_energy = 1.8
	mundo.add_child(luz)
	var llave := preload("res://Scripts/Despacho/modelo_llave.gd").new()
	mundo.add_child(llave)
	var camara := Camera3D.new()
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.size = 0.95
	mundo.add_child(camara)
	camara.position = Vector3(0.7, 0.7, 1.8)
	camara.look_at(Vector3(0, 0.28, 0))
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/vista_llave.png")
	quit()
