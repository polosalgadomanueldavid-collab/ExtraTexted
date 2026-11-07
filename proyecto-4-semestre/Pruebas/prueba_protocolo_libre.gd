extends SceneTree
## Godot --headless --path <proyecto> --script res://Pruebas/prueba_protocolo_libre.gd

const CASOS: Array[String] = [
	"uso_excesivo", "enlace_sospechoso", "suplantacion",
	"acoso_persistente", "amenaza_critica", "phishing_repetido"
]
var _errores: Array[String] = []
var _comprobaciones := 0
var _ordenes := 0


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	for nombre: String in CASOS:
		var plantilla := load("res://Casos/Despacho/denuncia_%s.tres" % nombre) as Denuncia
		for orden: Array in _permutaciones(plantilla.obtener_estaciones_requeridas()):
			_probar_orden(plantilla, orden)
		_verificar(plantilla.estaciones_completadas.is_empty(), "El recurso base conserva su progreso vacío")
	_probar_vencimiento_y_reinicio()
	_probar_estaciones_repetidas()
	_probar_ruta_sugerida()
	print("[PROTOCOLO LIBRE] %d órdenes, %d comprobaciones, %d errores." % [_ordenes, _comprobaciones, _errores.size()])
	quit(0 if _errores.is_empty() else 1)


func _permutaciones(estaciones: Array[String]) -> Array:
	if estaciones.is_empty():
		return [[]]
	var resultado: Array = []
	for estacion: String in estaciones:
		var restantes := estaciones.duplicate()
		restantes.erase(estacion)
		for sufijo: Array in _permutaciones(restantes):
			var orden: Array = [estacion]
			orden.append_array(sufijo)
			resultado.append(orden)
	return resultado


func _probar_orden(plantilla: Denuncia, orden: Array) -> void:
	_ordenes += 1
	var sistema := SistemaDespacho.new()
	var caso := plantilla.duplicate(true) as Denuncia
	var resueltas: Array[String] = []
	var completadas: Array[String] = []
	sistema.denuncia_resuelta.connect(func(denuncia: Denuncia) -> void: resueltas.append(denuncia.id))
	sistema.estacion_completada.connect(func(_denuncia: Denuncia, estacion: String) -> void: completadas.append(estacion))
	sistema.calma_operativa = 60
	sistema.recibir_denuncia(caso)
	_verificar(not sistema.interactuar_estacion(orden[0]), "Una denuncia pendiente requiere ser aceptada")
	sistema.iniciar_denuncia_prioritaria()
	_verificar(not sistema.interactuar_estacion("ajena"), "Una estación ajena al caso se rechaza")
	_verificar(not sistema.interactuar_estacion(""), "Una estación sin ID se rechaza")
	for i: int in range(orden.size()):
		var estacion: String = orden[i]
		_verificar(sistema.interactuar_estacion(estacion), "Se acepta %s en la posición %d de %s" % [estacion, i, orden])
		_verificar(caso.estaciones_completadas.size() == i + 1, "Cada visita válida agrega exactamente una estación")
		_verificar(not sistema.interactuar_estacion(estacion), "Repetir una estación ya completada se rechaza")
		_verificar(completadas.size() == i + 1, "Repetir no emite otro evento de estación completada")
		if i < orden.size() - 1:
			_verificar(caso.estado == Denuncia.Estado.EN_PROCESO and sistema.obtener_denuncia_activa() == caso, "El caso permanece activo mientras faltan estaciones")
			_verificar(sistema.puntuacion.puntos == 0 and sistema.calma_operativa == 60 and resueltas.is_empty(), "El avance parcial no premia ni recupera calma")
	_verificar(caso.estado == Denuncia.Estado.RESUELTA and resueltas == [caso.id], "Cualquier orden cierra el caso exactamente una vez")
	_verificar(sistema.obtener_denuncia_activa() == null and sistema.arbol.buscar_por_id(caso.id) == null and not sistema.tiempos_restantes.has(caso.id), "El cierre automático limpia caso activo, AVL y temporizador")
	_verificar(sistema.puntuacion.puntos == caso.obtener_puntaje_recompensa() and sistema.calma_operativa == 65, "El cierre concede una única recompensa y cinco de calma")
	sistema.actualizar_tiempos(1000.0)
	_verificar(sistema.calma_operativa == 65 and not sistema.resolver_denuncia(caso.id), "Un caso resuelto no vence después ni puede resolverse otra vez")
	sistema.free()


func _probar_vencimiento_y_reinicio() -> void:
	var sistema := SistemaDespacho.new()
	var caso := Denuncia.new()
	caso.id = "VENCE-CON-PROGRESO"
	caso.protocolo_estaciones = ["evidencias", "verificacion", "reporte"]
	caso.tiempo_limite_segundos = 1.0
	caso.penalidad_calma = 15
	sistema.recibir_denuncia(caso)
	sistema.iniciar_denuncia_prioritaria()
	sistema.interactuar_estacion("reporte")
	sistema.actualizar_tiempos(2.0)
	_verificar(caso.estado == Denuncia.Estado.VENCIDA and sistema.calma_operativa == 85, "Un caso con visitas fuera de orden puede vencer normalmente")
	_verificar(not sistema.interactuar_estacion("evidencias") and sistema.puntuacion.puntos == 0, "Una visita tardía no reabre ni premia el caso vencido")
	sistema.actualizar_tiempos(10.0)
	_verificar(sistema.calma_operativa == 85, "El vencimiento penaliza una sola vez")
	sistema.recibir_denuncia(caso)
	_verificar(caso.estaciones_completadas.is_empty() and caso.obtener_estaciones_pendientes().size() == 3, "Recibir una denuncia reinicia su progreso")
	sistema.iniciar_denuncia_prioritaria()
	sistema.interactuar_estacion("verificacion")
	var copia := (load("res://Casos/Despacho/denuncia_suplantacion.tres") as Denuncia).duplicate(true) as Denuncia
	_verificar(copia.estaciones_completadas.is_empty(), "Otro caso tiene un progreso independiente")
	sistema.free()


func _probar_estaciones_repetidas() -> void:
	var sistema := SistemaDespacho.new()
	var caso := Denuncia.new()
	caso.id = "REQUISITOS-SIN-DUPLICADOS"
	caso.protocolo_estaciones = ["reporte", "evidencias", "reporte", ""]
	sistema.recibir_denuncia(caso)
	sistema.iniciar_denuncia_prioritaria()
	_verificar(caso.obtener_estaciones_requeridas() == ["reporte", "evidencias"], "Una estación repetida en la plantilla cuenta una sola vez")
	sistema.interactuar_estacion("evidencias")
	sistema.interactuar_estacion("reporte")
	_verificar(caso.estado == Denuncia.Estado.RESUELTA, "Las estaciones duplicadas de la plantilla no impiden cerrar el caso")
	sistema.free()


func _probar_ruta_sugerida() -> void:
	var grafo := GrafoPiso.new()
	grafo.bloqueos_fijos.clear()
	for y: int in range(5):
		grafo.bloqueos_fijos[Vector2i(4, y)] = true
	grafo.construir_adyacencia()
	var origen := Vector2i(3, 2)
	var al_otro_lado := Vector2i(5, 2)
	var accesible := Vector2i(1, 2)
	var ruta := grafo.calcular_ruta_a_mas_cercana(origen, [al_otro_lado, accesible])
	_verificar(ruta.size() == 3 and ruta.back() == accesible, "Dijkstra recomienda el destino con menos recorrido, considerando el muro")
	grafo.bloqueos_temporales[accesible] = true
	grafo.construir_adyacencia()
	ruta = grafo.calcular_ruta_a_mas_cercana(origen, [accesible, al_otro_lado])
	_verificar(not ruta.is_empty() and ruta.back() == al_otro_lado, "La sugerencia descarta destinos bloqueados y encuentra una alternativa")
	_verificar(grafo.calcular_ruta_a_mas_cercana(origen, [origen]) == [origen], "Estar junto a una estación pendiente produce una ruta de cero pasos")
	_verificar(grafo.calcular_ruta_a_mas_cercana(origen, []).is_empty(), "Sin estaciones pendientes no se sugiere una ruta")
	_verificar(grafo.calcular_ruta(origen, accesible).is_empty(), "La búsqueda a un único destino bloqueado conserva su comportamiento")


func _verificar(condicion: bool, descripcion: String) -> void:
	_comprobaciones += 1
	if not condicion:
		_errores.append(descripcion)
		push_error("[PROTOCOLO LIBRE] " + descripcion)
