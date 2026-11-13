extends Control

signal reparado
signal cerrado
const Red := preload("res://Eventos/Inundacion/red_tuberias.gd")
const TEXTO := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
const ARTE := preload("res://Eventos/Inundacion/arte_tuberias.svg")
const TAMANO := Vector2(900, 550)
const TABLERO := Vector2(222, 76)
const CELDA := 88.0
const MASCARAS := [3, 5, 6, 9, 10, 12]
const TINTA := Color("25434c")
const CREMA := Color("f5efd4")
const AGUA := Color("73ded7")
var red := Red.new()
var seleccion := 0
var _tiempo := 0.0
var _llenado := 0.0
var _emitida := false
var _escala := 1.0
var _origen := Vector2.ZERO
var _foco_anterior: Control
var _fuente: FontVariation


func _ready() -> void:
	name = "PanelTuberias"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_fuente = FontVariation.new()
	_fuente.base_font = TEXTO
	_fuente.variation_opentype = {2003265652: 800.0}
	resized.connect(_ajustar)
	_ajustar()
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
	_ajustar()
	queue_redraw()


func cerrar() -> void:
	if not visible:
		return
	hide()
	if is_instance_valid(_foco_anterior) and _foco_anterior.is_visible_in_tree():
		_foco_anterior.grab_focus()
	cerrado.emit()


func _ajustar() -> void:
	_escala = maxf(0.01, minf(size.x / 1280.0, size.y / 720.0))
	_origen = (size - TAMANO * _escala) * 0.5
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_tiempo += delta
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
	if get_tree().paused:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = (event.position - _origen) / _escala
		if Rect2(TABLERO, Vector2(Red.COLUMNAS, Red.FILAS) * CELDA).has_point(p):
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
	estilo.set_corner_radius_all(3)
	estilo.border_color = borde
	estilo.set_border_width_all(0 if borde == Color.TRANSPARENT else 2)
	draw_style_box(estilo, rect)


func _texto(texto: String, punto: Vector2, tamano: int, color: Color = CREMA) -> void:
	draw_string(_fuente, punto, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, color)


func _imagen(destino: Rect2, region: Rect2, color := Color.WHITE) -> void:
	# El SVG se importa al doble de las coordenadas de diseño del atlas.
	draw_texture_rect_region(ARTE, destino, Rect2(region.position * 2, region.size * 2), color)


func _tecla(texto: String, posicion: Vector2, ancho: float) -> void:
	_caja(Rect2(posicion + Vector2(0, 2), Vector2(ancho, 25)), Color("142f39"))
	_caja(Rect2(posicion, Vector2(ancho, 25)), Color("e3e6d1"), TINTA)
	var texto_ancho := _fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	_texto(texto, posicion + Vector2((ancho - texto_ancho) * 0.5, 18), 17, TINTA)


func _dibujar_fugas(indice: int, origen: Vector2) -> void:
	for lado in 4:
		if not (red.piezas[indice] & (1 << lado)):
			continue
		if (indice == 0 and lado == 3) or (indice == red.piezas.size() - 1 and lado == 1):
			continue
		var vecina: Vector2i = Red.coordenada(indice) + Red.DIRECCIONES[lado]
		if Red.dentro(vecina) and (red.piezas[vecina.y * Red.COLUMNAS + vecina.x] & (1 << ((lado + 2) % 4))):
			continue
		var direccion := Vector2(Red.DIRECCIONES[lado])
		var extremo := origen + Vector2.ONE * CELDA * 0.5 + direccion * (CELDA * 0.5 - 4)
		for gota in 2:
			var fase := fposmod(_tiempo * 0.9 + gota * 0.5, 1.0)
			var punto := extremo + direccion * (5 + fase * 14) + Vector2(0, fase * fase * 25)
			var tamano := Vector2(9, 12) * (1.0 - fase * 0.3)
			_imagen(Rect2(punto - tamano * 0.5, tamano), Rect2(600, 590, 16, 20), Color(1, 1, 1, 1.0 - fase))


func _dibujar_seleccion() -> void:
	var esquina := TABLERO + Vector2(Red.coordenada(seleccion)) * CELDA + Vector2(4, 4)
	var ancho := CELDA - 8
	for giro in 4:
		var centro := esquina + Vector2.ONE * ancho * 0.5
		var puntos := PackedVector2Array()
		for punto in [Vector2(-ancho * 0.5, -ancho * 0.5 + 15), Vector2(-ancho * 0.5, -ancho * 0.5 + 4), Vector2(-ancho * 0.5 + 4, -ancho * 0.5), Vector2(-ancho * 0.5 + 15, -ancho * 0.5)]:
			puntos.append(centro + punto.rotated(giro * PI * 0.5))
		draw_polyline(puntos, Color("162e3a"), 6, true)
		draw_polyline(puntos, Color("ffce79"), 3, true)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.08, 0.13, 0.76))
	draw_set_transform(_origen, 0, Vector2.ONE * _escala)
	_imagen(Rect2(Vector2.ZERO, TAMANO), Rect2(Vector2.ZERO, TAMANO))
	for i in red.piezas.size():
		var p := TABLERO + Vector2(Red.coordenada(i)) * CELDA
		var mojada := red.conectadas.has(i)
		var region := Rect2(MASCARAS.find(red.piezas[i]) * 96, 690 if mojada else 590, CELDA, CELDA)
		_imagen(Rect2(p, Vector2.ONE * CELDA), region)
	for i in red.conectadas:
		_dibujar_fugas(i, TABLERO + Vector2(Red.coordenada(i)) * CELDA)
	_dibujar_seleccion()
	_texto("ENTRADA", Vector2(122, 171), 17)
	_texto("DESAGÜE", Vector2(698, 336), 17)
	# El visor desciende durante la confirmación de vaciado ya existente.
	var nivel := 0.73 * (1.0 - clampf(_llenado / 1.4, 0.0, 1.0))
	if nivel > 0.0:
		draw_rect(Rect2(152, 373 - 96 * nivel, 20, 96 * nivel), AGUA.darkened(0.15))
		draw_line(Vector2(152, 373 - 96 * nivel), Vector2(172, 373 - 96 * nivel), Color("b7f1df"), 2, true)
	for y in range(286, 370, 10):
		draw_line(Vector2(168, y), Vector2(173, y), TINTA, 1, true)
	var caudal := 1.0 if red.resuelta else float(red.conectadas.size()) / (Red.COLUMNAS * Red.FILAS) * 0.75
	var aguja := Vector2.UP.rotated(deg_to_rad(lerpf(-130, 110, caudal)))
	draw_line(Vector2(746, 146) - aguja * 8, Vector2(746, 146) + aguja * 33, Color("68443a"), 5, true)
	draw_line(Vector2(746, 146) - aguja * 8, Vector2(746, 146) + aguja * 33, Color("ee805f"), 2.5, true)
	draw_circle(Vector2(746, 146), 5.5, Color("a1b5aa"), true, -1, true)
	if red.resuelta:
		_texto("Flujo conectado", Vector2(378, 502), 20, AGUA)
	else:
		_tecla("↑↓←→", Vector2(281, 481), 65)
		_texto("Elegir", Vector2(354, 500), 18)
		_tecla("E", Vector2(422, 481), 25)
		_texto("/", Vector2(454, 500), 18)
		_tecla("Clic", Vector2(470, 481), 43)
		_texto("Girar", Vector2(522, 500), 18)
	draw_set_transform(Vector2.ZERO)
