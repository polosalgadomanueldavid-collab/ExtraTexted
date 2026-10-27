extends Node3D
## Laboratorio independiente: no sustituye al jugador ni la escena principal.

const CAMERA_YAW := 0.52
const CAMERA_PITCH := 0.28
const CAMERA_DISTANCE := 7.8
const ACTION_RESET := &"policia_prueba_reset"

@onready var policia: CharacterBody3D = $PoliciaAzul
@onready var camera: Camera3D = $Camara
@onready var animation_label: Label = %EstadoAnimacion
@onready var speed_label: Label = %Velocidad
@onready var contact_shadow: MeshInstance3D = $SombraContacto

var _yaw: float = CAMERA_YAW
var _pitch: float = CAMERA_PITCH
var _distance: float = CAMERA_DISTANCE
var _camera_target := Vector3(0.0, 1.32, 0.0)
var _orbiting := false


func _ready() -> void:
	get_window().title = "Policía azul · Prueba de personaje"
	get_viewport().msaa_3d = Viewport.MSAA_4X
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not InputMap.has_action(ACTION_RESET):
		InputMap.add_action(ACTION_RESET)
		var key := InputEventKey.new()
		key.physical_keycode = KEY_R
		InputMap.action_add_event(ACTION_RESET, key)
	%VistaFrente.pressed.connect(_set_view.bind(0.0))
	%VistaPerfil.pressed.connect(_set_view.bind(PI * 0.5))
	%VistaEspalda.pressed.connect(_set_view.bind(PI))
	%Centrar.pressed.connect(reset_scene)
	%Saludar.pressed.connect(_wave)
	policia.connect("animation_state_changed", _animation_changed)
	_animation_changed(&"idle")
	_update_camera(1.0)


func _process(delta: float) -> void:
	_update_camera(1.0 - exp(-7.0 * delta))
	_update_contact_shadow()
	var horizontal_speed := Vector2(policia.velocity.x, policia.velocity.z).length()
	speed_label.text = "%0.1f m/s" % horizontal_speed
	# Una caída fuera del borde siempre permite volver a probar inmediatamente.
	if policia.global_position.y < -7.0:
		reset_scene()


func _update_contact_shadow() -> void:
	# Sombras direccionales y spot producen bandas de color en Compatibility/AMD.
	# Esta sombra de contacto local conserva el color y se desvanece al saltar.
	var height := maxf(0.0, policia.global_position.y)
	contact_shadow.position = Vector3(policia.position.x, 0.009, policia.position.z)
	contact_shadow.visible = Vector2(policia.position.x, policia.position.z).length() < 6.4 and policia.position.y > -0.2
	contact_shadow.scale = Vector3.ONE * (1.0 + height * 0.2)
	var material := contact_shadow.mesh.surface_get_material(0) as ShaderMaterial
	material.set_shader_parameter("opacity", 0.28 / (1.0 + height))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_RESET) and not event.is_echo():
		reset_scene()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _orbiting else Input.MOUSE_MODE_VISIBLE
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = clampf(_distance - 0.5, 4.0, 14.0)
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clampf(_distance + 0.5, 4.0, 14.0)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _orbiting:
		_yaw -= event.relative.x * 0.006
		_pitch = clampf(_pitch + event.relative.y * 0.005, -0.05, 1.15)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_release_mouse()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_mouse()


func _release_mouse() -> void:
	_orbiting = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _update_camera(weight: float) -> void:
	var target := policia.global_position + Vector3(0.0, 1.32, 0.0)
	_camera_target = _camera_target.lerp(target, weight)
	var offset := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance
	camera.global_position = _camera_target + offset
	camera.look_at(_camera_target, Vector3.UP)


func _set_view(angle: float) -> void:
	# Las vistas siguen el frente real del muñeco incluso después de moverlo.
	var visual := policia.get_node("Visual") as Node3D
	_yaw = visual.global_rotation.y + angle
	_pitch = 0.12
	_distance = 6.6
	_release_mouse()


func _wave() -> void:
	policia.call("play_wave")


func reset_scene() -> void:
	policia.call("reset_to_spawn")
	_yaw = CAMERA_YAW
	_pitch = CAMERA_PITCH
	_distance = CAMERA_DISTANCE
	_camera_target = policia.global_position + Vector3(0.0, 1.32, 0.0)
	_release_mouse()
	_update_camera(1.0)


func _animation_changed(animation: StringName) -> void:
	var names := {
		&"idle": "En reposo", &"walk": "Caminando", &"run": "Corriendo",
		&"jump": "Saltando", &"fall": "En el aire", &"wave": "Saludando"
	}
	animation_label.text = str(names.get(animation, animation))
