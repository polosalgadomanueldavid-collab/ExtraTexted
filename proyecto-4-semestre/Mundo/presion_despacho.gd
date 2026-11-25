extends Node
## Cada expediente abierto ocupa una de las mesas sin estación. Las pilas
## siguen al mueble si flota y se dibujan con una sola llamada por mesa.
const MESAS := [
	"Mesas verticales IZQ/Table_018", "Mesas verticales DER/Table_019",
	"Mesas verticales IZQ/Table_020", "Mesas verticales DER/Table_016",
	"Mesas verticales DER/Table_022",
]
const TAPAS := [Color("527777"), Color("846c65"), Color("697681")]
var pilas: Array[MultiMeshInstance3D] = []
var _salidas: Dictionary[int, Tween] = {}
var _cantidad := 0
var _resueltas := 0


func configurar(oficina: Node, despacho: SistemaDespacho) -> void:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	var cubo := BoxMesh.new()
	cubo.material = material
	for i in MESAS.size():
		var mesa := oficina.get_node(MESAS[i]) as MeshInstance3D
		var lote := MultiMesh.new()
		lote.transform_format = MultiMesh.TRANSFORM_3D
		lote.use_colors = true
		lote.mesh = cubo
		var carpetas := 2 + i % 3
		lote.instance_count = carpetas * 4 + 2
		for j in carpetas:
			var giro := sin(i * 3.0 + j * 1.7) * 0.09
			var base := Vector3(0.01 * j, j * 0.043, 0)
			var color: Color = TAPAS[(i + j) % TAPAS.size()]
			var indice := 4 * j
			_pieza(lote, indice, base, Vector3(.37, .008, .26), giro, color)
			_pieza(lote, indice + 1, base + Vector3.UP * .019, Vector3(.35, .031, .245), giro, Color("e8dfcb"))
			_pieza(lote, indice + 2, base + Vector3.UP * .038, Vector3(.37, .007, .26), giro, color)
			var pestana := base + Vector3(-.10, .038, -.13).rotated(Vector3.UP, giro)
			_pieza(lote, indice + 3, pestana, Vector3(.09, .007, .035), giro, color)
		var altura := carpetas * .043
		_pieza(lote, carpetas * 4, Vector3(.045, altura, 0), Vector3(.18, .004, .13), -.16, Color("efe5d2"))
		_pieza(lote, carpetas * 4 + 1, Vector3(.095, altura + .005, .024), Vector3(.067, .004, .066), .13, Color("ddba70"))
		var pila := MultiMeshInstance3D.new()
		pila.name = "ArchivoPendiente"
		pila.multimesh = lote
		pila.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pila.position = mesa.get_aabb().get_center()
		pila.position.y = mesa.get_aabb().end.y + .005
		pila.visible = false
		mesa.add_child(pila)
		pilas.append(pila)
	despacho.denuncia_resuelta.connect(_al_resolver)
	despacho.denuncias_actualizadas.connect(actualizar)
	actualizar(despacho.obtener_denuncias_ordenadas())


func _al_resolver(_denuncia: Denuncia) -> void:
	_resueltas += 1


func actualizar(abiertas: Array[Denuncia]) -> void:
	var nueva := mini(abiertas.size(), pilas.size())
	for i in range(_cantidad, nueva):
		if _salidas.has(i):
			_salidas[i].kill()
			_salidas.erase(i)
		pilas[i].scale = Vector3.ONE
		pilas[i].show()
	for i in range(_cantidad - 1, nueva - 1, -1):
		if _resueltas > 0:
			_resueltas -= 1
			var salida := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_salidas[i] = salida
			salida.tween_property(pilas[i], "scale", Vector3(.92, .06, .92), .22)
			salida.tween_callback(_guardar_pila.bind(i))
		else:
			_guardar_pila(i)
	_cantidad = nueva
	_resueltas = 0


func _guardar_pila(i: int) -> void:
	pilas[i].hide()
	_salidas.erase(i)


func _pieza(lote: MultiMesh, i: int, posicion: Vector3, tamano: Vector3, giro: float, color: Color) -> void:
	lote.set_instance_transform(i, Transform3D(Basis(Vector3.UP, giro).scaled_local(tamano), posicion))
	lote.set_instance_color(i, color)
