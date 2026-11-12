extends CharacterBody3D
class_name Player
## Controlador independiente para la escena de pruebas del policía azul.
## El modelo mira hacia +Z y sus pies están en el origen de la escena.

signal animation_state_changed(animation: StringName)
signal reset_performed
# El futuro panel puede abrirse al mantener G y elegir el emote al soltarla.
signal emote_menu_requested
signal emote_menu_finished(cancelled: bool)
signal emote_rechazado(mensaje: String)

const LEFT := &"policia_prueba_izquierda"
const RIGHT := &"policia_prueba_derecha"
const FORWARD := &"policia_prueba_adelante"
const BACK := &"policia_prueba_atras"
const RUN := &"policia_prueba_correr"
const JUMP := &"policia_prueba_saltar"
const ALTURA_SALTO_DE_GRIETA := 0.25
const EMOTE_MENU := &"policia_menu_emotes"
const KAMEHAMEHA := &"policia_kamehameha"
const GENKIDAMA := &"policia_genkidama"
const RASENGAN := &"policia_rasengan"
const EMOTE_HOLD_SECONDS := 0.3
const AnimacionesInteraccion := preload("res://Personajes/PoliciaAzul/animaciones_interaccion.gd")

@export_category("Movimiento")
@export var walk_speed: float = 2.0
@export var run_speed: float = 4.0
@export var acceleration: float = 12.0
@export var braking: float = 16.0
@export var turn_speed: float = 12.0
@export var jump_velocity: float = 5.2
@export var camera_path: NodePath
@export var input_locked: bool = false:
	set(value):
		input_locked = value
		if value:
			_finish_emote_menu(true)
@export var interaction_action: StringName = &"Interactuar"
@export_range(0.1, 2.0, 0.05) var character_scale: float = 0.3
@export_category("Animación")
@export var blend_time: float = 0.15
@export_range(0.0, 2.0, 0.05) var intensidad_tambaleo: float = 1.0

var animation_player: AnimationPlayer
var current_animation: StringName = &""
var _spawn_transform: Transform3D
var _spawn_visual_rotation: Vector3
var _wave_remaining: float = 0.0
var _emote_hold_remaining: float = 0.0
var _emote_menu_active: bool = false
var _animation_names: Dictionary = {}
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var papel_en_mano: PapelDenuncia = null
var gestos: AnimacionesInteraccion
var control_incendio: Node
var control_inundacion: Node
var nadando := false
var nivel_agua := -INF
const FACTOR_NADO := 0.55
var _reloj_nado := 0.0
var _pose_modelo := Transform3D.IDENTITY
var usando_extintor := false
var _efecto_gesto: Callable
var _reloj_reposo: float = 0.0
var _reposo_disponible: bool = false
var _ultimo_reposo: StringName = &"idle_tambaleo"
var _azar_reposo := RandomNumberGenerator.new()
var _descanso_sentado: bool = false
var _taza_en_mano: bool = false

@onready var visual: Node3D = $Visual
@onready var shape_cast_3d: ShapeCast3D = $Visual/ShapeCast3D
@onready var sonido_pasos: SonidosPasos = $SonidosPasos
@onready var voz: VozPersonaje = $VozPersonaje

func _enter_tree() -> void:
	add_to_group("player")


func _ready() -> void:
	# La escena de Oficina instancia este personaje y puede conservar el scale
	# de la instancia. Aplicarlo aquí garantiza el tamaño también durante el juego.
	scale = Vector3.ONE * character_scale
	_spawn_transform = global_transform
	_spawn_visual_rotation = visual.rotation
	_pose_modelo = $Visual/Modelo.transform
	_register_inputs()
	animation_player = $Visual/Modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player == null:
		push_warning("PoliciaAzul: el modelo necesita un AnimationPlayer.")
	else:
		for clip: StringName in [&"idle", &"walk", &"run", &"jump", &"fall", &"wave"]:
			for imported_name: StringName in animation_player.get_animation_list():
				# Admite tanto nombres simples como bibliotecas o prefijos de importación.
				var leaf := String(imported_name).get_file().get_slice("|", String(imported_name).get_file().get_slice_count("|") - 1)
				if leaf.to_lower() == String(clip):
					_animation_names[clip] = imported_name
					break
	var esqueleto := $Visual/Modelo.find_child("Skeleton3D", true, false) as Skeleton3D
	if esqueleto != null:
		gestos = AnimacionesInteraccion.new()
		gestos.name = "AnimacionesInteraccion"
		gestos.jugador = self
		gestos.tambaleo = intensidad_tambaleo
		esqueleto.add_child(gestos)
		gestos.contacto.connect(_al_contacto_gesto)
		gestos.terminada.connect(_al_terminar_gesto)
		gestos.reposo_terminado.connect(_al_terminar_reposo)
	_azar_reposo.randomize()
	# Las poses de nado se construyen sobre el reposo mediante el modificador.
	if _animation_names.has(&"idle"):
		_animation_names[&"swim"] = _animation_names[&"idle"]
		_animation_names[&"swim_idle"] = _animation_names[&"idle"]
	_play_animation(&"idle")
	if not is_in_group("player"):
		add_to_group("player")


func _physics_process(delta: float) -> void:
	if _descanso_sentado:
		velocity = Vector3.ZERO
		sonido_pasos.detener()
		return
	_update_emote_hold(delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	var input_direction := Vector2.ZERO
	if not input_locked and not realizando_gesto() and not usando_extintor:
		input_direction = Input.get_vector(LEFT, RIGHT, FORWARD, BACK)
	var direction := _camera_relative_direction(input_direction)
	var moving := direction.length_squared() > 0.001
	var running := not input_locked and not realizando_gesto() and not usando_extintor and Input.is_action_pressed(RUN)

	if not nadando and not input_locked and not realizando_gesto() and not usando_extintor and Input.is_action_just_pressed(JUMP) and is_on_floor():
		_wave_remaining = 0.0
		velocity.y = jump_velocity
		for borde in get_tree().get_nodes_in_group(&"bordes_grietas_saltables"):
			if borde.frente_a_los_pies(global_position, direction):
				velocity.y = maxf(jump_velocity, sqrt(2.0 * _gravity * ALTURA_SALTO_DE_GRIETA))
				break
		reproducir_expresion(&"esfuerzo")
	if moving or input_locked or realizando_gesto() or not is_on_floor():
		_wave_remaining = 0.0
	else:
		_wave_remaining = maxf(0.0, _wave_remaining - delta)

	var target_speed := run_speed if running else walk_speed
	if nadando:
		target_speed = walk_speed * FACTOR_NADO
	var desired_velocity := direction * target_speed
	var change_rate := acceleration if moving else braking
	if nadando:
		change_rate *= 0.42
	velocity.x = move_toward(velocity.x, desired_velocity.x, change_rate * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, change_rate * delta)
	if moving:
		var angle := atan2(direction.x, direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, angle, 1.0 - exp(-turn_speed * delta))
	var posicion_anterior := global_position
	move_and_slide()
	var desplazamiento := Vector2(global_position.x - posicion_anterior.x, global_position.z - posicion_anterior.z).length()
	# El desplazamiento real evita seguir pisando al empujar una pared.
	var caminando := not nadando and is_on_floor() and not input_locked and desplazamiento > 0.1 * delta
	sonido_pasos.actualizar(delta, caminando, running)
	_update_animation(moving, running)
	_update_idle_variants(delta)
	_actualizar_pose_nado(delta)
	# Una caída fuera de la plataforma siempre vuelve al punto inicial.
	if global_position.y < -12.0:
		reset_to_spawn()


func _camera_relative_direction(input_direction: Vector2) -> Vector3:
	if input_direction.is_zero_approx():
		return Vector3.ZERO
	var camera := get_node_or_null(camera_path) as Camera3D if not camera_path.is_empty() else get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(input_direction.x, 0.0, input_direction.y).normalized()
	var right := camera.global_basis.x
	var forward := -camera.global_basis.z
	right.y = 0.0
	forward.y = 0.0
	# En vista cenital la mirada es vertical: el norte de pantalla es el eje Y de cámara.
	if forward.length_squared() < 0.01:
		forward = camera.global_basis.y
		forward.y = 0.0
	return (right.normalized() * input_direction.x - forward.normalized() * input_direction.y).normalized()


func _update_animation(moving: bool, running: bool) -> void:
	if nadando:
		_play_animation(&"swim" if moving and not realizando_gesto() else &"swim_idle")
	elif not is_on_floor():
		_play_animation(&"jump" if velocity.y > 0.0 else &"fall")
	elif _wave_remaining > 0.0:
		_play_animation(&"wave")
	elif moving or Vector2(velocity.x, velocity.z).length() > 0.15:
		_play_animation(&"run" if running else &"walk")
	else:
		_play_animation(&"idle")


func _play_animation(clip: StringName) -> void:
	if clip == current_animation:
		return
	current_animation = clip
	if animation_player != null and _animation_names.has(clip):
		animation_player.speed_scale = 1.0
		animation_player.play(_animation_names[clip], blend_time)
	animation_state_changed.emit(clip)


func play_wave() -> void:
	if _rechazar_emote_nadando():
		return
	if input_locked or _descanso_sentado or _taza_en_mano or realizando_gesto() or not is_on_floor():
		return
	_cancelar_reposo()
	_wave_remaining = 1.8
	if animation_player != null and _animation_names.has(&"wave"):
		_wave_remaining = animation_player.get_animation(_animation_names[&"wave"]).length
		# También permite repetir un saludo que aún está terminando.
		if current_animation == &"wave":
			animation_player.seek(0.0, true)
	_play_animation(&"wave")
	reproducir_expresion(&"saludo")


func reproducir_expresion(expresion: StringName) -> bool:
	return voz.reproducir(expresion) if is_instance_valid(voz) else false


func _input(event: InputEvent) -> void:
	if event.is_action_released(interaction_action) and is_instance_valid(control_incendio):
		control_incendio.soltar()
	if usando_extintor:
		return
	if input_locked or realizando_gesto():
		return
	if nadando and (event.is_action_pressed(EMOTE_MENU) or event.is_action_pressed(KAMEHAMEHA) or event.is_action_pressed(GENKIDAMA) or event.is_action_pressed(RASENGAN)):
		if not event.is_echo():
			_rechazar_emote_nadando()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(KAMEHAMEHA) and not (event is InputEventKey and event.echo):
		get_viewport().set_input_as_handled()
		ejecutar_gesto(&"kamehameha")
		return
	if event.is_action_pressed(GENKIDAMA) and not (event is InputEventKey and event.echo):
		get_viewport().set_input_as_handled()
		ejecutar_gesto(&"genkidama")
		return
	if event.is_action_pressed(RASENGAN) and not (event is InputEventKey and event.echo):
		get_viewport().set_input_as_handled()
		ejecutar_gesto(&"rasengan")
		return
	if event.is_action(EMOTE_MENU):
		if event.is_action_released(EMOTE_MENU):
			_finish_emote_menu(false)
		elif event.is_action_pressed(EMOTE_MENU) and not input_locked and not _emote_menu_active:
			_emote_hold_remaining = EMOTE_HOLD_SECONDS
		return
	if not event.is_action_pressed(interaction_action):
		return
	if event is InputEventKey and event.echo:
		return
	var objetivo := obtener_objetivo_interaccion()
	if objetivo is PCStatic:
		get_viewport().set_input_as_handled()
		(objetivo as PCStatic).interactuar(self)
	elif objetivo != null and objetivo.has_method("interactuar"):
		get_viewport().set_input_as_handled()
		objetivo.interactuar(self)
	elif is_instance_valid(papel_en_mano):
		get_viewport().set_input_as_handled()
		var hoja := papel_en_mano
		ejecutar_gesto(&"lanzar", func() -> void:
			if is_instance_valid(hoja) and hoja.portador == self:
				hoja.lanzar()
		)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_EXIT_TREE]:
		_finish_emote_menu(true)


func _update_emote_hold(delta: float) -> void:
	if _emote_hold_remaining <= 0.0:
		return
	_emote_hold_remaining = maxf(0.0, _emote_hold_remaining - delta)
	if is_zero_approx(_emote_hold_remaining):
		_emote_hold_remaining = 0.0
		_emote_menu_active = true
		emote_menu_requested.emit()


func _finish_emote_menu(cancelled: bool) -> void:
	_emote_hold_remaining = 0.0
	if _emote_menu_active:
		_emote_menu_active = false
		emote_menu_finished.emit(cancelled)


func obtener_objetivo_interaccion() -> Node3D:
	# La consulta visual y la tecla E comparten alcance, orden y disponibilidad.
	if not is_inside_tree() or input_locked or realizando_gesto() or not is_processing_input():
		return null
	if get_tree().paused:
		return null
	if is_instance_valid(control_inundacion):
		var tuberia: Node3D = control_inundacion.obtener_objetivo(self)
		if tuberia != null:
			return tuberia
	if is_instance_valid(control_incendio):
		var fuego: Node3D = control_incendio.obtener_objetivo(self)
		if fuego != null:
			return fuego
	if papel_en_mano == null:
		var papel_cercano := _buscar_papel_cercano()
		if papel_cercano != null:
			return papel_cercano
	if not is_instance_valid(shape_cast_3d):
		return null

	shape_cast_3d.force_shapecast_update()
	for indice: int in range(shape_cast_3d.get_collision_count()):
		var collider := shape_cast_3d.get_collider(indice) as Node
		var actual := collider
		while actual != null:
			if actual is PCStatic or (actual is Node3D and actual.has_method("interactuar")):
				return actual as Node3D
			actual = actual.get_parent()
	return null


func _buscar_papel_cercano() -> PapelDenuncia:
	var frente := visual.global_basis.z.normalized()
	var mas_cercano: PapelDenuncia = null
	var menor_distancia := 1.0
	for nodo: Node in get_tree().get_nodes_in_group("papeles_denuncia"):
		var papel := nodo as PapelDenuncia
		if not is_instance_valid(papel) or papel.portador != null:
			continue
		var desplazamiento := papel.global_position - global_position
		if absf(desplazamiento.y) > 1.1:
			continue
		desplazamiento.y = 0.0
		var distancia := desplazamiento.length()
		if distancia >= menor_distancia or (distancia > 0.1 and frente.dot(desplazamiento / distancia) < 0.1):
			continue
		menor_distancia = distancia
		mas_cercano = papel
	return mas_cercano


func reset_to_spawn() -> void:
	terminar_descanso_sentado(true)
	establecer_taza_en_mano(false)
	cancelar_gesto()
	_cancelar_reposo()
	_reposo_disponible = false
	_finish_emote_menu(true)
	voz.detener()
	sonido_pasos.detener()
	global_transform = _spawn_transform
	visual.rotation = _spawn_visual_rotation
	velocity = Vector3.ZERO
	_wave_remaining = 0.0
	_play_animation(&"idle")
	reset_performed.emit()


func realizando_gesto() -> bool:
	return is_instance_valid(gestos) and gestos.gesto != &""


func ejecutar_gesto(tipo: StringName, efecto: Callable = Callable(), objetivo: Node3D = null, segundos: float = 0.0) -> bool:
	if tipo in [&"kamehameha", &"genkidama", &"rasengan"] and _rechazar_emote_nadando():
		return false
	if usando_extintor:
		return false
	var beber_sentado := tipo == &"beber" and _descanso_sentado
	if (input_locked and not beber_sentado) or realizando_gesto() or (not is_on_floor() and not beber_sentado):
		return false
	if not is_instance_valid(gestos):
		# Mantiene funcionales escenas con un modelo alternativo sin esqueleto.
		if efecto.is_valid():
			efecto.call()
		return true
	if not gestos.iniciar(tipo, objetivo, segundos):
		return false
	_efecto_gesto = efecto
	_wave_remaining = 0.0
	_finish_emote_menu(true)
	velocity.x = 0.0
	velocity.z = 0.0
	if is_instance_valid(objetivo):
		var direccion := objetivo.global_position - global_position
		if Vector2(direccion.x, direccion.z).length() > 0.05:
			visual.rotation.y = atan2(direccion.x, direccion.z)
	_play_animation(&"idle")
	animation_state_changed.emit(tipo)
	return true


func play_idle_variant(tipo: StringName) -> bool:
	if _rechazar_emote_nadando():
		return false
	if not is_instance_valid(gestos) or input_locked or _descanso_sentado or _taza_en_mano or realizando_gesto() or not is_on_floor():
		return false
	if current_animation != &"idle" or Vector2(velocity.x, velocity.z).length() > 0.15:
		return false
	if not gestos.iniciar_reposo(tipo):
		return false
	_ultimo_reposo = tipo
	animation_state_changed.emit(tipo)
	return true


func _update_idle_variants(delta: float) -> void:
	if not is_instance_valid(gestos):
		return
	var disponible := not nadando and current_animation == &"idle" and is_on_floor() and not input_locked and not _descanso_sentado and not _taza_en_mano and not realizando_gesto() and not _emote_menu_active and not usando_extintor
	if not disponible:
		if _reposo_disponible:
			_cancelar_reposo()
		_reposo_disponible = false
		return
	if not _reposo_disponible:
		_reposo_disponible = true
		_reloj_reposo = _azar_reposo.randf_range(4.5, 7.0)
	if gestos.reposo_especial != &"":
		return
	_reloj_reposo -= delta
	if _reloj_reposo <= 0.0:
		var siguiente: StringName = &"idle_despistado" if _ultimo_reposo == &"idle_tambaleo" else &"idle_tambaleo"
		play_idle_variant(siguiente)


func _cancelar_reposo() -> void:
	if is_instance_valid(gestos) and gestos.reposo_especial != &"":
		gestos.cancelar_reposo()
		if current_animation == &"idle" and not realizando_gesto() and _wave_remaining <= 0.0:
			animation_state_changed.emit(&"idle")


func _al_terminar_reposo() -> void:
	_reloj_reposo = _azar_reposo.randf_range(4.5, 7.0)
	animation_state_changed.emit(&"idle")


func cancelar_gesto() -> void:
	_efecto_gesto = Callable()
	if is_instance_valid(gestos):
		gestos.cancelar()


func _al_contacto_gesto() -> void:
	var efecto := _efecto_gesto
	_efecto_gesto = Callable()
	if efecto.is_valid():
		efecto.call()


func _al_terminar_gesto() -> void:
	_efecto_gesto = Callable()
	animation_state_changed.emit(current_animation)


func anclaje_papel() -> Node3D:
	return gestos.mano_izquierda if is_instance_valid(gestos) else visual


func anclaje_taza() -> Node3D:
	return gestos.anclaje_taza if is_instance_valid(gestos) else visual


func establecer_taza_en_mano(activo: bool) -> void:
	_taza_en_mano = activo
	if is_instance_valid(gestos):
		gestos.lleva_taza = activo
	if activo:
		_cancelar_reposo()
		_finish_emote_menu(true)


func esta_sentado() -> bool:
	return _descanso_sentado


func iniciar_descanso_sentado() -> bool:
	if nadando:
		return false
	if _descanso_sentado or realizando_gesto() or not is_instance_valid(gestos) or get_tree().paused:
		return false
	_descanso_sentado = true
	_cancelar_reposo()
	_finish_emote_menu(true)
	_wave_remaining = 0.0
	velocity = Vector3.ZERO
	sonido_pasos.detener()
	_play_animation(&"idle")
	gestos.establecer_sentado(true)
	animation_state_changed.emit(&"sentado")
	return true


func terminar_descanso_sentado(inmediato: bool = false) -> void:
	var estaba_sentado := _descanso_sentado
	_descanso_sentado = false
	if is_instance_valid(gestos):
		gestos.establecer_sentado(false, inmediato)
	if estaba_sentado:
		velocity = Vector3.ZERO
		animation_state_changed.emit(current_animation)


func establecer_nivel_agua(altura: float) -> void:
	nivel_agua = altura
	if altura == -INF:
		$Visual/Modelo.transform = _pose_modelo
	var entrando := altura > 0.75
	if entrando == nadando:
		return
	nadando = entrando
	if nadando:
		_wave_remaining = 0.0
		_finish_emote_menu(true)
		_cancelar_reposo()
		if realizando_gesto() and gestos.gesto in [&"kamehameha", &"genkidama", &"rasengan"]:
			cancelar_gesto()
		sonido_pasos.detener()


func _rechazar_emote_nadando() -> bool:
	if not nadando:
		return false
	emote_rechazado.emit("No se pueden usar emotes en este momento")
	return true


func _actualizar_pose_nado(delta: float) -> void:
	_reloj_nado += delta
	var modelo := $Visual/Modelo as Node3D
	var destino := _pose_modelo
	if nadando:
		var avanzando := Vector2(velocity.x, velocity.z).length() > 0.15 and not realizando_gesto()
		var elevacion := maxf(0.0, nivel_agua - global_position.y - 0.43)
		destino.origin.y += (elevacion + sin(_reloj_nado * 3.0) * 0.018) / character_scale
		destino.basis = destino.basis * Basis.from_euler(Vector3(0.52 if avanzando else 0.10, 0, sin(_reloj_nado * 3) * 0.035))
	modelo.transform = modelo.transform.interpolate_with(destino, 1.0 - exp(-delta * 6.0))


func _register_inputs() -> void:
	_add_keys(LEFT, [KEY_A, KEY_LEFT])
	_add_keys(RIGHT, [KEY_D, KEY_RIGHT])
	_add_keys(FORWARD, [KEY_W, KEY_UP])
	_add_keys(BACK, [KEY_S, KEY_DOWN])
	_add_keys(RUN, [KEY_SHIFT])
	_add_keys(JUMP, [KEY_SPACE])
	_add_keys(EMOTE_MENU, [KEY_G])
	_add_keys(KAMEHAMEHA, [KEY_K])
	_add_keys(GENKIDAMA, [KEY_H])
	_add_keys(RASENGAN, [KEY_J])


func _add_keys(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for physical_key: int in keys:
		var key := InputEventKey.new()
		key.physical_keycode = physical_key
		InputMap.action_add_event(action, key)
