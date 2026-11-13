extends SkeletonModifier3D
## Poses posteriores a los clips importados; nunca acumula rotaciones entre frames.
## Los anclajes se actualizan con la pose final, incluidos los gestos y el tambaleo.

signal contacto
signal terminada
signal reposo_terminado

const DURACIONES := {&"recoger": 1.15, &"recibir": 0.75, &"interactuar": 0.7, &"reparar": 2.4, &"lanzar": 0.95, &"beber": 1.8, &"kamehameha": 3.6, &"genkidama": 5.0, &"rasengan": 3.8}
const CONTACTOS := {&"recoger": 0.48, &"recibir": 0.38, &"interactuar": 0.48, &"reparar": 0.85, &"lanzar": 0.46, &"beber": 0.56, &"kamehameha": 0.55, &"genkidama": 0.72, &"rasengan": 0.5}
const REPOSOS := {&"idle_despistado": 3.4, &"idle_tambaleo": 3.1}
const ESCALA_RAYO := 30.0
const ESCALA_ANCHO_RAYO := 10.0
const ESCALA_ESFERA_SALIDA := 8.5
const ESCALA_GENKIDAMA := 3.0
const RADIO_GENKIDAMA := 2.38
const ALTURA_MODELO_POLICIA := 2.66
var jugador: CharacterBody3D
var gesto: StringName = &""
var tiempo: float = 0.0
var duracion: float = 1.0
var tambaleo: float = 1.0
var mano_izquierda: Node3D
var mano_derecha: Node3D
var pie_izquierdo: Node3D
var pie_derecho: Node3D
var anclaje_taza: Node3D
var objetivo: Node3D
var _reloj: float = 0.0
var _contacto_emitido: bool = false
var _peso_papel: float = 0.0
var _huesos: Dictionary = {}
var _reposo: Dictionary = {}
var _llave: Node3D
var _energia: Node3D
var _esfera_energia: Node3D
var _aura: MeshInstance3D
var _material_aura: ShaderMaterial
var _luz_aura: OmniLight3D
var _rayo: Node3D
var _rayo_halo: MeshInstance3D
var _rayo_exterior: MeshInstance3D
var _rayo_nucleo: MeshInstance3D
var _esfera_origen_rayo: Node3D
var _cabeza_rayo: Node3D
var _esfera_genkidama: Node3D
var _luz_genkidama: OmniLight3D
var _rasengan: Node3D
var _rasengan_espinas: Node3D
var _rasengan_espinas_inversas: Node3D
var _rasengan_lanzado: bool = false
var _origen_lanzamiento_rasengan := Vector3.ZERO
var reposo_especial: StringName = &""
var tiempo_reposo: float = 0.0
var _peso_reposo: float = 0.0
var _saliendo_reposo: bool = false
var sentado: bool = false
var lleva_taza: bool = false
var rociando_extintor := false
var _peso_extintor := 0.0
var _peso_sentado: float = 0.0
var _peso_taza: float = 0.0
var _peso_nado := 0.0
var _peso_quemadura := 0.0
var _fase_quemadura := 0.0
var _contacto_quemadura := false
var _sobresalto_quemadura := 0.0


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
	pie_izquierdo = Node3D.new()
	pie_izquierdo.name = "AnclajePieIzquierdo"
	esqueleto.add_child(pie_izquierdo)
	pie_derecho = Node3D.new()
	pie_derecho.name = "AnclajePieDerecho"
	esqueleto.add_child(pie_derecho)
	anclaje_taza = Node3D.new()
	anclaje_taza.name = "AnclajeTaza"
	esqueleto.add_child(anclaje_taza)
	_crear_llave()
	_crear_energia(esqueleto)


func iniciar(tipo: StringName, destino: Node3D = null, segundos: float = 0.0) -> bool:
	if gesto != &"" or not DURACIONES.has(tipo):
		return false
	gesto = tipo
	tiempo = 0.0
	duracion = segundos if segundos > 0.0 else float(DURACIONES[tipo])
	_contacto_emitido = false
	if tipo == &"rasengan":
		_rasengan_lanzado = false
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
	if not jugador.congelado or gesto != &"":
		_reloj += delta
	_peso_nado = jugador.peso_nado
	var ardiendo: bool = jugador.quemandose_pies and not sentado
	if ardiendo and not _contacto_quemadura:
		_sobresalto_quemadura = 1.0
		if _peso_quemadura < 0.05:
			_fase_quemadura = 0.0
	_contacto_quemadura = ardiendo
	_sobresalto_quemadura = move_toward(_sobresalto_quemadura, 0.0, delta * 3.5)
	# Entrada de 0,2 s y salida amortiguada: no corta la pose al despegar o aterrizar.
	var respuesta := 12.0 if ardiendo else 7.0
	_peso_quemadura = lerpf(_peso_quemadura, float(ardiendo), 1.0 - exp(-delta * respuesta))
	if _peso_quemadura > 0.001:
		_fase_quemadura += delta * 12.5
	else:
		_peso_quemadura = 0.0
	_peso_sentado = move_toward(_peso_sentado, float(sentado), delta * 5.0)
	_peso_taza = move_toward(_peso_taza, float(lleva_taza), delta * 7.0)
	_peso_extintor = move_toward(_peso_extintor, float(rociando_extintor), delta * 8.0)
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
	var peso_balanceo := (1.0 - _peso_sentado * 0.85) * (1.0 - _peso_nado) * (1.0 - _peso_quemadura)
	var balanceo := sin(_reloj * ritmo) * amplitud * tambaleo * peso_balanceo
	_sumar("spine", Vector3(0.015 * sin(_reloj * ritmo * 2.0) * tambaleo, 0.0, balanceo))
	_sumar("chest", Vector3(0.025 * sin(_reloj * ritmo - 0.6) * tambaleo, balanceo * 0.35, -balanceo * 0.3))
	_sumar("head", Vector3(0.035 * sin(_reloj * ritmo - 0.9) * tambaleo, 0.0, -sin(_reloj * ritmo - 0.7) * amplitud * 1.4 * tambaleo))
	if _peso_sentado > 0.0:
		_aplicar_sentado(_peso_sentado)
	if _peso_nado > 0.0:
		_aplicar_nado(_peso_nado)
	if _peso_quemadura > 0.0:
		_aplicar_pies_quemados(_peso_quemadura)
	_sostener(_peso_papel)
	_sostener_taza(_peso_taza)
	if reposo_especial != &"":
		_aplicar_reposo(_peso_reposo)
	_llave.visible = gesto == &"reparar"
	if gesto != &"":
		_aplicar_gesto(tiempo / duracion)
	if _peso_extintor > 0.0:
		_aplicar_extintor(_peso_extintor)
	_actualizar_energia()
	var esqueleto := get_skeleton()
	mano_izquierda.transform = esqueleto.get_bone_global_pose(_huesos["hand.L"])
	mano_derecha.transform = esqueleto.get_bone_global_pose(_huesos["hand.R"])
	pie_izquierdo.transform = esqueleto.get_bone_global_pose(_huesos["foot.L"])
	pie_derecho.transform = esqueleto.get_bone_global_pose(_huesos["foot.R"])
	var inclinacion := 0.0
	if gesto == &"beber":
		var t := tiempo / duracion
		inclinacion = -0.55 * smoothstep(0.22, 0.42, t) * (1.0 - smoothstep(0.66, 0.90, t))
	anclaje_taza.transform = Transform3D(Basis.from_euler(Vector3(inclinacion, 0.0, 0.0)), mano_derecha.position + Vector3(0.13, -0.15, 0.05))


func _aplicar_pies_quemados(peso: float) -> void:
	# Pisadas de pánico: un pie se recoge hasta la cintura y el otro apenas toca.
	var ciclo := _fase_quemadura
	var sacudida := sin(ciclo)
	var sobresalto := _sobresalto_quemadura * _sobresalto_quemadura
	for lado: String in ["L", "R"]:
		var signo := -1.0 if lado == "L" else 1.0
		var levantar := smoothstep(-0.25, 0.85, sin(ciclo + (0.0 if lado == "L" else PI)))
		_pose("thigh." + lado, Vector3(-0.10 - 1.65 * levantar, signo * 0.12, signo * 0.18), peso)
		_pose("shin." + lado, Vector3(0.15 + 2.05 * levantar, 0.0, 0.0), peso)
		_pose("foot." + lado, Vector3(-0.35 - 0.45 * levantar, 0.0, signo * 0.16 * sin(ciclo * 3.0)), peso)
	_pose("pelvis", Vector3(-0.08, sacudida * 0.12, -sacudida * 0.16), peso)
	_pose("spine", Vector3(-0.20 - sobresalto * 0.15, 0.0, sacudida * 0.22), peso)
	_pose("chest", Vector3(0.10, -sacudida * 0.14, -sacudida * 0.12), peso)
	_pose("head", Vector3(0.38 - sobresalto * 0.55, sin(ciclo * 0.5) * 0.18, -sacudida * 0.16), peso)
	# Rebote puramente visual: no concede altura física extra ni evita daño.
	if _huesos.has("root"):
		var esqueleto := get_skeleton()
		var raiz: int = _huesos["root"]
		var elevacion := 0.06 + 0.15 * absf(cos(ciclo)) + 0.10 * sobresalto
		var desplazamiento := Vector3(sacudida * 0.075, elevacion, 0.0) * peso
		esqueleto.set_bone_pose_position(raiz, esqueleto.get_bone_pose_position(raiz) + desplazamiento)
	if gesto == &"":
		for lado: String in ["L", "R"]:
			var signo := -1.0 if lado == "L" else 1.0
			var agitar := sin(ciclo + signo * 0.8)
			_pose("upper_arm." + lado, Vector3(-0.65 - sobresalto * 0.5, signo * 0.18, signo * (1.15 + agitar * 0.30)), peso)
			_pose("forearm." + lado, Vector3(-0.95 + agitar * 0.35, 0.0, signo * 0.12), peso)
			_pose("hand." + lado, Vector3(sin(ciclo * 2.0) * 0.28, 0.0, signo * 0.25), peso)


func posicion_pie(lado: String) -> Vector3:
	# El esqueleto restaura su pose base tras los modificadores. Estos anclajes
	# conservan la pose final para los efectos que se actualizan en física.
	return pie_izquierdo.global_position if lado == "L" else pie_derecho.global_position


func _aplicar_nado(peso: float) -> void:
	var avance: float = jugador.avance_nado
	var ciclo: float = jugador.fase_nado
	# Entrada, tracción, empuje y recuperación. Se interpolan codo/hombro/mano
	# con la misma fase continua, también al cambiar de avance a flotación.
	const HOMBROS := [Vector3(-1.85, -0.12, 0.23), Vector3(-0.85, 0.12, 0.65), Vector3(0.55, 0.04, 0.32), Vector3(-0.85, -0.12, 1.0)]
	const CODOS := [-0.15, -0.85, -0.38, -1.55]
	for lado: String in ["L", "R"]:
		var signo := -1.0 if lado == "L" else 1.0
		var fase := ciclo + (PI if lado == "R" else 0.0)
		var tramo := fposmod(fase / TAU, 1.0) * 4.0
		var indice := floori(tramo)
		var mezcla := smoothstep(0.0, 1.0, fposmod(tramo, 1.0))
		var hombro: Vector3 = HOMBROS[indice].lerp(HOMBROS[(indice + 1) % 4], mezcla)
		hombro.z *= signo
		hombro.y *= signo
		var codo := lerpf(CODOS[indice], CODOS[(indice + 1) % 4], mezcla)
		var remada := Vector3(-0.48 + sin(fase) * 0.22, cos(fase) * signo * 0.12, signo * (0.65 + cos(fase) * 0.16))
		_pose("upper_arm." + lado, remada.lerp(hombro, avance), peso)
		_pose("forearm." + lado, Vector3(lerpf(-0.92 + sin(fase) * 0.20, codo, avance), 0, 0), peso)
		_pose("hand." + lado, Vector3(lerpf(-0.08, -0.24, avance), 0, signo * cos(fase) * 0.13), peso)
		var patada := sin(ciclo * 2.0 + (PI if lado == "R" else 0.0))
		_pose("thigh." + lado, Vector3(lerpf(-0.18 + sin(fase) * 0.20, patada * 0.23, avance), 0, signo * lerpf(0.19, 0.07, avance)), peso)
		_pose("shin." + lado, Vector3(lerpf(0.72 + cos(fase) * 0.28, 0.15 + maxf(0, -patada) * 0.28, avance), 0, 0), peso)
		_pose("foot." + lado, Vector3(lerpf(0.08, 0.35, avance), 0, signo * 0.04), peso)
	_pose("spine", Vector3(0.03, sin(ciclo) * 0.04 * avance, 0), peso)
	_pose("chest", Vector3(-0.04, sin(ciclo) * 0.10 * avance, 0), peso)
	_pose("head", Vector3(lerpf(-0.08, -0.50, avance), sin(ciclo) * 0.035 * avance, 0), peso)
	# Las poses de sostener papel/taza y de trabajo se aplican después, por brazo.


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
		&"kamehameha":
			# Carga de lado: palmas enfrentadas a distintas alturas. Luego gira
			# al frente y proyecta las manos juntas, una arriba de la otra, dejando
			# el hueco central de la "C" para el poder.
			var carga := smoothstep(0.04, 0.22, t) * (1.0 - smoothstep(0.43, 0.58, t))
			var lanzamiento := smoothstep(0.43, 0.62, t) * (1.0 - smoothstep(0.78, 0.94, t))
			var volver := smoothstep(0.82, 1.0, t)
			var temblor := sin(_reloj * 22.0) * carga * 0.025
			_pose("thigh.L", Vector3(-0.27 * carga, 0.0, 0.0), 1.0)
			_pose("thigh.R", Vector3(-0.27 * carga, 0.0, 0.0), 1.0)
			_pose("shin.L", Vector3(0.38 * carga, 0.0, 0.0), 1.0)
			_pose("shin.R", Vector3(0.38 * carga, 0.0, 0.0), 1.0)
			# En Godot, Y negativo gira el frente (+Z) hacia el costado -X,
			# el mismo lado donde se reúnen las manos durante la carga.
			var giro_lateral := -0.72 * carga * (1.0 - lanzamiento)
			_sumar("spine", Vector3(0.12 * carga - 0.05 * lanzamiento, giro_lateral, temblor))
			_sumar("chest", Vector3(-0.08 * carga + 0.10 * lanzamiento, giro_lateral * 0.72, -temblor))
			_sumar("head", Vector3(-0.04 * carga + 0.02 * lanzamiento, -giro_lateral * 0.55, 0.0))
			var esqueleto := get_skeleton()
			# X y Z iguales: las manos quedan apiladas en una sola línea vertical.
			var carga_superior := Vector3(-0.58, 1.49, 0.62)
			var carga_inferior := Vector3(-0.58, 1.23, 0.62)
			var mano_superior := Vector3(-0.13, 1.52, 0.78)
			var mano_inferior := Vector3(0.13, 1.27, 0.78)
			var peso_carga := carga * (1.0 - volver)
			var peso_lanzamiento := maxf(lanzamiento, volver)
			var peso_brazos := maxf(peso_carga, peso_lanzamiento)
			var objetivo_L := carga_superior.lerp(mano_superior, smoothstep(0.36, 0.64, t))
			var objetivo_R := carga_inferior.lerp(mano_inferior, smoothstep(0.36, 0.64, t))
			if peso_brazos > 0.01:
				_apuntar_mano(esqueleto.to_global(objetivo_L), peso_brazos, "L")
				_apuntar_mano(esqueleto.to_global(objetivo_R), peso_brazos, "R")
			_pose("hand.L", Vector3(0.10, 0.0, -0.22), peso_brazos)
			_pose("hand.R", Vector3(-0.08, 0.0, 0.22), peso_brazos)
		&"genkidama":
			var levantar := smoothstep(0.02, 0.24, t) * (1.0 - smoothstep(0.56, 0.69, t))
			var empujar := smoothstep(0.57, 0.72, t) * (1.0 - smoothstep(0.82, 0.96, t))
			var recuperar := smoothstep(0.84, 1.0, t)
			var temblor_esfera := sin(_reloj * 12.0) * levantar * 0.025
			_sumar("spine", Vector3(-0.04 * levantar + 0.12 * empujar, 0.0, temblor_esfera))
			_sumar("chest", Vector3(0.04 * levantar + 0.16 * empujar, 0.0, -temblor_esfera))
			_sumar("head", Vector3(-0.12 * levantar + 0.02 * empujar, 0.0, 0.0))
			var esqueleto := get_skeleton()
			# Manos sobre los hombros y un poco fuera del alcance para estirar los codos.
			var manos_arriba_L := Vector3(0.42, ALTURA_MODELO_POLICIA - 0.10, 0.20)
			var manos_arriba_R := Vector3(-0.42, ALTURA_MODELO_POLICIA - 0.10, 0.20)
			var manos_frente_L := Vector3(0.46, 1.68, 1.02)
			var manos_frente_R := Vector3(-0.46, 1.52, 1.02)
			var transicion_lanzamiento := smoothstep(0.56, 0.73, t)
			var peso_brazos := maxf(levantar, empujar) * (1.0 - recuperar)
			var objetivo_L := manos_arriba_L.lerp(manos_frente_L, transicion_lanzamiento)
			var objetivo_R := manos_arriba_R.lerp(manos_frente_R, transicion_lanzamiento)
			if peso_brazos > 0.01:
				_apuntar_mano(esqueleto.to_global(objetivo_L), peso_brazos, "L")
				_apuntar_mano(esqueleto.to_global(objetivo_R), peso_brazos, "R")
			_pose("hand.L", Vector3(-0.12, 0.0, -0.08), peso_brazos)
			_pose("hand.R", Vector3(0.12, 0.0, 0.08), peso_brazos)
		&"rasengan":
			var agacharse := smoothstep(0.0, 0.20, t) * (1.0 - smoothstep(0.78, 0.96, t))
			var extender := smoothstep(0.10, 0.40, t) * (1.0 - smoothstep(0.86, 0.99, t))
			var impulso := smoothstep(0.62, 0.72, t)
			var vibracion := sin(_reloj * 13.0) * agacharse * 0.018
			_pose("thigh.L", Vector3(-0.16 * agacharse, 0.0, 0.0), 1.0)
			_pose("thigh.R", Vector3(-0.16 * agacharse, 0.0, 0.0), 1.0)
			_pose("shin.L", Vector3(0.20 * agacharse, 0.0, 0.0), 1.0)
			_pose("shin.R", Vector3(0.20 * agacharse, 0.0, 0.0), 1.0)
			_sumar("spine", Vector3(0.14 * agacharse, 0.0, vibracion))
			_sumar("chest", Vector3(0.08 * agacharse + 0.12 * impulso, 0.0, -vibracion))
			_sumar("head", Vector3(-0.06 * agacharse, 0.0, 0.0))
			var esqueleto := get_skeleton()
			# El blanco queda más allá del alcance cómodo para que el brazo se estire.
			var mano_objetivo := Vector3(-0.58, 1.50, 1.18)
			if extender > 0.01:
				_apuntar_mano(esqueleto.to_global(mano_objetivo), extender, "R")
			_pose("hand.R", Vector3(0.0, 0.0, 0.08), extender)


func _aplicar_extintor(peso: float) -> void:
	# Izquierda en el asa; derecha dirige la boquilla con un barrido corto.
	var barrido := sin(_reloj * 3.8) * 0.10
	_pose("upper_arm.L", Vector3(-0.48, 0.0, -0.16), peso)
	_pose("forearm.L", Vector3(-1.12, 0.0, 0.0), peso)
	_pose("hand.L", Vector3.ZERO, peso)
	_pose("upper_arm.R", Vector3(-1.0, barrido, 0.12), peso)
	_pose("forearm.R", Vector3(-0.48, 0.0, 0.0), peso)
	_pose("hand.R", Vector3(0.0, barrido, 0.0), peso)
	_pose("thigh.L", Vector3(-0.14, 0.0, -0.05), peso)
	_pose("shin.L", Vector3(0.22, 0.0, 0.0), peso)
	_pose("thigh.R", Vector3(0.10, 0.0, 0.05), peso)
	_sumar("spine", Vector3(-0.09 + sin(_reloj * 19.0) * 0.012, barrido * 0.3, 0.0) * peso)
	_sumar("head", Vector3(0.10, -barrido * 0.3, 0.0) * peso)


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


func _crear_energia(esqueleto: Skeleton3D) -> void:
	_energia = Node3D.new()
	_energia.name = "EfectosKamehameha"
	esqueleto.add_child(_energia)
	_esfera_energia = Node3D.new()
	_esfera_energia.name = "EsferaDeEnergia"
	_energia.add_child(_esfera_energia)
	var material_exterior := StandardMaterial3D.new()
	material_exterior.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_exterior.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_exterior.albedo_color = Color(0.12, 0.72, 1.0, 0.34)
	material_exterior.emission_enabled = true
	material_exterior.emission = Color(0.04, 0.52, 1.0)
	material_exterior.emission_energy_multiplier = 2.4
	var exterior := MeshInstance3D.new()
	var malla_exterior := SphereMesh.new()
	malla_exterior.radius = 0.19
	malla_exterior.height = 0.38
	exterior.mesh = malla_exterior
	exterior.material_override = material_exterior
	_esfera_energia.add_child(exterior)
	var material_nucleo := StandardMaterial3D.new()
	material_nucleo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_nucleo.albedo_color = Color(0.72, 0.96, 1.0)
	material_nucleo.emission_enabled = true
	material_nucleo.emission = Color(0.30, 0.82, 1.0)
	material_nucleo.emission_energy_multiplier = 4.0
	var nucleo := MeshInstance3D.new()
	var malla_nucleo := SphereMesh.new()
	malla_nucleo.radius = 0.105
	malla_nucleo.height = 0.21
	nucleo.mesh = malla_nucleo
	nucleo.material_override = material_nucleo
	_esfera_energia.add_child(nucleo)
	var luz := OmniLight3D.new()
	luz.light_color = Color(0.16, 0.68, 1.0)
	luz.light_energy = 1.8
	luz.omni_range = 2.4
	_esfera_energia.add_child(luz)
	_aura = MeshInstance3D.new()
	_aura.name = "AuraAzul"
	var malla_aura := SphereMesh.new()
	malla_aura.radius = 1.0
	malla_aura.height = 2.0
	malla_aura.radial_segments = 40
	malla_aura.rings = 28
	_aura.mesh = malla_aura
	var shader_aura := Shader.new()
	shader_aura.code = """
shader_type spatial;
render_mode unshaded, cull_front, blend_add, depth_draw_never;
uniform float aura_strength = 0.0;
varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
	VERTEX += NORMAL * (0.025 * sin(TIME * 8.0 + VERTEX.y * 7.0 + VERTEX.x * 4.0));
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - facing, 2.0);
	float flicker = 0.68 + 0.32 * sin(TIME * 13.0 + local_position.y * 10.0 + sin(local_position.x * 8.0));
	float alpha = clamp(rim * flicker * aura_strength * 0.72, 0.0, 0.56);
	ALBEDO = vec3(0.025, 0.28, 1.0);
	EMISSION = vec3(0.015, 0.16, 1.0) * (1.1 + flicker * aura_strength);
	ALPHA = alpha;
}
"""
	_material_aura = ShaderMaterial.new()
	_material_aura.shader = shader_aura
	_material_aura.set_shader_parameter("aura_strength", 0.0)
	_aura.material_override = _material_aura
	_aura.position = Vector3(0.0, 1.34, 0.0)
	_energia.add_child(_aura)
	_luz_aura = OmniLight3D.new()
	_luz_aura.name = "LuzAuraAzul"
	_luz_aura.light_color = Color(0.035, 0.22, 1.0)
	_luz_aura.light_energy = 1.2
	_luz_aura.omni_range = 3.8
	_aura.add_child(_luz_aura)
	_crear_genkidama()
	_crear_rasengan()
	_rayo = Node3D.new()
	_rayo.name = "RayoDeEnergia"
	_rayo.rotation.x = PI * 0.5
	_rayo.position = Vector3(0.0, 1.36, 7.5)
	_energia.add_child(_rayo)
	_rayo_halo = _crear_tramo_rayo(0.36, Color(0.015, 0.12, 1.0, 0.12), 2.5)
	_rayo_exterior = _crear_tramo_rayo(0.22, Color(0.08, 0.48, 1.0, 0.38), 2.4)
	_rayo_nucleo = _crear_tramo_rayo(0.085, Color(0.82, 0.98, 1.0), 5.0)
	_rayo.add_child(_rayo_halo)
	_rayo.add_child(_rayo_exterior)
	_rayo.add_child(_rayo_nucleo)
	_esfera_origen_rayo = Node3D.new()
	_esfera_origen_rayo.name = "EsferaSalidaRayo"
	_esfera_origen_rayo.position = Vector3(0.0, 1.36, 6.2)
	_energia.add_child(_esfera_origen_rayo)
	_esfera_origen_rayo.add_child(_crear_esfera_rayo(0.50, Color(0.04, 0.36, 1.0, 0.42), 3.0))
	_esfera_origen_rayo.add_child(_crear_esfera_rayo(0.31, Color(0.80, 0.98, 1.0), 5.0))
	_cabeza_rayo = Node3D.new()
	_cabeza_rayo.name = "EsferaFrontalConPuntas"
	_cabeza_rayo.position = Vector3(0.0, 1.36, 6.2)
	_energia.add_child(_cabeza_rayo)
	_cabeza_rayo.add_child(_crear_esfera_rayo(0.62, Color(0.015, 0.20, 1.0, 0.38), 3.0))
	_cabeza_rayo.add_child(_crear_esfera_rayo(0.40, Color(0.88, 0.99, 1.0), 5.0))
	_crear_puntas_cabeza()
	_energia.visible = false


func _crear_tramo_rayo(radius: float, color: Color, brillo: float) -> MeshInstance3D:
	var tramo := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = radius
	cilindro.bottom_radius = radius
	cilindro.height = 14.0
	cilindro.radial_segments = 96
	tramo.mesh = cilindro
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = brillo
	tramo.material_override = material
	return tramo


func _crear_genkidama() -> void:
	_esfera_genkidama = Node3D.new()
	_esfera_genkidama.name = "Genkidama"
	_esfera_genkidama.position = Vector3(0.0, ALTURA_MODELO_POLICIA + RADIO_GENKIDAMA * ESCALA_GENKIDAMA, 0.25)
	_energia.add_child(_esfera_genkidama)
	_esfera_genkidama.add_child(_crear_esfera_rayo(RADIO_GENKIDAMA, Color(0.035, 0.34, 1.0, 0.12), 2.0))
	_esfera_genkidama.add_child(_crear_esfera_rayo(2.12, Color(0.08, 0.55, 1.0, 0.30), 3.0))
	_esfera_genkidama.add_child(_crear_esfera_rayo(1.55, Color(0.65, 0.91, 1.0), 4.2))
	_luz_genkidama = OmniLight3D.new()
	_luz_genkidama.name = "LuzGenkidama"
	_luz_genkidama.light_color = Color(0.12, 0.52, 1.0)
	_luz_genkidama.light_energy = 3.0
	_luz_genkidama.omni_range = 5.0
	_esfera_genkidama.add_child(_luz_genkidama)
	_esfera_genkidama.visible = false


func _crear_rasengan() -> void:
	_rasengan = Node3D.new()
	_rasengan.name = "RasenganEnMano"
	_rasengan.add_child(_crear_esfera_rayo(0.50, Color(0.04, 0.48, 1.0, 0.40), 3.0))
	_rasengan.add_child(_crear_esfera_rayo(0.31, Color(0.76, 0.98, 1.0), 5.0))
	_energia.add_child(_rasengan)
	_rasengan_espinas = Node3D.new()
	_rasengan_espinas.name = "EspinasAzules"
	_rasengan.add_child(_rasengan_espinas)
	_crear_espinas_rasengan(_rasengan_espinas, 10, 0.45, 0.11, 0.36, Color(0.12, 0.62, 1.0), 4.5)
	_rasengan_espinas_inversas = Node3D.new()
	_rasengan_espinas_inversas.name = "EspinasClaras"
	_rasengan.add_child(_rasengan_espinas_inversas)
	_crear_espinas_rasengan(_rasengan_espinas_inversas, 8, 0.35, 0.08, 0.27, Color(0.62, 0.92, 1.0), 5.0, PI / 8.0)
	var luz := OmniLight3D.new()
	luz.name = "LuzRasengan"
	luz.light_color = Color(0.05, 0.48, 1.0)
	luz.light_energy = 1.8
	luz.omni_range = 3.4
	_rasengan.add_child(luz)
	_rasengan.visible = false


func _crear_espinas_rasengan(grupo: Node3D, cantidad: int, radio: float, radio_base: float, alto: float, color: Color, brillo: float, desfase: float = 0.0) -> void:
	for indice: int in range(cantidad):
		var angulo := TAU * float(indice) / float(cantidad) + desfase
		var direccion := Vector3(cos(angulo), sin(angulo), 0.0)
		var punta := MeshInstance3D.new()
		var cono := CylinderMesh.new()
		cono.top_radius = 0.0
		cono.bottom_radius = radio_base
		cono.height = alto
		cono.radial_segments = 20
		punta.mesh = cono
		punta.position = direccion * radio
		punta.quaternion = Quaternion(Vector3.UP, direccion)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b)
		material.emission_energy_multiplier = brillo
		punta.material_override = material
		grupo.add_child(punta)


func _crear_esfera_rayo(radio: float, color: Color, brillo: float) -> MeshInstance3D:
	var esfera := MeshInstance3D.new()
	var malla := SphereMesh.new()
	malla.radius = radio
	malla.height = radio * 2.0
	malla.radial_segments = 64
	malla.rings = 40
	esfera.mesh = malla
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = brillo
	esfera.material_override = material
	return esfera


func _crear_puntas_cabeza() -> void:
	var cantidad := 16
	for indice: int in range(cantidad):
		var angulo := TAU * float(indice) / float(cantidad)
		var direccion := Vector3(cos(angulo), 0.0, sin(angulo))
		var punta := MeshInstance3D.new()
		var cono := CylinderMesh.new()
		cono.top_radius = 0.0
		cono.bottom_radius = 0.16
		cono.height = 0.95
		cono.radial_segments = 24
		punta.mesh = cono
		punta.position = direccion * 0.46
		punta.quaternion = Quaternion(Vector3.UP, direccion)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.16, 0.62, 1.0, 0.72)
		material.emission_enabled = true
		material.emission = Color(0.06, 0.38, 1.0)
		material.emission_energy_multiplier = 4.2
		punta.material_override = material
		_cabeza_rayo.add_child(punta)
	var punta_frontal := MeshInstance3D.new()
	var cono_frontal := CylinderMesh.new()
	cono_frontal.top_radius = 0.0
	cono_frontal.bottom_radius = 0.22
	cono_frontal.height = 1.0
	cono_frontal.radial_segments = 32
	punta_frontal.mesh = cono_frontal
	punta_frontal.position.y = 0.70
	var material_frontal := StandardMaterial3D.new()
	material_frontal.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_frontal.albedo_color = Color(0.76, 0.96, 1.0)
	material_frontal.emission_enabled = true
	material_frontal.emission = Color(0.42, 0.82, 1.0)
	material_frontal.emission_energy_multiplier = 5.0
	punta_frontal.material_override = material_frontal
	_cabeza_rayo.add_child(punta_frontal)


func _actualizar_energia() -> void:
	if not is_instance_valid(_energia):
		return
	var es_kamehameha := gesto == &"kamehameha"
	var es_genkidama := gesto == &"genkidama"
	var es_rasengan := gesto == &"rasengan"
	if not es_kamehameha and not es_genkidama and not es_rasengan:
		_energia.visible = false
		return
	_energia.visible = true
	var t := tiempo / duracion
	var fuerza_aura := 0.0 if es_rasengan else smoothstep(0.02, 0.18, t) * (1.0 - smoothstep(0.84, 0.99, t))
	_aura.visible = fuerza_aura > 0.01
	_aura.scale = Vector3(1.0, 1.55, 0.95) * (1.0 + sin(_reloj * 8.0) * 0.035 * fuerza_aura)
	_material_aura.set_shader_parameter("aura_strength", fuerza_aura)
	_luz_aura.light_energy = 0.8 + fuerza_aura * 1.8
	if es_rasengan:
		_rayo.visible = false
		_esfera_origen_rayo.visible = false
		_cabeza_rayo.visible = false
		_esfera_genkidama.visible = false
		_esfera_energia.visible = false
		var aparicion := smoothstep(0.30, 0.48, t) * (1.0 - smoothstep(0.97, 1.0, t))
		var mano := get_skeleton().get_bone_global_pose(_huesos["hand.R"]).origin
		var posicion_en_mano := mano + Vector3(-0.28, 0.02, 1.15)
		if t >= 0.68 and not _rasengan_lanzado:
			_origen_lanzamiento_rasengan = posicion_en_mano
			_rasengan_lanzado = true
		if _rasengan_lanzado:
			var recorrido := smoothstep(0.68, 0.96, t)
			_rasengan.position = _origen_lanzamiento_rasengan.lerp(_origen_lanzamiento_rasengan + Vector3(0.0, 0.0, 24.0), recorrido)
		else:
			_rasengan.position = posicion_en_mano
		_rasengan.visible = aparicion > 0.01
		_rasengan.scale = Vector3.ONE * 2.1 * aparicion * (1.0 + sin(_reloj * 9.0) * 0.035)
		_rasengan_espinas.rotation.z = _reloj * 8.0
		_rasengan_espinas_inversas.rotation.z = -_reloj * 10.5
		return
	_rasengan.visible = false
	if es_genkidama:
		_rayo.visible = false
		_esfera_energia.visible = false
		_esfera_origen_rayo.visible = false
		_cabeza_rayo.visible = false
		_esfera_genkidama.visible = t > 0.14 and t < 0.995
		var crecimiento := smoothstep(0.14, 0.34, t)
		var vuelo := smoothstep(0.66, 0.97, t)
		var pulso_genki := 1.0 + sin(_reloj * 7.0) * 0.035
		var altura_genkidama := ALTURA_MODELO_POLICIA + RADIO_GENKIDAMA * ESCALA_GENKIDAMA
		_esfera_genkidama.position = Vector3(0.0, altura_genkidama, 0.25).lerp(Vector3(0.0, altura_genkidama, 26.0), vuelo)
		_esfera_genkidama.scale = Vector3.ONE * ESCALA_GENKIDAMA * crecimiento * pulso_genki
		_luz_genkidama.light_energy = 1.5 + crecimiento * (1.5 + 1.0 * (1.0 - vuelo))
		return
	_esfera_genkidama.visible = false
	var carga := smoothstep(0.08, 0.20, t) * (1.0 - smoothstep(0.48, 0.60, t))
	var avance := smoothstep(0.59, 0.90, t)
	var desvanecer_rayo := 1.0 - smoothstep(0.90, 0.99, t)
	var disparo := smoothstep(0.59, 0.63, t) * desvanecer_rayo
	_esfera_energia.visible = t > 0.08 and t < 0.72
	# Son los puntos medios exactos de las dos manos en carga y lanzamiento.
	_esfera_energia.position = Vector3(-0.58, 1.36, 0.62).lerp(Vector3(0.0, 1.395, 0.78), smoothstep(0.42, 0.64, t))
	var pulso := 1.0 + sin(_reloj * 10.0) * (0.08 + carga * 0.14)
	_esfera_energia.scale = Vector3.ONE * pulso
	_luz_aura.light_energy = 0.8 + fuerza_aura * (1.0 + carga * 1.2)
	_rayo.visible = disparo > 0.01
	var escala_largo := ESCALA_RAYO * avance * desvanecer_rayo
	var escala_ancho := ESCALA_ANCHO_RAYO * smoothstep(0.04, 0.32, avance) * desvanecer_rayo
	_rayo.scale = Vector3(escala_ancho, escala_largo, escala_ancho)
	_rayo.position = Vector3(0.0, 1.36, 6.2 + 7.0 * escala_largo)
	_rayo_halo.visible = disparo > 0.01
	_rayo_exterior.visible = disparo > 0.01
	_rayo_nucleo.visible = disparo > 0.01
	_esfera_origen_rayo.visible = disparo > 0.01
	_esfera_origen_rayo.scale = Vector3.ONE * (ESCALA_ESFERA_SALIDA * desvanecer_rayo)
	_cabeza_rayo.visible = disparo > 0.01
	_cabeza_rayo.position.z = 6.2 + 14.0 * escala_largo
	var crecimiento_cabeza := smoothstep(0.03, 0.24, avance)
	_cabeza_rayo.scale = Vector3.ONE * ESCALA_ESFERA_SALIDA * crecimiento_cabeza * (0.88 + 0.12 * sin(_reloj * 16.0)) * desvanecer_rayo


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
