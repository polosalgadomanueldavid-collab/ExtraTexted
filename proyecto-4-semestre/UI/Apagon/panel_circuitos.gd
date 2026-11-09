class_name PanelCircuitos
extends Control
## Tres circuitos del gabinete. El progreso pertenece al apagón actual.

signal circuito_resuelto
signal cerrado

enum Tipo { INTERRUPTORES = 0, FASES = 2, CABLES = 3 }

const TIPOS_DISPONIBLES: Array[int] = [Tipo.CABLES, Tipo.FASES, Tipo.INTERRUPTORES]
const ARTE := preload("res://UI/Apagon/arte_circuitos.gd")
const SONIDOS := preload("res://UI/Apagon/sonidos_circuitos.gd")
const TAMANO_DISENO := Vector2(860, 510)
const ORIGEN_INTERIOR := Vector2(60, 110)
const DURACION_ENTRADA := 0.48
const DURACION_FIN := 0.85

var interruptores: Array[Button] = []
var botones_anillos: Array[Button] = []
var origenes_cables: Array[Button] = []
var destinos_cables: Array[Button] = []

var _tipo: int = Tipo.INTERRUPTORES
var _clave_estado: String = ""
var _estado: Dictionary = {}
var _abierto: bool = false
var _senal_emitida: bool = false
var _sonido_fin_emitido: bool = false
var _lienzo: Control
var _velo: ColorRect
var _arte: Control
var _sonidos: Node
var _foco_anterior: Control
var _foco_indice: int = 0
var _foco_destino: bool = false
var _seleccion_cable: int = -1
var _arrastrando: bool = false
var _usa_raton: bool = false
var _inicio_arrastre := Vector2.ZERO
var _raton := Vector2.ZERO
var _entrada_restante: float = 0.0
var _fin_restante: float = 0.0
var _error_restante: float = 0.0
var _error_indice: int = -1
var _progreso_visual: float = 0.0
var _tiempo: float = 0.0
var _palancas: Array[float] = []
var _conexiones_visuales: Array[float] = []
var _presiones: Array[float] = []


func _ready() -> void:
	name = "PanelCircuitos"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_velo = ColorRect.new()
	_velo.color = Color(0.04, 0.10, 0.14, 0.73)
	_velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_velo)
	_lienzo = Control.new()
	_lienzo.size = TAMANO_DISENO
	_lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lienzo)
	_arte = ARTE.new()
	_arte.size = TAMANO_DISENO
	_arte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lienzo.add_child(_arte)
	_sonidos = SONIDOS.new()
	_sonidos.name = "SonidosCircuitos"
	add_child(_sonidos)
	resized.connect(_ajustar_presentacion)
	hide()


func abrir(tipo: int, semilla: int) -> void:
	if not TIPOS_DISPONIBLES.has(tipo) or not is_node_ready():
		return
	_foco_anterior = get_viewport().gui_get_focus_owner()
	_tipo = tipo
	var clave := "%d/%d" % [tipo, semilla]
	if _clave_estado != clave:
		_estado = _crear_estado(tipo, semilla)
		_clave_estado = clave
		_senal_emitida = false
	_seleccion_cable = int(_estado.get("seleccion", -1))
	_arrastrando = false
	_usa_raton = false
	_foco_destino = _tipo == Tipo.CABLES and _seleccion_cable >= 0
	_foco_indice = 0
	_entrada_restante = DURACION_ENTRADA
	_fin_restante = 0.0
	_error_restante = 0.0
	_error_indice = -1
	_tiempo = 0.0
	_sincronizar_visuales()
	_crear_controles()
	_abierto = true
	show()
	_ajustar_presentacion()
	_refrescar()
	_sonidos.abrir()


func cerrar() -> void:
	if not _abierto:
		return
	# La solución se confirma antes de cerrar, incluso si se omite su animación.
	if bool(_estado.get("resuelto", false)) and not _senal_emitida:
		_emitir_solucion()
		if not _abierto:
			return
	_abierto = false
	_arrastrando = false
	_entrada_restante = 0.0
	_fin_restante = 0.0
	hide()
	_sonidos.cerrar()
	if is_instance_valid(_foco_anterior) and _foco_anterior.is_visible_in_tree():
		_foco_anterior.grab_focus()
	_foco_anterior = null
	cerrado.emit()


func obtener_estado() -> Dictionary:
	return _estado.duplicate(true)


func _crear_estado(tipo: int, semilla: int) -> Dictionary:
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	var estado := {"resuelto": false}
	match tipo:
		Tipo.INTERRUPTORES:
			estado.interruptores = [false, azar.randf() > 0.5, false, azar.randf() > 0.5, false]
		Tipo.FASES:
			estado.objetivos = []
			estado.fases = []
			estado.velocidades = []
			estado.fijados = [false, false, false]
			for indice: int in range(3):
				estado.objetivos.append(azar.randf_range(0, TAU))
				estado.fases.append(azar.randf_range(0, TAU))
				estado.velocidades.append((0.8 + indice * 0.22) * (1.0 if indice % 2 == 0 else -1.0))
		Tipo.CABLES:
			estado.destinos = [0, 1, 2, 3]
			for indice: int in range(3, 0, -1):
				var otro := azar.randi_range(0, indice)
				var anterior: int = estado.destinos[indice]
				estado.destinos[indice] = estado.destinos[otro]
				estado.destinos[otro] = anterior
			if estado.destinos == [0, 1, 2, 3]:
				estado.destinos = [2, 0, 3, 1]
			estado.conexiones = [-1, -1, -1, -1]
			estado.seleccion = -1
	return estado


func _sincronizar_visuales() -> void:
	_palancas.assign([0.0, 0.0, 0.0, 0.0, 0.0])
	_conexiones_visuales.assign([0.0, 0.0, 0.0, 0.0])
	_presiones.assign([0.0, 0.0, 0.0])
	if _tipo == Tipo.INTERRUPTORES:
		for indice: int in range(5):
			_palancas[indice] = float(_estado.interruptores[indice])
	elif _tipo == Tipo.CABLES:
		for indice: int in range(4):
			_conexiones_visuales[indice] = float(int(_estado.conexiones[indice]) >= 0)
		if _seleccion_cable >= 0:
			_raton = Vector2(225, 45 + _seleccion_cable * 70)
	_progreso_visual = _fraccion_completada()


func _crear_controles() -> void:
	for grupo: Array[Button] in [interruptores, botones_anillos, origenes_cables, destinos_cables]:
		for boton: Button in grupo:
			_lienzo.remove_child(boton)
			boton.queue_free()
		grupo.clear()
	match _tipo:
		Tipo.INTERRUPTORES:
			for indice: int in range(5):
				var boton := _boton(ARTE.rect_interruptor(indice), "Interruptor%d" % (indice + 1), indice)
				boton.toggle_mode = true
				boton.toggled.connect(_cambiar_interruptor.bind(indice))
				interruptores.append(boton)
		Tipo.FASES:
			for indice: int in range(3):
				var boton := _boton(ARTE.rect_fase(indice), "FijarAnillo%d" % (indice + 1), indice)
				boton.pressed.connect(_fijar_anillo.bind(indice))
				botones_anillos.append(boton)
		Tipo.CABLES:
			for indice: int in range(4):
				var origen := _boton(ARTE.rect_origen(indice), "OrigenCable%d" % (indice + 1), indice)
				origen.pressed.connect(_seleccionar_cable.bind(indice))
				origenes_cables.append(origen)
				var destino := _boton(ARTE.rect_destino(indice), "DestinoCable%d" % (indice + 1), indice, true)
				destino.pressed.connect(_conectar_cable.bind(indice))
				destinos_cables.append(destino)
	_actualizar_controles()


func _boton(caja: Rect2, nombre: String, indice: int, destino: bool = false) -> Button:
	var boton := Button.new()
	boton.name = nombre
	boton.position = caja.position
	boton.size = caja.size
	boton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for estilo: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		boton.add_theme_stylebox_override(estilo, StyleBoxEmpty.new())
	boton.focus_entered.connect(_al_enfocar.bind(indice, destino))
	_lienzo.add_child(boton)
	return boton


func _actualizar_controles() -> void:
	var bloqueado: bool = _estado.resuelto or _entrada_restante > 0.0
	for indice: int in range(interruptores.size()):
		interruptores[indice].set_pressed_no_signal(_estado.interruptores[indice])
		interruptores[indice].disabled = bloqueado
	for indice: int in range(botones_anillos.size()):
		botones_anillos[indice].disabled = bloqueado or _estado.fijados[indice]
	for indice: int in range(origenes_cables.size()):
		origenes_cables[indice].disabled = bloqueado or int(_estado.conexiones[indice]) >= 0
		destinos_cables[indice].disabled = bloqueado or _estado.conexiones.has(indice)


func _input(evento: InputEvent) -> void:
	if not _abierto or not is_visible_in_tree() or get_tree().paused:
		return
	if evento.is_action_pressed("ui_cancel") or evento.is_action_pressed("Cancel"):
		get_viewport().set_input_as_handled()
		cerrar()
		return
	if evento is InputEventKey:
		var tecla: int = evento.physical_keycode if evento.physical_keycode != 0 else evento.keycode
		if tecla == KEY_E:
			get_viewport().set_input_as_handled()
			if evento.pressed and not evento.echo and _acepta_entrada():
				_usa_raton = false
				_arrastrando = false
				_activar_foco()
			return
		if evento.pressed and not evento.echo and tecla in [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT]:
			get_viewport().set_input_as_handled()
			if _acepta_entrada():
				_usa_raton = false
				_arrastrando = false
				_navegar(-1 if tecla in [KEY_A, KEY_LEFT] else 1)
			return
	if _tipo != Tipo.CABLES or not _acepta_entrada():
		return
	if evento is InputEventMouseMotion and _seleccion_cable >= 0:
		_usa_raton = true
		_actualizar_raton(evento.position)
		_refrescar()
		if _arrastrando:
			get_viewport().set_input_as_handled()
	elif evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		_procesar_raton(evento)


func _procesar_raton(evento: InputEventMouseButton) -> void:
	_usa_raton = true
	var posicion := _lienzo.get_global_transform_with_canvas().affine_inverse() * evento.position
	_actualizar_raton(evento.position)
	var origen := _indice_boton(origenes_cables, posicion)
	var destino := _indice_boton(destinos_cables, posicion)
	if evento.pressed:
		if origen >= 0 and not origenes_cables[origen].disabled:
			_seleccionar_cable(origen)
			_actualizar_raton(evento.position)
			_arrastrando = true
			_inicio_arrastre = posicion
			get_viewport().set_input_as_handled()
		elif destino >= 0:
			_conectar_cable(destino)
			get_viewport().set_input_as_handled()
	elif _arrastrando:
		_arrastrando = false
		if destino >= 0:
			_conectar_cable(destino)
		elif posicion.distance_to(_inicio_arrastre) > 8.0:
			_rechazar(_seleccion_cable)
		get_viewport().set_input_as_handled()
	_refrescar()


func _indice_boton(botones: Array[Button], posicion: Vector2) -> int:
	for indice: int in range(botones.size()):
		if Rect2(botones[indice].position, botones[indice].size).has_point(posicion):
			return indice
	return -1


func _actualizar_raton(posicion: Vector2) -> void:
	_raton = _lienzo.get_global_transform_with_canvas().affine_inverse() * posicion - ORIGEN_INTERIOR


func _al_enfocar(indice: int, destino: bool) -> void:
	_foco_indice = indice
	_foco_destino = destino
	_refrescar()


func _botones_en_foco() -> Array[Button]:
	match _tipo:
		Tipo.INTERRUPTORES:
			return interruptores
		Tipo.FASES:
			return botones_anillos
		Tipo.CABLES:
			return destinos_cables if _foco_destino else origenes_cables
	return []


func _enfocar_disponible() -> void:
	if not _abierto:
		return
	var botones := _botones_en_foco()
	for paso: int in range(botones.size()):
		var indice := posmod(_foco_indice + paso, botones.size())
		if not botones[indice].disabled:
			botones[indice].grab_focus()
			return


func _navegar(paso: int) -> void:
	var botones := _botones_en_foco()
	for distancia: int in range(1, botones.size() + 1):
		var indice := posmod(_foco_indice + paso * distancia, botones.size())
		if not botones[indice].disabled:
			botones[indice].grab_focus()
			return


func _activar_foco() -> void:
	var botones := _botones_en_foco()
	if botones.is_empty() or botones[_foco_indice].disabled:
		return
	if _tipo == Tipo.INTERRUPTORES:
		botones[_foco_indice].button_pressed = not botones[_foco_indice].button_pressed
	else:
		botones[_foco_indice].pressed.emit()


func _acepta_entrada() -> bool:
	return _abierto and _entrada_restante <= 0.0 and not _estado.resuelto and not get_tree().paused


func _cambiar_interruptor(activado: bool, indice: int) -> void:
	if not _acepta_entrada():
		return
	_estado.interruptores[indice] = activado
	_sonidos.interruptor(activado)
	_foco_indice = indice
	_comprobar_solucion()
	_actualizar_controles()
	_refrescar()


func _fijar_anillo(indice: int) -> void:
	if not _acepta_entrada() or _estado.fijados[indice]:
		return
	_presiones[indice] = 1.0
	_foco_indice = indice
	var distancia := absf(angle_difference(float(_estado.fases[indice]), float(_estado.objetivos[indice])))
	if distancia > 0.4:
		_rechazar(indice)
		return
	_estado.fijados[indice] = true
	_sonidos.fijar_fase()
	_comprobar_solucion()
	_actualizar_controles()
	_refrescar()


func _seleccionar_cable(indice: int) -> void:
	if not _acepta_entrada() or int(_estado.conexiones[indice]) >= 0:
		return
	_seleccion_cable = indice
	_estado.seleccion = indice
	_foco_destino = true
	_foco_indice = 0
	_raton = Vector2(225, 45 + indice * 70)
	_sonidos.tomar_cable()
	_enfocar_disponible()
	_refrescar()


func _conectar_cable(fila: int) -> void:
	if not _acepta_entrada():
		return
	if _seleccion_cable < 0 or _estado.conexiones.has(fila) or int(_estado.destinos[fila]) != _seleccion_cable:
		_rechazar(fila)
		return
	var origen := _seleccion_cable
	_estado.conexiones[origen] = fila
	_conexiones_visuales[origen] = 0.0
	_seleccion_cable = -1
	_estado.seleccion = -1
	_arrastrando = false
	_foco_destino = false
	_foco_indice = (origen + 1) % 4
	_sonidos.conectar_cable()
	_comprobar_solucion()
	_actualizar_controles()
	_enfocar_disponible()
	_refrescar()


func _rechazar(indice: int) -> void:
	_error_indice = indice
	_error_restante = 0.42
	_sonidos.error()
	_refrescar()


func _fraccion_completada() -> float:
	var cantidad := 0
	match _tipo:
		Tipo.INTERRUPTORES:
			for activo: bool in _estado.interruptores:
				cantidad += int(activo)
			return float(cantidad) / 5.0
		Tipo.FASES:
			for fijo: bool in _estado.fijados:
				cantidad += int(fijo)
			return float(cantidad) / 3.0
		Tipo.CABLES:
			for destino: int in _estado.conexiones:
				cantidad += int(destino >= 0)
			return float(cantidad) / 4.0
	return 0.0


func _comprobar_solucion() -> void:
	if _estado.resuelto or _fraccion_completada() < 1.0:
		return
	_estado.resuelto = true
	_fin_restante = DURACION_FIN
	_sonido_fin_emitido = false
	_sonidos.motor_fases(false)


func _emitir_solucion() -> void:
	if _senal_emitida:
		return
	_senal_emitida = true
	_fin_restante = 0.0
	_progreso_visual = 1.0
	_refrescar()
	circuito_resuelto.emit()


func _process(delta: float) -> void:
	if not _abierto or not is_visible_in_tree():
		return
	_tiempo += delta
	var animando := false
	if _entrada_restante > 0.0:
		_entrada_restante = maxf(0.0, _entrada_restante - delta)
		_ajustar_presentacion()
		if _entrada_restante <= 0.0:
			_actualizar_controles()
			_enfocar_disponible()
		animando = true
	if _error_restante > 0.0:
		_error_restante = maxf(0.0, _error_restante - delta)
		animando = true
	for indice: int in range(_presiones.size()):
		if _presiones[indice] > 0.0:
			_presiones[indice] = maxf(0.0, _presiones[indice] - delta * 6.0)
			animando = true
	if _tipo == Tipo.INTERRUPTORES:
		for indice: int in range(5):
			var destino := float(_estado.interruptores[indice])
			if not is_equal_approx(_palancas[indice], destino):
				_palancas[indice] = move_toward(_palancas[indice], destino, delta / 0.22)
				animando = true
	elif _tipo == Tipo.FASES and _entrada_restante <= 0.0:
		for indice: int in range(3):
			if _estado.fijados[indice]:
				_estado.fases[indice] = lerp_angle(_estado.fases[indice], _estado.objetivos[indice], minf(1.0, delta * 18.0))
			else:
				_estado.fases[indice] = fposmod(float(_estado.fases[indice]) + float(_estado.velocidades[indice]) * delta, TAU)
		animando = true
	elif _tipo == Tipo.CABLES:
		for indice: int in range(4):
			if int(_estado.conexiones[indice]) >= 0 and _conexiones_visuales[indice] < 1.0:
				_conexiones_visuales[indice] = minf(1.0, _conexiones_visuales[indice] + delta / 0.22)
				animando = true
	var avance := _fraccion_completada()
	if absf(_progreso_visual - avance) > 0.001:
		_progreso_visual = lerpf(_progreso_visual, avance, minf(1.0, delta * 14.0))
		animando = true
	else:
		_progreso_visual = avance
	_sonidos.motor_fases(_tipo == Tipo.FASES and _entrada_restante <= 0.0 and not _estado.resuelto)
	if _fin_restante > 0.0:
		_fin_restante = maxf(0.0, _fin_restante - delta)
		if not _sonido_fin_emitido and _fin_restante <= 0.68:
			_sonido_fin_emitido = true
			_sonidos.completar()
		if _fin_restante <= 0.0:
			_emitir_solucion()
		animando = true
	if animando:
		_refrescar()


func _refrescar() -> void:
	if _estado.is_empty() or not is_instance_valid(_arte):
		return
	_arte.actualizar(_tipo, _estado, {
		"progreso": _progreso_visual,
		"palancas": _palancas,
		"conexiones": _conexiones_visuales,
		"presiones": _presiones,
		"error_indice": _error_indice,
		"error": _error_restante / 0.42,
		"seleccion": _seleccion_cable if _tipo == Tipo.CABLES else _foco_indice,
		"destino_seleccionado": _foco_indice if _tipo == Tipo.CABLES and _foco_destino else -1,
		"foco_indice": _foco_indice,
		"foco_destino": _foco_destino,
		"cable_arrastrado": _seleccion_cable if _usa_raton else -1,
		"raton": _raton,
		"brillo": clampf(1.0 - _fin_restante / DURACION_FIN, 0.0, 1.0) if _estado.resuelto else 0.0,
		"tiempo": _tiempo
	})


func _ajustar_presentacion() -> void:
	if not is_instance_valid(_lienzo):
		return
	var factor := maxf(0.1, minf(size.x / 1280.0, size.y / 720.0))
	_lienzo.scale = Vector2.ONE * factor
	var origen := (size - TAMANO_DISENO * factor) * 0.5
	var t := clampf(1.0 - _entrada_restante / DURACION_ENTRADA, 0.0, 1.0)
	var avance := t * t * (3.0 - 2.0 * t)
	_lienzo.position = origen + Vector2(0, (1.0 - avance) * (size.y - origen.y + 40.0 * factor))
	_velo.color.a = 0.73 * minf(1.0, t * 3.0)


func _exit_tree() -> void:
	if is_instance_valid(_sonidos):
		_sonidos.detener()
