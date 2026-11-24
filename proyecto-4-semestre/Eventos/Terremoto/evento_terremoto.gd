extends Node3D

const ResolucionAvatar := preload("res://Objetos/ZonaDescanso/resolucion_avatar.gd")
var _resolucion_avatar: Node3D
var _restos_avatar: Array[Dictionary] = []
var _alfombra_avatar := Transform3D.IDENTITY
var resolviendo_avatar: bool:
	get: return is_instance_valid(_resolucion_avatar)


signal preparacion_iniciada
signal preparacion_terminada(correcta: bool)
signal iniciado
signal temblor_actualizado(tiempo: float, intensidad: float)
signal suelo_roto
signal escombros_actualizados
signal jugador_caido(jugador: Player)
signal terminado

enum Etapa { INACTIVO, AVISO, RUPTURA, RECUPERACION }

const Planificador := preload("res://Eventos/Terremoto/planificador_terremoto.gd")
const Presupuesto := preload("res://Eventos/Terremoto/presupuesto_preparacion.gd")
const Grieta := preload("res://Eventos/Terremoto/grieta.gd")
const Escombro := preload("res://Eventos/Terremoto/escombro.gd")
const SonidosEventos := preload("res://Eventos/sonidos_eventos.gd")
const SEGUNDOS_POR_ETAPA := 8.0
const DURACION := 3.0 * SEGUNDOS_POR_ETAPA
const TIEMPO_CIERRE := 0.60
const ANCHO_PISO := 7.0
const LARGO_PISO := 12.5
const RESOLUCION_MASCARA := 32
const ANCHOS: Array[float] = Planificador.ANCHOS
const LARGOS: Array[float] = Planificador.LARGOS

@export var suelo: CSGBox3D
@export var techo: CSGBox3D
@export var alfombra: Node3D

var permiso_inicio: Callable
var permiso_aplicar: Callable
var actualizar_contexto: Callable
var preparando := false
var plan_preparado := false
var rechazo_preparacion := ""
var _esperar_autorizacion := false
var _presupuesto: Presupuesto
var _plan: Dictionary = {}
var _base_transitable: Array[bool] = []
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
var posiciones_red: Array[Vector3] = []
var hojas_red: Array[Vector3] = []
var _estado_escombros_red: int = 0
var _espacios_red: Array[Rect2i] = []
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
var _animacion_alfombra: Tween
var _reposo_alfombra: Transform3D
var _alfombra_caida := false


func _ready() -> void:
	var material := suelo.material as ShaderMaterial
	if material != null:
		_material_piso = material.duplicate() as ShaderMaterial
		suelo.material = _material_piso
	sonidos = SonidosEventos.new()
	add_child(sonidos)
	_altura = suelo.to_global(Vector3.UP * suelo.size.y * 0.5).y
	set_physics_process(false)


## Devuelve aceptación de la solicitud. El resultado se entrega en preparacion_terminada.
func iniciar(grafo: GrafoPiso, jugador: Player, bloqueos: Dictionary, huella_hoja: Rect2, esperar_autorizacion := false) -> bool:
	if permiso_inicio.is_valid() and not permiso_inicio.call():
		return false
	if activo or preparando or get_tree().paused or not grafo.es_celda_valida(grafo.posicion_a_celda(jugador.global_position)):
		return false
	_grafo = grafo
	_jugador = jugador
	_colision_jugador = jugador.get_node_or_null("Colision") as CollisionShape3D
	_bloqueos = bloqueos
	_huella_hoja = huella_hoja
	_esperar_autorizacion = esperar_autorizacion
	tiempo = 0.0
	rechazo_preparacion = ""
	preparando = true
	plan_preparado = false
	_presupuesto = Presupuesto.new()
	_presupuesto.arbol = get_tree()
	preparacion_iniciada.emit()
	_preparar_plan.call_deferred()
	return true


func _capturar_transitables() -> Array[bool]:
	var celdas: Array[bool] = []
	for fila in range(GrafoPiso.FILAS):
		for columna in range(GrafoPiso.COLUMNAS):
			celdas.append(_grafo.es_transitable(Vector2i(columna, fila)))
	return celdas


func _refrescar_contexto() -> void:
	if actualizar_contexto.is_valid():
		actualizar_contexto.call()


func _preparar_plan() -> void:
	await _presupuesto.paso()
	if _presupuesto.cancelado:
		_fallar_preparacion()
		return
	# Si alguien se mueve sobre el plan durante el montaje, descartar y volver
	# a planificar con posiciones actuales, sin iniciar avisos ni reloj.
	for intento_actualizacion in range(3):
		_refrescar_contexto()
		_base_transitable = _capturar_transitables()
		var planificador := Planificador.new()
		planificador.presupuesto = _presupuesto
		var copia := GrafoPiso.new()
		copia.bloqueos_fijos = _grafo.bloqueos_fijos.duplicate()
		copia.bloqueos_mesas = _grafo.bloqueos_mesas.duplicate()
		copia.bloqueos_temporales = _grafo.bloqueos_temporales.duplicate()
		copia.grietas.assign(_grafo.grietas)
		copia.escombros.assign(_grafo.escombros)
		copia.adyacencia = _grafo.adyacencia.duplicate(true)
		planificador._grafo = copia
		planificador._posicion_jugador = _jugador.global_position
		for celda: Vector2i in _bloqueos:
			planificador._bloqueos[celda] = true
		planificador._huella_hoja = _huella_hoja
		planificador.posiciones_red.assign(posiciones_red)
		planificador.hojas_red.assign(hojas_red)
		planificador._azar.state = _azar.state
		for acceso: Node3D in get_tree().get_nodes_in_group("accesos_navegacion"):
			planificador.accesos.append(acceso.global_position)
		var datos: Dictionary = await planificador.planificar()
		_azar.state = planificador._azar.state
		if _presupuesto.cancelado or datos.is_empty():
			rechazo_preparacion = "cancelado" if _presupuesto.cancelado else "sin distribución válida"
			break
		_plan = datos
		await _presupuesto.paso(2500)
		if _presupuesto.cancelado: break
		if not validar_plan_actual():
			continue
		await _montar_plan()
		if _presupuesto.cancelado:
			break
		await _presupuesto.paso(2500)
		if _presupuesto.cancelado: break
		if validar_plan_actual():
			plan_preparado = true
			if not _esperar_autorizacion and not autorizar_plan(false):
				_fallar_preparacion()
				return
			preparacion_terminada.emit(true)
			return
		_limpiar_preparacion_visual()
	_fallar_preparacion()


func validar_plan_actual() -> bool:
	_refrescar_contexto()
	if _plan.is_empty() or _presupuesto.cancelado or get_tree().paused or not is_instance_valid(_jugador):
		return _rechazar_plan("estado de preparación")
	if permiso_aplicar.is_valid() and not permiso_aplicar.call():
		return _rechazar_plan("permiso de aplicación")
	if _capturar_transitables() != _base_transitable:
		return _rechazar_plan("ocupación del grafo")
	var formas: Array = _plan.formas
	for i in range(formas.size()):
		var forma := preload("res://Eventos/Terremoto/forma_grieta.gd").new()
		var datos: Dictionary = formas[i]
		forma.centro = datos.centro
		forma.contorno = datos.contorno
		forma.limites = datos.limites
		if _huella_hoja.has_area() and forma.limites.intersects(_huella_hoja):
			return _rechazar_plan("hoja local en grieta")
		for hoja: Vector3 in hojas_red:
			if forma.toca_cuadro(Vector2(hoja.x, hoja.z), 0.35): return _rechazar_plan("hoja LAN en grieta")
		if i != int(_plan.gigante):
			for punto: Vector3 in posiciones_red + [_jugador.global_position]:
				if forma.toca_cuadro(Vector2(punto.x, punto.z), 0.32): return _rechazar_plan("jugador en grieta")
	var ensayo := AStarGrid2D.new()
	ensayo.region = Rect2i(0, 0, GrafoPiso.COLUMNAS, GrafoPiso.FILAS)
	ensayo.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	ensayo.update()
	for fila in range(GrafoPiso.FILAS):
		for columna in range(GrafoPiso.COLUMNAS):
			var celda := Vector2i(columna, fila)
			ensayo.set_point_solid(celda, (not _grafo.es_transitable(celda) and not _plan.caidas.has(celda)) or _plan.rotas.has(celda))
	for espacio: Rect2i in _plan.espacios:
		var p := _grafo.celda_a_posicion(espacio.position)
		var medidas := Vector2(espacio.size) * GrafoPiso.TAMANO_CELDA - Vector2.ONE * 0.04
		var centro := Vector2(p.x, p.z) + Vector2(espacio.size - Vector2i.ONE) * GrafoPiso.TAMANO_CELDA * 0.5
		var huella := Rect2(centro - medidas * 0.5, medidas)
		if huella.grow(0.32).has_point(Vector2(_jugador.global_position.x, _jugador.global_position.z)): return _rechazar_plan("jugador local bajo derrumbe")
		if _huella_hoja.has_area() and huella.grow(0.12).intersects(_huella_hoja): return _rechazar_plan("hoja local bajo derrumbe")
		for punto: Vector3 in posiciones_red + hojas_red:
			if huella.grow(0.35).has_point(Vector2(punto.x, punto.z)): return _rechazar_plan("jugador u hoja LAN bajo derrumbe")
		for celda in _celdas_del_espacio(espacio):
			ensayo.set_point_solid(celda)
	var origen: Vector2i = _plan.origen
	var alcanzables := _grafo.celdas_alcanzables(origen)
	var destinos := GrafoPiso.DESTINOS.values()
	for acceso: Node3D in get_tree().get_nodes_in_group("accesos_navegacion"):
		destinos.append(_grafo.posicion_a_celda(acceso.global_position))
	for punto: Vector3 in posiciones_red + [_jugador.global_position]:
		if not _grafo.es_celda_valida(_grafo.posicion_a_celda(punto)): return _rechazar_plan("jugador fuera del grafo")
		var acceso := _grafo.celda_de_acceso(punto)
		# La gigante puede abrirse bajo los pies tras los ocho segundos de aviso.
		if not _plan.rotas.has(acceso): destinos.append(acceso)
	# Un recorrido comprueba todos los destinos de una vez y evita repetir
	# búsquedas AStar durante la validación atómica justo antes de autorizar.
	var conectadas: Dictionary[Vector2i, bool] = {}
	var pendientes: Array[Vector2i] = []
	if not ensayo.is_point_solid(origen):
		conectadas[origen] = true
		pendientes.append(origen)
	var indice := 0
	while indice < pendientes.size():
		var celda := pendientes[indice]
		indice += 1
		for direccion in GrafoPiso.DIRECCIONES:
			var vecina := celda + direccion
			if _grafo.es_celda_valida(vecina) and not conectadas.has(vecina) and not ensayo.is_point_solid(vecina):
				conectadas[vecina] = true
				pendientes.append(vecina)
	for destino: Vector2i in destinos:
		if alcanzables.has(destino) and not conectadas.has(destino): return _rechazar_plan("acceso desconectado")
	return true


func _rechazar_plan(motivo: String) -> bool:
	rechazo_preparacion = motivo
	return false


func _montar_plan() -> void:
	_origen_seguro = _plan.origen
	_celdas_rotas.assign(_plan.rotas)
	_reservas_escombros.assign(_plan.reservas)
	for forma: Dictionary in _plan.formas:
		await _presupuesto.paso()
		if _presupuesto.cancelado: return
		var grieta := Grieta.new()
		grieta.cargar_forma(forma)
		_trazado.append(grieta)
		add_child(grieta)
	grieta_gigante = _trazado[int(_plan.gigante)]
	for celda: Vector2i in _plan.caidas:
		_celdas_caidas[celda] = _trazado[int(_plan.caidas[celda])]
	_estado_escombros_red = int(_plan.azar_escombros)
	_espacios_red.assign(_plan.espacios)
	var azar_visual := RandomNumberGenerator.new()
	azar_visual.state = _estado_escombros_red
	await _preparar_escombros(_espacios_red, azar_visual)


func autorizar_plan(validar := true) -> bool:
	if not preparando or not plan_preparado or (validar and not validar_plan_actual()):
		return false
	preparando = false
	plan_preparado = false
	_mostrar_aviso_gigante()
	etapa = Etapa.AVISO
	tiempo = 0.0
	_cerrando = false
	_jugador_en_grieta = false
	set_physics_process(true)
	sonidos.iniciar_terremoto()
	iniciado.emit()
	return true


func cancelar_preparacion() -> void:
	if not preparando: return
	_presupuesto.cancelado = true
	if plan_preparado:
		_fallar_preparacion()


func _limpiar_preparacion_visual() -> void:
	_limpiar_trazado()
	for escombro in escombros:
		escombro.hide()
		escombro.queue_free()
	escombros.clear()


func _fallar_preparacion() -> void:
	_limpiar_preparacion_visual()
	_plan.clear()
	preparando = false
	plan_preparado = false
	preparacion_terminada.emit(false)


func _exit_tree() -> void:
	if _presupuesto != null: _presupuesto.cancelado = true


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
	_hundir_alfombra()
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


func _hundir_alfombra() -> void:
	if not is_instance_valid(alfombra) or not alfombra.visible or _alfombra_caida:
		return
	_reposo_alfombra = alfombra.transform
	_alfombra_caida = true
	# Mismo vuelco y aceleración que los bloqueos al perder el apoyo.
	var hacia := Vector3(grieta_gigante.centro.x - alfombra.global_position.x, 0,
		grieta_gigante.centro.y - alfombra.global_position.z)
	var eje := Vector3.UP.cross(hacia.normalized())
	if eje.is_zero_approx():
		eje = Vector3.RIGHT
	var vuelco := alfombra.global_transform
	vuelco.basis = vuelco.basis.rotated(eje, 1.22)
	vuelco.origin += hacia.limit_length(0.65) + Vector3.DOWN * 1.8
	_animacion_alfombra = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_animacion_alfombra.tween_property(alfombra, "global_transform", vuelco, 0.72)
	_animacion_alfombra.tween_callback(alfombra.hide)


func _restaurar_alfombra() -> void:
	if _animacion_alfombra != null:
		_animacion_alfombra.kill()
		_animacion_alfombra = null
	if _alfombra_caida and is_instance_valid(alfombra):
		alfombra.transform = _reposo_alfombra
		alfombra.show()
	_alfombra_caida = false


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


func _celdas_del_espacio(espacio: Rect2i) -> Array[Vector2i]:
	var celdas: Array[Vector2i] = []
	for z in range(espacio.position.y, espacio.end.y):
		for x in range(espacio.position.x, espacio.end.x):
			celdas.append(Vector2i(x, z))
	return celdas


func _cajon_bajo_derrumbe(espacio: Rect2i) -> bool:
	return espacio.size == Vector2i.ONE and _bloqueos.has(espacio.position) and not _celdas_caidas.has(espacio.position)


func _preparar_escombros(espacios: Array[Rect2i], azar_visual: RandomNumberGenerator) -> void:
	for espacio in espacios:
		await _presupuesto.paso()
		if _presupuesto.cancelado: return
		var escombro := Escombro.new()
		escombros.append(escombro)
		escombro.celda = espacio.position
		escombro.celdas = _celdas_del_espacio(espacio)
		add_child(escombro)
		var p := _grafo.celda_a_posicion(espacio.position)
		p += Vector3(espacio.size.x - 1, 0, espacio.size.y - 1) * GrafoPiso.TAMANO_CELDA * 0.5
		p.y = _altura
		escombro.global_position = p
		var altura_techo := techo.to_global(Vector3.DOWN * techo.size.y * 0.5).y if is_instance_valid(techo) else _altura + 5.8
		await escombro.preparar(altura_techo - _altura, azar_visual, Vector2(espacio.size) * GrafoPiso.TAMANO_CELDA - Vector2.ONE * 0.04, _presupuesto)
		if _presupuesto.cancelado: return
		if _cajon_bajo_derrumbe(espacio):
			# La marca se proyecta sobre el cajón, donde se puede ver desde arriba.
			escombro._aviso.position.y = 0.94


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
		if grieta.is_inside_tree():
			grieta.queue_free()
		else:
			grieta.free()
	_trazado.clear()
	grieta_gigante = null
	_celdas_caidas.clear()
	_celdas_rotas.clear()
	_reservas_escombros.clear()


func atrapo_hoja(posicion: Vector3) -> bool:
	if not activo or posicion.y >= _altura - 0.025:
		return false
	for grieta in grietas:
		if grieta.contiene(Vector2(posicion.x, posicion.z)):
			return true
	return false


func _physics_process(delta: float) -> void:
	if resolviendo_avatar:
		return
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
	if preparando:
		cancelar_preparacion()
		return
	_cancelar_resolucion_avatar()
	if _colision_jugador != null:
		_colision_jugador.set_deferred("disabled", false)
	if _material_piso != null:
		_material_piso.set_shader_parameter("usar_mascara_huecos", false)
	if _jugador.global_position.y < _altura - 0.025:
		_devolver_a_tierra()
	for grieta in grietas:
		grieta.cerrar()
	grietas.clear()
	_plan.clear()
	_restaurar_alfombra()
	_limpiar_trazado()
	for escombro in escombros:
		escombro.retirar()
	escombros.clear()
	_restos_avatar.clear()
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
		if grieta.sellada_avatar:
			continue
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


## Un origen inicia la transición del objeto; sin origen, limpieza inmediata de reinicio/red.
func resolver_con_avatar(origen: Variant = null) -> void:
	if not activo:
		return
	if origen is Vector3:
		if resolviendo_avatar:
			return
		_cerrando = true
		_retirar_aviso_gigante()
		_restos_avatar.clear()
		for escombro in escombros:
			escombro._aviso.hide()
			_restos_avatar.append({"nodo": escombro._restos, "cuerpo": escombro, "pose": escombro._restos.transform})
		if _animacion_alfombra != null:
			_animacion_alfombra.kill()
			_animacion_alfombra = null
		if _alfombra_caida and is_instance_valid(alfombra):
			_alfombra_avatar = alfombra.transform
			alfombra.show()
		temblor_actualizado.emit(DURACION, 0.0)
		sonidos.cerrar_suelo()
		_resolucion_avatar = ResolucionAvatar.crear(self, origen, &"tierra", _avanzar_avatar, resolver_con_avatar)
		var polvo := PackedVector3Array()
		for grieta in grietas:
			for i in range(0, grieta.contorno.size(), maxi(1, grieta.contorno.size() / 3)):
				var borde: Vector2 = grieta.contorno[i]
				polvo.append(Vector3(borde.x, _altura + .03, borde.y))
		_resolucion_avatar.preparar_residuos(polvo)
		return
	temblor_actualizado.emit(DURACION, 0.0)
	_cerrar()

func _avanzar_avatar(frente: Node3D) -> void:
	var selladas := false
	for grieta in grietas:
		var peso: float = frente.peso_en(Vector3(grieta.centro.x, _altura, grieta.centro.y))
		if grieta.reconstruir_avatar(peso):
			selladas = true
	if selladas:
		_actualizar_mascara_huecos()
	for dato in _restos_avatar:
		if is_instance_valid(dato.nodo):
			var peso: float = frente.peso_en(dato.nodo.global_position)
			var pose: Transform3D = dato.pose
			# Se recogen bajo el suelo conservando su volumen, sin encogerse en el aire.
			pose.origin.y -= smoothstep(.15, .95, peso) * (maxf(0.0, pose.origin.y) + .75)
			dato.nodo.transform = pose
			if peso > .65:
				dato.cuerpo.set_deferred("collision_layer", 0)
	if _alfombra_caida and is_instance_valid(alfombra):
		alfombra.transform = _alfombra_avatar.interpolate_with(_reposo_alfombra, frente.peso_en(alfombra.global_position))


func exportar_trazado_red() -> Dictionary:
	return _plan.duplicate(true)


func importar_trazado_red(datos: Dictionary, grafo: GrafoPiso, jugador: Player, bloqueos: Dictionary) -> bool:
	if activo or preparando or datos.is_empty(): return false
	_grafo = grafo
	_jugador = jugador
	_colision_jugador = jugador.get_node_or_null("Colision") as CollisionShape3D
	_bloqueos = bloqueos
	_plan = datos.duplicate(true)
	_base_transitable = _capturar_transitables()
	tiempo = 0.0
	rechazo_preparacion = ""
	preparando = true
	plan_preparado = false
	_esperar_autorizacion = true
	_presupuesto = Presupuesto.new()
	_presupuesto.arbol = get_tree()
	preparacion_iniciada.emit()
	_montar_importado.call_deferred()
	return true


func _montar_importado() -> void:
	# Los clientes montan exclusivamente el plan autorizado, sin sortearlo otra vez.
	await _montar_plan()
	if _presupuesto.cancelado:
		_fallar_preparacion()
		return
	plan_preparado = true
	preparacion_terminada.emit(true)


func _cancelar_resolucion_avatar() -> void:
	if is_instance_valid(_resolucion_avatar):
		_resolucion_avatar.cancelar()
	_resolucion_avatar = null
