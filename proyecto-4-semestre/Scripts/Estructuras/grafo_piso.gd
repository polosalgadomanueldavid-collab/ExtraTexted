class_name GrafoPiso
extends RefCounted

const COLUMNAS: int = 14
const FILAS: int = 25
const TAMANO_CELDA: float = 0.5
const ORIGEN_X: float = -4.5
const ORIGEN_Z: float = -0.1

const DESTINOS: Dictionary = {
	# Casillas de aproximación: la mesa física se bloquea, pero el jugador debe
	# poder llegar a una celda contigua para interactuar con cada estación.
	"computador": Vector2i(7, 2),
	"evidencias": Vector2i(11, 7),
	"verificacion": Vector2i(2, 7),
	"privacidad": Vector2i(4, 10),
	"reporte": Vector2i(9, 10),
	"bienestar": Vector2i(2, 3)
}

const CELDAS_BLOQUEADAS_FIJAS: Array[Vector2i] = [
	Vector2i(1, 5),
	Vector2i(1, 10),
	Vector2i(13, 2),
	Vector2i(13, 5),
	Vector2i(13, 10),
	Vector2i(9, 0),
	Vector2i(12, 0),
	Vector2i(1, 0),
	Vector2i(4, 0),
	Vector2i(1, 12),
	Vector2i(12, 12)
]

const DIRECCIONES: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1)
]

var adyacencia: Dictionary = {}
var bloqueos_fijos: Dictionary = {}
# Casillas obtenidas de las colisiones reales de las mesas al cargar la escena.
# Se mantienen separadas de la lista manual para poder diagnosticarlas y recalcularlas.
var bloqueos_mesas: Dictionary = {}
var bloqueos_temporales: Dictionary = {}

func _init() -> void:
	for celda: Vector2i in CELDAS_BLOQUEADAS_FIJAS:
		bloqueos_fijos[celda] = true
	construir_adyacencia()

func es_celda_valida(celda: Vector2i) -> bool:
	return (
		celda.x >= 0
		and celda.x < COLUMNAS
		and celda.y >= 0
		and celda.y < FILAS
	)


func es_transitable(celda: Vector2i) -> bool:
	return (
		es_celda_valida(celda)
		and not bloqueos_fijos.has(celda)
		and not bloqueos_mesas.has(celda)
		and not bloqueos_temporales.has(celda)
	)


func establecer_bloqueos_de_mesas(celdas: Array[Vector2i]) -> void:
	bloqueos_mesas.clear()
	for celda: Vector2i in celdas:
		bloqueos_mesas[celda] = true
	construir_adyacencia()

func posicion_a_celda(posicion: Vector3) -> Vector2i:
	var columna: int = floori((posicion.x - ORIGEN_X) / TAMANO_CELDA)
	var fila: int = floori((posicion.z - ORIGEN_Z) / TAMANO_CELDA)
	return Vector2i(columna, fila)


func construir_adyacencia() -> void:
	adyacencia.clear()

	for fila: int in range(FILAS):
		for columna: int in range(COLUMNAS):
			var celda: Vector2i = Vector2i(columna, fila)

			if not es_transitable(celda):
				continue

			var vecinos: Array[Vector2i] = []

			for direccion: Vector2i in DIRECCIONES:
				var vecina: Vector2i = celda + direccion

				if es_transitable(vecina):
					vecinos.append(vecina)

			adyacencia[celda] = vecinos

func calcular_ruta(origen: Vector2i, destino: Vector2i) -> Array[Vector2i]:
	if not adyacencia.has(origen) or not adyacencia.has(destino):
		return []

	var infinito: float = INF
	var distancias: Dictionary = {}
	var anterior: Dictionary = {}
	var sin_visitar: Array[Vector2i] = []

	for celda: Vector2i in adyacencia.keys():
		distancias[celda] = infinito
		sin_visitar.append(celda)

	distancias[origen] = 0.0

	while not sin_visitar.is_empty():
		var actual: Vector2i = Vector2i(-1, -1)
		var mejor_distancia: float = infinito

		for celda: Vector2i in sin_visitar:
			if float(distancias[celda]) < mejor_distancia:
				mejor_distancia = float(distancias[celda])
				actual = celda

		if actual == Vector2i(-1, -1):
			break

		if actual == destino:
			break

		sin_visitar.erase(actual)

		for vecina: Vector2i in adyacencia[actual]:
			var distancia_nueva: float = float(distancias[actual]) + 1.0

			if distancia_nueva < float(distancias[vecina]):
				distancias[vecina] = distancia_nueva
				anterior[vecina] = actual

	if origen != destino and not anterior.has(destino):
		return []

	var ruta: Array[Vector2i] = [destino]
	var celda_actual: Vector2i = destino

	while celda_actual != origen:
		celda_actual = anterior[celda_actual]
		ruta.append(celda_actual)

	ruta.reverse()
	return ruta

func celda_a_posicion(celda: Vector2i) -> Vector3:
	return Vector3(
		ORIGEN_X + (celda.x + 0.5) * TAMANO_CELDA,
		0.0,
		ORIGEN_Z + (celda.y + 0.5) * TAMANO_CELDA
	)
