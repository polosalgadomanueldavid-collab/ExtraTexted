extends PanelContainer

const CREMA := Color("fff1d8")
const PETROLEO := Color("173b50")
const TEXTO_SUAVE := Color("d2e5e6")
const TAMANO_CAPTURA := Vector2(368, 207)
const PASOS := [
	[
		"Recibe una denuncia",
		"Cuando llegue un caso, acércate al computador o a su silla y pulsa E. Recibirás la hoja de la denuncia más urgente.",
		preload("res://UI/Menus/ArtePiloto/tutorial_denuncia.webp"),
	],
	[
		"Elige una estación pendiente",
		"Lleva la hoja a las estaciones marcadas en cualquier orden. E la lanza cuando miras a un espacio libre; E también la recoge. La flecha sugiere la estación más cercana.",
		preload("res://UI/Menus/ArtePiloto/tutorial_estacion.webp"),
	],
	[
		"Completa el protocolo",
		"Con la hoja en la mano, ponte frente a cada estación y pulsa E una vez. Al completar todas, el caso se cierra automáticamente y ganas puntos.",
		preload("res://UI/Menus/ArtePiloto/tutorial_protocolo.webp"),
	],
]
const ManualControles := preload("res://UI/Menus/manual_controles.gd")

@export var fuente_texto: Font
@export var fuente_enfasis: Font
@export var estilo_fila: StyleBox
@export var estilo_numero: StyleBox

@onready var titulo: Label = %Titulo
@onready var tutorial: VBoxContainer = %Tutorial
@onready var leyenda: ManualControles = %Leyenda
@onready var boton_cerrar: Button = %CerrarAyuda
@onready var pagina_manual: Label = %PaginaManual
@onready var seccion: Label = $Contenido/Encabezado/Seccion


func _ready() -> void:
	leyenda.pagina_cambiada.connect(_actualizar_pagina)
	for indice: int in range(PASOS.size()):
		var paso: Array = PASOS[indice]
		var tarjeta := PanelContainer.new()
		tarjeta.add_theme_stylebox_override("panel", estilo_fila)
		tutorial.add_child(tarjeta)

		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 18)
		tarjeta.add_child(fila)

		var detalle := HBoxContainer.new()
		detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detalle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		detalle.add_theme_constant_override("separation", 18)
		fila.add_child(detalle)
		detalle.add_child(_crear_distintivo(str(indice + 1), estilo_numero, Vector2(48, 48)))

		var contenido := VBoxContainer.new()
		contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		contenido.add_theme_constant_override("separation", 3)
		detalle.add_child(contenido)
		contenido.add_child(_crear_texto(paso[0], fuente_enfasis, 30, CREMA))
		contenido.add_child(_crear_texto(paso[1], fuente_texto, 27, TEXTO_SUAVE))

		var captura := TextureRect.new()
		captura.custom_minimum_size = TAMANO_CAPTURA
		captura.texture = paso[2]
		captura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		captura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		captura.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fila.add_child(captura)


func presentar(es_leyenda: bool, es_inicio: bool) -> void:
	custom_minimum_size.x = 1040.0 if es_leyenda else 1200.0
	titulo.text = "CONTROLES" if es_leyenda else "TUTORIAL"
	seccion.text = "MANUAL DEL AGENTE" if es_leyenda else "GUÍA DE DESPACHO"
	tutorial.visible = not es_leyenda
	leyenda.visible = es_leyenda
	pagina_manual.visible = es_leyenda
	boton_cerrar.text = "EMPEZAR TURNO" if es_inicio else "VOLVER"
	boton_cerrar.custom_minimum_size = Vector2(350, 80) if es_leyenda else Vector2(514.42, 92)
	if es_leyenda:
		var panel := StyleBoxFlat.new()
		panel.bg_color = PETROLEO
		panel.set_corner_radius_all(24)
		panel.content_margin_left = 32
		panel.content_margin_right = 32
		panel.content_margin_top = 32
		panel.content_margin_bottom = 24
		add_theme_stylebox_override("panel", panel)
		leyenda.seleccionar(0)
	else:
		remove_theme_stylebox_override("panel")


func controles_foco() -> Array[Control]:
	var controles: Array[Control] = []
	if leyenda.visible:
		controles.append_array(leyenda.pestanas)
	controles.append(boton_cerrar)
	return controles


func _actualizar_pagina(indice: int) -> void:
	pagina_manual.text = "%s · %d / 3" % [ManualControles.CATEGORIAS[indice].to_upper(), indice + 1]


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
