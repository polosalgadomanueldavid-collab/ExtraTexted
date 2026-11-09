extends Node

var arbol: ArbolDenunciasAVL = ArbolDenunciasAVL.new()

var denuncias_prueba: Array[Denuncia] = [
	preload("res://Casos/Despacho/denuncia_uso_excesivo.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_enlace_sospechoso.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_suplantacion.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_acoso_persistente.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_amenaza_critica.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_phishing_repetido.tres") as Denuncia
]


func _ready() -> void:
	print("===== PRUEBA AVL DE DESPACHO =====")

	for denuncia: Denuncia in denuncias_prueba:
		arbol.insertar(denuncia)
		print("Insertada: ", denuncia.id, " | Riesgo: ", denuncia.nivel_riesgo)

	print("")
	print("Altura de la raíz: ", arbol.raiz.altura)

	var prioritaria: Denuncia = arbol.obtener_prioritaria()

	if prioritaria != null:
		print("DENUNCIA PRIORITARIA: ", prioritaria.id, " - ", prioritaria.titulo)
	else:
		print("No hay denuncias pendientes.")

	print("")
	print("===== PANEL LATERAL ORDENADO =====")

	var ordenadas: Array[Denuncia] = arbol.recorrido_inorden()

	for indice: int in range(ordenadas.size()):
		var denuncia: Denuncia = ordenadas[indice]
		print(
			indice + 1,
			". [Nivel ",
			denuncia.nivel_riesgo,
			"] ",
			denuncia.id,
			" - ",
			denuncia.titulo,
			" | Hora: ",
			denuncia.hora_reporte
		)
		print("")
	
	print("===== ELIMINACIÓN DE DENUNCIA =====")

	var eliminada: bool = arbol.eliminar_por_id("D-005")
	print("¿Se eliminó D-005?: ", eliminada)

	var nueva_prioritaria: Denuncia = arbol.obtener_prioritaria()

	if nueva_prioritaria != null:
		print(
			"NUEVA DENUNCIA PRIORITARIA: ",
			nueva_prioritaria.id,
			" - ",
			nueva_prioritaria.titulo
		)

	print("")
	print("===== PANEL DESPUÉS DE ELIMINAR D-005 =====")

	var orden_despues: Array[Denuncia] = arbol.recorrido_inorden()

	for indice: int in range(orden_despues.size()):
		var denuncia: Denuncia = orden_despues[indice]
		print(
			indice + 1,
			". [Nivel ",
			denuncia.nivel_riesgo,
			"] ",
			denuncia.id,
			" - ",
			denuncia.titulo
		)
	_probar_todas_las_rotaciones()
	_probar_sistema_despacho()

func _probar_todas_las_rotaciones() -> void:
	print("")
	print("===== PRUEBAS DE ROTACIONES AVL =====")

	_probar_rotacion("LL", [3, 4, 5])
	_probar_rotacion("RR", [5, 4, 3])
	_probar_rotacion("LR", [3, 5, 4])
	_probar_rotacion("RL", [5, 3, 4])


func _probar_rotacion(nombre: String, riesgos: Array[int]) -> void:
	var arbol_prueba: ArbolDenunciasAVL = ArbolDenunciasAVL.new()

	for indice: int in range(riesgos.size()):
		var denuncia: Denuncia = Denuncia.new()
		denuncia.id = nombre + "-" + str(indice + 1)
		denuncia.titulo = "Prueba " + nombre
		denuncia.nivel_riesgo = riesgos[indice]
		denuncia.hora_reporte = 2000 + indice

		arbol_prueba.insertar(denuncia)

	var raiz: NodoAVL = arbol_prueba.raiz

	print(
		nombre,
		" -> raíz nivel ",
		raiz.denuncia.nivel_riesgo,
		" | altura ",
		raiz.altura
	)
	
	
func _probar_sistema_despacho() -> void:
	print("")
	print("===== PRUEBA DE CALMA Y TEMPORIZADORES =====")

	var despacho: SistemaDespacho = SistemaDespacho.new()
	add_child(despacho)

	# Desactivamos el _process automático para controlar el tiempo manualmente.
	despacho.set_process(false)

	# Se baja la calma solo para comprobar que resolver un caso recupera 5 puntos.
	despacho.calma_operativa = 80

	var caso_medio: Denuncia = Denuncia.new()
	caso_medio.id = "TEST-003"
	caso_medio.titulo = "Caso de prueba nivel 3"
	caso_medio.nivel_riesgo = 3
	caso_medio.hora_reporte = 3000
	caso_medio.tiempo_limite_segundos = 60.0
	caso_medio.penalidad_calma = 14

	var caso_critico: Denuncia = Denuncia.new()
	caso_critico.id = "TEST-005"
	caso_critico.titulo = "Caso de prueba nivel 5"
	caso_critico.nivel_riesgo = 5
	caso_critico.hora_reporte = 3001
	caso_critico.tiempo_limite_segundos = 40.0
	caso_critico.penalidad_calma = 30

	despacho.recibir_denuncia(caso_medio)
	despacho.recibir_denuncia(caso_critico)

	var prioritaria: Denuncia = despacho.obtener_denuncia_prioritaria()

	print("Prioritaria: ", prioritaria.id)
	print("Calma inicial: ", despacho.calma_operativa)

	# Se resuelve el caso más grave.
	despacho.resolver_denuncia("TEST-005")
	print("Calma tras resolver nivel 5: ", despacho.calma_operativa)

	# Simulamos 61 segundos para vencer el caso nivel 3.
	despacho.actualizar_tiempos(61.0)
	print("Calma tras vencer nivel 3: ", despacho.calma_operativa)

	var denuncias_pendientes: Array[Denuncia] = despacho.obtener_denuncias_ordenadas()
	print("Denuncias pendientes: ", denuncias_pendientes.size())
