extends Button
## Botón nativo: conserva el foco, los atajos y las señales de Godot.

const TEXTURAS_CORAL := {
	"normal": preload("res://UI/Menus/ArtePiloto/boton_coral_normal.svg"),
	"hover": preload("res://UI/Menus/ArtePiloto/boton_coral_hover.svg"),
	"pressed": preload("res://UI/Menus/ArtePiloto/boton_coral_pressed.svg"),
}
const TEXTURAS_CREMA := {
	"normal": preload("res://UI/Menus/ArtePiloto/boton_crema_normal.svg"),
	"hover": preload("res://UI/Menus/ArtePiloto/boton_crema_hover.svg"),
	"pressed": preload("res://UI/Menus/ArtePiloto/boton_crema_pressed.svg"),
}
const CREMA := Color("fff1d8")
const PETROLEO := Color("173b50")
const FACTOR_TAMANO := 0.85 * 0.85

@export var principal: bool = false
@export var simbolo: Texture2D

var _animacion: Tween
var _icono: TextureRect
var _tamano_fuente: int


func _ready() -> void:
	_tamano_fuente = get_theme_font_size("font_size")
	var texturas: Dictionary = TEXTURAS_CORAL if principal else TEXTURAS_CREMA
	for estado: String in ["normal", "hover", "pressed", "disabled"]:
		var textura_estado := "normal" if estado == "disabled" else estado
		var estilo := StyleBoxTexture.new()
		estilo.texture = texturas[textura_estado]
		estilo.texture_margin_left = 68.0 * FACTOR_TAMANO
		estilo.texture_margin_right = 68.0 * FACTOR_TAMANO
		estilo.texture_margin_top = 60.0 * FACTOR_TAMANO
		estilo.texture_margin_bottom = 60.0 * FACTOR_TAMANO
		estilo.content_margin_left = 52.0 * FACTOR_TAMANO
		estilo.content_margin_right = 52.0 * FACTOR_TAMANO
		estilo.content_margin_top = (16.0 if estado == "pressed" else 8.0) * FACTOR_TAMANO
		estilo.content_margin_bottom = (16.0 if estado == "pressed" else 24.0) * FACTOR_TAMANO
		add_theme_stylebox_override(estado, estilo)
	var foco := StyleBoxFlat.new()
	foco.draw_center = false
	foco.border_color = Color("fff1d8a6")
	foco.set_border_width_all(3)
	foco.set_corner_radius_all(roundi(64.0 * FACTOR_TAMANO))
	foco.expand_margin_left = 4.25
	foco.expand_margin_right = 4.25
	foco.expand_margin_top = 4.25
	foco.expand_margin_bottom = 0.85
	add_theme_stylebox_override("focus", foco)
	var tinta := CREMA if principal else PETROLEO
	for estado: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		add_theme_color_override(estado, tinta)
	# El icono no reserva ancho en el texto: la palabra se centra en todo el botón.
	_icono = TextureRect.new()
	_icono.name = "Icono"
	_icono.texture = simbolo
	_icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icono.modulate = tinta
	add_child(_icono)
	resized.connect(_centrar_pivote)
	mouse_entered.connect(_al_entrar_raton)
	mouse_exited.connect(_actualizar_animacion)
	focus_entered.connect(_actualizar_animacion)
	focus_exited.connect(_actualizar_animacion)
	button_down.connect(_actualizar_animacion)
	button_up.connect(_actualizar_animacion)
	_centrar_pivote()


func _centrar_pivote() -> void:
	pivot_offset = size * 0.5
	_ajustar_texto()
	_colocar_icono()


func _ajustar_texto() -> void:
	# Reserva el mismo espacio a ambos lados para no desplazar el texto del centro.
	var ancho_disponible := maxf(1.0, size.x - 2.0 * (52.0 + 88.0 + 12.0) * FACTOR_TAMANO)
	var fuente := get_theme_font("font")
	var tamano := _tamano_fuente
	while tamano > 16 and fuente.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x > ancho_disponible:
		tamano -= 1
	if get_theme_font_size("font_size") != tamano:
		add_theme_font_size_override("font_size", tamano)


func _colocar_icono() -> void:
	if not is_instance_valid(_icono):
		return
	var estilo := get_theme_stylebox("pressed" if is_pressed() else "normal")
	var centro_y := (size.y + estilo.content_margin_top - estilo.content_margin_bottom) * 0.5
	_icono.size = Vector2.ONE * 88.0 * FACTOR_TAMANO
	_icono.position = Vector2(52.0 * FACTOR_TAMANO, centro_y - _icono.size.y * 0.5)


func _al_entrar_raton() -> void:
	grab_focus()
	_actualizar_animacion()


func _actualizar_animacion() -> void:
	_colocar_icono()
	if is_instance_valid(_animacion):
		_animacion.kill()
	var destino := 1.025 if has_focus() or is_hovered() else 1.0
	if is_pressed():
		destino = 0.985
	_animacion = create_tween()
	_animacion.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_animacion.tween_property(self, "scale", Vector2.ONE * destino, 0.1)
