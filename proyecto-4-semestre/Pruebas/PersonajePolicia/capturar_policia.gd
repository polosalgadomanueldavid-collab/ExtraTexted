extends SceneTree
## Revisión visual reproducible. Ejecutar sin --headless, con --windowed --resolution 1280x720.
## Godot --path <proyecto> --script res://Pruebas/PersonajePolicia/capturar_policia.gd -- <carpeta_salida>

func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i.ZERO
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else OS.get_user_data_dir().path_join("revision_policia")
	DirAccess.make_dir_recursive_absolute(output)
	var lab := load("res://Pruebas/PersonajePolicia/PruebaPoliciaAzul.tscn").instantiate() as Node3D
	root.add_child(lab)
	current_scene = lab
	for frame in 30:
		await process_frame
	var player := lab.get_node("PoliciaAzul") as CharacterBody3D
	player.set_physics_process(false)
	var animator := player.get("animation_player") as AnimationPlayer
	await _save(output.path_join("01_plataforma.png"))
	lab.call("_set_view", 0.0)
	await _save(output.path_join("02_frente.png"))
	lab.call("_set_view", PI * 0.5)
	await _save(output.path_join("03_perfil.png"))
	lab.call("_set_view", PI)
	await _save(output.path_join("04_espalda.png"))
	lab.call("_set_view", 0.35)
	for clip: String in ["walk", "run", "wave"]:
		lab.call("_animation_changed", StringName(clip))
		animator.play(clip, 0.0)
		animator.seek(0.26 if clip != "wave" else 0.65, true)
		animator.pause()
		await _save(output.path_join("pose_" + clip + ".png"))
	print("POLICIA_CAPTURAS_OK: ", output)
	quit()


func _save(path: String) -> void:
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(path)
	if result != OK:
		push_error("No se pudo guardar captura: " + path)
