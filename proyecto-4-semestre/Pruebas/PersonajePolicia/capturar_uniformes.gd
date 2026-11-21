extends SceneTree
## Capturas transparentes de las tres escenas reales y sus accesorios animados.
## Godot --path <proyecto> --script res://Pruebas/PersonajePolicia/capturar_uniformes.gd -- <salida>
const MODELOS := ["res://Personajes/PoliciaAzul/ModeloAzul.tscn", "res://Personajes/PoliciaRelevo/ModeloRelevo.tscn", "res://Personajes/PoliciaRelevo/ModeloVioleta.tscn"]

func _initialize() -> void:
	capturar.call_deferred()

func capturar() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(64, 64)
	var salida := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(salida)
	var vista := SubViewport.new()
	vista.size = Vector2i(400, 500)
	vista.transparent_bg = true
	vista.own_world_3d = true
	vista.msaa_3d = Viewport.MSAA_4X
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vista)
	var mundo := Node3D.new()
	vista.add_child(mundo)
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_CLEAR_COLOR
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color(0.83, 0.88, 1)
	ambiente.environment.ambient_light_energy = 0.5
	ambiente.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	mundo.add_child(ambiente)
	for dato: Vector3 in [Vector3(-35, -35, 1.2), Vector3(-20, 125, 0.8), Vector3(-65, -160, 0.6)]:
		var luz := DirectionalLight3D.new()
		luz.rotation_degrees = Vector3(dato.x, dato.y, 0)
		luz.light_energy = dato.z
		mundo.add_child(luz)
	var camara := Camera3D.new()
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.size = 3.1
	mundo.add_child(camara)
	for i in MODELOS.size():
		vista.size = Vector2i(400, 500)
		camara.size = 3.1
		var modelo: Node3D = load(MODELOS[i]).instantiate()
		mundo.add_child(modelo)
		var rig := modelo.get_node("Rig/Skeleton3D") as Skeleton3D
		assert(rig.get_bone_count() >= 17)
		assert(rig.has_node("AcabadoUniforme"))
		var animador := modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
		assert(animador.has_animation("walk") and animador.has_animation("wave"))
		var puno := rig.get_node("AcabadoUniforme/RibetePunoR") as BoneAttachment3D
		await process_frame
		var mano_inicial := puno.global_position
		for v in 4:
			var angulo: float = [0.0, 0.50, PI, 0.50][v]
			camara.position = Vector3(sin(angulo) * 5, 2.30, cos(angulo) * 5)
			camara.look_at(Vector3(0, 1.36, 0))
			if v == 3:
				animador.play("wave")
				animador.seek(0.65, true)
				animador.pause()
			for cuadro in 4:
				await process_frame
			if v == 3:
				assert(puno.global_position.distance_to(mano_inicial) > 0.1, "El puño debe seguir la mano al saludar")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				assert(vista.get_texture().get_image().save_png(salida.path_join("policia_%d_%d.png" % [i, v])) == OK)
		if DisplayServer.get_name() != "headless":
			animador.stop()
			vista.size = Vector2i(384, 384)
			camara.size = 1.78
			camara.position = Vector3(0, 2.15, 5)
			camara.look_at(Vector3(0, 1.93, 0))
			for cuadro in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			assert(vista.get_texture().get_image().save_png(salida.path_join("retrato_%d.png" % i)) == OK)
		modelo.queue_free()
		await process_frame
	print("UNIFORMES_OK: tres rigs, accesorios y saludo")
	quit()
