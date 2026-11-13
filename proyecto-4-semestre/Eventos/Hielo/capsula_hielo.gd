extends Node3D
## Cristal facetado visual: nunca añade una colisión ni cambia la masa del policía.

var jugador: Player
var peso := 0.0
var _cristal: MeshInstance3D
var _material: StandardMaterial3D
var _borde: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(1, 1, 1, 0.46)
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.vertex_color_use_as_albedo = true
	_material.render_priority = 5
	_cristal = MeshInstance3D.new()
	_cristal.name = "Iceberg"
	var superficie := SurfaceTool.new()
	superficie.begin(Mesh.PRIMITIVE_TRIANGLES)
	var anillos: Array[PackedVector3Array] = []
	for fila in 4:
		var anillo := PackedVector3Array()
		for i in 7:
			var angulo := i * TAU / 7.0 + fila * 0.14
			var radio: float = [0.29, 0.42, 0.33, 0.12][fila]
			var altura: float = [0.02, 0.34, 0.88, 1.18][fila]
			anillo.append(Vector3(cos(angulo) * radio, altura + sin(i * 7.3 + fila) * 0.055, sin(angulo) * radio * 0.82))
		anillos.append(anillo)
	for fila in 3:
		for i in 7:
			var j := (i + 1) % 7
			for vertice: Vector3 in [anillos[fila][i], anillos[fila + 1][i], anillos[fila][j], anillos[fila][j], anillos[fila + 1][i], anillos[fila + 1][j]]:
				superficie.set_smooth_group(-1)
				superficie.set_color(Color("66aeec").lerp(Color("d5f3ff"), float((i * 3 + fila) % 7) / 7.0))
				superficie.add_vertex(vertice)
	for i in 7:
		for vertice: Vector3 in [anillos[3][i], Vector3(0.025, 1.28, 0), anillos[3][(i + 1) % 7]]:
			superficie.set_smooth_group(-1)
			superficie.set_color(Color("b9eaff"))
			superficie.add_vertex(vertice)
	superficie.generate_normals()
	_cristal.mesh = superficie.commit()
	_cristal.material_override = _material
	_cristal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cristal)
	var aristas := ImmediateMesh.new()
	aristas.surface_begin(Mesh.PRIMITIVE_LINES)
	for fila in 4:
		for i in 7:
			aristas.surface_add_vertex(anillos[fila][i])
			aristas.surface_add_vertex(anillos[fila][(i + 1) % 7])
			aristas.surface_add_vertex(anillos[fila][i])
			aristas.surface_add_vertex(anillos[fila + 1][i] if fila < 3 else Vector3(0.025, 1.28, 0))
	aristas.surface_end()
	_borde = StandardMaterial3D.new()
	_borde.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_borde.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_borde.albedo_color = Color("c9efff")
	_borde.render_priority = 6
	var contorno := MeshInstance3D.new()
	contorno.mesh = aristas
	contorno.material_override = _borde
	contorno.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cristal.add_child(contorno)
	hide()


func _process(delta: float) -> void:
	if not is_instance_valid(jugador):
		return
	peso = move_toward(peso, 1.0 if jugador.congelado else 0.0, delta * 6.5)
	visible = peso > 0.001 and not jugador.esta_sentado()
	global_position = jugador.global_position
	rotation.y = jugador.visual.global_rotation.y
	_cristal.scale = Vector3(0.8 + peso * 0.2, maxf(0.01, peso), 0.8 + peso * 0.2)
	_material.albedo_color.a = peso * 0.46
	_borde.albedo_color.a = peso * 0.80
