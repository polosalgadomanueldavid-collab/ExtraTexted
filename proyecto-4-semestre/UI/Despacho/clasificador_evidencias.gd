extends Control
## Tres documentos, tres bandejas. La selección y el orden cambian por caso.

signal terminado(caso_id: String)
signal cerrado

const FUENTE := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const TINTA := Color("173b50")
const CREMA := Color("fff1d8")
const CORAL := Color("ff785f")
const COLORES := [Color("ffc969"), Color("76d7c4"), Color("b8a7f2")]
const TIPOS := ["IDENTIDAD", "MENSAJES", "ENLACES"]

var caso_id: String = ""
var documentos: Array[int] = []
var archivados: int = 0
var seleccion: int = 1
var error_restante: float = 0.0


func _ready() -> void:
	name = "ClasificadorEvidencias"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


func iniciar(id: String) -> void:
	if caso_id != id or documentos.is_empty():
		caso_id = id
		documentos = [0, 1, 2]
		documentos.shuffle()
		archivados = 0
	seleccion = 1
	error_restante = 0.0
	show()
	queue_redraw()


func cancelar() -> void:
	hide()
	caso_id = ""
	documentos.clear()
	archivados = 0
	cerrado.emit()


func _process(delta: float) -> void:
	if not visible or error_restante <= 0.0:
		return
	error_restante = maxf(0.0, error_restante - delta)
	queue_redraw()


func _input(evento: InputEvent) -> void:
	if not visible or not evento is InputEventKey or not evento.pressed or evento.echo:
		return
	var tecla: int = evento.physical_keycode if evento.physical_keycode != 0 else evento.keycode
	if tecla == KEY_A or tecla == KEY_LEFT:
		seleccion = posmod(seleccion - 1, 3)
	elif tecla == KEY_D or tecla == KEY_RIGHT:
		seleccion = posmod(seleccion + 1, 3)
	elif tecla == KEY_E:
		_archivar()
	elif tecla == KEY_ESCAPE:
		hide()
		cerrado.emit()
	else:
		return
	get_viewport().set_input_as_handled()
	queue_redraw()


func _archivar() -> void:
	if documentos.is_empty() or archivados >= documentos.size():
		return
	if seleccion != documentos[archivados]:
		error_restante = 0.55
		return
	archivados += 1
	error_restante = 0.0
	if archivados == documentos.size():
		var id_terminado := caso_id
		hide()
		caso_id = ""
		documentos.clear()
		cerrado.emit()
		terminado.emit(id_terminado)
	else:
		seleccion = 1


func _draw() -> void:
	var factor := minf(size.x / 1280.0, size.y / 720.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.10, 0.14, 0.68))
	var centro := size * 0.5
	var caja := Rect2(centro - Vector2(343, 215) * factor, Vector2(686, 430) * factor)
	draw_rect(caja, TINTA)
	draw_rect(caja.grow(3.0 * factor), CREMA, false, 3.0 * factor)
	_texto("ARCHIVO DE EVIDENCIAS", centro + Vector2(-170, -172) * factor, 28, CREMA, factor)
	_texto("ELIGE LA BANDEJA DEL DOCUMENTO", centro + Vector2(-205, -132) * factor, 17, CORAL, factor)
	for i: int in range(3):
		var punto := centro + Vector2(-100 + i * 100, -78) * factor
		draw_circle(punto, 13.0 * factor, CORAL if i < archivados else CREMA.darkened(0.48))
	var tipo: int = documentos[archivados] if archivados < documentos.size() else 0
	var hoja := Rect2(centro + Vector2(-82, -46) * factor, Vector2(164, 88) * factor)
	draw_rect(hoja, CREMA)
	draw_rect(Rect2(hoja.position + Vector2(13, 13) * factor, Vector2(26, 26) * factor), COLORES[tipo])
	_texto(TIPOS[tipo], hoja.position + Vector2(13, 68) * factor, 18, TINTA, factor)
	for i: int in range(3):
		var bandeja := Rect2(centro + Vector2(-305 + i * 210, 66) * factor, Vector2(190, 82) * factor)
		draw_rect(bandeja, COLORES[i] if seleccion == i else CREMA.darkened(0.13))
		draw_rect(bandeja.grow(4.0 * factor), CORAL if seleccion == i else TINTA, false, 4.0 * factor)
		_texto(TIPOS[i], bandeja.position + Vector2(12, 49) * factor, 17, TINTA, factor)
	var instruccion := "A / D ELEGIR    ·    E ARCHIVAR    ·    ESC SALIR"
	_texto(instruccion, centro + Vector2(-250, 190) * factor, 16, CORAL if error_restante > 0.0 else CREMA, factor)
	if error_restante > 0.0:
		_texto("BANDEJA INCORRECTA", centro + Vector2(-120, 169) * factor, 17, CORAL, factor)


func _texto(valor: String, posicion: Vector2, tamano: int, color: Color, factor: float) -> void:
	draw_string(FUENTE, posicion, valor, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(10, roundi(tamano * factor)), color)
