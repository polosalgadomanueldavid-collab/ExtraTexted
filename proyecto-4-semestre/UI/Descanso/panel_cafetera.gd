extends Control
## Objeto 3D sobre la partida: el viewport no incluye fondo, suelo ni escenario.

signal servir_solicitado
signal recoger_solicitado
signal cerrar_solicitado

const CREMA := Color("fff1d8")
const PETROLEO := Color("173b50")
const CORAL := Color("ff785f")
const FUENTE := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")

var vista: SubViewport
var camara: Camera3D
var boton_servir: Button
var boton_taza: Button
var _modelo: Node3D
var _pulsador: MeshInstance3D
var _taza: Node3D
var _cafe: MeshInstance3D
var _chorro: MeshInstance3D
var _vapor: Node3D
var _pantalla: Label3D
var _precio: Label3D
var _beneficio: Label3D
var _fondo: ColorRect
var _tiempo := 0.0
var _preparando := false
var _lista := false
var _raton_anterior: Input.MouseMode


func _ready() -> void:
	name = "CafeteraPrimeraPersona"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fondo = ColorRect.new()
	_fondo.name = "EscenarioTraslucido"
	_fondo.color = Color(0.025, 0.06, 0.085, 0.48)
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fondo)
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var contenedor := SubViewportContainer.new()
	contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenedor.stretch = true
	add_child(contenedor)
	contenedor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vista = SubViewport.new()
	vista.name = "ObjetoSinFondo"
	vista.own_world_3d = true
	vista.transparent_bg = true
	vista.handle_input_locally = false
	vista.gui_disable_input = true
	vista.msaa_3d = Viewport.MSAA_4X
	contenedor.add_child(vista)
	_modelo = Node3D.new()
	vista.add_child(_modelo)
	camara = Camera3D.new()
	camara.fov = 32.0
	vista.add_child(camara)
	camara.current = true
	var ambiente := WorldEnvironment.new()
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_CLEAR_COLOR
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color("dce9ee")
	entorno.ambient_light_energy = 0.65
	ambiente.environment = entorno
	vista.add_child(ambiente)
	_luz(Vector3(-3, 5, 5), 1.5, Color("fff1da"))
	_luz(Vector3(4, 3, 1), 0.75, Color("c5e5ff"))
	_crear_maquina()
	boton_servir = _crear_boton("Pulsar botón de la cafetera", servir_solicitado.emit, _pulsador)
	boton_taza = _crear_boton("Recoger taza de café", recoger_solicitado.emit)
	resized.connect(_ajustar)
	visibility_changed.connect(_actualizar_render)
	hide()
	_ajustar.call_deferred()


func _material(color: Color, metal: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.36 if metal > 0.0 else 0.55
	mat.metallic = metal
	return mat


func _malla(padre: Node3D, forma: Mesh, posicion: Vector3, color: Color, metal: float = 0.0) -> MeshInstance3D:
	var objeto := MeshInstance3D.new()
	objeto.mesh = forma
	objeto.position = posicion
	objeto.material_override = _material(color, metal)
	padre.add_child(objeto)
	return objeto


func _caja(tamano: Vector3, posicion: Vector3, color: Color, metal: float = 0.0) -> MeshInstance3D:
	var forma := BoxMesh.new()
	forma.size = tamano
	return _malla(_modelo, forma, posicion, color, metal)


func _cilindro(padre: Node3D, radio: float, altura: float, posicion: Vector3, color: Color, metal: float = 0.0) -> MeshInstance3D:
	var forma := CylinderMesh.new()
	forma.top_radius = radio
	forma.bottom_radius = radio
	forma.height = altura
	forma.radial_segments = 48
	return _malla(padre, forma, posicion, color, metal)


func _letrero(texto: String, posicion: Vector3, escala: float, color: Color = PETROLEO) -> Label3D:
	var etiqueta := Label3D.new()
	etiqueta.text = texto
	var fuente_gruesa := FontVariation.new()
	fuente_gruesa.base_font = FUENTE
	fuente_gruesa.variation_embolden = 1.0
	etiqueta.font = fuente_gruesa
	etiqueta.font_size = 64
	etiqueta.pixel_size = escala
	etiqueta.modulate = color
	etiqueta.outline_size = 0
	etiqueta.position = posicion
	etiqueta.no_depth_test = false
	_modelo.add_child(etiqueta)
	return etiqueta


func _luz(posicion: Vector3, energia: float, color: Color) -> void:
	var luz := DirectionalLight3D.new()
	vista.add_child(luz)
	luz.position = posicion
	luz.look_at(Vector3(0, 1.4, 0))
	luz.light_energy = energia
	luz.light_color = color
	luz.shadow_enabled = energia > 1.0


func _crear_maquina() -> void:
	var metal := Color("a0b5ba")
	var oscuro := Color("0b2533")
	_caja(Vector3(2.5, 0.17, 1.65), Vector3(0, 0.1, 0), PETROLEO)
	_caja(Vector3(2.3, 2.45, 0.36), Vector3(0, 1.45, -0.55), PETROLEO)
	_caja(Vector3(0.26, 2.3, 1.25), Vector3(-1.02, 1.42, -0.05), CREMA)
	_caja(Vector3(0.55, 2.3, 1.25), Vector3(0.91, 1.42, -0.05), CREMA)
	_caja(Vector3(2.3, 0.57, 1.45), Vector3(0, 2.4, 0), CREMA)
	_caja(Vector3(2.12, 0.05, 1.22), Vector3(0, 2.71, -0.03), metal, 0.7)
	_caja(Vector3(1.43, 1.45, 0.05), Vector3(-0.25, 1.24, -0.32), oscuro)
	_caja(Vector3(1.6, 0.12, 1.04), Vector3(-0.25, 0.3, 0.14), metal, 0.65)
	for i in 12:
		_caja(Vector3(0.045, 0.012, 0.82), Vector3(-0.94 + i * 0.125, 0.367, 0.17), oscuro)
	_caja(Vector3(0.67, 0.2, 0.65), Vector3(-0.25, 2.01, 0.11), PETROLEO)
	_cilindro(_modelo, 0.14, 0.24, Vector3(-0.25, 1.82, 0.34), metal, 0.7)
	_cilindro(_modelo, 0.075, 0.07, Vector3(-0.25, 1.67, 0.34), oscuro)
	var aro := _cilindro(_modelo, 0.245, 0.04, Vector3(0.91, 1.43, 0.597), metal, 0.8)
	aro.rotation.x = PI / 2.0
	_pulsador = _cilindro(_modelo, 0.205, 0.07, Vector3(0.91, 1.43, 0.63), CORAL)
	_pulsador.rotation.x = PI / 2.0
	_caja(Vector3(0.48, 0.32, 0.05), Vector3(0.91, 1.96, 0.6), oscuro)
	_caja(Vector3(0.42, 0.25, 0.015), Vector3(0.91, 1.96, 0.632), Color("bfd5b4"))
	_pantalla = _letrero("LISTA", Vector3(0.91, 1.96, 0.647), 0.0017)
	_letrero("CAFÉ DE TURNO", Vector3(0, 2.43, 0.736), 0.0032)
	_beneficio = _letrero("+15 CALMA", Vector3(0, 2.23, 0.736), 0.0014)
	_letrero("SERVIR", Vector3(0.91, 1.08, 0.587), 0.0017)
	_precio = _letrero("50 PTS", Vector3(0.91, 0.91, 0.587), 0.0017)
	_letrero("ESC · SALIR", Vector3(0, 0.12, 0.837), 0.0014, CREMA)
	_taza = Node3D.new()
	_taza.position = Vector3(-0.25, 0.38, 0.34)
	_modelo.add_child(_taza)
	var exterior := CylinderMesh.new()
	exterior.top_radius = 0.3
	exterior.bottom_radius = 0.25
	exterior.height = 0.48
	exterior.cap_top = false
	exterior.radial_segments = 48
	_malla(_taza, exterior, Vector3(0, 0.24, 0), CREMA)
	var interior := CylinderMesh.new()
	interior.top_radius = 0.267
	interior.bottom_radius = 0.222
	interior.height = 0.43
	interior.cap_top = false
	interior.flip_faces = true
	interior.radial_segments = 48
	_malla(_taza, interior, Vector3(0, 0.265, 0), CREMA.darkened(0.08))
	var borde := TorusMesh.new()
	borde.inner_radius = 0.267
	borde.outer_radius = 0.3
	_malla(_taza, borde, Vector3(0, 0.48, 0), CREMA)
	var asa := TorusMesh.new()
	asa.inner_radius = 0.125
	asa.outer_radius = 0.225
	_malla(_taza, asa, Vector3(0.34, 0.25, 0), CREMA).rotation.x = PI / 2.0
	_cafe = _cilindro(_taza, 0.26, 0.015, Vector3(0, 0.12, 0), Color("522b19"))
	_chorro = _cilindro(_modelo, 0.018, 0.79, Vector3(-0.25, 1.24, 0.34), Color("713b1c"))
	_vapor = Node3D.new()
	_modelo.add_child(_vapor)
	for i in 3:
		var linea := _cilindro(_vapor, 0.008, 0.23, Vector3(-0.38 + i * 0.13, 1.06 + (i % 2) * 0.06, 0.34), CREMA)
		linea.rotation.z = -0.18 + i * 0.18
		var mat := linea.material_override as StandardMaterial3D
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.3


func _crear_boton(nombre: String, accion: Callable, objeto: MeshInstance3D = null) -> Button:
	var boton := Button.new()
	boton.name = "BotonServir" if objeto != null else "RecogerTaza"
	boton.accessibility_name = nombre
	boton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for estilo: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		boton.add_theme_stylebox_override(estilo, StyleBoxEmpty.new())
	boton.pressed.connect(accion)
	if objeto != null:
		boton.mouse_entered.connect(_resaltar.bind(true))
		boton.mouse_exited.connect(_resaltar.bind(false))
		boton.focus_entered.connect(_resaltar.bind(true))
		boton.focus_exited.connect(_resaltar.bind(false))
	add_child(boton)
	return boton


func _resaltar(activo: bool) -> void:
	var mat := _pulsador.material_override as StandardMaterial3D
	mat.emission_enabled = activo and not boton_servir.disabled
	mat.emission = CORAL
	mat.emission_energy_multiplier = 0.25


func abrir(precio: int, beneficio: int) -> void:
	_raton_anterior = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_precio.text = "%d PTS" % precio
	_beneficio.text = "+%d CALMA AL BEBER" % beneficio
	_preparando = false
	_lista = false
	_tiempo = 0.0
	_taza.show()
	_cafe.hide()
	_chorro.hide()
	_vapor.hide()
	_pantalla.text = "LISTA"
	boton_servir.disabled = false
	boton_taza.hide()
	show()
	_ajustar()
	boton_servir.grab_focus()


func cerrar() -> void:
	if not visible:
		return
	hide()
	Input.mouse_mode = _raton_anterior
	if boton_servir.is_inside_tree():
		boton_servir.release_focus()
		boton_taza.release_focus()


func preparando() -> void:
	_preparando = true
	boton_servir.disabled = true
	_resaltar(false)
	_pantalla.text = "SIRVIENDO"
	_cafe.show()
	_chorro.show()


func actualizar_progreso(avance: float) -> void:
	_cafe.position.y = lerpf(0.12, 0.445, avance)
	_pulsador.position.z = 0.63 - sin(minf(1.0, avance * 5.0) * PI) * 0.04
	_chorro.visible = avance > 0.06 and avance < 0.96
	_vapor.visible = avance > 0.8


func lista() -> void:
	_preparando = false
	_lista = true
	_chorro.hide()
	_vapor.show()
	_pantalla.text = "RETIRA"
	boton_taza.show()
	boton_taza.grab_focus()


func mostrar_error(texto: String) -> void:
	_pantalla.text = texto


func _actualizar_render() -> void:
	if is_instance_valid(vista):
		vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	set_process(visible)
	set_process_input(visible)
	set_process_unhandled_input(visible)


func _ajustar() -> void:
	if not is_instance_valid(camara) or size.y <= 0.0:
		return
	var aspecto := size.x / size.y
	camara.position = Vector3(0, 2.05, maxf(6.0, 1.6 / (tan(deg_to_rad(16.0)) * aspecto)))
	camara.look_at(Vector3(0, 1.4, 0))
	_colocar_boton(boton_servir, Vector3(0.91, 1.43, 0.67), Vector2(0.46, 0.46))
	_colocar_boton(boton_taza, Vector3(-0.2, 0.65, 0.64), Vector2(0.77, 0.57))


func _colocar_boton(boton: Button, centro: Vector3, medidas: Vector2) -> void:
	if not is_instance_valid(boton):
		return
	var inicio := camara.unproject_position(centro + Vector3(-medidas.x, medidas.y, 0) * 0.5)
	var fin := camara.unproject_position(centro + Vector3(medidas.x, -medidas.y, 0) * 0.5)
	boton.position = inicio
	boton.size = (fin - inicio).max(Vector2(44, 44))


func _process(delta: float) -> void:
	_tiempo += delta
	if _lista or _preparando:
		_vapor.position.y = sin(_tiempo * 2.0) * 0.025
	_ajustar()


func _input(evento: InputEvent) -> void:
	if not visible or get_tree().paused:
		return
	if evento is InputEventKey:
		var tecla: int = evento.physical_keycode if evento.physical_keycode != 0 else evento.keycode
		if tecla in [KEY_ESCAPE, KEY_E]:
			get_viewport().set_input_as_handled()
			if evento.pressed and not evento.echo:
				cerrar_solicitado.emit()


func _unhandled_input(_evento: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if visible:
		Input.mouse_mode = _raton_anterior
