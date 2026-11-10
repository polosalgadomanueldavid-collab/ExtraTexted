class_name FinalPartida
extends Control

signal relevo_iniciado
signal reiniciar_solicitado
signal menu_solicitado

const FUENTE_TITULOS := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const FUENTE_TEXTO := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
const SONIDO_ALERTA := preload("res://Audios/Apagon/rechazo.wav")
const SONIDO_RELEVO := preload("res://Audios/VozPersonaje/Gomosa/saludo.wav")
const SONIDO_PAGINA := preload("res://Audios/Mesas/pasar_hoja_1.ogg")
const PETROLEO := Color("173b50")
const CREMA := Color("fff1d8")
const CORAL := Color("ff785f")
const TINTA := Color("294459")
const NOMBRES_ESTACIONES := {
	"privacidad": "Seguridad",
	"evidencias": "Evidencias",
	"verificacion": "Verificación",
	"reporte": "Reporte",
	"bienestar": "Bienestar"
}

var _datos: Dictionary = {}
var _fase: int = 0
var _fondo: ColorRect
var _tarjeta: PanelContainer
var _rotulo: Label
var _titulo_caso: Label
var _detalle: Label
var _dialogo: Label
var _saltar: Button
var _cuaderno: PanelContainer
var _lomo: ColorRect
var _anillas: Array[Panel] = []
var _lista: VBoxContainer
var _estadisticas: Label
var _alerta: AudioStreamPlayer
var _voz: AudioStreamPlayer
var _pagina: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_construir_interfaz()
	resized.connect(_ajustar)
	_ajustar()
	hide()


func presentar(datos: Dictionary) -> void:
	if _fase != 0:
		return
	_datos = datos
	_fase = 1
	show()
	_tarjeta.show()
	_cuaderno.hide()
	_rotulo.text = "DENUNCIA VENCIDA · CALMA 0"
	var causa: Dictionary = _datos.get("causa", {})
	_titulo_caso.text = str(causa.get("titulo", "Denuncia sin resolver"))
	_detalle.text = "Quedó pendiente: %s" % _estaciones(causa.get("pendientes", []))
	_dialogo.text = ""
	_saltar.grab_focus()
	_alerta.play()
	_secuencia()


func _secuencia() -> void:
	await get_tree().create_timer(2.4, true, false, true).timeout
	if not is_inside_tree() or _fase != 1:
		return
	_rotulo.text = "RELEVO DE EMERGENCIA"
	_titulo_caso.text = "El equipo toma el relevo"
	_detalle.text = "Tu turno termina aquí."
	_dialogo.text = "COMPAÑERO · «Déjalo. Yo me encargo desde aquí»"
	_voz.play()
	relevo_iniciado.emit()
	await get_tree().create_timer(3.2, true, false, true).timeout
	if is_inside_tree() and _fase == 1:
		_abrir_cuaderno()


func _construir_interfaz() -> void:
	_fondo = ColorRect.new()
	_fondo.color = Color(0.02, 0.08, 0.12, 0.48)
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fondo)

	_tarjeta = PanelContainer.new()
	_tarjeta.add_theme_stylebox_override("panel", _estilo(PETROLEO, CORAL, 22))
	add_child(_tarjeta)
	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 10)
	_tarjeta.add_child(contenido)
	_rotulo = _etiqueta("", 24, CORAL, FUENTE_TITULOS)
	contenido.add_child(_rotulo)
	_titulo_caso = _etiqueta("", 36, CREMA, FUENTE_TITULOS)
	contenido.add_child(_titulo_caso)
	_detalle = _etiqueta("", 22, CREMA, FUENTE_TEXTO)
	contenido.add_child(_detalle)
	_dialogo = _etiqueta("", 21, Color("ffd279"), FUENTE_TEXTO)
	contenido.add_child(_dialogo)
	_saltar = Button.new()
	_saltar.text = "Ir al cuaderno  ›"
	_saltar.pressed.connect(_abrir_cuaderno)
	contenido.add_child(_saltar)

	_cuaderno = PanelContainer.new()
	_cuaderno.add_theme_stylebox_override("panel", _estilo(CREMA, TINTA, 30))
	add_child(_cuaderno)
	_lomo = ColorRect.new()
	_lomo.color = Color("e9ded0")
	_lomo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lomo)
	for indice: int in range(3):
		var anilla := Panel.new()
		var metal := _estilo(Color("587487"), TINTA, 0)
		metal.set_corner_radius_all(12)
		anilla.add_theme_stylebox_override("panel", metal)
		anilla.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(anilla)
		_anillas.append(anilla)
	var pagina := VBoxContainer.new()
	pagina.add_theme_constant_override("separation", 15)
	_cuaderno.add_child(pagina)
	var cabecera := _etiqueta("CUADERNO DE TURNO", 42, PETROLEO, FUENTE_TITULOS)
	pagina.add_child(cabecera)
	_estadisticas = _etiqueta("", 21, TINTA, FUENTE_TEXTO)
	pagina.add_child(_estadisticas)
	var separador := HSeparator.new()
	pagina.add_child(separador)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pagina.add_child(scroll)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 12)
	scroll.add_child(_lista)
	var acciones := HBoxContainer.new()
	acciones.alignment = BoxContainer.ALIGNMENT_END
	acciones.add_theme_constant_override("separation", 16)
	pagina.add_child(acciones)
	var reiniciar := Button.new()
	reiniciar.text = "Jugar de nuevo"
	reiniciar.pressed.connect(func() -> void: reiniciar_solicitado.emit())
	acciones.add_child(reiniciar)
	var menu := Button.new()
	menu.text = "Menú principal"
	menu.pressed.connect(func() -> void: menu_solicitado.emit())
	acciones.add_child(menu)
	_cuaderno.hide()
	_lomo.hide()
	for anilla: Panel in _anillas:
		anilla.hide()
	_alerta = _crear_sonido(SONIDO_ALERTA, -7.0)
	_voz = _crear_sonido(SONIDO_RELEVO, -4.0)
	_pagina = _crear_sonido(SONIDO_PAGINA, -5.0)


func _ajustar() -> void:
	if not is_instance_valid(_tarjeta):
		return
	var ancho_tarjeta := minf(720.0, size.x - 40.0)
	_tarjeta.size = Vector2(ancho_tarjeta, 260.0)
	_tarjeta.position = Vector2(20.0, maxf(20.0, size.y - _tarjeta.size.y - 25.0))
	_cuaderno.size = Vector2(minf(1050.0, size.x - 40.0), minf(760.0, size.y - 40.0))
	_cuaderno.position = (size - _cuaderno.size) * 0.5
	_lomo.position = _cuaderno.position + Vector2(18.0, 22.0)
	_lomo.size = Vector2(3.0, _cuaderno.size.y - 44.0)
	for indice: int in range(_anillas.size()):
		var anilla := _anillas[indice]
		anilla.size = Vector2(18.0, 18.0)
		anilla.position = _cuaderno.position + Vector2(10.0, _cuaderno.size.y * float(indice + 1) / 4.0 - 9.0)


func _abrir_cuaderno() -> void:
	if _fase != 1:
		return
	_fase = 2
	_pagina.play()
	_tarjeta.hide()
	_fondo.color = Color(0.02, 0.08, 0.12, 0.86)
	_cuaderno.show()
	_llenar_cuaderno()
	_ajustar.call_deferred()
	_animar_apertura.call_deferred()


func _animar_apertura() -> void:
	_cuaderno.pivot_offset = _cuaderno.size * 0.5
	_cuaderno.scale = Vector2(0.92, 0.08)
	_cuaderno.modulate = Color(1.0, 1.0, 1.0, 0.4)
	var apertura := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	apertura.set_parallel(true)
	apertura.tween_property(_cuaderno, "scale", Vector2.ONE, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	apertura.tween_property(_cuaderno, "modulate", Color.WHITE, 0.34)
	apertura.finished.connect(_al_abrir_cuaderno)


func _al_abrir_cuaderno() -> void:
	_lomo.show()
	for anilla: Panel in _anillas:
		anilla.show()
	var boton := _cuaderno.find_children("*", "Button", true, false).front() as Button
	if boton != null:
		boton.grab_focus()


func _llenar_cuaderno() -> void:
	for hijo: Node in _lista.get_children():
		_lista.remove_child(hijo)
		hijo.queue_free()
	var resueltas: Array = _datos.get("resueltas", [])
	var vencidas: Array = _datos.get("vencidas", [])
	var pendientes: Array = _datos.get("pendientes", [])
	var segundos := int(_datos.get("duracion", 0.0))
	_estadisticas.text = "TIEMPO  %02d:%02d     RESUELTAS  %d     VENCIDAS  %d     SIN CERRAR  %d\nPUNTOS GANADOS  %d     SALDO FINAL  %d" % [segundos / 60, segundos % 60, resueltas.size(), vencidas.size(), pendientes.size(), int(_datos.get("puntos_ganados", 0)), int(_datos.get("saldo", 0))]
	_agregar_seccion("LO QUE HICISTE", resueltas, "No se alcanzó a resolver ninguna denuncia.", Color("2c7c68"))
	_agregar_seccion("LO QUE VENCIÓ", vencidas, "Ninguna denuncia venció.", CORAL)
	_agregar_seccion("LO QUE QUEDÓ EN MANOS DEL EQUIPO", pendientes, "No quedaron denuncias abiertas.", TINTA)


func _agregar_seccion(titulo: String, casos: Array, vacio: String, color: Color) -> void:
	_lista.add_child(_etiqueta(titulo, 28, color, FUENTE_TITULOS))
	if casos.is_empty():
		_lista.add_child(_etiqueta(vacio, 19, TINTA, FUENTE_TEXTO))
		return
	for valor: Variant in casos:
		var caso: Dictionary = valor
		var texto := "• %s" % str(caso.get("titulo", "Denuncia"))
		var completadas: Array = caso.get("completadas", [])
		var pendientes: Array = caso.get("pendientes", [])
		if not completadas.is_empty():
			texto += "\n   Hecho: %s" % _estaciones(completadas)
		if not pendientes.is_empty():
			texto += "\n   Faltó: %s" % _estaciones(pendientes)
		_lista.add_child(_etiqueta(texto, 19, TINTA, FUENTE_TEXTO))


func _estaciones(ids: Array) -> String:
	if ids.is_empty():
		return "ninguna estación"
	var nombres := PackedStringArray()
	for id: Variant in ids:
		nombres.append(str(NOMBRES_ESTACIONES.get(str(id), str(id).capitalize())))
	return ", ".join(nombres)


func _etiqueta(texto: String, tamano: int, color: Color, fuente: Font) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.add_theme_font_override("font", fuente)
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	return etiqueta


func _estilo(fondo: Color, borde: Color, margen: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(18)
	estilo.content_margin_left = margen
	estilo.content_margin_right = margen
	estilo.content_margin_top = margen
	estilo.content_margin_bottom = margen
	return estilo


func _crear_sonido(clip: AudioStream, volumen: float) -> AudioStreamPlayer:
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = clip
	reproductor.volume_db = volumen
	reproductor.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(reproductor)
	return reproductor
