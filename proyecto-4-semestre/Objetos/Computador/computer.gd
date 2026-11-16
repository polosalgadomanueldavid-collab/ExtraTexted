extends StaticBody3D
class_name PCStatic

signal papel_solicitado(jugador: Player)

# El computador físico sigue siendo el punto donde se imprime la denuncia.
var is_using: bool = false


func interactuar(jugador: Player) -> void:
	papel_solicitado.emit(jugador)
