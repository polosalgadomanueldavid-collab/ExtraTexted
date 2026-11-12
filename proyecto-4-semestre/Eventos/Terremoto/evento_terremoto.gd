extends Node3D

signal iniciado
signal temblor_actualizado(tiempo: float, intensidad: float)
signal suelo_roto
signal jugador_caido(jugador: Player)
signal terminado

enum Etapa { INACTIVO, AVISO, RUPTURA, RECUPERACION }

const Grieta := preload("res://Eventos/Terremoto/grieta.gd")
const SonidosEventos := preload("res://Eventos/sonidos_eventos.gd")
const ZONA_MESAS := Rect2(-3.72, 1.04, 5.42, 4.72)
const SEGUNDOS_POR_ETAPA := 8.0
const DURACION := 3.0 * SEGUNDOS_POR_ETAPA
const TIEMPO_CIERRE := 0.60
# La base del policía mide 0.45 × 0.31 m y proyecta hasta 0.55 m en diagonal.
const ANCHOS: Array[float] = [1.33, 0.79, 0.73, 0.69]
const LARGOS: Array[float] = [2.18, 1.70, 1.42, 1.15]

@export var suelo: CSGBox3D

var permiso_inicio: Callable
var sonidos: SonidosEventos

var etapa := Etapa.INACTIVO
var activo: bool:
	get:
		return etapa != Etapa.INACTIVO
var tiempo := 0.0
var grietas: Array[Grieta] = []
var caidos: Array[StaticBody3D] = []

var _trazado: Array[Grieta] = []
var _celdas_rotas: Dictionary[Vector2i, bool] = {}
var _celdas_caidas: Dictionary[Vector2i, Grieta] = {}
var _azar := RandomNumberGenerator.new()
var _cerrando := false
var _grafo: GrafoPiso
var _jugador: Player
var _bloqueos: Dictionary
var _altura: float
var _ultimo_apoyo: Vector3
var _solto_gravilla := false
var _huella_hoja: Rect2
var _jugador_en_grieta := false


func _ready() -> void:
	sonidos = SonidosEventos.new()
	add_child(sonidos)
	_altura = suelo.to_global(Vector3.UP * suelo.size.y * 0.5).y
	set_physics_process(false)


func iniciar(grafo: GrafoPiso, jugador: Player, bloqueos: Dictionary, huella_hoja: Rect2) -> bool:
	if permiso_inicio.is_valid() and not permiso_inicio.call():
		return false
	var celda_jugador := grafo.posicion_a_celda(jugador.global_position)
	if activo or get_tree().paused or not grafo.es_celda_valida(celda_jugador) or grafo.es_zona_segura(celda_jugador):
		return false
	_grafo = grafo
	_jugador = jugador
	_bloqueos = bloqueos
	_huella_hoja = huella_hoja
	var origen := grafo.celda_de_acceso(jugador.global_position)
	var alcanzables := grafo.celdas_alcanzables(origen)
	var destinos := GrafoPiso.DESTINOS.values()
	for acceso: Node3D in get_tree().get_nodes_in_group("accesos_navegacion"):
		destinos.append(grafo.posicion_a_celda(acceso.global_position))
	var protegidos: Array[Vector2i] = []
	for celda: Vector2i in destinos:
		if alcanzables.has(celda):
			protegidos.append(celda)

	# La copia permite validar las cuatro grietas y mantener intactos los
	# caminos, las colisiones y las mesas hasta el instante de la rotura.
	var ensayo := AStarGrid2D.new()
	ensayo.region = Rect2i(0, 0, GrafoPiso.COLUMNAS, GrafoPiso.FILAS)
	ensayo.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	ensayo.update()
	for fila in range(GrafoPiso.FILAS):
		for columna in range(GrafoPiso.COLUMNAS):
			var celda := Vector2i(columna, fila)
			ensayo.set_point_solid(celda, not grafo.es_transitable(celda))
	for i in range(ANCHOS.size()):
		if not _elegir_grieta(i, origen, protegidos, ensayo):
			for anterior in _trazado:
				anterior.free()
			_trazado.clear()
			_celdas_caidas.clear()
			_celdas_rotas.clear()
			return false
	for grieta in _trazado:
		add_child(grieta)
	etapa = Etapa.AVISO
	tiempo = 0.0
	_cerrando = false
	_jugador_en_grieta = false
	set_physics_process(true)
	sonidos.iniciar_terremoto()
	iniciado.emit()
	return true


func _abrir_suelo() -> void:
	etapa = Etapa.RUPTURA
	sonidos.romper_suelo()
	grietas.assign(_trazado)
	_trazado.clear()
	_grafo.grietas.assign(_celdas_rotas)
	_celdas_rotas.clear()
	for grieta in grietas:
		grieta.abrir(suelo)
	for celda in _celdas_caidas:
		var bloqueo := _bloqueos[celda] as StaticBody3D
		bloqueo.call("caer_en_grieta", _celdas_caidas[celda].centro)
		caidos.append(bloqueo)
		_bloqueos.erase(celda)
		_grafo.bloqueos_temporales.erase(celda)
	_celdas_caidas.clear()
	_grafo.construir_adyacencia()
	# Si el suelo se abre justo debajo del jugador, empezar en tierra firme.
	_ultimo_apoyo = _grafo.celda_a_posicion(_grafo.celda_de_acceso(_jugador.global_position))
	_ultimo_apoyo.y = _altura
	suelo_roto.emit()


func _elegir_grieta(indice: int, origen: Vector2i, destinos: Array[Vector2i], ensayo: AStarGrid2D) -> bool:
	var mesas := _bloqueos.keys()
	var libres: Array[Vector2i] = []
	for celda: Vector2i in _grafo.adyacencia:
		var p := _grafo.celda_a_posicion(celda)
		if ZONA_MESAS.has_point(Vector2(p.x, p.z)) and not _celdas_rotas.has(celda):
			libres.append(celda)
	# En pasillos estrechos se acorta el trazado, conservando el ancho del salto.
	for escala: float in [1.0, 0.78, 0.60]:
		for grupo: Array in [mesas, libres]:
			var candidatas := grupo.duplicate()
			while not candidatas.is_empty():
				var celda: Vector2i = candidatas.pop_at(_azar.randi_range(0, candidatas.size() - 1))
				if _celdas_rotas.has(celda) or origen == celda or destinos.has(celda):
					continue
				var p := _grafo.celda_a_posicion(celda)
				var centro := Vector2(p.x + _azar.randf_range(-0.17, 0.17), p.z + _azar.randf_range(-0.17, 0.17))
				var candidata := Grieta.new()
				candidata.trazar(centro, LARGOS[indice] * escala, ANCHOS[indice], _azar.randf_range(-PI, PI), _azar)
				if ZONA_MESAS.encloses(candidata.limites) and _validar_trazado(candidata, origen, destinos, ensayo):
					candidata.saltable = indice > 0
					_trazado.append(candidata)
					return true
				candidata.free()
	return false


func _validar_trazado(candidata: Grieta, origen: Vector2i, destinos: Array[Vector2i], ensayo: AStarGrid2D) -> bool:
	var p := _jugador.global_position
	if candidata.toca_cuadro(Vector2(p.x, p.z), 0.32):
		return false
	if _huella_hoja.has_area() and candidata.limites.intersects(_huella_hoja):
		return false
	for otra in _trazado:
		if otra.invade_borde(candidata.contorno, candidata.limites):
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
			if _grafo.es_zona_segura(celda):
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
		if ensayo.get_id_path(origen, destino).is_empty():
			for celda in anteriores:
				ensayo.set_point_solid(celda, anteriores[celda])
			return false
	for celda in peligros:
		_celdas_rotas[celda] = true
	for celda in colindantes:
		_celdas_caidas[celda] = candidata
	return true


func atrapo_hoja(posicion: Vector3) -> bool:
	if not activo or posicion.y >= _altura - 0.025:
		return false
	for grieta in grietas:
		if grieta.contiene(Vector2(posicion.x, posicion.z)):
			return true
	return false


func _physics_process(delta: float) -> void:
	tiempo = minf(tiempo + delta, DURACION)
	var intensidad := 1.0
	if tiempo + 0.00001 < SEGUNDOS_POR_ETAPA:
		intensidad = lerpf(0.14, 1.0, smoothstep(0.0, SEGUNDOS_POR_ETAPA, tiempo))
	elif etapa == Etapa.AVISO:
		_abrir_suelo()
	if tiempo + 0.00001 >= SEGUNDOS_POR_ETAPA * 2.0:
		etapa = Etapa.RECUPERACION
		intensidad = 1.0 - smoothstep(SEGUNDOS_POR_ETAPA * 2.0, DURACION, tiempo)
		if not _cerrando and tiempo + 0.00001 >= DURACION - TIEMPO_CIERRE:
			_cerrando = true
			sonidos.cerrar_suelo()
			for grieta in grietas:
				grieta.animar_cierre()
	# Detectar la entrada antes del rescate o del cierre del suelo.
	var en_grieta := not _jugador.is_on_floor() and _jugador.velocity.y < 0.0 and atrapo_hoja(_jugador.global_position)
	var acaba_de_caer := en_grieta and not _jugador_en_grieta
	_jugador_en_grieta = en_grieta
	if acaba_de_caer:
		jugador_caido.emit(_jugador)
	if tiempo + 0.00001 >= DURACION:
		temblor_actualizado.emit(DURACION, 0.0)
		_cerrar()
		return
	var intensidad_local := intensidad * _peso_en_zona_de_juego()
	sonidos.actualizar_terremoto(intensidad, intensidad_local)
	temblor_actualizado.emit(tiempo, intensidad_local)
	if etapa == Etapa.AVISO:
		return
	if _jugador.global_position.y < _altura - 0.55:
		_devolver_a_tierra()
	elif not _solto_gravilla and _jugador.velocity.y < 0.0 and _jugador.global_position.y < _altura - 0.10:
		var pies := Vector2(_jugador.global_position.x, _jugador.global_position.z)
		for grieta in grietas:
			if grieta.saltable and grieta.contiene(pies):
				grieta.desprender_gravilla(pies)
				_solto_gravilla = true
				break
	elif _jugador.is_on_floor() and absf(_jugador.global_position.y - _altura) < 0.025:
		var pies := _jugador.global_position
		for grieta in grietas:
			if grieta.toca_cuadro(Vector2(pies.x, pies.z), 0.14):
				return
		_ultimo_apoyo = pies
		_solto_gravilla = false


func _peso_en_zona_de_juego() -> float:
	var p := _jugador.global_position
	var celda := _grafo.posicion_a_celda(p)
	if not _grafo.es_celda_valida(celda) or _grafo.es_zona_segura(celda):
		return 0.0
	# El temblor se desvanece en la última casilla antes de entrar al descanso.
	var centro := _grafo.celda_a_posicion(celda)
	var peso := 1.0
	for direccion in GrafoPiso.DIRECCIONES:
		if _grafo.es_zona_segura(celda + direccion):
			var avance := Vector2(p.x - centro.x, p.z - centro.z).dot(Vector2(direccion))
			peso = minf(peso, smoothstep(0.0, GrafoPiso.TAMANO_CELDA, GrafoPiso.TAMANO_CELDA * 0.5 - avance))
	return peso


func _devolver_a_tierra() -> void:
	_solto_gravilla = false
	_jugador_en_grieta = false
	_jugador.global_position = _ultimo_apoyo + Vector3.UP * 0.04
	_jugador.velocity = Vector3.ZERO
	_jugador.reset_physics_interpolation()


func _cerrar() -> void:
	if _jugador.global_position.y < _altura - 0.025:
		_devolver_a_tierra()
	for grieta in grietas:
		grieta.cerrar()
	grietas.clear()
	_grafo.grietas.clear()
	_grafo.construir_adyacencia()
	set_physics_process(false)
	sonidos.detener()
	etapa = Etapa.INACTIVO
	terminado.emit()
