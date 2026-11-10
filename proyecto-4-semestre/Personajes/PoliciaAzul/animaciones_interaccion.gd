extends SkeletonModifier3D
## Poses posteriores a los clips importados; nunca acumula rotaciones entre frames.
## Los anclajes se actualizan con la pose final, incluidos los gestos y el tambaleo.

signal contacto
signal terminada
signal reposo_terminado

const DURACIONES := {&"recoger": 1.15, &"recibir": 0.75, &"interactuar": 0.7, &"reparar": 2.4, &"lanzar": 0.95, &"beber": 1.8}
const CONTACTOS := {&"recoger": 0.48, &"recibir": 0.38, &"interactuar": 0.48, &"reparar": 0.85, &"lanzar": 0.46, &"beber": 0.56}
const REPOSOS := {&"idle_despistado": 3.4, &"idle_tambaleo": 3.1}
var jugador: CharacterBody3D
var gesto: StringName = &""
var tiempo: float = 0.0
var duracion: float = 1.0
var tambaleo: float = 1.0
var mano_izquierda: Node3D
var mano_derecha: Node3D
var anclaje_taza: Node3D
var objetivo: Node3D
var _reloj: float = 0.0
var _contacto_emitido: bool = false
var _peso_papel: float = 0.0
var _huesos: Dictionary = {}
var _reposo: Dictionary = {}
var _llave: Node3D
var reposo_especial: StringName = &""
var tiempo_reposo: float = 0.0
var _peso_reposo: float = 0.0
var _saliendo_reposo: bool = false
var sentado: bool = false
var lleva_taza: bool = false
var _peso_sentado: float = 0.0
var _peso_taza: float = 0.0


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
	anclaje_taza = Node3D.new()
	anclaje_taza.name = "AnclajeTaza"
	esqueleto.add_child(anclaje_taza)
	_crear_llave()


func iniciar(tipo: StringName, destino: Node3D = null, segundos: float = 0.0) -> bool:
	if gesto != &"" or not DURACIONES.has(tipo):
		return false
	gesto = tipo
	tiempo = 0.0
	duracion = segundos if segundos > 0.0 else float(DURACIONES[tipo])
	_contacto_emitido = false
	objetivo = destino
	cancelar_reposo()
	return true


func iniciar_reposo(tipo: StringName) -> bool:
	if gesto != &"" or reposo_especial != &"" or not REPOSOS.has(tipo):
		return false
	reposo_especial = tipo
	tiempo_reposo = 0.0
	_peso_reposo = 0.0
	_saliendo_reposo = false
	return true


func cancelar_reposo() -> void:
	if reposo_especial != &"":
		_saliendo_reposo = true


func establecer_sentado(activo: bool, inmediato: bool = false) -> void:
	sentado = activo
	if activo:
		reposo_especial = &""
		_peso_reposo = 0.0
		_saliendo_reposo = false
	if inmediato:
		_peso_sentado = float(activo)


func cancelar() -> void:
	gesto = &""
	objetivo = null
	_llave.visible = false


func _process(delta: float) -> void:
	tambaleo = jugador.intensidad_tambaleo
	_reloj += delta
	_peso_sentado = move_toward(_peso_sentado, float(sentado), delta * 5.0)
	_peso_taza = move_toward(_peso_taza, float(lleva_taza), delta * 7.0)
	var lleva: bool = is_instance_valid(jugador.papel_en_mano)
	_peso_papel = move_toward(_peso_papel, 1.0 if lleva else 0.0, delta * 7.0)
	if reposo_especial != &"":
		if _saliendo_reposo:
			_peso_reposo = move_toward(_peso_reposo, 0.0, delta * 7.0)
			if is_zero_approx(_peso_reposo):
				reposo_especial = &""
				_saliendo_reposo = false
		else:
			_peso_reposo = move_toward(_peso_reposo, 1.0, delta * 5.0)
			tiempo_reposo += delta
			if tiempo_reposo >= float(REPOSOS[reposo_especial]):
				_saliendo_reposo = true
				reposo_terminado.emit()
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
	var peso_balanceo := 1.0 - _peso_sentado * 0.85
	var balanceo := sin(_reloj * ritmo) * amplitud * tambaleo * peso_balanceo
	_sumar("spine", Vector3(0.015 * sin(_reloj * ritmo * 2.0) * tambaleo, 0.0, balanceo))
	_sumar("chest", Vector3(0.025 * sin(_reloj * ritmo - 0.6) * tambaleo, balanceo * 0.35, -balanceo * 0.3))
	_sumar("head", Vector3(0.035 * sin(_reloj * ritmo - 0.9) * tambaleo, 0.0, -sin(_reloj * ritmo - 0.7) * amplitud * 1.4 * tambaleo))
	if _peso_sentado > 0.0:
		_aplicar_sentado(_peso_sentado)
	_sostener(_peso_papel)
	_sostener_taza(_peso_taza)
	if reposo_especial != &"":
		_aplicar_reposo(_peso_reposo)
	_llave.visible = gesto == &"reparar"
	if gesto != &"":
		_aplicar_gesto(tiempo / duracion)
	var esqueleto := get_skeleton()
	mano_izquierda.transform = esqueleto.get_bone_global_pose(_huesos["hand.L"])
	mano_derecha.transform = esqueleto.get_bone_global_pose(_huesos["hand.R"])
	var inclinacion := 0.0
	if gesto == &"beber":
		var t := tiempo / duracion
		inclinacion = -0.55 * smoothstep(0.22, 0.42, t) * (1.0 - smoothstep(0.66, 0.90, t))
	anclaje_taza.transform = Transform3D(Basis.from_euler(Vector3(inclinacion, 0.0, 0.0)), mano_derecha.position + Vector3(0.13, -0.15, 0.05))


func _aplicar_sentado(peso: float) -> void:
	for lado: String in ["L", "R"]:
		_pose("thigh." + lado, Vector3(-1.48, 0.0, -0.06 if lado == "L" else 0.06), peso)
		_pose("shin." + lado, Vector3(1.52, 0.0, 0.0), peso)
		_pose("foot." + lado, Vector3(-0.04, 0.0, 0.0), peso)
		_pose("upper_arm." + lado, Vector3(-0.30, 0.0, 0.06 if lado == "R" else -0.06), peso)
		_pose("forearm." + lado, Vector3(-0.58, 0.0, 0.0), peso)
	_sumar("spine", Vector3(-0.045 * peso, 0.0, 0.0))
	_sumar("chest", Vector3(0.025 * sin(_reloj * 1.6) * peso, 0.0, 0.0))
	_sumar("head", Vector3(0.025 * sin(_reloj * 1.2 - 0.3) * peso, 0.0, 0.0))


func _aplicar_reposo(peso: float) -> void:
	var t := tiempo_reposo
	var entrar := smoothstep(0.0, 0.35, t)
	var salir := 1.0 - smoothstep(float(REPOSOS[reposo_especial]) - 0.55, float(REPOSOS[reposo_especial]), t)
	var suave := peso * entrar * salir
	if reposo_especial == &"idle_despistado":
		var mirar := sin(t * 2.4) * 0.32 * suave
		var rascar := smoothstep(0.75, 1.2, t) * (1.0 - smoothstep(2.3, 2.8, t)) * peso
		_sumar("spine", Vector3(0.0, mirar * 0.35, sin(t * 3.0) * 0.065 * suave * tambaleo))
		_sumar("head", Vector3(0.08 * suave, mirar, sin(t * 4.0) * 0.11 * suave * tambaleo))
		_pose("upper_arm.R", Vector3(-0.28, 0.0, 2.30), rascar)
		_pose("forearm.R", Vector3(-0.35, 0.0, 0.20 * sin(t * 13.0)), rascar)
		_pose("hand.R", Vector3(0.0, 0.0, 0.20 * sin(t * 13.0)), rascar)
		_sumar("chest", Vector3(0.0, -mirar * 0.3, 0.0))
	else:
		var perder := smoothstep(0.15, 0.55, t) * (1.0 - smoothstep(1.85, 2.3, t)) * peso
		var vaiven := (sin(t * 5.5) * 0.26 + 0.18) * perder * tambaleo
		_sumar("spine", Vector3(0.10 * perder, 0.0, vaiven))
		_sumar("chest", Vector3(-0.08 * perder, 0.0, -vaiven * 0.4))
		_sumar("head", Vector3(-0.13 * perder, 0.0, -vaiven * 1.5))
		_pose("upper_arm.R", Vector3(-0.30, 0.0, 0.85 + 0.20 * sin(t * 8.0)), perder)
		_sumar("upper_arm.L", Vector3(-0.12 * perder, 0.0, -0.18 * perder))
		_pose("thigh.R", Vector3(-0.34, 0.0, 0.0), perder)
		_pose("shin.R", Vector3(0.48, 0.0, 0.0), perder)
		var esqueleto := get_skeleton()
		var raiz: int = _huesos["root"]
		esqueleto.set_bone_pose_position(raiz, esqueleto.get_bone_pose_position(raiz) + Vector3(0.0, -0.07 * perder, 0.0))
		if t > 2.15:
			_sumar("head", Vector3(0.11 * sin((t - 2.15) * 9.0) * suave, 0.0, 0.0))


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
		&"beber":
			var sorbo := smoothstep(0.0, 0.30, t) * (1.0 - smoothstep(0.68, 0.96, t))
			_pose("upper_arm.R", Vector3(-0.90, 0.0, 0.08), sorbo)
			_pose("forearm.R", Vector3(-1.65, 0.0, 0.0), sorbo)
			_pose("hand.R", Vector3(0.35, 0.0, -0.05), sorbo)
			_sumar("head", Vector3(-0.07 * sorbo, 0.0, 0.0))
			var esqueleto := get_skeleton()
			var boca := esqueleto.get_bone_global_pose(_huesos["head"]).origin + Vector3(0.0, 0.12, 0.48)
			_apuntar_mano(esqueleto.to_global(boca), sorbo, "R")


func _sostener(peso: float) -> void:
	_pose("upper_arm.L", Vector3(-0.42, 0.0, -0.12), peso)
	_pose("forearm.L", Vector3(-1.38, 0.0, 0.0), peso)
	_pose("hand.L", Vector3.ZERO, peso)


func _sostener_taza(peso: float) -> void:
	_pose("upper_arm.R", Vector3(-0.32, 0.0, 0.06), peso)
	_pose("forearm.R", Vector3(-1.40, 0.0, 0.0), peso)
	_pose("hand.R", Vector3.ZERO, peso)


func _pose(nombre: String, giro: Vector3, peso: float) -> void:
	var esqueleto := get_skeleton()
	var i: int = _huesos[nombre]
	var destino: Quaternion = _reposo[nombre] * Quaternion.from_euler(giro)
	esqueleto.set_bone_pose_rotation(i, esqueleto.get_bone_pose_rotation(i).slerp(destino, peso))


func _sumar(nombre: String, giro: Vector3) -> void:
	var esqueleto := get_skeleton()
	var i: int = _huesos[nombre]
	esqueleto.set_bone_pose_rotation(i, esqueleto.get_bone_pose_rotation(i) * Quaternion.from_euler(giro))


func _apuntar_mano(destino_global: Vector3, peso: float, lado: String = "L") -> void:
	var esqueleto := get_skeleton()
	var destino := esqueleto.to_local(destino_global)
	# CCD breve: rota hombro y codo, sin mover el cuerpo físico ni estirar huesos.
	for repeticion: int in range(3):
		for nombre: String in ["forearm." + lado, "upper_arm." + lado]:
			var i: int = _huesos[nombre]
			var pose := esqueleto.get_bone_global_pose(i)
			var mano := esqueleto.get_bone_global_pose(_huesos["hand." + lado]).origin
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
