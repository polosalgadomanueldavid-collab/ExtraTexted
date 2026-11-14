extends Node3D

signal inicio_solicitado
signal temblor_actualizado(tiempo: float, intensidad: float)
signal suelo_roto
signal terminado

enum Etapa { INACTIVO, AVISO, RUPTURA, RECUPERACION }

const Grieta := preload("res://Eventos/Terremoto/grieta.gd")
const ZONA_MESAS := Rect2(-3.72, 1.04, 5.42, 4.72)
const SEGUNDOS_POR_ETAPA := 8.0
const DURACION := 3.0 * SEGUNDOS_POR_ETAPA
const TIEMPO_CIERRE := 0.60
# La base del policía mide 0.45 × 0.31 m y proyecta hasta 0.55 m en diagonal.
const ANCHOS: Array[float] = [1.33, 0.79, 0.73, 0.69]
const LARGOS: Array[float] = [2.18, 1.70, 1.42, 1.15]
const ANCHO_PISO := 7.0
const LARGO_PISO := 12.5
const RESOLUCION_MASCARA := 32

@export var suelo: CSGBox3D
@export_range(5.0, 120.0, 1.0) var espera_minima := 25.0
@export_range(5.0, 120.0, 1.0) var espera_maxima := 40.0

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
var _reloj: Timer
var _cerrando := false
var _grafo: GrafoPiso
var _jugador: Player
var _bloqueos: Dictionary
var _altura: float
var _ultimo_apoyo: Vector3
var _solto_gravilla := false
var _huella_hoja: Rect2
var _material_piso: ShaderMaterial
var _colision_jugador: CollisionShape3D


func _ready() -> void:
	var material := suelo.material as ShaderMaterial
	if material != null:
		_material_piso = material.duplicate() as ShaderMaterial
		suelo.material = _material_piso
	_reloj = Timer.new()
	_reloj.one_shot = true
	_reloj.process_callback = Timer.TIMER_PROCESS_PHYSICS
	add_child(_reloj)
	_reloj.timeout.connect(_solicitar_inicio)
	_altura = suelo.to_global(Vector3.UP * suelo.size.y * 0.5).y
	set_physics_process(false)


func programar() -> void:
	_reloj.start(_azar.randf_range(espera_minima, maxf(espera_maxima, espera_minima)))


func _solicitar_inicio() -> void:
	# Si sigue en la zona segura o en una interacción, consultar de nuevo.
	_reloj.start(2.0)
	inicio_solicitado.emit()


func iniciar(grafo: GrafoPiso, jugador: Player, bloqueos: Dictionary, huella_hoja: Rect2) -> bool:
	var celda_jugador := grafo.posicion_a_celda(jugador.global_position)
	if activo or get_tree().paused or not grafo.es_celda_valida(celda_jugador) or grafo.es_zona_segura(celda_jugador):
		return false
	_grafo = grafo
	_jugador = jugador
	_colision_jugador = jugador.get_node_or_null("Colision") as CollisionShape3D
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
	_reloj.stop()
	etapa = Etapa.AVISO
	tiempo = 0.0
	_cerrando = false
	set_physics_process(true)
	return true


func _abrir_suelo() -> void:
	etapa = Etapa.RUPTURA
	grietas.assign(_trazado)
	_trazado.clear()
	_grafo.grietas.assign(_celdas_rotas)
	_celdas_rotas.clear()
	for grieta in grietas:
		grieta.abrir(suelo)
	_actualizar_mascara_huecos()
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
			for grieta in grietas:
				grieta.animar_cierre()
	if tiempo + 0.00001 >= DURACION:
		temblor_actualizado.emit(DURACION, 0.0)
		_cerrar()
		return
	temblor_actualizado.emit(tiempo, intensidad * _peso_en_zona_de_juego())
	if etapa == Etapa.AVISO:
		return
	var punto_jugador := Vector2(_jugador.global_position.x, _jugador.global_position.z)
	var dentro_de_hueco := false
	for grieta in grietas:
		if grieta.contiene_hueco(punto_jugador):
			dentro_de_hueco = true
			break
	if dentro_de_hueco and _colision_jugador != null and not _colision_jugador.disabled:
		_colision_jugador.set_deferred("disabled", true)
		_jugador.velocity.y = minf(_jugador.velocity.y, -2.0)
	if _jugador.global_position.y < _altura - 1.45:
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
	if _colision_jugador != null:
		_colision_jugador.set_deferred("disabled", false)
	_jugador.global_position = _ultimo_apoyo + Vector3.UP * 0.04
	_jugador.velocity = Vector3.ZERO
	_jugador.reset_physics_interpolation()


func _cerrar() -> void:
	if _colision_jugador != null:
		_colision_jugador.set_deferred("disabled", false)
	if _material_piso != null:
		_material_piso.set_shader_parameter("usar_mascara_huecos", false)
	if _jugador.global_position.y < _altura - 0.025:
		_devolver_a_tierra()
	for grieta in grietas:
		grieta.cerrar()
	grietas.clear()
	_grafo.grietas.clear()
	_grafo.construir_adyacencia()
	set_physics_process(false)
	etapa = Etapa.INACTIVO
	terminado.emit()
	programar()


func _actualizar_mascara_huecos() -> void:
	if _material_piso == null:
		return
	var ancho := int(ANCHO_PISO * RESOLUCION_MASCARA)
	var alto := int(LARGO_PISO * RESOLUCION_MASCARA)
	var imagen := Image.create(ancho, alto, false, Image.FORMAT_R8)
	imagen.fill(Color.WHITE)
	var origen := Vector2(GrafoPiso.ORIGEN_X, GrafoPiso.ORIGEN_Z)
	for grieta in grietas:
		var inicio_x := clampi(int(floor((grieta.limites.position.x - origen.x) * RESOLUCION_MASCARA)), 0, ancho - 1)
		var fin_x := clampi(int(ceil((grieta.limites.end.x - origen.x) * RESOLUCION_MASCARA)), 0, ancho - 1)
		var inicio_y := clampi(int(floor((grieta.limites.position.y - origen.y) * RESOLUCION_MASCARA)), 0, alto - 1)
		var fin_y := clampi(int(ceil((grieta.limites.end.y - origen.y) * RESOLUCION_MASCARA)), 0, alto - 1)
		for y in range(inicio_y, fin_y + 1):
			for x in range(inicio_x, fin_x + 1):
				var punto := origen + Vector2((float(x) + 0.5) / RESOLUCION_MASCARA,
					(float(y) + 0.5) / RESOLUCION_MASCARA)
				if Geometry2D.is_point_in_polygon(punto, grieta.contorno_hueco):
					imagen.set_pixel(x, y, Color.BLACK)
	_material_piso.set_shader_parameter("mascara_huecos", ImageTexture.create_from_image(imagen))
	_material_piso.set_shader_parameter("usar_mascara_huecos", true)
