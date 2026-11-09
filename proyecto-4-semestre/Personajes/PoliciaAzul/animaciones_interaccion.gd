extends SkeletonModifier3D
## Poses posteriores a los clips importados; nunca acumula rotaciones entre frames.
## Los anclajes se actualizan con la pose final, incluidos los gestos y el tambaleo.

signal contacto
signal terminada

const DURACIONES := {&"recoger": 1.15, &"recibir": 0.75, &"interactuar": 0.7, &"reparar": 2.4, &"lanzar": 0.95}
const CONTACTOS := {&"recoger": 0.48, &"recibir": 0.38, &"interactuar": 0.48, &"reparar": 0.85, &"lanzar": 0.46}
var jugador: CharacterBody3D
var gesto: StringName = &""
var tiempo: float = 0.0
var duracion: float = 1.0
var tambaleo: float = 1.0
var mano_izquierda: Node3D
var mano_derecha: Node3D
var objetivo: Node3D
var _reloj: float = 0.0
var _contacto_emitido: bool = false
var _peso_papel: float = 0.0
var _huesos: Dictionary = {}
var _reposo: Dictionary = {}
var _llave: Node3D


func _ready() -> void:
	var esqueleto := get_skeleton()
	for i: int in range(esqueleto.get_bone_count()):
		var nombre := esqueleto.get_bone_name(i)
		_huesos[nombre] = i
		_reposo[nombre] = esqueleto.get_bone_rest(i).basis.get_rotation_quaternion()
	mano_izquierda = Node3D.new()
	mano_izquierda.name = "AnclajeManoIzquierda"
	esqueleto.add_child(mano_izquierda)
	mano_derecha = Node3D.new()
	mano_derecha.name = "AnclajeManoDerecha"
	esqueleto.add_child(mano_derecha)
	_crear_llave()


func iniciar(tipo: StringName, destino: Node3D = null, segundos: float = 0.0) -> bool:
	if gesto != &"" or not DURACIONES.has(tipo):
		return false
	gesto = tipo
	tiempo = 0.0
	duracion = segundos if segundos > 0.0 else float(DURACIONES[tipo])
	_contacto_emitido = false
	objetivo = destino
	return true


func cancelar() -> void:
	gesto = &""
	objetivo = null
	_llave.visible = false


func _process(delta: float) -> void:
	tambaleo = jugador.intensidad_tambaleo
	_reloj += delta
	var lleva: bool = is_instance_valid(jugador.papel_en_mano)
	_peso_papel = move_toward(_peso_papel, 1.0 if lleva else 0.0, delta * 7.0)
	if gesto == &"":
		return
	tiempo = minf(tiempo + delta, duracion)
	if not _contacto_emitido and tiempo >= duracion * float(CONTACTOS[gesto]):
		_contacto_emitido = true
		contacto.emit()
		# El efecto puede cancelar el gesto (por ejemplo, al reiniciar la prueba).
		if gesto == &"":
			return
	if tiempo >= duracion:
		cancelar()
		terminada.emit()


func _process_modification() -> void:
	if not is_instance_valid(jugador) or _huesos.is_empty():
		return
	var locomocion: StringName = jugador.current_animation
	var ritmo := 2.5
	var amplitud := 0.035
	if locomocion == &"walk":
		ritmo = 7.3
		amplitud = 0.11
	elif locomocion == &"run":
		ritmo = 10.8
		amplitud = 0.16
	elif locomocion in [&"jump", &"fall", &"wave"]:
		ritmo = 5.0
		amplitud = 0.095
	var balanceo := sin(_reloj * ritmo) * amplitud * tambaleo
	_sumar("spine", Vector3(0.015 * sin(_reloj * ritmo * 2.0) * tambaleo, 0.0, balanceo))
	_sumar("chest", Vector3(0.025 * sin(_reloj * ritmo - 0.6) * tambaleo, balanceo * 0.35, -balanceo * 0.3))
	_sumar("head", Vector3(0.035 * sin(_reloj * ritmo - 0.9) * tambaleo, 0.0, -sin(_reloj * ritmo - 0.7) * amplitud * 1.4 * tambaleo))
	_sostener(_peso_papel)
	_llave.visible = gesto == &"reparar"
	if gesto != &"":
		_aplicar_gesto(tiempo / duracion)
	var esqueleto := get_skeleton()
	mano_izquierda.transform = esqueleto.get_bone_global_pose(_huesos["hand.L"])
	mano_derecha.transform = esqueleto.get_bone_global_pose(_huesos["hand.R"])


func _aplicar_gesto(t: float) -> void:
	var entrada := smoothstep(0.0, 0.18, t)
	var salida := 1.0 - smoothstep(0.78, 1.0, t)
	var peso := entrada * salida
	var meneo := sin(t * TAU * 2.0) * 0.10 * tambaleo * peso
	_sumar("spine", Vector3(0.0, 0.0, meneo))
	_sumar("head", Vector3(0.04 * sin(t * TAU * 3.0), -meneo * 0.6, -meneo * 1.3))
	match gesto:
		&"recoger", &"recibir":
			var alcanzar := smoothstep(0.0, 0.32, t) * (1.0 - smoothstep(0.49, 0.85, t))
			var suelo := gesto == &"recoger"
			_sumar("spine", Vector3(0.65 if suelo else 0.10, 0.0, 0.0) * alcanzar)
			_sumar("head", Vector3(0.18, 0.0, 0.0) * alcanzar)
			if suelo:
				var esqueleto := get_skeleton()
				var raiz: int = _huesos["root"]
				esqueleto.set_bone_pose_position(raiz, esqueleto.get_bone_pose_position(raiz) + Vector3(0.0, -0.30 * alcanzar, 0.0))
				for lado: String in ["L", "R"]:
					_pose("thigh." + lado, Vector3(-0.5, 0.0, 0.0), alcanzar)
					_pose("shin." + lado, Vector3(0.9, 0.0, 0.0), alcanzar)
			_pose("upper_arm.L", Vector3(-0.85, 0.0, -0.1), alcanzar)
			_pose("forearm.L", Vector3(-0.12 if suelo else -0.7, 0.0, 0.0), alcanzar)
			# La mano busca la hoja real, también si quedó a un lado de los pies.
			if is_instance_valid(objetivo) and not _contacto_emitido:
				_apuntar_mano(objetivo.global_position, alcanzar)
		&"reparar":
			var ciclo := sin((t - 0.18) * TAU * 4.0)
			_sumar("spine", Vector3(0.19 * peso, 0.0, ciclo * 0.045 * peso * tambaleo))
			_pose("upper_arm.R", Vector3(-0.72, 0.0, 0.12), peso)
			_pose("forearm.R", Vector3(-0.87 + ciclo * 0.24, 0.0, 0.06 * ciclo), peso)
			_pose("hand.R", Vector3(0.0, ciclo * 0.4, ciclo * 0.12), peso)
			if t > 0.83:
				_sumar("head", Vector3(sin((t - 0.83) * TAU * 5.8) * 0.16, 0.0, 0.0))
		&"interactuar":
			_pose("upper_arm.R", Vector3(-0.83, 0.0, 0.06), peso)
			_pose("forearm.R", Vector3(-0.60 + sin(t * TAU * 2.0) * 0.09, 0.0, 0.0), peso)
			_sumar("spine", Vector3(0.10 * peso, 0.05 * peso, 0.0))
		&"lanzar":
			var impulso := smoothstep(0.28, 0.46, t)
			var preparar := smoothstep(0.0, 0.25, t) * (1.0 - impulso)
			_pose("upper_arm.L", Vector3(-0.42 + 0.95 * preparar - impulso, 0.0, -0.14), salida)
			_pose("forearm.L", Vector3(-1.38 + 0.65 * preparar + 1.10 * impulso, 0.0, 0.0), salida)
			_sumar("chest", Vector3(0.0, (-0.17 * preparar + 0.14 * impulso) * salida, 0.0))


func _sostener(peso: float) -> void:
	_pose("upper_arm.L", Vector3(-0.42, 0.0, -0.12), peso)
	_pose("forearm.L", Vector3(-1.38, 0.0, 0.0), peso)
	_pose("hand.L", Vector3.ZERO, peso)


func _pose(nombre: String, giro: Vector3, peso: float) -> void:
	var esqueleto := get_skeleton()
	var i: int = _huesos[nombre]
	var destino: Quaternion = _reposo[nombre] * Quaternion.from_euler(giro)
	esqueleto.set_bone_pose_rotation(i, esqueleto.get_bone_pose_rotation(i).slerp(destino, peso))


func _sumar(nombre: String, giro: Vector3) -> void:
	var esqueleto := get_skeleton()
	var i: int = _huesos[nombre]
	esqueleto.set_bone_pose_rotation(i, esqueleto.get_bone_pose_rotation(i) * Quaternion.from_euler(giro))


func _apuntar_mano(destino_global: Vector3, peso: float) -> void:
	var esqueleto := get_skeleton()
	var destino := esqueleto.to_local(destino_global)
	# CCD breve: rota hombro y codo, sin mover el cuerpo físico ni estirar huesos.
	for repeticion: int in range(3):
		for nombre: String in ["forearm.L", "upper_arm.L"]:
			var i: int = _huesos[nombre]
			var pose := esqueleto.get_bone_global_pose(i)
			var mano := esqueleto.get_bone_global_pose(_huesos["hand.L"]).origin
			var desde := (mano - pose.origin).normalized()
			var hacia := (destino - pose.origin).normalized()
			if desde.is_zero_approx() or hacia.is_zero_approx():
				continue
			var ajuste := Quaternion(desde, hacia)
			var padre := esqueleto.get_bone_global_pose(esqueleto.get_bone_parent(i)).basis.get_rotation_quaternion()
			var local := padre.inverse() * ajuste * padre * esqueleto.get_bone_pose_rotation(i)
			esqueleto.set_bone_pose_rotation(i, esqueleto.get_bone_pose_rotation(i).slerp(local, peso * 0.65))


func _crear_llave() -> void:
	_llave = Node3D.new()
	_llave.name = "LlaveReparacion"
	mano_derecha.add_child(_llave)
	_llave.position.y = 0.10
	_llave.rotation.x = -1.25
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("9fb8ca")
	metal.metallic = 0.55
	metal.roughness = 0.35
	for datos: Array in [
		[Vector3(0.0, 0.20, 0.0), Vector3(0.065, 0.32, 0.065)],
		[Vector3(0.0, 0.38, 0.0), Vector3(0.16, 0.07, 0.065)],
		[Vector3(-0.06, 0.45, 0.0), Vector3(0.04, 0.10, 0.065)],
		[Vector3(0.06, 0.45, 0.0), Vector3(0.04, 0.10, 0.065)]]:
		var pieza := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = datos[1]
		pieza.mesh = caja
		pieza.position = datos[0]
		pieza.material_override = metal
		_llave.add_child(pieza)
	_llave.visible = false
