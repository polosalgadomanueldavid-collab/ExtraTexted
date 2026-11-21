extends Node3D
## Un chorro continuo con nÃºcleo, envolvente turbulenta y brasas pequeÃ±as.
const SHADER := preload("res://Objetos/ZonaDescanso/fuego_flujo.gdshader")
const RUIDO := preload("res://Objetos/ZonaDescanso/ruido_flujo.tres")
static var _malla: ArrayMesh
var ancho := .24
var profundo := .16
var intensidad := 0.0
var largo := .7
var reloj := 0.0
var semilla := 0.0
var _materiales: Array[ShaderMaterial] = []
var _brasas: MultiMeshInstance3D

func _ready() -> void:
	if _malla == null:
		_malla = _crear_malla()
	for i in 3:
		var lengua := MeshInstance3D.new()
		lengua.mesh = _malla
		lengua.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("ruido", RUIDO)
		mat.set_shader_parameter("capa", i * .5)
		mat.set_shader_parameter("semilla", semilla + i * .37)
		lengua.material_override = mat
		_materiales.append(mat)
		add_child(lengua)
	_brasas = MultiMeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 1.0
	esfera.height = 2.0
	esfera.radial_segments = 8
	esfera.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	esfera.material = mat
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = esfera
	multi.instance_count = 18
	_brasas.multimesh = multi
	_brasas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_brasas)
	establecer_intensidad(0)

func establecer_intensidad(valor: float) -> void:
	intensidad = clampf(valor, 0, 1)
	visible = intensidad > .005
	for i in _materiales.size():
		_materiales[i].set_shader_parameter("reloj", reloj)
		_materiales[i].set_shader_parameter("intensidad", intensidad)
		_materiales[i].set_shader_parameter("largo", largo * (1.0 - i * .16))
		_materiales[i].set_shader_parameter("radio", ancho * (.48 - i * .12) * sqrt(maxf(.01, intensidad)))
	if _brasas == null:
		return
	for i in 18:
		var edad := fposmod(reloj * 1.6 + i * .618 + semilla, 1.0)
		var angulo := i * 2.399 + semilla
		var r := (.025 + edad * .12) * sin(i * 7.1)
		var p := Vector3(cos(angulo) * r, edad * largo * 1.15, sin(angulo) * r)
		var tamano := (.002 + (i % 3) * .0015) * (1.0 - edad) * intensidad
		_brasas.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(tamano, tamano * 2.8, tamano)), p))
		_brasas.multimesh.set_instance_color(i, Color(1, .65 + .25 * (1.0 - edad), .2, (1.0 - edad) * intensidad))

func _crear_malla() -> ArrayMesh:
	const ANILLOS := 72
	const LADOS := 40
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in ANILLOS + 1:
		for i in LADOS + 1:
			var a := i * TAU / LADOS
			st.set_uv(Vector2(float(i) / LADOS, float(j) / ANILLOS))
			st.set_normal(Vector3(cos(a), 0, sin(a)))
			st.add_vertex(Vector3(cos(a), float(j) / ANILLOS, sin(a)))
	for j in ANILLOS:
		for i in LADOS:
			var k := j * (LADOS + 1) + i
			for n: int in [k, k + 1, k + LADOS + 1, k + 1, k + LADOS + 2, k + LADOS + 1]:
				st.add_index(n)
	return st.commit()
