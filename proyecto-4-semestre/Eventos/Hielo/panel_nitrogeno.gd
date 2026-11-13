extends Control
## Apriete cruzado de cuatro tuercas, en tres pasadas. Conserva el progreso al salir.

signal reparado
signal cerrado
const Arte := preload("res://Eventos/Hielo/arte_nitrogeno.gd")
const TAMANO := Arte.TAMANO
const CENTROS := Arte.CENTROS
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
var _arte := Arte.new()
var _giros: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _golpes: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _sobre_tuerca := -1
var _ultima_tuerca := -1
var _acierto := 0.0


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
	_giros.fill(0.0)
	_golpes.fill(0.0)
	_sobre_tuerca = -1
	_ultima_tuerca = -1
	_acierto = 0.0


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
	_ultima_tuerca = indice
	_acierto = 1.0
	_golpes[indice] = 1.0
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
	_acierto = maxf(0.0, _acierto - delta * 2.5)
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
		if Arte.SALIR.has_point(punto):
			cerrar()
		else:
			var indice := _indice_en_punto(punto)
			if indice >= 0:
				apretar(indice)
		accept_event()


func _indice_en_punto(punto: Vector2) -> int:
	for i in 4:
		if punto.distance_to(CENTROS[i]) <= Arte.RADIO_TUERCA:
			return i
	return -1


func _actualizar_cursor() -> void:
	var punto := (get_local_mouse_position() - _origen) / _escala
	_sobre_tuerca = _indice_en_punto(punto) if not resuelto else -1
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _sobre_tuerca >= 0 or Arte.SALIR.has_point(punto) else Control.CURSOR_ARROW


func _draw() -> void:
	_arte.dibujar(self)
