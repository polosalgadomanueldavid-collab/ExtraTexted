extends SceneTree
## Ejecutar: Godot --headless --path <proyecto> --script res://Pruebas/PersonajePolicia/prueba_policia_smoke.gd
## Prueba el recurso importado y el controlador real sobre la plataforma.

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://Pruebas/PersonajePolicia/PruebaPoliciaAzul.tscn") as PackedScene
	if packed == null:
		push_error("No se pudo cargar la escena de prueba.")
		quit(1)
		return
	var lab := packed.instantiate()
	root.add_child(lab)
	current_scene = lab
	await _frames(90)
	var player := lab.get_node("PoliciaAzul") as CharacterBody3D
	_check(player != null, "Personaje instanciado")
	if player == null:
		quit(1)
		return
	_check(player.is_on_floor(), "Colisión con la plataforma al iniciar")
	var spawn := player.global_position
	var animation_player := player.get("animation_player") as AnimationPlayer
	_check(animation_player != null, "AnimationPlayer importado")
	if animation_player != null:
		for clip: String in ["idle", "walk", "run", "jump", "fall", "wave"]:
			var found := false
			for imported: StringName in animation_player.get_animation_list():
				if String(imported).get_file().get_slice("|", String(imported).get_file().get_slice_count("|") - 1).to_lower() == clip:
					var animation := animation_player.get_animation(imported)
					found = animation.length > 0.0 and animation.get_track_count() > 0
					var expected_loop := Animation.LOOP_LINEAR if clip in ["idle", "walk", "run", "fall"] else Animation.LOOP_NONE
					_check(animation.loop_mode == expected_loop, "Repetición correcta: " + clip)
			_check(found, "Clip con pistas: " + clip)
	var skeletons := player.find_children("*", "Skeleton3D", true, false)
	_check(not skeletons.is_empty(), "Esqueleto importado")
	var skeleton := skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	if not skeletons.is_empty():
		_check(skeleton.get_bone_count() >= 15, "Rig de cuerpo y extremidades")
	var has_skin := false
	for node: Node in player.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).skin != null:
			has_skin = true
	_check(has_skin, "Malla vinculada al rig")
	# El reposo debe seguir reproduciéndose después de terminar su primera vuelta.
	await _frames(180)
	_check(animation_player != null and animation_player.is_playing(), "Ciclo de reposo continuo")

	Input.action_press(&"policia_prueba_adelante")
	await _frames(40)
	var walk_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_check(player.global_position.distance_to(spawn) > 0.5, "Desplazamiento al caminar")
	_check(player.get("current_animation") == &"walk", "Animación de caminar")
	await _frames(30)
	_check(animation_player != null and animation_player.is_playing(), "Ciclo de caminar continuo")
	Input.action_press(&"policia_prueba_correr")
	await _frames(50)
	_check(Vector2(player.velocity.x, player.velocity.z).length() > walk_speed * 1.5, "Correr aumenta la velocidad")
	_check(player.get("current_animation") == &"run", "Animación de correr")
	_check(animation_player != null and animation_player.is_playing(), "Ciclo de correr continuo")
	Input.action_release(&"policia_prueba_adelante")
	Input.action_release(&"policia_prueba_correr")
	await _frames(30)
	_check(Vector2(player.velocity.x, player.velocity.z).length() < 0.05, "Frenado al soltar las teclas")
	player.call("reset_to_spawn")
	await _frames(3)
	_check(player.global_position.distance_to(spawn) < 0.1, "Reinicio al punto inicial")

	Input.action_press(&"policia_prueba_saltar")
	await _frames(3)
	Input.action_release(&"policia_prueba_saltar")
	_check(player.velocity.y > 0.0 and player.global_position.y > spawn.y + 0.05, "Salto físico")
	_check(player.get("current_animation") == &"jump", "Animación de salto")
	await _frames(35)
	_check(player.get("current_animation") == &"fall", "Animación de caída")
	await _frames(55)
	_check(player.is_on_floor(), "Aterrizaje en la plataforma")
	var before_wave: Array[Quaternion] = []
	if skeleton != null:
		for bone: int in skeleton.get_bone_count():
			before_wave.append(skeleton.get_bone_pose_rotation(bone))
	player.call("play_wave")
	await _frames(18)
	_check(player.get("current_animation") == &"wave", "Saludo reproducible")
	if skeleton != null:
		var pose_changed := false
		for bone: int in skeleton.get_bone_count():
			if before_wave[bone].angle_to(skeleton.get_bone_pose_rotation(bone)) > 0.05:
				pose_changed = true
		_check(pose_changed, "La animación modifica las articulaciones del rig")
	await _frames(120)
	_check(player.get("current_animation") == &"idle", "El saludo termina y vuelve a reposo")
	player.set("input_locked", true)
	Input.action_press(&"policia_prueba_adelante")
	await _frames(15)
	_check(Vector2(player.velocity.x, player.velocity.z).length() < 0.05, "Bloqueo de entrada")
	Input.action_release(&"policia_prueba_adelante")
	player.set("input_locked", false)
	player.global_position.y = -15.0
	await _frames(90)
	_check(player.global_position.distance_to(spawn) < 0.1 and player.is_on_floor(), "Recuperación al caer al vacío")

	if _failures.is_empty():
		print("POLICIA_SMOKE_OK: modelo, rig, seis clips, movimiento, carrera, salto, aterrizaje, saludo y recuperación.")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("POLICIA_SMOKE: " + failure)
		quit(1)


func _frames(count: int) -> void:
	for frame: int in count:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
