extends SkeletonModifier3D
## Superpone el agotamiento al reposo o a la caminata durante el relevo.
## SkeletonModifier3D recibe la pose del clip cada cuadro: no acumula giros.

@export_range(0.0, 1.0) var peso: float = 0.0
var caminando: bool = false

var _tiempo: float = 0.0
var _huesos: Dictionary = {}
var _reposo: Dictionary = {}


func _ready() -> void:
	var esqueleto := get_skeleton()
	if esqueleto == null:
		return
	for nombre: String in ["spine", "chest", "head", "upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R", "hand.L", "hand.R"]:
		var indice := esqueleto.find_bone(nombre)
		if indice >= 0:
			_huesos[nombre] = indice
			_reposo[nombre] = esqueleto.get_bone_rest(indice).basis.get_rotation_quaternion()


func _process(delta: float) -> void:
	_tiempo += delta


func _process_modification() -> void:
	if peso <= 0.0 or _huesos.is_empty():
		return
	var intensidad := clampf(peso, 0.0, 1.0)
	var respiracion := sin(_tiempo * 1.7) * 0.018
	var vaiven := sin(_tiempo * (4.2 if caminando else 1.1)) * (0.028 if caminando else 0.012)
	# La mirada cae al suelo y la espalda se encorva sin alterar las piernas
	# del clip: así los pies siguen apoyándose durante la salida lenta.
	_sumar("spine", Vector3(0.24 + respiracion, 0.0, vaiven), intensidad)
	_sumar("chest", Vector3(0.12 + respiracion * 0.5, 0.0, -vaiven * 0.35), intensidad)
	_sumar("head", Vector3(0.40 + respiracion * 0.4, 0.035, -vaiven * 0.45), intensidad)
	# Amortigua el braceo de la caminata y deja los brazos junto al cuerpo.
	var peso_brazos := intensidad * (0.78 if caminando else 0.92)
	for lado: String in ["L", "R"]:
		var signo := 1.0 if lado == "L" else -1.0
		_pose("upper_arm." + lado, Vector3(0.22, 0.0, signo * 0.17), peso_brazos)
		_pose("forearm." + lado, Vector3(-0.08, 0.0, 0.0), peso_brazos)
		_pose("hand." + lado, Vector3(0.10, 0.0, signo * 0.04), intensidad * 0.7)


func _sumar(nombre: String, giro: Vector3, intensidad: float) -> void:
	if not _huesos.has(nombre):
		return
	var esqueleto := get_skeleton()
	var indice: int = _huesos[nombre]
	var original := esqueleto.get_bone_pose_rotation(indice)
	esqueleto.set_bone_pose_rotation(indice, original * Quaternion.from_euler(giro * intensidad))


func _pose(nombre: String, giro: Vector3, intensidad: float) -> void:
	if not _huesos.has(nombre):
		return
	var esqueleto := get_skeleton()
	var indice: int = _huesos[nombre]
	var destino: Quaternion = _reposo[nombre] * Quaternion.from_euler(giro)
	esqueleto.set_bone_pose_rotation(indice, esqueleto.get_bone_pose_rotation(indice).slerp(destino, intensidad))
