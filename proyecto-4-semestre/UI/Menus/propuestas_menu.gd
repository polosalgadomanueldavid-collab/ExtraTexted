extends Control
## Galería interactiva de cuatro composiciones. No sustituye el menú principal.

const ESCENA_MENU := preload("res://UI/Menus/MainMenu.tscn")
const MODELO_POLICIA := preload("res://Personajes/PoliciaAzul/policia_azul.glb")
const FUENTE := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
const NOMBRES := ["01  Escolta", "02  Compañeros", "03  Expediente", "04  Primer plano"]
const DESCRIPCIONES := [
	"Dos policías flanquean el menú. La oficina queda al fondo.",
	"Menú a la izquierda; dos policías posan a la derecha.",
	"Menú a la derecha; los policías ocupan la zona de investigación.",
	"Menú compacto y un policía protagonista en primer plano."
]

var _escena_3d: Node3D
var _camara: Camera3D
var _policias: Array[Node3D] = []
var _animadores: Array[AnimationPlayer] = []
var _luces_pantalla: Array[OmniLight3D] = []
var _luz_techo: OmniLight3D
var _menu: Control
var _tabs: Array[Button] = []
var _descripcion: Label
var _indice := 0
var _tiempo := 0.0
var _saludo_pendiente := 3.0


func _ready() -> void:
	_crear_escenario()
	_menu = ESCENA_MENU.instantiate()
	add_child(_menu)
	_menu.get_node("FondoOficina").hide()
	_menu.get_node("Background").hide()
	_menu.get_node("CenterContainer/MenuPanel").remove_theme_stylebox_override("panel")
	_crear_navegacion()
	_mostrar_propuesta(0)
	if "--capturas" in OS.get_cmdline_user_args():
		call_deferred("_capturar_todas")


func _process(delta: float) -> void:
	_tiempo += delta
	# Movimiento discreto de cámara, monitores y luz de la oficina.
	_camara.position.x = sin(_tiempo * 0.24) * 0.13
	_luz_techo.light_energy = 0.55 + sin(_tiempo * 1.7) * 0.05
	for i in _luces_pantalla.size():
		_luces_pantalla[i].light_energy = 0.17 + sin(_tiempo * (1.1 + i * 0.25)) * 0.04
	_saludo_pendiente -= delta
	if _saludo_pendiente <= 0.0 and _animadores.size() == 2:
		_reproducir(_animadores[1], "wave")
		_saludo_pendiente = 8.0


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
		_mostrar_propuesta(event.keycode - KEY_1)
	elif event.keycode == KEY_F12:
		call_deferred("_capturar_actual")


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
	_escena_3d = Node3D.new()
	vista.add_child(_escena_3d)

	var entorno := WorldEnvironment.new()
	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = Color("173b50")
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color("bacbd0")
	ambiente.ambient_light_energy = 0.4
	ambiente.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	entorno.environment = ambiente
	_escena_3d.add_child(entorno)

	_camara = Camera3D.new()
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camara.size = 7.9
	_camara.position = Vector3(0, 3.25, 12.0)
	_escena_3d.add_child(_camara)
	_camara.look_at(Vector3(0, 2.12, 0))
	_camara.current = true

	var luz_principal := DirectionalLight3D.new()
	luz_principal.rotation_degrees = Vector3(-42, -22, 0)
	luz_principal.light_color = Color("fff1d8")
	luz_principal.light_energy = 0.8
	_escena_3d.add_child(luz_principal)
	_luz_techo = _luz(Vector3(0, 5.5, 1), Color("d7e5dd"), 0.55, 12)
	_luz(Vector3(-5.4, 3.6, 3.8), Color("ffab86"), 0.32, 7)
	_luz(Vector3(5.4, 3.6, 3.8), Color("9dc8de"), 0.4, 7)

	# La escenografía toma la paleta y el mobiliario de la oficina del juego.
	_caja("Suelo", Vector3(0, -0.16, 0), Vector3(16, 0.3, 13), Color("1d3d4c"))
	_caja("Pared trasera", Vector3(0, 3.25, -4.25), Vector3(16, 6.5, 0.25), Color("254252"))
	_caja("Pared izquierda", Vector3(-7.9, 3.25, 0), Vector3(0.25, 6.5, 13), Color("1e3948"))
	_caja("Pared derecha", Vector3(7.9, 3.25, 0), Vector3(0.25, 6.5, 13), Color("1e3948"))
	for i in range(-7, 8):
		_caja("Junta suelo", Vector3(i, 0.001, 0), Vector3(0.012, 0.006, 13), Color("2b4b58"))
	for z in [-3.0, -1.0, 1.0, 3.0, 5.0]:
		_caja("Junta suelo", Vector3(0, 0.002, z), Vector3(16, 0.006, 0.012), Color("2b4b58"))
	for x in [-5.1, 0.0, 5.1]:
		_caja("Ventana", Vector3(x, 4.25, -4.06), Vector3(3.25, 2.0, 0.035), Color("102c3e"), true)
		_caja("Marco vertical", Vector3(x, 4.25, -4.025), Vector3(0.075, 2.08, 0.06), Color("e8e6d2"))
		_caja("Marco horizontal", Vector3(x, 4.25, -4.02), Vector3(3.3, 0.065, 0.06), Color("e8e6d2"))
		_caja("Luz de ciudad", Vector3(x - 0.85, 3.68, -4.0), Vector3(0.22, 0.2, 0.06), Color("db9c77"), true)
		_caja("Luz de ciudad", Vector3(x + 0.92, 4.02, -4.0), Vector3(0.16, 0.13, 0.06), Color("82aebc"), true)
	_caja("Franja baja", Vector3(0, 1.15, -4.01), Vector3(16, 0.14, 0.08), Color("183d50"))
	_crear_escritorio(-4.8, -1.9)
	_crear_escritorio(4.8, -1.9)
	_crear_tablero()
	for i in 2:
		var policia: Node3D = MODELO_POLICIA.instantiate()
		_escena_3d.add_child(policia)
		_policias.append(policia)
		var animador := policia.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_animadores.append(animador)
		_reproducir(animador, "idle")
		if animador != null:
			animador.animation_finished.connect(_al_terminar_animacion.bind(animador))


func _crear_escritorio(x: float, z: float) -> void:
	_caja("Mesa", Vector3(x, 0.95, z), Vector3(3.2, 0.16, 1.3), Color("ae805c"))
	_caja("Frente mesa", Vector3(x, 0.48, z + 0.49), Vector3(2.9, 0.85, 0.13), Color("704c3d"))
	for dx in [-1.38, 1.38]:
		_caja("Pata", Vector3(x + dx, 0.45, z), Vector3(0.12, 0.9, 1.05), Color("533d3b"))
	_caja("Monitor", Vector3(x, 1.59, z - 0.18), Vector3(1.25, 0.83, 0.13), Color("102b3b"))
	_caja("Pantalla", Vector3(x, 1.59, z - 0.095), Vector3(1.1, 0.67, 0.013), Color("4e9cba"), true)
	_caja("Soporte", Vector3(x, 1.13, z - 0.18), Vector3(0.12, 0.3, 0.12), Color("193344"))
	_caja("Teclado", Vector3(x, 1.05, z + 0.38), Vector3(0.85, 0.045, 0.28), Color("183646"))
	_caja("Archivadores", Vector3(x - 1.1, 1.14, z - 0.3), Vector3(0.32, 0.26, 0.45), Color("f7dfb2"))
	_luces_pantalla.append(_luz(Vector3(x, 1.62, z + 0.35), Color("64c4e6"), 0.17, 2.8))


func _crear_tablero() -> void:
	_caja("Tablero", Vector3(0, 1.9, -4.03), Vector3(2.5, 1.24, 0.11), Color("ac765a"))
	for x in [-0.7, -0.1, 0.58]:
		_caja("Expediente", Vector3(x, 1.95 + x * 0.22, -3.94), Vector3(0.43, 0.52, 0.018), Color("ffe9c5"))
	_caja("Lámpara techo", Vector3(0, 6.0, 0.5), Vector3(3.2, 0.12, 0.55), Color("dfecdf"), true)


func _caja(nombre: String, posicion: Vector3, tamano: Vector3, color: Color, emision := false) -> MeshInstance3D:
	var instancia := MeshInstance3D.new()
	instancia.name = nombre
	var malla := BoxMesh.new()
	malla.size = tamano
	instancia.mesh = malla
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	if emision:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.35
	instancia.material_override = material
	instancia.position = posicion
	_escena_3d.add_child(instancia)
	return instancia


func _luz(posicion: Vector3, color: Color, energia: float, alcance: float) -> OmniLight3D:
	var luz := OmniLight3D.new()
	luz.position = posicion
	luz.light_color = color
	luz.light_energy = energia
	luz.omni_range = alcance
	luz.shadow_enabled = true
	_escena_3d.add_child(luz)
	return luz


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


func _crear_navegacion() -> void:
	var barra := PanelContainer.new()
	barra.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	barra.custom_minimum_size.y = 64
	barra.offset_bottom = 64
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color("0a2b3ad9")
	fondo.content_margin_left = 22
	fondo.content_margin_right = 22
	fondo.content_margin_top = 8
	fondo.content_margin_bottom = 8
	barra.add_theme_stylebox_override("panel", fondo)
	add_child(barra)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	barra.add_child(fila)
	var etiqueta := Label.new()
	etiqueta.text = "PROPUESTAS DE MENÚ"
	etiqueta.add_theme_font_override("font", FUENTE)
	etiqueta.add_theme_font_size_override("font_size", 21)
	etiqueta.add_theme_color_override("font_color", Color("fff1d8"))
	etiqueta.custom_minimum_size.x = 250
	fila.add_child(etiqueta)
	for i in NOMBRES.size():
		var boton := Button.new()
		boton.text = NOMBRES[i]
		boton.custom_minimum_size = Vector2(175, 42)
		boton.add_theme_font_override("font", FUENTE)
		boton.add_theme_font_size_override("font_size", 19)
		boton.pressed.connect(_mostrar_propuesta.bind(i))
		fila.add_child(boton)
		_tabs.append(boton)
	var nota := Label.new()
	nota.text = "1–4: cambiar · F12: captura"
	nota.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nota.add_theme_font_override("font", FUENTE)
	nota.add_theme_font_size_override("font_size", 17)
	nota.add_theme_color_override("font_color", Color("b9d8df"))
	fila.add_child(nota)
	_descripcion = Label.new()
	_descripcion.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_descripcion.offset_top = -52
	_descripcion.offset_bottom = 0
	_descripcion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_descripcion.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_descripcion.add_theme_font_override("font", FUENTE)
	_descripcion.add_theme_font_size_override("font_size", 22)
	_descripcion.add_theme_color_override("font_color", Color("fff1d8"))
	_descripcion.add_theme_color_override("font_shadow_color", Color("071d29"))
	_descripcion.add_theme_constant_override("shadow_offset_x", 2)
	_descripcion.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_descripcion)


func _mostrar_propuesta(indice: int) -> void:
	_indice = indice
	_descripcion.text = DESCRIPCIONES[indice]
	for i in _tabs.size():
		_tabs[i].modulate = Color("ffb493") if i == indice else Color.WHITE
	var posiciones := [
		[Vector3(-4.7, 0, 1.45), Vector3(4.7, 0, 1.45)],
		[Vector3(2.9, 0, 1.2), Vector3(5.15, 0, 2.0)],
		[Vector3(-5.15, 0, 2.0), Vector3(-2.9, 0, 1.2)],
		[Vector3(1.65, 0, -0.25), Vector3(4.5, 0, 2.1)]
	]
	var angulos := [[12.0, -12.0], [17.0, -18.0], [12.0, -17.0], [12.0, -18.0]]
	var escalas := [[1.36, 1.36], [1.26, 1.5], [1.26, 1.5], [0.95, 1.85]]
	for i in _policias.size():
		_policias[i].position = posiciones[indice][i]
		_policias[i].rotation_degrees.y = angulos[indice][i]
		_policias[i].scale = Vector3.ONE * escalas[indice][i]
	_menu.desplazamiento_horizontal = [0.0, -480.0, 480.0, -520.0][indice]
	_menu.desplazamiento_vertical = [0.0, 0.0, 0.0, -70.0][indice]
	_menu.escala_presentacion = [1.0, 1.0, 1.0, 0.78][indice]
	_menu._ajustar_escala()
	if indice > 0 and _animadores.size() == 2:
		_reproducir(_animadores[0 if indice == 2 else 1], "wave")


func _capturar_actual() -> void:
	await RenderingServer.frame_post_draw
	var ruta := "res://UI/Menus/Propuestas/captura_%02d.png" % (_indice + 1)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://UI/Menus/Propuestas"))
	get_viewport().get_texture().get_image().save_png(ruta)
	print("CAPTURA: ", ProjectSettings.globalize_path(ruta))


func _capturar_todas() -> void:
	for i in NOMBRES.size():
		_mostrar_propuesta(i)
		await get_tree().create_timer(1.0).timeout
		await _capturar_actual()
	get_tree().quit()
