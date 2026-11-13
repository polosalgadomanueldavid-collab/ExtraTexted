class_name GrafoPiso
extends RefCounted

const COLUMNAS: int = 14
const FILAS: int = 25
const TAMANO_CELDA: float = 0.5
const ORIGEN_X: float = -4.5
const ORIGEN_Z: float = -0.1
# Zona de descanso: tramo central inferior más los extremos laterales de las
# últimas filas. Se mantiene transitable, pero se excluye de bloqueos temporales.
const ZONA_SEGURA_CENTRAL := Rect2i(1, 14, 12, 11)
const ZONA_SEGURA_EXTREMOS := Rect2i(0, 7, COLUMNAS, 18)

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
var grietas: Dictionary[Vector2i, bool] = {}

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


func es_zona_segura(celda: Vector2i) -> bool:
	return (
		ZONA_SEGURA_CENTRAL.has_point(celda)
		or (
			ZONA_SEGURA_EXTREMOS.has_point(celda)
			and (celda.x == 0 or celda.x == COLUMNAS - 1)
		)
	)


func es_transitable(celda: Vector2i) -> bool:
	return (
		es_celda_valida(celda)
		and not bloqueos_fijos.has(celda)
		and not bloqueos_mesas.has(celda)
		and not bloqueos_temporales.has(celda)
		and not grietas.has(celda)
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


func celda_de_acceso(posicion: Vector3) -> Vector2i:
	# Una mesa puede bloquear parte de una celda mientras el personaje cabe
	# en el borde libre. Proyectar al grafo sin abrir la celda de la mesa.
	var actual := posicion_a_celda(posicion)
	if es_transitable(actual):
		return actual
	var cercana := Vector2i(-1, -1)
	var menor_distancia := INF
	for fila: int in range(FILAS):
		for columna: int in range(COLUMNAS):
			var celda := Vector2i(columna, fila)
			if not es_transitable(celda):
				continue
			var centro := celda_a_posicion(celda)
			var distancia := Vector2(centro.x - posicion.x, centro.z - posicion.z).length_squared()
			if distancia < menor_distancia:
				menor_distancia = distancia
				cercana = celda
	return cercana


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


func celdas_alcanzables(origen: Vector2i) -> Dictionary:
	# Lee la ocupación actual, incluso antes de reconstruir la adyacencia.
	if not es_transitable(origen):
		return {}
	var visitadas: Dictionary = {origen: true}
	var pendientes: Array[Vector2i] = [origen]
	while not pendientes.is_empty():
		var actual: Vector2i = pendientes.pop_back()
		for direccion: Vector2i in DIRECCIONES:
			var vecina := actual + direccion
			if not visitadas.has(vecina) and es_transitable(vecina):
				visitadas[vecina] = true
				pendientes.append(vecina)
	return visitadas


func calcular_ruta(origen: Vector2i, destino: Vector2i) -> Array[Vector2i]:
	return calcular_ruta_a_mas_cercana(origen, [destino])


func calcular_ruta_a_mas_cercana(origen: Vector2i, destinos: Array[Vector2i]) -> Array[Vector2i]:
	# Un solo Dijkstra: termina al alcanzar el primer destino pendiente.
	if not adyacencia.has(origen) or destinos.is_empty():
		return []
	var destino := Vector2i(-1, -1)

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

		if destinos.has(actual):
			destino = actual
			break

		sin_visitar.erase(actual)

		for vecina: Vector2i in adyacencia[actual]:
			var distancia_nueva: float = float(distancias[actual]) + 1.0

			if distancia_nueva < float(distancias[vecina]):
				distancias[vecina] = distancia_nueva
				anterior[vecina] = actual

	if destino == Vector2i(-1, -1):
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
