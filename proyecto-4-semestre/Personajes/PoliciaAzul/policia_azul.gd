extends CharacterBody3D
class_name Player
## Controlador independiente para la escena de pruebas del policía azul.
## El modelo mira hacia +Z y sus pies están en el origen de la escena.

signal animation_state_changed(animation: StringName)
signal reset_performed

const LEFT := &"policia_prueba_izquierda"
const RIGHT := &"policia_prueba_derecha"
const FORWARD := &"policia_prueba_adelante"
const BACK := &"policia_prueba_atras"
const RUN := &"policia_prueba_correr"
const JUMP := &"policia_prueba_saltar"
const WAVE := &"policia_prueba_saludar"

@export_category("Movimiento")
@export var walk_speed: float = 2.0
@export var run_speed: float = 4.0
@export var acceleration: float = 12.0
@export var braking: float = 16.0
@export var turn_speed: float = 12.0
@export var jump_velocity: float = 5.2
@export var camera_path: NodePath
@export var input_locked: bool = false
@export var interaction_action: StringName = &"Interactuar"
@export_range(0.1, 2.0, 0.05) var character_scale: float = 0.3
@export_category("Animación")
@export var blend_time: float = 0.15

var animation_player: AnimationPlayer
var current_animation: StringName = &""
var _spawn_transform: Transform3D
var _spawn_visual_rotation: Vector3
var _wave_remaining: float = 0.0
var _animation_names: Dictionary = {}
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

@onready var visual: Node3D = $Visual
@onready var shape_cast_3d: ShapeCast3D = $Visual/ShapeCast3D


func _enter_tree() -> void:
	add_to_group("player")


func _ready() -> void:
	# La escena de Oficina instancia este personaje y puede conservar el scale
	# de la instancia. Aplicarlo aquí garantiza el tamaño también durante el juego.
	scale = Vector3.ONE * character_scale
	_spawn_transform = global_transform
	_spawn_visual_rotation = visual.rotation
	_register_inputs()
	animation_player = $Visual/Modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player == null:
		push_warning("PoliciaAzul: el modelo necesita un AnimationPlayer.")
	else:
		for clip: StringName in [&"idle", &"walk", &"run", &"jump", &"fall", &"wave"]:
			for imported_name: StringName in animation_player.get_animation_list():
				# Admite tanto nombres simples como bibliotecas o prefijos de importación.
				var leaf := String(imported_name).get_file().get_slice("|", String(imported_name).get_file().get_slice_count("|") - 1)
				if leaf.to_lower() == String(clip):
					_animation_names[clip] = imported_name
					break
	_play_animation(&"idle")
	if not is_in_group("player"):
		add_to_group("player")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	var input_direction := Vector2.ZERO
	if not input_locked:
		input_direction = Input.get_vector(LEFT, RIGHT, FORWARD, BACK)
	var direction := _camera_relative_direction(input_direction)
	var moving := direction.length_squared() > 0.001
	var running := not input_locked and Input.is_action_pressed(RUN)

	if not input_locked and Input.is_action_just_pressed(JUMP) and is_on_floor():
		_wave_remaining = 0.0
		velocity.y = jump_velocity
	elif not input_locked and Input.is_action_just_pressed(WAVE) and is_on_floor():
		play_wave()
	if moving or input_locked or not is_on_floor():
		_wave_remaining = 0.0
	else:
		_wave_remaining = maxf(0.0, _wave_remaining - delta)

	var target_speed := run_speed if running else walk_speed
	var desired_velocity := direction * target_speed
	var change_rate := acceleration if moving else braking
	velocity.x = move_toward(velocity.x, desired_velocity.x, change_rate * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, change_rate * delta)
	if moving:
		var angle := atan2(direction.x, direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, angle, 1.0 - exp(-turn_speed * delta))

	move_and_slide()
	_update_animation(moving, running)
	# Una caída fuera de la plataforma siempre vuelve al punto inicial.
	if global_position.y < -12.0:
		reset_to_spawn()


func _camera_relative_direction(input_direction: Vector2) -> Vector3:
	if input_direction.is_zero_approx():
		return Vector3.ZERO
	var camera := get_node_or_null(camera_path) as Camera3D if not camera_path.is_empty() else get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(input_direction.x, 0.0, input_direction.y).normalized()
	var right := camera.global_basis.x
	var forward := -camera.global_basis.z
	right.y = 0.0
	forward.y = 0.0
	return (right.normalized() * input_direction.x - forward.normalized() * input_direction.y).normalized()


func _update_animation(moving: bool, running: bool) -> void:
	if not is_on_floor():
		_play_animation(&"jump" if velocity.y > 0.0 else &"fall")
	elif _wave_remaining > 0.0:
		_play_animation(&"wave")
	elif moving or Vector2(velocity.x, velocity.z).length() > 0.15:
		_play_animation(&"run" if running else &"walk")
	else:
		_play_animation(&"idle")


func _play_animation(clip: StringName) -> void:
	if clip == current_animation:
		return
	current_animation = clip
	if animation_player != null and _animation_names.has(clip):
		animation_player.speed_scale = 1.0
		animation_player.play(_animation_names[clip], blend_time)
	animation_state_changed.emit(clip)


func play_wave() -> void:
	if input_locked or not is_on_floor():
		return
	_wave_remaining = 1.8
	if animation_player != null and _animation_names.has(&"wave"):
		_wave_remaining = animation_player.get_animation(_animation_names[&"wave"]).length
		# También permite repetir un saludo que aún está terminando.
		if current_animation == &"wave":
			animation_player.seek(0.0, true)
	_play_animation(&"wave")


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(interaction_action):
		return
	if event is InputEventKey and event.echo:
		return
	var objetivo := obtener_objetivo_interaccion()
	if objetivo is PCStatic:
		input_locked = true
		get_viewport().set_input_as_handled()
		(objetivo as PCStatic).toggle_use()
	elif objetivo is Estacion:
		get_viewport().set_input_as_handled()
		(objetivo as Estacion).interactuar(self)


func obtener_objetivo_interaccion() -> Node3D:
	# La consulta visual y la tecla E comparten alcance, orden y disponibilidad.
	if not is_inside_tree() or input_locked or not is_processing_input():
		return null
	if get_tree().paused:
		return null
	if not is_instance_valid(shape_cast_3d):
		return null

	shape_cast_3d.force_shapecast_update()
	for indice: int in range(shape_cast_3d.get_collision_count()):
		var collider := shape_cast_3d.get_collider(indice) as Node
		var actual := collider
		while actual != null:
			if actual is PCStatic or actual is Estacion:
				return actual as Node3D
			actual = actual.get_parent()
	return null


func reset_to_spawn() -> void:
	global_transform = _spawn_transform
	visual.rotation = _spawn_visual_rotation
	velocity = Vector3.ZERO
	_wave_remaining = 0.0
	_play_animation(&"idle")
	reset_performed.emit()


func _register_inputs() -> void:
	_add_keys(LEFT, [KEY_A, KEY_LEFT])
	_add_keys(RIGHT, [KEY_D, KEY_RIGHT])
	_add_keys(FORWARD, [KEY_W, KEY_UP])
	_add_keys(BACK, [KEY_S, KEY_DOWN])
	_add_keys(RUN, [KEY_SHIFT])
	_add_keys(JUMP, [KEY_SPACE])
	if InputMap.has_action(WAVE):
		InputMap.action_erase_events(WAVE)
	_add_keys(WAVE, [KEY_G])


func _add_keys(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for physical_key: int in keys:
		var key := InputEventKey.new()
		key.physical_keycode = physical_key
		InputMap.action_add_event(action, key)
