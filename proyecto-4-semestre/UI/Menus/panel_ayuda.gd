extends PanelContainer

const CREMA := Color("fff1d8")
const PETROLEO := Color("173b50")
const TEXTO_SUAVE := Color("d2e5e6")
const TAMANO_CAPTURA := Vector2(368, 207)
const PASOS := [
	[
		"Recibe una denuncia",
		"Cuando llegue un caso a la barra de denuncias, acércate al computador y pulsa E para aceptar el más urgente.",
		preload("res://UI/Menus/ArtePiloto/tutorial_denuncia.webp"),
	],
	[
		"Ve a la estación indicada",
		"Pulsa E para salir del computador. Sigue el icono de la próxima estación. Si queda fuera de vista, la flecha indica la dirección.",
		preload("res://UI/Menus/ArtePiloto/tutorial_estacion.webp"),
	],
	[
		"Completa el protocolo",
		"Ponte frente a la estación y pulsa E. Completa todos los pasos antes de que se agote el tiempo para ganar puntos.",
		preload("res://UI/Menus/ArtePiloto/tutorial_protocolo.webp"),
	],
]
const CONTROLES := [
	["W A S D  /  ↑ ← ↓ →", "Moverse por la oficina"],
	["Mayús", "Correr mientras te mueves"],
	["Espacio", "Saltar"],
	["E", "Usar una estación o entrar y salir del computador"],
	["Mantener Tab", "Ver la clasificación durante la partida"],
	["Esc", "Pausar o volver a la pantalla anterior"],
	["Tab  /  Mayús + Tab", "Recorrer las opciones del menú"],
	["Enter  /  Espacio", "Confirmar una opción del menú"],
	["Mantener G", "Menú de emotes (en desarrollo)"],
]

@export var fuente_texto: Font
@export var fuente_enfasis: Font
@export var estilo_fila: StyleBox
@export var estilo_numero: StyleBox
@export var estilo_tecla: StyleBox

@onready var titulo: Label = %Titulo
@onready var tutorial: VBoxContainer = %Tutorial
@onready var leyenda: VBoxContainer = %Leyenda
@onready var boton_cerrar: Button = %CerrarAyuda


func _ready() -> void:
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

	for control: Array in CONTROLES:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 20)
		leyenda.add_child(fila)
		fila.add_child(_crear_distintivo(control[0], estilo_tecla, Vector2(265, 45)))
		var accion := _crear_texto(control[1], fuente_texto, 27, CREMA)
		accion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		accion.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fila.add_child(accion)


func presentar(es_leyenda: bool, es_inicio: bool) -> void:
	custom_minimum_size.x = 1040.0 if es_leyenda else 1200.0
	titulo.text = "CONTROLES" if es_leyenda else "TUTORIAL"
	tutorial.visible = not es_leyenda
	leyenda.visible = es_leyenda
	boton_cerrar.text = "EMPEZAR TURNO" if es_inicio else "VOLVER"


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
