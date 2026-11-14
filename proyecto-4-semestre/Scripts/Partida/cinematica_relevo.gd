extends Node3D
## Dirige el relevo con el despacho detenido y la emergencia en curso.

signal terminada

const MODELO_RELEVO := preload("res://Personajes/PoliciaRelevo/PoliciaRelevo.tscn")
const Ambiente := preload("res://Scripts/Partida/ambiente_relevo.gd")
const SEPARACION := 0.64
const POSE_AGOTADA := preload("res://Personajes/PoliciaAzul/pose_agotada.gd")
const FUENTE := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
const VOZ_RELEVO := preload("res://Audios/VozPersonaje/Gomosa/saludo.wav")

var companero: Player
var camara: Camera3D
var burbuja: PanelContainer
var finalizada := false
var jugador_salio := false
var companero_llego := false
var _jugador: Player
var _puerta: Node3D
var _pose: SkeletonModifier3D
var _animador: AnimationPlayer
var _seguir_actores := false
var _seguir_companero := false
var _punta: Polygon2D
var _capa: CanvasLayer
var _recorrido_salida: PackedVector3Array
var _recorrido_entrada: PackedVector3Array
var _grafo: GrafoPiso
var ambiente: Ambiente
var _puesto: Vector3
var _movimientos: Dictionary = {}
var _fuera := Vector3.ZERO
var _listo := false


func iniciar(jugador: Player, puerta: Node3D, grafo: GrafoPiso, oficina: Node3D) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_jugador = jugador
	_puerta = puerta
	_grafo = grafo
	_puesto = jugador.global_position
	_preparar_jugador()
	_preparar_camara()
	_preparar_companero()
	_preparar_burbuja()
	ambiente = Ambiente.new()
	add_child(ambiente)
	ambiente.configurar(oficina, companero, camara)
	_fuera = _puerta.to_global(Vector3(-0.22, 0, -1.15))
	_listo = true
	_secuencia()


func _preparar_jugador() -> void:
	_jugador.input_locked = true
	_jugador.en_relevo = true
	_jugador.process_mode = Node.PROCESS_MODE_ALWAYS
	_jugador.set_physics_process(false)
	_jugador.set_process_input(false)
	_jugador.set_collision_mask_value(2, true)
	# La congelación conserva la inercia que ya tenía al perder el turno.
	if not _jugador.hielo_activo:
		_jugador.velocity = Vector3.ZERO
	_jugador.velocity.y = 0.0
	_jugador.sonido_pasos.detener()
	_jugador.terminar_descanso_sentado(true)
	_jugador.establecer_taza_en_mano(false)
	if is_instance_valid(_jugador.gestos):
		_jugador.gestos.cancelar()
		_jugador.gestos.active = true
	# Solo el modelo se anima durante la pausa; no se reactiva el controlador.
	var esqueleto := _jugador.visual.find_child("Skeleton3D", true, false) as Skeleton3D
	esqueleto.process_mode = Node.PROCESS_MODE_ALWAYS
	_pose = POSE_AGOTADA.new()
	esqueleto.add_child(_pose)
	_jugador.animation_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_reproducir(_jugador.animation_player, "idle", 0.7)
	# Recuperar un personaje que ya cayó usa el rescate del propio terremoto.
	var sismo: Node = get_parent().evento_terremoto
	if sismo.activo and _jugador.global_position.y < _puerta.global_position.y - 0.1:
		sismo._devolver_a_tierra()
		_puesto = _jugador.global_position


func _preparar_camara() -> void:
	var anterior := get_viewport().get_camera_3d()
	camara = Camera3D.new()
	camara.name = "CamaraRelevo"
	add_child(camara)
	camara.global_transform = anterior.global_transform
	camara.fov = anterior.fov
	camara.environment = anterior.environment.duplicate() as Environment
	camara.cull_mask = anterior.cull_mask
	camara.near = 0.05
	camara.make_current()


func _preparar_companero() -> void:
	companero = MODELO_RELEVO.instantiate() as Player
	companero.name = "CompaneroRelevo"
	companero.character_scale = _jugador.character_scale
	add_child(companero)
	companero.en_relevo = true
	companero.input_locked = true
	companero.set_physics_process(false)
	companero.set_process_input(false)
	companero.set_collision_mask_value(2, true)
	companero.remove_from_group("player")
	# Se aparta en el pasillo; el umbral solo admite un policía a la vez.
	companero.global_position = _puerta.to_global(Vector3(0.44, 0.0, -1.25))
	companero.visual.rotation.y = _puerta.global_rotation.y
	_animador = companero.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_reproducir(_animador, "idle")


func _secuencia() -> void:
	# Una pausa breve permite leer el agotamiento antes de descubrir la puerta.
	await get_tree().create_timer(0.8).timeout
	var plano_puerta := _transform_camara(_puerta.to_global(Vector3(1.8, 1.55, 2.65)), _puerta.to_global(Vector3(0, 0.67, 0.33)))
	var giro := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	giro.tween_property(camara, "global_transform", plano_puerta, 1.65)
	await giro.finished
	await _puerta.abrir().finished
	if not is_inside_tree():
		return
	var interior := _puerta.to_global(Vector3(0, 0, 0.95))
	var salida := _ruta(_jugador.global_position, interior)
	salida.append(_puerta.to_global(Vector3(0, 0, 0.30)))
	salida.append(_puerta.to_global(Vector3(0, 0, -0.45)))
	salida.append(_fuera)
	var apartadero := _buscar_apartadero(salida, interior)
	if apartadero != Vector3.INF:
		var entrada := PackedVector3Array([_puerta.to_global(Vector3(0, 0, -0.65)), _puerta.to_global(Vector3(0, 0, 0.40)), interior])
		entrada.append_array(_ruta(interior, apartadero, _jugador.global_position))
		if _distancia_a_ruta(_jugador.global_position, entrada, companero.global_position) >= SEPARACION:
			await _recorrer(companero, entrada, 1.2)
			if not is_inside_tree():
				return
		else:
			apartadero = Vector3.INF
	# Si se pierde el turno en la puerta, el compañero cede primero la salida.
	if apartadero == Vector3.INF:
		_seguir_actores = true
		await _salir_jugador()
		if not is_inside_tree():
			return
		await _recorrer(companero, PackedVector3Array([_puerta.to_global(Vector3(0, 0, -0.65)), _puerta.to_global(Vector3(0, 0, 0.40)), interior]), 1.2)
	else:
		_salir_jugador()
	if not is_inside_tree():
		return
	_reproducir(_animador, "idle")
	_mostrar_dialogo()
	# Mantén el primer plano para leer la frase antes de abrir el encuadre.
	await get_tree().create_timer(1.2).timeout
	_seguir_actores = true
	await get_tree().create_timer(2.4).timeout
	var despedida := create_tween()
	despedida.tween_property(burbuja, "modulate:a", 0.0, 0.35)
	await despedida.finished
	burbuja.hide()
	_punta.hide()
	# Reserva el apartadero hasta que el saliente haya liberado el paso.
	while not jugador_salio:
		await get_tree().process_frame
		if not is_inside_tree():
			return
	_ocupar_puesto()
	await _puerta.cerrar().finished
	_seguir_companero = true
	while not companero_llego:
		await get_tree().process_frame
		if not is_inside_tree():
			return
	await get_tree().create_timer(0.8).timeout
	_seguir_actores = false
	await get_tree().create_timer(0.45).timeout
	finalizada = true
	ambiente.finalizar()
	terminada.emit()


func _grafo_actual(evitar := Vector3.INF) -> GrafoPiso:
	var mapa := GrafoPiso.new()
	mapa.bloqueos_fijos = _grafo.bloqueos_fijos.duplicate()
	mapa.bloqueos_mesas = _grafo.bloqueos_mesas.duplicate()
	mapa.bloqueos_temporales = _grafo.bloqueos_temporales.duplicate()
	mapa.grietas = _grafo.grietas.duplicate()
	mapa.escombros = _grafo.escombros.duplicate()
	var sismo: Node = ambiente.oficina.evento_terremoto
	if sismo.activo:
		# Evitar también las zonas anunciadas, antes de que caiga el escombro.
		mapa.grietas.merge(sismo._celdas_rotas)
		mapa.escombros.merge(sismo._reservas_escombros)
	if evitar != Vector3.INF:
		for celda: Vector2i in _grafo.adyacencia:
			if _plano(mapa.celda_a_posicion(celda) - evitar).length() < SEPARACION + 0.12:
				mapa.bloqueos_temporales[celda] = true
	mapa.construir_adyacencia()
	return mapa


func _ruta(desde: Vector3, hasta: Vector3, evitar := Vector3.INF) -> PackedVector3Array:
	var grafo := _grafo_actual(evitar)
	var puntos := PackedVector3Array()
	var inicio := grafo.celda_de_acceso(desde)
	var fin := grafo.celda_de_acceso(hasta)
	for celda: Vector2i in grafo.calcular_ruta(inicio, fin):
		var punto := grafo.celda_a_posicion(celda)
		punto.y = _puerta.global_position.y
		puntos.append(punto)
	if not puntos.is_empty():
		# Un puesto destruido se sustituye por su apoyo firme más cercano.
		if grafo.es_transitable(grafo.posicion_a_celda(hasta)) or hasta.distance_to(_puerta.global_position) < 1.15:
			hasta.y = _puerta.global_position.y
			puntos.append(hasta)
	return _suavizar_ruta(desde, puntos, grafo)


func _suavizar_ruta(desde: Vector3, puntos: PackedVector3Array, mapa: GrafoPiso) -> PackedVector3Array:
	var resultado := PackedVector3Array()
	var indice := 0
	while indice < puntos.size():
		var elegido := indice
		for candidato in range(puntos.size() - 1, indice - 1, -1):
			if _segmento_libre(desde, puntos[candidato], mapa):
				elegido = candidato
				break
		resultado.append(puntos[elegido])
		desde = puntos[elegido]
		indice = elegido + 1
	return resultado


func _segmento_libre(desde: Vector3, hasta: Vector3, mapa: GrafoPiso) -> bool:
	var pasos := maxi(1, ceili(desde.distance_to(hasta) / 0.12))
	for i in range(1, pasos + 1):
		var punto := desde.lerp(hasta, float(i) / pasos)
		if not mapa.es_transitable(mapa.posicion_a_celda(punto)):
			return false
	var consulta := PhysicsShapeQueryParameters3D.new()
	var forma := BoxShape3D.new()
	var original := _jugador.get_node("Colision") as CollisionShape3D
	forma.size = (original.shape as BoxShape3D).size * original.global_basis.get_scale()
	consulta.shape = forma
	consulta.collision_mask = 1
	consulta.margin = 0.004
	consulta.transform.origin = desde + Vector3(0, forma.size.y * 0.5 + 0.018, 0.018)
	consulta.motion = hasta - desde
	return get_world_3d().direct_space_state.cast_motion(consulta)[0] > 0.999


func _salir_jugador() -> void:
	var interior := _puerta.to_global(Vector3(0, 0, 0.95))
	var reserva := companero.global_position if _puerta.to_local(companero.global_position).z > 0 else Vector3.INF
	_recorrido_salida = _ruta(_jugador.global_position, interior, reserva)
	while _recorrido_salida.is_empty():
		await get_tree().create_timer(0.25).timeout
		_recorrido_salida = _ruta(_jugador.global_position, interior, reserva)
	await _recorrer(_jugador, _recorrido_salida, 0.85)
	if not is_inside_tree():
		return
	await _recorrer(_jugador, PackedVector3Array([_puerta.to_global(Vector3(0, 0, 0.30)), _puerta.to_global(Vector3(0, 0, -0.45)), _fuera]), 0.85)
	if not is_inside_tree():
		return
	_jugador.hide()
	_jugador.collision_layer = 0
	_jugador.sonido_pasos.detener()
	jugador_salio = true


func _ocupar_puesto() -> void:
	_recorrido_entrada = _ruta(companero.global_position, _puesto)
	while _recorrido_entrada.is_empty():
		await get_tree().create_timer(0.25).timeout
		_recorrido_entrada = _ruta(companero.global_position, _puesto)
	await _recorrer(companero, _recorrido_entrada, 1.35)
	if not is_inside_tree():
		return
	companero_llego = true


func _recorrer(actor: Player, puntos: PackedVector3Array, rapidez: float) -> void:
	if puntos.is_empty():
		return
	_movimientos[actor] = {"puntos": puntos, "indice": 0, "rapidez": rapidez, "atasco": 0.0}
	while is_inside_tree() and _movimientos.has(actor):
		await get_tree().physics_frame


func _buscar_apartadero(salida: PackedVector3Array, interior: Vector3) -> Vector3:
	var mapa := _grafo_actual(_jugador.global_position)
	var mejor := Vector3.INF
	var distancia := INF
	for celda: Vector2i in mapa.celdas_alcanzables(mapa.celda_de_acceso(interior)):
		var punto := mapa.celda_a_posicion(celda)
		punto.y = _puerta.global_position.y
		var local := _puerta.to_local(punto)
		if local.z < 0.8 or local.z > 2.6 or punto.distance_to(interior) > 2.2:
			continue
		if _distancia_a_ruta(punto, salida, _jugador.global_position) < SEPARACION + 0.2:
			continue
		var ruta := _ruta(interior, punto, _jugador.global_position)
		if ruta.is_empty() or _distancia_a_ruta(_jugador.global_position, ruta, interior) < SEPARACION:
			continue
		if punto.distance_to(interior) < distancia:
			mejor = punto
			distancia = punto.distance_to(interior)
	return mejor


func _distancia_a_ruta(posicion: Vector3, puntos: PackedVector3Array, origen: Vector3) -> float:
	var menor := INF
	for punto: Vector3 in puntos:
		var cerca := Geometry2D.get_closest_point_to_segment(_plano(posicion), _plano(origen), _plano(punto))
		menor = minf(menor, _plano(posicion).distance_to(cerca))
		origen = punto
	return menor


func _plano(punto: Vector3) -> Vector2:
	return Vector2(punto.x, punto.z)


func _physics_process(delta: float) -> void:
	if not _listo or finalizada:
		return
	for actor: Player in [_jugador, companero]:
		if not actor.visible:
			continue
		ambiente.aplicar(actor)
		_avanzar_actor(actor, delta)


func _avanzar_actor(actor: Player, delta: float) -> void:
	var anterior := actor.global_position
	var deseada := Vector3.ZERO
	var distancia := INF
	if _movimientos.has(actor):
		var viaje: Dictionary = _movimientos[actor]
		var puntos: PackedVector3Array = viaje.puntos
		while viaje.indice < puntos.size() and _plano(puntos[viaje.indice] - actor.global_position).length() < 0.035:
			viaje.indice += 1
		if viaje.indice == puntos.size():
			_movimientos.erase(actor)
			actor.velocity = Vector3.ZERO
		else:
			var diferencia := puntos[viaje.indice] - actor.global_position
			diferencia.y = 0.0
			distancia = diferencia.length()
			deseada = diferencia.normalized() * viaje.rapidez * ambiente.factor_velocidad(actor)
			# Frenar antes del vértice impide orbitar el punto con inercia.
			deseada = deseada.limit_length(distancia * (2.4 if actor.hielo_activo else 4.5))
	var aceleracion := actor.ACELERACION_HIELO if actor.hielo_activo else 5.0
	if deseada.is_zero_approx():
		aceleracion = actor.FRENADO_HIELO if actor.hielo_activo else 8.0
	if not actor.congelado:
		actor.velocity = actor.velocity.move_toward(deseada, aceleracion * delta)
	var paso := actor.velocity * delta
	if not actor.congelado and paso.length() > distancia:
		paso = paso.normalized() * distancia
	var otro: Player = companero if actor == _jugador else _jugador
	var separacion := maxf(SEPARACION, 0.8 if actor.nadando or otro.nadando or actor.congelado or otro.congelado else 0.0)
	# Barrido entre cuadros: también impide atravesarse con FPS bajos o hielo.
	if otro.visible and _distancia_a_ruta(otro.global_position, PackedVector3Array([anterior + paso]), anterior) < separacion:
		paso = Vector3.ZERO
		actor.velocity = Vector3.ZERO
	var sismo: Node = ambiente.oficina.evento_terremoto
	if sismo.activo:
		for grieta: Node in sismo.grietas:
			if grieta.contiene_hueco(_plano(anterior + paso)):
				paso = Vector3.ZERO
				actor.velocity = Vector3.ZERO
				break
	if not paso.is_zero_approx():
		var restante := paso
		for intento in 3:
			var choque := actor.move_and_collide(restante)
			if choque == null:
				break
			restante = choque.get_remainder().slide(choque.get_normal())
			actor.velocity = actor.velocity.slide(choque.get_normal())
			if restante.length_squared() < 0.0000001:
				break
		# El deslizamiento junto a una pared tampoco puede invadir al compañero.
		if otro.visible and _distancia_a_ruta(otro.global_position, PackedVector3Array([actor.global_position]), anterior) < SEPARACION:
			actor.global_position = anterior
			actor.velocity = Vector3.ZERO
		var giro := atan2(paso.x, paso.z)
		actor.visual.rotation.y = lerp_angle(actor.visual.rotation.y, giro, 1.0 - exp(-8.0 * delta))
	# Los cuerpos permanecen sobre el apoyo, incluso si el turno terminó saltando.
	var consulta := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 0.15, actor.global_position + Vector3.DOWN * 2.0, 1)
	var apoyo := get_world_3d().direct_space_state.intersect_ray(consulta)
	if not apoyo.is_empty():
		actor.global_position.y = move_toward(actor.global_position.y, apoyo.position.y + 0.002, delta * 1.5)
	var rapidez := _plano(actor.global_position - anterior).length() / delta
	actor.actualizar_animacion_relevo(delta, rapidez, actor == _jugador)
	actor.visual.rotation.z = sin(ambiente.reloj_temblor * 9.0 + (0.8 if actor == companero else 0.0)) * ambiente.temblor * 0.045
	if actor == _jugador:
		_pose.caminando = rapidez > 0.035
		_pose.congelado = actor.congelado
		_pose.peso = move_toward(_pose.peso, 0.12 if actor.nadando else (0.4 if actor.quemandose_pies else 1.0), delta * 1.5)
	if _movimientos.has(actor):
		var viaje: Dictionary = _movimientos[actor]
		viaje.atasco = viaje.atasco + delta if rapidez < 0.025 and not actor.congelado else 0.0
		if viaje.atasco > 0.6 and _puerta.to_local(actor.global_position).z > 0.8:
			var fin: Vector3 = viaje.puntos[-1]
			var reserva := otro.global_position if otro.visible and _puerta.to_local(otro.global_position).z > 0 else Vector3.INF
			var nueva := _ruta(actor.global_position, fin, reserva)
			if not nueva.is_empty():
				viaje.puntos = nueva
				viaje.indice = 0
			viaje.atasco = 0.0


func _process(delta: float) -> void:
	if not is_instance_valid(camara) or finalizada:
		return
	camara.h_offset = 0.0
	camara.v_offset = 0.0
	if _seguir_actores:
		var foco := _puerta.global_position + Vector3(-0.6, 0.7, 0.0)
		if not jugador_salio:
			foco = foco.lerp(_jugador.global_position + Vector3.UP * 0.55, 0.5)
		var distancia := _jugador.global_position.distance_to(_puerta.global_position) if not jugador_salio else 0.0
		var altura := 2.7 + distancia * 0.38
		var posicion := Vector3(maxf(-3.8, foco.x - 2.6), altura, minf(11.8, foco.z + 3.5 + distancia * 0.15))
		if _seguir_companero:
			foco = companero.global_position + Vector3.UP * 0.55
			posicion = Vector3(clampf(foco.x - 1.4, -3.6, 1.4), 2.8, minf(foco.z + 3.0, 11.8))
		var deseada := _transform_camara(posicion, foco)
		camara.global_transform = camara.global_transform.interpolate_with(deseada, 1.0 - exp(-2.1 * delta))
	if is_instance_valid(ambiente) and bool(get_node("/root/AjustesAccesibilidad").get("balanceo_camara")):
		var t := ambiente.reloj_temblor
		camara.h_offset = sin(t * 30.7) * 0.05 * ambiente.temblor
		camara.v_offset = sin(t * 36.1) * 0.035 * ambiente.temblor
	_actualizar_burbuja()


func _transform_camara(posicion: Vector3, foco: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(foco - posicion), posicion)


func _reproducir(animador: AnimationPlayer, nombre: String, velocidad: float = 1.0) -> void:
	if not is_instance_valid(animador):
		return
	for clip: StringName in animador.get_animation_list():
		if String(clip).to_lower().ends_with(nombre):
			animador.play(clip, 0.25, velocidad)
			return


func _preparar_burbuja() -> void:
	_capa = CanvasLayer.new()
	_capa.layer = 31
	add_child(_capa)
	_punta = Polygon2D.new()
	_punta.color = Color("fff1d8")
	_punta.polygon = PackedVector2Array([Vector2(-10, 0), Vector2(10, 0), Vector2(0, 14)])
	_capa.add_child(_punta)
	_punta.hide()
	burbuja = PanelContainer.new()
	burbuja.name = "BurbujaCompanero"
	burbuja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("fff1d8")
	estilo.set_corner_radius_all(14)
	estilo.content_margin_left = 20
	estilo.content_margin_right = 20
	estilo.content_margin_top = 12
	estilo.content_margin_bottom = 14
	estilo.shadow_color = Color(0, 0, 0, 0.25)
	estilo.shadow_size = 6
	estilo.shadow_offset = Vector2(0, 3)
	burbuja.add_theme_stylebox_override("panel", estilo)
	_capa.add_child(burbuja)
	var textos := VBoxContainer.new()
	textos.add_theme_constant_override("separation", 2)
	burbuja.add_child(textos)
	var nombre := Label.new()
	var fuente_legible := FontVariation.new()
	fuente_legible.base_font = FUENTE
	fuente_legible.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 650.0}
	nombre.text = "COMPAÑERO"
	nombre.add_theme_font_override("font", fuente_legible)
	nombre.add_theme_font_size_override("font_size", 12)
	nombre.add_theme_color_override("font_color", Color("6c7b76"))
	textos.add_child(nombre)
	var frase := Label.new()
	frase.text = "Déjalo. Yo me encargo\ndesde aquí."
	frase.add_theme_font_override("font", fuente_legible)
	frase.add_theme_font_size_override("font_size", 21)
	frase.add_theme_color_override("font_color", Color("173b50"))
	textos.add_child(frase)
	burbuja.hide()


func _mostrar_dialogo() -> void:
	burbuja.show()
	_punta.show()
	burbuja.modulate.a = 0.0
	create_tween().tween_property(burbuja, "modulate:a", 1.0, 0.25)
	var voz := AudioStreamPlayer3D.new()
	voz.bus = "Interacciones"
	voz.stream = VOZ_RELEVO
	voz.volume_db = -5.0
	voz.unit_size = 8.0
	companero.add_child(voz)
	voz.play()
	_actualizar_burbuja()


func _actualizar_burbuja() -> void:
	if not is_instance_valid(burbuja) or not burbuja.visible:
		return
	var ancla := companero.global_position + Vector3.UP * 1.05
	if camara.is_position_behind(ancla):
		burbuja.modulate.a = 0.0
		_punta.hide()
		return
	var pantalla := get_viewport().get_visible_rect().size
	var punto := camara.unproject_position(ancla)
	var escala := clampf(pantalla.x / 1280.0, 0.72, 1.0)
	burbuja.scale = Vector2.ONE * escala
	var tamano := burbuja.size * escala
	burbuja.position = Vector2(clampf(punto.x - tamano.x * 0.5, 16, pantalla.x - tamano.x - 16), maxf(16, punto.y - tamano.y - 14))
	_punta.position = Vector2(clampf(punto.x, burbuja.position.x + 18, burbuja.position.x + tamano.x - 18), burbuja.position.y + tamano.y - 1)
	_punta.modulate.a = burbuja.modulate.a
