extends Camera3D

@export var objetivo: Node3D # Asigna aquí a tu jugador desde el Inspector
@export var offset: Vector3 = Vector3(0, 3, 2) # Distancia/Ángulo de la cámara
@export var suavizado: float = 5.0 # Velocidad de seguimiento

# Límites del rango (Ajusta estos valores desde el Inspector)
@export_group("Límites de Cámara")
@export var limite_min_x: float = -4.592
@export var limite_max_x: float = 2.415
@export var limite_min_z: float = -0.153
@export var limite_max_z: float = 12.473

func _physics_process(delta: float) -> void:
	if not objetivo:
		return
		
	# 1. Calculamos la posición ideal según el personaje + el desfase
	var posicion_deseada = objetivo.global_position + offset
	
	# 2. Restringimos las coordenadas X y Z dentro del rango permitido
	posicion_deseada.x = clamp(posicion_deseada.x, limite_min_x, limite_max_x)
	posicion_deseada.z = clamp(posicion_deseada.z, limite_min_z, limite_max_z)
	
	# 3. Interpolamos suavemente hacia la posición restringida
	global_position = global_position.lerp(posicion_deseada, suavizado * delta)
