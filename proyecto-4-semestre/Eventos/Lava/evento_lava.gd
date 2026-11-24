extends Node3D

const ResolucionAvatar := preload("res://Objetos/ZonaDescanso/resolucion_avatar.gd")
var _resolucion_avatar: Node3D
var _luces_avatar: Dictionary = {}
var _panel_avatar := 1.0
var resolviendo_avatar: bool:
	get: return is_instance_valid(_resolucion_avatar)


signal iniciado
signal terminado

const DURACION := 60.0
const DURACION_ENTRADA := 3.0
const INTERVALO_BLOQUEOS := 4.0
const PERDIDA_POR_SEGUNDO := 0.7
const EXTRA_CHARCO := 0.45
const CANTIDAD_CHARCOS := 6
const PISO := 0.372
const CAPA_ANTITREPAR := Player.CAPA_MUEBLES_NO_TREPABLES
const MAGMA := preload("res://Eventos/Lava/magma.gdshader")
const PatronMagma := preload("res://Eventos/Lava/patron_magma.gd")
const PanelLava := preload("res://Eventos/Lava/panel_lava.gd")
const Fuego := preload("res://Eventos/Incendio/fuego_3d.gd")
const SONIDO_LAVA := preload("res://Audios/Eventos/lava_quemadura.wav")

var activo := false
var tiempo_restante := 0.0
var permiso_inicio: Callable
var charcos: Array[Vector3] = [] # x, z, longitud de los ramales desde la unión.
var posiciones_protegidas_red: Array[Vector3] = []
var charcos_red: Array[Vector3] = []
var usar_charcos_red := false
var panel: PanelLava
var superficie: MeshInstance3D
var _oficina: Node3D
var _jugador: Player
var _material: ShaderMaterial
var _patron: RefCounted
var _visuales: Node3D
var _barreras: Node3D
var _chispas_pies: CPUParticles3D
var _llamas_pies: Array[Node3D] = []
var _chispas_suelo: Array[CPUParticles3D] = []
var _luces_calor: Array[OmniLight3D] = []
var _calor_pies := 0.0
var _origen_calor := Vector2.ZERO
var _perdida_acumulada := 0.0
var _intervalo_anterior := 10.0
var _reloj_estaba_parado := false
var _tiempo := 0.0
var _sonido_quemadura: AudioStreamPlayer
var _tiempo_sonido_quemadura := 0.0


func configurar(oficina: Node3D, jugador: Player) -> void:
	_oficina = oficina
	_jugador = jugador
	# Preparadas una sola vez: también protegen las estaciones con dona y sin lava.
	_crear_barreras()
	_sonido_quemadura = AudioStreamPlayer.new()
	_sonido_quemadura.stream = SONIDO_LAVA
	_sonido_quemadura.bus = "Interacciones"
	_sonido_quemadura.volume_db = -9.0
	add_child(_sonido_quemadura)
	# Después del movimiento del personaje: comprobar el apoyo de este paso físico.
	process_physics_priority = 100
	panel = PanelLava.new()
	_oficina.get_node("CanvasLayer").add_child(panel)
	# Preparar las placas al cargar la oficina, antes del aviso del evento.
	_patron = PatronMagma.new(CargaEscenas.activa)
	while not _patron.preparar_lote():
		await get_tree().process_frame
	set_physics_process(false)


func iniciar() -> bool:
	if activo or (not (SesionLAN.en_partida and SesionLAN.puente.iniciando_evento) and (get_tree().paused or _jugador.input_locked or _jugador.realizando_gesto() or _jugador.esta_sentado())):
		return false
	if permiso_inicio.is_valid() and not permiso_inicio.call():
		return false
	activo = true
	tiempo_restante = DURACION
	_tiempo = 0.0
	_calor_pies = 0.0
	_tiempo_sonido_quemadura = 0.0
	_origen_calor = Vector2(_jugador.global_position.x, _jugador.global_position.z)
	_perdida_acumulada = 0.0
	_intervalo_anterior = _oficina.temporizador_bloqueos.wait_time
	_reloj_estaba_parado = _oficina.temporizador_bloqueos.is_stopped()
	_oficina.temporizador_bloqueos.start(INTERVALO_BLOQUEOS)
	_jugador.lava_activa = true
	for bloqueo: Node3D in _oficina._bloqueos_pool:
		var forma := bloqueo.get_node("CollisionShape3D") as CollisionShape3D
		var limites := forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
		_jugador.altura_bloqueo_lava = limites.size.y
		break
	_crear_visuales()
	for bloqueo: Node in _oficina.bloqueos_visuales.values():
		bloqueo.actualizar_lava(true)
	_actualizar_panel()
	panel.show()
	set_physics_process(true)
	_jugador.reproducir_expresion(&"sorpresa")
	iniciado.emit()
	return true


func _physics_process(delta: float) -> void:
	if resolviendo_avatar:
		return
	if not activo:
		return
	var paso := minf(delta, tiempo_restante)
	var anterior := _tiempo
	_tiempo += paso
	tiempo_restante = maxf(0.0, tiempo_restante - paso)
	_material.set_shader_parameter("reloj", _tiempo)
	_actualizar_entrada()
	var arde := tocando_suelo()
	if arde:
		_tiempo_sonido_quemadura -= paso
		if _tiempo_sonido_quemadura <= 0.0:
			_sonido_quemadura.play()
			_tiempo_sonido_quemadura = 0.9
	else:
		_tiempo_sonido_quemadura = 0.0
	_jugador.quemandose_pies = arde
	_chispas_pies.global_position = _jugador.global_position + Vector3.UP * 0.06
	_chispas_pies.emitting = arde
	_calor_pies = move_toward(_calor_pies, float(arde), paso * (5.0 if arde else 3.5))
	for i in _llamas_pies.size():
		var llama := _llamas_pies[i]
		llama.establecer_intensidad(_calor_pies)
		if is_instance_valid(_jugador.gestos):
			llama.global_position = _jugador.gestos.posicion_pie("L" if i == 0 else "R") + Vector3.DOWN * 0.025
	if arde:
		# Conservar fracciones entre saltos: saltos cortos no borran el daño pendiente.
		var contacto := maxf(0.0, _tiempo - maxf(anterior, DURACION_ENTRADA))
		_perdida_acumulada += contacto * (PERDIDA_POR_SEGUNDO + (EXTRA_CHARCO if en_charco(_jugador.global_position) else 0.0))
		var puntos := floori(_perdida_acumulada)
		if puntos > 0:
			_perdida_acumulada -= puntos
			_oficina.sistema_despacho.perder_calma(puntos, &"lava")
			# La pérdida puede finalizar la partida y detener el evento sincrónicamente.
			if not activo:
				return
	_actualizar_panel()
	if tiempo_restante <= 0.0:
		detener()
		terminado.emit()


func sobre_bloqueo_temporal() -> bool:
	if not _jugador.is_on_floor():
		return false
	for i in _jugador.get_slide_collision_count():
		var choque := _jugador.get_slide_collision(i)
		var cuerpo := choque.get_collider() as Node
		if is_instance_valid(cuerpo) and cuerpo.is_in_group("bloqueos_temporales") and cuerpo.collision_layer != 0 and choque.get_normal().dot(Vector3.UP) > 0.7:
			return true
	return false


func tocando_suelo() -> bool:
	if _jugador.en_relevo:
		return activo and _jugador.visible and _jugador.quemandose_pies
	return activo and not resolviendo_avatar and _tiempo >= DURACION_ENTRADA and _jugador.is_on_floor() and not _jugador.esta_sentado() and not sobre_bloqueo_temporal() and _jugador.global_position.y <= PISO + 0.10


func en_charco(punto: Vector3) -> bool:
	return activo and is_instance_valid(_patron) and _patron.contiene(Vector2(punto.x, punto.z))


func _actualizar_entrada() -> void:
	var entrada := clampf(_tiempo / DURACION_ENTRADA, 0.0, 1.0)
	_material.set_shader_parameter("presencia", entrada)
	panel.modulate.a = smoothstep(0.0, 0.35, _tiempo)
	for particulas in _chispas_suelo:
		var punto := Vector2(particulas.global_position.x, particulas.global_position.z)
		particulas.emitting = entrada > 0.35 + punto.distance_to(_origen_calor) / 24.0
	for luz in _luces_calor:
		luz.light_energy = smoothstep(0.1, 1.0, entrada) * (0.32 + 0.06 * sin(_tiempo * 2.1 + luz.position.z))


func _actualizar_panel() -> void:
	panel.actualizar(tiempo_restante)


func detener() -> void:
	_cancelar_resolucion_avatar()
	if not activo:
		return
	activo = false
	_sonido_quemadura.stop()
	set_physics_process(false)
	_jugador.lava_activa = false
	_jugador.quemandose_pies = false
	for bloqueo: Node in get_tree().get_nodes_in_group("bloqueos_temporales"):
		if _oficina.is_ancestor_of(bloqueo):
			bloqueo.actualizar_lava(false)
	_oficina.temporizador_bloqueos.wait_time = _intervalo_anterior
	if _reloj_estaba_parado or _oficina.partida_finalizada:
		_oficina.temporizador_bloqueos.stop()
	else:
		_oficina.temporizador_bloqueos.start(_intervalo_anterior)
	panel.hide()
	_visuales.hide()
	_visuales.queue_free()
	charcos.clear()
	_patron.reiniciar()
	_llamas_pies.clear()
	_chispas_suelo.clear()
	_luces_calor.clear()


func salpicar(punto: Vector3) -> void:
	if not activo or _tiempo < DURACION_ENTRADA:
		return
	var chispas := _crear_chispas(Vector3(punto.x, PISO + 0.05, punto.z), Vector3(0.28, 0, 0.28), 9)
	chispas.preprocess = 0.0
	chispas.one_shot = true
	chispas.explosiveness = 1.0
	chispas.finished.connect(chispas.queue_free)
	chispas.restart()


func _crear_visuales() -> void:
	_visuales = Node3D.new()
	_visuales.name = "MagmaYChispas"
	add_child(_visuales)
	_material = ShaderMaterial.new()
	_material.shader = MAGMA
	_material.set_shader_parameter("origen_calor", _origen_calor)
	if not is_instance_valid(_patron):
		_patron = PatronMagma.new()
	else:
		_patron.reiniciar()
	superficie = _plano(Vector2(6.86, 12.48), Vector3(-1.02, PISO + 0.012, 6.14), _material)
	superficie.name = "SuperficieMagma"
	_chispas_suelo.append(_crear_chispas(Vector3(-1.02, PISO + 0.04, 6.14), Vector3(3.4, 0, 6.2), 100))
	for z: float in [2.0, 5.4, 9.0]:
		var luz := OmniLight3D.new()
		luz.light_color = Color("ff742d")
		luz.light_energy = 0.0
		luz.omni_range = 3.1
		luz.omni_attenuation = 1.5
		luz.position = Vector3(-1.0, PISO + 0.35, z)
		_visuales.add_child(luz)
		_luces_calor.append(luz)
	var candidatos: Array[Vector2i] = []
	for fila in range(2, 23):
		for columna in range(1, 13):
			var celda := Vector2i(columna, fila)
			if _oficina.grafo_piso.es_transitable(celda) and not GrafoPiso.DESTINOS.values().has(celda):
				candidatos.append(celda)
	while not usar_charcos_red and charcos.size() < CANTIDAD_CHARCOS and not candidatos.is_empty():
		var indice: int = _oficina.generador_aleatorio.randi_range(0, candidatos.size() - 1)
		var punto: Vector3 = _oficina.grafo_piso.celda_a_posicion(candidatos.pop_at(indice))
		var cruce: Vector2 = _patron.cruce_cercano(Vector2(punto.x, punto.z))
		if not cruce.is_finite():
			continue
		punto.x = cruce.x
		punto.z = cruce.y
		var celda: Vector2i = _oficina.grafo_piso.posicion_a_celda(punto)
		if not _oficina.grafo_piso.es_transitable(celda) or GrafoPiso.DESTINOS.values().has(celda):
			continue
		if punto.distance_to(_jugador.global_position) < 1.2:
			continue
		var separado := true
		for protegido: Vector3 in posiciones_protegidas_red:
			if Vector2(punto.x - protegido.x, punto.z - protegido.z).length() < 1.2:
				separado = false
		for charco in charcos:
			if Vector2(punto.x - charco.x, punto.z - charco.y).length() < 1.35:
				separado = false
		if not separado:
			continue
		var extension: float = _oficina.generador_aleatorio.randf_range(0.88, 1.04)
		var charco := Vector3(punto.x, punto.z, extension)
		charcos.append(charco)
	if usar_charcos_red:
		charcos.assign(charcos_red)
	for charco: Vector3 in charcos:
		_patron.agregar_charco(Vector2(charco.x, charco.y), charco.z)
		_chispas_suelo.append(_crear_chispas(Vector3(charco.x, PISO + 0.05, charco.y), Vector3(0.20, 0, 0.20), 9))
	_patron.aplicar(_material)
	_chispas_pies = _crear_chispas(_jugador.global_position, Vector3(0.16, 0.015, 0.12), 16)
	_chispas_pies.emitting = false
	for i in 2:
		var fuego := Fuego.new()
		fuego.ancho = 0.35
		fuego.profundo = 0.30
		fuego.intensidad = 0.0
		fuego.scale = Vector3(0.32, 0.40, 0.32)
		_visuales.add_child(fuego)
		_llamas_pies.append(fuego)
	for particulas in _chispas_suelo:
		particulas.emitting = false
	panel.modulate.a = 0.0


func _plano(tamano: Vector2, punto: Vector3, material: Material) -> MeshInstance3D:
	var instancia := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = tamano
	instancia.mesh = plano
	instancia.material_override = material
	instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instancia.position = punto
	_visuales.add_child(instancia)
	return instancia


func _crear_chispas(punto: Vector3, extension: Vector3, cantidad: int) -> CPUParticles3D:
	var chispas := CPUParticles3D.new()
	chispas.amount = cantidad
	chispas.lifetime = 0.85
	chispas.preprocess = 0.0
	chispas.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	chispas.emission_box_extents = extension
	chispas.direction = Vector3.UP
	chispas.spread = 24.0
	chispas.initial_velocity_min = 0.25
	chispas.initial_velocity_max = 0.75
	chispas.gravity = Vector3(0, -0.65, 0)
	chispas.scale_amount_min = 0.4
	chispas.scale_amount_max = 1.0
	chispas.local_coords = false
	var malla := SphereMesh.new()
	malla.radius = 0.012
	malla.height = 0.035
	malla.radial_segments = 4
	malla.rings = 1
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	malla.material = material
	chispas.mesh = malla
	var colores := Gradient.new()
	colores.set_color(0, Color("fff0a1"))
	colores.set_color(1, Color(0.9, 0.12, 0.02, 0.0))
	colores.add_point(0.45, Color("ff8e32"))
	chispas.color_ramp = colores
	chispas.position = punto
	_visuales.add_child(chispas)
	return chispas


func _crear_barreras() -> void:
	# Impedir entrar por arriba sin rellenar los huecos entre patas al caminar.
	# La cabeza solo alcanza estas barreras al saltar, conservando los accesos con E.
	var colision_jugador := _jugador.get_node("Colision") as CollisionShape3D
	var limites_jugador := colision_jugador.global_transform * colision_jugador.shape.get_debug_mesh().get_aabb()
	var altura_libre := PISO + limites_jugador.size.y + 0.06
	_barreras = Node3D.new()
	_barreras.name = "MueblesNoTrepables"
	add_child(_barreras)
	for cuerpo: Node in _oficina.find_children("*", "StaticBody3D", true, false):
		if cuerpo.is_in_group("bloqueos_temporales") or is_ancestor_of(cuerpo):
			continue
		for colision: Node in cuerpo.get_children():
			if not colision is CollisionShape3D or colision.disabled or colision.shape == null:
				continue
			var limites: AABB = colision.global_transform * colision.shape.get_debug_mesh().get_aabb()
			if limites.end.y <= PISO + 0.12 or limites.position.y > PISO + 2.5:
				continue
			var barrera := StaticBody3D.new()
			barrera.collision_layer = 1 << (CAPA_ANTITREPAR - 1)
			barrera.collision_mask = _jugador.collision_layer
			var forma := CollisionShape3D.new()
			var caja := BoxShape3D.new()
			var base := maxf(altura_libre, limites.end.y)
			caja.size = Vector3(limites.size.x, 4.5 - base, limites.size.z)
			forma.shape = caja
			barrera.add_child(forma)
			_barreras.add_child(barrera)
			barrera.global_position = Vector3(limites.get_center().x, base + caja.size.y * 0.5, limites.get_center().z)


## Un origen inicia la transición del objeto; sin origen, limpieza inmediata de reinicio/red.
func resolver_con_avatar(origen: Variant = null) -> void:
	if not activo:
		return
	if origen is Vector3:
		if resolviendo_avatar:
			return
		_jugador.quemandose_pies = false
		_chispas_pies.emitting = false
		for llama in _llamas_pies:
			llama.establecer_intensidad(0.0)
		for chispas in _chispas_suelo:
			chispas.emitting = false
		for luz in _luces_calor:
			_luces_avatar[luz] = luz.light_energy
		_panel_avatar = panel.modulate.a
		_resolucion_avatar = ResolucionAvatar.crear(self, origen, &"vapor", _avanzar_avatar, resolver_con_avatar)
		return
	detener()
	terminado.emit()

func _avanzar_avatar(frente: Node3D) -> void:
	frente.aplicar_material(_material)
	_material.set_shader_parameter("reloj", _tiempo + frente.tiempo)
	for luz in _luces_calor:
		luz.light_energy = _luces_avatar[luz] * (1.0 - frente.peso_en(luz.global_position))
	panel.modulate.a = _panel_avatar * (1.0 - smoothstep(0.0, .6, frente.tiempo))

func _cancelar_resolucion_avatar() -> void:
	if is_instance_valid(_resolucion_avatar):
		_resolucion_avatar.cancelar()
	_resolucion_avatar = null
	_luces_avatar.clear()
