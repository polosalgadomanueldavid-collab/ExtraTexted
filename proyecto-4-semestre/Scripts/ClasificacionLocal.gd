class_name ClasificacionLocal
extends RefCounted
## Mejores puntajes de cada nombre en esta instalación.

const RUTA_PREDETERMINADA := "user://clasificacion_local.json"
const MAX_CARACTERES_NOMBRE := 24
const VERSION := 1

var _ruta: String
var _jugadores: Dictionary[String, Dictionary] = {}


func _init(ruta: String = RUTA_PREDETERMINADA) -> void:
	_ruta = ruta


static func limpiar_nombre(nombre: String) -> String:
	var texto := nombre.replace("\t", " ").replace("\n", " ").replace("\r", " ").replace("\u00a0", " ")
	return " ".join(texto.strip_escapes().split(" ", false))


func cargar() -> Error:
	var archivo := FileAccess.open(_ruta, FileAccess.READ)
	if archivo == null:
		var error := FileAccess.get_open_error()
		if error == ERR_FILE_NOT_FOUND and not DirAccess.dir_exists_absolute(_ruta):
			_jugadores.clear()
			return OK
		return error

	var texto := archivo.get_as_text()
	var error_lectura := archivo.get_error()
	archivo.close()
	if error_lectura != OK and error_lectura != ERR_FILE_EOF:
		return error_lectura
	var json := JSON.new()
	if json.parse(texto) != OK:
		return ERR_FILE_CORRUPT
	var raiz: Variant = json.data
	if not raiz is Dictionary or raiz.get("version") != VERSION or not raiz.get("jugadores") is Dictionary:
		return ERR_FILE_CORRUPT

	var jugadores: Dictionary[String, Dictionary] = {}
	for clave: String in raiz.jugadores:
		var registro: Variant = raiz.jugadores[clave]
		if not registro is Dictionary or not registro.get("nombre") is String or not registro.get("puntos") is String:
			return ERR_FILE_CORRUPT
		var nombre: String = registro.nombre
		if not _nombre_valido(nombre) or limpiar_nombre(nombre) != nombre or nombre.to_lower() != clave:
			return ERR_FILE_CORRUPT
		var puntos: int = registro.puntos.to_int()
		if puntos < 0 or str(puntos) != registro.puntos:
			return ERR_FILE_CORRUPT
		jugadores[clave] = {"nombre": nombre, "puntos": puntos}

	_jugadores = jugadores
	return OK


func registrar_puntuacion(nombre: String, puntos: int) -> Error:
	nombre = limpiar_nombre(nombre)
	if not _nombre_valido(nombre) or puntos < 0:
		return ERR_INVALID_PARAMETER
	# Recarga para conservar los cambios hechos por otra instancia del menú.
	var error := cargar()
	if error != OK:
		return error

	var clave := nombre.to_lower()
	var anterior: Dictionary = _jugadores.get(clave, {})
	if not anterior.is_empty() and puntos <= anterior.puntos:
		return OK

	var nuevos := _jugadores.duplicate()
	nuevos[clave] = {"nombre": anterior.get("nombre", nombre), "puntos": puntos}
	error = _guardar(nuevos)
	if error == OK:
		_jugadores = nuevos
	return error


func obtener_clasificacion() -> Array[Dictionary]:
	var clasificacion: Array[Dictionary] = []
	for registro: Dictionary in _jugadores.values():
		clasificacion.append(registro.duplicate())
	clasificacion.sort_custom(func(primero: Dictionary, segundo: Dictionary) -> bool:
		if primero.puntos != segundo.puntos:
			return primero.puntos > segundo.puntos
		var orden: int = primero.nombre.nocasecmp_to(segundo.nombre)
		return primero.nombre < segundo.nombre if orden == 0 else orden < 0
	)
	return clasificacion


static func _nombre_valido(nombre: String) -> bool:
	return not nombre.is_empty() and nombre.length() <= MAX_CARACTERES_NOMBRE


func _guardar(jugadores: Dictionary[String, Dictionary]) -> Error:
	var registros := {}
	for clave: String in jugadores:
		var registro := jugadores[clave]
		# JSON leería un número grande como float. El decimal conserva los 64 bits.
		registros[clave] = {"nombre": registro.nombre, "puntos": str(registro.puntos)}

	var temporal := "%s.%d.%d.tmp" % [_ruta, OS.get_process_id(), Time.get_ticks_usec()]
	var archivo := FileAccess.open(temporal, FileAccess.WRITE)
	if archivo == null:
		return FileAccess.get_open_error()
	var escrito := archivo.store_string(JSON.stringify({"version": VERSION, "jugadores": registros}, "\t") + "\n")
	archivo.flush()
	var error := archivo.get_error()
	archivo.close()
	if not escrito and error == OK:
		error = ERR_FILE_CANT_WRITE
	if error == OK:
		error = DirAccess.rename_absolute(temporal, _ruta)
	if error != OK:
		DirAccess.remove_absolute(temporal)
	return error
