extends Node

## Piloto de regresión: comprueba que cada protocolo tenga una estación real,
## una celda navegable de destino y que el indicador se pueda construir.

const INDICADOR_SCRIPT: Script = preload("res://Scripts/indicador_proxima_estacion.gd")
const CASOS: Array[Denuncia] = [
	preload("res://Casos/Despacho/denuncia_uso_excesivo.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_enlace_sospechoso.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_suplantacion.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_acoso_persistente.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_amenaza_critica.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_phishing_repetido.tres") as Denuncia
]


func _ready() -> void:
	var errores: Array[String] = []
	var oficina := preload("res://Oficina.tscn").instantiate()
	add_child(oficina)
	await get_tree().physics_frame

	var estaciones: Dictionary = {}
	for nodo: Node in oficina.find_children("*", "Estacion", true, false):
		var estacion := nodo as Estacion
		estaciones[estacion.estacion_id] = estacion

	for caso: Denuncia in CASOS:
		for estacion_id: String in caso.protocolo_estaciones:
			if not estaciones.has(estacion_id):
				errores.append("%s referencia una estación ausente: %s" % [caso.id, estacion_id])
			if not GrafoPiso.DESTINOS.has(estacion_id):
				errores.append("%s no tiene destino en el grafo: %s" % [caso.id, estacion_id])

	for estacion_id: String in estaciones:
		var estacion := estaciones[estacion_id] as Estacion
		var indicador := INDICADOR_SCRIPT.new() as IndicadorProximaEstacion
		indicador.configurar(estacion_id, estacion.nombre_visible)
		add_child(indicador)
		if indicador.get_node_or_null("AroOrientacion") == null:
			errores.append("El indicador de %s no creó su aro visual." % estacion_id)
		indicador.queue_free()

	_probar_cambio_de_indicador(oficina, errores)

	if errores.is_empty():
		print("[PILOTO INDICADORES] OK: protocolos, destinos e indicadores verificados.")
	else:
		for error: String in errores:
			push_error("[PILOTO INDICADORES] " + error)

	oficina.queue_free()
	get_tree().quit(0 if errores.is_empty() else 1)


func _probar_cambio_de_indicador(oficina: Node, errores: Array[String]) -> void:
	var caso: Denuncia = CASOS[0].duplicate(true) as Denuncia
	caso.id = "PILOTO-INDICADOR"
	var sistema := oficina.get("sistema_despacho") as SistemaDespacho
	var indicadores: Dictionary = oficina.get("indicadores_estaciones") as Dictionary

	if not sistema.recibir_denuncia(caso):
		errores.append("No fue posible iniciar el caso de piloto.")
		return

	oficina.call("_on_computador_despacho_abierto")
	_validar_visibilidad(indicadores, "bienestar", errores, "al iniciar el protocolo")

	oficina.call("interactuar_estacion", "bienestar")
	_validar_visibilidad(indicadores, "reporte", errores, "tras completar bienestar")

	oficina.call("interactuar_estacion", "reporte")
	_validar_visibilidad(indicadores, "", errores, "al resolver el protocolo")


func _validar_visibilidad(
	indicadores: Dictionary,
	esperado: String,
	errores: Array[String],
	momento: String
) -> void:
	for estacion_id: String in indicadores:
		var indicador := indicadores[estacion_id] as Node3D
		var deberia_verse: bool = estacion_id == esperado
		if indicador.visible != deberia_verse:
			errores.append(
				"Indicador de %s incoherente %s (esperado visible: %s)."
				% [estacion_id, momento, deberia_verse]
			)
