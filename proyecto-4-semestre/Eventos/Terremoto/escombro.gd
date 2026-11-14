extends StaticBody3D
## Placas de techo fracturadas, yeso, áridos y armadura expuesta.

const EFECTO := preload("res://Eventos/Terremoto/EfectoFractura.tscn")
const IMPACTO := preload("res://Audios/Eventos/terremoto_ruptura.wav")
const AVISO_SHADER := preload("res://Eventos/Terremoto/aviso_escombro.gdshader")
const RADIO := 0.23
const ALTURA := 0.48
const AVISO := 0.85
const CAIDA := 0.72

var celda: Vector2i
var celdas: Array[Vector2i] = []
var asentado := false
var _activo := false
var _tiempo := 0.0
var _altura_techo := 5.8
var _tamano := Vector2.ONE * RADIO * 2.0
var _restos: Node3D
var _aviso: MeshInstance3D
var _material_aviso: ShaderMaterial
var _polvo: Node3D
var _sonido: AudioStreamPlayer3D
var _piezas: Array[MeshInstance3D] = []
var _poses: Array[Transform3D] = []
var _giro := 0.0


func preparar(altura_techo: float, azar: RandomNumberGenerator, tamano: Vector2 = Vector2.ONE * RADIO * 2.0) -> void:
	collision_layer = 0
	collision_mask = 0
	_altura_techo = altura_techo
	_tamano = tamano
	if celdas.is_empty():
		celdas.append(celda)
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(tamano.x, ALTURA, tamano.y)
	forma.shape = caja
	forma.position.y = ALTURA * 0.5
	add_child(forma)
	_restos = Node3D.new()
	add_child(_restos)
	_giro = azar.randf_range(-PI, PI)
	var piedra := StandardMaterial3D.new()
	piedra.vertex_color_use_as_albedo = true
	piedra.roughness = 1.0
	piedra.emission_enabled = true
	piedra.emission = Color(0.07, 0.058, 0.04)
	# Base ancha de fragmentos, evitando la silueta de columnas de piedra.
	for i in range(13):
		var angulo := TAU * i / 13.0 + _giro
		var radio := azar.randf_range(0.20, 0.34)
		var medidas := Vector3(azar.randf_range(0.17, 0.29), azar.randf_range(0.07, 0.14), azar.randf_range(0.15, 0.26))
		var posicion := Vector3(cos(angulo) * radio, medidas.y * 0.5, sin(angulo) * radio)
		_agregar_losa(medidas, posicion, Vector3(azar.randf_range(-0.2, 0.2), angulo, azar.randf_range(-0.2, 0.2)), Color("b1a38a"), piedra, azar)
	# Placas de hormigón con la cara pintada de marfil y el canto oscuro roto.
	_agregar_losa(Vector3(0.80, 0.12, 0.70), Vector3(0, 0.12, 0), Vector3(0.08, _giro, -0.13), Color("a99c85"), piedra, azar)
	_agregar_losa(Vector3(0.69, 0.11, 0.62), Vector3(-0.09, 0.22, 0.06), Vector3(0.32, _giro + 1.2, 0.16), Color("e0d7bd"), piedra, azar)
	_agregar_losa(Vector3(0.53, 0.09, 0.48), Vector3(0.09, 0.34, -0.06), Vector3(-0.24, _giro - 0.8, -0.18), Color("eee3c7"), piedra, azar)
	for i in range(3):
		var varilla := MeshInstance3D.new()
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("67503b")
		material.metallic = 0.6
		material.roughness = 0.68
		var datos := SurfaceTool.new()
		datos.begin(Mesh.PRIMITIVE_TRIANGLES)
		var x := -0.19 + i * 0.16
		var a := Vector3(x, 0.22, -0.31)
		var b := Vector3(x, 0.34, 0.14)
		var c := Vector3(x + 0.07, 0.46, 0.28)
		_barra(datos, a, b)
		_barra(datos, b, c)
		varilla.mesh = datos.commit()
		varilla.material_override = material
		_restos.add_child(varilla)
	# Una sola huella física y visual; las piezas no invaden los pasos vecinos.
	var limites := AABB()
	for hijo: MeshInstance3D in _restos.get_children():
		limites = limites.merge(hijo.transform * hijo.get_aabb())
	_restos.scale = Vector3(tamano.x / limites.size.x, 1.0, tamano.y / limites.size.z)
	for hijo: MeshInstance3D in _restos.get_children():
		hijo.position.x -= limites.get_center().x
		hijo.position.z -= limites.get_center().z
		_piezas.append(hijo)
		_poses.append(hijo.transform)
	_restos.hide()
	_aviso = MeshInstance3D.new()
	var marca := PlaneMesh.new()
	marca.size = tamano + Vector2.ONE * 0.16
	_aviso.mesh = marca
	_aviso.position.y = 0.018
	_material_aviso = ShaderMaterial.new()
	_material_aviso.shader = AVISO_SHADER
	_material_aviso.set_shader_parameter("medidas", tamano)
	_aviso.material_override = _material_aviso
	_aviso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_aviso)
	_aviso.hide()
	_polvo = EFECTO.instantiate()
	_polvo.scale = Vector3(maxf(0.8, tamano.x), 0.8, maxf(0.8, tamano.y))
	add_child(_polvo)
	var polvo := _polvo.get_node("Polvareda") as CPUParticles3D
	polvo.amount = 14
	var degradado := Gradient.new()
	degradado.offsets = PackedFloat32Array([0, 0.25, 1])
	degradado.colors = PackedColorArray([Color(0.78, 0.74, 0.65, 0.5), Color(0.75, 0.72, 0.65, 0.35), Color(0.8, 0.77, 0.7, 0)])
	polvo.color_ramp = degradado
	_sonido = AudioStreamPlayer3D.new()
	_sonido.stream = IMPACTO
	_sonido.volume_db = -20.0
	_sonido.pitch_scale = azar.randf_range(0.8, 0.94)
	_sonido.max_distance = 18.0
	add_child(_sonido)


func _agregar_losa(tamano: Vector3, posicion: Vector3, giro: Vector3, color: Color, material: Material, azar: RandomNumberGenerator) -> void:
	var pieza := MeshInstance3D.new()
	pieza.mesh = _malla_losa(tamano, color, azar)
	pieza.material_override = material
	pieza.position = posicion
	pieza.rotation = giro
	_restos.add_child(pieza)


func _malla_losa(tamano: Vector3, color: Color, azar: RandomNumberGenerator) -> ArrayMesh:
	var contorno := PackedVector2Array([Vector2(-0.48, -0.37), Vector2(-0.25, -0.50),
		Vector2(0.42, -0.46), Vector2(0.50, 0.06), Vector2(0.25, 0.47), Vector2(-0.31, 0.42), Vector2(-0.50, 0.18)])
	for i in range(contorno.size()):
		contorno[i] += Vector2(azar.randf_range(-0.035, 0.035), azar.randf_range(-0.035, 0.035))
	var datos := SurfaceTool.new()
	datos.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(contorno.size()):
		var a := contorno[i]
		var b := contorno[(i + 1) % contorno.size()]
		var v1 := Vector3(a.x * tamano.x, tamano.y * 0.5, a.y * tamano.z)
		var v2 := Vector3(b.x * tamano.x, tamano.y * 0.5, b.y * tamano.z)
		var v3 := v2 - Vector3.UP * tamano.y
		var v4 := v1 - Vector3.UP * tamano.y
		_triangulo(datos, Vector3.UP * tamano.y * 0.5, v1, v2, color.lightened(azar.randf_range(0.0, 0.06)))
		_triangulo(datos, Vector3.DOWN * tamano.y * 0.5, v3, v4, color.darkened(0.30))
		var canto := Color("b7a58b").darkened(azar.randf_range(0.0, 0.14))
		_triangulo(datos, v1, v4, v3, canto)
		_triangulo(datos, v1, v3, v2, canto)
		# Áridos expuestos en las caras rotas, de colores distintos al yeso.
		var centro := (v1 + v2 + v3 + v4) * 0.25
		var normal := Vector3(a.x + b.x, 0, a.y + b.y).normalized()
		centro += normal * 0.001
		var tangente := (v2 - v1).normalized() * minf(0.023, tamano.x * 0.08)
		_triangulo(datos, centro - tangente, centro + Vector3.UP * tamano.y * 0.26, centro + tangente, Color("c6baa2"))
	# Fisura oscura superficial que llega al canto.
	var y := tamano.y * 0.5 + 0.001
	_triangulo(datos, Vector3(-tamano.x * 0.40, y, 0.04 * tamano.z), Vector3(0.1 * tamano.x, y, -0.03 * tamano.z), Vector3(-0.05 * tamano.x, y, -0.04 * tamano.z), Color("756c5b"))
	return datos.commit()


func _triangulo(datos: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	datos.set_color(color)
	datos.set_normal((c - a).cross(b - a).normalized())
	for p: Vector3 in [a, b, c]:
		datos.add_vertex(p)


func _barra(datos: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var eje := a.direction_to(b)
	var u := eje.cross(Vector3.RIGHT).normalized() * 0.012
	var v := eje.cross(u).normalized() * 0.012
	for i in range(6):
		var inicio := u * cos(TAU * i / 6.0) + v * sin(TAU * i / 6.0)
		var fin := u * cos(TAU * (i + 1) / 6.0) + v * sin(TAU * (i + 1) / 6.0)
		_triangulo(datos, a + inicio, b + fin, b + inicio, Color.WHITE)
		_triangulo(datos, a + inicio, a + fin, b + fin, Color.WHITE)


func iniciar_aviso(retraso: float) -> void:
	_tiempo = -retraso
	_activo = true


func avanzar(delta: float) -> bool:
	if not _activo:
		return false
	_tiempo += delta
	if asentado:
		var rebote := clampf((_tiempo - AVISO - CAIDA) / 0.32, 0.0, 1.0)
		_restos.position.y = sin(rebote * PI) * 0.045 * (1.0 - rebote)
		return false
	if _tiempo < 0.0:
		return false
	_aviso.show()
	_material_aviso.set_shader_parameter("progreso", clampf(_tiempo / (AVISO + CAIDA), 0.0, 1.0))
	_material_aviso.set_shader_parameter("reloj", _tiempo)
	if _tiempo < AVISO:
		return false
	_restos.show()
	var caida := clampf((_tiempo - AVISO) / CAIDA, 0.0, 1.0)
	_restos.position.y = (_altura_techo - ALTURA) * (1.0 - caida * caida)
	for i in range(_piezas.size()):
		var pose := _poses[i]
		pose.origin.y += (1.0 - caida) * (0.12 * (i % 5))
		pose.basis = pose.basis.rotated(Vector3.RIGHT, (1.0 - caida) * sin(float(i)) * 0.7)
		_piezas[i].transform = pose
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
	return Rect2(Vector2(global_position.x, global_position.z) - _tamano * 0.5, _tamano)


func retirar() -> void:
	_activo = false
	collision_layer = 0
	_sonido.stop()
	hide()
	queue_free()
