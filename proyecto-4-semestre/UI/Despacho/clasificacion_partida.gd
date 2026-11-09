extends Control
## Consulta rápida de los mejores puntajes en el escenario de la partida.

const CLASIFICACION := preload("res://Scripts/Partida/ClasificacionLocal.gd")
const MAX_FILAS := 5
const MARGEN := 20.0
const TAMANO_DISENO := Vector2(1600, 900)
const CREMA := Color("fff1d8")
const CORAL := Color("ffa388")

@export var fuente_tabla: Font
@export var estilo_fila: StyleBox
@export var estilo_fila_local: StyleBox

@onready var tarjeta: PanelContainer = %Tarjeta
@onready var tabla: VBoxContainer = %Tabla
@onready var filas: VBoxContainer = %Filas
@onready var estado: Label = %Estado
@onready var tu_puesto: Label = %TuPuesto
@onready var tu_alias: Label = %TuAlias
@onready var tus_puntos: Label = %TusPuntos

func _ready() -> void:
	resized.connect(_ajustar_presentacion)
	_ajustar_presentacion()


func presentar(entradas: Array[Dictionary], nombre: String, puntos: int, error: Error = OK) -> void:
	for fila: Node in filas.get_children():
		filas.remove_child(fila)
		fila.queue_free()

	var clave := CLASIFICACION.limpiar_nombre(nombre).to_lower()
	var posicion := 0
	if error == OK:
		for indice: int in range(entradas.size()):
			var entrada := entradas[indice]
			var es_local: bool = entrada.nombre.to_lower() == clave
			if es_local:
				posicion = indice + 1
			if indice < MAX_FILAS:
				_agregar_fila(indice + 1, entrada.nombre, entrada.puntos, es_local)

	tabla.visible = filas.get_child_count() > 0
	estado.visible = not tabla.visible
	estado.text = "Aún no hay récords locales." if error == OK else "No se pudo leer la clasificación local."
	tu_puesto.text = "TU PARTIDA · PUESTO #%d" % posicion if posicion > 0 else "TU PARTIDA"
	tu_alias.text = "Sin alias" if clave.is_empty() else nombre
	tus_puntos.text = str(puntos)
	_ajustar_presentacion()


func _agregar_fila(puesto: int, nombre: String, puntos: int, es_local: bool) -> void:
	var fondo := PanelContainer.new()
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo.add_theme_stylebox_override("panel", estilo_fila_local if es_local else estilo_fila)
	filas.add_child(fondo)

	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_theme_constant_override("separation", 10)
	fondo.add_child(fila)

	var numero := _crear_celda(str(puesto))
	numero.custom_minimum_size.x = 58.0
	numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	numero.add_theme_color_override("font_color", CORAL)
	fila.add_child(numero)

	var jugador := _crear_celda(nombre)
	jugador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jugador.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	fila.add_child(jugador)

	var marcador := _crear_celda(str(puntos))
	marcador.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fila.add_child(marcador)


func _crear_celda(texto: String) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_override("font", fuente_tabla)
	etiqueta.add_theme_font_size_override("font_size", 21)
	etiqueta.add_theme_color_override("font_color", CREMA)
	return etiqueta


func _ajustar_presentacion() -> void:
	var escala := clampf(minf(size.x / TAMANO_DISENO.x, size.y / TAMANO_DISENO.y), 0.1, 1.15)
	tarjeta.size = tarjeta.get_combined_minimum_size()
	tarjeta.scale = Vector2.ONE * escala
	tarjeta.position = Vector2.ONE * MARGEN * escala
