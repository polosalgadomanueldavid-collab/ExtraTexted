extends Control
## Decorado del menú: oficina jugable, dos policías y degradado izquierdo.

const ESCENA_OFICINA := preload("res://Mundo/Oficina.tscn")
const MODELO_POLICIA := preload("res://Personajes/PoliciaAzul/policia_azul.glb")
const DEGRADADO := preload("res://UI/Menus/degradado_oficina_menu.gdshader")

var degradado: ColorRect
var _camara: Camera3D
var _luces: Array[OmniLight3D] = []
var _animadores: Array[AnimationPlayer] = []
var _policias: Array[Node3D] = []
var _discusion_activa := false
var _tiempo := 0.0
var _saludo_pendiente := 4.0


func _ready() -> void:
	_crear_escenario()
	degradado = ColorRect.new()
	degradado.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	degradado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = DEGRADADO
	degradado.material = material
	add_child(degradado)


func _process(delta: float) -> void:
	_tiempo += delta
	_camara.position.x = -0.3 + sin(_tiempo * 0.24) * 0.025
	for i in _luces.size():
		_luces[i].light_energy = 0.48 + sin(_tiempo * (1.4 + i * 0.3)) * 0.045
	for i in _policias.size():
		var orientacion := 14.0 if i == 0 else -18.0
		if _discusion_activa:
			orientacion = 46.0 if i == 0 else -46.0
		_policias[i].rotation_degrees.y = lerpf(_policias[i].rotation_degrees.y, orientacion, minf(delta * 3.0, 1.0))
	if _discusion_activa:
		return
	_saludo_pendiente -= delta
	if _saludo_pendiente <= 0.0:
		_reproducir(_animadores[0], "wave")
		_saludo_pendiente = 8.0


func _crear_escenario() -> void:
	var contenedor := SubViewportContainer.new()
	contenedor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	contenedor.stretch = true
	contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(contenedor)
	var vista := SubViewport.new()
	vista.size = Vector2i(1600, 900)
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	contenedor.add_child(vista)
	var escenario := Node3D.new()
	vista.add_child(escenario)

	var oficina: Node3D = ESCENA_OFICINA.instantiate()
	# Se conserva la geometría real sin iniciar la lógica de la partida.
	for nombre in ["Gameplay", "CanvasLayer", "EventoApagon", "TacoLuz", "Computer"]:
		var nodo := oficina.get_node_or_null(nombre)
		if nodo != null:
			oficina.remove_child(nodo)
			nodo.free()
	_quitar_logica(oficina)
	var estructura := oficina.get_node("Pared, suelo, techo")
	# La cámara queda dentro de la sala; se retira solo la pared frontal.
	estructura.get_node("Pared4").hide()
	escenario.add_child(oficina)

	var entorno := WorldEnvironment.new()
	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = Color("173b50")
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color("b8c9d0")
	ambiente.ambient_light_energy = 0.42
	ambiente.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	entorno.environment = ambiente
	escenario.add_child(entorno)

	_camara = Camera3D.new()
	_camara.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camara.fov = 58.0
	_camara.position = Vector3(-0.3, 3.2, 10.5)
	escenario.add_child(_camara)
	_camara.look_at(Vector3(-0.8, 1.5, 1.8))
	_camara.current = true
	resized.connect(_ajustar_camara)
	_ajustar_camara()

	var luz_frontal := DirectionalLight3D.new()
	luz_frontal.rotation_degrees = Vector3(-37, -20, 0)
	luz_frontal.light_color = Color("fff1d8")
	luz_frontal.light_energy = 0.72
	escenario.add_child(luz_frontal)
	for posicion in [Vector3(-0.3, 4.2, 9.6), Vector3(2.1, 4.0, 9.2)]:
		var luz := OmniLight3D.new()
		luz.position = posicion
		luz.light_color = Color("d6ecf0")
		luz.light_energy = 0.48
		luz.omni_range = 6.0
		luz.shadow_enabled = true
		escenario.add_child(luz)
		_luces.append(luz)

	for i in 2:
		var policia: Node3D = MODELO_POLICIA.instantiate()
		policia.position = [Vector3(0.2, 0.4, 6.65), Vector3(1.5, 0.4, 6.75)][i]
		policia.rotation_degrees.y = [14.0, -18.0][i]
		policia.scale = Vector3.ONE * [1.0, 1.05][i]
		escenario.add_child(policia)
		_policias.append(policia)
		var animador := policia.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_animadores.append(animador)
		_reproducir(animador, "idle")
		if animador != null:
			animador.animation_finished.connect(_al_terminar_animacion.bind(animador))


func establecer_discusion(activa: bool) -> void:
	_discusion_activa = activa
	if not activa:
		_saludo_pendiente = 4.0


func gesticular(indice: int) -> void:
	if _discusion_activa and indice >= 0 and indice < _animadores.size():
		_reproducir(_animadores[indice], "wave")


func _quitar_logica(nodo: Node) -> void:
	if nodo.get_script() != null:
		nodo.set_script(null)
	for hijo in nodo.get_children():
		_quitar_logica(hijo)


func _ajustar_camara() -> void:
	# Mantiene el encuadre horizontal en pantallas más estrechas.
	var proporcion := size.x / maxf(size.y, 1.0)
	var apertura := tan(deg_to_rad(58.0) * 0.5) * maxf(1.0, (16.0 / 9.0) / proporcion)
	_camara.fov = rad_to_deg(2.0 * atan(apertura))


func _reproducir(animador: AnimationPlayer, nombre: String) -> void:
	if animador == null:
		return
	for animacion in animador.get_animation_list():
		if animacion.to_lower().contains(nombre):
			animador.play(animacion)
			return


func _al_terminar_animacion(animacion: StringName, animador: AnimationPlayer) -> void:
	if String(animacion).to_lower().contains("wave"):
		_reproducir(animador, "idle")
