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
