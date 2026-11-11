extends PanelContainer

signal nombre_confirmado(nombre: String)

const ClasificacionLocalScript := preload("res://Scripts/Partida/ClasificacionLocal.gd")
const CREMA := Color("fff1d8")
const Arte := preload("res://UI/Despacho/arte_clasificacion.gd")
const FUENTE_TITULO := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")

var _modo_tabla := false
var _nombre_local := ""

@export var fuente_tabla: Font

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
@onready var volver_expediente: Button = %VolverExpediente
@onready var ficha: HBoxContainer = $Contenido/ResumenExpediente/FichaPersonal
@onready var marca: HBoxContainer = $Contenido/ResumenExpediente/MejorMarca


func _ready() -> void:
	nombre_jugador.max_length = ClasificacionLocalScript.MAX_CARACTERES_NOMBRE
	nombre_jugador.text_changed.connect(_actualizar_nombre)
	nombre_jugador.text_submitted.connect(_confirmar_nombre)
	boton_continuar.pressed.connect(func() -> void: _confirmar_nombre(nombre_jugador.text))
	lista.gui_input.connect(_desplazar_tabla)
	resized.connect(queue_redraw)
	for etiqueta: Label in $Contenido/Tabla/Cabecera.get_children():
		etiqueta.add_theme_color_override("font_color", Arte.TINTA)
		etiqueta.add_theme_font_override("font", FUENTE_TITULO)
		etiqueta.add_theme_font_size_override("font_size", 33)
	for grupo: HBoxContainer in [ficha, marca]:
		for elemento in grupo.get_children():
			if elemento is Label:
				elemento.add_theme_color_override("font_color", Arte.TINTA)
	var cabecera: HBoxContainer = $Contenido/Tabla/Cabecera
	cabecera.draw.connect(func() -> void:
		cabecera.draw_line(Vector2(13, cabecera.size.y + 3), cabecera.size + Vector2(-9, 3), Color("ae9c79"), 2, true))
	cabecera.resized.connect(cabecera.queue_redraw)
	var rotulo_puesto: Label = ficha.get_node("Rotulo")
	rotulo_puesto.draw.connect(func() -> void:
		if marca.visible:
			var y := rotulo_puesto.size.y + 1
			rotulo_puesto.draw_line(Vector2(2, y), Vector2(rotulo_puesto.size.x - 2, y - 1), Arte.CORAL, 4, true))
	marca.visibility_changed.connect(rotulo_puesto.queue_redraw)
	filas.add_theme_constant_override("separation", 0)
	estado.add_theme_color_override("font_color", Arte.TINTA)
	estado.custom_minimum_size.y = 120


func _draw() -> void:
	if _modo_tabla:
		Arte.marco(self, Arte.EXPEDIENTE, 221, 169)
		draw_string(FUENTE_TITULO, Vector2(50, 58), "RÉCORDS",
			HORIZONTAL_ALIGNMENT_CENTER, 220, 42, Arte.TINTA)


func _establecer_diseno(es_tabla: bool) -> void:
	_modo_tabla = es_tabla
	$Contenido/Encabezado/Seccion.visible = not es_tabla
	$Contenido/ResumenExpediente.visible = es_tabla
	$Contenido/Botones.alignment = BoxContainer.ALIGNMENT_END if es_tabla else BoxContainer.ALIGNMENT_CENTER
	volver_expediente.visible = es_tabla
	boton_volver.visible = not es_tabla
	marca.hide()
	titulo.add_theme_color_override("font_color", Arte.TINTA if es_tabla else CREMA)
	titulo.add_theme_font_size_override("font_size", 86 if es_tabla else 60)
	custom_minimum_size.x = 1100 if es_tabla else 1040
	if es_tabla:
		add_theme_stylebox_override("panel", Arte.margenes(101, 98, 100, 17))
		$Contenido.add_theme_constant_override("separation", 27)
		$Contenido/Encabezado.custom_minimum_size.y = 122
	else:
		remove_theme_stylebox_override("panel")
		$Contenido.add_theme_constant_override("separation", 20)
		$Contenido/Encabezado.custom_minimum_size.y = 0
	queue_redraw()


func presentar_nombre(nombre_anterior: String) -> void:
	_establecer_diseno(false)
	titulo.text = "TU NOMBRE"
	tabla.hide()
	estado.hide()
	formulario.show()
	boton_continuar.show()
	nombre_jugador.text = nombre_anterior
	error_inicio.hide()
	_actualizar_nombre(nombre_anterior)


func presentar_tabla(entradas: Array[Dictionary], error: Error, nombre_local: String = "") -> void:
	_establecer_diseno(true)
	_nombre_local = ClasificacionLocalScript.limpiar_nombre(nombre_local).to_lower()
	titulo.text = "CLASIFICACIÓN"
	formulario.hide()
	boton_continuar.hide()
	for fila: Node in filas.get_children():
		filas.remove_child(fila)
		fila.queue_free()

	ficha.get_node("Valor").tooltip_text = ""
	ficha.get_node("Rotulo").text = "RÉCORDS LOCALES"
	ficha.get_node("Valor").text = str(entradas.size()) if error == OK else "—"
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
		var propia: bool = not _nombre_local.is_empty() and entrada.nombre.to_lower() == _nombre_local
		_agregar_fila(indice + 1, entrada.nombre, entrada.puntos, propia)
		if propia:
			ficha.get_node("Rotulo").text = "PUESTO #%d" % (indice + 1)
			ficha.get_node("Valor").text = entrada.nombre
			ficha.get_node("Valor").tooltip_text = entrada.nombre
			marca.get_node("Valor").text = str(entrada.puntos)
			marca.show()
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


func _agregar_fila(posicion: int, nombre: String, puntos: int, propia: bool) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Arte.margenes(39, 0, 20, 0))
	panel.custom_minimum_size.y = 78
	panel.draw.connect(func() -> void: Arte.fila_expediente(panel, propia, posicion))
	panel.resized.connect(panel.queue_redraw)
	filas.add_child(panel)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 40)
	panel.add_child(fila)

	var numero := _crear_celda(str(posicion))
	numero.custom_minimum_size.x = 98
	numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fila.add_child(numero)
	var jugador := _crear_celda(nombre)
	jugador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jugador.clip_text = true
	jugador.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	jugador.tooltip_text = nombre
	fila.add_child(jugador)
	var marcador := _crear_celda(str(puntos))
	marcador.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fila.add_child(marcador)


func _crear_celda(texto: String) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_override("font", fuente_tabla)
	etiqueta.add_theme_font_size_override("font_size", 48)
	etiqueta.add_theme_color_override("font_color", Arte.TINTA)
	return etiqueta
