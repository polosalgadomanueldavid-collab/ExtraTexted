@tool
extends Node3D
## Acabados sobre el rig original; cada accesorio sigue su hueso.
@export_enum("Cobalto", "Menta", "Violeta") var variante: int = 0
var rig: Skeleton3D
var oro: StandardMaterial3D
var oscuro: StandardMaterial3D
var acento: StandardMaterial3D

func _ready() -> void:
	rig = get_node("Rig/Skeleton3D") as Skeleton3D
	if rig.has_node("AcabadoUniforme"):
		return
	var detalles := Node3D.new()
	detalles.name = "AcabadoUniforme"
	rig.add_child(detalles)
	var paletas := [
		["397cce", "225087", "67b1ef", "a4d8f5", "d5eaf7", "20354d", "efc76c"],
		["378a83", "244f58", "71c5bb", "f3e5c7", "efb39a", "263c43", "e8c580"],
		["7363a7", "3f3d68", "ad9dd7", "d8cee9", "efa793", "302e49", "e8c580"]]
	var p: Array = paletas[clampi(variante, 0, 2)]
	var uniforme := material(p[0], 0.72)
	var pantalon := material(p[1], 0.76)
	var piel := material(p[2], 0.55)
	var cuello := material(p[3], 0.71)
	acento = material(p[4], 0.64)
	oscuro = material(p[5], 0.55)
	oro = material(p[6], 0.34, 0.42)
	pintar(["Chaqueta", "Manga L", "Manga R", "Gorra de plato"], uniforme)
	pintar(["Cabeza sin rostro", "Mano L", "Mano R"], piel)
	pintar(["Cuello derecho", "Cuello izquierdo", "Cuello trasero"], cuello)
	pintar(["Pantalón continuo"], pantalon)
	pintar(["Banda de la gorra", "Visera", "Cinturón", "Cartuchera L", "Cartuchera R", "Funda lateral L", "Funda lateral R", "Solapa L", "Solapa R", "Broche L", "Broche R"], oscuro)
	pintar(["Placa de la gorra", "Placa del pecho", "Botón dorado 1", "Botón dorado 2", "Botón dorado 3", "Hebilla"], oro)
	if variante == 1:
		pintar(["Gorra de plato"], cuello)
	elif variante == 2:
		pintar(["Gorra de plato"], material("aea0ce", 0.72))
	var aro := PackedVector3Array()
	for i in 65:
		var a := i * TAU / 64.0
		var z := sin(a) * 0.451 - 0.014
		aro.append(Vector3(cos(a) * 0.449, 2.18 + 0.263 * z, z))
	pieza("RibeteGorra", tubo(aro, 0.012, oro), "head")
	pieza("Tapeta", tubo(PackedVector3Array([Vector3(0, 0.91, 0.478), Vector3(0, 1.15, 0.452), Vector3(0, 1.44, 0.390)]), 0.008, acento), "chest")
	pieza("Identificacion", caja(Vector3(0.15, 0.027, 0.025), oro), "chest", Vector3(-0.22, 1.37, 0.379), Vector3(0, 0.45, 0))
	for lado: float in [-1.0, 1.0]:
		var sufijo := "L" if lado > 0 else "R"
		pieza("Hombrera" + sufijo, ovalo(acento), "upper_arm." + sufijo, Vector3(lado * 0.44, 1.585, -0.025), Vector3(0, 0, lado * 0.32), Vector3(0.11, 0.033, 0.16))
		pieza("Botin" + sufijo, ovalo(oscuro), "foot." + sufijo, Vector3(lado * 0.30, 0.105, 0.057), Vector3.ZERO, Vector3(0.138, 0.108, 0.175))
		var puno := PackedVector3Array()
		for i in 33:
			var a := i * TAU / 32.0
			puno.append(Vector3(lado * 0.684 + cos(a) * 0.181, 0.86 + lado * cos(a) * 0.045, -0.038 + sin(a) * 0.194))
		pieza("RibetePuno" + sufijo, tubo(puno, 0.016, acento), "forearm." + sufijo)
	for i in variante + 1:
		pieza("TrazoPlaca%d" % i, caja(Vector3(0.012, 0.070, 0.014), oscuro), "head", Vector3((i - variante * 0.5) * 0.031, 2.431, 0.445), Vector3(-0.16, 0, 0))
	if variante == 1:
		pieza("NudoPanuelo", ovalo(acento), "chest", Vector3(0, 1.60, 0.345), Vector3.ZERO, Vector3(0.078, 0.060, 0.048))
		pieza("PuntaPanuelo", ovalo(acento), "chest", Vector3(-0.065, 1.51, 0.389), Vector3(0, 0, -0.38), Vector3(0.047, 0.12, 0.025))
		pieza("Radio", caja(Vector3(0.106, 0.16, 0.060), oscuro), "chest", Vector3(-0.29, 1.405, 0.329), Vector3(0, 0.55, 0))
		pieza("Antena", tubo(PackedVector3Array([Vector3(-0.29, 1.48, 0.32), Vector3(-0.29, 1.64, 0.32)]), 0.009, oscuro), "chest")
		for i in 3:
			pieza("RejillaRadio%d" % i, caja(Vector3(0.055, 0.009, 0.009), acento), "chest", Vector3(-0.305, 1.43 - i * 0.025, 0.362), Vector3(0, 0.55, 0))
	elif variante == 2:
		var puntos := PackedVector3Array()
		for i in 33:
			var t := float(i) / 32.0
			puntos.append(Vector3(0.30 + 0.23 * t, 1.55 - 0.30 * sin(t * PI), 0.20 + 0.09 * sin(t * PI)))
		pieza("CordonHombro", tubo(puntos, 0.020, oro), "chest")
		for lado: float in [-1.0, 1.0]:
			for i in 2:
				var y := 1.03 + i * 0.08
				var x := lado * (0.695 - (y - 0.836) * 0.395)
				var puntos_galon := PackedVector3Array([Vector3(x - 0.08, y + 0.03, 0.151), Vector3(x, y - 0.01, 0.164), Vector3(x + 0.08, y + 0.03, 0.151)])
				pieza("Galon%s%d" % [str(lado), i], tubo(puntos_galon, 0.016, oro), "forearm." + ("L" if lado > 0 else "R"))

func material(color: String, rugosidad: float, metal: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color)
	mat.roughness = rugosidad
	mat.metallic = metal
	return mat

func pintar(nombres: Array, mat: Material) -> void:
	for nombre: String in nombres:
		var objeto := rig.get_node_or_null(NodePath(nombre)) as MeshInstance3D
		if objeto != null:
			objeto.material_override = mat

func pieza(nombre: String, malla: Mesh, hueso: String, posicion := Vector3.ZERO, rotacion := Vector3.ZERO, tamano := Vector3.ONE) -> void:
	var ancla := BoneAttachment3D.new()
	ancla.name = nombre
	ancla.bone_name = hueso
	ancla.use_external_skeleton = true
	ancla.external_skeleton = NodePath("../..")
	rig.get_node("AcabadoUniforme").add_child(ancla)
	var objeto := MeshInstance3D.new()
	objeto.name = "Detalle"
	ancla.add_child(objeto)
	objeto.mesh = malla
	var reposo := rig.get_bone_global_rest(rig.find_bone(hueso))
	objeto.transform = reposo.affine_inverse() * Transform3D(Basis.from_euler(rotacion).scaled(tamano), posicion)

func caja(tamano: Vector3, mat: Material) -> BoxMesh:
	var malla := BoxMesh.new()
	malla.size = tamano
	malla.material = mat
	return malla

func ovalo(mat: Material) -> SphereMesh:
	var malla := SphereMesh.new()
	malla.radius = 1.0
	malla.height = 2.0
	malla.radial_segments = 24
	malla.rings = 12
	malla.material = mat
	return malla

func tubo(puntos: PackedVector3Array, radio: float, mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	for i in puntos.size():
		var tangente := (puntos[mini(i + 1, puntos.size() - 1)] - puntos[maxi(i - 1, 0)]).normalized()
		var eje := tangente.cross(Vector3.UP).normalized()
		if eje.length_squared() < 0.01:
			eje = Vector3.RIGHT
		var otro := tangente.cross(eje).normalized()
		for j in 8:
			var normal := eje * cos(j * TAU / 8.0) + otro * sin(j * TAU / 8.0)
			st.set_normal(normal)
			st.add_vertex(puntos[i] + normal * radio)
	for i in puntos.size() - 1:
		for j in 8:
			var a := i * 8 + j
			var b := i * 8 + (j + 1) % 8
			for indice: int in [a, b, b + 8, a, b + 8, a + 8]:
				st.add_index(indice)
	return st.commit()
