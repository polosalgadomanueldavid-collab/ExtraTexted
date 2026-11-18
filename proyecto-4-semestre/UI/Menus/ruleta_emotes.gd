extends Control
class_name RuletaEmotes

signal emote_seleccionado(tipo: StringName)

const PETROLEO := Color("173b50")
const PETROLEO_OSCURO := Color("0c2634")
const TURQUESA := Color("15b7c0")
const CREMA := Color("fff1d8")
const CORAL := Color("ff785f")
const FUENTE_TITULO := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const FUENTE_TEXTO := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
const ICONO_KAMEHAMEHA := preload("res://UI/Menus/ArtePiloto/Emotes/kamehameha.png")
const ICONO_RASENGAN := preload("res://UI/Menus/ArtePiloto/Emotes/rasengan.png")
const ICONO_EXPLOSION := preload("res://UI/Menus/ArtePiloto/Emotes/explosion_final.png")
const ICONO_GENKIDAMA := preload("res://UI/Menus/ArtePiloto/Emotes/genkidama.png")
const ICONO_AURA := preload("res://UI/Menus/ArtePiloto/Emotes/aura.png")
const TAMANO_LIENZO := Vector2(780.0, 780.0)
const TAMANO_BOTON := Vector2(172.0, 172.0)
const RADIO_BOTONES := 232.0

var _modo_mouse_previo: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _aura_activada := false
var _dispositivo_mando := -1
var _indice_enfocado := -1
var _lienzo: Control
var _rotulo_centro: Label
var _botones: Array[Button] = []

var _selecciones: Array[Dictionary] = [
	{"tipo": &"kamehameha", "nombre": "KAMEHAMEHA", "icono": ICONO_KAMEHAMEHA},
	{"tipo": &"rasengan", "nombre": "RASENGAN", "icono": ICONO_RASENGAN},
	{"tipo": &"explosion_final", "nombre": "EXPLOSIÓN FINAL", "icono": ICONO_EXPLOSION},
	{"tipo": &"genkidama", "nombre": "GENKIDAMA", "icono": ICONO_GENKIDAMA},
	{"tipo": &"aura_persistente", "nombre": "AURA", "icono": ICONO_AURA},
]


func _ready() -> void:
	add_to_group(&"ruleta_emotes")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resized.connect(_ajustar_presentacion)
	_crear_interfaz()
	_ajustar_presentacion()


func abrir(aura_activa: bool = false, dispositivo_mando: int = -1) -> void:
	_actualizar_opciones_multijugador()
	_modo_mouse_previo = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_aura_activada = aura_activa
	_dispositivo_mando = dispositivo_mando
	_indice_enfocado = -1
	_actualizar_estado_aura()
	visible = true
	if _dispositivo_mando >= 0 and not _botones.is_empty():
		_indice_enfocado = 0
		_botones[0].grab_focus()


func _actualizar_opciones_multijugador() -> void:
	var mostrar_duelo := SesionLAN.en_partida and SesionLAN.participantes.size() == 2
	var tiene_duelo := _selecciones.size() == 6
	if mostrar_duelo == tiene_duelo:
		return
	if mostrar_duelo:
		_selecciones.append({"tipo": &"duelo_kamehameha", "nombre": "DUELO KAMEHAMEHA", "icono": ICONO_KAMEHAMEHA})
	else:
		_selecciones.remove_at(5)
	for hijo in get_children():
		remove_child(hijo)
		hijo.queue_free()
	_botones.clear()
	_crear_interfaz()
	_ajustar_presentacion()


func cerrar() -> void:
	visible = false
	Input.mouse_mode = _modo_mouse_previo
	_indice_enfocado = -1
	_dispositivo_mando = -1
	if is_instance_valid(_lienzo):
		var foco := get_viewport().gui_get_focus_owner()
		if foco != null and is_ancestor_of(foco):
			foco.release_focus()


func _gui_input(evento: InputEvent) -> void:
	if not OS.has_feature("android") or not visible:
		return
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT and not _lienzo.get_global_rect().has_point(evento.global_position):
		var jugador := get_parent().get_parent().get("jugador") as Player
		if is_instance_valid(jugador):
			jugador.cerrar_menu_emotes(true)


func _process(_delta: float) -> void:
	if not visible or _dispositivo_mando < 0 or _botones.is_empty():
		return
	var eje := Vector2(
		Input.get_joy_axis(_dispositivo_mando, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(_dispositivo_mando, JOY_AXIS_RIGHT_Y)
	)
	if eje.length() < 0.48:
		return
	var paso := TAU / float(_botones.size())
	var indice := posmod(roundi((eje.angle() + PI * 0.5) / paso), _botones.size())
	if indice == _indice_enfocado:
		return
	_indice_enfocado = indice
	_botones[indice].grab_focus()


func _crear_interfaz() -> void:
	var fondo_general := ColorRect.new()
	fondo_general.color = Color(0.015, 0.055, 0.075, 0.74)
	fondo_general.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo_general.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo_general)

	_lienzo = Control.new()
	_lienzo.custom_minimum_size = TAMANO_LIENZO
	_lienzo.size = TAMANO_LIENZO
	_lienzo.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_lienzo)

	var rueda := FondoRuleta.new()
	rueda.cantidad = _selecciones.size()
	rueda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rueda.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lienzo.add_child(rueda)

	_crear_cabecera()
	_crear_centro()
	for indice: int in range(_selecciones.size()):
		_crear_boton(indice)
	_crear_pie()


func _crear_cabecera() -> void:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _estilo_capsula(CREMA, CORAL, 4, 18))
	_lienzo.add_child(panel)
	_centrar(panel, Vector2(0.0, -344.0), Vector2(292.0, 66.0))

	var titulo := Label.new()
	titulo.text = "EMOTES"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titulo.add_theme_color_override("font_color", PETROLEO_OSCURO)
	titulo.add_theme_font_override("font", FUENTE_TITULO)
	titulo.add_theme_font_size_override("font_size", 38)
	titulo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(titulo)


func _crear_centro() -> void:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _estilo_circular(CREMA, TURQUESA, 5, 12))
	_lienzo.add_child(panel)
	_centrar(panel, Vector2.ZERO, Vector2(154.0, 154.0))

	_rotulo_centro = Label.new()
	_rotulo_centro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo_centro.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rotulo_centro.add_theme_color_override("font_color", PETROLEO_OSCURO)
	_rotulo_centro.add_theme_font_override("font", FUENTE_TITULO)
	_rotulo_centro.add_theme_font_size_override("font_size", 18)
	_rotulo_centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(_rotulo_centro)
	_actualizar_estado_aura()


func _crear_boton(indice: int) -> void:
	var item: Dictionary = _selecciones[indice]
	var boton := Button.new()
	boton.custom_minimum_size = TAMANO_BOTON
	boton.size = TAMANO_BOTON
	boton.focus_mode = Control.FOCUS_ALL
	boton.tooltip_text = "Activar o desactivar el aura" if item["tipo"] == &"aura_persistente" else "Elegir %s" % item["nombre"]
	boton.add_theme_stylebox_override("normal", _estilo_circular(PETROLEO, CREMA, 5, 10))
	boton.add_theme_stylebox_override("hover", _estilo_circular(Color("22596a"), TURQUESA, 7, 15))
	boton.add_theme_stylebox_override("focus", _estilo_circular(Color("22596a"), CORAL, 7, 15))
	boton.add_theme_stylebox_override("pressed", _estilo_circular(PETROLEO_OSCURO, CORAL, 7, 5))
	boton.pivot_offset = TAMANO_BOTON * 0.5
	_lienzo.add_child(boton)

	var angulo := -PI * 0.5 + TAU * float(indice) / float(_selecciones.size())
	_centrar(boton, Vector2.from_angle(angulo) * RADIO_BOTONES, TAMANO_BOTON)

	var icono := TextureRect.new()
	icono.texture = item["icono"]
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Los medallones contienen ilustración y texto fino: el filtrado lineal directo
	# conserva mejor sus bordes que solicitar mipmaps que estos recursos no usan.
	icono.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icono.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icono.offset_left = 8.0
	icono.offset_top = 8.0
	icono.offset_right = -8.0
	icono.offset_bottom = -8.0
	boton.add_child(icono)
	if item["tipo"] == &"duelo_kamehameha":
		var placa := Label.new()
		placa.text = "DUELO"
		placa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placa.add_theme_font_size_override("font_size", 15)
		placa.add_theme_color_override("font_color", Color.WHITE)
		placa.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		placa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boton.add_child(placa)

	boton.pressed.connect(_seleccionar.bind(item["tipo"]))
	boton.mouse_entered.connect(_animar_boton.bind(boton, Vector2(1.08, 1.08)))
	boton.mouse_exited.connect(_animar_boton.bind(boton, Vector2.ONE))
	boton.focus_entered.connect(_animar_boton.bind(boton, Vector2(1.08, 1.08)))
	boton.focus_exited.connect(_animar_boton.bind(boton, Vector2.ONE))
	_botones.append(boton)


func _crear_pie() -> void:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _estilo_capsula(CREMA, TURQUESA, 3, 12))
	_lienzo.add_child(panel)
	_centrar(panel, Vector2(0.0, 350.0), Vector2(470.0, 50.0))

	var texto := Label.new()
	texto.text = "TOCA UN GESTO PARA ELEGIR  •  TOCA AFUERA PARA CERRAR" if OS.has_feature("android") else "PALANCA DERECHA + A PARA ELEGIR  •  B CIERRA  •  G / ESC"
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto.add_theme_color_override("font_color", PETROLEO_OSCURO)
	texto.add_theme_font_override("font", FUENTE_TEXTO)
	texto.add_theme_font_size_override("font_size", 16)
	texto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(texto)


func _ajustar_presentacion() -> void:
	if not is_instance_valid(_lienzo):
		return
	var escala := minf(1.0, minf(size.x / TAMANO_LIENZO.x, size.y / TAMANO_LIENZO.y))
	_lienzo.scale = Vector2.ONE * escala
	_lienzo.position = (size - TAMANO_LIENZO * escala) * 0.5


func _actualizar_estado_aura() -> void:
	if not is_instance_valid(_rotulo_centro):
		return
	_rotulo_centro.text = "AURA\nACTIVA" if _aura_activada else "AURA\nINACTIVA"
	_rotulo_centro.add_theme_color_override("font_color", CORAL if _aura_activada else PETROLEO_OSCURO)


func _animar_boton(boton: Button, escala_objetivo: Vector2) -> void:
	if not is_instance_valid(boton):
		return
	var tween := boton.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(boton, "scale", escala_objetivo, 0.16)


func _seleccionar(tipo: StringName) -> void:
	emote_seleccionado.emit(tipo)


func _centrar(control: Control, desplazamiento: Vector2, dimensiones: Vector2) -> void:
	control.anchor_left = 0.5
	control.anchor_top = 0.5
	control.anchor_right = 0.5
	control.anchor_bottom = 0.5
	control.offset_left = desplazamiento.x - dimensiones.x * 0.5
	control.offset_top = desplazamiento.y - dimensiones.y * 0.5
	control.offset_right = desplazamiento.x + dimensiones.x * 0.5
	control.offset_bottom = desplazamiento.y + dimensiones.y * 0.5


func _estilo_circular(fondo: Color, borde: Color, grosor: int, sombra: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(grosor)
	estilo.set_corner_radius_all(96)
	estilo.shadow_color = Color(0.0, 0.03, 0.05, 0.70)
	estilo.shadow_size = sombra
	return estilo


func _estilo_capsula(fondo: Color, borde: Color, grosor: int, sombra: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(grosor)
	estilo.set_corner_radius_all(28)
	estilo.shadow_color = Color(0.0, 0.03, 0.05, 0.65)
	estilo.shadow_size = sombra
	return estilo


class FondoRuleta extends Control:
	var cantidad := 5
	func _draw() -> void:
		var centro := size * 0.5
		draw_circle(centro + Vector2(0.0, 12.0), 336.0, Color(0.0, 0.02, 0.03, 0.48), true, -1.0, true)
		draw_circle(centro, 330.0, Color("0c2634"), true, -1.0, true)
		draw_arc(centro, 330.0, 0.0, TAU, 160, Color("fff1d8"), 8.0, true)
		draw_arc(centro, 316.0, 0.0, TAU, 160, Color("ff785f"), 4.0, true)
		draw_circle(centro, 292.0, Color("173b50"), true, -1.0, true)
		for indice: int in range(cantidad):
			var angulo := -PI * 0.5 + TAU * float(indice) / float(cantidad)
			var direccion := Vector2.from_angle(angulo)
			draw_line(centro + direccion * 92.0, centro + direccion * 142.0, Color(1.0, 0.945, 0.847, 0.22), 3.0, true)
		draw_circle(centro, 92.0, Color("0c2634"), true, -1.0, true)
		draw_arc(centro, 92.0, 0.0, TAU, 80, Color("15b7c0"), 4.0, true)
