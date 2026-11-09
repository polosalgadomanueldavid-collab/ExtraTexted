extends StaticBody3D
## Herramienta de la impresora. La E usa el mismo alcance físico que las mesas.

const TINTA := Color("173b50")
const CREMA := Color("fff1d8")
const CORAL := Color("ff785f")

var activa: bool = false


func _ready() -> void:
	name = "HerramientaImpresora"
	collision_mask = 0
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 0.27
	forma.shape = esfera
	forma.position.y = 0.36
	add_child(forma)
	var soporte := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 0.29
	disco.bottom_radius = 0.29
	disco.height = 0.06
	soporte.mesh = disco
	soporte.position.y = 0.06
	soporte.material_override = _material(CORAL)
	add_child(soporte)
	_agregar_pieza(Vector3(-0.07, 0.13, 0), Vector3(0.36, 0.06, 0.10), TINTA)
	_agregar_pieza(Vector3(-0.19, 0.17, 0), Vector3(0.14, 0.08, 0.13), CREMA)
	_agregar_pieza(Vector3(0.16, 0.13, -0.09), Vector3(0.17, 0.07, 0.08), CREMA)
	_agregar_pieza(Vector3(0.16, 0.13, 0.09), Vector3(0.17, 0.07, 0.08), CREMA)
	var texto := Label3D.new()
	texto.text = "[E] HERRAMIENTA"
	texto.font = preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
	texto.font_size = 26
	texto.pixel_size = 0.0045
	texto.modulate = CORAL
	texto.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texto.position.y = 0.95
	add_child(texto)
	establecer_activa(false)


func establecer_activa(valor: bool) -> void:
	activa = valor
	visible = valor
	collision_layer = 4 if valor else 0


func interactuar(jugador: Player) -> void:
	if not activa:
		return
	var gestor := get_tree().get_first_node_in_group("gestor_partida")
	if gestor != null:
		jugador.ejecutar_gesto(&"interactuar", gestor.recoger_herramienta_reporte.bind(jugador), self)


func _agregar_pieza(posicion: Vector3, tamano: Vector3, color: Color) -> void:
	var pieza := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = tamano
	pieza.mesh = caja
	pieza.position = posicion
	pieza.material_override = _material(color)
	add_child(pieza)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material
