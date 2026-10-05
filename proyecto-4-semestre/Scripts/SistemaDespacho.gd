class_name SistemaDespacho
extends Node

signal denuncias_actualizadas(denuncias: Array[Denuncia])
signal calma_actualizada(nueva_calma: int)
signal denuncia_resuelta(denuncia: Denuncia)
signal denuncia_vencida(denuncia: Denuncia)
signal partida_terminada

const CALMA_MAXIMA: int = 100
const CALMA_RECUPERADA_AL_RESOLVER: int = 5

var arbol: ArbolDenunciasAVL = ArbolDenunciasAVL.new()
var calma_operativa: int = CALMA_MAXIMA
var denuncia_activa_id: String = ""
# Guarda cuánto tiempo le queda a cada denuncia pendiente.
var tiempos_restantes: Dictionary = {}


func _process(delta: float) -> void:
	actualizar_tiempos(delta)


func recibir_denuncia(denuncia: Denuncia) -> bool:
	if denuncia == null or denuncia.id.is_empty():
		push_warning("La denuncia no tiene un ID válido.")
		return false

	if arbol.buscar_por_id(denuncia.id) != null:
		push_warning("La denuncia ya se encuentra en el despacho: " + denuncia.id)
		return false

	denuncia.estado = Denuncia.Estado.PENDIENTE
	arbol.insertar(denuncia)
	tiempos_restantes[denuncia.id] = denuncia.tiempo_limite_segundos

	_notificar_cambios()
	return true


func iniciar_denuncia_prioritaria() -> Denuncia:
	if not denuncia_activa_id.is_empty():
		return arbol.buscar_por_id(denuncia_activa_id)

	var denuncia: Denuncia = arbol.obtener_prioritaria()

	if denuncia == null:
		return null

	denuncia.estado = Denuncia.Estado.EN_PROCESO
	denuncia_activa_id = denuncia.id

	_notificar_cambios()
	return denuncia


func obtener_denuncia_activa() -> Denuncia:
	if denuncia_activa_id.is_empty():
		return null

	return arbol.buscar_por_id(denuncia_activa_id)

func resolver_denuncia(id: String) -> bool:
	var denuncia: Denuncia = arbol.buscar_por_id(id)

	if denuncia == null:
		return false

	denuncia.estado = Denuncia.Estado.RESUELTA
	arbol.eliminar_por_id(id)
	tiempos_restantes.erase(id)

	calma_operativa = min(
		CALMA_MAXIMA,
		calma_operativa + CALMA_RECUPERADA_AL_RESOLVER
	)

	denuncia_resuelta.emit(denuncia)
	
	if denuncia_activa_id == id:
		denuncia_activa_id = ""
	
	_notificar_cambios()
	return true


func vencer_denuncia(id: String) -> bool:
	var denuncia: Denuncia = arbol.buscar_por_id(id)

	if denuncia == null:
		return false

	denuncia.estado = Denuncia.Estado.VENCIDA
	arbol.eliminar_por_id(id)
	tiempos_restantes.erase(id)

	calma_operativa = max(
		0,
		calma_operativa - denuncia.penalidad_calma
	)

	denuncia_vencida.emit(denuncia)
	if denuncia_activa_id == id:
		denuncia_activa_id = ""
	
	_notificar_cambios()

	if calma_operativa <= 0:
		partida_terminada.emit()

	return true


func actualizar_tiempos(delta: float) -> void:
	var ids: Array = tiempos_restantes.keys()

	for valor_id: Variant in ids:
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


func _notificar_cambios() -> void:
	denuncias_actualizadas.emit(arbol.recorrido_inorden())
	calma_actualizada.emit(calma_operativa)
