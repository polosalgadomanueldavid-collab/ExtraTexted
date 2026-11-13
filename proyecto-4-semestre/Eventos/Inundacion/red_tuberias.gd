extends RefCounted
## Máscaras N/E/S/O. Se genera primero una ruta válida y luego se giran sus piezas.

const COLUMNAS := 5
const FILAS := 4
const DIRECCIONES := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
var piezas: Array[int] = []
var solucion: Array[int] = []
var conectadas: Array[int] = []
var resuelta := false


func generar(semilla: int) -> void:
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	var ruta: Array[int] = []
	for intento in 100:
		ruta = [0]
		var visitadas := {0: true}
		_buscar_ruta(ruta, visitadas, azar)
		if ruta.size() >= 9:
			break
	solucion.clear()
	for i in COLUMNAS * FILAS:
		solucion.append(3 if azar.randf() < 0.7 else 5)
	for i in ruta.size():
		var mascara := 0
		var celda := coordenada(ruta[i])
		var anterior := Vector2i(-1, 0) if i == 0 else coordenada(ruta[i - 1])
		var siguiente := Vector2i(COLUMNAS, FILAS - 1) if i == ruta.size() - 1 else coordenada(ruta[i + 1])
		mascara |= 1 << DIRECCIONES.find(anterior - celda)
		mascara |= 1 << DIRECCIONES.find(siguiente - celda)
		solucion[ruta[i]] = mascara
	piezas.assign(solucion)
	for i in piezas.size():
		for giro in azar.randi_range(0, 3):
			piezas[i] = rotada(piezas[i])
	# Nunca entregar una red ya conectada, incluso con semillas degeneradas.
	while comprobar():
		piezas[0] = rotada(piezas[0])
	comprobar()


func _buscar_ruta(ruta: Array[int], visitadas: Dictionary, azar: RandomNumberGenerator) -> bool:
	if ruta.back() == COLUMNAS * FILAS - 1:
		return true
	var opciones: Array[int] = [0, 1, 2, 3]
	for i in range(3, 0, -1):
		var j := azar.randi_range(0, i)
		var temporal := opciones[i]
		opciones[i] = opciones[j]
		opciones[j] = temporal
	for d in opciones:
		var vecina: Vector2i = coordenada(ruta.back()) + DIRECCIONES[d]
		if not dentro(vecina):
			continue
		var indice := vecina.y * COLUMNAS + vecina.x
		if visitadas.has(indice):
			continue
		visitadas[indice] = true
		ruta.append(indice)
		if _buscar_ruta(ruta, visitadas, azar):
			return true
		ruta.pop_back()
	return false


static func coordenada(indice: int) -> Vector2i:
	return Vector2i(indice % COLUMNAS, indice / COLUMNAS)


static func dentro(celda: Vector2i) -> bool:
	return celda.x >= 0 and celda.x < COLUMNAS and celda.y >= 0 and celda.y < FILAS


static func rotada(mascara: int) -> int:
	return ((mascara << 1) & 15) | (mascara >> 3)


func girar(indice: int) -> void:
	if indice < 0 or indice >= piezas.size():
		return
	piezas[indice] = rotada(piezas[indice])
	comprobar()


func comprobar() -> bool:
	conectadas.clear()
	resuelta = false
	if piezas.is_empty() or not (piezas[0] & 8):
		return false
	var pendientes: Array[int] = [0]
	var fuga := false
	var salida := false
	while not pendientes.is_empty():
		var indice: int = pendientes.pop_front()
		if conectadas.has(indice):
			continue
		conectadas.append(indice)
		for d in 4:
			if not (piezas[indice] & (1 << d)):
				continue
			if indice == 0 and d == 3:
				continue
			if indice == piezas.size() - 1 and d == 1:
				salida = true
				continue
			var vecina: Vector2i = coordenada(indice) + DIRECCIONES[d]
			if not dentro(vecina):
				fuga = true
				continue
			var vecino := vecina.y * COLUMNAS + vecina.x
			if not (piezas[vecino] & (1 << ((d + 2) % 4))):
				fuga = true
			else:
				pendientes.append(vecino)
	resuelta = salida and not fuga
	return resuelta
