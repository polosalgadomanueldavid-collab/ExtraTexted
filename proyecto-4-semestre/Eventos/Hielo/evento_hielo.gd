extends Node3D

signal iniciado
signal terminado
const TuberiaRompible := preload("res://Eventos/Tuberias/tuberia_rompible.gd")
const PanelNitrogeno := preload("res://Eventos/Hielo/panel_nitrogeno.gd")
const PanelHielo := preload("res://Eventos/Hielo/panel_hielo.gd")
const Capsula := preload("res://Eventos/Hielo/capsula_hielo.gd")
const Indicador := preload("res://Eventos/Hielo/indicador_nitrogeno.gd")
const SUELO := preload("res://Eventos/Hielo/suelo_hielo.gdshader")
const ESCARCHA := preload("res://Eventos/Hielo/escarcha.gdshader")
const NieveAcumulada := preload("res://Eventos/Hielo/nieve_acumulada.gd")
const MONTICULOS := preload("res://Eventos/Hielo/monticulos_nieve.gdshader")
const PISO := 0.372
const ENTRADA := 3.0
const INTERVALO := 4.0
const CONGELACION := 1.25
const DESHIELO := 2.5
const ALCANCE := 1.05

var activo := false
var reparando := false
var descongelando := false
var tiempo := 0.0
var permiso_inicio: Callable
var panel: PanelNitrogeno
var aviso: PanelHielo
var indicador: Indicador
var tuberia: TuberiaRompible
var acceso: Marker3D
var superficie: MeshInstance3D
var capsula: Capsula
var _oficina: Node3D
var _jugador: Player
var _material: ShaderMaterial
var _escarcha: ShaderMaterial
var _material_nieve: ShaderMaterial
var _monticulos: Array[MeshInstance3D] = []
var _generador_nieve := NieveAcumulada.new()
var nieve_preparada := false
var _recubiertos: Array[Dictionary] = []
var _visuales: Node3D
var _nieve: CPUParticles3D
var _fuga: CPUParticles3D
var _luces: Array[Dictionary] = []
var _tiempo_deshielo := 0.0
var _presencia_al_reparar := 1.0
var _raton_anterior: Input.MouseMode
var _bloqueo_anterior := false


func configurar(oficina: Node3D, jugador: Player) -> void:
	_oficina = oficina
	_jugador = jugador
	jugador.control_hielo = self
	jugador.reset_performed.connect(_cerrar_reparacion)
	# La congelación se decide antes de que el personaje integre el movimiento.
	process_physics_priority = -100
	_crear_tuberia()
	var capa := CanvasLayer.new()
	capa.layer = 40
	add_child(capa)
	panel = PanelNitrogeno.new()
	capa.add_child(panel)
	panel.cerrado.connect(_cerrar_reparacion)
	panel.reparado.connect(_al_reparar)
	aviso = PanelHielo.new()
	oficina.get_node("CanvasLayer").add_child(aviso)
	indicador = Indicador.new()
	oficina.get_node("CanvasLayer").add_child(indicador)
	indicador.name = "IndicadorNitrogeno"
	indicador.rotulo = "NITRÓGENO"
	set_physics_process(false)
	set_process(false)
	_preparar_nieve.call_deferred()


func iniciar() -> bool:
	if activo or (not (SesionLAN.en_partida and SesionLAN.puente.iniciando_evento) and (get_tree().paused or _jugador.input_locked or _jugador.realizando_gesto() or _jugador.esta_sentado())):
		return false
	if permiso_inicio.is_valid() and not permiso_inicio.call():
		return false
	activo = true
	descongelando = false
	tiempo = 0.0
	_tiempo_deshielo = 0.0
	_jugador.hielo_activo = true
	_jugador.congelado = false
	panel.preparar(_oficina.generador_aleatorio.randi())
	_crear_visuales()
	_recubrir_mobiliario()
	for luz: Node in _oficina.find_children("*", "Light3D", true, false):
		_luces.append({"nodo": luz, "color": luz.light_color})
	tuberia.romper()
	set_physics_process(true)
	set_process(true)
	aviso.actualizar(INTERVALO, false, false, INTERVALO)
	aviso.show()
	_jugador.reproducir_expresion(&"sorpresa")
	iniciado.emit()
	return true


func _physics_process(delta: float) -> void:
	if not activo:
		return
	tiempo += delta
	var presencia := minf(1.0, tiempo / ENTRADA)
	var fase := fposmod(tiempo, INTERVALO)
	if not _jugador.en_relevo:
		_jugador.congelado = not descongelando and tiempo >= INTERVALO and fase < CONGELACION
	if descongelando:
		_tiempo_deshielo += delta
		presencia = _presencia_al_reparar * (1.0 - clampf(_tiempo_deshielo / DESHIELO, 0.0, 1.0))
	_material.set_shader_parameter("presencia", presencia)
	_escarcha.set_shader_parameter("presencia", presencia)
	_material_nieve.set_shader_parameter("presencia", presencia)
	for dato in _luces:
		if is_instance_valid(dato.nodo):
			dato.nodo.light_color = dato.color.lerp(Color("85afff"), presencia * 0.68)
	var restante := CONGELACION - fase if _jugador.congelado else INTERVALO - fase
	var duracion := CONGELACION if _jugador.congelado else INTERVALO
	if not _jugador.congelado and tiempo >= INTERVALO:
		duracion = INTERVALO - CONGELACION
	aviso.actualizar(restante, _jugador.congelado, descongelando, duracion)
	if descongelando and _tiempo_deshielo >= DESHIELO:
		detener()
		terminado.emit()


func _process(_delta: float) -> void:
	var disponible: bool = activo and not _oficina.partida_finalizada and not reparando and not _oficina.computador.is_using and not _oficina.clasificacion_partida.visible and not _oficina.clasificador_evidencias.visible and not _oficina.escaner_verificacion.visible
	aviso.visible = disponible and not descongelando
	indicador.actualizar(get_viewport().get_camera_3d(), tuberia.global_position + Vector3.UP * 0.45,
		_jugador.global_position, obtener_objetivo(_jugador) == self, disponible and not descongelando)


func obtener_objetivo(jugador: Player) -> Node3D:
	if not activo or descongelando or reparando or jugador != _jugador or _oficina.partida_finalizada:
		return null
	var diferencia := tuberia.global_position - jugador.global_position
	diferencia.y = 0
	if diferencia.length() > ALCANCE:
		return null
	if diferencia.length() > 0.1 and jugador.visual.global_basis.z.normalized().dot(diferencia.normalized()) < 0.2:
		return null
	var origen := jugador.global_position + Vector3.UP * 0.45
	var destino := tuberia.cuerpo.global_position
	var consulta := PhysicsRayQueryParameters3D.create(origen, destino, 1)
	consulta.exclude = [jugador.get_rid()]
	var impacto := get_world_3d().direct_space_state.intersect_ray(consulta)
	return self if impacto.is_empty() or tuberia.is_ancestor_of(impacto.collider) else null


func interactuar(jugador: Player) -> void:
	if SesionLAN.en_partida and not SesionLAN.puente.reservar_confirmada("hielo"):
		SesionLAN.puente.reservar_local("hielo", func(): interactuar(jugador))
		return
	if jugador.input_locked or jugador.realizando_gesto() or get_tree().paused or obtener_objetivo(jugador) != self:
		if SesionLAN.en_partida:
			SesionLAN.puente.liberar_local("hielo")
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
	aviso.hide()


func _cerrar_reparacion() -> void:
	if not reparando:
		return
	reparando = false
	if SesionLAN.en_partida:
		SesionLAN.puente.liberar_local("hielo")
	panel.cerrar()
	_jugador.input_locked = _bloqueo_anterior or _oficina.partida_finalizada
	Input.mouse_mode = _raton_anterior


func _al_reparar() -> void:
	if SesionLAN.en_partida and not SesionLAN.puente.aplicando:
		SesionLAN.solicitar("reparar", {"objetivo": "hielo"})
		return
	if not activo or descongelando or not panel.resuelto:
		return
	_cerrar_reparacion()
	descongelando = true
	_tiempo_deshielo = 0.0
	_presencia_al_reparar = minf(1.0, tiempo / ENTRADA)
	_jugador.congelado = false
	tuberia.sellar()
	_nieve.emitting = false
	_oficina.anuncios.mostrar_evento("¡FUGA", "SELLADA!", "El hielo se está derritiendo")


func detener() -> void:
	_cerrar_reparacion()
	if not activo:
		return
	activo = false
	descongelando = false
	set_physics_process(false)
	set_process(false)
	_jugador.hielo_activo = false
	_jugador.congelado = false
	if is_instance_valid(_jugador.animation_player):
		_jugador.animation_player.speed_scale = 1.0
	for dato in _recubiertos:
		if is_instance_valid(dato.nodo):
			dato.nodo.material_overlay = dato.material
	_recubiertos.clear()
	for monticulo in _monticulos:
		if is_instance_valid(monticulo):
			monticulo.hide()
			monticulo.queue_free()
	_monticulos.clear()
	for dato in _luces:
		if is_instance_valid(dato.nodo):
			dato.nodo.light_color = dato.color
	_luces.clear()
	tuberia.restablecer()
	_visuales.hide()
	_visuales.queue_free()
	aviso.hide()
	indicador.hide()
	panel.cerrar()


func _crear_visuales() -> void:
	_visuales = Node3D.new()
	_visuales.name = "HieloYNieve"
	add_child(_visuales)
	_material = ShaderMaterial.new()
	_material.shader = SUELO
	var origen_fuga := tuberia.salida.global_position
	_material.set_shader_parameter("origen", Vector2(origen_fuga.x, origen_fuga.z))
	# El plano transparente se dibuja antes que la cápsula y la nieve.
	# Evita que el suelo tape las caras del iceberg que no tienen al policía detrás.
	_material.render_priority = -20
	_escarcha = ShaderMaterial.new()
	_escarcha.shader = ESCARCHA
	_material_nieve = ShaderMaterial.new()
	_material_nieve.shader = MONTICULOS
	_material_nieve.render_priority = 1
	superficie = MeshInstance3D.new()
	superficie.name = "PisoCongelado"
	var plano := PlaneMesh.new()
	plano.size = Vector2(6.86, 12.48)
	superficie.mesh = plano
	superficie.material_override = _material
	superficie.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	superficie.position = Vector3(-1.02, PISO + 0.014, 6.14)
	_visuales.add_child(superficie)
	capsula = Capsula.new()
	capsula.jugador = _jugador
	_visuales.add_child(capsula)
	_nieve = _particulas(95, Color("e2efff"), 0.014)
	_nieve.lifetime = 4.5
	_nieve.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_nieve.emission_box_extents = Vector3(3.35, 0.3, 6.1)
	_nieve.position = Vector3(-1.02, 3.1, 6.14)
	_nieve.direction = Vector3(-0.2, -1, 0.1)
	_nieve.initial_velocity_min = 0.35
	_nieve.initial_velocity_max = 0.65
	_nieve.gravity = Vector3(0.03, -0.16, 0)
	_visuales.add_child(_nieve)
	_nieve.emitting = true


func _raices_mobiliario() -> Array[Node]:
	var raices: Array[Node] = []
	for mesa: Node in get_tree().get_nodes_in_group("mesas_incendiables"):
		if _oficina.is_ancestor_of(mesa):
			raices.append(mesa)
	raices.append(_oficina.computador)
	var descanso := _oficina.get_node_or_null("ZonaDescanso")
	if is_instance_valid(descanso):
		raices.append(descanso)
	# Recubrir el pool entero: la nieve sigue al cajón durante su caída y reciclaje.
	for bloqueo: Node in _oficina._bloqueos_pool:
		raices.append(bloqueo)
	return raices


func _preparar_nieve() -> void:
	# Preparar entre cuadros al cargar la oficina, antes de sortear el evento.
	# La segunda pasada incluye el pool que se construye gradualmente.
	var limite := Time.get_ticks_usec() + 3000
	for pasada in 2:
		if pasada == 1:
			while _oficina._bloqueos_pool.size() < _oficina.BLOQUEOS_SIMULTANEOS:
				await get_tree().process_frame
				if not is_inside_tree() or activo:
					return
		for raiz in _raices_mobiliario():
			if not is_instance_valid(raiz):
				continue
			var mallas := raiz.find_children("*", "MeshInstance3D", true, false)
			if raiz is MeshInstance3D:
				mallas.push_front(raiz)
			for candidata in mallas:
				if activo:
					return
				if not is_instance_valid(candidata):
					continue
				var malla := candidata as MeshInstance3D
				if malla.get_viewport() != _oficina.get_viewport():
					continue
				while not _generador_nieve.preparar_lote(malla):
					await get_tree().process_frame
					if not is_inside_tree() or activo or not is_instance_valid(malla):
						return
					limite = Time.get_ticks_usec() + 3000
				_generador_nieve.crear(malla, null, true)
				if Time.get_ticks_usec() >= limite:
					await get_tree().process_frame
					limite = Time.get_ticks_usec() + 3000
				if not is_inside_tree():
					return
	nieve_preparada = true


func _recubrir_mobiliario() -> void:
	for raiz in _raices_mobiliario():
		if raiz is MeshInstance3D:
			_recubrir(raiz)
		for malla: Node in raiz.find_children("*", "MeshInstance3D", true, false):
			_recubrir(malla)


func recubrir_bloqueo(bloqueo: Node) -> void:
	if activo:
		for malla: Node in bloqueo.find_children("*", "MeshInstance3D", true, false):
			_recubrir(malla)


func _recubrir(malla: MeshInstance3D) -> void:
	if malla.mesh == null or malla.has_meta(NieveAcumulada.MARCA) or malla.get_viewport() != _oficina.get_viewport():
		return
	for dato in _recubiertos:
		if dato.nodo == malla:
			return
	_recubiertos.append({"nodo": malla, "material": malla.material_overlay})
	malla.material_overlay = _escarcha
	var monticulo := _generador_nieve.crear(malla, _material_nieve)
	if monticulo != null:
		_monticulos.append(monticulo)


func _particulas(cantidad: int, color: Color, radio: float) -> CPUParticles3D:
	var particulas := CPUParticles3D.new()
	particulas.emitting = false
	particulas.amount = cantidad
	particulas.spread = 20
	particulas.scale_amount_min = 0.4
	particulas.scale_amount_max = 1.0
	var copo := SphereMesh.new()
	copo.radius = radio
	copo.height = radio * 2
	copo.radial_segments = 4
	copo.rings = 1
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	copo.material = material
	particulas.mesh = copo
	var rampa := Gradient.new()
	rampa.set_color(0, Color(color, 0.0))
	rampa.add_point(0.15, color)
	rampa.add_point(0.65, color)
	rampa.set_color(1, Color(color, 0.0))
	particulas.color_ramp = rampa
	return particulas


func _crear_tuberia() -> void:
	tuberia = _oficina.get_node_or_null("TuberiaNitrogeno") as TuberiaRompible
	if tuberia == null:
		push_error("No se encontró la estación TuberiaNitrogeno en la escena de oficina.")
		return
	_fuga = tuberia.chorro
	acceso = Marker3D.new()
	acceso.name = "AccesoNitrogeno"
	acceso.add_to_group("accesos_navegacion")
	acceso.position = Vector3(1.42, PISO, tuberia.position.z)
	add_child(acceso)


func resolver_con_avatar() -> void:
	if not activo:
		return
	detener()
	terminado.emit()
