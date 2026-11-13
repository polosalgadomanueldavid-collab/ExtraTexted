extends Control

signal reparado
signal cerrado
const Red := preload("res://Eventos/Inundacion/red_tuberias.gd")
const TITULO := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const TEXTO := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
const TAMANO := Vector2(820, 630)
const TABLERO := Vector2(190, 158)
const CELDA := 88.0
const TINTA := Color("173b50")
const AGUA := Color("42dbef")
var red := Red.new()
var seleccion := 0
var _tiempo := 0.0
var _llenado := 0.0
var _emitida := false
var _escala := 1.0
var _origen := Vector2.ZERO
var _foco_anterior: Control


func _ready() -> void:
	name = "PanelTuberias"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	hide()


func preparar(semilla: int) -> void:
	red.generar(semilla)
	seleccion = 0
	_llenado = 0.0
	_emitida = false


func abrir() -> void:
	_foco_anterior = get_viewport().gui_get_focus_owner()
	show()
	grab_focus()
	queue_redraw()


func cerrar() -> void:
	if not visible:
		return
	hide()
	if is_instance_valid(_foco_anterior) and _foco_anterior.is_visible_in_tree():
		_foco_anterior.grab_focus()
	cerrado.emit()


func _process(delta: float) -> void:
	if not visible:
		return
	_tiempo += delta
	_escala = minf(size.x / (TAMANO.x + 40), size.y / (TAMANO.y + 40))
	_origen = (size - TAMANO * _escala) * 0.5
	if red.resuelta and not _emitida:
		_llenado += delta
		if _llenado >= 1.4:
			_emitida = true
			reparado.emit()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or get_tree().paused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				cerrar()
			KEY_LEFT, KEY_A:
				seleccion = (seleccion / Red.COLUMNAS) * Red.COLUMNAS + posmod(seleccion % Red.COLUMNAS - 1, Red.COLUMNAS)
			KEY_RIGHT, KEY_D:
				seleccion = (seleccion / Red.COLUMNAS) * Red.COLUMNAS + (seleccion + 1) % Red.COLUMNAS
			KEY_UP, KEY_W:
				seleccion = posmod(seleccion - Red.COLUMNAS, red.piezas.size())
			KEY_DOWN, KEY_S:
				seleccion = (seleccion + Red.COLUMNAS) % red.piezas.size()
			KEY_E, KEY_ENTER, KEY_SPACE:
				_girar(seleccion)
			_:
				return
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = (event.position - _origen) / _escala
		if Rect2(683, 28, 100, 38).has_point(p):
			cerrar()
		elif Rect2(TABLERO, Vector2(5, 4) * CELDA).has_point(p):
			var celda := Vector2i((p - TABLERO) / CELDA)
			seleccion = celda.y * Red.COLUMNAS + celda.x
			_girar(seleccion)
		accept_event()


func _girar(indice: int) -> void:
	if red.resuelta or _emitida:
		return
	red.girar(indice)
	_llenado = 0.0
	queue_redraw()


func _caja(rect: Rect2, color: Color, borde: Color = Color.TRANSPARENT) -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.set_corner_radius_all(12)
	estilo.border_color = borde
	estilo.set_border_width_all(2)
	draw_style_box(estilo, rect)


func _texto(texto: String, punto: Vector2, tamano: int, color: Color, fuente: Font = TEXTO) -> void:
	draw_string(fuente, punto, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, color)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.08, 0.13, 0.76))
	draw_set_transform(_origen, 0, Vector2.ONE * _escala)
	_caja(Rect2(Vector2(0, 7), TAMANO), Color("081f31"))
	_caja(Rect2(Vector2.ZERO, TAMANO), Color("fff1d8"), TINTA)
	_texto("REPARAR TUBERÍAS", Vector2(38, 65), 34, TINTA, TITULO)
	_caja(Rect2(683, 28, 100, 38), TINTA)
	_texto("ESC · Salir", Vector2(695, 54), 16, Color("fff1d8"))
	_texto("Gira los tramos y conecta la entrada con el desagüe.", Vector2(38, 102), 22, TINTA)
	_texto("El agua azul muestra hasta dónde llega el flujo.", Vector2(38, 131), 18, TINTA)
	_caja(Rect2(TABLERO - Vector2(8, 8), Vector2(5, 4) * CELDA + Vector2(16, 16)), TINTA)
	for i in red.piezas.size():
		var p := TABLERO + Vector2(Red.coordenada(i)) * CELDA
		_caja(Rect2(p + Vector2(3, 3), Vector2.ONE * (CELDA - 6)), Color("24566c"), Color("ffcb68") if i == seleccion else Color.TRANSPARENT)
		var centro := p + Vector2.ONE * CELDA * 0.5
		var mojada := red.conectadas.has(i)
		var color := AGUA if mojada else Color("a0b4bb")
		for d in 4:
			if not (red.piezas[i] & (1 << d)):
				continue
			var extremo := centro + Vector2(Red.DIRECCIONES[d]) * (CELDA * 0.5 - 5)
			draw_line(centro, extremo, Color("102f40"), 30, true)
			draw_line(centro, extremo, color, 21, true)
			draw_line(centro + Vector2(-2, -2), extremo + Vector2(-2, -2), Color(color, 0.4).lightened(0.35), 4, true)
			if mojada:
				draw_circle(centro.lerp(extremo, fposmod(_tiempo * 0.8 + i * 0.16, 1.0)), 3, Color("e3ffff"), true, -1, true)
		draw_circle(centro, 11, color, true, -1, true)
	_texto("ENTRADA", Vector2(50, 194), 20, TINTA, TITULO)
	draw_line(Vector2(141, 202), TABLERO + Vector2(0, 44), AGUA, 15, true)
	_texto("DESAGÜE", Vector2(651, 440), 19, TINTA, TITULO)
	draw_line(TABLERO + Vector2(440, 308), Vector2(680, 466), AGUA if red.resuelta else Color("718b99"), 15, true)
	_texto("FLUJO CONECTADO · Vaciando la oficina…" if red.resuelta else "Clic o E / Espacio: girar   ·   WASD / Flechas: elegir", Vector2(38, 558), 22, TINTA)
	_caja(Rect2(38, 580, 744, 12), Color("b5c7c7"))
	if red.resuelta:
		_caja(Rect2(38, 580, 744 * clampf(_llenado / 1.4, 0, 1), 12), Color("168b9d"))
	else:
		_texto("Puedes salir y continuar después. Los casos siguen en marcha.", Vector2(38, 616), 16, TINTA)
	draw_set_transform(Vector2.ZERO)
