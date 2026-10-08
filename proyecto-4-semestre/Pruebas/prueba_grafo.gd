extends Node


func _ready() -> void:
	var grafo: GrafoPiso = GrafoPiso.new()

	var origen: Vector2i = Vector2i(7, 0)
	var destino: Vector2i = Vector2i(13, 7)

	var ruta: Array[Vector2i] = grafo.calcular_ruta(origen, destino)

	print("Ruta calculada: ", ruta)
	print("Cantidad de celdas: ", ruta.size())

	if ruta.is_empty():
		print("ERROR: no existe una ruta.")
		return

	print("Inicio correcto: ", ruta.front() == origen)
	print("Destino correcto: ", ruta.back() == destino)
