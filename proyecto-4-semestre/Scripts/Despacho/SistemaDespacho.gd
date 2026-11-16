class_name SistemaDespacho
extends Node

signal denuncias_actualizadas(denuncias: Array[Denuncia])
signal calma_actualizada(nueva_calma: int)
signal denuncia_resuelta(denuncia: Denuncia)
signal denuncia_vencida(denuncia: Denuncia)
signal partida_terminada
signal estacion_completada(denuncia: Denuncia, estacion_id: String)
signal estacion_incorrecta(denuncia: Denuncia, estacion_usada: String)
signal cordura_jugador_actualizada(jugador_id: int, valor: int)
signal jugador_eliminado(jugador_id: int)
signal estado_compartido_actualizado

const CALMA_MAXIMA: int = 100
const CALMA_RECUPERADA_AL_RESOLVER: int = 5

var arbol: ArbolDenunciasAVL = ArbolDenunciasAVL.new()
var puntuacion: SistemaPuntuacion = SistemaPuntuacion.new()
var jugador_local_id: int = 1
var jugadores: Dictionary = {1: {"cordura": 100, "eliminado": false}}
var casos_en_proceso: Dictionary = {}
var participantes: Dictionary = {}
## Totales del turno. Solo la autoridad suma; el cliente recibe la misma copia.
var aportes_jugadores: Dictionary = {1: {"misiones": 0, "tareas": 0}}
var ultimos_portadores: Dictionary = {}
var casos_por_jugador: Dictionary = {}
var max_casos_en_proceso: int = 1
var autoridad: bool = true
var solicitar_cambio: Callable
var calma_operativa: int:
	get:
		return obtener_cordura(jugador_local_id)
	set(valor):
		if jugadores.has(jugador_local_id):
			jugadores[jugador_local_id].cordura = clampi(valor, 0, CALMA_MAXIMA)
var causa_agotamiento: StringName = &""
var terminada: bool = false
var tiempo_detenido := false
var denuncia_activa_id: String:
	get:
		return str(casos_por_jugador.get(jugador_local_id, ""))
	set(valor):
		casos_por_jugador[jugador_local_id] = valor
# Guarda cuánto tiempo le queda a cada denuncia pendiente.
var tiempos_restantes: Dictionary = {}


func _process(delta: float) -> void:
	if autoridad:
		actualizar_tiempos(delta)


func recibir_denuncia(denuncia: Denuncia) -> bool:
	if terminada:
		return false
	if denuncia == null or denuncia.id.is_empty():
		push_warning("La denuncia no tiene un ID válido.")
		return false

	if arbol.buscar_por_id(denuncia.id) != null:
		push_warning("La denuncia ya se encuentra en el despacho: " + denuncia.id)
		return false

	denuncia.estado = Denuncia.Estado.PENDIENTE
	denuncia.estaciones_completadas.clear()
	arbol.insertar(denuncia)
	tiempos_restantes[denuncia.id] = denuncia.tiempo_limite_segundos

	_notificar_cambios()
	return true


func iniciar_denuncia_prioritaria(jugador_id: int = 0) -> Denuncia:
	jugador_id = jugador_local_id if jugador_id == 0 else jugador_id
	if terminada or not esta_activo(jugador_id):
		return null
	var actual: String = str(casos_por_jugador.get(jugador_id, ""))
	if not actual.is_empty():
		return arbol.buscar_por_id(actual)
	if casos_en_proceso.size() >= max_casos_en_proceso:
		return null
	var denuncia: Denuncia = null
	for candidata: Denuncia in arbol.recorrido_inorden():
		if candidata.estado == Denuncia.Estado.PENDIENTE:
			denuncia = candidata
			break

	if denuncia == null:
		return null

	denuncia.estado = Denuncia.Estado.EN_PROCESO
	casos_en_proceso[denuncia.id] = true
	establecer_portador(denuncia.id, jugador_id)

	_notificar_cambios()
	return denuncia


func obtener_denuncia_activa() -> Denuncia:
	if denuncia_activa_id.is_empty():
		return null

	return arbol.buscar_por_id(denuncia_activa_id)

func resolver_denuncia(id: String) -> bool:
	if terminada:
		return false
	var denuncia: Denuncia = arbol.buscar_por_id(id)

	if denuncia == null:
		return false

	denuncia.estado = Denuncia.Estado.RESUELTA
	arbol.eliminar_por_id(id)
	tiempos_restantes.erase(id)

	for id_jugador: int in responsables(id):
		recuperar_calma(CALMA_RECUPERADA_AL_RESOLVER, id_jugador)

	# El saldo ya está actualizado cuando el HUD recibe la resolución.
	puntuacion.registrar_resolucion(denuncia)
	if autoridad:
		# Una misión compartida cuenta para quienes completaron una estación,
		# nunca para alguien que solo llevó la hoja o recibió la recompensa.
		for id_jugador: int in participantes.get(id, []):
			if aportes_jugadores.has(id_jugador):
				aportes_jugadores[id_jugador].misiones += 1
	denuncia_resuelta.emit(denuncia)
	
	_limpiar_caso(id)
	
	_notificar_cambios()
	return true


func vencer_denuncia(id: String, motivo := Denuncia.MotivoPerdida.TIEMPO) -> bool:
	if terminada:
		return false
	var denuncia: Denuncia = arbol.buscar_por_id(id)

	if denuncia == null:
		return false

	denuncia.estado = Denuncia.Estado.VENCIDA
	denuncia.motivo_perdida = motivo
	arbol.eliminar_por_id(id)
	tiempos_restantes.erase(id)

	# Aplicar todo el resultado antes de emitir el final de equipo.
	for id_jugador: int in responsables(id):
		_cambiar_cordura(id_jugador, -denuncia.penalidad_calma)

	denuncia_vencida.emit(denuncia)
	_limpiar_caso(id)
	
	_notificar_cambios()

	_comprobar_final()

	return true


func actualizar_tiempos(delta: float) -> void:
	if terminada or tiempo_detenido:
		return
	var ids: Array = tiempos_restantes.keys()

	for valor_id: Variant in ids:
		if terminada:
			break
		var id: String = str(valor_id)
		tiempos_restantes[id] = float(tiempos_restantes[id]) - delta

		if tiempos_restantes[id] <= 0.0:
			vencer_denuncia(id)


func obtener_tiempo_restante(id: String) -> float:
	return float(tiempos_restantes.get(id, 0.0))


func obtener_denuncia_prioritaria() -> Denuncia:
	return arbol.obtener_prioritaria()


func obtener_denuncias_ordenadas() -> Array[Denuncia]:
	return arbol.recorrido_inorden()


func perder_calma(cantidad: int, causa: StringName = &"", jugador_id: int = 0) -> int:
	jugador_id = jugador_local_id if jugador_id == 0 else jugador_id
	if not autoridad and solicitar_cambio.is_valid():
		solicitar_cambio.call("cordura", {"cantidad": -cantidad, "causa": str(causa)})
		return 0
	if terminada or cantidad <= 0 or not esta_activo(jugador_id):
		return 0
	var perdida := mini(cantidad, obtener_cordura(jugador_id))
	causa_agotamiento = causa
	_cambiar_cordura(jugador_id, -perdida)
	_comprobar_final()
	return perdida


func recuperar_calma(cantidad: int, jugador_id: int = 0) -> int:
	jugador_id = jugador_local_id if jugador_id == 0 else jugador_id
	if not autoridad and solicitar_cambio.is_valid():
		solicitar_cambio.call("cordura", {"cantidad": cantidad})
		return 0
	# Descansar o beber no puede reactivar una partida que llegó a cero de calma.
	if terminada or cantidad <= 0 or not esta_activo(jugador_id):
		return 0
	var recuperada := mini(cantidad, CALMA_MAXIMA - obtener_cordura(jugador_id))
	_cambiar_cordura(jugador_id, recuperada)
	return recuperada


func _notificar_cambios() -> void:
	denuncias_actualizadas.emit(arbol.recorrido_inorden())
	calma_actualizada.emit(calma_operativa)
	estado_compartido_actualizado.emit()

func interactuar_estacion(estacion_id: String, caso_id: String = "", jugador_id: int = 0) -> bool:
	jugador_id = jugador_local_id if jugador_id == 0 else jugador_id
	if terminada or not esta_activo(jugador_id):
		return false
	if caso_id.is_empty():
		caso_id = str(casos_por_jugador.get(jugador_id, ""))
	var denuncia: Denuncia = arbol.buscar_por_id(caso_id)

	if denuncia == null:
		return false

	if not denuncia.completar_estacion(estacion_id):
		estacion_incorrecta.emit(denuncia, estacion_id)
		return false
	if not participantes.has(caso_id):
		participantes[caso_id] = []
	if not participantes[caso_id].has(jugador_id):
		participantes[caso_id].append(jugador_id)
	if autoridad and aportes_jugadores.has(jugador_id):
		aportes_jugadores[jugador_id].tareas += 1

	estacion_completada.emit(denuncia, estacion_id)

	# Cualquier estación puede ser la última: cerrar cuando no quede ninguna pendiente.
	if denuncia.obtener_estaciones_pendientes().is_empty():
		resolver_denuncia(denuncia.id)

	return true


func configurar_jugadores(ids: Array, local_id: int) -> void:
	jugadores.clear()
	aportes_jugadores.clear()
	for id: int in ids:
		jugadores[id] = {"cordura": 100, "eliminado": false}
		aportes_jugadores[id] = {"misiones": 0, "tareas": 0}
	jugador_local_id = local_id
	max_casos_en_proceso = mini(2, ids.size())


func obtener_resumen_equipo(identidades: Dictionary) -> Array[Dictionary]:
	var resumen: Array[Dictionary] = []
	var ids := aportes_jugadores.keys()
	ids.sort()
	for id: int in ids:
		var aporte: Dictionary = aportes_jugadores[id]
		resumen.append({
			"id": id,
			"nombre": str(identidades.get(id, {}).get("alias", "Policía")),
			"misiones": int(aporte.misiones),
			"tareas": int(aporte.tareas)
		})
	return resumen


func obtener_cordura(id: int) -> int:
	return int(jugadores.get(id, {}).get("cordura", 0))


func esta_activo(id: int) -> bool:
	return jugadores.has(id) and not jugadores[id].eliminado and obtener_cordura(id) > 0


func establecer_portador(caso: String, id: int) -> void:
	for otro: int in casos_por_jugador.keys():
		if casos_por_jugador[otro] == caso:
			casos_por_jugador.erase(otro)
	if id != 0:
		casos_por_jugador[id] = caso
		ultimos_portadores[caso] = id


func responsables(caso: String) -> Array:
	var lista: Array = participantes.get(caso, [])
	if not lista.is_empty():
		return lista.duplicate()
	if ultimos_portadores.has(caso):
		return [ultimos_portadores[caso]]
	return jugadores.keys()


func _limpiar_caso(id: String) -> void:
	casos_en_proceso.erase(id)
	establecer_portador(id, 0)
	participantes.erase(id)
	ultimos_portadores.erase(id)


func _cambiar_cordura(id: int, cambio: int) -> void:
	if not esta_activo(id):
		return
	jugadores[id].cordura = clampi(obtener_cordura(id) + cambio, 0, CALMA_MAXIMA)
	if jugadores[id].cordura == 0:
		jugadores[id].eliminado = true
		jugador_eliminado.emit(id)
	cordura_jugador_actualizada.emit(id, obtener_cordura(id))
	calma_actualizada.emit(calma_operativa)
	estado_compartido_actualizado.emit()


func _comprobar_final() -> void:
	if terminada:
		return
	for id: int in jugadores:
		if esta_activo(id):
			return
	terminada = true
	partida_terminada.emit()
