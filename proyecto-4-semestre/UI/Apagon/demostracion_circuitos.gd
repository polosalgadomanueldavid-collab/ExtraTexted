extends Control
## Reproducción visual del tutorial. Sus estados son independientes de la partida.

signal circuito_cambiado(tipo: int)

const ARTE := preload("res://UI/Apagon/arte_circuitos.gd")
const TIPOS := [ARTE.CABLES, ARTE.FASES, ARTE.INTERRUPTORES]
const DURACION_CIRCUITO := 8.0
const AREA_ARTE := Rect2(-42, -12, 916, 540)
const DESTINOS_CABLE := [2, 0, 3, 1]
const OBJETIVOS_FASE := [-PI / 3.0, -PI / 2.0, PI / 5.0]

var tipo_actual: int = ARTE.CABLES
var _arte: Control
var _indice := 0
var _tiempo := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_arte = ARTE.new()
	add_child(_arte)
	resized.connect(_ajustar_arte)
	visibility_changed.connect(_al_cambiar_visibilidad)
	_ajustar_arte()
	_al_cambiar_visibilidad()


func reiniciar() -> void:
	_indice = 0
	_tiempo = 0.0
	tipo_actual = TIPOS[_indice]
	if is_instance_valid(_arte):
		_actualizar_demostracion()
	circuito_cambiado.emit(tipo_actual)


func _al_cambiar_visibilidad() -> void:
	set_process(is_visible_in_tree())
	if is_visible_in_tree():
		reiniciar()


func _process(delta: float) -> void:
	_tiempo += delta
	if _tiempo >= DURACION_CIRCUITO:
		_tiempo = fmod(_tiempo, DURACION_CIRCUITO)
		_indice = (_indice + 1) % TIPOS.size()
		tipo_actual = TIPOS[_indice]
		circuito_cambiado.emit(tipo_actual)
	_actualizar_demostracion()


func _ajustar_arte() -> void:
	var factor := maxf(0.001, minf(size.x / AREA_ARTE.size.x, size.y / AREA_ARTE.size.y))
	_arte.scale = Vector2.ONE * factor
	_arte.position = (size - AREA_ARTE.size * factor) * 0.5 - AREA_ARTE.position * factor


func _actualizar_demostracion() -> void:
	match tipo_actual:
		ARTE.CABLES:
			_demostrar_cables()
		ARTE.FASES:
			_demostrar_fases()
		ARTE.INTERRUPTORES:
			_demostrar_interruptores()


func _demostrar_cables() -> void:
	var conexiones := [-1, -1, -1, -1]
	var visual := {
		"conexiones": [1.0, 1.0, 1.0, 1.0],
		"seleccion": -1,
		"cable_arrastrado": -1,
		"progreso": 0.0,
	}
	var completados := 0
	for indice: int in range(4):
		var transcurrido := _tiempo - (0.8 + indice * 1.4)
		var destino := DESTINOS_CABLE.find(indice)
		if transcurrido >= 1.1:
			conexiones[indice] = destino
			completados += 1
		elif transcurrido >= 0.0:
			var inicio := Vector2(144, ARTE.ALTURAS_CABLE[indice])
			var fin := Vector2(594, ARTE.ALTURAS_CABLE[destino])
			var avance := smoothstep(0.0, 0.95, transcurrido)
			visual.seleccion = indice
			visual.cable_arrastrado = indice
			visual.raton = inicio.lerp(fin, avance)
	visual.progreso = float(completados) / 4.0
	visual.brillo = 0.3 if completados == 4 else 0.0
	_arte.actualizar(tipo_actual, {
		"destinos": DESTINOS_CABLE,
		"conexiones": conexiones,
	}, visual)


func _demostrar_fases() -> void:
	var fases: Array[float] = []
	var fijados: Array[bool] = []
	var presiones: Array[float] = []
	var completados := 0
	var seleccion := -1
	for indice: int in range(3):
		var momento_fijar := 2.2 + indice * 1.6
		var fijado := _tiempo >= momento_fijar
		var velocidad := 2.2 if indice % 2 == 0 else -2.2
		var angulo := float(OBJETIVOS_FASE[indice])
		if not fijado:
			angulo -= (momento_fijar - _tiempo) * velocidad
			if seleccion < 0:
				seleccion = indice
		else:
			completados += 1
		fases.append(angulo)
		fijados.append(fijado)
		presiones.append(clampf(1.0 - (_tiempo - momento_fijar) / 0.3, 0.0, 1.0) if fijado else 0.0)
	_arte.actualizar(tipo_actual, {
		"objetivos": OBJETIVOS_FASE,
		"fases": fases,
		"fijados": fijados,
	}, {
		"presiones": presiones,
		"seleccion": seleccion,
		"progreso": float(completados) / 3.0,
		"brillo": 0.3 if completados == 3 else 0.0,
	})


func _demostrar_interruptores() -> void:
	var interruptores: Array[bool] = []
	var palancas: Array[float] = []
	var completados := 0
	var seleccion := -1
	for indice: int in range(5):
		var transcurrido := _tiempo - (0.8 + indice * 0.95)
		var activo := transcurrido >= 0.28
		interruptores.append(activo)
		palancas.append(smoothstep(0.0, 0.28, transcurrido))
		if activo:
			completados += 1
		elif seleccion < 0:
			seleccion = indice
	_arte.actualizar(tipo_actual, {"interruptores": interruptores}, {
		"palancas": palancas,
		"seleccion": seleccion,
		"progreso": float(completados) / 5.0,
		"brillo": 0.3 if completados == 5 else 0.0,
	})
