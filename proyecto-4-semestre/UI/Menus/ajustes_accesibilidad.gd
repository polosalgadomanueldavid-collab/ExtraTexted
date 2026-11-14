extends Node

signal ajustes_cambiados

const ARCHIVO := "user://accesibilidad.cfg"
const BRILLO_MINIMO := 0.8
const BRILLO_MAXIMO := 1.2
const BUS_GENERAL: StringName = &"Master"
const BUS_MUSICA: StringName = &"Musica"
const BUS_INTERACCIONES: StringName = &"Interacciones"

var modo: int = 0
var intensidad: float = 1.0
var brillo: float = 1.0
var balanceo_camara: bool = true
var volumen_general: float = 1.0
var volumen_musica: float = 1.0
var volumen_interacciones: float = 1.0

var _pendiente: bool = false
var _temporizador_guardado: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_temporizador_guardado = Timer.new()
	_temporizador_guardado.one_shot = true
	_temporizador_guardado.wait_time = 0.3
	_temporizador_guardado.timeout.connect(guardar)
	add_child(_temporizador_guardado)
	_asegurar_bus_audio(BUS_MUSICA)
	_asegurar_bus_audio(BUS_INTERACCIONES)
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
	var balanceo_guardado: Variant = config.get_value("accesibilidad", "balanceo_camara", true)
	balanceo_camara = balanceo_guardado if balanceo_guardado is bool else true
	volumen_general = _numero_valido(config.get_value("audio", "general", 1.0), 0.0, 1.0)
	volumen_musica = _numero_valido(config.get_value("audio", "musica", 1.0), 0.0, 1.0)
	volumen_interacciones = _numero_valido(config.get_value("audio", "interacciones", 1.0), 0.0, 1.0)
	_aplicar_volumenes_audio()
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


func establecer_balanceo_camara(valor: bool) -> void:
	if balanceo_camara == valor:
		return
	balanceo_camara = valor
	_notificar_cambio()


func establecer_volumen_general(valor: float) -> void:
	valor = _numero_valido(valor, 0.0, 1.0)
	if is_equal_approx(volumen_general, valor):
		return
	volumen_general = valor
	_aplicar_volumenes_audio()
	_notificar_cambio()


func establecer_volumen_musica(valor: float) -> void:
	valor = clampf(valor, 0.0, 1.0)
	if is_equal_approx(volumen_musica, valor):
		return
	volumen_musica = valor
	_aplicar_volumenes_audio()
	_notificar_cambio()


func establecer_volumen_interacciones(valor: float) -> void:
	valor = clampf(valor, 0.0, 1.0)
	if is_equal_approx(volumen_interacciones, valor):
		return
	volumen_interacciones = valor
	_aplicar_volumenes_audio()
	_notificar_cambio()


func restablecer() -> void:
	modo = 0
	intensidad = 1.0
	brillo = 1.0
	balanceo_camara = true
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
	config.set_value("accesibilidad", "balanceo_camara", balanceo_camara)
	config.set_value("audio", "general", volumen_general)
	config.set_value("audio", "musica", volumen_musica)
	config.set_value("audio", "interacciones", volumen_interacciones)
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


func _asegurar_bus_audio(nombre: StringName) -> int:
	var indice := AudioServer.get_bus_index(nombre)
	if indice >= 0:
		return indice
	indice = AudioServer.bus_count
	AudioServer.add_bus(indice)
	AudioServer.set_bus_name(indice, String(nombre))
	AudioServer.set_bus_send(indice, &"Master")
	return indice


func _aplicar_volumenes_audio() -> void:
	_aplicar_volumen_bus(BUS_GENERAL, volumen_general)
	_aplicar_volumen_bus(BUS_MUSICA, volumen_musica)
	_aplicar_volumen_bus(BUS_INTERACCIONES, volumen_interacciones)


func _aplicar_volumen_bus(nombre: StringName, valor: float) -> void:
	var indice := AudioServer.get_bus_index(nombre)
	if indice < 0:
		return
	AudioServer.set_bus_mute(indice, valor <= 0.001)
	AudioServer.set_bus_volume_db(indice, linear_to_db(maxf(valor, 0.0001)))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		guardar()


func _exit_tree() -> void:
	guardar()
