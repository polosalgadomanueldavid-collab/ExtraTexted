class_name PapelDenuncia
extends RigidBody3D

const TAMANO := Vector3(0.24, 0.012, 0.18)

var denuncia_id: String = ""
var portador: Player = null


func _ready() -> void:
	name = "PapelDenuncia"
	add_to_group("papeles_denuncia")
	contact_monitor = false
	continuous_cd = true
	var forma := BoxShape3D.new()
	forma.size = TAMANO
	var colision := CollisionShape3D.new()
	colision.shape = forma
	add_child(colision)
	var malla := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = TAMANO
	malla.mesh = caja
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("fff1d8")
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	malla.material_override = material
	add_child(malla)
	var franja := MeshInstance3D.new()
	var franja_malla := BoxMesh.new()
	franja_malla.size = Vector3(0.17, 0.002, 0.018)
	franja.mesh = franja_malla
	franja.position = Vector3(0.0, 0.008, -0.045)
	var tinta := StandardMaterial3D.new()
	tinta.albedo_color = Color("173b50")
	franja.material_override = tinta
	add_child(franja)


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
	get_parent().remove_child(self)
	jugador.visual.add_child(self)
	position = Vector3(0.42, 2.45, 0.55)
	rotation = Vector3(-0.18, 0.0, 0.2)
	jugador.papel_en_mano = self


func lanzar() -> void:
	if not is_instance_valid(portador):
		return
	var jugador := portador
	var origen := jugador.global_position + Vector3.UP * 0.8 + jugador.visual.global_basis.z.normalized() * 0.4
	var direccion := jugador.visual.global_basis.z.normalized()
	jugador.papel_en_mano = null
	portador = null
	get_parent().remove_child(self)
	jugador.get_tree().current_scene.add_child(self)
	global_position = origen
	global_rotation = jugador.visual.global_rotation
	freeze = false
	collision_layer = 1
	collision_mask = 1
	linear_velocity = direccion * 4.5 + Vector3.UP * 2.0
	angular_velocity = Vector3(0.5, 2.0, 1.0)


func _physics_process(_delta: float) -> void:
	if portador == null and global_position.y < -12.0:
		var gestor := get_tree().get_first_node_in_group("gestor_partida")
		if gestor != null and gestor.has_method("recuperar_papel_perdido"):
			gestor.recuperar_papel_perdido(self)
