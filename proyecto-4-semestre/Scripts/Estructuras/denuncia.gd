class_name Denuncia
extends Resource

enum Estado {
	PENDIENTE,
	EN_PROCESO,
	RESUELTA,
	VENCIDA
}

@export_group("Identificación")
@export var id: String = ""
@export var titulo: String = ""
@export_multiline var descripcion_despacho: String = ""

@export_group("Prioridad")
@export_range(1, 5, 1) var nivel_riesgo: int = 1
@export var hora_reporte: int = 0

@export_group("Partida")
@export var tiempo_limite_segundos: float = 110.0
@export var penalidad_calma: int = 4
@export var puntaje_recompensa: int = 20
@export var protocolo_estaciones: Array[String] = []

var estado: Estado = Estado.PENDIENTE
var indice_estacion_actual: int = 0

func va_antes_que(otra: Denuncia) -> bool:
	# 1. Mayor riesgo = más urgente.
	if nivel_riesgo != otra.nivel_riesgo:
		return nivel_riesgo > otra.nivel_riesgo

	# 2. Con igual riesgo, se atiende primero quien reportó antes.
	if hora_reporte != otra.hora_reporte:
		return hora_reporte < otra.hora_reporte

	# 3. El ID solo rompe empates exactos.
	return id < otra.id
