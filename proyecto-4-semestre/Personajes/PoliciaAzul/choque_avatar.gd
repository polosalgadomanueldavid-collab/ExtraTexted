extends Node
## Reacción cosmética compartida por los dos avatares de un contacto LAN.
## No mueve el cuerpo ni cambia la velocidad, las tareas o los paquetes de red.

const DURACION := 0.42
const SEPARACION := 0.82
var habilitado := false
var tiempo := DURACION
var intensidad := 0.0
var direccion := Vector3.ZERO
var contactos: Dictionary = {}
var _espera := 0.0
@onready var jugador: CharacterBody3D = get_parent()

func _process(delta: float) -> void:
	tiempo = minf(DURACION, tiempo + delta)
	_espera = maxf(0.0, _espera - delta)
	for id: int in contactos.keys():
		var otro = contactos[id].get_ref()
		if not is_instance_valid(otro) or jugador.global_position.distance_to(otro.global_position) > SEPARACION:
			contactos.erase(id)

func disponible() -> bool:
	return habilitado and jugador.visible and not jugador.en_relevo and not jugador.esta_sentado() and not jugador.nadando and not jugador.congelado and not jugador.input_locked and not jugador.realizando_gesto()

func registrar(otro: Object, velocidad_entrada: Vector3) -> bool:
	if not otro is CharacterBody3D or not otro.is_in_group("player") or otro == jugador:
		return false
	var reaccion = otro.get("choque")
	if reaccion == null or not disponible() or not reaccion.disponible():
		return false
	var id := otro.get_instance_id()
	if contactos.has(id) or _espera > 0.0 or reaccion._espera > 0.0:
		return false
	var hacia: Vector3 = otro.global_position - jugador.global_position
	hacia.y = 0.0
	if hacia.length_squared() < 0.001:
		return false
	hacia = hacia.normalized()
	var acercamiento: float = (velocidad_entrada - otro.velocity).dot(hacia)
	# Ignora el roce lateral, la corrección de red y el contacto casi inmóvil.
	if acercamiento < 0.65:
		return false
	contactos[id] = weakref(otro)
	reaccion.contactos[jugador.get_instance_id()] = weakref(jugador)
	var fuerza := clampf(acercamiento / 5.0, 0.45, 1.0)
	_iniciar(-hacia, fuerza)
	reaccion._iniciar(hacia, fuerza)
	_destello((jugador.global_position + otro.global_position) * 0.5 + Vector3.UP * 0.57)
	return true

func _iniciar(retroceso: Vector3, fuerza: float) -> void:
	tiempo = 0.0
	_espera = 0.6
	intensidad = fuerza
	direccion = jugador.visual.global_basis.orthonormalized().inverse() * retroceso

func reiniciar() -> void:
	tiempo = DURACION
	_espera = 0.0
	contactos.clear()

func aplicar_pose(modificador: SkeletonModifier3D) -> void:
	if tiempo >= DURACION:
		return
	# Compresión en 55 ms, cabezazo hacia atrás y una sola oscilación amortiguada.
	var compresion := sin(PI * clampf(tiempo / 0.13, 0.0, 1.0)) * intensidad
	var rebote := sin(PI * clampf((tiempo - 0.045) / 0.29, 0.0, 1.0)) * intensidad
	var asentamiento := sin(PI * clampf((tiempo - 0.28) / 0.14, 0.0, 1.0)) * intensidad
	var inclinacion := rebote * 0.28 - asentamiento * 0.065
	modificador._sumar("spine", Vector3(direccion.z * inclinacion, 0.0, -direccion.x * inclinacion))
	modificador._sumar("head", Vector3(direccion.z * (rebote * 0.22 - compresion * 0.12), rebote * 0.07, -direccion.x * rebote * 0.20))
	# Manos ocupadas conservan el agarre de la hoja, la taza y las herramientas.
	if not is_instance_valid(jugador.papel_en_mano) and not jugador._taza_en_mano and not jugador.usando_extintor:
		for lado: String in ["L", "R"]:
			var signo := -1.0 if lado == "L" else 1.0
			modificador._sumar("upper_arm." + lado, Vector3(-rebote * 0.24, 0.0, signo * rebote * 0.48))
			modificador._sumar("forearm." + lado, Vector3(-rebote * 0.28, 0.0, 0.0))
	var esqueleto := modificador.get_skeleton()
	var raiz := esqueleto.find_bone("root")
	if raiz >= 0:
		var escala := Vector3(1.0 + compresion * 0.07, 1.0 - compresion * 0.09, 1.0 + compresion * 0.07)
		esqueleto.set_bone_pose_scale(raiz, esqueleto.get_bone_pose_scale(raiz) * escala)
		esqueleto.set_bone_pose_position(raiz, esqueleto.get_bone_pose_position(raiz) + direccion * rebote * 0.14)

func _destello(punto: Vector3) -> void:
	var efecto := Node3D.new()
	efecto.name = "Poc"
	get_tree().current_scene.add_child(efecto)
	efecto.global_position = punto
	var camara := get_viewport().get_camera_3d()
	if camara != null:
		efecto.global_basis = camara.global_basis.orthonormalized()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ffdc88")
	for i in 5:
		var angulo := TAU * i / 5.0 + 0.3
		var rayo := MeshInstance3D.new()
		var malla := QuadMesh.new()
		malla.size = Vector2(0.023, 0.09)
		rayo.mesh = malla
		rayo.material_override = material
		rayo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rayo.position = Vector3(sin(angulo), cos(angulo), 0.0) * 0.10
		rayo.rotation.z = -angulo
		efecto.add_child(rayo)
	var tween := efecto.create_tween()
	tween.tween_property(efecto, "scale", Vector3.ONE * 1.65, 0.09).from(Vector3.ONE * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(efecto, "scale", Vector3.ZERO, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(efecto.queue_free)
