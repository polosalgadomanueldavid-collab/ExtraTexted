extends StaticBody3D

enum Servicio { CAFETERA, SOFA }
@export var servicio: Servicio = Servicio.CAFETERA

func interactuar(jugador: Player) -> void:
	var zona := get_parent().get_parent()
	if servicio == Servicio.SOFA:
		zona.interactuar_sofa(jugador)
	else:
		zona.interactuar_cafetera(jugador)
