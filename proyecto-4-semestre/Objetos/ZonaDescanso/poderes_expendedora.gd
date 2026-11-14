extends Node
## Suspende el mundo sin pausar el SceneTree: tareas, jugador y menús siguen disponibles.
const ELEMENTO := preload("res://Objetos/ZonaDescanso/efecto_elemental.gd")
const SONIDO_DETENER := preload("res://Audios/Expendedora/za_warudo_detener.mp3")
const SONIDO_REANUDAR := preload("res://Audios/Expendedora/za_warudo_reanudar.mp3")
var restante := 0.0
var oficina: Node3D
var jugador: Player
var _guardados: Dictionary = {}
var _tweens: Array[Tween] = []
var _exentos: Array[Node] = []
var _capa: CanvasLayer
var _pantalla: ColorRect
var _burbuja: MeshInstance3D
var _reloj: AudioStreamPlayer
var _sonido_detener: AudioStreamPlayer
var _sonido_reanudar: AudioStreamPlayer
var _tic := 0.0
var _inicio := Vector3.ZERO
var _congelado_anterior := false
var _quemadura_anterior := false
var _elemento: Node3D

func configurar(mundo: Node3D, policia: Player) -> void:
	oficina = mundo
	jugador = policia
	process_physics_priority = -100
	_capa = CanvasLayer.new()
	_capa.layer = 25
	add_child(_capa)
	_pantalla = ColorRect.new()
	_pantalla.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pantalla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://Objetos/ZonaDescanso/tiempo_detenido.gdshader")
	_pantalla.material = material
	_capa.add_child(_pantalla)
	_pantalla.hide()
	_reloj = AudioStreamPlayer.new()
	_reloj.bus = "Interacciones" if AudioServer.get_bus_index("Interacciones") >= 0 else "Master"
	_reloj.volume_db = -12.0
	_reloj.stream = _crear_tic()
	add_child(_reloj)
	_sonido_detener = _crear_audio("DetenerTiempo", SONIDO_DETENER)
	_sonido_reanudar = _crear_audio("ReanudarTiempo", SONIDO_REANUDAR)

func _crear_audio(nombre: String, sonido: AudioStream) -> AudioStreamPlayer:
	var reproductor := AudioStreamPlayer.new()
	reproductor.name = nombre
	reproductor.stream = sonido
	reproductor.bus = _reloj.bus
	reproductor.volume_db = -9.0
	add_child(reproductor)
	return reproductor

func evento_actual() -> Node:
	for nombre: String in ["evento_inundacion", "evento_incendio", "evento_terremoto", "evento_hielo", "evento_lava"]:
		var evento: Node = oficina.get(nombre)
		if is_instance_valid(evento) and evento.get("activo"):
			return evento
	if oficina.evento_apagon.estado != 0:
		return oficina.evento_apagon
	return null

func gesto_para(evento: Node) -> StringName:
	if evento == oficina.evento_inundacion or evento == oficina.evento_lava:
		return &"control_agua"
	if evento == oficina.evento_incendio or evento == oficina.evento_apagon:
		return &"control_fuego"
	if evento == oficina.evento_terremoto:
		return &"control_tierra"
	return &"control_aire"

func animar_elemento(gesto: StringName) -> void:
	if is_instance_valid(_elemento):
		_elemento.queue_free()
	_elemento = ELEMENTO.new()
	_elemento.tipo = gesto
	_elemento.jugador = jugador
	oficina.add_child(_elemento)
	_elemento.global_position = jugador.global_position
	_elemento.rotation.y = jugador.visual.global_rotation.y

func detener_tiempo() -> void:
	if restante > 0.0 or oficina.partida_finalizada:
		return
	restante = 12.0
	# El efecto elegido suena completo, una sola vez, al nacer la burbuja.
	# El tic-tac de fondo entra después para no tapar el ataque del audio.
	_tic = SONIDO_DETENER.get_length()
	_inicio = jugador.global_position + Vector3.UP * 0.6
	oficina.sistema_despacho.tiempo_detenido = true
	jugador.tiempo_detenido = true
	_congelado_anterior = jugador.congelado
	_quemadura_anterior = jugador.quemandose_pies
	jugador.congelado = false
	jugador.quemandose_pies = false
	_exentos.assign([self, get_parent(), jugador, oficina.get_node("Gameplay/Camera3D"), oficina.get_node("CanvasLayer"), oficina.computador, oficina.sistema_despacho, oficina.temporizador_seguridad, oficina.sonidos_mesas])
	# Los tweens ya existentes pertenecen al mundo anterior al gesto. Las nuevas
	# animaciones de completar tareas se crean después y continúan normalmente.
	for tween: Tween in get_tree().get_processed_tweens():
		if tween.is_running():
			_tweens.append(tween)
			tween.pause()
	for hijo: Node in oficina.get_children():
		_congelar_rama(hijo)
	get_tree().node_added.connect(_al_agregar_nodo)
	_crear_burbuja()
	_pantalla.show()
	_actualizar_pantalla(0.0)
	_sonido_reanudar.stop()
	_sonido_detener.play()

func _congelar_rama(nodo: Node) -> void:
	if _exentos.has(nodo):
		return
	var contiene_exento := false
	for exento: Node in _exentos:
		if nodo.is_ancestor_of(exento):
			contiene_exento = true
			break
	if not contiene_exento:
		_congelar_nodo(nodo)
	for hijo: Node in nodo.get_children():
		_congelar_rama(hijo)

func _congelar_nodo(nodo: Node) -> void:
	var id := nodo.get_instance_id()
	if _guardados.has(id):
		return
	var dato := {"nodo": nodo, "modo": nodo.process_mode}
	if nodo is CollisionObject3D:
		dato["desactivacion"] = nodo.disable_mode
		nodo.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	if nodo is GPUParticles3D or nodo is CPUParticles3D:
		dato["velocidad"] = nodo.speed_scale
		nodo.speed_scale = 0.0
	if nodo is AudioStreamPlayer or nodo is AudioStreamPlayer3D or nodo is AudioStreamPlayer2D:
		dato["audio"] = nodo.stream_paused
		nodo.stream_paused = true
	if nodo is RigidBody3D:
		dato["freeze"] = nodo.freeze
		dato["lineal"] = nodo.linear_velocity
		dato["angular"] = nodo.angular_velocity
		nodo.freeze = true
	nodo.process_mode = Node.PROCESS_MODE_DISABLED
	_guardados[id] = dato

func _al_agregar_nodo(nodo: Node) -> void:
	_congelar_nuevo.call_deferred(nodo)

func _congelar_nuevo(nodo: Node) -> void:
	if restante <= 0.0 or not is_instance_valid(nodo) or not oficina.is_ancestor_of(nodo):
		return
	for exento: Node in _exentos:
		if is_instance_valid(exento) and (nodo == exento or exento.is_ancestor_of(nodo)):
			return
	_congelar_rama(nodo)

func _physics_process(delta: float) -> void:
	if restante <= 0.0:
		return
	restante = maxf(0.0, restante - delta)
	_tic -= delta
	if _tic <= 0.0:
		_tic += 1.0
		_reloj.pitch_scale = 1.0 if ceili(restante) % 2 == 0 else 0.78
		_reloj.play()
	var transcurrido := 12.0 - restante
	_actualizar_pantalla(transcurrido)
	if is_instance_valid(_burbuja):
		_burbuja.scale = Vector3.ONE * maxf(0.01, transcurrido * 16.0)
		_burbuja.visible = transcurrido < 1.7
	if restante <= 0.0:
		reanudar_tiempo()

func _actualizar_pantalla(tiempo: float) -> void:
	var camara := get_viewport().get_camera_3d()
	var centro := Vector2(0.5, 0.5)
	if camara != null and not camara.is_position_behind(_inicio):
		centro = camara.unproject_position(_inicio) / get_viewport().get_visible_rect().size
	var material := _pantalla.material as ShaderMaterial
	material.set_shader_parameter("centro", centro)
	material.set_shader_parameter("radio", minf(2.0, tiempo * 1.8))
	material.set_shader_parameter("fuerza", minf(1.0, restante / 0.35))

func reanudar_tiempo(con_sonido: bool = true) -> void:
	var estaba_detenido := is_instance_valid(jugador) and jugador.tiempo_detenido
	if get_tree() != null and get_tree().node_added.is_connected(_al_agregar_nodo):
		get_tree().node_added.disconnect(_al_agregar_nodo)
	for dato: Dictionary in _guardados.values():
		if not is_instance_valid(dato.nodo):
			continue
		var nodo: Node = dato.nodo
		nodo.process_mode = dato.modo
		if dato.has("desactivacion"):
			nodo.disable_mode = dato.desactivacion
		if dato.has("velocidad"):
			nodo.speed_scale = dato.velocidad
		if dato.has("audio"):
			nodo.stream_paused = dato.audio
		if dato.has("freeze") and not (nodo is PapelDenuncia and is_instance_valid(nodo.portador)):
			nodo.freeze = dato.freeze
			nodo.linear_velocity = dato.lineal
			nodo.angular_velocity = dato.angular
	_guardados.clear()
	for tween: Tween in _tweens:
		if tween.is_valid():
			tween.play()
	_tweens.clear()
	if is_instance_valid(oficina) and is_instance_valid(oficina.sistema_despacho):
		oficina.sistema_despacho.tiempo_detenido = false
	if is_instance_valid(jugador) and jugador.tiempo_detenido:
		jugador.tiempo_detenido = false
		jugador.congelado = _congelado_anterior
		jugador.quemandose_pies = _quemadura_anterior
	restante = 0.0
	if is_instance_valid(_pantalla):
		_pantalla.hide()
	if is_instance_valid(_burbuja):
		_burbuja.queue_free()
		_burbuja = null
	if is_instance_valid(_reloj):
		_reloj.stop()
	if is_instance_valid(_sonido_detener):
		_sonido_detener.stop()
	if is_instance_valid(_sonido_reanudar):
		if con_sonido and estaba_detenido and is_inside_tree():
			_sonido_reanudar.play()
		elif not con_sonido:
			_sonido_reanudar.stop()

func limpiar() -> void:
	reanudar_tiempo(false)
	if is_instance_valid(_elemento):
		_elemento.queue_free()

func _exit_tree() -> void:
	limpiar()

func _crear_burbuja() -> void:
	_burbuja = MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 1.0
	esfera.height = 2.0
	_burbuja.mesh = esfera
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.72, 0.74, 0.79, 0.16)
	_burbuja.material_override = material
	_burbuja.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_burbuja)
	_burbuja.global_position = _inicio
	_burbuja.scale = Vector3.ONE * 0.01

func _crear_tic() -> AudioStreamWAV:
	var sonido := AudioStreamWAV.new()
	sonido.format = AudioStreamWAV.FORMAT_16_BITS
	sonido.mix_rate = 22050
	var datos := PackedByteArray()
	datos.resize(6615 * 2)
	for i in 6615:
		var t := float(i) / 22050.0
		var muestra := (sin(TAU * 1450.0 * t) + sin(TAU * 2180.0 * t) * 0.4) * exp(-t * 55.0)
		muestra += sin(TAU * 180.0 * t) * exp(-t * 18.0) * 0.3
		datos.encode_s16(i * 2, int(clampf(muestra * 0.5, -1.0, 1.0) * 32767))
	sonido.data = datos
	return sonido

func crear_snack(indice: int) -> Node3D:
	var pieza := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	if indice == 0:
		var barra := BoxMesh.new()
		barra.size = Vector3(0.28, 0.09, 0.42)
		pieza.mesh = barra
		material.albedo_color = Color("51291c")
	else:
		var dona := TorusMesh.new()
		dona.inner_radius = 0.09
		dona.outer_radius = 0.23
		pieza.mesh = dona
		material.albedo_color = Color("ef8eae")
	pieza.material_override = material
	return pieza
