extends Camera3D

signal vista_cambiada(vista: int)

enum Vista { ACTUAL, FRONTAL, GOD }

@export var objetivo: Node3D
@export var offset: Vector3 = Vector3(0, 3, 2)
@export_range(0.1, 20.0, 0.1) var suavizado: float = 5.0

@export_group("Vistas de cámara")
@export var vista_actual: Vista = Vista.ACTUAL
@export var offset_frontal := Vector3(0, 2.7, 3.8)
@export_range(-80.0, -10.0, 1.0) var inclinacion_frontal: float = -28.0
@export var offset_god := Vector3(0, 7, 0)
@export_range(0.1, 20.0, 0.1) var suavizado_giro: float = 4.0

@export_group("Balanceo ambiental")
var balanceo_activo: bool = true
@export var amplitud_balanceo := Vector2(0.12, 0.06)
@export_range(4.0, 30.0, 0.5) var periodo_balanceo: float = 10.0

@export_group("Límites de Cámara")
@export var limite_min_x: float = -4.592
@export var limite_max_x: float = 2.415
@export var limite_min_z: float = -0.153
@export var limite_max_z: float = 12.473

@export_group("Zona segura del encuadre")
@export var zona_segura_activa: bool = true
## Caras interiores de los muros de Oficina, en coordenadas X/Z del mundo.
@export var recinto_visible := Rect2(-4.38, -0.07, 6.74, 12.46)
@export_range(0.05, 0.8, 0.01) var margen_pared: float = 0.22
## La cota más baja de las coronaciones evita ver por fuera en vista cenital.
@export var altura_pared: float = 6.10

var _orientacion_original: Quaternion
var _orientacion: Quaternion
var _posicion_seguimiento: Vector3
var _fase_balanceo: float = 0.0
var _peso_balanceo: float = 1.0
var _temblor := Vector2.ZERO
var _camara_libre: bool = false
var _bloqueo_previo_jugador: bool = false
var _modo_mouse_previo: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _yaw_libre: float = 0.0
var _pitch_libre: float = 0.0
var _ayuda_camara_libre: Label
var _peso_zoom_explosion: float = 0.0
var _fase_orbita_aura: float = 0.0
var _peso_orbita_aura: float = 0.0
var _peso_zoom_aura: float = 0.0


func actualizar_temblor(tiempo: float, intensidad: float) -> void:
	# Las tres etapas comparten la misma onda. Solo cambia su amplitud.
	_temblor = 0.080 * intensidad * Vector2(
		sin(tiempo * 30.7) + 0.32 * sin(tiempo * 51.3),
		0.67 * sin(tiempo * 36.1) + 0.19 * sin(tiempo * 48.7)
	)


func _ready() -> void:
	_orientacion_original = global_basis.orthonormalized().get_rotation_quaternion()
	_orientacion = _orientacion_original
	_posicion_seguimiento = global_position
	_sincronizar_balanceo()
	_peso_balanceo = 1.0 if balanceo_activo else 0.0
	get_node("/root/AjustesAccesibilidad").connect("ajustes_cambiados", _sincronizar_balanceo)


func _sincronizar_balanceo() -> void:
	balanceo_activo = bool(get_node("/root/AjustesAccesibilidad").get("balanceo_camara"))


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_echo() or not is_current() or get_tree().paused:
		return
	if evento is InputEventKey and evento.pressed and evento.physical_keycode == KEY_F5:
		_alternar_camara_libre()
		get_viewport().set_input_as_handled()
		return
	if _camara_libre:
		if evento is InputEventMouseMotion:
			var movimiento := evento as InputEventMouseMotion
			_yaw_libre -= movimiento.relative.x * 0.0025
			_pitch_libre = clampf(_pitch_libre - movimiento.relative.y * 0.0025, -1.50, 1.50)
			rotation = Vector3(_pitch_libre, _yaw_libre, 0.0)
			get_viewport().set_input_as_handled()
		return
	if not is_instance_valid(objetivo) or bool(objetivo.get("input_locked")):
		return
	if evento.is_action_pressed("CambiarCamara"):
		establecer_vista((int(vista_actual) + 1) % Vista.size())
	elif evento.is_action_pressed("CamaraActual"):
		establecer_vista(Vista.ACTUAL)
	elif evento.is_action_pressed("CamaraFrontal"):
		establecer_vista(Vista.FRONTAL)
	elif evento.is_action_pressed("CamaraGod"):
		establecer_vista(Vista.GOD)
	else:
		return
	get_viewport().set_input_as_handled()


func establecer_vista(vista: int) -> void:
	var siguiente := clampi(vista, Vista.ACTUAL, Vista.GOD) as Vista
	if vista_actual == siguiente:
		return
	vista_actual = siguiente
	vista_cambiada.emit(vista_actual)


func _physics_process(delta: float) -> void:
	if _camara_libre:
		_actualizar_camara_libre(delta)
		return
	if not is_instance_valid(objetivo):
		return
	var zoom_objetivo := _obtener_zoom_explosion_final()
	_peso_zoom_explosion = move_toward(_peso_zoom_explosion, zoom_objetivo, delta * 3.0)
	var gestos: Variant = objetivo.get("gestos")
	var transformando_aura := is_instance_valid(gestos) and bool(gestos.get("aura_transformacion_en_curso"))
	if transformando_aura:
		var progreso_aura := clampf(float(gestos.get("aura_transformacion_progreso")), 0.0, 1.0)
		var recorrido_aura := smoothstep(0.0, 1.0, progreso_aura)
		_fase_orbita_aura = TAU * recorrido_aura
		_peso_orbita_aura = 1.0
		_peso_zoom_aura = 1.0 - recorrido_aura
	elif is_instance_valid(gestos) and bool(gestos.get("aura_persistente_activada")) and float(gestos.get("aura_transformacion_progreso")) >= 1.0:
		# La vuelta completa termina exactamente en el encuadre normal; el blend
		# de seguimiento suaviza el pequeño error acumulado de la cámara.
		_fase_orbita_aura = 0.0
		_peso_orbita_aura = 0.0
		_peso_zoom_aura = 0.0
	else:
		_peso_orbita_aura = move_toward(_peso_orbita_aura, 0.0, delta * 0.9)
		_peso_zoom_aura = move_toward(_peso_zoom_aura, 0.0, delta * 0.9)
	# Conserva el seguimiento original y aplica luego la seguridad al encuadre real.
	var ancla := objetivo.global_position + offset
	ancla.x = clampf(ancla.x, limite_min_x, limite_max_x)
	ancla.z = clampf(ancla.z, limite_min_z, limite_max_z)
	ancla -= offset
	var desfase := offset
	var orientacion_deseada := _orientacion_original
	if vista_actual == Vista.FRONTAL:
		desfase = offset_frontal
		orientacion_deseada = Quaternion(Vector3.RIGHT, deg_to_rad(inclinacion_frontal))
	elif vista_actual == Vista.GOD:
		desfase = offset_god
		orientacion_deseada = Quaternion(Vector3.RIGHT, -PI / 2.0)
	if _peso_orbita_aura > 0.001:
		# Durante la transformación se usa la vista orbital estándar y luego se
		# mezcla de vuelta a la vista que el jugador tenía seleccionada.
		desfase = desfase.lerp(offset, _peso_orbita_aura)
	desfase *= 1.0 + 1.4 * _peso_zoom_explosion
	var zoom_radial_aura := Vector2(desfase.x, desfase.z) * (1.0 + 2.1 * _peso_zoom_aura)
	desfase = Vector3(zoom_radial_aura.x, desfase.y + 1.1 * _peso_zoom_aura, zoom_radial_aura.y)
	if _peso_orbita_aura > 0.001:
		var giro := _fase_orbita_aura * _peso_orbita_aura
		desfase = Basis(Vector3.UP, giro) * desfase
	var posicion_deseada := _limitar_encuadre(ancla + desfase, Basis(orientacion_deseada))
	if zona_segura_activa and vista_actual != Vista.GOD:
		# Al detenerse antes del muro posterior, inclina la vista lo necesario para
		# conservar al personaje dentro de la pantalla, sin atravesar la pared.
		var hacia := objetivo.global_position + Vector3.UP * 0.45 - posicion_deseada
		var inclinacion_objetivo := atan2(hacia.y, -hacia.z)
		var inclinacion_base := Basis(orientacion_deseada).get_euler().x
		var rayo_inferior := project_local_ray_normal(Vector2(get_viewport().get_visible_rect().size.x * 0.5, get_viewport().get_visible_rect().size.y))
		var margen_angular := atan2(-rayo_inferior.y, -rayo_inferior.z) * 0.55
		var inclinacion_segura := minf(inclinacion_base, inclinacion_objetivo + margen_angular)
		orientacion_deseada = Quaternion(Vector3.RIGHT, maxf(-PI * 0.5, inclinacion_segura))
		posicion_deseada = _limitar_encuadre(posicion_deseada, Basis(orientacion_deseada))
	if _peso_orbita_aura > 0.001:
		var punto_mirada := objetivo.global_position + Vector3.UP * 0.85
		var orientacion_orbita := Basis.looking_at(punto_mirada - posicion_deseada, Vector3.UP).get_rotation_quaternion()
		orientacion_deseada = orientacion_deseada.slerp(orientacion_orbita, _peso_orbita_aura)
	var avance := 1.0 - exp(-suavizado * delta)
	_posicion_seguimiento = _posicion_seguimiento.lerp(posicion_deseada, avance)
	_orientacion = _orientacion.slerp(orientacion_deseada, 1.0 - exp(-suavizado_giro * delta))
	global_basis = Basis(_orientacion)

	# Dos senos a frecuencias 1:2 dibujan un infinito en el plano de la pantalla.
	# Se aplica después del seguimiento para evitar deriva o acumulación del balanceo.
	_fase_balanceo = fposmod(_fase_balanceo + TAU * delta / periodo_balanceo, TAU)
	_peso_balanceo = lerpf(_peso_balanceo, 1.0 if balanceo_activo else 0.0, avance)
	var balanceo := Vector2(sin(_fase_balanceo), sin(2.0 * _fase_balanceo)) * amplitud_balanceo * _peso_balanceo
	if balanceo_activo:
		balanceo += _temblor
	# Limita también cada cuadro intermedio y el balanceo, no solo el destino.
	_posicion_seguimiento = _limitar_encuadre(_posicion_seguimiento, global_basis)
	global_position = _limitar_encuadre(_posicion_seguimiento + global_basis.x * balanceo.x + global_basis.y * balanceo.y, global_basis)


func _obtener_zoom_explosion_final() -> float:
	if not is_instance_valid(objetivo):
		return 0.0
	var animacion: Variant = objetivo.get("gestos")
	if not is_instance_valid(animacion) or animacion.get("gesto") != &"explosion_final":
		return 0.0
	var duracion_gesto := maxf(0.001, float(animacion.get("duracion")))
	var progreso := float(animacion.get("tiempo")) / duracion_gesto
	return smoothstep(0.40, 0.58, progreso) * (1.0 - smoothstep(0.93, 1.0, progreso))


func _alternar_camara_libre() -> void:
	if not is_instance_valid(objetivo):
		return
	_camara_libre = not _camara_libre
	if _camara_libre:
		_bloqueo_previo_jugador = bool(objetivo.get("input_locked"))
		objetivo.set("input_locked", true)
		_modo_mouse_previo = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var angulos := global_rotation
		_pitch_libre = angulos.x
		_yaw_libre = angulos.y
		_mostrar_ayuda_camara_libre(true)
	else:
		Input.mouse_mode = _modo_mouse_previo
		objetivo.set("input_locked", _bloqueo_previo_jugador)
		_mostrar_ayuda_camara_libre(false)
		_posicion_seguimiento = global_position
		_orientacion = global_basis.orthonormalized().get_rotation_quaternion()


func _actualizar_camara_libre(delta: float) -> void:
	var lateral := (1.0 if Input.is_key_pressed(KEY_D) else 0.0) - (1.0 if Input.is_key_pressed(KEY_A) else 0.0)
	var adelante := (1.0 if Input.is_key_pressed(KEY_W) else 0.0) - (1.0 if Input.is_key_pressed(KEY_S) else 0.0)
	var vertical := (1.0 if Input.is_key_pressed(KEY_SPACE) else 0.0) - (1.0 if Input.is_key_pressed(KEY_CTRL) else 0.0)
	var direccion := global_basis.x * lateral - global_basis.z * adelante + Vector3.UP * vertical
	if direccion.length_squared() < 0.001:
		return
	var rapidez := 6.0
	if Input.is_key_pressed(KEY_SHIFT):
		rapidez = 18.0
	elif Input.is_key_pressed(KEY_ALT):
		rapidez = 2.0
	global_position += direccion.normalized() * rapidez * delta


func _mostrar_ayuda_camara_libre(mostrar: bool) -> void:
	if mostrar:
		var capa := CanvasLayer.new()
		capa.name = "AyudaCamaraLibre"
		capa.layer = 100
		add_child(capa)
		_ayuda_camara_libre = Label.new()
		_ayuda_camara_libre.text = "CÁMARA LIBRE  ·  WASD mover  ·  Espacio/Ctrl subir/bajar  ·  Mayús rápido  ·  F5 salir"
		_ayuda_camara_libre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ayuda_camara_libre.add_theme_color_override("font_color", Color("fff1d8"))
		_ayuda_camara_libre.add_theme_color_override("font_shadow_color", Color(0.02, 0.06, 0.08, 0.9))
		_ayuda_camara_libre.add_theme_constant_override("shadow_offset_x", 2)
		_ayuda_camara_libre.add_theme_constant_override("shadow_offset_y", 2)
		_ayuda_camara_libre.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_ayuda_camara_libre.offset_top = -46.0
		_ayuda_camara_libre.offset_bottom = -16.0
		capa.add_child(_ayuda_camara_libre)
	elif is_instance_valid(_ayuda_camara_libre):
		_ayuda_camara_libre.get_parent().queue_free()
		_ayuda_camara_libre = null


func _limitar_encuadre(posicion: Vector3, orientacion: Basis) -> Vector3:
	if not zona_segura_activa:
		return posicion
	var minimo := recinto_visible.position + Vector2.ONE * margen_pared
	var maximo := recinto_visible.end - Vector2.ONE * margen_pared
	if posicion.y > altura_pared:
		# Proyecta las esquinas sobre la altura de los muros. Por debajo, las
		# paredes ya cierran la vista; por encima, todo el encuadre debe caber.
		var pantalla := get_viewport().get_visible_rect().size
		var alcance_min := Vector2.ZERO
		var alcance_max := Vector2.ZERO
		for esquina: Vector2 in [Vector2.ZERO, Vector2(pantalla.x, 0), pantalla, Vector2(0, pantalla.y)]:
			var rayo := orientacion * project_local_ray_normal(esquina)
			if rayo.y >= -0.001:
				# Una transición aún demasiado horizontal se mantiene bajo el muro.
				posicion.y = altura_pared - margen_pared
				alcance_min = Vector2.ZERO
				alcance_max = Vector2.ZERO
				break
			var alcance := Vector2(rayo.x, rayo.z) / -rayo.y
			alcance_min = alcance_min.min(alcance)
			alcance_max = alcance_max.max(alcance)
		var amplitud := alcance_max - alcance_min
		var disponible := maximo - minimo
		var altura_disponible := posicion.y - altura_pared
		if amplitud.x > 0.001:
			altura_disponible = minf(altura_disponible, disponible.x / amplitud.x)
		if amplitud.y > 0.001:
			altura_disponible = minf(altura_disponible, disponible.y / amplitud.y)
		posicion.y = minf(posicion.y, altura_pared + altura_disponible)
		minimo -= alcance_min * altura_disponible
		maximo -= alcance_max * altura_disponible
	posicion.x = clampf(posicion.x, minimo.x, maxf(minimo.x, maximo.x))
	posicion.z = clampf(posicion.z, minimo.y, maxf(minimo.y, maximo.y))
	return posicion
