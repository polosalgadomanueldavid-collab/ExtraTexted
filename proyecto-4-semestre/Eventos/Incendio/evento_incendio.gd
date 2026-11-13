extends Node3D
## Solo las mesas registradas del perímetro se pueden extinguir.
## Los cajones arden diez segundos y conservan su colisión como ceniza.

signal iniciado
signal terminado
signal mesa_recuperada(estacion_id: String)

const Foco := preload("res://Eventos/Incendio/foco_incendio.gd")
const Fuego := preload("res://Eventos/Incendio/fuego_3d.gd")
const Extintor := preload("res://Eventos/Incendio/extintor.gd")
const PanelIncendio := preload("res://Eventos/Incendio/panel_incendio.gd")
const IndicadorExtintor := preload("res://Eventos/Incendio/indicador_extintor.gd")
const SonidosMesas := preload("res://UI/Despacho/sonidos_mesas.gd")
const SEGUNDOS_CENIZA := 10.0
const SEGUNDOS_POR_MESA := 3.0
const SEGUNDOS_GRACIA_CORDURA := 30.0
const SEGUNDOS_ESCALADA_CORDURA := 30.0
const PERDIDA_BASE_CORDURA := 1.0
const ETAPAS_DESGASTE := 3
const ALCANCE := 1.15

var permiso_inicio: Callable
var activo := false
var tiempo := 0.0
var equipado := false
var rociando := false
var bloqueos_fijos := false
var focos: Array[Foco] = []
var extintor: Extintor
var panel: PanelIncendio
var indicador_extintor: IndicadorExtintor
var objetivo: Foco
var _oficina: Node3D
var _jugador: Player
var _solicitud := false
var _cajones: Dictionary = {}
var _fuegos_cajones: Array[Fuego] = []
var _ambiente: AudioStreamPlayer
var _chorro: AudioStreamPlayer
var _papel_guardado: PapelDenuncia
var _pose_papel: Transform3D
var _mostrar_completado := 0.0
var _focos_perimetro: Array[Foco] = []
var _perdida_acumulada := 0.0


func configurar(oficina: Node3D, jugador: Player) -> void:
	_oficina = oficina
	_jugador = jugador
	_jugador.control_incendio = self
	_jugador.reset_performed.connect(soltar)
	for mesa: Node3D in get_tree().get_nodes_in_group("mesas_incendiables"):
		if not oficina.is_ancestor_of(mesa):
			continue
		var cuerpo := mesa.get_node("StaticBody3D") as StaticBody3D
		var colision := cuerpo.get_node("CollisionShape3D") as CollisionShape3D
		var limites := colision.global_transform * colision.shape.get_debug_mesh().get_aabb()
		var foco := Foco.new()
		foco.evento = self
		foco.mesa = mesa
		foco.cuerpo = cuerpo
		foco.limites = limites
		if cuerpo is Estacion:
			foco.estacion_id = cuerpo.estacion_id
			foco.nombre_visible = cuerpo.nombre_visible
		add_child(foco)
		foco.global_position = Vector3(limites.get_center().x, limites.end.y + 0.025, limites.get_center().z)
		focos.append(foco)
		# Protege una aproximación a cada mesa desde la primera distribución.
		var centro := limites.get_center()
		var acceso := Marker3D.new()
		acceso.add_to_group("accesos_navegacion")
		add_child(acceso)
		if mesa.get_parent().name == &"Mesas verticales IZQ":
			acceso.global_position = Vector3(limites.end.x + 0.38, 0.38, centro.z)
		elif mesa.get_parent().name == &"Mesas verticales DER":
			acceso.global_position = Vector3(limites.position.x - 0.38, 0.38, centro.z)
		elif centro.z < 1.0:
			acceso.global_position = Vector3(centro.x, 0.38, limites.end.z + 0.38)
		else:
			acceso.global_position = Vector3(centro.x, 0.38, limites.position.z - 0.38)
		foco.acceso = acceso
	_ordenar_perimetro()
	# Identifica la mesa del PC por cercanía, sin depender del nombre del modelo.
	var mas_cercana: Foco
	var distancia := INF
	for foco in focos:
		var d := foco.global_position.distance_squared_to(oficina.computador.global_position)
		if d < distancia:
			distancia = d
			mas_cercana = foco
	if mas_cercana != null:
		mas_cercana.estacion_id = "computador"
		mas_cercana.nombre_visible = "Computador"
	extintor = Extintor.new()
	extintor.evento = self
	add_child(extintor)
	extintor.global_position = Vector3(0.8, 0.38, 7.8)
	var acceso_extintor := Marker3D.new()
	acceso_extintor.position = extintor.position
	acceso_extintor.add_to_group("accesos_navegacion")
	add_child(acceso_extintor)
	panel = PanelIncendio.new()
	oficina.get_node("CanvasLayer").add_child(panel)
	indicador_extintor = IndicadorExtintor.new()
	oficina.get_node("CanvasLayer").add_child(indicador_extintor)
	_ambiente = SonidosMesas.crear_reproductor(self, "CrepitarIncendio", preload("res://Audios/Eventos/incendio_fuego.wav"), -23.0, true)
	_chorro = SonidosMesas.crear_reproductor(self, "ChorroExtintor", preload("res://Audios/Eventos/incendio_extintor.wav"), -18.0, true)


func _ordenar_perimetro() -> void:
	_focos_perimetro.assign(focos)
	if focos.is_empty():
		return
	var limites := focos[0].limites
	for foco in focos:
		limites = limites.merge(foco.limites)
	var centro := limites.get_center()
	# El orden del árbol no sigue las paredes; el ángulo conserva ambas vecinas,
	# incluidas las esquinas, sin saltar mesas que ya estén apagadas.
	_focos_perimetro.sort_custom(func(a: Foco, b: Foco) -> bool:
		var pa := a.global_position - centro
		var pb := b.global_position - centro
		return atan2(pa.z, pa.x) < atan2(pb.z, pb.x)
	)


func ajustar_accesos(grafo: GrafoPiso) -> void:
	# El grafo ya incorporó las colisiones de mesas y sillas. Reservar celdas reales.
	for foco in focos:
		var celda := grafo.celda_de_acceso(foco.acceso.global_position)
		foco.acceso.global_position = grafo.celda_a_posicion(celda)


func iniciar(bloqueos: Dictionary) -> bool:
	if activo or focos.is_empty() or get_tree().paused or _jugador.input_locked or _jugador.realizando_gesto():
		return false
	if permiso_inicio.is_valid() and not permiso_inicio.call():
		return false
	activo = true
	bloqueos_fijos = false
	tiempo = 0.0
	_perdida_acumulada = 0.0
	equipado = false
	extintor.recogido = false
	extintor.deposito.transform = Transform3D.IDENTITY
	extintor.show()
	panel.show()
	_mostrar_completado = 0.0
	_cajones = bloqueos.duplicate()
	for foco in focos:
		foco.encender()
	for cajon: StaticBody3D in _cajones.values():
		if cajon.get("es_ceniza") == true:
			continue
		var fuego := Fuego.new()
		fuego.ancho = 0.45
		fuego.profundo = 0.4
		add_child(fuego)
		fuego.global_position = cajon.global_position + Vector3.UP * 0.85
		_fuegos_cajones.append(fuego)
	_ambiente.play()
	_jugador.reproducir_expresion(&"estres")
	iniciado.emit()
	_actualizar_panel()
	_actualizar_indicador_extintor()
	return true


func arde_estacion(estacion_id: String) -> bool:
	if not activo:
		return false
	for foco in focos:
		if foco.estacion_id == estacion_id:
			return foco.apagado < 1.0
	return false


func obtener_objetivo(jugador: Player) -> Node3D:
	if not activo or jugador != _jugador or _oficina.partida_finalizada:
		return null
	if not equipado and _al_alcance(extintor.global_position + Vector3.UP * 0.25, null):
		return extintor
	var cercano: Foco
	var menor := INF
	for foco in focos:
		if foco.apagado >= 1.0:
			continue
		var p := jugador.global_position
		var punto := Vector3(clampf(p.x, foco.limites.position.x, foco.limites.end.x), p.y + 0.42, clampf(p.z, foco.limites.position.z, foco.limites.end.z))
		var distancia := Vector2(punto.x - p.x, punto.z - p.z).length()
		if distancia < menor and _al_alcance(punto, foco):
			menor = distancia
			cercano = foco
	return cercano


func _al_alcance(punto: Vector3, foco: Foco) -> bool:
	var origen := _jugador.global_position + Vector3.UP * 0.42
	var diferencia := punto - origen
	var horizontal := Vector3(diferencia.x, 0, diferencia.z)
	if horizontal.length() > ALCANCE or absf(diferencia.y) > 0.8:
		return false
	if horizontal.length() > 0.08 and _jugador.visual.global_basis.z.normalized().dot(horizontal.normalized()) < 0.25:
		return false
	var consulta := PhysicsRayQueryParameters3D.create(origen, punto, 1)
	consulta.exclude = [_jugador.get_rid()]
	var impacto := get_world_3d().direct_space_state.intersect_ray(consulta)
	if impacto.is_empty():
		return true
	var cuerpo := impacto.get("collider") as Node
	return foco != null and (cuerpo == foco.cuerpo or foco.mesa.is_ancestor_of(cuerpo))


func recoger_extintor(jugador: Player) -> void:
	if not activo or equipado or jugador != _jugador or obtener_objetivo(jugador) != extintor:
		return
	if jugador._taza_en_mano:
		_oficina.panel_despacho._mostrar_mensaje("Termina el café con F antes de tomar el extintor.", Color("ff9b44"))
		return
	jugador.ejecutar_gesto(&"recoger", _equipar, extintor)


func _equipar() -> void:
	if not activo:
		return
	equipado = true
	extintor.recogido = true
	indicador_extintor.hide()
	_actualizar_panel()


func solicitar_apagado(foco: Foco, jugador: Player) -> void:
	if not activo or jugador != _jugador or not focos.has(foco) or foco.apagado >= 1.0:
		return
	if not equipado:
		_oficina.panel_despacho._mostrar_mensaje("¡Está en llamas! Busca el extintor en la zona de descanso.", Color("ff9b44"))
		return
	if jugador._taza_en_mano:
		_oficina.panel_despacho._mostrar_mensaje("Termina el café con F antes de usar el extintor.", Color("ff9b44"))
		return
	if obtener_objetivo(jugador) != foco:
		return
	objetivo = foco
	_solicitud = true


func soltar() -> void:
	_solicitud = false
	rociando = false
	if is_instance_valid(_jugador):
		_jugador.usando_extintor = false
		if is_instance_valid(_jugador.gestos):
			_jugador.gestos.rociando_extintor = false
	if is_instance_valid(extintor):
		extintor.espuma.emitting = false
	if is_instance_valid(_chorro):
		_chorro.stop()
	if is_instance_valid(_papel_guardado) and _papel_guardado.portador == _jugador:
		_papel_guardado.transform = _pose_papel
	_papel_guardado = null


func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		soltar()


func _physics_process(delta: float) -> void:
	if not activo:
		if _mostrar_completado > 0.0:
			_mostrar_completado -= delta
			if _mostrar_completado <= 0.0:
				panel.hide()
		return
	var tiempo_anterior := tiempo
	tiempo += delta
	if tiempo + 0.00001 >= SEGUNDOS_CENIZA and not _fuegos_cajones.is_empty():
		_convertir_cenizas()
	if _solicitud:
		if not Input.is_action_pressed(_jugador.interaction_action) or _jugador.input_locked or _jugador.realizando_gesto() or not _jugador.is_on_floor() or _jugador._taza_en_mano or obtener_objetivo(_jugador) != objetivo or _oficina.clasificacion_partida.visible:
			soltar()
		else:
			rociando = true
			_jugador.usando_extintor = true
			_jugador.velocity.x = 0.0
			_jugador.velocity.z = 0.0
			_jugador._cancelar_reposo()
			if is_instance_valid(_jugador.gestos):
				_jugador.gestos.rociando_extintor = true
			if not _chorro.playing:
				_chorro.play()
			if objetivo.rociar(delta, SEGUNDOS_POR_MESA):
				_recuperar_mesa_y_adyacentes(objetivo)
				soltar()
				if _todas_apagadas():
					_finalizar()
	if activo:
		_aplicar_desgaste_cordura(tiempo_anterior)
		# perder_calma puede terminar la partida y ocultar el evento de inmediato.
		if not activo:
			return
	_actualizar_panel()


func _recuperar_mesa_y_adyacentes(foco: Foco) -> void:
	mesa_recuperada.emit(foco.estacion_id)
	var indice := _focos_perimetro.find(foco)
	if indice < 0:
		return
	for paso: int in [-1, 1]:
		var vecina := _focos_perimetro[posmod(indice + paso, _focos_perimetro.size())]
		if vecina.apagado >= 1.0:
			continue
		# Solo las dos vecinas originales: el apagado adicional no se propaga.
		vecina.rociar(SEGUNDOS_POR_MESA, SEGUNDOS_POR_MESA)
		mesa_recuperada.emit(vecina.estacion_id)


func _aplicar_desgaste_cordura(tiempo_anterior: float) -> void:
	# Integra únicamente el tiempo posterior a cada umbral, incluso si un
	# cuadro cruza varios: 1 punto/s tras 30 s, 2 tras 60 s y 3 tras 90 s.
	for etapa in ETAPAS_DESGASTE:
		var umbral := SEGUNDOS_GRACIA_CORDURA + etapa * SEGUNDOS_ESCALADA_CORDURA
		_perdida_acumulada += maxf(0.0, tiempo - maxf(tiempo_anterior, umbral)) * PERDIDA_BASE_CORDURA
	var puntos := floori(_perdida_acumulada + 0.00001)
	if puntos > 0:
		_perdida_acumulada = maxf(0.0, _perdida_acumulada - puntos)
		_oficina.sistema_despacho.perder_calma(puntos, &"incendio")


func _process(_delta: float) -> void:
	if not activo:
		return
	_actualizar_indicador_extintor()
	var destino := objetivo.global_position if is_instance_valid(objetivo) else Vector3.ZERO
	extintor.actualizar(_jugador, rociando, destino)
	if rociando and is_instance_valid(_jugador.papel_en_mano):
		if _papel_guardado != _jugador.papel_en_mano:
			_papel_guardado = _jugador.papel_en_mano
			_pose_papel = _papel_guardado.transform
		_papel_guardado.global_position = _jugador.global_position + Vector3.UP * 0.40 - _jugador.visual.global_basis.z.normalized() * 0.18
		_papel_guardado.global_basis = _jugador.visual.global_basis.orthonormalized() * Basis.from_euler(Vector3(PI * 0.5, 0, 0))


func _actualizar_indicador_extintor() -> void:
	if not activo or equipado or _oficina.partida_finalizada:
		indicador_extintor.hide()
		return
	indicador_extintor.actualizar(
		get_viewport().get_camera_3d(), extintor.global_position + Vector3.UP * 1.1,
		_jugador.global_position, _jugador.obtener_objetivo_interaccion() == extintor and not _jugador._taza_en_mano,
		true
	)


func _convertir_cenizas() -> void:
	bloqueos_fijos = true
	for cajon: StaticBody3D in _cajones.values():
		if is_instance_valid(cajon):
			cajon.convertir_en_ceniza()
	for fuego in _fuegos_cajones:
		fuego.queue_free()
	_fuegos_cajones.clear()


func _todas_apagadas() -> bool:
	for foco in focos:
		if foco.apagado < 1.0:
			return false
	return true


func _actualizar_panel() -> void:
	panel.progreso = 0.0
	panel.completadas = 0
	panel.total = focos.size()
	for foco in focos:
		panel.progreso += foco.apagado / focos.size()
		if foco.apagado >= 1.0:
			panel.completadas += 1
	if panel.completadas == panel.total:
		panel.progreso = 1.0
	panel.instruccion = "Acércate al fuego y mantén E para apagarlo" if equipado else "Busca el extintor en la zona de descanso"
	var cercano := obtener_objetivo(_jugador) as Foco
	panel.nombre_mesa = cercano.nombre_visible if cercano != null and equipado else ""
	panel.progreso_mesa = cercano.apagado if cercano != null else 0.0
	panel.apagando_mesa = rociando and cercano != null
	if tiempo <= SEGUNDOS_GRACIA_CORDURA:
		panel.estado_cordura = "Cordura en %d s · Apaga hasta 3 mesas a la vez" % ceili(SEGUNDOS_GRACIA_CORDURA - tiempo)
	else:
		var etapa := mini(ETAPAS_DESGASTE, 1 + floori((tiempo - SEGUNDOS_GRACIA_CORDURA) / SEGUNDOS_ESCALADA_CORDURA))
		panel.estado_cordura = "Pierdes %d de cordura/s · ¡Apaga el incendio!" % (etapa * PERDIDA_BASE_CORDURA)
	if not activo:
		panel.instruccion = "Oficina recuperada · vuelven los bloqueos normales"
		panel.estado_cordura = ""
	panel.queue_redraw()


func _finalizar() -> void:
	soltar()
	activo = false
	bloqueos_fijos = false
	for fuego in _fuegos_cajones:
		fuego.queue_free()
	_fuegos_cajones.clear()
	_cajones.clear()
	equipado = false
	extintor.hide()
	indicador_extintor.hide()
	_ambiente.stop()
	_mostrar_completado = 3.0
	terminado.emit()


func detener() -> void:
	soltar()
	activo = false
	_perdida_acumulada = 0.0
	equipado = false
	_mostrar_completado = 0.0
	extintor.hide()
	indicador_extintor.hide()
	panel.hide()
	_ambiente.stop()


func _exit_tree() -> void:
	soltar()
