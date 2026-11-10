extends Control
## Comparador del menú definitivo con y sin el degradado.

const ESCENA_MENU := preload("res://UI/Menus/MainMenu.tscn")
const FUENTE := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
const NOMBRES := ["01  Sin degradado", "02  Con degradado"]

var _menu: Control
var _descripcion: Label
var _tabs: Array[Button] = []
var _indice := 1


func _ready() -> void:
	_menu = ESCENA_MENU.instantiate()
	add_child(_menu)
	_crear_navegacion()
	_mostrar_propuesta(1)
	if "--capturas" in OS.get_cmdline_user_args():
		call_deferred("_capturar_todas")


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_1, KEY_2]:
		_mostrar_propuesta(event.keycode - KEY_1)
	elif event.keycode == KEY_F12:
		call_deferred("_capturar_actual")


func _crear_navegacion() -> void:
	var barra := PanelContainer.new()
	barra.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	barra.offset_bottom = 64
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color("092c3bbb")
	fondo.content_margin_left = 22
	fondo.content_margin_right = 22
	fondo.content_margin_top = 8
	fondo.content_margin_bottom = 8
	barra.add_theme_stylebox_override("panel", fondo)
	add_child(barra)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	barra.add_child(fila)
	var titulo := Label.new()
	titulo.text = "OFICINA REAL · PROPUESTA 2"
	titulo.custom_minimum_size.x = 370
	titulo.add_theme_font_override("font", FUENTE)
	titulo.add_theme_font_size_override("font_size", 21)
	titulo.add_theme_color_override("font_color", Color("fff1d8"))
	fila.add_child(titulo)
	for i in NOMBRES.size():
		var boton := Button.new()
		boton.text = NOMBRES[i]
		boton.custom_minimum_size = Vector2(220, 42)
		boton.add_theme_font_override("font", FUENTE)
		boton.add_theme_font_size_override("font_size", 19)
		boton.pressed.connect(_mostrar_propuesta.bind(i))
		fila.add_child(boton)
		_tabs.append(boton)
	var ayuda := Label.new()
	ayuda.text = "1–2: cambiar · F12: captura"
	ayuda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ayuda.add_theme_font_override("font", FUENTE)
	ayuda.add_theme_font_size_override("font_size", 17)
	ayuda.add_theme_color_override("font_color", Color("c9dde2"))
	fila.add_child(ayuda)
	_descripcion = Label.new()
	_descripcion.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_descripcion.offset_top = -52
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
	_menu.get_node("FondoOficina").degradado.visible = indice == 1
	_descripcion.text = [
		"Menú sobre la oficina real, sin degradado.",
		"Menú definitivo: perspectiva y degradado desde la izquierda."
	][indice]
	for i in _tabs.size():
		_tabs[i].modulate = Color("ffb493") if i == indice else Color.WHITE


func _capturar_actual() -> void:
	await RenderingServer.frame_post_draw
	var ruta := "res://UI/Menus/Propuestas/oficina_real_%02d.png" % (_indice + 1)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://UI/Menus/Propuestas"))
	get_viewport().get_texture().get_image().save_png(ruta)
	print("CAPTURA: ", ProjectSettings.globalize_path(ruta))


func _capturar_todas() -> void:
	for i in NOMBRES.size():
		_mostrar_propuesta(i)
		await get_tree().create_timer(0.65).timeout
		await _capturar_actual()
	get_tree().quit()
