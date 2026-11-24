extends Node3D
## Tres lotes opacos, 36 triángulos por roca y cero cuerpos físicos.
## Las trayectorias viven en el shader; no hay bucle por roca durante el gesto.
const SHADER := preload("res://Objetos/ZonaDescanso/macizos_tierra.gdshader")
const COREOGRAFIA := preload("res://Personajes/PoliciaAzul/coreografia_avatar.gd")
const CANTIDADES := [[32, 16, 16], [32, 40, 48], [32, 64, 88]]
# Incluye toda la trayectoria deformada en GPU, también la descarga y las puntas.
const ENVOLVENTE := AABB(Vector3(-4.5, -2.0, -4.5), Vector3(9, 7, 13))
static var _recursos: Array = []
var _grupos: Array[MultiMeshInstance3D] = []
var _material: ShaderMaterial
var _reloj := 0.0
var _nivel := -1
var _soltado := false

static func preparar_recursos() -> void:
	if not _recursos.is_empty():
		return
	var azar := RandomNumberGenerator.new()
	azar.seed = 412709
	var mallas: Array[ArrayMesh] = []
	var datos: Array = []
	for grupo in 3:
		mallas.append(_crear_roca(grupo))
		var instancias: Array[Color] = []
		for i in CANTIDADES[2][grupo]:
			# Alternar lados permite reducir detalle conservando ambos macizos.
			var lado := -1.0 if i % 2 == 0 else 1.0
			var x := lado * azar.randf_range(.9, 2.5)
			var z := azar.randf_range(-2.25, .35)
			var altura := azar.randf_range(.65, 2.4)
			var tamano := azar.randf_range(.30, .58) if grupo == 0 else (azar.randf_range(.12, .25) if grupo == 1 else azar.randf_range(.035, .095))
			instancias.append(Color(x, z, altura, tamano))
		datos.append(instancias)
	for nivel in 3:
		var lotes: Array[MultiMesh] = []
		for grupo in 3:
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.use_custom_data = true
			multi.use_colors = true
			multi.mesh = mallas[grupo]
			multi.instance_count = CANTIDADES[nivel][grupo]
			multi.custom_aabb = ENVOLVENTE
			for i in multi.instance_count:
				multi.set_instance_transform(i, Transform3D.IDENTITY)
				multi.set_instance_custom_data(i, datos[grupo][i])
				multi.set_instance_color(i, Color("665441").lerp(Color("b39b73"), float(i % 7) / 8.0))
			lotes.append(multi)
		_recursos.append(lotes)

static func _crear_roca(variante: int) -> ArrayMesh:
	# Conserva el orden de caras del primitivo y calcula normales planas.
	var base := SphereMesh.new()
	base.radius = 1.0
	base.height = 2.0
	base.radial_segments = 6
	base.rings = 2
	var arrays := base.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normales: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var herramienta := SurfaceTool.new()
	herramienta.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, indices.size(), 3):
		var puntos: Array[Vector3] = []
		for j in 3:
			var p := vertices[indices[i + j]]
			var irregular := 1.0 + .14 * sin(p.x * 7.0 + p.y * 4.0 + p.z * 3.0 + variante * 2.1)
			puntos.append(p * irregular)
		var normal := (puntos[1] - puntos[0]).cross(puntos[2] - puntos[0]).normalized()
		if normal.dot(normales[indices[i]] + normales[indices[i + 1]] + normales[indices[i + 2]]) < 0:
			normal = -normal
		for p in puntos:
			herramienta.set_normal(normal)
			herramienta.add_vertex(p)
	return herramienta.commit()

func _ready() -> void:
	preparar_recursos()
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("pisada_l", COREOGRAFIA.PISADAS_TIERRA[0])
	_material.set_shader_parameter("pisada_r", COREOGRAFIA.PISADAS_TIERRA[1])
	for i in 3:
		var grupo := MultiMeshInstance3D.new()
		grupo.material_override = _material
		grupo.custom_aabb = ENVOLVENTE
		grupo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(grupo)
		_grupos.append(grupo)
	var calidad := get_node_or_null("/root/CalidadVisual")
	_aplicar_calidad(int(calidad.nivel) if calidad != null else 2)
	if calidad != null:
		calidad.nivel_cambiado.connect(_aplicar_calidad)
	# Mantener los lotes registrados desde el inicio evita reconstruir su lista
	# de luces justo en la pisada. El shader tiene escala cero antes de emerger.

func _aplicar_calidad(nivel: int) -> void:
	_nivel = clampi(nivel, 0, 2)
	for i in _grupos.size():
		_grupos[i].multimesh = _recursos[_nivel][i]
		# Solo los 32 bloques principales proyectan sombras en alta/ultra.
		_grupos[i].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if i == 0 and _nivel >= 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func actualizar(reloj: float, mano_l: Vector3, mano_r: Vector3, suelo: float) -> void:
	_reloj = reloj
	var fase := clampf(reloj / 3.6, 0, 1)
	visible = fase < 1.0
	_material.set_shader_parameter("fase", fase)
	_material.set_shader_parameter("suelo", suelo)
	if not _soltado:
		_material.set_shader_parameter("mano_l", mano_l)
		_material.set_shader_parameter("mano_r", mano_r)
		_soltado = fase >= .72

func cantidad_visible() -> int:
	var total := 0
	for grupo in _grupos:
		total += grupo.multimesh.instance_count
	return total
