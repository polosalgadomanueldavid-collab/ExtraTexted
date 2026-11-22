extends Node3D
## Agua reunida -> columna envolvente -> frente de ola. Todo usa el reloj del gesto.
const SHADER := preload("res://Objetos/ZonaDescanso/manto_agua.gdshader")
const RUIDO := preload("res://Objetos/ZonaDescanso/ruido_flujo.tres")
const GOTAS := 120
var _manto: MeshInstance3D
var _base: MeshInstance3D
var _ola: MeshInstance3D
var _espirales: Array[MeshInstance3D] = []
var _espuma: MultiMeshInstance3D
var _materiales: Array[ShaderMaterial] = []
var _reloj := 0.0
var _formacion := 0.0
var _salida := 0.0
var _altura := 0.0

func _ready() -> void:
	_base = _pieza(.62)
	_manto = _pieza(.48)
	for i in 3:
		_espirales.append(_pieza(.78))
	_ola = _pieza(.82)
	_espuma = MultiMeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 1.0
	esfera.height = 2.0
	esfera.radial_segments = 8
	esfera.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(.72, .93, 1, .85)
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = .3
	esfera.material = mat
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = esfera
	multi.instance_count = GOTAS
	_espuma.multimesh = multi
	_espuma.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_espuma)

func _pieza(opacidad: float) -> MeshInstance3D:
	var pieza := MeshInstance3D.new()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("ruido", RUIDO)
	mat.set_shader_parameter("opacidad", opacidad)
	pieza.material_override = mat
	pieza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_materiales.append(mat)
	add_child(pieza)
	return pieza

func actualizar(reloj: float, presencia: float, manos: Vector3) -> void:
	_reloj = reloj
	var fase := clampf(reloj / 3.6, 0, 1)
	_formacion = smoothstep(.04, .38, fase)
	_salida = smoothstep(.66, .96, fase)
	_altura = lerpf(.10, 1.52, _formacion) + sin(fase * PI) * .10
	var envolver := (1.0 - smoothstep(.69, .88, fase)) * presencia
	var ola := smoothstep(.64, .73, fase) * presencia
	for mat in _materiales:
		mat.set_shader_parameter("reloj", reloj)
		mat.set_shader_parameter("presencia", presencia)
	(_manto.material_override as ShaderMaterial).set_shader_parameter("presencia", envolver)
	(_ola.material_override as ShaderMaterial).set_shader_parameter("presencia", ola)
	_manto.visible = envolver > .01
	_ola.visible = ola > .01
	_base.mesh = _superficie(0, 96, 10)
	if _manto.visible:
		_manto.mesh = _superficie(1, 96, 18)
	for i in 3:
		_espirales[i].visible = envolver > .01
		(_espirales[i].material_override as ShaderMaterial).set_shader_parameter("presencia", envolver)
		if _espirales[i].visible:
			_espirales[i].mesh = _superficie(2 + i, 96, 10)
	if _ola.visible:
		_ola.position = Vector3(manos.x * .25, 0, .28 + _salida * 3.0)
		_ola.mesh = _superficie(5, 80, 24)
	for i in GOTAS:
		var u := float(i) / GOTAS
		var edad := fposmod(reloj * .75 + i * .618, 1.0)
		var a := u * TAU * 5 + reloj * 4.5
		var r := .52 + .42 * u + edad * .23
		var p := Vector3(cos(a) * r, .06 + u * _altura + edad * .25 - edad * edad * .35, sin(a) * r)
		if _salida > 0:
			var frente := Vector3((u * 2 - 1) * 1.35, .12 + sin(u * PI) * .9 + edad * .2, .35 + _salida * 3.0 + edad * .6)
			p = p.lerp(frente, _salida)
		var tamano := (.008 + (i % 5) * .003) * sin(edad * PI) * presencia
		_espuma.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(tamano, tamano * 1.4, tamano)), p))
		_espuma.multimesh.set_instance_color(i, Color(1, 1, 1, (1.0 - edad) * presencia))

func _punto(tipo: int, u: float, v: float) -> Vector3:
	if tipo == 0:
		var a := u * TAU
		var r := lerpf(.27, 1.20 + _salida * .50, v)
		var y := .018 + sin(v * PI) * (.045 + _formacion * .07) + sin(a * 5 - _reloj * 7 + v * 9) * .018 * sin(v * PI)
		return Vector3(cos(a) * r, y, sin(a) * r)
	if tipo == 1:
		var a := u * TAU
		var r := .42 + pow(v, 1.6) * .38 + sin(v * PI) * .06
		r += sin(a * 3 - v * 11 - _reloj * 7) * .035 * _formacion
		var y := .035 + v * _altura
		y += pow(v, 5) * (.055 * sin(a * 5 - _reloj * 6) + .035 * sin(a * 9 + _reloj * 3))
		return Vector3(cos(a) * r, y, sin(a) * r)
	if tipo < 5:
		var indice := tipo - 2
		var a := u * TAU * 1.15 - _reloj * 4.3 + indice * TAU / 3.0
		var h := .04 + u * _altura
		var r := .47 + pow(u, 1.5) * .40
		var b := v * TAU
		var grosor := sin(u * PI) * (.10 + _formacion * .045)
		r += cos(b) * grosor
		h += sin(b) * grosor * 1.25
		return Vector3(cos(a) * r, h, sin(a) * r)
	# Ola ancha con cresta que se enrolla hacia delante; la base permanece baja.
	var x := (u * 2 - 1) * (1.05 + _salida * .35)
	var envolvente := pow(maxf(0, sin(u * PI)), .30)
	var angulo := lerpf(-PI * .5, PI * .70, v)
	var alto := (.52 + .12 * sin(u * PI * 3 + _reloj * 3)) * envolvente
	var y := .02 + (1 + sin(angulo)) * alto
	var z := cos(angulo) * (.32 + _salida * .13) + sin(u * PI * 4 + _reloj * 5) * .035 * v
	return Vector3(x, y, z)

func _superficie(tipo: int, nx: int, ny: int) -> ArrayMesh:
	# Muestrear cada punto una sola vez; los vecinos proporcionan las normales.
	var puntos := PackedVector3Array()
	for j in ny + 1:
		for i in nx + 1:
			puntos.append(_punto(tipo, float(i) / nx, float(j) / ny))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in ny + 1:
		var v := float(j) / ny
		for i in nx + 1:
			var u := float(i) / nx
			var p := puntos[j * (nx + 1) + i]
			var du := puntos[j * (nx + 1) + mini(nx, i + 1)] - puntos[j * (nx + 1) + maxi(0, i - 1)]
			var dv := puntos[mini(ny, j + 1) * (nx + 1) + i] - puntos[maxi(0, j - 1) * (nx + 1) + i]
			var normal := du.cross(dv).normalized()
			var cresta := 0.0
			var alpha := 1.0
			if tipo == 0:
				cresta = smoothstep(.78, .98, v) * (.65 + .35 * sin(u * 33 + _reloj * 4))
				alpha = sin(v * PI) * .8
			elif tipo == 1:
				cresta = smoothstep(.85, .99, v)
				alpha = smoothstep(0, .08, v) * (1.0 - smoothstep(.97, 1, v))
			elif tipo < 5:
				cresta = pow(maxf(0, sin(v * TAU)), 3) * .85 + pow(maxf(0, cos(v * TAU)), 8) * .25
				alpha = smoothstep(0, .04, u) * (1.0 - smoothstep(.96, 1, u))
			else:
				cresta = smoothstep(.58, .93, v)
				alpha = pow(maxf(0, sin(u * PI)), .35) * smoothstep(0, .06, v) * (1.0 - smoothstep(.96, 1, v))
			st.set_normal(normal)
			st.set_color(Color(cresta, 0, 0, alpha))
			st.set_uv(Vector2(u, v))
			st.add_vertex(p)
	for j in ny:
		for i in nx:
			var a := j * (nx + 1) + i
			for indice: int in [a, a + 1, a + nx + 1, a + 1, a + nx + 2, a + nx + 1]:
				st.add_index(indice)
	return st.commit()
