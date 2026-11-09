extends Node3D
## Abrir PruebaApagon.tscn y ejecutar la escena con F6.

const FUENTE := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
const EVENTO_APAGON := preload("res://Eventos/Apagon/evento_apagon.gd")
const VERDE := Color("8ce8b0")
const AMBAR := Color("ffc76a")

@onready var jugador: Player = $Jugador
@onready var camara: Camera3D = $Camara
@onready var taco: StaticBody3D = $TacoLuz
@onready var evento: EVENTO_APAGON = $EventoApagon

var boton_apagon: Button
var _estado: Label
var _instruccion: Label
var _indicacion: Label
var _interfaz: Control


func _ready() -> void:
	_crear_senales_suelo()
	_crear_interfaz()
	evento.estado_cambiado.connect(_actualizar_estado)
	_actualizar_estado(evento.estado)
	jugador.visual.rotation.y = PI


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_B:
		evento.iniciar_apagon()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var frente_al_taco := jugador.obtener_objetivo_interaccion() == taco
	_indicacion.visible = evento.estado == EVENTO_APAGON.Estado.APAGADO and frente_al_taco


func _crear_interfaz() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 30
	add_child(capa)
	_interfaz = Control.new()
	_interfaz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interfaz.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	capa.add_child(_interfaz)
	var tema := Theme.new()
	var fuente_texto := FontVariation.new()
	fuente_texto.base_font = FUENTE
	fuente_texto.variation_opentype = {2003265652: 650.0}
	tema.default_font = fuente_texto
	tema.default_font_size = 18
	_interfaz.theme = tema
	var cabecera := PanelContainer.new()
	cabecera.position = Vector2(28, 24)
	cabecera.size = Vector2(1224, 112)
	cabecera.add_theme_stylebox_override("panel", _estilo(Color("111e2c"), Color("314659")))
	_interfaz.add_child(cabecera)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 24)
	cabecera.add_child(fila)
	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(textos)
	var titulo := Label.new()
	titulo.text = "LABORATORIO ELÉCTRICO  /  01"
	titulo.add_theme_color_override("font_color", Color("8cabbc"))
	titulo.add_theme_font_size_override("font_size", 14)
	textos.add_child(titulo)
	_estado = Label.new()
	_estado.add_theme_font_size_override("font_size", 26)
	textos.add_child(_estado)
	_instruccion = Label.new()
	_instruccion.add_theme_font_size_override("font_size", 16)
	textos.add_child(_instruccion)
	boton_apagon = Button.new()
	boton_apagon.text = "Provocar apagón  [B]"
	boton_apagon.custom_minimum_size = Vector2(230, 46)
	boton_apagon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	boton_apagon.focus_mode = Control.FOCUS_NONE
	boton_apagon.add_theme_stylebox_override("normal", _estilo(Color("263f50"), Color("537589")))
	boton_apagon.add_theme_stylebox_override("hover", _estilo(Color("36566b"), AMBAR))
	boton_apagon.add_theme_stylebox_override("pressed", _estilo(Color("152b3c"), AMBAR))
	boton_apagon.pressed.connect(evento.iniciar_apagon)
	fila.add_child(boton_apagon)
	_indicacion = Label.new()
	_indicacion.text = "[E]  Abrir taco de luz"
	_indicacion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_indicacion.position = Vector2(390, 575)
	_indicacion.size = Vector2(500, 48)
	_indicacion.add_theme_font_size_override("font_size", 22)
	_indicacion.add_theme_color_override("font_color", AMBAR)
	_indicacion.add_theme_color_override("font_shadow_color", Color.BLACK)
	_indicacion.add_theme_constant_override("shadow_outline_size", 6)
	_indicacion.hide()
	_interfaz.add_child(_indicacion)
	var controles := Label.new()
	controles.text = "WASD / Flechas  Mover     ·     Shift  Correr     ·     E  Interactuar     ·     Esc  Cerrar circuito"
	controles.position = Vector2(28, 657)
	controles.size = Vector2(1224, 38)
	controles.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controles.add_theme_font_size_override("font_size", 16)
	controles.add_theme_color_override("font_color", Color("b1c4d0"))
	_interfaz.add_child(controles)
	get_viewport().size_changed.connect(_ajustar_interfaz)
	_ajustar_interfaz()


func _ajustar_interfaz() -> void:
	var tamano := get_viewport().get_visible_rect().size
	var factor := minf(tamano.x / 1280.0, tamano.y / 720.0)
	_interfaz.scale = Vector2.ONE * factor
	_interfaz.size = Vector2(1280, 720)
	_interfaz.position = (tamano - Vector2(1280, 720) * factor) * 0.5


func _actualizar_estado(nuevo_estado: EVENTO_APAGON.Estado) -> void:
	boton_apagon.disabled = nuevo_estado != EVENTO_APAGON.Estado.RESTAURADO
	match nuevo_estado:
		EVENTO_APAGON.Estado.RESTAURADO:
			_estado.text = "ENERGÍA RESTAURADA"
			_estado.modulate = VERDE
			_instruccion.text = "Activa el apagón para probar uno de los tres circuitos."
		EVENTO_APAGON.Estado.APAGADO:
			_estado.text = "APAGÓN  ·  VISIÓN LIMITADA"
			_estado.modulate = AMBAR
			_instruccion.text = "Busca el taco de luz al fondo de la sala y pulsa E frente a él."
		EVENTO_APAGON.Estado.REPARANDO:
			_estado.text = "REPARANDO EL CIRCUITO"
			_estado.modulate = AMBAR
			_instruccion.text = "Completa el circuito para devolver la energía."


func _estilo(fondo: Color, borde: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(10)
	estilo.content_margin_left = 20
	estilo.content_margin_right = 20
	estilo.content_margin_top = 12
	estilo.content_margin_bottom = 12
	return estilo


func _crear_senales_suelo() -> void:
	var material_lineas := StandardMaterial3D.new()
	material_lineas.albedo_color = Color("3c505d")
	material_lineas.roughness = 0.9
	for x: int in range(-5, 6):
		_linea_suelo(Vector3(x, 0.002, 0), Vector2(0.015, 9.5), material_lineas)
	for z: int in range(-4, 5):
		_linea_suelo(Vector3(0, 0.002, z), Vector2(11.6, 0.015), material_lineas)
	var material_zona := StandardMaterial3D.new()
	material_zona.albedo_color = Color("c79e47")
	_linea_suelo(Vector3(0, 0.006, -1.25), Vector2(1.8, 0.065), material_zona)
	_linea_suelo(Vector3(-0.9, 0.006, -2.05), Vector2(0.065, 1.6), material_zona)
	_linea_suelo(Vector3(0.9, 0.006, -2.05), Vector2(0.065, 1.6), material_zona)


func _linea_suelo(posicion: Vector3, tamano: Vector2, material_linea: Material) -> void:
	var linea := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = tamano
	plano.material = material_linea
	linea.mesh = plano
	linea.position = posicion
	linea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(linea)
