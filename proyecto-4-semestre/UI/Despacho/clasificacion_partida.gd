extends Control
## Consulta rápida de los mejores puntajes en el escenario de la partida.

const CLASIFICACION := preload("res://Scripts/Partida/ClasificacionLocal.gd")
const MAX_FILAS := 5
const MARGEN := 28.0
const TAMANO_DISENO := Vector2(1920, 1080)
const Arte := preload("res://UI/Despacho/arte_clasificacion.gd")
const FilaCalma := preload("res://UI/Despacho/fila_calma_jugador.gd")
const MARCA_PUESTO := preload("res://UI/Despacho/Arte/puesto_marcado.svg")
const SEPARACION_CALMA := 24.0

@export var fuente_tabla: Font

@onready var tarjeta: PanelContainer = %Tarjeta
@onready var tabla: VBoxContainer = %Tabla
@onready var columna_puesto: Label = $Tarjeta/Contenido/Tabla/Columnas/Posicion
@onready var filas: VBoxContainer = %Filas
@onready var estado: Label = %Estado
@onready var tu_puesto: Label = %TuPuesto
@onready var tu_alias: Label = %TuAlias
@onready var tus_puntos: Label = %TusPuntos

func _ready() -> void:
	_preparar_diseno()
	resized.connect(_ajustar_presentacion)
	tarjeta.minimum_size_changed.connect(_ajustar_presentacion)
	_ajustar_presentacion()


func _preparar_diseno() -> void:
	tarjeta.add_theme_stylebox_override("panel", Arte.margenes(41, 20, 47, 28))
	tarjeta.draw.connect(func() -> void: Arte.marco(tarjeta, Arte.VINETA, 126, 121))
	tarjeta.resized.connect(tarjeta.queue_redraw)
	for etiqueta: Label in $Tarjeta/Contenido/Tabla/Columnas.get_children():
		etiqueta.add_theme_color_override("font_color", Color("405052"))
		etiqueta.add_theme_font_override("font", fuente_tabla)
		etiqueta.add_theme_font_size_override("font_size", 22)
	tabla.draw.connect(func() -> void:
		var x := columna_puesto.size.x + 7
		tabla.draw_line(Vector2(x, 2), Vector2(x, tabla.size.y), Color("bb907a99"), 1.4, true))
	tabla.resized.connect(tabla.queue_redraw)
	estado.add_theme_color_override("font_color", Arte.TINTA)
	var pie: PanelContainer = $Tarjeta/Contenido/TuPartida
	pie.add_theme_stylebox_override("panel", Arte.margenes(16, 0, 17, 0))
	var rotulo: Label = $Tarjeta/Contenido/TuPartida/Resumen/Puntaje/RotuloPuntaje
	for etiqueta: Label in [tu_puesto, rotulo]:
		etiqueta.add_theme_font_override("font", fuente_tabla)
		etiqueta.add_theme_font_size_override("font_size", 22)
	for etiqueta: Label in [tu_puesto, tu_alias, rotulo, tus_puntos]:
		etiqueta.add_theme_color_override("font_color", Arte.CREMA)


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
	tu_puesto.text = "PUESTO #%d" % posicion if posicion > 0 else "PUESTO"
	tu_alias.text = "Sin alias" if clave.is_empty() else nombre
	tu_alias.tooltip_text = tu_alias.text
	tus_puntos.text = str(puntos)
	_ajustar_presentacion()


func _agregar_fila(puesto: int, nombre: String, puntos: int, es_local: bool) -> void:
	var fondo := PanelContainer.new()
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo.add_theme_stylebox_override("panel", Arte.margenes(0, 1, 10, 2))
	fondo.draw.connect(func() -> void: Arte.renglon(fondo))
	fondo.resized.connect(fondo.queue_redraw)
	filas.add_child(fondo)

	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_theme_constant_override("separation", 18)
	fondo.add_child(fila)

	var numero := _crear_celda(str(puesto))
	numero.custom_minimum_size = Vector2(columna_puesto.get_combined_minimum_size().x, 50)
	numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if es_local:
		var circulo := StyleBoxTexture.new()
		circulo.texture = MARCA_PUESTO
		numero.add_theme_stylebox_override("normal", circulo)
	fila.add_child(numero)

	var jugador := _crear_celda(nombre)
	jugador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jugador.clip_text = true
	jugador.tooltip_text = nombre
	jugador.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	fila.add_child(jugador)

	var marcador := _crear_celda(str(puntos))
	marcador.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fila.add_child(marcador)


func _crear_celda(texto: String) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_override("font", fuente_tabla)
	etiqueta.add_theme_font_size_override("font_size", 36)
	etiqueta.add_theme_color_override("font_color", Arte.TINTA)
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return etiqueta


func _ajustar_presentacion() -> void:
	if not is_instance_valid(tarjeta):
		return
	var escala := maxf(0.1, minf(size.x / TAMANO_DISENO.x, size.y / TAMANO_DISENO.y))
	tarjeta.size = tarjeta.get_combined_minimum_size()
	tarjeta.scale = Vector2.ONE * escala
	# Conserva el hueco de los dos jugadores incluso mientras se juega en solitario.
	var alto_calma := FilaCalma.ALTO * 2.0 + 8.0
	var calma := get_parent().get_node_or_null("CalmaJugadores") as Control
	var origen := Vector2.ONE * MARGEN * escala
	if is_instance_valid(calma):
		origen = calma.position
		alto_calma = maxf(alto_calma, calma.get_combined_minimum_size().y)
	var y := origen.y + (alto_calma + SEPARACION_CALMA) * escala
	var disponible := size.y - y - MARGEN * escala
	var escala_tarjeta := minf(escala, maxf(0.1, disponible / tarjeta.size.y))
	tarjeta.scale = Vector2.ONE * escala_tarjeta
	tarjeta.position = Vector2(origen.x, y)
