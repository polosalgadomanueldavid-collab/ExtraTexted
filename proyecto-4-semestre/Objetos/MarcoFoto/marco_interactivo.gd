@tool
extends StaticBody3D

@export var foto: Texture2D:
	set(valor):
		foto = valor
		_actualizar_foto()
@export var titulo := "Fotografía"
@export var material_marco: StandardMaterial3D:
	set(valor):
		material_marco = valor
		_actualizar_material_marco()


func _ready() -> void:
	_actualizar_foto()
	_actualizar_material_marco()


func _actualizar_foto() -> void:
	var pantalla := get_node_or_null("Visual/HaciaSala/Foto") as MeshInstance3D
	if pantalla == null or foto == null:
		return
	var malla := pantalla.mesh as QuadMesh
	if malla != null:
		var area := Vector2(1.68, 1.3)
		var escala_visual := Vector2(0.61, 0.42)
		var aspecto_local := (float(foto.get_width()) / float(foto.get_height())) * escala_visual.y / escala_visual.x
		var aspecto_area := area.x / area.y
		if aspecto_local > aspecto_area:
			area.y = area.x / aspecto_local
		else:
			area.x = area.y * aspecto_local
		malla.size = area
	var material := pantalla.material_override as StandardMaterial3D
	if material != null:
		material.albedo_texture = foto


func _actualizar_material_marco() -> void:
	var marco := get_node_or_null("Visual/HaciaSala/Apaisado/MarcoFoto")
	if marco == null or material_marco == null:
		return
	_aplicar_material_a_mallas(marco)


func _aplicar_material_a_mallas(nodo: Node) -> void:
	var malla := nodo as MeshInstance3D
	if malla != null:
		malla.material_override = material_marco
	for hijo in nodo.get_children():
		_aplicar_material_a_mallas(hijo)


func interactuar(jugador: Player) -> void:
	if foto == null or not is_instance_valid(jugador) or not jugador.is_on_floor():
		return
	if absf(jugador.global_position.y - global_position.y) > 0.24:
		return
	var visor := get_tree().get_first_node_in_group(&"visor_cuadros") as Control
	if visor != null and visor.has_method("mostrar"):
		visor.call("mostrar", foto, titulo, jugador)
