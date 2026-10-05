class_name PanelDespacho
extends Control

@onready var calma_texto: Label = $PanelContainer/MarginContainer/VBoxContainer/CalmaTexto
@onready var calma_barra: ProgressBar = $PanelContainer/MarginContainer/VBoxContainer/CalmaBar
@onready var lista_denuncias: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ListaDenuncias

var sistema_despacho: SistemaDespacho = null
var tarjetas: Dictionary = {}
var denuncias_visibles: Dictionary = {}


func _ready() -> void:
	actualizar_calma(100)
	actualizar_denuncias([])


func _process(_delta: float) -> void:
	if sistema_despacho == null:
		return

	for id: String in tarjetas:
		var denuncia: Denuncia = denuncias_visibles.get(id)
		_actualizar_tarjeta(denuncia)


func configurar_sistema(nuevo_sistema: SistemaDespacho) -> void:
	sistema_despacho = nuevo_sistema

	sistema_despacho.denuncias_actualizadas.connect(actualizar_denuncias)
	sistema_despacho.calma_actualizada.connect(actualizar_calma)

	actualizar_calma(sistema_despacho.calma_operativa)
	actualizar_denuncias(sistema_despacho.obtener_denuncias_ordenadas())


func actualizar_calma(nueva_calma: int) -> void:
	calma_barra.value = nueva_calma
	calma_texto.text = "Calma operativa: %d / 100" % nueva_calma


func actualizar_denuncias(denuncias: Array[Denuncia]) -> void:
	for hijo: Node in lista_denuncias.get_children():
		hijo.queue_free()

	tarjetas.clear()
	denuncias_visibles.clear()

	for denuncia: Denuncia in denuncias:
		var tarjeta: Label = Label.new()
		tarjeta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tarjeta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tarjeta.custom_minimum_size = Vector2(300, 72)

		lista_denuncias.add_child(tarjeta)

		tarjetas[denuncia.id] = tarjeta
		denuncias_visibles[denuncia.id] = denuncia

		_actualizar_tarjeta(denuncia)


func _actualizar_tarjeta(denuncia: Denuncia) -> void:
	var tarjeta: Label = tarjetas.get(denuncia.id)

	if tarjeta == null:
		return

	var tiempo_restante: float = denuncia.tiempo_limite_segundos

	if sistema_despacho != null:
		tiempo_restante = sistema_despacho.obtener_tiempo_restante(denuncia.id)

	var segundos: int = max(0, ceili(tiempo_restante))
	var minutos: int = floori(segundos / 60)
	var segundos_finales: int = segundos % 60

	tarjeta.text = (
		"[NIVEL %d] %s\n%s\nTiempo: %02d:%02d | %s"
		% [
			denuncia.nivel_riesgo,
			_etiqueta_riesgo(denuncia.nivel_riesgo),
			denuncia.titulo,
			minutos,
			segundos_finales,
			_estado_texto(denuncia.estado)
		]
	)

	tarjeta.modulate = _color_riesgo(denuncia.nivel_riesgo)


func _etiqueta_riesgo(nivel: int) -> String:
	match nivel:
		5:
			return "CRÍTICA"
		4:
			return "ALTA"
		3:
			return "MEDIA"
		2:
			return "PREVENCIÓN"
		_:
			return "BIENESTAR"


func _estado_texto(estado: Denuncia.Estado) -> String:
	match estado:
		Denuncia.Estado.EN_PROCESO:
			return "EN PROCESO"
		Denuncia.Estado.RESUELTA:
			return "RESUELTA"
		Denuncia.Estado.VENCIDA:
			return "VENCIDA"
		_:
			return "EN ESPERA"


func _color_riesgo(nivel: int) -> Color:
	match nivel:
		5:
			return Color("#ff6b6b")
		4:
			return Color("#ffad5c")
		3:
			return Color("#ffe66d")
		2:
			return Color("#7bdff2")
		_:
			return Color("#a8dadc")
