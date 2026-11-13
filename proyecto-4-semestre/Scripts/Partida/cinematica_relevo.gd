extends Node3D
## Dirige el relevo con la simulación de la partida detenida.

signal terminada

const MODELO_RELEVO := preload("res://Personajes/PoliciaRelevo/ModeloRelevo.tscn")
const POSE_AGOTADA := preload("res://Personajes/PoliciaAzul/pose_agotada.gd")
const FUENTE := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
const VOZ_RELEVO := preload("res://Audios/VozPersonaje/Gomosa/saludo.wav")

var companero: Node3D
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


func iniciar(jugador: Player, puerta: Node3D, grafo: GrafoPiso) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_jugador = jugador
	_puerta = puerta
	_preparar_jugador()
	_preparar_camara()
	_preparar_companero()
	_preparar_burbuja()
	_preparar_recorridos(grafo)
	_secuencia()


func _preparar_jugador() -> void:
	_jugador.input_locked = true
	_jugador.velocity = Vector3.ZERO
	_jugador.sonido_pasos.detener()
	_jugador.terminar_descanso_sentado(true)
	_jugador.establecer_taza_en_mano(false)
	if is_instance_valid(_jugador.gestos):
		_jugador.gestos.cancelar()
		_jugador.gestos.active = false
	# Solo el modelo se anima durante la pausa; no se reactiva el controlador.
	var esqueleto := _jugador.visual.find_child("Skeleton3D", true, false) as Skeleton3D
	esqueleto.process_mode = Node.PROCESS_MODE_ALWAYS
	_pose = POSE_AGOTADA.new()
	esqueleto.add_child(_pose)
	_jugador.animation_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_reproducir(_jugador.animation_player, "idle", 0.7)
	create_tween().tween_property(_pose, "peso", 1.0, 0.8)
	# El final también puede producirse durante un salto o una caída.
	create_tween().tween_property(_jugador, "global_position:y", _puerta.global_position.y, 0.55)


func _preparar_camara() -> void:
	var anterior := get_viewport().get_camera_3d()
	camara = Camera3D.new()
	camara.name = "CamaraRelevo"
	add_child(camara)
	camara.global_transform = anterior.global_transform
	camara.fov = anterior.fov
	camara.environment = anterior.environment.duplicate() as Environment
	camara.environment.ambient_light_energy = 0.6
	camara.cull_mask = anterior.cull_mask
	camara.near = 0.05
	camara.make_current()


func _preparar_companero() -> void:
	companero = MODELO_RELEVO.instantiate() as Node3D
	companero.name = "CompaneroRelevo"
	add_child(companero)
	companero.scale = _jugador.scale
	companero.global_position = _puerta.to_global(Vector3(0.0, 0.0, -0.85))
	companero.rotation.y = _puerta.global_rotation.y
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
	_reproducir(_animador, "walk")
	var interior := _puerta.to_global(Vector3(-0.24, 0, 0.95))
	var entrada := create_tween()
	entrada.tween_method(_mover_actor.bind(companero, companero), companero.global_position, interior, 1.5)
	# Ambos desplazamientos pertenecen a la misma escena: el compañero entra
	# mientras el jugador abandona su puesto, con la cabeza y los hombros caídos.
	_salir_jugador()
	await entrada.finished
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
	# El relevo espera junto a la puerta hasta poder cruzarse en el espacio
	# despejado del fondo, sin atravesar al jugador en los pasillos estrechos.
	while _jugador.global_position.distance_to(interior) > 2.0 and not jugador_salio:
		await get_tree().process_frame
	_ocupar_puesto()
	while not jugador_salio:
		await get_tree().process_frame
	await _puerta.cerrar().finished
	_seguir_companero = true
	while not companero_llego:
		await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	_seguir_actores = false
	await get_tree().create_timer(0.45).timeout
	finalizada = true
	terminada.emit()


func _preparar_recorridos(grafo: GrafoPiso) -> void:
	var altura := _puerta.global_position.y
	var inicio := grafo.celda_de_acceso(_jugador.global_position)
	var interior := _puerta.to_global(Vector3(0.24, 0, 1.05))
	var destino := grafo.celda_de_acceso(interior)
	_recorrido_salida.append(Vector3(_jugador.global_position.x, altura, _jugador.global_position.z))
	_recorrido_salida.append_array(_ruta_por_el_piso(grafo, inicio, destino, altura))
	_recorrido_salida.append(interior)
	# Dos lados del umbral dejan espacio para el cruce de ambos personajes.
	_recorrido_salida.append(_puerta.to_global(Vector3(0.16, 0, 0.15)))
	_recorrido_salida.append(_puerta.to_global(Vector3(0.16, 0, -1.05)))
	_recorrido_entrada.append(_puerta.to_global(Vector3(-0.24, 0, 0.95)))
	# El compañero se aparta hacia el centro del área de descanso al cruzarse.
	# Desde allí retoma las mismas celdas seguras hacia el puesto vacante.
	var cruce := _puerta.to_global(Vector3(-0.65, 0, 1.85))
	_recorrido_entrada.append(cruce)
	_recorrido_entrada.append_array(_ruta_por_el_piso(grafo, grafo.celda_de_acceso(cruce), inicio, altura))
	# La última posición conserva exactamente el puesto del jugador, incluso
	# si perdió la calma junto a la puerta.
	_recorrido_entrada.append(_recorrido_salida[0])


func _ruta_por_el_piso(grafo: GrafoPiso, inicio: Vector2i, fin: Vector2i, altura: float) -> PackedVector3Array:
	var puntos := PackedVector3Array()
	for celda: Vector2i in grafo.calcular_ruta(inicio, fin):
		var punto := grafo.celda_a_posicion(celda)
		punto.y = altura
		puntos.append(punto)
	return puntos


func _salir_jugador() -> void:
	_pose.set("caminando", true)
	_reproducir(_jugador.animation_player, "walk", 0.62)
	var salida := _recorrer(_jugador, _jugador.visual, _recorrido_salida, 0.85)
	salida.finished.connect(func() -> void:
		_jugador.hide()
		jugador_salio = true
		_pose.set("caminando", false)
		_reproducir(_jugador.animation_player, "idle", 0.7)
	)


func _ocupar_puesto() -> void:
	_reproducir(_animador, "walk", 1.0)
	var entrada := _recorrer(companero, companero, _recorrido_entrada, 1.35)
	entrada.finished.connect(func() -> void:
		companero_llego = true
		_reproducir(_animador, "idle")
	)


func _recorrer(actor: Node3D, visual: Node3D, puntos: PackedVector3Array, velocidad: float) -> Tween:
	var movimiento := create_tween()
	var anterior := actor.global_position
	for punto: Vector3 in puntos:
		var distancia := anterior.distance_to(punto)
		if distancia < 0.025:
			continue
		movimiento.tween_method(_mover_actor.bind(actor, visual), anterior, punto, distancia / velocidad)
		anterior = punto
	# Un recorrido de longitud cero sigue emitiendo finished.
	movimiento.tween_interval(0.05)
	return movimiento


func _mover_actor(posicion: Vector3, actor: Node3D, visual: Node3D) -> void:
	var direccion := posicion - actor.global_position
	if direccion.length_squared() > 0.000001:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direccion.x, direccion.z), 0.22)
	actor.global_position = posicion


func _process(delta: float) -> void:
	if not is_instance_valid(camara) or finalizada:
		return
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
