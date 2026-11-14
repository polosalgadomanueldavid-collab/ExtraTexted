extends PanelContainer

const CREMA := Color("fff1d8")
const PETROLEO := Color("173b50")
const TAMANO_EXPEDIENTE := 1560.0
const DemostracionCircuitos := preload("res://UI/Apagon/demostracion_circuitos.gd")
const ManualControles := preload("res://UI/Menus/manual_controles.gd")
const TEMA_AJUSTES := preload("res://UI/Menus/tema_ajustes.tres")
const GuiasEventos := preload("res://UI/Menus/guias_eventos.gd")
const PASOS_APAGON := [
	["Sigue el rayo", "Busca «Activar luz» en la zona de descanso.",
		preload("res://UI/Menus/ArtePiloto/apagon_rayo.webp")],
	["Abre el taco de luz", "Acércate al tablero junto a la puerta de personal y pulsa E.",
		preload("res://UI/Menus/ArtePiloto/apagon_taco.webp")],
]
const PASO_CIRCUITO := {
	PanelCircuitos.Tipo.CABLES: ["Cables · 1/3", "Une cada cable con el terminal de su mismo color."],
	PanelCircuitos.Tipo.FASES: ["Agujas · 2/3", "Pulsa cada botón cuando su aguja entre en verde."],
	PanelCircuitos.Tipo.INTERRUPTORES: ["Interruptores · 3/3", "Activa las palancas hasta ver cinco luces verdes."],
}
const PASOS := [
	[
		"Recibe el caso",
		"Acércate al computador y pulsa E para recoger la hoja de la denuncia.",
		preload("res://UI/Menus/ArtePiloto/tutorial_denuncia.webp"),
	],
	[
		"Visita las estaciones",
		"Lleva la hoja a las estaciones marcadas. Puedes visitarlas en cualquier orden.",
		preload("res://UI/Menus/ArtePiloto/tutorial_estacion.webp"),
	],
	[
		"Completa el caso",
		"Con la hoja en la mano, pulsa E frente a cada estación. Completa todas y gana puntos.",
		preload("res://UI/Menus/ArtePiloto/tutorial_protocolo.webp"),
	],
]

@export var fuente_texto: Font
@export var fuente_enfasis: Font
@export var estilo_numero: StyleBox
@export var estilo_tecla: StyleBox
@export var estilo_expediente: StyleBox
@export var estilo_pestana: StyleBox
@export var estilo_marco_foto: StyleBox

@onready var titulo: Label = %Titulo
@onready var seccion: Label = %Seccion
@onready var tutorial: HBoxContainer = %Tutorial
@onready var leyenda: ManualControles = %Leyenda
@onready var tutorial_apagon: HBoxContainer = %TutorialApagon
@onready var tutorial_evento: HBoxContainer = %TutorialEvento
@onready var boton_cerrar: Button = %CerrarAyuda
@onready var pista: Label = %Pista

var _es_expediente := true
var _estilos_cierre: Dictionary = {}


func _ready() -> void:
	_crear_pasos(tutorial, PASOS)
	_crear_pasos(tutorial_apagon, PASOS_APAGON)
	_crear_demostracion_circuitos()
	for estado: String in ["normal", "hover", "pressed", "focus"]:
		_estilos_cierre[estado] = boton_cerrar.get_theme_stylebox(estado)


func _draw() -> void:
	if _es_expediente:
		draw_style_box(estilo_pestana, Rect2(44, -24, 210, 28))


func _crear_pasos(destino: HBoxContainer, pasos: Array) -> void:
	for indice: int in range(pasos.size()):
		var paso: Array = pasos[indice]
		var columna := _crear_columna(destino)
		var marco := _crear_marco(columna)
		var captura := TextureRect.new()
		captura.texture = paso[2]
		captura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		captura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		captura.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marco.add_child(captura)
		_crear_encabezado_paso(columna, indice + 1, paso[0])
		columna.add_child(_crear_texto(paso[1], fuente_texto, 28, PETROLEO))


func _crear_columna(destino: HBoxContainer) -> VBoxContainer:
	var columna := VBoxContainer.new()
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna.add_theme_constant_override("separation", 16)
	destino.add_child(columna)
	return columna


func _crear_marco(columna: VBoxContainer) -> PanelContainer:
	var proporcion := AspectRatioContainer.new()
	proporcion.ratio = 16.0 / 9.0
	proporcion.custom_minimum_size.y = 250
	columna.add_child(proporcion)
	var marco := PanelContainer.new()
	marco.add_theme_stylebox_override("panel", estilo_marco_foto)
	proporcion.add_child(marco)
	return marco


func _crear_encabezado_paso(columna: VBoxContainer, numero: int, texto: String) -> void:
	var encabezado := HBoxContainer.new()
	encabezado.add_theme_constant_override("separation", 12)
	columna.add_child(encabezado)
	encabezado.add_child(_crear_distintivo(str(numero), estilo_numero, Vector2(40, 40)))
	var etiqueta := _crear_texto(texto, fuente_enfasis, 32, PETROLEO)
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	encabezado.add_child(etiqueta)


func controles_foco() -> Array[Control]:
	var controles: Array[Control] = []
	if leyenda.visible:
		controles.append_array(leyenda.pestanas)
	controles.append(boton_cerrar)
	return controles


func presentar(es_leyenda: bool, es_inicio: bool) -> void:
	_establecer_expediente(not es_leyenda)
	titulo.add_theme_font_size_override("font_size", 60)
	custom_minimum_size.x = 1040.0 if es_leyenda else TAMANO_EXPEDIENTE
	seccion.text = "GUÍA DE DESPACHO"
	titulo.text = "CONTROLES" if es_leyenda else "TU PRIMER TURNO"
	tutorial.visible = not es_leyenda
	leyenda.visible = es_leyenda
	tutorial_apagon.hide()
	tutorial_evento.hide()
	boton_cerrar.text = "EMPEZAR TURNO" if es_inicio else "VOLVER"
	pista.text = "E · Interactuar, recoger o lanzar la hoja"
	boton_cerrar.custom_minimum_size = Vector2(350, 80) if es_leyenda else Vector2(340, 76)
	if es_leyenda:
		seccion.text = "MANUAL DEL AGENTE"
		var panel := StyleBoxFlat.new()
		panel.bg_color = PETROLEO
		panel.set_corner_radius_all(24)
		panel.content_margin_left = 32
		panel.content_margin_right = 32
		panel.content_margin_top = 32
		panel.content_margin_bottom = 24
		add_theme_stylebox_override("panel", panel)
		leyenda.seleccionar(0)


func presentar_tutorial_evento(evento: StringName, desde_pausa: bool) -> void:
	_establecer_expediente(true)
	custom_minimum_size.x = TAMANO_EXPEDIENTE
	titulo.add_theme_font_size_override("font_size", 60)
	tutorial.hide()
	leyenda.hide()
	tutorial_apagon.visible = evento == &"apagon"
	tutorial_evento.visible = evento != &"apagon"
	boton_cerrar.custom_minimum_size = Vector2(340, 76)
	boton_cerrar.text = "VOLVER" if desde_pausa else "ENTENDIDO"
	if evento == &"apagon":
		seccion.text = "GUÍA DE DESPACHO  ·  APAGÓN"
		titulo.text = "RESTABLECE LA LUZ"
		pista.text = "Repara el circuito para recuperar la luz."
		return
	var guia: Dictionary = GuiasEventos.GUIAS[evento]
	seccion.text = "GUÍA DE DESPACHO  ·  " + guia.nombre
	titulo.text = guia.titulo
	pista.text = guia.pista
	for columna in tutorial_evento.get_children():
		tutorial_evento.remove_child(columna)
		columna.queue_free()
	_crear_pasos(tutorial_evento, guia.pasos)


func _establecer_expediente(activo: bool) -> void:
	_es_expediente = activo
	if activo:
		add_theme_stylebox_override("panel", estilo_expediente)
	else:
		remove_theme_stylebox_override("panel")
	titulo.add_theme_color_override("font_color", PETROLEO if activo else CREMA)
	seccion.add_theme_color_override("font_color", Color("9d4939") if activo else Color("ff9e8a"))
	pista.visible = activo
	%LineaEncabezado.visible = activo
	%LineaPie.visible = activo
	boton_cerrar.size_flags_horizontal = Control.SIZE_SHRINK_END if activo else Control.SIZE_SHRINK_CENTER
	boton_cerrar.add_theme_font_override("font", fuente_enfasis if activo else TEMA_AJUSTES.get_font("font", "Button"))
	boton_cerrar.add_theme_font_size_override("font_size", 28 if activo else 42)
	for estado: String in ["normal", "hover", "pressed", "focus"]:
		var estilo: StyleBox = _estilos_cierre[estado] if activo else TEMA_AJUSTES.get_stylebox(estado, "Button" if estado == "focus" else "Volver")
		boton_cerrar.add_theme_stylebox_override(estado, estilo)
	queue_redraw()


func _crear_demostracion_circuitos() -> void:
	var columna := _crear_columna(tutorial_apagon)
	var marco := _crear_marco(columna)
	var demostracion := DemostracionCircuitos.new()
	demostracion.name = "DemostracionCircuitos"
	_crear_encabezado_paso(columna, 3, "Repara el circuito")
	var titulo_circuito := _crear_texto("", fuente_enfasis, 24, Color("9d4939"))
	var instruccion := _crear_texto("", fuente_texto, 28, PETROLEO)
	columna.add_child(titulo_circuito)
	columna.add_child(instruccion)
	demostracion.circuito_cambiado.connect(func(tipo: int) -> void:
		titulo_circuito.text = PASO_CIRCUITO[tipo][0]
		instruccion.text = PASO_CIRCUITO[tipo][1]
	)
	marco.add_child(demostracion)


func _crear_distintivo(texto: String, estilo: StyleBox, minimo: Vector2) -> PanelContainer:
	var distintivo := PanelContainer.new()
	distintivo.custom_minimum_size = minimo
	distintivo.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	distintivo.add_theme_stylebox_override("panel", estilo)
	var etiqueta := _crear_texto(texto, fuente_enfasis, 25, PETROLEO)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	distintivo.add_child(etiqueta)
	return distintivo


func _crear_texto(texto: String, fuente: Font, tamano: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_override("font", fuente)
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return etiqueta
