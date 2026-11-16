extends Node
## Transporte persistente. Ningún RPC acepta rutas o nombres de métodos remotos.
signal sala_actualizada
signal aviso(mensaje: String)
signal respuesta_recibida(numero: int, resultado: Dictionary)
signal tutorial_actualizado

const PUERTO := 7000
const VERSION := "extratexted-lan-3"
const OFICINA := "res://Mundo/Oficina.tscn"
var activa := false
var en_partida := false
var cargando := false
var participantes: Dictionary = {}
var puente: Node
var ultimo_aviso := ""
var tutorial_actual: StringName = &""
var confirmaciones_tutorial: Dictionary = {}
var _alias := ""
var _pausas: Dictionary = {}
var _cargados: Dictionary = {}
var _numero := 0
var _pendientes: Dictionary = {}
var _respuestas: Dictionary = {}
var _ultima_solicitud: Dictionary = {}
var _limite_conexion := 0.0
var _limite_carga := 0.0
var ronda := 0
var _cerrando := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.connected_to_server.connect(_conectado)
	multiplayer.connection_failed.connect(func(): cerrar("No se pudo conectar. Revisa la IP y la red LAN."))
	multiplayer.server_disconnected.connect(func(): cerrar("El anfitrión se desconectó."))
	multiplayer.peer_disconnected.connect(_desconectado)

func es_anfitrion() -> bool:
	return activa and multiplayer.is_server()

func id_local() -> int:
	return multiplayer.get_unique_id() if activa else 1

func crear(alias_jugador: String) -> Error:
	if activa:
		return ERR_ALREADY_IN_USE
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PUERTO, 1)
	if error != OK:
		_notificar("No se pudo abrir el puerto UDP %d: %s" % [PUERTO, error_string(error)])
		return error
	multiplayer.multiplayer_peer = peer
	activa = true
	_alias = _nombre(alias_jugador)
	participantes = {1: {"alias": _alias, "listo": false}}
	ultimo_aviso = "Sala creada. Esperando al compañero."
	sala_actualizada.emit()
	return OK

func unirse(ip: String, alias_jugador: String) -> Error:
	if activa:
		return ERR_ALREADY_IN_USE
	if not ip.strip_edges().is_valid_ip_address():
		_notificar("Escribe una dirección IP válida.")
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(ip.strip_edges(), PUERTO)
	if error != OK:
		_notificar("No se pudo iniciar la conexión: %s" % error_string(error))
		return error
	multiplayer.multiplayer_peer = peer
	activa = true
	_alias = _nombre(alias_jugador)
	_limite_conexion = 10.0
	ultimo_aviso = "Conectando…"
	sala_actualizada.emit()
	return OK

func _nombre(valor: String) -> String:
	var limpio := ClasificacionLocal.limpiar_nombre(valor).left(10)
	return "Policía" if limpio.is_empty() else limpio

func _conectado() -> void:
	_registrar.rpc_id(1, VERSION, _alias)

@rpc("any_peer", "call_remote", "reliable")
func _registrar(version: String, alias_jugador: String) -> void:
	if not es_anfitrion():
		return
	var id := multiplayer.get_remote_sender_id()
	if en_partida or cargando or participantes.size() >= 2 or version != VERSION:
		_rechazar.rpc_id(id, "Sala llena, partida iniciada o versión incompatible.")
		return
	participantes[id] = {"alias": _nombre(alias_jugador), "listo": false}
	_publicar_sala()

@rpc("authority", "call_remote", "reliable")
func _rechazar(motivo: String) -> void:
	cerrar(motivo)

func establecer_listo(listo: bool) -> void:
	if es_anfitrion():
		participantes[1].listo = listo
		_publicar_sala()
	elif activa:
		_listo.rpc_id(1, listo)

@rpc("any_peer", "call_remote", "reliable")
func _listo(valor: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if es_anfitrion() and participantes.has(id) and not en_partida and not cargando:
		participantes[id].listo = valor
		_publicar_sala()

func _publicar_sala() -> void:
	_sala.rpc(participantes)
	sala_actualizada.emit()

@rpc("authority", "call_remote", "reliable")
func _sala(datos: Dictionary) -> void:
	participantes = datos.duplicate(true)
	_limite_conexion = 0.0
	ultimo_aviso = "Conectado. Confirma que estás listo."
	sala_actualizada.emit()

func iniciar() -> void:
	if not es_anfitrion() or participantes.size() != 2 or cargando or en_partida:
		return
	for dato: Dictionary in participantes.values():
		if not dato.listo:
			return
	_cargar.rpc(ronda + 1)

func reiniciar() -> void:
	if es_anfitrion() and en_partida:
		_cargar.rpc(ronda + 1)

@rpc("authority", "call_local", "reliable")
func _cargar(nueva_ronda: int) -> void:
	if is_instance_valid(puente):
		puente.preparar_salida()
	MenuGlobal.omitir_tutorial_siguiente_partida = ronda > 0 or MenuGlobal.omitir_tutorial_siguiente_partida
	ronda = nueva_ronda
	puente = null
	en_partida = false
	cargando = true
	_limite_carga = Time.get_ticks_msec() / 1000.0 + 60.0
	_cargados.clear()
	_pausas.clear()
	tutorial_actual = &""
	confirmaciones_tutorial.clear()
	_respuestas.clear()
	_ultima_solicitud.clear()
	_cancelar_pendientes()
	MenuGlobal.nombre_partida = str(participantes.get(id_local(), {}).get("alias", _alias))
	MenuGlobal.final_de_partida_activo = false
	get_tree().paused = false
	_cambiar_a_oficina.call_deferred()

func _cambiar_a_oficina() -> void:
	CargaEscenas.cargar(OFICINA)

func oficina_lista(nuevo_puente: Node) -> void:
	puente = nuevo_puente
	get_tree().paused = true
	if es_anfitrion():
		_marcar_cargado(1)
	else:
		_cargado.rpc_id(1, ronda)

@rpc("any_peer", "call_remote", "reliable")
func _cargado(ronda_cliente: int) -> void:
	if es_anfitrion() and cargando and ronda_cliente == ronda:
		_marcar_cargado(multiplayer.get_remote_sender_id())

func _marcar_cargado(id: int) -> void:
	if not participantes.has(id):
		return
	_cargados[id] = true
	if _cargados.size() == 2 and is_instance_valid(puente):
		_comenzar.rpc()

@rpc("authority", "call_local", "reliable")
func _comenzar() -> void:
	cargando = false
	_limite_carga = 0.0
	en_partida = true
	get_tree().paused = not _pausas.is_empty()
	CargaEscenas.finalizar_espera()
	puente.comenzar()
	MenuGlobal._abrir_tutorial_inicial.call_deferred()

func pedir_pausa(valor: bool) -> void:
	if not activa:
		get_tree().paused = valor
		return
	if es_anfitrion():
		_guardar_pausa(1, valor)
	else:
		_pausa.rpc_id(1, valor)

@rpc("any_peer", "call_remote", "reliable")
func _pausa(valor: bool) -> void:
	if es_anfitrion():
		_guardar_pausa(multiplayer.get_remote_sender_id(), valor)

func _guardar_pausa(id: int, valor: bool) -> void:
	if not participantes.has(id):
		return
	if valor:
		_pausas[id] = true
	else:
		_pausas.erase(id)
	_pausa_confirmada.rpc(_pausas)

@rpc("authority", "call_local", "reliable")
func _pausa_confirmada(datos: Dictionary) -> void:
	_pausas = datos.duplicate()
	get_tree().paused = cargando or not datos.is_empty() or MenuGlobal.final_de_partida_activo

func iniciar_tutorial(tutorial: StringName) -> void:
	if not es_anfitrion() or not en_partida or tutorial == &"" or tutorial == tutorial_actual:
		return
	_estado_tutorial.rpc(ronda, tutorial, {})

func confirmar_tutorial(tutorial: StringName) -> void:
	if not en_partida or tutorial != tutorial_actual or confirmaciones_tutorial.has(id_local()):
		return
	if es_anfitrion():
		_guardar_confirmacion_tutorial(1, tutorial)
	else:
		_confirmar_tutorial.rpc_id(1, ronda, tutorial)

@rpc("any_peer", "call_remote", "reliable")
func _confirmar_tutorial(ronda_cliente: int, tutorial: StringName) -> void:
	if es_anfitrion() and ronda_cliente == ronda:
		_guardar_confirmacion_tutorial(multiplayer.get_remote_sender_id(), tutorial)

func _guardar_confirmacion_tutorial(id: int, tutorial: StringName) -> void:
	if not en_partida or not participantes.has(id) or tutorial == &"" or tutorial != tutorial_actual or confirmaciones_tutorial.has(id):
		return
	var confirmaciones := confirmaciones_tutorial.duplicate()
	confirmaciones[id] = true
	_estado_tutorial.rpc(ronda, tutorial, confirmaciones)

@rpc("authority", "call_local", "reliable")
func _estado_tutorial(ronda_servidor: int, tutorial: StringName, confirmaciones: Dictionary) -> void:
	if not en_partida or ronda_servidor != ronda:
		return
	tutorial_actual = tutorial
	confirmaciones_tutorial = confirmaciones.duplicate()
	tutorial_actualizado.emit()

func solicitar(tipo: String, datos: Dictionary = {}, al_terminar: Callable = Callable()) -> void:
	if not en_partida or not is_instance_valid(puente):
		if al_terminar.is_valid():
			al_terminar.call_deferred({"ok": false, "mensaje": "La partida no está lista."})
		return
	_numero += 1
	if al_terminar.is_valid():
		_pendientes[_numero] = al_terminar
	if es_anfitrion():
		_ejecutar(1, _numero, tipo, datos)
	else:
		_accion.rpc_id(1, ronda, _numero, tipo, datos)

@rpc("any_peer", "call_remote", "reliable", 0)
func _accion(ronda_cliente: int, numero: int, tipo: String, datos: Dictionary) -> void:
	if es_anfitrion() and ronda_cliente == ronda:
		_ejecutar(multiplayer.get_remote_sender_id(), numero, tipo, datos)

func _ejecutar(id: int, numero: int, tipo: String, datos: Dictionary) -> void:
	if not participantes.has(id) or not is_instance_valid(puente):
		return
	var clave := "%d:%d" % [id, numero]
	var resultado: Dictionary
	if _respuestas.has(clave):
		resultado = _respuestas[clave]
	else:
		if numero <= int(_ultima_solicitud.get(id, 0)):
			return
		_ultima_solicitud[id] = numero
		resultado = puente.procesar(id, tipo, datos)
		_respuestas[clave] = resultado
		if _respuestas.size() > 1024:
			_respuestas.erase(_respuestas.keys()[0])
		puente.publicar()
	if id == 1:
		_resultado.call_deferred(numero, resultado)
	else:
		_resultado.rpc_id(id, numero, resultado)

@rpc("authority", "call_remote", "reliable", 0)
func _resultado(numero: int, resultado: Dictionary) -> void:
	if not activa:
		return
	var callback: Callable = _pendientes.get(numero, Callable())
	_pendientes.erase(numero)
	if callback.is_valid():
		callback.call(resultado)
	respuesta_recibida.emit(numero, resultado)
	if not resultado.get("ok", false) and is_instance_valid(puente):
		puente.mensaje(str(resultado.get("mensaje", "Acción no disponible.")))

func publicar(datos: Dictionary) -> void:
	if es_anfitrion() and en_partida:
		_estado.rpc(ronda, datos)

@rpc("authority", "call_remote", "reliable", 2)
func _estado(ronda_servidor: int, datos: Dictionary) -> void:
	if ronda_servidor == ronda and is_instance_valid(puente):
		puente.recibir_estado(datos)

func enviar_movimiento(datos: Dictionary) -> void:
	if not en_partida:
		return
	if es_anfitrion():
		_movimiento_confirmado.rpc(1, datos)
	else:
		_movimiento.rpc_id(1, ronda, datos)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _movimiento(ronda_cliente: int, datos: Dictionary) -> void:
	if not es_anfitrion() or ronda_cliente != ronda or not en_partida or not is_instance_valid(puente):
		return
	var id := multiplayer.get_remote_sender_id()
	if puente.recibir_movimiento(id, datos, true):
		_movimiento_confirmado.rpc(id, datos)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _movimiento_confirmado(id: int, datos: Dictionary) -> void:
	if is_instance_valid(puente) and id != id_local():
		puente.recibir_movimiento(id, datos, false)

func difundir(tipo: String, datos: Dictionary) -> void:
	if es_anfitrion():
		_evento.rpc(ronda, tipo, datos)

@rpc("authority", "call_local", "reliable", 0)
func _evento(ronda_servidor: int, tipo: String, datos: Dictionary) -> void:
	if ronda_servidor == ronda and is_instance_valid(puente):
		puente.aplicar_evento(tipo, datos)

func _desconectado(id: int) -> void:
	if not activa or not participantes.has(id):
		return
	if en_partida or cargando:
		cerrar("El compañero se desconectó. La sesión ha terminado.")
	else:
		participantes.erase(id)
		if es_anfitrion():
			_publicar_sala()

func cerrar(motivo: String = "") -> void:
	if _cerrando:
		return
	_cerrando = true
	if is_instance_valid(puente):
		puente.preparar_salida()
	var volver := en_partida or cargando
	ronda = 0
	activa = false
	en_partida = false
	cargando = false
	puente = null
	_limite_conexion = 0.0
	_limite_carga = 0.0
	participantes.clear()
	_pausas.clear()
	tutorial_actual = &""
	confirmaciones_tutorial.clear()
	_cargados.clear()
	_respuestas.clear()
	_cancelar_pendientes()
	get_tree().paused = false
	_notificar(motivo)
	sala_actualizada.emit()
	_cerrar_transporte.call_deferred(volver)

func _cerrar_transporte(volver: bool) -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_cerrando = false
	if volver:
		MenuGlobal._cambiando_escena = false
		MenuGlobal.volver_al_menu()

func _cancelar_pendientes() -> void:
	# Las vistas de la ronda se destruyen; no ejecutar callbacks que las capturan.
	_pendientes.clear()

func _notificar(texto: String) -> void:
	ultimo_aviso = texto
	aviso.emit(texto)

func _process(delta: float) -> void:
	if _limite_conexion > 0.0:
		_limite_conexion -= delta
		if _limite_conexion <= 0.0:
			cerrar("La conexión agotó el tiempo de espera.")
	if _limite_carga > 0.0:
		if Time.get_ticks_msec() / 1000.0 >= _limite_carga:
			cerrar("El compañero no terminó de cargar la oficina.")


func confirmar_finales(numero: int) -> void:
	_acuse_finales.rpc_id(1, ronda, numero)

@rpc("any_peer", "call_remote", "reliable", 2)
func _acuse_finales(ronda_cliente: int, numero: int) -> void:
	if es_anfitrion() and ronda_cliente == ronda and participantes.has(multiplayer.get_remote_sender_id()) and is_instance_valid(puente):
		puente.confirmar_finales(numero)

func pedir_estado_completo() -> void:
	_pedir_estado_completo.rpc_id(1, ronda)

@rpc("any_peer", "call_remote", "reliable", 2)
func _pedir_estado_completo(ronda_cliente: int) -> void:
	if es_anfitrion() and ronda_cliente == ronda and participantes.has(multiplayer.get_remote_sender_id()) and is_instance_valid(puente):
		puente._estado_enviado.clear()
