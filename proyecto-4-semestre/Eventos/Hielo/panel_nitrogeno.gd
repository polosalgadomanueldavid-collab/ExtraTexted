extends Control
## Apriete cruzado de cuatro tuercas, en tres pasadas. Conserva el progreso al salir.

signal reparado
signal cerrado
const TITULO := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const TEXTO := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
const ARTE := preload("res://Eventos/Hielo/arte_nitrogeno.svg")
const TAMANO := Vector2(860, 570)
const CENTROS := [Vector2(218.48, 216.32), Vector2(399.52, 216.32), Vector2(218.48, 314.28), Vector2(399.52, 314.28)]
const FICHA := Vector2(577, 184)
const CROQUIS := [Vector2(43, 75), Vector2(155, 75), Vector2(43, 139), Vector2(155, 139)]
const TINTA := Color("293f50")
const BLANCO := Color("fff1d8")
const VERDE := Color("7bd7d1")
const AMBAR := Color("f3ce8c")
var orden: Array[int] = [0, 3, 1, 2]
var aprietes: Array[int] = [0, 0, 0, 0]
var paso := 0
var seleccion := 0
var resuelto := false
var _emitida := false
var _tiempo := 0.0
var _error := 0.0
var _sellado := 0.0
var _escala := 1.0
var _origen := Vector2.ZERO
var _foco_anterior: Control
var _fuente: FontVariation
var _giros: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _golpes: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _sobre_tuerca := -1


func _ready() -> void:
	name = "PanelNitrogeno"
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
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	var primero := azar.randi_range(0, 3)
	orden = [primero, 3 - primero, primero ^ 1, (3 - primero) ^ 1]
	aprietes = [0, 0, 0, 0]
	paso = 0
	seleccion = 0
	resuelto = false
	_emitida = false
	_sellado = 0.0
	_error = 0.0
	_giros.fill(0.0)
	_golpes.fill(0.0)
	_sobre_tuerca = -1
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()


func abrir() -> void:
	_foco_anterior = get_viewport().gui_get_focus_owner()
	show()
	grab_focus()
	_ajustar()
	_actualizar_cursor()
	queue_redraw()


func cerrar() -> void:
	if not visible:
		return
	hide()
	if is_instance_valid(_foco_anterior) and _foco_anterior.is_visible_in_tree():
		_foco_anterior.grab_focus()
	cerrado.emit()


func objetivo_actual() -> int:
	return -1 if resuelto else orden[paso % 4]


func apretar(indice: int) -> bool:
	if not visible or get_tree().paused or resuelto or indice < 0 or indice > 3:
		return false
	seleccion = indice
	if indice != objetivo_actual():
		_error = 0.85
		queue_redraw()
		return false
	aprietes[indice] += 1
	paso += 1
	resuelto = paso == 12
	_error = 0.0
	_golpes[indice] = 1.0
	queue_redraw()
	return true


func _ajustar() -> void:
	_escala = maxf(0.01, minf(size.x / 1280.0, size.y / 720.0))
	_origen = (size - TAMANO * _escala) * 0.5
	queue_redraw()


func _process(delta: float) -> void:
	# Sellar se completa incluso si se pulsa Esc durante la confirmación final.
	if resuelto and not _emitida:
		_sellado += delta
		if _sellado >= 0.75:
			_emitida = true
			reparado.emit()
	if not visible:
		return
	_tiempo += delta
	_error = maxf(0.0, _error - delta)
	for i in 4:
		_giros[i] = move_toward(_giros[i], aprietes[i] * PI / 3.0, delta * 7.0)
		_golpes[i] = maxf(0.0, _golpes[i] - delta * 4.0)
	_actualizar_cursor()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or get_tree().paused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				cerrar()
			KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D:
				seleccion = seleccion ^ 1
			KEY_UP, KEY_W, KEY_DOWN, KEY_S:
				seleccion = seleccion ^ 2
			KEY_E, KEY_ENTER, KEY_SPACE:
				apretar(seleccion)
			_:
				return
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var punto: Vector2 = (event.position - _origen) / _escala
		var indice := _indice_en_punto(punto)
		if indice >= 0:
			apretar(indice)
		accept_event()


func _indice_en_punto(punto: Vector2) -> int:
	for i in 4:
		if punto.distance_to(CENTROS[i]) <= 42:
			return i
	return -1


func _actualizar_cursor() -> void:
	var punto := (get_local_mouse_position() - _origen) / _escala
	_sobre_tuerca = _indice_en_punto(punto) if not resuelto else -1
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _sobre_tuerca >= 0 else Control.CURSOR_ARROW


func _caja(rect: Rect2, color: Color, borde := Color.TRANSPARENT) -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.border_color = borde
	estilo.set_border_width_all(0 if borde == Color.TRANSPARENT else 2)
	estilo.set_corner_radius_all(4)
	draw_style_box(estilo, rect)


func _texto(texto: String, punto: Vector2, tamano: int, color := BLANCO, fuente: Font = null) -> void:
	draw_string(_fuente if fuente == null else fuente, punto, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, color)


func _imagen(destino: Rect2, region: Rect2, color := Color.WHITE) -> void:
	# El SVG se importa al doble de las coordenadas de diseño del atlas.
	draw_texture_rect_region(ARTE, destino, Rect2(region.position * 2, region.size * 2), color)


func _tecla(texto: String, posicion: Vector2, ancho: float) -> void:
	_caja(Rect2(posicion + Vector2(0, 2), Vector2(ancho, 25)), Color("142f39"))
	_caja(Rect2(posicion, Vector2(ancho, 25)), Color("e3e6d1"), TINTA)
	var texto_ancho := _fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	_texto(texto, posicion + Vector2((ancho - texto_ancho) * 0.5, 18), 17, TINTA)


func _dibujar_tuercas() -> void:
	for i in 4:
		var centro: Vector2 = CENTROS[i]
		var objetivo := i == objetivo_actual()
		var destino := Rect2(centro - Vector2(40, 40), Vector2(80, 80))
		_imagen(destino, Rect2(0, 590, 80, 80))
		# Movimiento de issa sobre la tuerca original de Barandica; la arandela queda fija.
		var elevacion := Vector2(0, -3.0 * float(i == _sobre_tuerca) - sin(_golpes[i] * PI) * 4.0)
		draw_set_transform(_origen + (centro + elevacion) * _escala, _giros[i], Vector2.ONE * _escala)
		_imagen(Rect2(-40, -40, 80, 80), Rect2(96, 590, 80, 80))
		draw_set_transform(_origen, 0, Vector2.ONE * _escala)
		if objetivo:
			draw_circle(centro + elevacion, 15, AMBAR, true, -1, true)
			draw_colored_polygon(PackedVector2Array([centro + Vector2(-55, -5), centro + Vector2(-46, 0), centro + Vector2(-55, 5)]), AMBAR)
		if i == seleccion or i == _sobre_tuerca:
			var color := Color("ff9671") if _error > 0 and i == seleccion else AMBAR
			for segmento in 4:
				var inicio := segmento * PI * 0.5 - 0.2
				draw_arc(centro, 40, inicio, inicio + 1.2, 18, Color("263c50"), 6, true)
				draw_arc(centro, 40, inicio, inicio + 1.2, 18, color, 3, true)
		# El número acompaña el rebote, pero siempre se lee derecho.
		_texto(str(i + 1), centro + elevacion + Vector2(-8, 9), 26, TINTA if objetivo else BLANCO, TITULO)
		for marca in 3:
			var punto := centro + Vector2((marca - 1) * 12, 42)
			draw_circle(punto + Vector2(0, 1), 4, Color("8199ab"), true, -1, true)
			draw_circle(punto, 3.4, VERDE if marca < aprietes[i] else Color("1c364e"), true, -1, true)


func _dibujar_ficha() -> void:
	draw_set_transform(_origen + FICHA * _escala, deg_to_rad(-2.3), Vector2.ONE * _escala)
	_texto("Orden", Vector2(70, 32), 21, TINTA)
	var contorno := PackedVector2Array([Vector2(22, 60), Vector2(35, 47), Vector2(166, 47), Vector2(179, 60), Vector2(179, 151), Vector2(166, 163), Vector2(35, 163), Vector2(22, 151), Vector2(22, 60)])
	draw_polyline(contorno, Color("8b9c98"), 1.5, true)
	draw_dashed_line(Vector2(100, 50), Vector2(100, 160), Color("879b9e"), 1, 4)
	for tramo in 3:
		var origen: Vector2 = CROQUIS[orden[tramo]]
		var destino: Vector2 = CROQUIS[orden[tramo + 1]]
		var direccion := (destino - origen).normalized()
		var punta := destino - direccion * 15
		draw_line(origen + direccion * 15, punta, Color("466470"), 2, true)
		draw_polyline(PackedVector2Array([punta - direccion * 7 + direccion.orthogonal() * 4, punta, punta - direccion * 7 - direccion.orthogonal() * 4]), Color("466470"), 2, true)
	for i in 4:
		var objetivo := i == objetivo_actual()
		draw_circle(CROQUIS[i], 12, Color("466470"), true, -1, true)
		draw_circle(CROQUIS[i], 10.3, AMBAR if objetivo else Color("f7efd9"), true, -1, true)
		_texto(str(i + 1), CROQUIS[i] + Vector2(-5, 6), 17, TINTA)
		var x := 23 + i * 43
		if orden[i] == objetivo_actual():
			_caja(Rect2(x - 4, 175, 23, 24), AMBAR, Color("8b7a59"))
		_texto(str(orden[i] + 1), Vector2(x, 194), 20, TINTA)
		if i < 3:
			_texto("→", Vector2(x + 22, 192), 16, Color("637e85"))
	draw_set_transform(_origen, 0, Vector2.ONE * _escala)


func _dibujar_pie() -> void:
	_caja(Rect2(56, 490, 127, 45), Color("253f53"), Color("9eb4bd"))
	_texto("Pasada", Vector2(66, 509), 17)
	_texto("%d/3" % mini(3, paso / 4 + 1), Vector2(141, 509), 17)
	for pasada in 3:
		var rect := Rect2(67 + pasada * 33, 518, 27, 6)
		_caja(rect, Color("52697c"))
		if paso >= (pasada + 1) * 4:
			_caja(rect, VERDE)
		elif pasada == paso / 4:
			_caja(rect, Color("7e725e"))
			for raya in 4:
				draw_line(rect.position + Vector2(2 + raya * 6, 5), rect.position + Vector2(5 + raya * 6, 1), AMBAR, 2, true)
	if resuelto:
		_texto("Fuga sellada", Vector2(212, 518), 19, VERDE)
	elif _error > 0:
		_texto("Sigue el orden", Vector2(212, 518), 18, Color("ffbc91"))
	_tecla("↑↓←→", Vector2(426, 497), 65)
	_texto("Elegir", Vector2(499, 516), 18)
	_tecla("E", Vector2(568, 497), 25)
	_texto("/", Vector2(600, 516), 18)
	_tecla("Clic", Vector2(616, 497), 43)
	_texto("Apretar", Vector2(668, 516), 18)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.035, 0.09, 0.76))
	draw_set_transform(_origen, 0, Vector2.ONE * _escala)
	_imagen(Rect2(Vector2.ZERO, TAMANO), Rect2(Vector2.ZERO, TAMANO))
	var presion := 1.0 - paso / 12.0
	if presion > 0.0:
		var vaho := Rect2(Vector2(296.6, 256) + Vector2(0, sin(_tiempo * 1.8) * 2), Vector2(160, 180))
		_imagen(vaho, Rect2(448, 590, 160, 180), Color(1, 1, 1, presion * (0.85 + sin(_tiempo * 1.5) * 0.15)))
	_dibujar_tuercas()
	_dibujar_ficha()
	_dibujar_pie()
	draw_set_transform(Vector2.ZERO)
