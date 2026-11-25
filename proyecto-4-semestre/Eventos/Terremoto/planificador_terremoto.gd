extends RefCounted
## Solo datos y AStar privado. No crea nodos, mallas, materiales ni toca el árbol activo.
const Forma := preload("res://Eventos/Terremoto/forma_grieta.gd")
const Presupuesto := preload("res://Eventos/Terremoto/presupuesto_preparacion.gd")
const ZONA_MESAS := Rect2(-3.72, 1.04, 5.42, 4.72)
const ZONA_SISMO := Rect2(-3.72, 1.04, 5.42, 10.65)
const ZONA_DESCANSO := Rect2(-3.45, 6.95, 5.15, 4.65)
const ZONA_DERRUMBES_SUPERIOR := Rect2(-4.05, 0.40, 6.15, 6.50)
# La base del policía mide 0.45 × 0.31 m y proyecta hasta 0.55 m en diagonal.
const ANCHOS: Array[float] = [1.33, 0.79, 0.73, 0.69, 0.73, 0.69, 0.73, 0.69, 0.73, 0.69, 0.69]
const LARGOS: Array[float] = [2.18, 1.70, 1.42, 1.15, 1.05, 1.00, 1.25, 1.15, 1.10, 1.00, 0.95]
const MINIMO_GRIETAS := 10
const GRIETAS_OFICINA_INICIALES := 3
const MINIMO_ESCOMBROS := 14
const MAXIMO_ESCOMBROS := 23
const MINIMO_ESCOMBROS_SUPERIORES := 14
const MAXIMO_ESCOMBROS_SUPERIORES := 20
const MAXIMO_ESCOMBROS_DESCANSO := 3
const MINIMO_PASOS_CERRADOS := 4

var presupuesto: Presupuesto
var _grafo: GrafoPiso
var _posicion_jugador: Vector3
var _bloqueos: Dictionary
var _huella_hoja: Rect2
var posiciones_red: Array[Vector3] = []
var hojas_red: Array[Vector3] = []
var accesos: Array[Vector3] = []
var _azar := RandomNumberGenerator.new()
var _trazado: Array[Forma] = []
var grieta_gigante: Forma
var _origen_seguro: Vector2i
var _celdas_rotas: Dictionary[Vector2i, bool] = {}
var _celdas_caidas: Dictionary[Vector2i, Forma] = {}
var _reservas_escombros: Dictionary[Vector2i, bool] = {}

func _limpiar() -> void:
	_trazado.clear()
	grieta_gigante = null
	_celdas_rotas.clear()
	_celdas_caidas.clear()
	_reservas_escombros.clear()

func planificar() -> Dictionary:
	var origen := _grafo.celda_de_acceso(_posicion_jugador)
	var alcanzables := _grafo.celdas_alcanzables(origen)
	var destinos := GrafoPiso.DESTINOS.values()
	for punto: Vector3 in posiciones_red:
		var acceso_red := _grafo.celda_de_acceso(punto)
		if not destinos.has(acceso_red):
			destinos.append(acceso_red)
	for acceso: Vector3 in accesos:
		destinos.append(_grafo.posicion_a_celda(acceso))
	var protegidos: Array[Vector2i] = []
	for celda: Vector2i in destinos:
		if alcanzables.has(celda):
			protegidos.append(celda)

	# Si el jugador espera en descanso, la gigante puede abrirse bajo sus
	# pies después del aviso. Las rutas y el rescate parten de un acceso firme.
	if _grafo.es_zona_segura(origen) and not protegidos.is_empty():
		origen = protegidos[0]
	_origen_seguro = origen

	# La copia permite validar grietas y derrumbes y mantener intactos los
	# caminos, las colisiones y las mesas hasta el instante de la rotura.
	var ensayo := AStarGrid2D.new()
	ensayo.region = Rect2i(0, 0, GrafoPiso.COLUMNAS, GrafoPiso.FILAS)
	ensayo.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	ensayo.update()
	var espacios_escombros: Array[Rect2i] = []
	var plan_valido := false
	for intento in range(32):
		await presupuesto.paso()
		if presupuesto.cancelado: return {}
		_limpiar()
		espacios_escombros.clear()
		for fila in range(GrafoPiso.FILAS):
			for columna in range(GrafoPiso.COLUMNAS):
				var celda := Vector2i(columna, fila)
				ensayo.set_point_solid(celda, not _grafo.es_transitable(celda))
		if not await _elegir_gigante(origen, protegidos, ensayo):
			continue
		var cantidad := ANCHOS.size() if intento < 3 else MINIMO_GRIETAS - 1
		for i in range(cantidad):
			# Reservar los derrumbes junto a las primeras grietas, antes de que
			# las restantes consuman todo el suelo firme de la oficina.
			if i == GRIETAS_OFICINA_INICIALES:
				var cupo := MAXIMO_ESCOMBROS_SUPERIORES if intento < 3 else (16 if intento < 6 else MINIMO_ESCOMBROS_SUPERIORES)
				espacios_escombros = await _elegir_espacios_escombros(origen, protegidos, ensayo, cupo, true)
				if espacios_escombros.size() < MINIMO_ESCOMBROS:
					break
				for espacio in espacios_escombros:
					for celda in _celdas_del_espacio(espacio):
						_reservas_escombros[celda] = true
			# Si la oficina está muy ocupada, acortar sin estrechar los saltos.
			var escala := (0.85 if i == 0 else (0.65 if intento < 16 else 0.60)) if intento >= 6 else 1.0
			if not await _elegir_grieta(i, origen, protegidos, ensayo, escala):
				break
		if _trazado.size() >= MINIMO_GRIETAS and espacios_escombros.size() >= MINIMO_ESCOMBROS:
			var inferiores := await _elegir_espacios_escombros(origen, protegidos, ensayo, 0, false)
			if presupuesto.cancelado: return {}
			# Descanso admite hasta tres derrumbes, pero no es obligatorio ocuparlo.
			# Los mínimos y los montones anchos se garantizan en la zona superior.
			espacios_escombros.append_array(inferiores)
			plan_valido = true
			break
	if not plan_valido:
		_limpiar()
		return {}
	# Mantener primero la grieta grande de oficina, luego las saltables.
	_trazado.erase(grieta_gigante)
	_trazado.append(grieta_gigante)
	var formas: Array[Dictionary] = []
	for forma in _trazado:
		formas.append(forma.serializar())
	var caidas := {}
	for celda: Vector2i in _celdas_caidas:
		caidas[celda] = _trazado.find(_celdas_caidas[celda])
	return {"formas": formas, "gigante": _trazado.find(grieta_gigante), "rotas": _celdas_rotas.duplicate(), "caidas": caidas, "reservas": _reservas_escombros.duplicate(), "espacios": espacios_escombros, "azar_escombros": _azar.state, "origen": _origen_seguro}


func _elegir_gigante(origen: Vector2i, destinos: Array[Vector2i], ensayo: AStarGrid2D) -> bool:
	for intento in range(48):
		await presupuesto.paso()
		if presupuesto.cancelado: return false
		var centro := Vector2(_azar.randf_range(-1.1, -0.25), _azar.randf_range(9.1, 9.5))
		var angulo := _azar.randf_range(-0.16, 0.16)
		var largo := _azar.randf_range(3.85, 4.3)
		var ancho := _azar.randf_range(2.05, 2.4)
		if intento >= 24:
			# Conservar también los accesos de las dos herramientas en partidas LAN.
			centro = Vector2(-1.25, 8.18 if intento % 2 == 0 else 10.45)
			angulo = PI * 0.5
			largo = _azar.randf_range(3.70, 3.85)
			ancho = _azar.randf_range(2.0, 2.1)
		var candidata := Forma.new()
		candidata.trazar(centro, largo, ancho, angulo, _azar)
		if ZONA_DESCANSO.encloses(candidata.limites) and await _validar_trazado(candidata, origen, destinos, ensayo, true):
			grieta_gigante = candidata
			_trazado.append(candidata)
			return true
	return false


func _celdas_del_espacio(espacio: Rect2i) -> Array[Vector2i]:
	var celdas: Array[Vector2i] = []
	for z in range(espacio.position.y, espacio.end.y):
		for x in range(espacio.position.x, espacio.end.x):
			celdas.append(Vector2i(x, z))
	return celdas


func _cajon_bajo_derrumbe(espacio: Rect2i) -> bool:
	return espacio.size == Vector2i.ONE and _bloqueos.has(espacio.position) and not _celdas_caidas.has(espacio.position)


func _paso_abierto(celda: Vector2i, ensayo: AStarGrid2D) -> float:
	# Romper los recorridos rectos largos, especialmente donde se cruzan.
	if ensayo.is_point_solid(celda):
		return 0.0
	var horizontal := 1
	var vertical := 1
	for direccion in GrafoPiso.DIRECCIONES:
		var siguiente := celda + direccion
		var largo := 0
		while _grafo.es_celda_valida(siguiente) and siguiente.y < 14 and not ensayo.is_point_solid(siguiente):
			largo += 1
			siguiente += direccion
		if direccion.x != 0:
			horizontal += largo
		else:
			vertical += largo
	return float(maxi(horizontal, vertical)) + float(mini(horizontal, vertical)) * 0.5


func _elegir_espacios_escombros(origen: Vector2i, destinos: Array[Vector2i], ensayo: AStarGrid2D, cupo_superior: int, solo_superior: bool) -> Array[Rect2i]:
	var candidatas: Array[Rect2i] = []
	var puntuaciones: Dictionary[Rect2i, float] = {}
	for fila in range(GrafoPiso.FILAS - 1):
		for columna in range(GrafoPiso.COLUMNAS - 1):
			for tamano: Vector2i in [Vector2i(2, 1), Vector2i(1, 2), Vector2i.ONE]:
				await presupuesto.paso()
				if presupuesto.cancelado: return []
				var espacio := Rect2i(Vector2i(columna, fila), tamano)
				var sobre_cajon := _cajon_bajo_derrumbe(espacio)
				var valida := true
				for celda in _celdas_del_espacio(espacio):
					if (ensayo.is_point_solid(celda) and not sobre_cajon) or celda == origen or destinos.has(celda):
						valida = false
						break
				if not valida:
					continue
				var p := _grafo.celda_a_posicion(espacio.position)
				var medidas := Vector2(tamano) * GrafoPiso.TAMANO_CELDA - Vector2.ONE * 0.04
				var punto := Vector2(p.x, p.z) + Vector2(tamano - Vector2i.ONE) * GrafoPiso.TAMANO_CELDA * 0.5
				var huella := Rect2(punto - medidas * 0.5, medidas)
				var arriba := ZONA_DERRUMBES_SUPERIOR.encloses(huella)
				if arriba != solo_superior:
					continue
				if (not arriba and not ZONA_SISMO.encloses(huella)) or huella.grow(0.32).has_point(Vector2(_posicion_jugador.x, _posicion_jugador.z)):
					continue
				if _huella_hoja.has_area() and huella.grow(0.12).intersects(_huella_hoja):
					continue
				for protegido: Vector3 in posiciones_red + hojas_red:
					if huella.grow(0.35).has_point(Vector2(protegido.x, protegido.z)):
						valida = false
						break
				if not valida:
					continue
				var bordes: Array[Vector2] = []
				for grieta in _trazado:
					for celda in _celdas_del_espacio(espacio):
						var centro := _grafo.celda_a_posicion(celda)
						if grieta.toca_cuadro(Vector2(centro.x, centro.z), 0.25):
							valida = false
							break
					if not valida:
						break
					var cercano := grieta.contorno[0]
					for j in range(grieta.contorno.size()):
						var borde := Geometry2D.get_closest_point_to_segment(punto, grieta.contorno[j - 1], grieta.contorno[j])
						if punto.distance_squared_to(borde) < punto.distance_squared_to(cercano):
							cercano = borde
					if punto.distance_to(cercano) < 1.35:
						bordes.append(cercano - punto)
				if not valida or (bordes.is_empty() and not arriba):
					continue
				# Priorizar pasos entre dos grietas y montones de dos casillas.
				var puntuacion := 6.0 if bordes.is_empty() else 4.0 + bordes[0].length()
				for a in range(bordes.size()):
					for b in range(a + 1, bordes.size()):
						if bordes[a].normalized().dot(bordes[b].normalized()) < -0.25:
							puntuacion = minf(puntuacion, bordes[a].length() + bordes[b].length())
				candidatas.append(espacio)
				# Primero saturar oficina; descanso no puede consumir el cupo.
				var preferencia_ancho := (2.0 if arriba else 5.0) if tamano != Vector2i.ONE else 0.0
				var paso := _paso_abierto(espacio.position, ensayo) if arriba else 0.0
				puntuaciones[espacio] = puntuacion - (40.0 if arriba else 0.0) - preferencia_ancho - paso * 1.3 + (3.0 if sobre_cajon else 0.0)
	candidatas.sort_custom(func(a: Rect2i, b: Rect2i) -> bool: return puntuaciones[a] < puntuaciones[b])
	var elegidas: Array[Rect2i] = []
	var superiores := 0
	var descanso := 0
	var indice := 0
	var sin_cambios := 0
	# Reconsiderar los pasos antes rechazados: al ocupar el fondo de un
	# callejón, el siguiente tramo ya puede cerrarse sin aislar suelo libre.
	while sin_cambios < candidatas.size():
		await presupuesto.paso()
		if presupuesto.cancelado: return []
		var espacio := candidatas[indice % candidatas.size()]
		indice += 1
		sin_cambios += 1
		if elegidas.has(espacio):
			continue
		var arriba := espacio.end.y <= 14
		if arriba and superiores >= cupo_superior:
			continue
		if not arriba and descanso >= MAXIMO_ESCOMBROS_DESCANSO:
			continue
		var celdas := _celdas_del_espacio(espacio)
		# Un derrumbe puede aplastar un cajón que ya ocupaba esa casilla.
		# La ocupación no cambia: los caminos siguen siendo los ya validados.
		if _cajon_bajo_derrumbe(espacio):
			elegidas.append(espacio)
			sin_cambios = 0
			if arriba:
				superiores += 1
			else:
				descanso += 1
			if elegidas.size() >= MAXIMO_ESCOMBROS:
				break
			continue
		var conectado := true
		for celda in celdas:
			if ensayo.is_point_solid(celda):
				conectado = false
		if not conectado:
			continue
		var vecinos_conectados: Array[Vector2i] = []
		for celda in celdas:
			for direccion in GrafoPiso.DIRECCIONES:
				var vecina := celda + direccion
				if _grafo.es_celda_valida(vecina) and not celdas.has(vecina) and not ensayo.is_point_solid(vecina) and not ensayo.get_id_path(origen, vecina).is_empty():
					vecinos_conectados.append(vecina)
		for celda in celdas:
			ensayo.set_point_solid(celda)
		for destino in destinos:
			await presupuesto.paso()
			if presupuesto.cancelado: return []
			if ensayo.get_id_path(origen, destino).is_empty():
				conectado = false
		# Mantener conectados los pasos vecinos para no encerrar al jugador.
		for vecina in vecinos_conectados:
			await presupuesto.paso()
			if presupuesto.cancelado: return []
			if ensayo.get_id_path(origen, vecina).is_empty():
				conectado = false
		if not conectado:
			for celda in celdas:
				ensayo.set_point_solid(celda, false)
			continue
		elegidas.append(espacio)
		sin_cambios = 0
		if arriba:
			superiores += 1
		else:
			descanso += 1
		if elegidas.size() >= MAXIMO_ESCOMBROS:
			break
	var anchos := 0
	var pasos_cerrados := 0
	for espacio in elegidas:
		if espacio.get_area() > 1:
			anchos += 1
		for celda in _celdas_del_espacio(espacio):
			if _grafo.es_transitable(celda):
				pasos_cerrados += 1
	# Repartir algunas huellas dobles en dos caídas independientes permite
	# mantener la densidad incluso sin cajones, sin ocupar ni cerrar más suelo.
	for i in range(elegidas.size() - 1, -1, -1):
		if superiores >= MINIMO_ESCOMBROS_SUPERIORES and elegidas.size() >= MINIMO_ESCOMBROS:
			break
		var espacio := elegidas[i]
		if espacio.end.y > 14 or espacio.get_area() != 2 or anchos <= 2:
			continue
		var celdas := _celdas_del_espacio(espacio)
		elegidas[i] = Rect2i(celdas[0], Vector2i.ONE)
		elegidas.insert(i + 1, Rect2i(celdas[1], Vector2i.ONE))
		superiores += 1
		anchos -= 1
	if solo_superior and (superiores < MINIMO_ESCOMBROS_SUPERIORES or pasos_cerrados < MINIMO_PASOS_CERRADOS or anchos < 2):
		elegidas.clear()
	return elegidas


func _elegir_grieta(indice: int, origen: Vector2i, destinos: Array[Vector2i], ensayo: AStarGrid2D, escala_general: float = 1.0) -> bool:
	var zona := ZONA_MESAS if indice < GRIETAS_OFICINA_INICIALES else ZONA_SISMO
	var mesas := _bloqueos.keys()
	var libres: Array[Vector2i] = []
	for celda: Vector2i in _grafo.adyacencia:
		var p := _grafo.celda_a_posicion(celda)
		if zona.has_point(Vector2(p.x, p.z)) and not _celdas_rotas.has(celda):
			libres.append(celda)
	# En pasillos estrechos se acorta el trazado, conservando el ancho del salto.
	for escala: float in [1.0, 0.78, 0.60]:
		for grupo: Array in [mesas, libres]:
			var candidatas := grupo.duplicate()
			while not candidatas.is_empty():
				await presupuesto.paso()
				if presupuesto.cancelado: return false
				var celda: Vector2i = candidatas.pop_at(_azar.randi_range(0, candidatas.size() - 1))
				if _celdas_rotas.has(celda) or origen == celda or destinos.has(celda):
					continue
				var p := _grafo.celda_a_posicion(celda)
				var centro := Vector2(p.x + _azar.randf_range(-0.17, 0.17), p.z + _azar.randf_range(-0.17, 0.17))
				var candidata := Forma.new()
				candidata.trazar(centro, LARGOS[indice] * escala * escala_general, ANCHOS[indice], _azar.randf_range(-PI, PI), _azar)
				if zona.encloses(candidata.limites) and await _validar_trazado(candidata, origen, destinos, ensayo):
					candidata.saltable = indice > 0
					_trazado.append(candidata)
					return true
	return false


func _validar_trazado(candidata: Forma, origen: Vector2i, destinos: Array[Vector2i], ensayo: AStarGrid2D, avisar_bajo_jugador: bool = false) -> bool:
	for hoja: Vector3 in hojas_red:
		if candidata.toca_cuadro(Vector2(hoja.x, hoja.z), 0.35):
			return false
	if not avisar_bajo_jugador:
		for punto: Vector3 in posiciones_red:
			if candidata.toca_cuadro(Vector2(punto.x, punto.z), 0.32):
				return false
	var p := _posicion_jugador
	if not avisar_bajo_jugador and candidata.toca_cuadro(Vector2(p.x, p.z), 0.32):
		return false
	if _huella_hoja.has_area() and candidata.limites.intersects(_huella_hoja):
		return false
	for otra in _trazado:
		if otra.invade_borde(candidata.contorno, candidata.limites):
			return false
	for celda in _reservas_escombros:
		var apoyo := _grafo.celda_a_posicion(celda)
		if candidata.toca_cuadro(Vector2(apoyo.x, apoyo.z), 0.31 if _bloqueos.has(celda) else 0.25):
			return false
	var peligros: Array[Vector2i] = []
	var colindantes: Array[Vector2i] = []
	var limites := candidata.limites.grow(0.32)
	var inicio := _grafo.posicion_a_celda(Vector3(limites.position.x, 0, limites.position.y))
	var fin := _grafo.posicion_a_celda(Vector3(limites.end.x, 0, limites.end.y))
	for z in range(inicio.y, fin.y + 1):
		for x in range(inicio.x, fin.x + 1):
			var celda := Vector2i(x, z)
			var posicion := _grafo.celda_a_posicion(celda)
			var punto := Vector2(posicion.x, posicion.z)
			if not _grafo.es_celda_valida(celda):
				return false
			if _bloqueos.has(celda) and not _celdas_caidas.has(celda) and candidata.toca_cuadro(punto, 0.31):
				colindantes.append(celda)
			# El grafo guía los pies entre centros de celda. Una punta que
			# apenas toca una esquina todavía deja una orilla transitable.
			if not _celdas_rotas.has(celda) and candidata.toca_cuadro(punto, 0.15):
				if celda == origen or destinos.has(celda):
					return false
				peligros.append(celda)
	var anteriores: Dictionary[Vector2i, bool] = {}
	for celda: Vector2i in peligros + colindantes:
		anteriores[celda] = ensayo.is_point_solid(celda)
	for celda in colindantes:
		ensayo.set_point_solid(celda, _celdas_rotas.has(celda))
	for celda in peligros:
		ensayo.set_point_solid(celda)
	for destino in destinos:
		await presupuesto.paso()
		if presupuesto.cancelado:
			for celda in anteriores: ensayo.set_point_solid(celda, anteriores[celda])
			return false
		if ensayo.get_id_path(origen, destino).is_empty():
			for celda in anteriores:
				ensayo.set_point_solid(celda, anteriores[celda])
			return false
	for celda in peligros:
		_celdas_rotas[celda] = true
	for celda in colindantes:
		_celdas_caidas[celda] = candidata
	return true


