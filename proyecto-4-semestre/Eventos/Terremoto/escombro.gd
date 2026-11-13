extends StaticBody3D
## Restos de techo: señal en el piso, caída escalonada y bloqueo hasta el cierre.

const EFECTO := preload("res://Eventos/Terremoto/EfectoFractura.tscn")
const IMPACTO := preload("res://Audios/Eventos/terremoto_ruptura.wav")
const RADIO := 0.23
const ALTURA := 0.95
const AVISO := 0.9
const CAIDA := 0.72

var celda: Vector2i
var asentado := false
var _activo := false
var _tiempo := 0.0
var _altura_techo := 5.8
var _restos: Node3D
var _aviso: MeshInstance3D
var _material_aviso: StandardMaterial3D
var _polvo: Node3D
var _sonido: AudioStreamPlayer3D


func preparar(altura_techo: float, azar: RandomNumberGenerator) -> void:
	collision_layer = 0
	collision_mask = 0
	_altura_techo = altura_techo
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(RADIO * 2.0, ALTURA, RADIO * 2.0)
	forma.shape = caja
	forma.position.y = ALTURA * 0.5
	add_child(forma)
	_restos = Node3D.new()
	add_child(_restos)
	# Losas de hormigón facetadas y fragmentos de yeso apilados.
	for i in range(7):
		var pieza := MeshInstance3D.new()
		var malla := CylinderMesh.new()
		malla.top_radius = 0.12 if i % 2 else 0.18
		malla.bottom_radius = 0.21
		malla.height = 0.22
		malla.radial_segments = 5
		malla.rings = 1
		pieza.mesh = malla
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("a49b85").darkened(azar.randf_range(0.0, 0.32))
		material.roughness = 1.0
		pieza.material_override = material
		pieza.position = Vector3(azar.randf_range(-0.025, 0.025), 0.11 + i * 0.118, azar.randf_range(-0.025, 0.025))
		pieza.rotation = Vector3(azar.randf_range(-0.12, 0.12), azar.randf_range(-PI, PI), azar.randf_range(-0.12, 0.12))
		_restos.add_child(pieza)
	_restos.hide()
	_aviso = MeshInstance3D.new()
	var marca := TorusMesh.new()
	marca.inner_radius = 0.29
	marca.outer_radius = 0.34
	marca.rings = 24
	marca.ring_segments = 6
	_aviso.mesh = marca
	_aviso.position.y = 0.018
	_aviso.scale.y = 0.16
	_material_aviso = StandardMaterial3D.new()
	_material_aviso.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_aviso.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material_aviso.albedo_color = Color(1.0, 0.51, 0.13, 0.8)
	_aviso.material_override = _material_aviso
	_aviso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_aviso)
	_aviso.hide()
	_polvo = EFECTO.instantiate()
	add_child(_polvo)
	_sonido = AudioStreamPlayer3D.new()
	_sonido.stream = IMPACTO
	_sonido.volume_db = -21.0
	_sonido.pitch_scale = azar.randf_range(0.8, 0.94)
	_sonido.max_distance = 18.0
	add_child(_sonido)


func iniciar_aviso(retraso: float) -> void:
	_tiempo = -retraso
	_activo = true


func avanzar(delta: float) -> bool:
	if not _activo or asentado:
		return false
	_tiempo += delta
	if _tiempo < 0.0:
		return false
	_aviso.show()
	_material_aviso.albedo_color.a = 0.55 + 0.35 * absf(sin(_tiempo * 9.0))
	if _tiempo < AVISO:
		return false
	_restos.show()
	var caida := clampf((_tiempo - AVISO) / CAIDA, 0.0, 1.0)
	_restos.position.y = (_altura_techo - ALTURA) * (1.0 - caida * caida)
	_restos.rotation.y = (1.0 - caida) * 0.7
	if caida < 1.0:
		return false
	asentado = true
	collision_layer = 1
	_aviso.hide()
	for emisor: CPUParticles3D in _polvo.get_children():
		emisor.restart()
	_sonido.play()
	return true


func huella() -> Rect2:
	return Rect2(Vector2(global_position.x, global_position.z) - Vector2.ONE * RADIO, Vector2.ONE * RADIO * 2.0)


func retirar() -> void:
	_activo = false
	collision_layer = 0
	_sonido.stop()
	hide()
	queue_free()
