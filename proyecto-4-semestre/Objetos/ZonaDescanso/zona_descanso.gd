extends Node3D
## Interacciones locales. Los casos siguen avanzando y los efectos ocurren una sola vez.

enum Estado { LIBRE, PREPARANDO, SENTADO, BEBIENDO, CAFE_LISTO }
const PANEL_CAFETERA := preload("res://UI/Descanso/panel_cafetera.gd")
const AVISO := preload("res://UI/Descanso/aviso_descanso.gd")
const SONIDOS := preload("res://UI/Despacho/sonidos_mesas.gd")
const PREPARAR := preload("res://Audios/Descanso/cafetera_preparar.wav")
const SORBO := preload("res://Audios/Descanso/cafe_beber.wav")
const CONTENIDO_CAFE := preload("res://Objetos/ZonaDescanso/contenido_cafe.gd")
@export var costo_cafe: int = 50
@export var calma_cafe: int = 15
@export var segundos_preparacion: float = 1.8
@export var segundos_descanso: float = 2.0

var estado: Estado = Estado.LIBRE
var taza_en_mano: MeshInstance3D
var _gestor: Node3D
var _jugador: Player
var _pago_red_pendiente := false
var _consumo_cafe_pendiente := false
var _devolver_al_terminar := false
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
var panel_cafetera: Control

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
		var contenido := CONTENIDO_CAFE.crear(taza.name == "TazaAmarilla")
		contenido.hide()
		taza.add_child(contenido)
	var capa := CanvasLayer.new()
	capa.name = "InterfazDescanso"
	capa.layer = 35
	add_child(capa)
	_aviso = AVISO.new()
	capa.add_child(_aviso)
	panel_cafetera = PANEL_CAFETERA.new()
	capa.add_child(panel_cafetera)
	panel_cafetera.servir_solicitado.connect(preparar_cafe)
	panel_cafetera.recoger_solicitado.connect(recoger_cafe)
	panel_cafetera.cerrar_solicitado.connect(cerrar_cafetera)
	_audio = SONIDOS.crear_reproductor(self, "SonidoServicio", SONIDOS.BIENESTAR, -17.0)
	_maquina = SONIDOS.crear_reproductor(self, "SonidoCafetera", PREPARAR, -14.0)
	_sorbo = SONIDOS.crear_reproductor(self, "SonidoSorbo", SORBO, -12.0)
	_jugador.reset_performed.connect(_al_reiniciar_jugador)
	_despacho.partida_terminada.connect(_al_terminar_partida)
	_gestor.evento_apagon.estado_cambiado.connect(func(nuevo_estado: int) -> void:
		if nuevo_estado != 0:
			cerrar_cafetera()
	)

func obtener_estado() -> Dictionary:
	return {"sentado": _asiento_activo and not _entrando, "preparando": estado == Estado.PREPARANDO,
		"tiene_cafe": tiene_cafe(), "bebiendo": estado == Estado.BEBIENDO,
		"tiempo_descanso": _tiempo_descanso, "tiempo_preparacion": _tiempo_preparacion,
		"cafetera_abierta": is_instance_valid(panel_cafetera) and panel_cafetera.visible,
		"cafe_listo": estado == Estado.CAFE_LISTO}

func tiene_cafe() -> bool:
	return is_instance_valid(taza_en_mano) and not _devolver_al_terminar

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

func impedimento_cafe() -> String:
	var espera: int = _gestor.espera_compra("cafe", _despacho.jugador_local_id)
	if espera > 0:
		return "Tu próximo café en %d s" % espera
	if tiene_cafe():
		return "Primero bebe el café que llevas con F."
	if is_instance_valid(_jugador.papel_en_mano):
		return "Deja el papel antes de pedir una taza de café."
	if _gestor.evento_apagon.estado != 0:
		return "Repara la luz para usar la cafetera."
	if _despacho.calma_operativa >= _despacho.CALMA_MAXIMA:
		return "Tu calma operativa ya está completa."
	if _despacho.puntuacion.puntos < costo_cafe:
		return "Necesitas %d puntos para pedir café." % costo_cafe
	return ""

func interactuar_cafetera(quien: Player) -> bool:
	if _pago_red_pendiente or estado != Estado.LIBRE or not _objetivo_valido(quien, $RinconCafe/MuebleCafe):
		return false
	var motivo := impedimento_cafe()
	if not motivo.is_empty():
		mostrar_mensaje(motivo)
		return false
	if SesionLAN.en_partida and not SesionLAN.puente.reservar_confirmada("cafetera"):
		SesionLAN.puente.reservar_local("cafetera", func():
			if not interactuar_cafetera(quien): SesionLAN.puente.liberar_local("cafetera")
		)
		return true
	_jugador.cerrar_menu_emotes(true)
	_bloquear_pose()
	_pose_anterior = _jugador.global_transform
	panel_cafetera.abrir(costo_cafe, _tazas[_siguiente_taza])
	_aviso.hide()
	_mensaje_restante = 0.0
	return true

func _cafetera_valida() -> bool:
	return _disponible() and not _despacho.terminada and not _gestor.clasificacion_partida.visible and _gestor.evento_apagon.estado == 0 and not is_instance_valid(_jugador.papel_en_mano) and _jugador.global_position.distance_to(_pose_anterior.origin) <= 0.35 and not _jugador.nadando

func preparar_cafe() -> bool:
	if not panel_cafetera.visible or estado != Estado.LIBRE or not _cafetera_valida():
		return false
	if _despacho.calma_operativa >= _despacho.CALMA_MAXIMA:
		panel_cafetera.mostrar_error("CALMA LLENA")
		return false
	if _despacho.puntuacion.puntos < costo_cafe:
		panel_cafetera.mostrar_error("SIN SALDO")
		return false
	_tiempo_preparacion = 0.0
	estado = Estado.PREPARANDO
	_maquina.play()
	panel_cafetera.preparando()
	return true

func _servir_cafe() -> void:
	if not _cafetera_valida() or _despacho.calma_operativa >= _despacho.CALMA_MAXIMA:
		cerrar_cafetera()
		return
	_maquina.stop()
	estado = Estado.CAFE_LISTO
	panel_cafetera.lista()

func recoger_cafe() -> bool:
	if _pago_red_pendiente:
		return false
	if not panel_cafetera.visible or estado != Estado.CAFE_LISTO or not _cafetera_valida():
		return false
	if _despacho.calma_operativa >= _despacho.CALMA_MAXIMA:
		cerrar_cafetera()
		return false
	if SesionLAN.en_partida:
		_pago_red_pendiente = true
		SesionLAN.solicitar("comprar", {"producto": "cafe", "indice": _siguiente_taza}, func(resultado: Dictionary):
			_pago_red_pendiente = false
			if resultado.get("ok", false):
				_recibir_cafe_visual(int(resultado.get("taza", _siguiente_taza)))
			else:
				cerrar_cafetera()
		)
		return true
	if not _despacho.puntuacion.gastar_puntos(costo_cafe):
		cerrar_cafetera()
		mostrar_mensaje("No tienes puntos suficientes para este café.")
		return false
	_gestor.registrar_compra("cafe", _despacho.jugador_local_id)
	_recibir_cafe_visual()
	return true

func _recibir_cafe_visual(indice: int = -1) -> void:
	if indice >= 0 and indice < _tazas.size():
		_siguiente_taza = indice
	taza_en_mano = _tazas[_siguiente_taza]
	_siguiente_taza = (_siguiente_taza + 1) % _tazas.size()
	var anclaje := _jugador.anclaje_taza()
	taza_en_mano.reparent(anclaje, true)
	taza_en_mano.position = Vector3.ZERO
	taza_en_mano.rotation = Vector3.ZERO
	taza_en_mano.scale = Vector3.ONE / anclaje.global_basis.get_scale()
	var contenido := taza_en_mano.get_node("ContenidoCafe") as MeshInstance3D
	CONTENIDO_CAFE.establecer_llenado(contenido, 1.0)
	contenido.show()
	_devolver_al_terminar = false
	_jugador.establecer_taza_en_mano(true)
	_jugador.cancelar_gesto()
	cerrar_cafetera()
	_audio.play()
	_consulta_restante = 0.0

func cerrar_cafetera() -> void:
	if not is_instance_valid(panel_cafetera) or not panel_cafetera.visible:
		return
	_maquina.stop()
	panel_cafetera.cerrar()
	if SesionLAN.en_partida:
		SesionLAN.puente.liberar_local("cafetera")
	_liberar_pose()
	_tiempo_preparacion = 0.0
	estado = Estado.LIBRE
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
	if _consumo_cafe_pendiente or _devolver_al_terminar or estado != Estado.BEBIENDO or not tiene_cafe() or not is_instance_valid(_despacho) or _despacho.calma_operativa <= 0:
		return
	var recuperada := mini(calma_cafe, 100 - _despacho.calma_operativa)
	if SesionLAN.en_partida:
		_consumo_cafe_pendiente = true
		SesionLAN.solicitar("beber", {}, func(resultado: Dictionary):
			_consumo_cafe_pendiente = false
			if resultado.get("ok", false): _terminar_cafe_visual(recuperada)
		)
		return
	recuperada = _despacho.recuperar_calma(calma_cafe)
	_terminar_cafe_visual(recuperada)

func _terminar_cafe_visual(recuperada: int) -> void:
	if not is_instance_valid(taza_en_mano):
		return
	# El consumo ocurre en la boca; la taza vacía acompaña el descenso del brazo.
	_devolver_al_terminar = true
	(taza_en_mano.get_node("ContenidoCafe") as MeshInstance3D).hide()
	if not _jugador.realizando_gesto():
		_devolver_taza()
	mostrar_mensaje("Café terminado  ·  +%d de calma operativa" % recuperada)
	_audio.play()
	_jugador.reproducir_expresion(&"alegria")

func _devolver_taza() -> void:
	_devolver_al_terminar = false
	if is_instance_valid(taza_en_mano):
		var indice := _tazas.find(taza_en_mano)
		var contenido := taza_en_mano.get_node("ContenidoCafe") as MeshInstance3D
		contenido.hide()
		CONTENIDO_CAFE.establecer_llenado(contenido, 1.0)
		taza_en_mano.reparent($RinconCafe, false)
		taza_en_mano.transform = _origenes[indice]
		taza_en_mano = null
	if is_instance_valid(_jugador):
		_jugador.establecer_taza_en_mano(false)

func interactuar_sofa(quien: Player) -> bool:
	if estado != Estado.LIBRE or not _objetivo_valido(quien, $SofaL/Cuerpo):
		return false
	if SesionLAN.en_partida:
		var asiento_red := "AsientoTramo" if quien.global_position.distance_squared_to($SofaL/AsientoTramo.global_position) <= quien.global_position.distance_squared_to($SofaL/AsientoRetorno.global_position) else "AsientoRetorno"
		if not SesionLAN.puente.reservar_confirmada("sofa:" + asiento_red):
			SesionLAN.puente.reservar_local("sofa:" + asiento_red, func():
				if not interactuar_sofa(quien): SesionLAN.puente.liberar_local("sofa:" + asiento_red)
			)
			return true
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
	if SesionLAN.en_partida:
		SesionLAN.puente.liberar_local("sofa:AsientoTramo")
		SesionLAN.puente.liberar_local("sofa:AsientoRetorno")
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
	if is_instance_valid(panel_cafetera) and panel_cafetera.visible:
		cerrar_cafetera()
		return
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
	if evento is InputEventJoypadButton and evento.pressed:
		if evento.is_action_pressed("ui_accept") and tiene_cafe():
			get_viewport().set_input_as_handled()
			beber_cafe()
		elif evento.is_action_pressed("ui_cancel"):
			if _jugador.esta_sentado():
				get_viewport().set_input_as_handled()
				levantarse()
			elif estado == Estado.PREPARANDO:
				get_viewport().set_input_as_handled()
				_cancelar_preparacion()
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
	if panel_cafetera.visible and not get_tree().paused and not _cafetera_valida():
		cerrar_cafetera()
	if estado == Estado.PREPARANDO:
		_tiempo_preparacion += delta
		panel_cafetera.actualizar_progreso(clampf(_tiempo_preparacion / segundos_preparacion, 0.0, 1.0))
		if _tiempo_preparacion >= segundos_preparacion:
			_servir_cafe()
	elif estado == Estado.BEBIENDO and not _jugador.realizando_gesto():
		if _devolver_al_terminar:
			_devolver_taza()
		elif tiene_cafe():
			CONTENIDO_CAFE.establecer_llenado(taza_en_mano.get_node("ContenidoCafe"), 1.0)
		_sorbo.stop()
		_espera_sorbo = -1.0
		estado = Estado.SENTADO if _jugador.esta_sentado() else Estado.LIBRE
	if estado == Estado.BEBIENDO and tiene_cafe():
		CONTENIDO_CAFE.actualizar_sorbo(taza_en_mano.get_node("ContenidoCafe"), _jugador.gestos.tiempo / _jugador.gestos.duracion)
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
	if not _disponible() or panel_cafetera.visible or _gestor.evento_apagon.estado == 2 or _gestor.clasificacion_partida.visible:
		_aviso.hide()
		return
	var titulo := ""
	var detalle := ""
	var progreso := -1.0
	if estado == Estado.PREPARANDO:
		titulo = "PREPARANDO CAFÉ"
		detalle = "%d puntos al recibir la taza  ·  %s cancelar" % [costo_cafe, "B" if ControladorInterfaz.dispositivo_mando >= 0 else "Esc"]
		progreso = _tiempo_preparacion / segundos_preparacion
	elif _jugador.esta_sentado():
		titulo = "DESCANSANDO  ·  [%s] LEVANTARSE" % ("B" if ControladorInterfaz.dispositivo_mando >= 0 else "E")
		detalle = "+1 calma cada 2 s  ·  los casos siguen corriendo"
		if _mensaje_restante > 0.0 and not tiene_cafe():
			detalle = _mensaje
		progreso = _tiempo_descanso / segundos_descanso
	elif tiene_cafe() or estado == Estado.BEBIENDO:
		# El medallón del bolsillo ya indica F / BEBIENDO.
		_aviso.hide()
		return
	elif _mensaje_restante > 0.0:
		titulo = "ZONA DE DESCANSO"
		detalle = _mensaje
	else:
		var objetivo := _jugador.obtener_objetivo_interaccion()
		if objetivo == $RinconCafe/MuebleCafe:
			titulo = "CAFETERA  ·  %d PTS" % costo_cafe
			var espera: int = _gestor.espera_compra("cafe", _despacho.jugador_local_id)
			detalle = "Tu próximo café en %d s" % espera if espera > 0 else "Prepara y recoge tu café"
		elif objetivo == $SofaL/Cuerpo:
			titulo = "DESCANSO"
			detalle = "+1 de calma cada 2 segundos"
	if titulo.is_empty():
		_aviso.hide()
	else:
		_aviso.presentar(titulo, detalle, progreso)
		var margen := 12.0 * _aviso.scale.y
		var limite := get_viewport().get_visible_rect().size.y - margen
		var papel: Control = _gestor.get("indicador_papel")
		var apagon: Control = _gestor.get("_aviso_apagon")
		var bolsillo: Control = _gestor.get("indicador_bolsillo")
		for otro: Control in [papel, apagon, bolsillo]:
			if is_instance_valid(otro) and otro.is_visible_in_tree():
				limite = minf(limite, otro.global_position.y - margen)
		_aviso.position.y = minf(_aviso.position.y, limite - _aviso.size.y * _aviso.scale.y)

func _al_reiniciar_jugador() -> void:
	_limpiar_interaccion(false)

func _al_terminar_partida() -> void:
	_limpiar_interaccion(true)

func _limpiar_interaccion(restaurar_posicion: bool) -> void:
	cerrar_cafetera()
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
	if is_instance_valid(panel_cafetera):
		panel_cafetera.cerrar()
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
