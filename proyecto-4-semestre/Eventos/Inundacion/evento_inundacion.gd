extends Node3D
## La física horizontal y el grafo permanecen anclados; solo el aspecto flota.
## Así el agua no permite atravesar mesas ni cambia las celdas de los cajones.

signal iniciado
signal terminado
const PanelTuberias := preload("res://Eventos/Inundacion/panel_tuberias.gd")
const Indicador := preload("res://Eventos/Inundacion/indicador_tuberias.gd")
const Salpicadura := preload("res://Eventos/Inundacion/salpicadura.gd")
const AGUA := preload("res://Eventos/Inundacion/agua.gdshader")
const Sonidos := preload("res://UI/Despacho/sonidos_mesas.gd")
const PISO := 0.372
const NIVEL_MAXIMO := 1.10
const SUBIDA := 4.0
const VACIADO := 4.0
const ALCANCE := 1.05

var activo := false
var drenando := false
var reparando := false
var nivel := PISO
var tiempo := 0.0
var permiso_inicio: Callable
var panel: PanelTuberias
var indicador: Indicador
var tuberias: Node3D
var acceso: Marker3D
var superficie: MeshInstance3D
var _volumen: MeshInstance3D
var _material: ShaderMaterial
var _oficina: Node3D
var _jugador: Player
var _flotantes: Array[Dictionary] = []
var _colisiones: Array[Dictionary] = []
var _reloj_ondas := 0.0
var _raton_anterior: Input.MouseMode
var _bloqueo_anterior := false
var _chorro: CPUParticles3D
var _valvula: Node3D
var _union: MeshInstance3D
var _aviso: Label
var _efectos: Node3D
var _ambiente: AudioStreamPlayer
var _salpicaduras: Array[AudioStreamPlayer] = []
var _impactos: Array[Vector4] = []
var _ultima_posicion_nado := Vector3.ZERO


func configurar(oficina: Node3D, jugador: Player) -> void:
	_oficina = oficina
	_jugador = jugador
	_jugador.control_inundacion = self
	_jugador.reset_performed.connect(_cerrar_reparacion)
	_jugador.brazada_agua.connect(_al_brazar)
	_crear_agua()
	_crear_tuberias()
	_efectos = Node3D.new()
	_efectos.name = "OndasYSalpicaduras"
	add_child(_efectos)
	var capa := CanvasLayer.new()
	capa.layer = 40
	add_child(capa)
	panel = PanelTuberias.new()
	capa.add_child(panel)
	panel.cerrado.connect(_cerrar_reparacion)
	panel.reparado.connect(_al_reparar)
	indicador = Indicador.new()
	oficina.get_node("CanvasLayer").add_child(indicador)
	_aviso = Label.new()
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_aviso.offset_left = -225
	_aviso.offset_right = 225
	_aviso.offset_top = 20
	_aviso.offset_bottom = 88
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_aviso.add_theme_font_override("font", preload("res://UI/Menus/ArtePiloto/Nunito.ttf"))
	_aviso.add_theme_font_size_override("font_size", 20)
	_aviso.add_theme_color_override("font_color", Color("d2faff"))
	_aviso.add_theme_color_override("font_outline_color", Color("102c42"))
	_aviso.add_theme_constant_override("outline_size", 2)
	var fondo_aviso := StyleBoxFlat.new()
	fondo_aviso.bg_color = Color("173b50")
	fondo_aviso.border_color = Color("76d7e7")
	fondo_aviso.set_border_width_all(2)
	fondo_aviso.set_corner_radius_all(16)
	_aviso.add_theme_stylebox_override("normal", fondo_aviso)
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oficina.get_node("CanvasLayer").add_child(_aviso)
	_aviso.hide()
	_ambiente = Sonidos.crear_reproductor(self, "AguaInundacion", preload("res://Audios/Eventos/inundacion_agua.wav"), -26.0, true)
	for i in 3:
		_salpicaduras.append(Sonidos.crear_reproductor(self, "Salpicadura%d" % i, preload("res://Audios/Eventos/inundacion_salpicadura.wav"), -20.0))
	set_process(false)
	set_physics_process(false)


func iniciar() -> bool:
	if activo or get_tree().paused or _jugador.input_locked or _jugador.realizando_gesto() or _jugador.esta_sentado():
		return false
	if permiso_inicio.is_valid() and not permiso_inicio.call():
		return false
	activo = true
	drenando = false
	nivel = PISO
	tiempo = 0.0
	_reloj_ondas = 0.0
	_impactos.clear()
	_ultima_posicion_nado = _jugador.global_position
	panel.preparar(_oficina.generador_aleatorio.randi())
	for mesa: Node3D in get_tree().get_nodes_in_group("mesas_incendiables"):
		if _oficina.is_ancestor_of(mesa):
			_registrar_flotante(mesa)
	for ruta: String in ["ZonaDescanso/SofaL", "ZonaDescanso/RinconCafe"]:
		var mueble := _oficina.get_node_or_null(ruta) as Node3D
		if mueble != null:
			_registrar_flotante(mueble)
	# La computadora independiente mantiene su cuerpo y cámara en su lugar.
	for hijo in _oficina.computador.get_children():
		if hijo is Node3D and not hijo is CollisionObject3D and not hijo is CollisionShape3D and not hijo is Camera3D:
			_registrar_flotante(hijo)
	superficie.show()
	_volumen.show()
	_chorro.emitting = true
	_union.scale.y = 0.12
	_ambiente.play()
	_aviso.show()
	set_process(true)
	set_physics_process(true)
	iniciado.emit()
	return true


func _registrar_flotante(nodo: Node3D) -> void:
	_flotantes.append({"nodo": nodo, "pose": nodo.transform, "fase": nodo.global_position.x * 1.3 + nodo.global_position.z * 0.8})
	for cuerpo: Node3D in nodo.find_children("*", "CollisionObject3D", true, false):
		_colisiones.append({"nodo": cuerpo, "pose": cuerpo.transform, "independiente": cuerpo.top_level})
		var mundo := cuerpo.global_transform
		cuerpo.top_level = true
		cuerpo.global_transform = mundo


func _physics_process(delta: float) -> void:
	if not activo:
		return
	tiempo += delta
	if drenando:
		nivel = move_toward(nivel, PISO, delta * (NIVEL_MAXIMO - PISO) / VACIADO)
	else:
		nivel = move_toward(nivel, NIVEL_MAXIMO, delta * (NIVEL_MAXIMO - PISO) / SUBIDA)
	if not _jugador.en_relevo:
		_jugador.establecer_nivel_agua(nivel)
	for papel: PapelDenuncia in get_tree().get_nodes_in_group("papeles_denuncia"):
		if _oficina.is_ancestor_of(papel):
			papel.nivel_agua = nivel + 0.025
	for bloqueo: Node3D in _oficina.bloqueos_visuales.values():
		bloqueo.actualizar_agua(nivel, tiempo)
	if drenando and is_equal_approx(nivel, PISO):
		detener()
		terminado.emit()


func _process(delta: float) -> void:
	if not activo:
		return
	var altura := maxf(0.0, nivel - PISO)
	_ambiente.volume_db = lerpf(-34.0, -26.0, altura / (NIVEL_MAXIMO - PISO))
	var peso := smoothstep(0.0, 0.25, altura)
	superficie.position.y = nivel
	_material.set_shader_parameter("reloj", tiempo)
	_material.set_shader_parameter("amplitud", 0.028 * peso)
	_material.set_shader_parameter("presencia", peso)
	_actualizar_impactos()
	for efecto: Node3D in _efectos.get_children():
		efecto.global_position.y = nivel + 0.045
	_volumen.position.y = PISO + altura * 0.5
	_volumen.scale.y = maxf(0.001, altura)
	for dato in _flotantes:
		var nodo: Node3D = dato.nodo
		if not is_instance_valid(nodo):
			continue
		var pose: Transform3D = dato.pose
		var fase: float = dato.fase
		var ola := sin(tiempo * 1.8 + fase)
		# Flotan con pequeño cabeceo: ningún mueble deriva horizontalmente.
		pose.origin.y += maxf(0, altura - 0.12) + ola * 0.017 * peso
		pose.basis = pose.basis * Basis.from_euler(Vector3(sin(tiempo * 1.4 + fase) * 0.014, 0, ola * 0.018) * peso)
		nodo.transform = pose
	_valvula.rotation.z = lerp_angle(_valvula.rotation.z, PI * 0.5 if drenando else 0.0, delta * 4)
	_union.scale.y = move_toward(_union.scale.y, 1.0 if drenando else 0.12, delta * 2.0)
	_aviso.visible = not _oficina.partida_finalizada and not reparando and not _oficina.computador.is_using and not _oficina.clasificacion_partida.visible
	_aviso.text = "INUNDACIÓN\nEl agua está bajando" if drenando else "INUNDACIÓN · Nadas más lento\nRepara las tuberías en descanso · E"
	indicador.actualizar(get_viewport().get_camera_3d(), tuberias.global_position + Vector3.UP * 0.5,
		_jugador.global_position, obtener_objetivo(_jugador) == self,
		not _oficina.partida_finalizada and not drenando and not reparando and not _oficina.computador.is_using and not _oficina.clasificacion_partida.visible)
	_reloj_ondas -= delta
	if _jugador.nadando and _jugador.visible:
		var recorrido := _jugador.global_position.distance_to(_ultima_posicion_nado)
		if (recorrido > 0.23 and _reloj_ondas <= 0.0) or _reloj_ondas < -0.9:
			_reloj_ondas = 0.25
			_ultima_posicion_nado = _jugador.global_position
			var atras := -_jugador.visual.global_basis.z.normalized() * 0.16
			salpicar(_jugador.global_position + atras, 0.32, true)


func _al_brazar(lado: String) -> void:
	if not activo or not _jugador.nadando:
		return
	var mano: Node3D = _jugador.gestos.mano_izquierda if lado == "L" else _jugador.gestos.mano_derecha
	salpicar(mano.global_position, 0.24)


func _actualizar_impactos() -> void:
	while not _impactos.is_empty() and tiempo - _impactos.front().z > 2.2:
		_impactos.pop_front()
	var datos := PackedVector4Array()
	datos.resize(32)
	for i in _impactos.size():
		datos[i] = _impactos[i]
	_material.set_shader_parameter("impactos", datos)
	_material.set_shader_parameter("cantidad_impactos", _impactos.size())


func obtener_objetivo(jugador: Player) -> Node3D:
	if not activo or drenando or reparando or jugador != _jugador or _oficina.partida_finalizada:
		return null
	var diferencia := tuberias.global_position - jugador.global_position
	diferencia.y = 0
	if diferencia.length() > ALCANCE:
		return null
	if diferencia.length() > 0.1 and jugador.visual.global_basis.z.normalized().dot(diferencia.normalized()) < 0.2:
		return null
	var origen := jugador.global_position + Vector3.UP * 0.45
	var destino := Vector3(tuberias.global_position.x, origen.y, tuberias.global_position.z)
	var consulta := PhysicsRayQueryParameters3D.create(origen, destino, 1)
	consulta.exclude = [jugador.get_rid()]
	return self if get_world_3d().direct_space_state.intersect_ray(consulta).is_empty() else null


func interactuar(jugador: Player) -> void:
	if jugador.input_locked or jugador.realizando_gesto() or get_tree().paused or obtener_objetivo(jugador) != self:
		return
	_bloqueo_anterior = jugador.input_locked
	_raton_anterior = Input.mouse_mode
	reparando = true
	jugador.input_locked = true
	jugador.velocity.x = 0
	jugador.velocity.z = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	panel.abrir()
	indicador.hide()


func _cerrar_reparacion() -> void:
	if not reparando:
		return
	reparando = false
	panel.cerrar()
	_jugador.input_locked = _bloqueo_anterior or _oficina.partida_finalizada
	Input.mouse_mode = _raton_anterior


func _al_reparar() -> void:
	if not activo or drenando or not panel.red.resuelta:
		return
	_cerrar_reparacion()
	drenando = true
	_chorro.emitting = false
	indicador.hide()
	_oficina.anuncios.mostrar_evento("TUBERÍAS", "REPARADAS", "El agua está bajando")


func salpicar(punto: Vector3, fuerza: float = 1.0, solo_ondas := false) -> void:
	if not activo or nivel < PISO + 0.05:
		return
	var efecto := Salpicadura.new()
	efecto.intensidad = fuerza
	efecto.solo_ondas = solo_ondas
	_efectos.add_child(efecto)
	efecto.global_position = Vector3(punto.x, nivel + 0.045, punto.z)
	if _impactos.size() == 32:
		_impactos.pop_front()
	_impactos.append(Vector4(punto.x, punto.z, tiempo, fuerza))
	if solo_ondas:
		return
	for sonido in _salpicaduras:
		if not sonido.playing:
			sonido.volume_db = -20.0 if fuerza >= 1.0 else -29.0
			sonido.pitch_scale = 0.95 + sin(tiempo * 2.1) * 0.08
			sonido.play()
			break


func detener() -> void:
	_cerrar_reparacion()
	activo = false
	drenando = false
	nivel = PISO
	_impactos.clear()
	set_process(false)
	set_physics_process(false)
	if is_instance_valid(_jugador):
		_jugador.establecer_nivel_agua(-INF)
	for dato in _flotantes:
		if is_instance_valid(dato.nodo):
			dato.nodo.transform = dato.pose
	_flotantes.clear()
	for dato in _colisiones:
		if is_instance_valid(dato.nodo):
			dato.nodo.top_level = dato.independiente
			dato.nodo.transform = dato.pose
	_colisiones.clear()
	for bloqueo: Node3D in _oficina.bloqueos_visuales.values():
		bloqueo.actualizar_agua(-INF, 0)
	for papel: PapelDenuncia in get_tree().get_nodes_in_group("papeles_denuncia"):
		if _oficina.is_ancestor_of(papel):
			papel.nivel_agua = -INF
	superficie.hide()
	_volumen.hide()
	_chorro.emitting = false
	_ambiente.stop()
	_union.scale.y = 1.0
	for sonido in _salpicaduras:
		sonido.stop()
	_aviso.hide()
	indicador.hide()
	panel.cerrar()
	for efecto in _efectos.get_children():
		efecto.queue_free()


func _crear_agua() -> void:
	superficie = MeshInstance3D.new()
	superficie.name = "SuperficieAgua"
	var plano := PlaneMesh.new()
	plano.size = Vector2(6.86, 12.48)
	plano.subdivide_width = 96
	plano.subdivide_depth = 160
	superficie.mesh = plano
	_material = ShaderMaterial.new()
	_material.shader = AGUA
	superficie.material_override = _material
	superficie.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	superficie.position = Vector3(-1.02, PISO, 6.14)
	add_child(superficie)
	superficie.hide()
	_volumen = MeshInstance3D.new()
	var volumen := BoxMesh.new()
	volumen.size = Vector3(6.85, 1, 12.47)
	_volumen.mesh = volumen
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.12, 0.65, 0.64, 0.12)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_volumen.material_override = material
	_volumen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_volumen.position = superficie.position
	add_child(_volumen)
	_volumen.hide()


func _crear_tuberias() -> void:
	tuberias = Node3D.new()
	tuberias.name = "TuberiasDescanso"
	add_child(tuberias)
	tuberias.position = Vector3(2.12, 1.30, 10.60)
	tuberias.rotation.y = -PI * 0.5
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("63a8b8")
	metal.metallic = 0.6
	metal.roughness = 0.3
	for datos: Array in [[Vector3(-0.34, 0, 0), 1.0, false], [Vector3(0.34, -0.23, 0), 0.55, false], [Vector3(0, 0.46, 0), 0.68, true]]:
		var tramo := MeshInstance3D.new()
		var tubo := CylinderMesh.new()
		tubo.top_radius = 0.065
		tubo.bottom_radius = 0.065
		tubo.height = datos[1]
		tramo.mesh = tubo
		tramo.position = datos[0]
		tramo.rotation.z = PI * 0.5 if datos[2] else 0
		tramo.material_override = metal
		tuberias.add_child(tramo)
	_union = MeshInstance3D.new()
	_union.name = "UnionReparada"
	var manguito := CylinderMesh.new()
	manguito.top_radius = 0.073
	manguito.bottom_radius = 0.073
	manguito.height = 0.42
	_union.mesh = manguito
	_union.material_override = metal
	_union.position = Vector3(0.34, 0.25, 0)
	tuberias.add_child(_union)
	_valvula = Node3D.new()
	_valvula.position = Vector3(-0.34, 0.12, 0.1)
	tuberias.add_child(_valvula)
	var aro := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.12
	toro.outer_radius = 0.16
	aro.mesh = toro
	aro.rotation.x = PI * 0.5
	var rojo := StandardMaterial3D.new()
	rojo.albedo_color = Color("ff945f")
	aro.material_override = rojo
	_valvula.add_child(aro)
	for i in 3:
		var radio := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = Vector3(0.27, 0.025, 0.025)
		radio.mesh = caja
		radio.rotation.z = i * TAU / 3
		radio.material_override = rojo
		_valvula.add_child(radio)
	var rotulo := Label3D.new()
	rotulo.text = "TUBERÍAS"
	rotulo.font_size = 44
	rotulo.pixel_size = 0.003
	rotulo.position = Vector3(0, 0.75, 0.05)
	rotulo.modulate = Color("d2faff")
	tuberias.add_child(rotulo)
	_chorro = CPUParticles3D.new()
	_chorro.emitting = false
	_chorro.amount = 38
	_chorro.lifetime = 0.65
	_chorro.direction = Vector3(0.1, 0.25, 1)
	_chorro.spread = 14
	_chorro.initial_velocity_min = 0.8
	_chorro.initial_velocity_max = 1.4
	_chorro.gravity = Vector3(0, -3, 0)
	_chorro.position = Vector3(0.34, 0.18, 0)
	var gota := SphereMesh.new()
	gota.radius = 0.022
	gota.height = 0.065
	var agua := StandardMaterial3D.new()
	agua.albedo_color = Color("9ee9f2")
	agua.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gota.material = agua
	_chorro.mesh = gota
	tuberias.add_child(_chorro)
	acceso = Marker3D.new()
	acceso.name = "AccesoTuberias"
	acceso.add_to_group("accesos_navegacion")
	acceso.position = Vector3(1.5, PISO, tuberias.position.z)
	add_child(acceso)
