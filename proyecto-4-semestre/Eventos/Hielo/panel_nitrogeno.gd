extends Control
## Apriete cruzado de cuatro tuercas, en tres pasadas. Conserva el progreso al salir.

signal reparado
signal cerrado
const TITULO := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const TEXTO := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
const TAMANO := Vector2(800, 620)
const CENTROS := [Vector2(255, 240), Vector2(545, 240), Vector2(255, 410), Vector2(545, 410)]
const TINTA := Color("142b50")
const BLANCO := Color("eaf6ff")
const AZUL := Color("83baff")
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


func _ready() -> void:
	name = "PanelNitrogeno"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
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
	queue_redraw()
	return true


func _ajustar() -> void:
	_escala = minf(size.x / (TAMANO.x + 40), size.y / (TAMANO.y + 40))
	_origen = (size - TAMANO * _escala) * 0.5


func _process(delta: float) -> void:
	# Sellar se completa incluso si se pulsa Esc durante la confirmación final.
	if resuelto and not _emitida:
		_sellado += delta
		if _sellado >= 0.75:
			_emitida = true
			reparado.emit()
	if not visible:
		return
	_ajustar()
	_tiempo += delta
	_error = maxf(0.0, _error - delta)
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
		if Rect2(665, 25, 105, 38).has_point(punto):
			cerrar()
		else:
			for i in 4:
				if punto.distance_to(CENTROS[i]) <= 53:
					apretar(i)
		accept_event()


func _caja(rect: Rect2, color: Color, borde := Color.TRANSPARENT) -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.border_color = borde
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(14)
	draw_style_box(estilo, rect)


func _texto(texto: String, punto: Vector2, tamano: int, color := BLANCO, fuente: Font = TEXTO) -> void:
	draw_string(fuente, punto, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, color)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.035, 0.09, 0.76))
	draw_set_transform(_origen, 0, Vector2.ONE * _escala)
	_caja(Rect2(Vector2(0, 8), TAMANO), Color("08172f"))
	_caja(Rect2(Vector2.ZERO, TAMANO), TINTA, AZUL)
	_texto("FUGA DE NITRÓGENO", Vector2(32, 60), 34, BLANCO, TITULO)
	_caja(Rect2(665, 25, 105, 38), BLANCO)
	_texto("ESC · Salir", Vector2(678, 51), 16, TINTA)
	_texto("Aprieta las tuercas en cruz para sellar la tubería.", Vector2(32, 100), 23)
	var secuencia := "%d  →  %d  →  %d  →  %d" % [orden[0] + 1, orden[1] + 1, orden[2] + 1, orden[3] + 1]
	_texto("ORDEN   " + secuencia + "     ·     3 pasadas", Vector2(32, 134), 20, AZUL)
	_caja(Rect2(32, 155, 736, 326), Color("0b1c38"), Color("344f75"))
	# Tubería y brida: las cuatro tuercas se aprietan alrededor de la fuga central.
	draw_line(Vector2(75, 325), Vector2(725, 325), Color("273f60"), 85, true)
	draw_line(Vector2(75, 312), Vector2(725, 312), Color("7495bb"), 42, true)
	draw_line(Vector2(75, 300), Vector2(725, 300), Color("acc5e2"), 5, true)
	_caja(Rect2(210, 192, 380, 263), Color("3e5c82"), AZUL)
	draw_line(Vector2(400, 195), Vector2(400, 451), Color("0b1c38"), 8, true)
	var presion := 1.0 - paso / 12.0
	for i in 9:
		var fase := fposmod(_tiempo * 0.75 + i * 0.11, 1.0)
		draw_circle(Vector2(400 + sin(i * 2.4) * fase * 45, 345 - fase * 120), 7 + fase * 14, Color(0.7, 0.85, 1.0, (1.0 - fase) * presion * 0.4), true, -1, true)
	for i in 4:
		var centro: Vector2 = CENTROS[i]
		var objetivo := i == objetivo_actual()
		if i == seleccion:
			draw_arc(centro, 54, 0, TAU, 40, Color("ffda8a"), 3, true)
		var hexagono := PackedVector2Array()
		for j in 6:
			hexagono.append(centro + Vector2.from_angle(j * TAU / 6.0 + aprietes[i] * PI / 6.0) * 38)
		draw_colored_polygon(hexagono, Color("b9f5e2") if aprietes[i] == 3 else (BLANCO if objetivo else Color("7293bc")))
		hexagono.append(hexagono[0])
		draw_polyline(hexagono, TINTA, 4, true)
		draw_circle(centro, 19, TINTA, true, -1, true)
		_texto(str(i + 1), centro + Vector2(-8, 8), 23, BLANCO, TITULO)
		for j in 3:
			draw_circle(centro + Vector2((j - 1) * 14, 45), 4, Color("b9f5e2") if j < aprietes[i] else Color("162c49"), true, -1, true)
	var mensaje := "Fuga sellada · La oficina se está descongelando" if resuelto else "PASADA %d / 3   ·   Aprieta la tuerca %d" % [mini(3, paso / 4 + 1), objetivo_actual() + 1]
	if _error > 0.0:
		mensaje = "Sigue el orden en cruz: toca la tuerca %d" % (objetivo_actual() + 1)
	_texto(mensaje, Vector2(32, 514), 23, Color("ffda8a") if _error > 0 else BLANCO)
	_caja(Rect2(32, 533, 736, 12), Color("344f75"))
	if paso > 0:
		_caja(Rect2(32, 533, 736 * paso / 12.0, 12), Color("b9f5e2"))
	_texto("Clic: apretar  ·  WASD / Flechas: elegir  ·  E / Espacio: apretar", Vector2(32, 576), 19, AZUL)
	_texto("Puedes salir y continuar después. Los casos siguen en marcha.", Vector2(32, 604), 16, AZUL)
	draw_set_transform(Vector2.ZERO)
