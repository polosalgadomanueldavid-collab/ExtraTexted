class_name SistemaPuntuacion
extends RefCounted
## Saldo de la partida actual. Cada despacho crea su propia instancia.

signal puntos_actualizados(total: int)

var puntos: int:
	get:
		return _puntos

# La clasificación usa lo ganado; los consumibles solo reducen el saldo.
var puntos_ganados: int:
	get:
		return _puntos_ganados

var _puntos: int = 0
var _puntos_ganados: int = 0
var _casos_premiados: Dictionary = {}


func registrar_resolucion(denuncia: Denuncia) -> int:
	if denuncia == null or denuncia.id.is_empty():
		return 0
	if denuncia.estado != Denuncia.Estado.RESUELTA or _casos_premiados.has(denuncia.id):
		return 0

	var recompensa := denuncia.obtener_puntaje_recompensa()
	_casos_premiados[denuncia.id] = true
	_puntos += recompensa
	if not denuncia.es_practica:
		_puntos_ganados += recompensa
	puntos_actualizados.emit(_puntos)
	return recompensa


func gastar_puntos(cantidad: int) -> bool:
	if cantidad <= 0 or cantidad > _puntos:
		return false
	_puntos -= cantidad
	puntos_actualizados.emit(_puntos)
	return true


func sumar_puntos_debug(cantidad: int) -> void:
	# Saldo de prueba: no registra denuncias ni altera el puntaje de clasificación.
	if not OS.is_debug_build() or cantidad <= 0 or cantidad > 1000000000:
		return
	_puntos += cantidad
	puntos_actualizados.emit(_puntos)
