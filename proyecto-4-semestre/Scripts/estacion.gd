class_name Estacion
extends StaticBody3D

@export var estacion_id: String = ""
@export var nombre_visible: String = ""


func interactuar(_jugador: Player) -> void:
	print("[Estación] Interacción recibida en '", estacion_id, "' (", nombre_visible, ").")
	var gestor: Node = get_tree().get_first_node_in_group("gestor_partida")

	if gestor == null:
		push_warning("No se encontró el gestor de partida.")
		return

	if not gestor.has_method("interactuar_estacion"):
		push_warning("El gestor no puede procesar estaciones.")
		return

	gestor.interactuar_estacion(estacion_id)
