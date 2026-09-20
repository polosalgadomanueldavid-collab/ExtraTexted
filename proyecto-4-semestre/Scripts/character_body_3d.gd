extends CharacterBody3D
class_name Player
@export var SPEED: float = 2.0
@export var ACCELERATION: float = 10.0
@export var FRICTION: float = 12.0
@export var ROTATION_SPEED: float = 12.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var input_locked:bool = false
@onready var animation_player: AnimationPlayer = $godot_plush_model/AnimationPlayer
@onready var shape_cast_3d: ShapeCast3D = $ShapeCast3D
func _ready() -> void:
	add_to_group("player")

func _physics_process(delta: float) -> void:
	# 1. Aplicar Gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta
	if input_locked:
		velocity.x = 0
		velocity.z = 0
		if animation_player and animation_player.has_animation("idle"):
			animation_player.play("idle")
		return

	# 2. Entrada del jugador
	var input_dir := Input.get_vector("Izquierda", "Derecha", "Arriba", "Abajo")
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()

	# 3. Movimiento y Rotación
	if direction != Vector3.ZERO:
		# Aceleración suave
		var target_velocity_x = direction.x * SPEED
		var target_velocity_z = direction.z * SPEED
		
		velocity.x = lerp(velocity.x, target_velocity_x, ACCELERATION * delta)
		velocity.z = lerp(velocity.z, target_velocity_z, ACCELERATION * delta)
		
		# Cálculo perfecto para ortogonales y diagonales
		var target_angle = Vector2(-direction.x, direction.z).angle() - PI / 2
		rotation.y = lerp_angle(rotation.y, target_angle, ROTATION_SPEED * delta)
		
		# Animación de caminar
		if animation_player and animation_player.has_animation("walk"):
			animation_player.play("walk")
	else:
		# Frenado progresivo
		velocity.x = lerp(velocity.x, 0.0, FRICTION * delta)
		velocity.z = lerp(velocity.z, 0.0, FRICTION * delta)
		
		# Animación de reposo
		if animation_player and animation_player.has_animation("idle"):
			animation_player.play("idle")

	# 4. Aplicar movimiento
	move_and_slide()
func _input(event: InputEvent) -> void:
	if input_locked:
		return
		
	if Input.is_action_just_pressed("Interactuar"):
		if shape_cast_3d.is_colliding():
			var collided = shape_cast_3d.get_collision_result()[0]["collider"]
			
			if collided is PCStatic:
				input_locked = true
				collided.toggle_use()
			
		
	
