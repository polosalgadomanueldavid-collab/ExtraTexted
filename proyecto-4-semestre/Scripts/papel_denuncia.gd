class_name PapelDenuncia
extends RigidBody3D

const TAMANO := Vector3(0.24, 0.012, 0.18)
const IMPULSO_HORIZONTAL := 1.4
const IMPULSO_VERTICAL := 0.5
const RESALTADO := preload("res://MarcadoresEstaciones/resaltado_interaccion.gdshader")

var denuncia_id: String = ""
var portador: Player = null
var _malla_hoja: MeshInstance3D
var _contorno: ShaderMaterial
var _material_hoja: StandardMaterial3D
var _tiempo_resaltado: float = 0.0
var _marcador_recoger: Label3D


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
	_material_hoja.albedo_color = Color("fff1d8")
	_material_hoja.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material_hoja.emission_enabled = true
	_material_hoja.emission = Color("fff1d8")
	_malla_hoja.material_override = _material_hoja
	add_child(_malla_hoja)
	_contorno = ShaderMaterial.new()
	_contorno.shader = RESALTADO
	_actualizar_resaltado()
	var franja := MeshInstance3D.new()
	var franja_malla := BoxMesh.new()
	franja_malla.size = Vector3(0.17, 0.002, 0.018)
	franja.mesh = franja_malla
	franja.position = Vector3(0.0, 0.008, -0.045)
	var tinta := StandardMaterial3D.new()
	tinta.albedo_color = Color("173b50")
	franja.material_override = tinta
	add_child(franja)
	_marcador_recoger = Label3D.new()
	_marcador_recoger.name = "MarcadorRecoger"
	_marcador_recoger.text = "✋ E"
	_marcador_recoger.font_size = 30
	_marcador_recoger.pixel_size = 0.003
	_marcador_recoger.outline_size = 8
	_marcador_recoger.modulate = Color("fff1d8")
	_marcador_recoger.outline_modulate = Color("173b50")
	_marcador_recoger.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_marcador_recoger)
	_marcador_recoger.top_level = true
	_actualizar_marcador()


func _process(delta: float) -> void:
	if portador != null:
		return
	_tiempo_resaltado += delta
	_actualizar_resaltado()
	_actualizar_marcador()


func _actualizar_marcador() -> void:
	if not is_instance_valid(_marcador_recoger):
		return
	_marcador_recoger.visible = portador == null
	if portador == null:
		_marcador_recoger.global_position = global_position + Vector3.UP * (0.23 + sin(_tiempo_resaltado * 3.0) * 0.015)


func _actualizar_resaltado() -> void:
	if not is_instance_valid(_malla_hoja):
		return
	var suelta := portador == null
	var pulso := 0.5 + 0.5 * sin(_tiempo_resaltado * 4.5)
	_malla_hoja.material_overlay = _contorno if suelta else null
	_contorno.set_shader_parameter("grosor", lerpf(0.007, 0.012, pulso) if suelta else 0.0)
	_material_hoja.emission_energy_multiplier = 0.35 + pulso * 0.25 if suelta else 0.0


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
	_actualizar_resaltado()
	_actualizar_marcador()


func lanzar() -> void:
	if not is_instance_valid(portador):
		return
	var jugador := portador
	var origen := jugador.global_position + Vector3.UP * 0.65 + jugador.visual.global_basis.z.normalized() * 0.32
	var direccion := jugador.visual.global_basis.z.normalized()
	jugador.papel_en_mano = null
	portador = null
	get_parent().remove_child(self)
	jugador.get_tree().current_scene.add_child(self)
	global_position = origen
	global_rotation = jugador.visual.global_rotation
	freeze = false
	# El ShapeCast (máscara 5) aún la detecta; el cuerpo del jugador (máscara 1) no.
	collision_layer = 4
	collision_mask = 1
	linear_velocity = direccion * IMPULSO_HORIZONTAL + Vector3.UP * IMPULSO_VERTICAL
	angular_velocity = Vector3(0.2, 0.6, 0.4)
	_actualizar_resaltado()
	_actualizar_marcador()


func _physics_process(_delta: float) -> void:
	if portador == null and global_position.y < -12.0:
		var gestor := get_tree().get_first_node_in_group("gestor_partida")
		if gestor != null and gestor.has_method("recuperar_papel_perdido"):
			gestor.recuperar_papel_perdido(self)
