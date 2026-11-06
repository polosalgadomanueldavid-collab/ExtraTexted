extends PanelContainer

signal nombre_confirmado(nombre: String)

const ClasificacionLocalScript := preload("res://Scripts/ClasificacionLocal.gd")
const CREMA := Color("fff1d8")
const CORAL := Color("ff9e8a")

@export var fuente_tabla: Font
@export var estilo_fila: StyleBox

@onready var titulo: Label = %Titulo
@onready var formulario: VBoxContainer = %Formulario
@onready var nombre_jugador: LineEdit = %NombreJugador
@onready var boton_continuar: Button = %Continuar
@onready var boton_volver: Button = %Volver
@onready var error_inicio: Label = %ErrorInicio
@onready var tabla: VBoxContainer = %Tabla
@onready var lista: ScrollContainer = %Lista
@onready var filas: VBoxContainer = %Filas
@onready var estado: Label = %Estado


func _ready() -> void:
	nombre_jugador.max_length = ClasificacionLocalScript.MAX_CARACTERES_NOMBRE
	nombre_jugador.text_changed.connect(_actualizar_nombre)
	nombre_jugador.text_submitted.connect(_confirmar_nombre)
	boton_continuar.pressed.connect(func() -> void: _confirmar_nombre(nombre_jugador.text))
	lista.gui_input.connect(_desplazar_tabla)


func presentar_nombre(nombre_anterior: String) -> void:
	titulo.text = "TU NOMBRE"
	tabla.hide()
	estado.hide()
	formulario.show()
	boton_continuar.show()
	nombre_jugador.text = nombre_anterior
	error_inicio.hide()
	_actualizar_nombre(nombre_anterior)


func presentar_tabla(entradas: Array[Dictionary], error: Error) -> void:
	titulo.text = "CLASIFICACIÓN"
	formulario.hide()
	boton_continuar.hide()
	for fila: Node in filas.get_children():
		filas.remove_child(fila)
		fila.queue_free()

	if error != OK or entradas.is_empty():
		tabla.hide()
		estado.text = "No se pudo leer la clasificación local." if error != OK else (
			"Aún no hay puntuaciones. Completa una denuncia para registrar tu marca."
		)
		estado.show()
		return

	estado.hide()
	for indice: int in range(entradas.size()):
		var entrada := entradas[indice]
		_agregar_fila(indice + 1, entrada["nombre"], entrada["puntos"])
	lista.scroll_vertical = 0
	tabla.show()


func mostrar_error_inicio() -> void:
	error_inicio.show()


func _actualizar_nombre(texto: String) -> void:
	boton_continuar.disabled = ClasificacionLocalScript.limpiar_nombre(texto).is_empty()


func _confirmar_nombre(texto: String) -> void:
	var nombre := ClasificacionLocalScript.limpiar_nombre(texto)
	if not nombre.is_empty():
		nombre_confirmado.emit(nombre)


func _desplazar_tabla(evento: InputEvent) -> void:
	if not evento is InputEventKey or not evento.pressed:
		return
	match evento.keycode:
		KEY_UP:
			lista.scroll_vertical -= 54
		KEY_DOWN:
			lista.scroll_vertical += 54
		KEY_PAGEUP:
			lista.scroll_vertical -= roundi(lista.size.y)
		KEY_PAGEDOWN:
			lista.scroll_vertical += roundi(lista.size.y)
		KEY_HOME:
			lista.scroll_vertical = 0
		KEY_END:
			lista.scroll_vertical = ceili(lista.get_v_scroll_bar().max_value)
		_:
			return
	lista.accept_event()


func _agregar_fila(posicion: int, nombre: String, puntos: int) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", estilo_fila)
	filas.add_child(panel)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	panel.add_child(fila)

	var numero := _crear_celda(str(posicion), 76, CORAL)
	numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fila.add_child(numero)
	var jugador := _crear_celda(nombre, 0, CREMA)
	jugador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jugador.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	jugador.tooltip_text = nombre
	fila.add_child(jugador)
	var marcador := _crear_celda(str(puntos), 310, CREMA)
	marcador.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fila.add_child(marcador)


func _crear_celda(texto: String, ancho_minimo: float, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.custom_minimum_size.x = ancho_minimo
	etiqueta.add_theme_font_override("font", fuente_tabla)
	etiqueta.add_theme_font_size_override("font_size", 26)
	etiqueta.add_theme_color_override("font_color", color)
	return etiqueta
