class_name SistemaPuntuacion
extends RefCounted
## Saldo de la partida actual. Cada despacho crea su propia instancia.

signal puntos_actualizados(total: int)

var puntos: int:
	get:
		return _puntos

var _puntos: int = 0
var _casos_premiados: Dictionary = {}


func registrar_resolucion(denuncia: Denuncia) -> int:
	if denuncia == null or denuncia.id.is_empty():
		return 0
	if denuncia.estado != Denuncia.Estado.RESUELTA or _casos_premiados.has(denuncia.id):
		return 0

	var recompensa := denuncia.obtener_puntaje_recompensa()
	_casos_premiados[denuncia.id] = true
	_puntos += recompensa
	puntos_actualizados.emit(_puntos)
	return recompensa
