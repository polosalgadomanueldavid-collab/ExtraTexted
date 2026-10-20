extends Node

signal ajustes_cambiados

const ARCHIVO := "user://accesibilidad.cfg"
const BRILLO_MINIMO := 0.8
const BRILLO_MAXIMO := 1.2

var modo: int = 0
var intensidad: float = 1.0
var brillo: float = 1.0

var _pendiente: bool = false
var _temporizador_guardado: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_temporizador_guardado = Timer.new()
	_temporizador_guardado.one_shot = true
	_temporizador_guardado.wait_time = 0.3
	_temporizador_guardado.timeout.connect(guardar)
	add_child(_temporizador_guardado)
	cargar()


func cargar() -> void:
	var config := ConfigFile.new()
	var error := config.load(ARCHIVO)
	if error != OK:
		if error != ERR_FILE_NOT_FOUND:
			push_warning("No se pudieron cargar los ajustes de accesibilidad.")
		return

	var modo_guardado: Variant = config.get_value("accesibilidad", "modo", 0)
	modo = clampi(modo_guardado, 0, 3) if modo_guardado is int else 0
	intensidad = _numero_valido(config.get_value("accesibilidad", "intensidad", 1.0), 0.0, 1.0)
	brillo = _numero_valido(config.get_value("accesibilidad", "brillo", 1.0), BRILLO_MINIMO, BRILLO_MAXIMO)
	ajustes_cambiados.emit()


func establecer_modo(valor: int) -> void:
	valor = clampi(valor, 0, 3)
	if modo == valor:
		return
	modo = valor
	_notificar_cambio()


func establecer_intensidad(valor: float) -> void:
	valor = _numero_valido(valor, 0.0, 1.0)
	if is_equal_approx(intensidad, valor):
		return
	intensidad = valor
	_notificar_cambio()


func establecer_brillo(valor: float) -> void:
	valor = _numero_valido(valor, BRILLO_MINIMO, BRILLO_MAXIMO)
	if is_equal_approx(brillo, valor):
		return
	brillo = valor
	_notificar_cambio()


func restablecer() -> void:
	modo = 0
	intensidad = 1.0
	brillo = 1.0
	_notificar_cambio()
	guardar()


func guardar() -> void:
	if not _pendiente:
		return
	_temporizador_guardado.stop()
	var config := ConfigFile.new()
	config.set_value("accesibilidad", "modo", modo)
	config.set_value("accesibilidad", "intensidad", intensidad)
	config.set_value("accesibilidad", "brillo", brillo)
	if config.save(ARCHIVO) == OK:
		_pendiente = false
	else:
		push_warning("No se pudieron guardar los ajustes de accesibilidad.")


func _notificar_cambio() -> void:
	_pendiente = true
	ajustes_cambiados.emit()
	_temporizador_guardado.start()


func _numero_valido(valor: Variant, minimo: float, maximo: float) -> float:
	if (valor is float or valor is int) and is_finite(float(valor)):
		return clampf(float(valor), minimo, maximo)
	return 1.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		guardar()


func _exit_tree() -> void:
	guardar()
