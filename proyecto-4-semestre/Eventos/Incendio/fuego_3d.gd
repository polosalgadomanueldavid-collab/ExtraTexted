extends Node3D
## Llamas redondas con cuello, punta curva y gotas que se desprenden.
## La silueta tiene volumen 3D; las bandas de color se pintan sobre la malla.

const LLAMA := preload("res://Eventos/Incendio/llama.gdshader")
static var _malla_compartida: ArrayMesh
var intensidad := 1.0
var ancho := 1.0
var profundo := 0.5
var _llamas: Node3D
var _humo: CPUParticles3D
var _chispas: CPUParticles3D
var _materiales: Array[ShaderMaterial] = []
var _gotas: Array[MeshInstance3D] = []
var _reloj := 0.0
var _fase := 0.0


func _ready() -> void:
	_llamas = Node3D.new()
	add_child(_llamas)
	if _malla_compartida == null:
		_malla_compartida = _malla_llama()
	# Ciclos independientes sin consumir el generador de azar de la partida.
	_fase = float(get_instance_id() % 71) * 0.17
	var tamano := 0.60 if ancho < 0.6 else 1.0
	for i in 3:
		var lengua := _crear_lengua(_llamas, _fase + float(i) * 2.1)
		lengua.position = Vector3((float(i) - 1.0) * ancho * 0.29, 0.0, sin(i * 2.4) * profundo * 0.14)
		lengua.rotation.y = i * 2.4
		lengua.scale = Vector3(0.31, 0.76 if i != 1 else 1.02, 0.26) * tamano
	for i in 2:
		_gotas.append(_crear_lengua(_llamas, _fase + i * 2.8))
	_humo = _particulas(6, Color(0.20, 0.19, 0.18, 0.19), 0.10, 1.7)
	_humo.direction = Vector3.UP
	_humo.initial_velocity_min = 0.20
	_humo.initial_velocity_max = 0.4
	_humo.gravity = Vector3(0.04, 0.12, 0.02)
	_humo.position.y = 0.8 * tamano
	_chispas = _particulas(5, Color("ffd076"), 0.012, 0.8)
	_chispas.direction = Vector3.UP
	_chispas.initial_velocity_min = 0.6
	_chispas.initial_velocity_max = 1.0
	_chispas.gravity = Vector3(0, 0.2, 0)
	_actualizar_gotas()
	establecer_intensidad(intensidad)


func _crear_lengua(padre: Node3D, fase: float) -> MeshInstance3D:
	var pieza := MeshInstance3D.new()
	pieza.mesh = _malla_compartida
	pieza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = LLAMA
	material.set_shader_parameter("fase", fase)
	pieza.material_override = material
	_materiales.append(material)
	padre.add_child(pieza)
	return pieza


func establecer_intensidad(valor: float) -> void:
	intensidad = clampf(valor, 0.0, 1.0)
	if not is_instance_valid(_llamas):
		return
	visible = intensidad > 0.0
	set_process(visible)
	_llamas.scale = Vector3.ONE * maxf(0.001, sqrt(intensidad))
	_humo.emitting = intensidad > 0.05
	_chispas.emitting = intensidad > 0.2


func _process(delta: float) -> void:
	_reloj += delta
	for material in _materiales:
		material.set_shader_parameter("reloj", _reloj)
	_actualizar_gotas()


func _actualizar_gotas() -> void:
	var tamano := 0.60 if ancho < 0.6 else 1.0
	for i in _gotas.size():
		var t := fposmod(_reloj * 0.65 + _fase * 0.3 + i * 0.5, 1.0)
		var gota := _gotas[i]
		var crecimiento := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.48, 0.95, t))
		gota.visible = crecimiento > 0.01
		gota.position = Vector3(sin(t * 3.0 + i * 2.5) * 0.18, 0.80 + t * 0.82, cos(t * 4.0 + i) * 0.08) * tamano
		gota.scale = Vector3(0.12, 0.24, 0.10) * maxf(0.001, crecimiento) * tamano
		gota.rotation.z = sin(t * 5.0 + i) * 0.45


func _particulas(cantidad: int, color: Color, radio: float, vida: float) -> CPUParticles3D:
	var particulas := CPUParticles3D.new()
	particulas.amount = cantidad
	particulas.lifetime = vida
	particulas.preprocess = vida * 0.4
	particulas.spread = 22.0
	particulas.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particulas.emission_box_extents = Vector3(ancho * 0.35, 0.02, profundo * 0.3)
	var esfera := SphereMesh.new()
	esfera.radius = radio
	esfera.height = radio * 2.0
	esfera.radial_segments = 8
	esfera.rings = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	esfera.material = material
	particulas.mesh = esfera
	var gradiente := Gradient.new()
	gradiente.set_color(0, color)
	gradiente.set_color(1, Color(color, 0.0))
	particulas.color_ramp = gradiente
	particulas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particulas)
	return particulas


func _perfil(y: float) -> Vector3:
	# Base ancha, cuello estrecho, panza redonda y punta curvada.
	var radios := [0.75, 0.83, 0.74, 0.56, 0.44, 0.55, 0.76, 0.71, 0.47, 0.24, 0.0]
	var tramo := minf(y * 10.0, 9.9999)
	var indice := int(tramo)
	var p0: float = radios[maxi(0, indice - 1)]
	var p1: float = radios[indice]
	var p2: float = radios[indice + 1]
	var p3: float = radios[mini(radios.size() - 1, indice + 2)]
	var t := tramo - indice
	var radio := maxf(0.0, 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	var curva := sin(y * 4.7) * y * 0.25 + pow(y, 4.0) * 0.44
	return Vector3(curva, y, radio)


func _malla_llama() -> ArrayMesh:
	var superficie := SurfaceTool.new()
	superficie.begin(Mesh.PRIMITIVE_TRIANGLES)
	const ANILLOS := 32
	const LADOS := 24
	for nivel in ANILLOS:
		for lado in LADOS:
			for esquina: Vector2i in [Vector2i(nivel, lado), Vector2i(nivel + 1, lado), Vector2i(nivel + 1, lado + 1), Vector2i(nivel, lado), Vector2i(nivel + 1, lado + 1), Vector2i(nivel, lado + 1)]:
				var y := float(esquina.x) / ANILLOS
				var perfil := _perfil(y)
				var angulo := float(esquina.y) / LADOS * TAU
				var pendiente := (_perfil(minf(1.0, y + 0.005)) - _perfil(maxf(0.0, y - 0.005))) / 0.01
				var normal := Vector3(cos(angulo), -pendiente.z - pendiente.x * cos(angulo), sin(angulo)).normalized()
				superficie.set_normal(normal)
				superficie.add_vertex(Vector3(cos(angulo) * perfil.z + perfil.x, y, sin(angulo) * perfil.z))
	superficie.index()
	return superficie.commit()
