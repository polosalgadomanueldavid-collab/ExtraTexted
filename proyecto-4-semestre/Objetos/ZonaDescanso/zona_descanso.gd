extends Node3D
## Interacciones locales. Los casos siguen avanzando y los efectos ocurren una sola vez.

enum Estado { LIBRE, PREPARANDO, SENTADO, BEBIENDO }
const AVISO := preload("res://UI/Descanso/aviso_descanso.gd")
const SONIDOS := preload("res://UI/Despacho/sonidos_mesas.gd")
const PREPARAR := preload("res://Audios/Descanso/cafetera_preparar.wav")
const SORBO := preload("res://Audios/Descanso/cafe_beber.wav")
@export var costo_cafe: int = 50
@export var calma_cafe: int = 15
@export var segundos_preparacion: float = 1.8
@export var segundos_descanso: float = 2.0

var estado: Estado = Estado.LIBRE
var taza_en_mano: MeshInstance3D
var _gestor: Node3D
var _jugador: Player
var _despacho: SistemaDespacho
var _aviso: PanelContainer
var _audio: AudioStreamPlayer
var _maquina: AudioStreamPlayer
var _sorbo: AudioStreamPlayer
var _espera_sorbo: float = -1.0
var _tazas: Array[MeshInstance3D] = []
var _origenes: Array[Transform3D] = []
var _siguiente_taza: int = 0
var _tiempo_preparacion: float = 0.0
var _tiempo_descanso: float = 0.0
var _consulta_restante: float = 0.0
var _mensaje: String = ""
var _mensaje_restante: float = 0.0
var _pose_anterior := Transform3D.IDENTITY
var _giro_anterior: float = 0.0
var _capa_anterior: int = 0
var _mascara_anterior: int = 0
var _bloqueo_anterior: bool = false
var _pose_bloqueada: bool = false
var _transicion: Tween
var _entrando: bool = false
var _saliendo: bool = false
var _asiento_activo: bool = false
var _asiento_actual: Marker3D
var _beber_pendiente: bool = false

func _ready() -> void:
	_configurar.call_deferred()

func _configurar() -> void:
	_gestor = get_tree().get_first_node_in_group("gestor_partida") as Node3D
	if _gestor == null or not _gestor.is_ancestor_of(self):
		set_process(false)
		set_process_input(false)
		return
	_jugador = _gestor.get("jugador") as Player
	_despacho = _gestor.get("sistema_despacho") as SistemaDespacho
	if _jugador == null or _despacho == null:
		set_process(false)
		return
	_tazas.assign([$RinconCafe/TazaBlanca, $RinconCafe/TazaAmarilla])
	for taza: MeshInstance3D in _tazas:
		_origenes.append(taza.transform)
		var contenido := MeshInstance3D.new()
		contenido.name = "ContenidoCafe"
		var cilindro := CylinderMesh.new()
		cilindro.top_radius = 0.031
		cilindro.bottom_radius = 0.031
		cilindro.height = 0.002
		cilindro.radial_segments = 16
		contenido.mesh = cilindro
		contenido.position.y = 0.074 if taza.name == "TazaAmarilla" else 0.068
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("422417")
		material.roughness = 0.3
		contenido.material_override = material
		contenido.hide()
		taza.add_child(contenido)
	var capa := CanvasLayer.new()
	capa.name = "InterfazDescanso"
	capa.layer = 35
	add_child(capa)
	_aviso = AVISO.new()
	capa.add_child(_aviso)
	_audio = SONIDOS.crear_reproductor(self, "SonidoServicio", SONIDOS.BIENESTAR, -17.0)
	_maquina = SONIDOS.crear_reproductor(self, "SonidoCafetera", PREPARAR, -14.0)
	_sorbo = SONIDOS.crear_reproductor(self, "SonidoSorbo", SORBO, -12.0)
	_jugador.reset_performed.connect(_al_reiniciar_jugador)
	_despacho.partida_terminada.connect(_al_terminar_partida)

func obtener_estado() -> Dictionary:
	return {"sentado": _asiento_activo and not _entrando, "preparando": estado == Estado.PREPARANDO,
		"tiene_cafe": is_instance_valid(taza_en_mano), "bebiendo": estado == Estado.BEBIENDO,
		"tiempo_descanso": _tiempo_descanso, "tiempo_preparacion": _tiempo_preparacion}

func tiene_cafe() -> bool:
	return is_instance_valid(taza_en_mano)

func mostrar_mensaje(texto: String) -> void:
	_mensaje = texto
	_mensaje_restante = 2.5
	_consulta_restante = 0.0

func _disponible() -> bool:
	return is_instance_valid(_jugador) and is_instance_valid(_despacho) and _despacho.calma_operativa > 0 and not get_tree().paused and not MenuGlobal.capa.visible

func _objetivo_valido(quien: Player, objetivo: Node3D) -> bool:
	if is_instance_valid(quien) and is_instance_valid(quien.control_inundacion) and quien.control_inundacion.activo:
		mostrar_mensaje("Repara las tuberías antes de usar la zona de descanso.")
		return false
	return _disponible() and quien == _jugador and not _jugador.input_locked and not _jugador.realizando_gesto() and _jugador.obtener_objetivo_interaccion() == objetivo

func interactuar_cafetera(quien: Player) -> bool:
	if estado != Estado.LIBRE or not _objetivo_valido(quien, $RinconCafe/MuebleCafe):
		return false
	if tiene_cafe():
		mostrar_mensaje("Primero bebe el café que llevas con F.")
		return false
	if is_instance_valid(_jugador.papel_en_mano):
		mostrar_mensaje("Deja el papel antes de pedir una taza de café.")
		return false
	if _gestor.evento_apagon.estado != 0:
		mostrar_mensaje("Repara la luz para usar la cafetera.")
		return false
	if _despacho.calma_operativa >= _despacho.CALMA_MAXIMA:
		mostrar_mensaje("Tu calma operativa ya está completa.")
		return false
	if _despacho.puntuacion.puntos < costo_cafe:
		mostrar_mensaje("Necesitas %d puntos para pedir café." % costo_cafe)
		return false
	if not _jugador.ejecutar_gesto(&"interactuar", Callable(), $RinconCafe/Cafetera, segundos_preparacion):
		return false
	_bloquear_pose()
	_pose_anterior = _jugador.global_transform
	_tiempo_preparacion = 0.0
	estado = Estado.PREPARANDO
	_maquina.play()
	_mensaje_restante = 0.0
	return true

func _servir_cafe() -> void:
	if not _disponible() or _despacho.calma_operativa >= _despacho.CALMA_MAXIMA or _gestor.evento_apagon.estado != 0 or is_instance_valid(_jugador.papel_en_mano) or _jugador.global_position.distance_to(_pose_anterior.origin) > 0.35:
		_cancelar_preparacion()
		return
	if not _despacho.puntuacion.gastar_puntos(costo_cafe):
		_cancelar_preparacion()
		mostrar_mensaje("No tienes puntos suficientes para este café.")
		return
	taza_en_mano = _tazas[_siguiente_taza]
	_siguiente_taza = (_siguiente_taza + 1) % _tazas.size()
	var anclaje := _jugador.anclaje_taza()
	taza_en_mano.reparent(anclaje, true)
	taza_en_mano.position = Vector3.ZERO
	taza_en_mano.rotation = Vector3.ZERO
	taza_en_mano.scale = Vector3.ONE / anclaje.global_basis.get_scale()
	(taza_en_mano.get_node("ContenidoCafe") as MeshInstance3D).show()
	_jugador.establecer_taza_en_mano(true)
	_jugador.cancelar_gesto()
	_liberar_pose()
	_maquina.stop()
	estado = Estado.LIBRE
	_audio.play()
	_consulta_restante = 0.0

func beber_cafe() -> bool:
	if not _disponible() or not tiene_cafe() or estado in [Estado.PREPARANDO, Estado.BEBIENDO] or _saliendo or _jugador.realizando_gesto():
		return false
	if _entrando:
		_beber_pendiente = true
		return true
	if _jugador.input_locked and not _jugador.esta_sentado():
		return false
	if _gestor.clasificacion_partida.visible:
		return false
	var anterior := estado
	estado = Estado.BEBIENDO
	if not _jugador.ejecutar_gesto(&"beber", _consumir_cafe):
		estado = anterior
		return false
	_espera_sorbo = 0.55 if tiene_cafe() else -1.0
	_mensaje_restante = 0.0
	return true

func _consumir_cafe() -> void:
	if estado != Estado.BEBIENDO or not tiene_cafe() or not is_instance_valid(_despacho) or _despacho.calma_operativa <= 0:
		return
	var recuperada := _despacho.recuperar_calma(calma_cafe)
	_devolver_taza()
	mostrar_mensaje("Café terminado  ·  +%d de calma operativa" % recuperada)
	_audio.play()
	_jugador.reproducir_expresion(&"alegria")

func _devolver_taza() -> void:
	if is_instance_valid(taza_en_mano):
		var indice := _tazas.find(taza_en_mano)
		(taza_en_mano.get_node("ContenidoCafe") as MeshInstance3D).hide()
		taza_en_mano.reparent($RinconCafe, false)
		taza_en_mano.transform = _origenes[indice]
		taza_en_mano = null
	if is_instance_valid(_jugador):
		_jugador.establecer_taza_en_mano(false)

func interactuar_sofa(quien: Player) -> bool:
	if estado != Estado.LIBRE or not _objetivo_valido(quien, $SofaL/Cuerpo):
		return false
	if not _jugador.iniciar_descanso_sentado():
		return false
	_pose_anterior = _jugador.global_transform
	_giro_anterior = _jugador.visual.rotation.y
	_capa_anterior = _jugador.collision_layer
	_mascara_anterior = _jugador.collision_mask
	_bloquear_pose()
	_jugador.collision_layer = 0
	_jugador.collision_mask = 0
	_asiento_activo = true
	var asiento := $SofaL/AsientoTramo as Marker3D
	if _jugador.global_position.distance_squared_to($SofaL/AsientoRetorno.global_position) < _jugador.global_position.distance_squared_to(asiento.global_position):
		asiento = $SofaL/AsientoRetorno
	_asiento_actual = asiento
	var frente := asiento.global_basis.z.normalized()
	_jugador.visual.rotation.y = atan2(frente.x, frente.z)
	_tiempo_descanso = 0.0
	estado = Estado.SENTADO
	_entrando = true
	_transicion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transicion.tween_property(_jugador, "global_position", asiento.global_position, 0.32)
	_transicion.tween_callback(_terminar_entrada)
	return true

func _terminar_entrada() -> void:
	_entrando = false
	if _beber_pendiente:
		_beber_pendiente = false
		beber_cafe()

func levantarse() -> bool:
	if not is_instance_valid(_jugador) or not _jugador.esta_sentado() or _saliendo or get_tree().paused:
		return false
	var salida := _buscar_salida()
	if not salida.is_finite():
		mostrar_mensaje("El paso está ocupado. Intenta levantarte de nuevo.")
		return false
	if is_instance_valid(_transicion):
		_transicion.kill()
	_jugador.cancelar_gesto()
	_sorbo.stop()
	_espera_sorbo = -1.0
	_entrando = false
	_beber_pendiente = false
	_saliendo = true
	estado = Estado.LIBRE
	_transicion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transicion.tween_property(_jugador, "global_position", salida, 0.28)
	_transicion.tween_callback(_terminar_salida)
	return true

func _buscar_salida() -> Vector3:
	if not is_instance_valid(_asiento_actual):
		return Vector3.INF
	var entrada := _pose_anterior.origin
	var centro := _asiento_actual.global_position
	centro.y = entrada.y
	var frente := _asiento_actual.global_basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var lateral := Vector3(frente.z, 0.0, -frente.x)
	var hacia_entrada := (entrada - centro).normalized()
	if hacia_entrada.is_zero_approx():
		hacia_entrada = frente
	var candidatos: Array[Vector3] = [entrada]
	# Empujar el mueble deja un contacto que intersect_shape puede considerar ocupado.
	# Separarse unos centímetros conserva la salida por la que llegó el jugador.
	for separacion: float in [0.03, 0.06, 0.12, 0.2]:
		candidatos.append(entrada + hacia_entrada * separacion)
		candidatos.append(entrada + frente * separacion)
	# Si la entrada se ocupó durante el descanso, solo busca delante del asiento.
	# No usa accesos de navegación lejanos como destino de la animación.
	for avance: float in [0.4, 0.55, 0.7]:
		for desplazamiento: float in [0.0, 0.2, -0.2, 0.4, -0.4]:
			candidatos.append(centro + frente * avance + lateral * desplazamiento)
	var forma := _jugador.get_node("Colision") as CollisionShape3D
	for punto: Vector3 in candidatos:
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		var transformacion := _pose_anterior
		transformacion.origin = punto + Vector3.UP * 0.02
		consulta.transform = transformacion * forma.transform
		consulta.collision_mask = _mascara_anterior
		consulta.margin = _jugador.safe_margin + 0.002
		consulta.exclude = [_jugador.get_rid()]
		if get_world_3d().direct_space_state.intersect_shape(consulta).is_empty():
			return punto
	return Vector3.INF

func _terminar_salida() -> void:
	if is_instance_valid(_jugador):
		# Mantener la física sentada hasta aquí evita gravedad mientras el tween
		# mueve un cuerpo que todavía tiene sus colisiones suspendidas.
		_jugador.terminar_descanso_sentado()
		_jugador.collision_layer = _capa_anterior
		_jugador.collision_mask = _mascara_anterior
		_jugador.visual.rotation.y = _giro_anterior
		_jugador.velocity = Vector3.ZERO
	_saliendo = false
	_asiento_activo = false
	_asiento_actual = null
	_liberar_pose()
	_consulta_restante = 0.0

func _bloquear_pose() -> void:
	_bloqueo_anterior = _jugador.input_locked
	_pose_bloqueada = true
	_jugador.input_locked = true
	_jugador.velocity = Vector3.ZERO

func _liberar_pose() -> void:
	if _pose_bloqueada and is_instance_valid(_jugador):
		_jugador.input_locked = _bloqueo_anterior
	_pose_bloqueada = false

func _cancelar_preparacion() -> void:
	_maquina.stop()
	if is_instance_valid(_jugador):
		_jugador.cancelar_gesto()
	_liberar_pose()
	_tiempo_preparacion = 0.0
	estado = Estado.LIBRE
	mostrar_mensaje("Preparación cancelada  ·  no se cobraron puntos")

func _input(evento: InputEvent) -> void:
	if not _disponible() or evento.is_echo():
		return
	if evento is InputEventKey and evento.pressed:
		var tecla: int = evento.physical_keycode if evento.physical_keycode != 0 else evento.keycode
		if tecla == KEY_F and tiene_cafe():
			get_viewport().set_input_as_handled()
			beber_cafe()
		elif tecla in [KEY_E, KEY_ESCAPE]:
			if _jugador.esta_sentado():
				get_viewport().set_input_as_handled()
				levantarse()
			elif estado == Estado.PREPARANDO and tecla == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_cancelar_preparacion()

func _process(delta: float) -> void:
	if not is_instance_valid(_jugador) or not is_instance_valid(_despacho):
		return
	if _mensaje_restante > 0.0:
		_mensaje_restante = maxf(0.0, _mensaje_restante - delta)
	if _despacho.calma_operativa <= 0:
		return
	if estado == Estado.PREPARANDO:
		_tiempo_preparacion += delta
		if _tiempo_preparacion >= segundos_preparacion:
			_servir_cafe()
	elif estado == Estado.BEBIENDO and not _jugador.realizando_gesto():
		_sorbo.stop()
		_espera_sorbo = -1.0
		estado = Estado.SENTADO if _jugador.esta_sentado() else Estado.LIBRE
	if estado == Estado.BEBIENDO and _espera_sorbo >= 0.0:
		_espera_sorbo -= delta
		if _espera_sorbo < 0.0:
			_sorbo.play()
	if _jugador.esta_sentado() and estado == Estado.SENTADO and not _entrando:
		if _despacho.calma_operativa < _despacho.CALMA_MAXIMA:
			_tiempo_descanso += delta
			if _tiempo_descanso >= segundos_descanso:
				_tiempo_descanso = fmod(_tiempo_descanso, segundos_descanso)
				_despacho.recuperar_calma(1)
		else:
			_tiempo_descanso = 0.0
	_consulta_restante -= delta
	if _consulta_restante <= 0.0:
		_consulta_restante = 0.1
		_actualizar_aviso()

func _actualizar_aviso() -> void:
	if not is_instance_valid(_aviso):
		return
	if not _disponible() or _gestor.evento_apagon.estado == 2 or _gestor.clasificacion_partida.visible:
		_aviso.hide()
		return
	var titulo := ""
	var detalle := ""
	var progreso := -1.0
	if estado == Estado.PREPARANDO:
		titulo = "PREPARANDO CAFÉ"
		detalle = "%d puntos al recibir la taza  ·  Esc cancelar" % costo_cafe
		progreso = _tiempo_preparacion / segundos_preparacion
	elif estado == Estado.BEBIENDO:
		titulo = "BEBIENDO CAFÉ"
		detalle = "Recuperas calma al tomarlo."
	elif _jugador.esta_sentado():
		titulo = "DESCANSANDO  ·  [E] LEVANTARSE"
		detalle = "+1 calma cada 2 s  ·  los casos siguen corriendo"
		if tiene_cafe():
			detalle = "[F] Beber café  ·  +1 calma cada 2 s al descansar"
		if _mensaje_restante > 0.0:
			detalle = _mensaje
		progreso = _tiempo_descanso / segundos_descanso
	elif _mensaje_restante > 0.0:
		titulo = "ZONA DE DESCANSO"
		detalle = _mensaje
	elif tiene_cafe():
		titulo = "CAFÉ LISTO  ·  [F] BEBER"
		detalle = "+%d de calma operativa al beberlo" % calma_cafe
	else:
		var objetivo := _jugador.obtener_objetivo_interaccion()
		if objetivo == $RinconCafe/MuebleCafe:
			titulo = "[E] PEDIR CAFÉ  ·  %d PTS" % costo_cafe
			detalle = "+%d de calma operativa al beberlo" % calma_cafe
		elif objetivo == $SofaL/Cuerpo:
			titulo = "[E] SENTARSE Y RELAJARSE"
			detalle = "+1 de calma cada 2 segundos"
	if titulo.is_empty():
		_aviso.hide()
	else:
		_aviso.presentar(titulo, detalle, progreso)
		var margen := 12.0 * _aviso.scale.y
		var limite := get_viewport().get_visible_rect().size.y - margen
		var papel: Control = _gestor.get("indicador_papel")
		var apagon: Control = _gestor.get("_aviso_apagon")
		for otro: Control in [papel, apagon]:
			if is_instance_valid(otro) and otro.is_visible_in_tree():
				limite = minf(limite, otro.global_position.y - margen)
		_aviso.position.y = minf(_aviso.position.y, limite - _aviso.size.y * _aviso.scale.y)

func _al_reiniciar_jugador() -> void:
	_limpiar_interaccion(false)

func _al_terminar_partida() -> void:
	_limpiar_interaccion(true)

func _limpiar_interaccion(restaurar_posicion: bool) -> void:
	_maquina.stop()
	_sorbo.stop()
	_espera_sorbo = -1.0
	if is_instance_valid(_transicion):
		_transicion.kill()
	if is_instance_valid(_jugador):
		var estaba_sentado := _asiento_activo
		_jugador.cancelar_gesto()
		_jugador.terminar_descanso_sentado(true)
		if estaba_sentado:
			if restaurar_posicion:
				_jugador.global_transform = _pose_anterior
			_jugador.collision_layer = _capa_anterior
			_jugador.collision_mask = _mascara_anterior
		_liberar_pose()
	_devolver_taza()
	estado = Estado.LIBRE
	_entrando = false
	_saliendo = false
	_asiento_activo = false
	_asiento_actual = null
	_beber_pendiente = false
	_tiempo_descanso = 0.0
	_tiempo_preparacion = 0.0
	_mensaje = ""
	_mensaje_restante = 0.0
	_consulta_restante = 0.0
	if is_instance_valid(_aviso):
		_aviso.hide()

func _exit_tree() -> void:
	if is_instance_valid(_transicion):
		_transicion.kill()
	if is_instance_valid(_jugador):
		if _asiento_activo:
			_jugador.global_transform = _pose_anterior
			_jugador.collision_layer = _capa_anterior
			_jugador.collision_mask = _mascara_anterior
		_jugador.cancelar_gesto()
		_jugador.terminar_descanso_sentado(true)
		_jugador.establecer_taza_en_mano(false)
		_liberar_pose()
	if is_instance_valid(taza_en_mano):
		taza_en_mano.queue_free()
	if is_instance_valid(_audio):
		_audio.stop()
	if is_instance_valid(_maquina):
		_maquina.stop()
	if is_instance_valid(_sorbo):
		_sorbo.stop()
