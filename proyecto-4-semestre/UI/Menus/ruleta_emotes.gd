extends Control
class_name RuletaEmotes

signal emote_seleccionado(tipo: StringName)

const PETROLEO := Color("102b3a")
const AZUL := Color("15b7c0")
const CREMA := Color("fff1d8")
const FUENTE_TITULO := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const FUENTE_TEXTO := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
var _modo_mouse_previo: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _aura_activada: bool = false
var _rotulo_centro: Label

var _selecciones: Array[Dictionary] = [
	{"tipo": &"kamehameha", "nombre": "KAMEHAMEHA", "color": Color(0.15, 0.72, 1.0)},
	{"tipo": &"genkidama", "nombre": "GENKIDAMA", "color": Color(0.26, 0.72, 1.0)},
	{"tipo": &"rasengan", "nombre": "RASENGAN", "color": Color(0.18, 0.65, 1.0)},
	{"tipo": &"explosion_final", "nombre": "EXPLOSIÓN FINAL", "color": Color(1.0, 0.68, 0.12)},
	{"tipo": &"aura_persistente", "nombre": "AURA", "color": Color(1.0, 0.48, 0.12)},
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resized.connect(queue_redraw)
	_crear_rotulo("EMOTES", Vector2(0.0, -250.0), Vector2(260.0, 42.0), 29, CREMA)
	_crear_rotulo("Haz clic para elegir  ·  G o Esc para cerrar", Vector2(0.0, 245.0), Vector2(430.0, 34.0), 16, Color("c5dcdd"))
	_rotulo_centro = _crear_rotulo("AURA\nDESACTIVADA", Vector2.ZERO, Vector2(138.0, 58.0), 14, CREMA)
	for indice: int in range(_selecciones.size()):
		_crear_boton(indice)


func abrir(aura_activa: bool = false) -> void:
	_modo_mouse_previo = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_aura_activada = aura_activa
	_rotulo_centro.text = "AURA\nACTIVADA" if _aura_activada else "AURA\nDESACTIVADA"
	visible = true
	queue_redraw()


func cerrar() -> void:
	visible = false
	Input.mouse_mode = _modo_mouse_previo


func _draw() -> void:
	var centro := size * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.028, 0.04, 0.38), true)
	draw_circle(centro + Vector2(0, 6), 282.0, Color(0.008, 0.025, 0.035, 0.52), true, -1.0, true)
	draw_arc(centro, 278.0, 0.0, TAU, 128, Color(PETROLEO.lightened(0.55), 0.96), 5.0, true)
	draw_arc(centro, 267.0, 0.0, TAU, 128, Color(AZUL, 0.9), 2.0, true)
	draw_circle(centro, 76.0, Color(PETROLEO, 0.97), true, -1.0, true)
	draw_arc(centro, 75.0, 0.0, TAU, 64, Color(AZUL, 0.95), 3.0, true)
	for angulo: float in [-PI * 0.5, -PI * 0.1, PI * 0.3, PI * 0.7, PI * 1.1]:
		var vector := Vector2.from_angle(angulo)
		draw_line(centro + vector * 76.0, centro + vector * 218.0, Color(CREMA, 0.14), 2.0, true)


func _crear_boton(indice: int) -> void:
	var item: Dictionary = _selecciones[indice]
	var boton := Button.new()
	boton.custom_minimum_size = Vector2(168, 82)
	boton.focus_mode = Control.FOCUS_ALL
	boton.tooltip_text = "Activar o desactivar el aura" if item["tipo"] == &"aura_persistente" else "Elegir %s" % item["nombre"]
	boton.add_theme_stylebox_override("normal", _estilo_boton(Color("183b4a"), Color("f2ddba")))
	boton.add_theme_stylebox_override("hover", _estilo_boton(Color("22596a"), Color("17c1c4")))
	boton.add_theme_stylebox_override("pressed", _estilo_boton(Color("0c2735"), Color("17c1c4")))
	boton.add_theme_color_override("font_color", CREMA)
	boton.add_theme_color_override("font_hover_color", Color.WHITE)
	boton.add_theme_font_override("font", FUENTE_TEXTO)
	boton.add_theme_font_size_override("font_size", 17)
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 10)
	fila.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boton.add_child(fila)
	var icono := IconoPoder.new()
	icono.tipo = item["tipo"]
	icono.color = item["color"]
	icono.custom_minimum_size = Vector2(50, 54)
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(icono)
	var texto := Label.new()
	texto.text = item["nombre"]
	texto.custom_minimum_size.x = 112
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto.add_theme_color_override("font_color", CREMA)
	texto.add_theme_font_size_override("font_size", 16)
	texto.add_theme_font_override("font", FUENTE_TEXTO)
	fila.add_child(texto)
	add_child(boton)
	var angulo := -PI * 0.5 + TAU * float(indice) / float(_selecciones.size())
	var desplazamiento := Vector2.from_angle(angulo) * 169.0
	_centrar(boton, desplazamiento, boton.custom_minimum_size)
	boton.pressed.connect(_seleccionar.bind(item["tipo"]))


func _crear_rotulo(contenido: String, desplazamiento: Vector2, dimensiones: Vector2, tamano: int, color: Color) -> Label:
	var rotulo := Label.new()
	rotulo.text = contenido
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotulo.add_theme_color_override("font_color", color)
	rotulo.add_theme_font_size_override("font_size", tamano)
	rotulo.add_theme_font_override("font", FUENTE_TITULO if contenido == "EMOTES" else FUENTE_TEXTO)
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rotulo)
	_centrar(rotulo, desplazamiento, dimensiones)
	return rotulo


func _centrar(control: Control, desplazamiento: Vector2, dimensiones: Vector2) -> void:
	control.anchor_left = 0.5
	control.anchor_top = 0.5
	control.anchor_right = 0.5
	control.anchor_bottom = 0.5
	control.offset_left = desplazamiento.x - dimensiones.x * 0.5
	control.offset_top = desplazamiento.y - dimensiones.y * 0.5
	control.offset_right = desplazamiento.x + dimensiones.x * 0.5
	control.offset_bottom = desplazamiento.y + dimensiones.y * 0.5


func _estilo_boton(fondo: Color, borde: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(16)
	estilo.shadow_color = Color(0.0, 0.025, 0.04, 0.62)
	estilo.shadow_size = 8
	estilo.content_margin_left = 12.0
	estilo.content_margin_right = 12.0
	estilo.content_margin_top = 8.0
	estilo.content_margin_bottom = 8.0
	return estilo


func _seleccionar(tipo: StringName) -> void:
	emote_seleccionado.emit(tipo)


class IconoPoder extends Control:
	var tipo: StringName = &""
	var color: Color = Color.CYAN

	func _draw() -> void:
		var centro := size * 0.5
		var radio := minf(size.x, size.y) * 0.34
		if tipo == &"kamehameha":
			draw_colored_polygon(PackedVector2Array([centro + Vector2(-4, -8), centro + Vector2(22, -14), centro + Vector2(22, 14), centro + Vector2(-4, 8)]), Color(color, 0.70))
			_dibujar_esfera(centro + Vector2(-9, 0), radio * 0.78)
		elif tipo == &"explosion_final":
			var puntos := PackedVector2Array()
			for punta: int in range(16):
				var r := radio * (1.36 if punta % 2 == 0 else 0.66)
				puntos.append(centro + Vector2.from_angle(TAU * float(punta) / 16.0) * r)
			draw_colored_polygon(puntos, Color(color, 0.82))
			draw_circle(centro, radio * 0.52, Color(1.0, 0.95, 0.62), true, -1.0, true)
		elif tipo == &"aura_persistente":
			for llama: int in range(8):
				var direccion := Vector2.from_angle(-PI * 0.5 + TAU * float(llama) / 8.0)
				var lateral := direccion.orthogonal() * radio * 0.28
				var base := centro + direccion * radio * 0.42
				var punta := centro + direccion * radio * (1.2 if llama % 2 == 0 else 0.92)
				draw_colored_polygon(PackedVector2Array([base - lateral, punta, base + lateral]), Color(color.lightened(0.12), 0.82))
			_dibujar_esfera(centro, radio * 0.52)
		else:
			var escala := 1.0 if tipo == &"genkidama" else 0.82
			_dibujar_esfera(centro, radio * escala)
			if tipo == &"rasengan":
				for punta: int in range(8):
					var a := TAU * float(punta) / 8.0
					var direccion := Vector2.from_angle(a)
					draw_line(centro + direccion * radio * 0.72, centro + direccion * radio * 1.42, Color(0.68, 0.93, 1.0), 2.5, true)
			else:
				draw_arc(centro, radio * 1.12, 0.4, 5.2, 36, Color(0.78, 0.96, 1.0, 0.88), 2.0, true)

	func _dibujar_esfera(centro: Vector2, radio: float) -> void:
		draw_circle(centro + Vector2(1, 2), radio + 3.0, Color(color, 0.22), true, -1.0, true)
		draw_circle(centro, radio, color, true, -1.0, true)
		draw_circle(centro + Vector2(-radio * 0.24, -radio * 0.30), radio * 0.56, color.lightened(0.42), true, -1.0, true)
		draw_circle(centro + Vector2(-radio * 0.34, -radio * 0.42), radio * 0.18, Color.WHITE, true, -1.0, true)
		draw_arc(centro, radio, 0.0, TAU, 48, Color(0.78, 0.96, 1.0, 0.85), 1.8, true)
