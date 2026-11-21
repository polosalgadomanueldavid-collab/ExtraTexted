extends Node3D
## Dos corrientes con sección redonda, continuidad en las manos y gotas balísticas.
const AGUA := preload("res://Objetos/ZonaDescanso/agua_flujo.gdshader")
const RUIDO := preload("res://Objetos/ZonaDescanso/ruido_flujo.tres")
const TORBELLINO := preload("res://Objetos/ZonaDescanso/torbellino_agua.gd")
var jugador: Player
var _chorros: Array[MeshInstance3D] = []
var _material: ShaderMaterial
var _gotas: MultiMeshInstance3D
var _reloj := 0.0
var _torbellino: Node3D

func _ready() -> void:
	_torbellino = TORBELLINO.new()
	add_child(_torbellino)
	_material = ShaderMaterial.new()
	_material.shader = AGUA
	_material.set_shader_parameter("ruido", RUIDO)
	for i in 2:
		var chorro := MeshInstance3D.new()
		chorro.material_override = _material
		chorro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(chorro)
		_chorros.append(chorro)
	_gotas = MultiMeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 1
	esfera.height = 2
	esfera.radial_segments = 12
	esfera.rings = 6
	esfera.material = _material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = esfera
	multi.instance_count = 36
	_gotas.multimesh = multi
	_gotas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_gotas)

func _punto(u: float, lado: int, fase: float) -> Vector3:
	var mano: Node3D = jugador.gestos.mano_izquierda if lado == 0 else jugador.gestos.mano_derecha
	var fin := to_local(mano.global_position)
	var s := 1.0 if lado == 0 else -1.0
	var disparo := smoothstep(.68, .96, fase)
	var p0 := Vector3(s * .35, .06, -.20)
	var p1 := Vector3(s * (.68 + .07 * sin(_reloj * 2)), .25 + .18 * sin(_reloj * 1.6 + lado), -.45)
	var p2 := fin + Vector3(s * .25, .18, -.22)
	if disparo > 0:
		p0 = p0.lerp(fin - Vector3(0, .08, .15), disparo)
		p1 = p1.lerp(fin + Vector3(s * .05, .22, .3), disparo)
		p2 = fin + Vector3(s * .12, .28 - disparo * .14, disparo * 1.2)
		fin += Vector3(s * disparo * .25, -.14 * disparo, disparo * 2.3)
	var v := 1.0 - u
	var p := p0 * v * v * v + p1 * 3.0 * v * v * u + p2 * 3.0 * v * u * u + fin * u * u * u
	var ondular := sin(u * PI) * .018
	p += Vector3(sin(u * 18 - _reloj * 7 + lado), cos(u * 13 - _reloj * 5), sin(u * 11 - _reloj * 6)) * ondular
	return p

func actualizar(reloj: float, presencia: float) -> void:
	_reloj = reloj
	var fase := clampf(reloj / 3.6, 0, 1)
	_material.set_shader_parameter("reloj", reloj)
	_material.set_shader_parameter("presencia", presencia)
	var manos := to_local((jugador.gestos.mano_izquierda.global_position + jugador.gestos.mano_derecha.global_position) * .5)
	_torbellino.actualizar(reloj, presencia, manos)
	for lado in 2:
		_chorros[lado].mesh = _tubo(lado, fase, presencia)
	for i in 36:
		var lado := i % 2
		var edad := fposmod(reloj * 1.25 + i * .618, 1.0)
		var u := .25 + fposmod(i * .371, .70)
		var inicio := _punto(u, lado, fase)
		var tangente := (_punto(minf(1, u + .015), lado, fase) - inicio).normalized()
		var dispersion := Vector3(sin(i * 2.4), .5 + sin(i * 3.7) * .3, cos(i * 2.4))
		var p := inicio + (tangente * .18 + dispersion * .12) * edad
		p.y -= .30 * edad * edad
		var tamano := (.004 + (i % 4) * .002) * sin(edad * PI) * presencia
		_gotas.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(tamano, tamano * 1.55, tamano)), p))

func _tubo(lado: int, fase: float, presencia: float) -> ArrayMesh:
	const TRAMOS := 48
	const LADOS := 12
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var eje_anterior := Vector3.RIGHT
	for j in TRAMOS + 1:
		var u := float(j) / TRAMOS
		var centro := _punto(u, lado, fase)
		var tangente := (_punto(minf(1, u + .005), lado, fase) - _punto(maxf(0, u - .005), lado, fase)).normalized()
		# Marco transportado: evita que la sección dé un giro al cruzar la vertical.
		var eje := (eje_anterior - tangente * eje_anterior.dot(tangente)).normalized()
		if eje.length_squared() < .1:
			eje = tangente.cross(Vector3.FORWARD).normalized()
		eje_anterior = eje
		var otro := tangente.cross(eje).normalized()
		var radio := (.045 + .085 * sin(u * PI)) * (.83 + .17 * sin(u * 22 - _reloj * 8 + lado))
		radio *= smoothstep(0, .07, u) * (1.0 - smoothstep(.94, 1.0, u)) * sqrt(maxf(.001, presencia))
		for k in LADOS + 1:
			var a := k * TAU / LADOS
			var n := eje * cos(a) + otro * sin(a)
			var irregular := 1.0 + .10 * sin(a * 3 + u * 17 - _reloj * 5)
			st.set_normal(n)
			st.set_uv(Vector2(u, float(k) / LADOS))
			st.add_vertex(centro + n * radio * irregular)
	for j in TRAMOS:
		for k in LADOS:
			var a := j * (LADOS + 1) + k
			for indice: int in [a, a + 1, a + LADOS + 1, a + 1, a + LADOS + 2, a + LADOS + 1]:
				st.add_index(indice)
	return st.commit()
