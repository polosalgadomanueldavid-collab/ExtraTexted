extends Node3D

const ResolucionAvatar := preload("res://Objetos/ZonaDescanso/resolucion_avatar.gd")
var _resolucion_avatar: Node3D
var resolviendo_avatar: bool:
	get: return is_instance_valid(_resolucion_avatar)


## Los muebles conservan sus obstáculos de navegación mientras flotan.
## La alfombra tiene una colisión móvil que acompaña su superficie en el agua.

signal iniciado
signal terminado
const TuberiaRompible := preload("res://Eventos/Tuberias/tuberia_rompible.gd")
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
var _nivel_avatar := PISO
var nivel := PISO
var tiempo := 0.0
var permiso_inicio: Callable
var panel: PanelTuberias
var indicador: Indicador
var tuberias: TuberiaRompible
var acceso: Marker3D
var superficie: MeshInstance3D
var _volumen: MeshInstance3D
var _material: ShaderMaterial
var _oficina: Node3D
var _jugador: Player
var _flotantes: Array[Dictionary] = []
var _colisiones: Array[Dictionary] = []
var _alfombra: Node3D
var _colision_alfombra: AnimatableBody3D
var _forma_alfombra: BoxShape3D
var _centro_alfombra := Vector3.ZERO
var _reloj_ondas := 0.0
var _raton_anterior: Input.MouseMode
var _bloqueo_anterior := false
var _chorro: CPUParticles3D
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
	_crear_colision_alfombra()
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
	_ambiente = Sonidos.crear_reproductor(self, "AguaInundacion", preload("res://Audios/Eventos/inundacion_agua.wav"), -26.0, true)
	for i in 3:
		_salpicaduras.append(Sonidos.crear_reproductor(self, "Salpicadura%d" % i, preload("res://Audios/Eventos/inundacion_salpicadura.wav"), -20.0))
	set_process(false)
	set_physics_process(false)


func iniciar() -> bool:
	if activo or (not (SesionLAN.en_partida and SesionLAN.puente.iniciando_evento) and (get_tree().paused or _jugador.input_locked or _jugador.realizando_gesto() or _jugador.esta_sentado())):
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
	for ruta: String in ["ZonaDescanso/SofaL", "ZonaDescanso/RinconCafe", "MaquinaExpendedora/Modelo", "PlantaEsquinaCuadranteInferior"]:
		var mueble := _oficina.get_node_or_null(ruta) as Node3D
		if mueble != null:
			_registrar_flotante(mueble)
	if is_instance_valid(_alfombra):
		# El tapete es delgado: debe quedar sobre las olas, no sumergido como las patas.
		_registrar_flotante(_alfombra, -0.045)
	# La computadora independiente mantiene su cuerpo y cámara en su lugar.
	for hijo in _oficina.computador.get_children():
		if hijo is Node3D and not hijo is CollisionObject3D and not hijo is CollisionShape3D and not hijo is Camera3D:
			_registrar_flotante(hijo)
	superficie.show()
	_volumen.show()
	tuberias.romper()
	_ambiente.play()
	set_process(true)
	set_physics_process(true)
	iniciado.emit()
	return true


func _registrar_flotante(nodo: Node3D, calado := 0.12) -> void:
	_flotantes.append({"nodo": nodo, "pose": nodo.transform, "fase": nodo.global_position.x * 1.3 + nodo.global_position.z * 0.8, "calado": calado})
	for cuerpo: Node3D in nodo.find_children("*", "CollisionObject3D", true, false):
		_colisiones.append({"nodo": cuerpo, "pose": cuerpo.transform, "independiente": cuerpo.top_level})
		var mundo := cuerpo.global_transform
		cuerpo.top_level = true
		cuerpo.global_transform = mundo


func _crear_colision_alfombra() -> void:
	_alfombra = _oficina.get_node_or_null("AlfombraCentro") as Node3D
	if _alfombra == null:
		return
	var limites := AABB()
	var primera := true
	for malla: MeshInstance3D in _alfombra.find_children("*", "MeshInstance3D", true, false):
		var local := _alfombra.global_transform.affine_inverse() * malla.global_transform * malla.get_aabb()
		limites = local if primera else limites.merge(local)
		primera = false
	if primera:
		return
	_centro_alfombra = limites.get_center()
	_forma_alfombra = BoxShape3D.new()
	_forma_alfombra.size = limites.size * _alfombra.global_basis.get_scale().abs()
	_colision_alfombra = AnimatableBody3D.new()
	_colision_alfombra.name = "ColisionAlfombraFlotante"
	_colision_alfombra.sync_to_physics = false
	_colision_alfombra.collision_layer = 0
	_colision_alfombra.collision_mask = _jugador.collision_layer
	add_child(_colision_alfombra)
	var forma := CollisionShape3D.new()
	forma.shape = _forma_alfombra
	_colision_alfombra.add_child(forma)
	_actualizar_colision_alfombra(0.0)


func _actualizar_colision_alfombra(altura: float) -> void:
	if not is_instance_valid(_colision_alfombra):
		return
	# El personaje nada visualmente, pero su cuerpo físico sigue en el suelo.
	# Cubrir hasta el piso impide que pase por debajo del tapete. La huella se
	# mantiene horizontal para que el cabeceo no cree rampas en sus bordes.
	var centro := _alfombra.to_global(_centro_alfombra)
	_forma_alfombra.size.y = maxf(0.02, centro.y + 0.02 - PISO)
	centro.y = PISO + _forma_alfombra.size.y * 0.5
	_colision_alfombra.global_transform = Transform3D(Basis.IDENTITY, centro)
	_colision_alfombra.collision_layer = 1 if activo and altura > 0.055 else 0


func _actualizar_flotantes() -> void:
	var altura := maxf(0.0, nivel - PISO)
	var peso := smoothstep(0.0, 0.25, altura)
	for dato in _flotantes:
		var nodo: Node3D = dato.nodo
		if not is_instance_valid(nodo):
			continue
		var pose: Transform3D = dato.pose
		var fase: float = dato.fase
		var ola := sin(tiempo * 1.8 + fase)
		var calado: float = dato.calado
		# Flotan con pequeño cabeceo: ningún mueble deriva horizontalmente.
		pose.origin.y += maxf(0.0, altura - maxf(calado, 0.0)) + (maxf(-calado, 0.0) + ola * 0.017) * peso
		pose.basis = pose.basis * Basis.from_euler(Vector3(sin(tiempo * 1.4 + fase) * 0.014, 0, ola * 0.018) * peso)
		nodo.transform = pose
	_actualizar_colision_alfombra(altura)


func _physics_process(delta: float) -> void:
	if resolviendo_avatar:
		return
	if not activo:
		return
	tiempo += delta
	if drenando:
		nivel = move_toward(nivel, PISO, delta * (NIVEL_MAXIMO - PISO) / VACIADO)
	else:
		nivel = move_toward(nivel, NIVEL_MAXIMO, delta * (NIVEL_MAXIMO - PISO) / SUBIDA)
	_actualizar_flotantes()
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
	tuberias.nivel_agua = nivel
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
	var destino := tuberias.cuerpo.global_position
	var consulta := PhysicsRayQueryParameters3D.create(origen, destino, 1)
	consulta.exclude = [jugador.get_rid()]
	var impacto := get_world_3d().direct_space_state.intersect_ray(consulta)
	return self if impacto.is_empty() or tuberias.is_ancestor_of(impacto.collider) else null


func interactuar(jugador: Player) -> void:
	if SesionLAN.en_partida and not SesionLAN.puente.reservar_confirmada("inundacion"):
		SesionLAN.puente.reservar_local("inundacion", func(): interactuar(jugador))
		return
	if jugador.input_locked or jugador.realizando_gesto() or get_tree().paused or obtener_objetivo(jugador) != self:
		if SesionLAN.en_partida:
			SesionLAN.puente.liberar_local("inundacion")
		return
	_bloqueo_anterior = jugador.input_locked
	_raton_anterior = Input.mouse_mode
	reparando = true
	jugador.input_locked = true
	jugador.velocity.x = 0
	jugador.velocity.z = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	tuberias.establecer_abierto(true)
	panel.abrir()
	indicador.hide()


func _cerrar_reparacion() -> void:
	if not reparando:
		return
	reparando = false
	tuberias.establecer_abierto(false)
	if SesionLAN.en_partida:
		SesionLAN.puente.liberar_local("inundacion")
	panel.cerrar()
	_jugador.input_locked = _bloqueo_anterior or _oficina.partida_finalizada
	Input.mouse_mode = _raton_anterior


func _al_reparar() -> void:
	if SesionLAN.en_partida and not SesionLAN.puente.aplicando:
		SesionLAN.solicitar("reparar", {"objetivo": "inundacion"})
		return
	if not activo or drenando or not panel.red.resuelta:
		return
	_cerrar_reparacion()
	drenando = true
	tuberias.sellar()
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
	_cancelar_resolucion_avatar()
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
	_actualizar_colision_alfombra(0.0)
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
	_material.set_shader_parameter("avatar_activo", false)
	tuberias.restablecer()
	_ambiente.stop()
	for sonido in _salpicaduras:
		sonido.stop()
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
	tuberias = _oficina.get_node_or_null("CompuertaEstacionInundacion") as TuberiaRompible
	if tuberias == null:
		push_error("No se encontró la estación CompuertaEstacionInundacion en la escena de oficina.")
		return
	_chorro = tuberias.chorro
	acceso = Marker3D.new()
	acceso.name = "AccesoTuberias"
	acceso.add_to_group("accesos_navegacion")
	acceso.position = Vector3(1.45, PISO, tuberias.position.z)
	add_child(acceso)


## Un origen inicia la transición del objeto; sin origen, limpieza inmediata de reinicio/red.
func resolver_con_avatar(origen: Variant = null) -> void:
	if not activo:
		return
	if origen is Vector3:
		if resolviendo_avatar:
			return
		_cerrar_reparacion()
		drenando = true
		_nivel_avatar = nivel
		tuberias.sellar()
		indicador.hide()
		_resolucion_avatar = ResolucionAvatar.crear(self, origen, &"agua", _avanzar_avatar, resolver_con_avatar)
		return
	detener()
	terminado.emit()

func _avanzar_avatar(frente: Node3D) -> void:
	tiempo += get_physics_process_delta_time()
	nivel = lerpf(_nivel_avatar, PISO, smoothstep(.05, 2.45, frente.tiempo))
	_actualizar_flotantes()
	_jugador.establecer_nivel_agua(nivel)
	for bloqueo: Node3D in _oficina.bloqueos_visuales.values():
		bloqueo.actualizar_agua(nivel, tiempo)
	for papel: PapelDenuncia in get_tree().get_nodes_in_group("papeles_denuncia"):
		if _oficina.is_ancestor_of(papel):
			papel.nivel_agua = nivel + .025
	frente.aplicar_material(_material)

func _cancelar_resolucion_avatar() -> void:
	if is_instance_valid(_resolucion_avatar):
		_resolucion_avatar.cancelar()
	_resolucion_avatar = null
