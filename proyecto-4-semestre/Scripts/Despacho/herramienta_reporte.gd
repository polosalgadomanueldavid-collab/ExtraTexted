extends StaticBody3D
## Herramienta de la impresora. La E usa el mismo alcance físico que las mesas.

const CORAL := Color("ff785f")

var activa: bool = false
var indice_red := 0
var mostrar_indicador: bool = true:
	set(valor):
		mostrar_indicador = valor
		if is_instance_valid(_indicador):
			_indicador.visible = valor
var _indicador: Label3D


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
	var llave := preload("res://Scripts/Despacho/modelo_llave.gd").new()
	llave.name = "Llave"
	llave.position = Vector3(-0.18, 0.16, 0)
	llave.rotation = Vector3(0, 0, -PI / 2.0)
	add_child(llave)
	var texto := Label3D.new()
	texto.text = "Llave"
	texto.font = preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
	texto.font_size = 26
	texto.pixel_size = 0.0045
	texto.modulate = CORAL
	texto.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texto.position.y = 0.95
	add_child(texto)
	_indicador = texto
	_indicador.visible = mostrar_indicador
	establecer_activa(false)


func orientar_desde(posicion: Vector3) -> void:
	if activa:
		_indicador.visible = mostrar_indicador and global_position.distance_squared_to(posicion) > 1.8


func establecer_activa(valor: bool) -> void:
	activa = valor
	visible = valor
	collision_layer = 4 if valor else 0


func interactuar(jugador: Player) -> void:
	if not activa:
		return
	var gestor := get_tree().get_first_node_in_group("gestor_partida")
	if gestor != null:
		jugador.ejecutar_gesto(&"interactuar", gestor.recoger_herramienta_reporte.bind(jugador, indice_red), self)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material
