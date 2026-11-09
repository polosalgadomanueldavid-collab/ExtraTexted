class_name SillaComputador
extends StaticBody3D


func interactuar(jugador: Player) -> void:
	var gestor := get_tree().get_first_node_in_group("gestor_partida")
	if gestor == null:
		return
	var computador := gestor.get_node_or_null("Computer") as PCStatic
	if is_instance_valid(computador):
		computador.interactuar(jugador)
