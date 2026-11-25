class_name PapelDenuncia
extends RigidBody3D

const TAMANO := Vector3(0.24, 0.012, 0.18)
const IMPULSO_HORIZONTAL := 1.4
const IMPULSO_VERTICAL := 0.5
const MODELOS := preload("res://MarcadoresEstaciones/modelos_marcador.gd")

var denuncia_id: String = ""
var portador: Player = null
var red: Node
var nivel_agua := -INF
var _malla_hoja: MeshInstance3D
var _material_hoja: StandardMaterial3D
var _tiempo_resaltado: float = 0.0
var _marcador_recoger: Node3D
var _firma_expediente := ""
var _piezas_expediente: Array[MeshInstance3D] = []
var enfocado := false
var mostrar_indicador: bool = true:
	set(valor):
		mostrar_indicador = valor
		_actualizar_marcador()


func _ready() -> void:
	name = "PapelDenuncia"
	add_to_group("papeles_denuncia")
	contact_monitor = false
	continuous_cd = true
	linear_damp = 3.0
	angular_damp = 4.0
	var roce := PhysicsMaterial.new()
	roce.friction = 1.0
	roce.bounce = 0.0
	physics_material_override = roce
	var forma := BoxShape3D.new()
	forma.size = TAMANO
	var colision := CollisionShape3D.new()
	colision.shape = forma
	add_child(colision)
	_malla_hoja = MeshInstance3D.new()
	_malla_hoja.name = "HojaVisual"
	var caja := BoxMesh.new()
	caja.size = TAMANO
	_malla_hoja.mesh = caja
	_material_hoja = StandardMaterial3D.new()
	_material_hoja.albedo_color = Color("d7ac69")
	_material_hoja.cull_mode = BaseMaterial3D.CULL_DISABLED
	_malla_hoja.material_override = _material_hoja
	add_child(_malla_hoja)
	var franja := MeshInstance3D.new()
	var franja_malla := BoxMesh.new()
	franja_malla.size = Vector3(0.17, 0.002, 0.018)
	franja.mesh = franja_malla
	franja.position = Vector3(0.0, 0.008, -0.045)
	var tinta := StandardMaterial3D.new()
	tinta.albedo_color = Color("173b50")
	franja.material_override = tinta
	add_child(franja)
	var pestana := MeshInstance3D.new()
	var pestana_malla := BoxMesh.new()
	pestana_malla.size = Vector3(.085, .012, .025)
	pestana.mesh = pestana_malla
	pestana.position = Vector3(-.055, 0, -.095)
	pestana.material_override = _material_hoja
	add_child(pestana)
	_marcador_recoger = MODELOS.crear_mano_recoger()
	add_child(_marcador_recoger)
	_marcador_recoger.top_level = true
	_actualizar_marcador()


func _process(delta: float) -> void:
	if portador != null:
		return
	_tiempo_resaltado += delta
	_actualizar_marcador()


func actualizar_expediente(requeridas: Array[String], hechas: Array[String]) -> void:
	var firma := str(requeridas) + str(hechas)
	if firma == _firma_expediente: return
	_firma_expediente = firma
	for pieza in _piezas_expediente: pieza.queue_free()
	_piezas_expediente.clear()
	for i in requeridas.size():
		var pieza := MeshInstance3D.new()
		var malla := BoxMesh.new()
		malla.size = Vector3(.026, .003, .085)
		pieza.mesh = malla
		pieza.position = Vector3(-.075+i*.035, .009, .008)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("fff1d8") if hechas.has(requeridas[i]) else Color("ba945c")
		pieza.material_override = material
		add_child(pieza)
		_piezas_expediente.append(pieza)


func _actualizar_marcador() -> void:
	if not is_instance_valid(_marcador_recoger):
		return
	_marcador_recoger.visible = portador == null and mostrar_indicador and not enfocado
	if _marcador_recoger.visible:
		_marcador_recoger.global_position = global_position + Vector3.UP * (0.34 + sin(_tiempo_resaltado * 3.0) * 0.015)
		var camara := get_viewport().get_camera_3d()
		if is_instance_valid(camara):
			_marcador_recoger.global_basis = camara.global_basis.orthonormalized().scaled(Vector3.ONE * 0.55)


func interactuar(jugador: Player) -> void:
	if portador != null or jugador.papel_en_mano != null:
		return
	var gestor := get_tree().get_first_node_in_group("gestor_partida")
	if gestor == null or not gestor.has_method("recoger_papel"):
		return
	gestor.recoger_papel(jugador, self)


func tomar(jugador: Player) -> void:
	portador = jugador
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	# Conservar el tamaño mundial al pasar del escenario al esqueleto escalado.
	reparent(jugador.anclaje_papel(), true)
	position = Vector3(0.0, 0.12, TAMANO.z * scale.z * 0.5 + 0.025)
	rotation = Vector3.ZERO
	jugador.papel_en_mano = self
	_actualizar_marcador()


func lanzar() -> void:
	if is_instance_valid(red) and not red.aplicando:
		SesionLAN.solicitar("lanzar")
		return
	if not is_instance_valid(portador):
		return
	var jugador := portador
	var direccion := jugador.visual.global_basis.z.normalized()
	jugador.papel_en_mano = null
	portador = null
	# Se libera donde está la mano, con el tamaño y orientación del último frame.
	reparent(jugador.get_tree().current_scene, true)
	freeze = false
	# El ShapeCast (máscara 5) aún la detecta; el cuerpo del jugador (máscara 1) no.
	collision_layer = 4
	collision_mask = 1
	linear_velocity = direccion * IMPULSO_HORIZONTAL + Vector3.UP * IMPULSO_VERTICAL
	angular_velocity = Vector3(0.2, 0.6, 0.4)
	_actualizar_marcador()


func _physics_process(_delta: float) -> void:
	if is_instance_valid(red) and not SesionLAN.es_anfitrion():
		return
	if nivel_agua > -INF and portador == null:
		sleeping = false
	if portador == null and global_position.y < -12.0:
		var gestor := get_tree().get_first_node_in_group("gestor_partida")
		if gestor != null and gestor.has_method("recuperar_papel_perdido"):
			gestor.recuperar_papel_perdido(self)


func _integrate_forces(estado: PhysicsDirectBodyState3D) -> void:
	if portador != null or nivel_agua == -INF:
		return
	var profundidad := nivel_agua - estado.transform.origin.y
	if profundidad > -0.04:
		# Resorte amortiguado: conserva el lanzamiento y aterriza sobre el agua.
		var empuje := maxf(0.0, estado.total_gravity.length() + profundidad * 65.0 - estado.linear_velocity.y * 12.0)
		estado.linear_velocity.y += empuje * estado.step
		estado.angular_velocity *= maxf(0.0, 1.0 - estado.step * 5.0)
