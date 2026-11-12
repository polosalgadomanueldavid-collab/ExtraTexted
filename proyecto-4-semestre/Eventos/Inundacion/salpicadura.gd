extends Node3D
## Corona de gotas balísticas y dos ondas que se expanden sobre la superficie.

var intensidad := 1.0
var _tiempo := 0.0
var _gotas: Array[MeshInstance3D] = []
var _velocidades: Array[Vector3] = []
var _ondas: Array[MeshInstance3D] = []
var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color("b9f6ff")
	var gota := SphereMesh.new()
	gota.radius = 0.022 * intensidad
	gota.height = 0.065 * intensidad
	gota.radial_segments = 6
	gota.rings = 3
	for i in 12:
		var angulo := TAU * i / 12.0
		var malla := MeshInstance3D.new()
		malla.mesh = gota
		malla.material_override = _material
		add_child(malla)
		_gotas.append(malla)
		_velocidades.append(Vector3(cos(angulo) * 0.65, 1.0 + (i % 3) * 0.22, sin(angulo) * 0.65) * intensidad)
	for i in 2:
		var onda := MeshInstance3D.new()
		var aro := TorusMesh.new()
		aro.inner_radius = 0.20
		aro.outer_radius = 0.23
		aro.rings = 24
		aro.ring_segments = 6
		onda.mesh = aro
		onda.material_override = _material
		add_child(onda)
		_ondas.append(onda)


func _process(delta: float) -> void:
	_tiempo += delta
	for i in _gotas.size():
		_gotas[i].position = _velocidades[i] * _tiempo + Vector3.DOWN * 2.6 * _tiempo * _tiempo
		_gotas[i].visible = _gotas[i].position.y >= 0.0
	for i in _ondas.size():
		var radio := (0.2 + maxf(0.0, _tiempo - i * 0.12) * 2.8) * intensidad
		_ondas[i].scale = Vector3(radio, 0.18, radio)
	_material.albedo_color.a = 1.0 - smoothstep(0.3, 1.0, _tiempo)
	if _tiempo >= 1.0:
		queue_free()
