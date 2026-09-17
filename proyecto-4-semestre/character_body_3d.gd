extends CharacterBody3D

@export var SPEED: float = 2.0
@export var ACCELERATION: float = 10.0
@export var FRICTION: float = 12.0
@export var ROTATION_SPEED: float = 12.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var animation_player: AnimationPlayer = $godot_plush_model/AnimationPlayer


func _physics_process(delta: float) -> void:
	# 1. Aplicar Gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta

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
