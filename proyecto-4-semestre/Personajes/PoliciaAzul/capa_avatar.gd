extends Node3D
## Capa Avatar adaptada a la pose final del esqueleto, con margen para las extremidades.
var rig: Skeleton3D
var tiempo := 0.0
var cuerpo := MeshInstance3D.new()
var esclavina := MeshInstance3D.new()
var ribetes := MeshInstance3D.new()
var broche := Node3D.new()
var amarillo: ShaderMaterial
var naranja: ShaderMaterial
var oro: ShaderMaterial
var capsulas: Array[Dictionary] = []
var pecho := Transform3D.IDENTITY
var pelvis := Transform3D.IDENTITY

const TELA := preload("res://Personajes/PoliciaAzul/capa_avatar.gdshader")
var _materiales: Array[ShaderMaterial] = []
var _huesos: Dictionary = {}
var _inversas: Dictionary = {}

func mat(hex: String, rough: float, metal := 0.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TELA
	material.set_shader_parameter("tinte", Color(hex))
	material.set_shader_parameter("rugosidad", rough)
	material.set_shader_parameter("metal", metal)
	_materiales.append(material)
	return material

func _ready() -> void:
	amarillo = mat("e9b144", .64)
	naranja = mat("d46724", .69)
	oro = mat("f2c561", .40, .18)
	for nodo: Node in [cuerpo, esclavina, ribetes, broche]:
		add_child(nodo)
	for i in rig.get_bone_count():
		var nombre := rig.get_bone_name(i)
		_huesos[nombre] = i
		_inversas[nombre] = rig.get_bone_global_rest(i).affine_inverse()
	_crear_mallas()
	# El broche sigue el pecho como nodo; no necesita deformar sus vertices.
	var metal_broche := StandardMaterial3D.new()
	metal_broche.albedo_color = Color("f2c561")
	metal_broche.roughness = .40
	metal_broche.metallic = .18
	for i in 3:
		var pieza := MeshInstance3D.new()
		var esfera := SphereMesh.new()
		esfera.radius = [.086, .061, .034][i]
		esfera.height = esfera.radius * 2.0
		esfera.radial_segments = 40
		esfera.rings = 20
		esfera.material = metal_broche
		pieza.mesh = esfera
		pieza.scale = Vector3(1, 1, .24)
		pieza.position.z = i * .014
		broche.add_child(pieza)

func deformacion(hueso: String) -> Transform3D:
	var id: int = _huesos[hueso]
	return rig.get_bone_global_pose(id) * _inversas[hueso]

func preparar_capsulas() -> void:
	capsulas.clear()
	for lado: String in ["L", "R"]:
		var hombro := rig.get_bone_global_pose(rig.find_bone("upper_arm." + lado)).origin
		var codo := rig.get_bone_global_pose(rig.find_bone("forearm." + lado)).origin
		var mano := rig.get_bone_global_pose(rig.find_bone("hand." + lado)).origin
		var mano_fin: Vector3 = deformacion("hand." + lado) * Vector3(.76 if lado == "L" else -.76, .68, -.04)
		capsulas.append({"a": hombro, "b": codo, "r": .235})
		capsulas.append({"a": codo, "b": mano, "r": .225})
		capsulas.append({"a": mano, "b": mano_fin, "r": .21})
		var rodilla := rig.get_bone_global_pose(rig.find_bone("shin." + lado)).origin
		var pie := rig.get_bone_global_pose(rig.find_bone("foot." + lado)).origin
		capsulas.append({"a": rodilla, "b": pie, "r": .21})

func base(u: float, v: float, manto: bool) -> Vector3:
	var borde := pow(absf(u * 2 - 1), 8)
	var apertura := lerpf(.10, .68, smoothstep(0, .7, v))
	if not manto:
		apertura = lerpf(.52, .92, smoothstep(0, 1, v))
	var a := lerpf(apertura, TAU - apertura, u)
	var x: float
	var y: float
	var z: float
	if manto:
		var radio_x := lerpf(.345, .77, sin(v * PI * .5))
		var radio_z := lerpf(.35, .52, sin(v * PI * .5))
		x = sin(a) * radio_x
		z = cos(a) * radio_z
		y = 1.685 - .25 * v - .11 * sin(v * PI * .6) * (1.0 - borde)
		y += .11 * borde * v
	else:
		var ancho := lerpf(.50, 1.05, pow(v, .65))
		var fondo := lerpf(.36, .70, pow(v, .65))
		var pliegue := (.045 * sin(u * PI * 10 + v * .8) + .022 * sin(u * PI * 18 - v)) * sin(v * PI * .8)
		x = sin(a) * (ancho + pliegue)
		z = cos(a) * (fondo + pliegue) - .04
		y = lerpf(1.53, .20, v) + .055 * cos(u * PI * 10) * pow(v, 4) + .10 * borde * v
		# Abertura lateral para que los brazos trabajen delante de la capa.
		var lateral := pow(absf(sin(a)), 8) * sin(v * PI)
		z -= .22 * lateral
		z -= (.08 + .07 * sin(tiempo * 3.2 - v * 3 + u * 2)) * v * v
		x += .055 * sin(tiempo * 3 - v * 4) * v * v
	var p := Vector3(x, y, z)
	var mezcla := 0.0 if manto else smoothstep(.15, .85, v) * .55
	p = (pecho * p).lerp(pelvis * p, mezcla)
	return p

func superficie(vertices: PackedVector3Array, normales: PackedVector3Array, uv: PackedVector2Array, indices: PackedInt32Array, material: Material, mesh: ArrayMesh, manto: bool) -> void:
	if indices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var colores := PackedColorArray()
	colores.resize(vertices.size())
	colores.fill(Color(1 if manto else 0, 0, 0, 1))
	arrays[Mesh.ARRAY_COLOR] = colores
	arrays[Mesh.ARRAY_NORMAL] = normales
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var orientados := indices.duplicate()
	for i in range(0, orientados.size(), 3):
		var aux := orientados[i + 1]
		orientados[i + 1] = orientados[i + 2]
		orientados[i + 2] = aux
	arrays[Mesh.ARRAY_INDEX] = orientados
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)

func construir(manto: bool) -> Dictionary:
	const NX := 64
	var ny := 16 if manto else 32
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	for j in ny + 1:
		for i in NX + 1:
			var u := float(i) / NX
			var v := float(j) / ny
			vertices.append(base(u, v, manto))
			uv.append(Vector2(u, v))
	# Suaviza la tela neutra una sola vez. Los contactos se resuelven en GPU.
	for pasada in 1:
		var relajados := vertices.duplicate()
		for j in range(1, ny):
			for i in range(1, NX):
				var k := j * (NX + 1) + i
				var media := (vertices[k - 1] + vertices[k + 1] + vertices[k - NX - 1] + vertices[k + NX + 1]) * .25
				relajados[k] = vertices[k].lerp(media, .28)
		vertices = relajados
	var normales := PackedVector3Array()
	for j in ny + 1:
		for i in NX + 1:
			var du := vertices[j * (NX + 1) + mini(i + 1, NX)] - vertices[j * (NX + 1) + maxi(i - 1, 0)]
			var dv := vertices[mini(j + 1, ny) * (NX + 1) + i] - vertices[maxi(j - 1, 0) * (NX + 1) + i]
			normales.append(dv.cross(du).normalized())
	var centro := PackedInt32Array()
	var borde := PackedInt32Array()
	for j in ny:
		for i in NX:
			var k := j * (NX + 1) + i
			var tri := PackedInt32Array([k, k + NX + 1, k + 1, k + 1, k + NX + 1, k + NX + 2])
			if j >= ny - 2 or i < 2 or i >= NX - 2:
				borde.append_array(tri)
			else:
				centro.append_array(tri)
	var mesh := ArrayMesh.new()
	superficie(vertices, normales, uv, centro, naranja if manto else amarillo, mesh, manto)
	superficie(vertices, normales, uv, borde, oro if manto else naranja, mesh, manto)
	return {"mesh": mesh, "vertices": vertices, "nx": NX, "ny": ny}

func tubo(st: SurfaceTool, puntos: PackedVector3Array, radio: float, anclas: PackedVector2Array, manto: bool) -> void:
	for i in puntos.size() - 1:
		var eje := (puntos[i + 1] - puntos[i]).normalized()
		var a := eje.cross(Vector3.UP).normalized()
		if a.length_squared() < .1:
			a = eje.cross(Vector3.RIGHT).normalized()
		var b := eje.cross(a).normalized()
		for j in 8:
			var n1 := a * cos(j * TAU / 8) + b * sin(j * TAU / 8)
			var n2 := a * cos((j + 1) * TAU / 8) + b * sin((j + 1) * TAU / 8)
			for dato: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1)]:
				var n := n1 if dato.y == 0 else n2
				st.set_color(Color(1 if manto else 0, 0, 0, 1))
				st.set_uv(anclas[i + dato.x])
				st.set_normal(n)
				st.add_vertex(puntos[i + dato.x] + n * radio)

func _crear_mallas() -> void:
	var principal := construir(false)
	var superior := construir(true)
	cuerpo.mesh = principal.mesh
	esclavina.mesh = superior.mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(oro)
	for datos: Dictionary in [principal, superior]:
		var v: PackedVector3Array = datos.vertices
		var nx: int = datos.nx
		var ny: int = datos.ny
		var manto: bool = datos == superior
		var anclas := PackedVector2Array()
		var hem := PackedVector3Array()
		for i in nx + 1:
			hem.append(v[ny * (nx + 1) + i])
			anclas.append(Vector2(float(i) / nx, 1))
		tubo(st, hem, .012, anclas, manto)
		for lado: int in [0, nx]:
			anclas.clear()
			var lateral := PackedVector3Array()
			for j in ny + 1:
				lateral.append(v[j * (nx + 1) + lado])
				anclas.append(Vector2(float(lado) / nx, float(j) / ny))
			tubo(st, lateral, .010, anclas, manto)
	# Cuello enrollado, unido al broche sin cortar la garganta.
	var cuello := PackedVector3Array()
	var anclas_cuello := PackedVector2Array()
	for i in 65:
		var a := lerpf(.08, TAU - .08, i / 64.0)
		cuello.append(Vector3(sin(a) * .35, 1.685, cos(a) * .36))
		anclas_cuello.append(Vector2(i / 64.0, 0))
	tubo(st, cuello, .025, anclas_cuello, true)
	st.index()
	ribetes.mesh = st.commit()
	# Las poses pueden alejar vertices del AABB neutro (giros y brazos elevados).
	for pieza: MeshInstance3D in [cuerpo, esclavina, ribetes]:
		pieza.custom_aabb = AABB(Vector3(-3, -2, -3), Vector3(6, 7, 6))

func actualizar(t: float) -> void:
	tiempo = t
	pecho = deformacion("chest")
	pelvis = deformacion("pelvis")
	preparar_capsulas()
	var inicios := PackedVector4Array()
	var finales := PackedVector4Array()
	for c: Dictionary in capsulas:
		var a: Vector3 = c.a
		var b: Vector3 = c.b
		inicios.append(Vector4(a.x, a.y, a.z, c.r))
		finales.append(Vector4(b.x, b.y, b.z, 1.0 / maxf((b - a).length_squared(), .000001)))
	for material in _materiales:
		material.set_shader_parameter("reloj", tiempo)
		material.set_shader_parameter("pecho", pecho)
		material.set_shader_parameter("pelvis", pelvis)
		material.set_shader_parameter("capsulas_a", inicios)
		material.set_shader_parameter("capsulas_b", finales)
	broche.transform = pecho * Transform3D(Basis.IDENTITY, Vector3(0, 1.61, .405))
