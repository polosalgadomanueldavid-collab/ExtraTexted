extends Node3D
## Corona dentada, chorro de rebote, gotas balísticas y ondas de espuma rotas.
## Una sola MultiMesh para todas las gotas de cada impacto.

const CORONA := preload("res://Eventos/Inundacion/salpicadura.gdshader")
const ONDA := preload("res://Eventos/Inundacion/onda.gdshader")
const DURACION := 1.85
var intensidad := 1.0
var solo_ondas := false
var _tiempo := 0.0
var _corona: MeshInstance3D
var _chorro: MeshInstance3D
var _ondas: MeshInstance3D
var _gotas: MultiMeshInstance3D
var _material: ShaderMaterial
var _material_chorro: ShaderMaterial
var _material_onda: ShaderMaterial
var _velocidades: Array[Vector3] = []
static var _malla_corona: ArrayMesh
static var _malla_gota: SphereMesh
static var _malla_onda: PlaneMesh
static var _material_gotas: StandardMaterial3D


func _ready() -> void:
	_preparar_mallas()
	_material_onda = ShaderMaterial.new()
	_material_onda.shader = ONDA
	_material_onda.render_priority = 3
	_ondas = _crear_malla(_malla_onda, _material_onda)
	_ondas.scale = Vector3.ONE * intensidad
	if solo_ondas:
		return
	_material = ShaderMaterial.new()
	_material.shader = CORONA
	_material.set_shader_parameter("fuerza", intensidad)
	_material.render_priority = 4
	_corona = _crear_malla(_malla_corona, _material)
	if intensidad >= 0.7:
		_material_chorro = _material.duplicate() as ShaderMaterial
		_material_chorro.set_shader_parameter("chorro", true)
		_chorro = _crear_malla(_malla_corona, _material_chorro)
	_gotas = MultiMeshInstance3D.new()
	_gotas.multimesh = MultiMesh.new()
	_gotas.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_gotas.multimesh.mesh = _malla_gota
	_gotas.multimesh.instance_count = 14 if intensidad >= 0.7 else 6
	_gotas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gotas.custom_aabb = AABB(Vector3(-2, -0.2, -2), Vector3(4, 3, 4))
	add_child(_gotas)
	for i in _gotas.multimesh.instance_count:
		var angulo := i * 2.39996
		var velocidad := 0.45 + (i % 4) * 0.12
		_velocidades.append(Vector3(cos(angulo) * velocidad, 1.6 + (i % 3) * 0.24, sin(angulo) * velocidad) * sqrt(intensidad))
	_actualizar_gotas()


func _crear_malla(malla: Mesh, material: Material) -> MeshInstance3D:
	var instancia := MeshInstance3D.new()
	instancia.mesh = malla
	instancia.material_override = material
	instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instancia.custom_aabb = AABB(Vector3(-2, -0.1, -2), Vector3(4, 3, 4))
	add_child(instancia)
	return instancia


static func _preparar_mallas() -> void:
	if _malla_corona != null:
		return
	var geometria := SurfaceTool.new()
	geometria.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segmento in 56:
		for nivel in 6:
			for esquina: Vector2i in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var uv := Vector2((segmento + esquina.x) / 56.0, (nivel + esquina.y) / 6.0)
				geometria.set_uv(uv)
				geometria.set_normal(Vector3.UP)
				geometria.add_vertex(Vector3(cos(uv.x * TAU), uv.y, sin(uv.x * TAU)))
	_malla_corona = geometria.commit()
	_malla_onda = PlaneMesh.new()
	_malla_onda.size = Vector2.ONE * 4.0
	_material_gotas = StandardMaterial3D.new()
	_material_gotas.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_gotas.albedo_color = Color("d6fff6")
	_malla_gota = SphereMesh.new()
	_malla_gota.radius = 0.021
	_malla_gota.height = 0.066
	_malla_gota.radial_segments = 6
	_malla_gota.rings = 3
	_malla_gota.material = _material_gotas


func _process(delta: float) -> void:
	_tiempo += delta
	_material_onda.set_shader_parameter("edad", _tiempo)
	if not solo_ondas:
		_material.set_shader_parameter("edad", _tiempo)
		_corona.visible = _tiempo < 0.8
		if is_instance_valid(_chorro):
			_material_chorro.set_shader_parameter("edad", _tiempo)
			_chorro.visible = _tiempo > 0.10 and _tiempo < 0.78
		_actualizar_gotas()
	if _tiempo >= DURACION:
		queue_free()


func _actualizar_gotas() -> void:
	for i in _velocidades.size():
		var t := maxf(0, _tiempo - 0.06 - (i % 3) * 0.025)
		var punto := _velocidades[i] * t + Vector3.DOWN * 2.8 * t * t
		var velocidad := _velocidades[i] + Vector3.DOWN * 5.6 * t
		var tamano := intensidad * (1.0 - smoothstep(0.45, 0.8, t)) if punto.y >= 0.0 and t > 0.0 else 0.001
		var orientacion := Basis(Quaternion(Vector3.UP, velocidad.normalized()))
		_gotas.multimesh.set_instance_transform(i, Transform3D(orientacion.scaled(Vector3.ONE * maxf(0.001, tamano)), punto))
