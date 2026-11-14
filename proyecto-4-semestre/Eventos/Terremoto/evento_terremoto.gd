extends Node3D

signal iniciado
signal temblor_actualizado(tiempo: float, intensidad: float)
signal suelo_roto
signal escombros_actualizados
signal jugador_caido(jugador: Player)
signal terminado

enum Etapa { INACTIVO, AVISO, RUPTURA, RECUPERACION }

const Grieta := preload("res://Eventos/Terremoto/grieta.gd")
const Escombro := preload("res://Eventos/Terremoto/escombro.gd")
const SonidosEventos := preload("res://Eventos/sonidos_eventos.gd")
const ZONA_MESAS := Rect2(-3.72, 1.04, 5.42, 4.72)
const ZONA_SISMO := Rect2(-3.72, 1.04, 5.42, 10.65)
const ZONA_DESCANSO := Rect2(-3.45, 6.95, 5.15, 4.65)
const ZONA_DERRUMBES_SUPERIOR := Rect2(-4.05, 0.40, 6.15, 6.50)
const SEGUNDOS_POR_ETAPA := 8.0
const DURACION := 3.0 * SEGUNDOS_POR_ETAPA
const TIEMPO_CIERRE := 0.60
const ANCHO_PISO := 7.0
const LARGO_PISO := 12.5
const RESOLUCION_MASCARA := 32
# La base del policía mide 0.45 × 0.31 m y proyecta hasta 0.55 m en diagonal.
const ANCHOS: Array[float] = [1.33, 0.79, 0.73, 0.69, 0.73, 0.69, 0.73, 0.69, 0.73, 0.69, 0.69]
const LARGOS: Array[float] = [2.18, 1.70, 1.42, 1.15, 1.05, 1.00, 1.25, 1.15, 1.10, 1.00, 0.95]
const MINIMO_GRIETAS := 10
const MINIMO_ESCOMBROS := 14
const MAXIMO_ESCOMBROS := 23
const MINIMO_ESCOMBROS_SUPERIORES := 14
const MAXIMO_ESCOMBROS_SUPERIORES := 20
const MAXIMO_ESCOMBROS_DESCANSO := 3
const MINIMO_PASOS_CERRADOS := 4

@export var suelo: CSGBox3D
@export var techo: CSGBox3D

var permiso_inicio: Callable
var sonidos: SonidosEventos

var etapa := Etapa.INACTIVO
var activo: bool:
	get:
		return etapa != Etapa.INACTIVO
var tiempo := 0.0
var grietas: Array[Grieta] = []
var caidos: Array[StaticBody3D] = []
var escombros: Array[Escombro] = []
var grieta_gigante: Grieta
var _aviso_gigante: MeshInstance3D

var _trazado: Array[Grieta] = []
var _celdas_rotas: Dictionary[Vector2i, bool] = {}
var _celdas_caidas: Dictionary[Vector2i, Grieta] = {}
var _reservas_escombros: Dictionary[Vector2i, bool] = {}
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
var _origen_seguro: Vector2i
var _material_piso: ShaderMaterial
var _colision_jugador: CollisionShape3D


func _ready() -> void:
	var material := suelo.material as ShaderMaterial
	if material != null:
		_material_piso = material.duplicate() as ShaderMaterial
		suelo.material = _material_piso
	sonidos = SonidosEventos.new()
	add_child(sonidos)
	_altura = suelo.to_global(Vector3.UP * suelo.size.y * 0.5).y
	set_physics_process(false)


func iniciar(grafo: GrafoPiso, jugador: Player, bloqueos: Dictionary, huella_hoja: Rect2) -> bool:
	if permiso_inicio.is_valid() and not permiso_inicio.call():
		return false
	var celda_jugador := grafo.posicion_a_celda(jugador.global_position)
	if activo or get_tree().paused or not grafo.es_celda_valida(celda_jugador):
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

	# Si el jugador espera en descanso, la gigante puede abrirse bajo sus
	# pies después del aviso. Las rutas y el rescate parten de un acceso firme.
	if grafo.es_zona_segura(origen) and not protegidos.is_empty():
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
		_limpiar_trazado()
		espacios_escombros.clear()
		for fila in range(GrafoPiso.FILAS):
			for columna in range(GrafoPiso.COLUMNAS):
				var celda := Vector2i(columna, fila)
				ensayo.set_point_solid(celda, not grafo.es_transitable(celda))
		if not _elegir_gigante(origen, protegidos, ensayo):
			continue
		var cantidad := ANCHOS.size() if intento < 3 else MINIMO_GRIETAS - 1
		for i in range(cantidad):
			# Reservar los derrumbes junto a las primeras grietas, antes de que
			# las restantes consuman todo el suelo firme de la oficina.
			if i == 6:
				var cupo := MAXIMO_ESCOMBROS_SUPERIORES if intento < 3 else (16 if intento < 6 else MINIMO_ESCOMBROS_SUPERIORES)
				espacios_escombros = _elegir_espacios_escombros(origen, protegidos, ensayo, cupo, true)
				if espacios_escombros.size() < MINIMO_ESCOMBROS:
					break
				for espacio in espacios_escombros:
					for celda in _celdas_del_espacio(espacio):
						_reservas_escombros[celda] = true
			# Si la oficina está muy ocupada, acortar sin estrechar los saltos.
			var escala := (0.85 if i == 0 else (0.65 if intento < 16 else 0.60)) if intento >= 6 else 1.0
			if not _elegir_grieta(i, origen, protegidos, ensayo, escala):
				break
		if _trazado.size() >= MINIMO_GRIETAS and espacios_escombros.size() >= MINIMO_ESCOMBROS:
			var inferiores := _elegir_espacios_escombros(origen, protegidos, ensayo, 0, false)
			if not inferiores.is_empty():
				espacios_escombros.append_array(inferiores)
				plan_valido = true
				break
	if not plan_valido:
		_limpiar_trazado()
		return false
	# Mantener primero la grieta grande de oficina, luego las saltables.
	_trazado.erase(grieta_gigante)
	_trazado.append(grieta_gigante)
	_preparar_escombros(espacios_escombros)
	for grieta in _trazado:
		add_child(grieta)
	_mostrar_aviso_gigante()
	etapa = Etapa.AVISO
	tiempo = 0.0
	_cerrando = false
	_jugador_en_grieta = false
	set_physics_process(true)
	sonidos.iniciar_terremoto()
	iniciado.emit()
	return true


func _abrir_suelo() -> void:
	_retirar_aviso_gigante()
	etapa = Etapa.RUPTURA
	sonidos.romper_suelo()
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
	for i in range(escombros.size()):
		# Tres oleadas obligan a revisar los pasos durante toda la rotura.
		escombros[i].iniciar_aviso(0.25 + (i % 3) * 2.6 + (i / 3) * 0.12)
	_grafo.construir_adyacencia()
	# Si el suelo se abre justo debajo del jugador, empezar en tierra firme.
	_ultimo_apoyo = _apoyo_conectado(_jugador.global_position)
	suelo_roto.emit()


func _mostrar_aviso_gigante() -> void:
	var datos := SurfaceTool.new()
	datos.begin(Mesh.PRIMITIVE_TRIANGLES)
	var contorno := grieta_gigante.contorno
	for i in range(contorno.size()):
		var a := contorno[i]
		var b := contorno[(i + 1) % contorno.size()]
		var margen := (b - a).orthogonal().normalized() * 0.045
		for p: Vector2 in [a, b, b + margen, a, b + margen, a + margen]:
			datos.add_vertex(Vector3(p.x, _altura + 0.014, p.y))
	_aviso_gigante = MeshInstance3D.new()
	_aviso_gigante.mesh = datos.commit()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color("ffbd59")
	_aviso_gigante.material_override = material
	_aviso_gigante.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_aviso_gigante)


func _retirar_aviso_gigante() -> void:
	if is_instance_valid(_aviso_gigante):
		_aviso_gigante.hide()
		_aviso_gigante.queue_free()
		_aviso_gigante = null


func _elegir_gigante(origen: Vector2i, destinos: Array[Vector2i], ensayo: AStarGrid2D) -> bool:
	for intento in range(48):
		var centro := Vector2(_azar.randf_range(-1.1, -0.25), _azar.randf_range(9.1, 9.5))
		var angulo := _azar.randf_range(-0.16, 0.16)
		var largo := _azar.randf_range(3.85, 4.3)
		var ancho := _azar.randf_range(2.05, 2.4)
		if intento >= 24:
			centro = Vector2(-0.25, 8.18 if intento % 2 == 0 else 10.45)
			angulo = PI * 0.5
			largo = _azar.randf_range(3.70, 3.85)
			ancho = _azar.randf_range(2.0, 2.1)
		var candidata := Grieta.new()
		candidata.trazar(centro, largo, ancho, angulo, _azar)
		if ZONA_DESCANSO.encloses(candidata.limites) and _validar_trazado(candidata, origen, destinos, ensayo, true):
			grieta_gigante = candidata
			_trazado.append(candidata)
			return true
		candidata.free()
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
				if (not arriba and not ZONA_SISMO.encloses(huella)) or huella.grow(0.32).has_point(Vector2(_jugador.global_position.x, _jugador.global_position.z)):
					continue
				if _huella_hoja.has_area() and huella.grow(0.12).intersects(_huella_hoja):
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
				var preferencia_ancho := (-2.0 if arriba else 5.0) if tamano != Vector2i.ONE else 0.0
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
			if ensayo.get_id_path(origen, destino).is_empty():
				conectado = false
		# Mantener conectados los pasos vecinos para no encerrar al jugador.
		for vecina in vecinos_conectados:
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
	if (solo_superior and (superiores < MINIMO_ESCOMBROS_SUPERIORES or pasos_cerrados < MINIMO_PASOS_CERRADOS)) or (not solo_superior and anchos < 2):
		elegidas.clear()
	return elegidas


func _preparar_escombros(espacios: Array[Rect2i]) -> void:
	for espacio in espacios:
		var escombro := Escombro.new()
		escombro.celda = espacio.position
		escombro.celdas = _celdas_del_espacio(espacio)
		add_child(escombro)
		var p := _grafo.celda_a_posicion(espacio.position)
		p += Vector3(espacio.size.x - 1, 0, espacio.size.y - 1) * GrafoPiso.TAMANO_CELDA * 0.5
		p.y = _altura
		escombro.global_position = p
		var altura_techo := techo.to_global(Vector3.DOWN * techo.size.y * 0.5).y if is_instance_valid(techo) else _altura + 5.8
		escombro.preparar(altura_techo - _altura, _azar, Vector2(espacio.size) * GrafoPiso.TAMANO_CELDA - Vector2.ONE * 0.04)
		if _cajon_bajo_derrumbe(espacio):
			# La marca se proyecta sobre el cajón, donde se puede ver desde arriba.
			escombro._aviso.position.y = 0.94
		escombros.append(escombro)


func _actualizar_escombros(delta: float) -> void:
	for escombro in escombros:
		if not escombro.avanzar(delta):
			continue
		for celda in escombro.celdas:
			if _bloqueos.has(celda):
				var cajon := _bloqueos[celda] as StaticBody3D
				cajon.call("desactivar")
				caidos.append(cajon)
				_bloqueos.erase(celda)
				_grafo.bloqueos_temporales.erase(celda)
			_grafo.escombros[celda] = true
		_grafo.construir_adyacencia()
		# El aviso permite apartarse; si se entra justo al impactar, sacar al
		# personaje del volumen sólido antes del siguiente movimiento físico.
		var pies := Vector2(_jugador.global_position.x, _jugador.global_position.z)
		if not _jugador.en_relevo and escombro.huella().grow(0.32).has_point(pies):
			_ultimo_apoyo = _apoyo_conectado(_jugador.global_position)
			_devolver_a_tierra()
		escombros_actualizados.emit()


func _limpiar_trazado() -> void:
	_retirar_aviso_gigante()
	for grieta in _trazado:
		grieta.free()
	_trazado.clear()
	grieta_gigante = null
	_celdas_caidas.clear()
	_celdas_rotas.clear()
	_reservas_escombros.clear()


func _elegir_grieta(indice: int, origen: Vector2i, destinos: Array[Vector2i], ensayo: AStarGrid2D, escala_general: float = 1.0) -> bool:
	var zona := ZONA_MESAS if indice < 6 else ZONA_SISMO
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
				var celda: Vector2i = candidatas.pop_at(_azar.randi_range(0, candidatas.size() - 1))
				if _celdas_rotas.has(celda) or origen == celda or destinos.has(celda):
					continue
				var p := _grafo.celda_a_posicion(celda)
				var centro := Vector2(p.x + _azar.randf_range(-0.17, 0.17), p.z + _azar.randf_range(-0.17, 0.17))
				var candidata := Grieta.new()
				candidata.trazar(centro, LARGOS[indice] * escala * escala_general, ANCHOS[indice], _azar.randf_range(-PI, PI), _azar)
				if zona.encloses(candidata.limites) and _validar_trazado(candidata, origen, destinos, ensayo):
					candidata.saltable = indice > 0
					_trazado.append(candidata)
					return true
				candidata.free()
	return false


func _validar_trazado(candidata: Grieta, origen: Vector2i, destinos: Array[Vector2i], ensayo: AStarGrid2D, avisar_bajo_jugador: bool = false) -> bool:
	var p := _jugador.global_position
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
	var en_grieta := not _jugador.en_relevo and not _jugador.is_on_floor() and _jugador.velocity.y < 0.0 and atrapo_hoja(_jugador.global_position)
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
	if _jugador.en_relevo:
		# El director reserva las grietas/derrumbes para los dos actores.
		_actualizar_escombros(delta)
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
	_actualizar_escombros(delta)
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
	# Descanso también se fractura: el aviso y la cámara se sienten en toda la oficina.
	return 1.0 if _grafo.es_celda_valida(_grafo.posicion_a_celda(_jugador.global_position)) else 0.0


func _devolver_a_tierra() -> void:
	_solto_gravilla = false
	_jugador_en_grieta = false
	if _colision_jugador != null:
		_colision_jugador.set_deferred("disabled", false)
	if not _grafo.es_transitable(_grafo.posicion_a_celda(_ultimo_apoyo)):
		_ultimo_apoyo = _apoyo_conectado(_ultimo_apoyo)
	_jugador.global_position = _ultimo_apoyo + Vector3.UP * 0.04
	_jugador.velocity = Vector3.ZERO
	_jugador.reset_physics_interpolation()


func _apoyo_conectado(cerca: Vector3) -> Vector3:
	var apoyo := _grafo.celda_a_posicion(_origen_seguro)
	var menor_distancia := INF
	for celda: Vector2i in _grafo.celdas_alcanzables(_origen_seguro):
		var p := _grafo.celda_a_posicion(celda)
		var distancia := Vector2(p.x - cerca.x, p.z - cerca.z).length_squared()
		if distancia < menor_distancia:
			menor_distancia = distancia
			apoyo = p
	apoyo.y = _altura
	return apoyo


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
	_limpiar_trazado()
	for escombro in escombros:
		escombro.retirar()
	escombros.clear()
	_grafo.escombros.clear()
	_grafo.grietas.clear()
	_grafo.construir_adyacencia()
	set_physics_process(false)
	sonidos.detener()
	etapa = Etapa.INACTIVO
	terminado.emit()


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
