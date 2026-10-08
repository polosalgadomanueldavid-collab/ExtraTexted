class_name PanelDespacho
extends Control

@onready var calma_texto: Label = $PanelContainer/MarginContainer/VBoxContainer/CalmaTexto
@onready var calma_barra: ProgressBar = $PanelContainer/MarginContainer/VBoxContainer/CalmaBar
@onready var denuncia_activa_detalle: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/DenunciaActivaDetalle
@onready var denuncia_activa_titulo: Label = $PanelContainer/MarginContainer/VBoxContainer/DenunciaActivaDetalle/Titulo
@onready var denuncia_activa_tiempo: Label = $PanelContainer/MarginContainer/VBoxContainer/DenunciaActivaDetalle/Tiempo
@onready var denuncia_activa_progreso: Label = $PanelContainer/MarginContainer/VBoxContainer/DenunciaActivaDetalle/Progreso
@onready var denuncia_activa_estacion: Label = $PanelContainer/MarginContainer/VBoxContainer/DenunciaActivaDetalle/ProximaEstacion
@onready var mensaje_estacion: Label = $PanelContainer/MarginContainer/VBoxContainer/MensajeEstacion
@onready var lista_denuncias: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ListaDenuncias

var sistema_despacho: SistemaDespacho = null
var tarjetas: Dictionary = {}
var denuncias_visibles: Dictionary = {}
var segundos_mensaje: float = 0.0


func _ready() -> void:
	actualizar_calma(100)
	actualizar_denuncias([])
	_actualizar_denuncia_activa()


func _process(delta: float) -> void:
	if sistema_despacho == null:
		return

	for id: String in tarjetas:
		var denuncia: Denuncia = denuncias_visibles.get(id)
		_actualizar_tarjeta(denuncia)

	_actualizar_denuncia_activa()
	_actualizar_mensaje(delta)


func configurar_sistema(nuevo_sistema: SistemaDespacho) -> void:
	sistema_despacho = nuevo_sistema

	sistema_despacho.denuncias_actualizadas.connect(actualizar_denuncias)
	sistema_despacho.calma_actualizada.connect(actualizar_calma)
	sistema_despacho.estacion_completada.connect(_on_estacion_completada)
	sistema_despacho.estacion_incorrecta.connect(_on_estacion_incorrecta)
	sistema_despacho.denuncia_resuelta.connect(_on_denuncia_resuelta)
	sistema_despacho.denuncia_vencida.connect(_on_denuncia_vencida)

	actualizar_calma(sistema_despacho.calma_operativa)
	actualizar_denuncias(sistema_despacho.obtener_denuncias_ordenadas())


func actualizar_calma(nueva_calma: int) -> void:
	calma_barra.value = nueva_calma
	calma_texto.text = "Calma operativa: %d / 100" % nueva_calma

	var color_calma: Color = Color.WHITE if nueva_calma >= 30 else Color("#ff6b6b")
	calma_texto.modulate = color_calma
	calma_barra.modulate = color_calma


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


func _actualizar_denuncia_activa() -> void:
	if sistema_despacho == null:
		return

	var denuncia: Denuncia = sistema_despacho.obtener_denuncia_activa()

	if denuncia == null:
		denuncia_activa_detalle.visible = false
		return

	denuncia_activa_detalle.visible = true
	denuncia_activa_titulo.text = "[NIVEL %d] %s\n%s" % [
		denuncia.nivel_riesgo,
		_etiqueta_riesgo(denuncia.nivel_riesgo),
		denuncia.titulo
	]
	denuncia_activa_titulo.modulate = _color_riesgo(denuncia.nivel_riesgo)

	var segundos: int = max(0, ceili(sistema_despacho.obtener_tiempo_restante(denuncia.id)))
	denuncia_activa_tiempo.text = "Tiempo restante: %02d:%02d" % [
		floori(segundos / 60),
		segundos % 60
	]
	denuncia_activa_tiempo.modulate = (
		Color("#ff6b6b")
		if segundos <= denuncia.tiempo_limite_segundos * 0.25
		else Color.WHITE
	)

	var total_pasos: int = denuncia.protocolo_estaciones.size()
	var paso_actual: int = min(denuncia.indice_estacion_actual + 1, total_pasos)
	denuncia_activa_progreso.text = "Progreso: Paso %d de %d" % [paso_actual, total_pasos]

	if denuncia.indice_estacion_actual < total_pasos:
		denuncia_activa_estacion.text = "Próxima estación: %s" % denuncia.protocolo_estaciones[denuncia.indice_estacion_actual].capitalize()
	else:
		denuncia_activa_estacion.text = "Protocolo completado"


func _on_estacion_completada(denuncia: Denuncia, estacion_id: String) -> void:
	_mostrar_mensaje("Correcto: %s completada." % estacion_id.capitalize(), Color("#86efac"))


func _on_estacion_incorrecta(_denuncia: Denuncia, estacion_esperada: String) -> void:
	_mostrar_mensaje("Estación incorrecta. Ve a %s." % estacion_esperada.capitalize(), Color("#ff6b6b"))


func _on_denuncia_resuelta(denuncia: Denuncia) -> void:
	_mostrar_mensaje("Denuncia resuelta: +5 de calma.", Color("#86efac"))


func _on_denuncia_vencida(denuncia: Denuncia) -> void:
	_mostrar_mensaje("La denuncia '%s' venció." % denuncia.titulo, Color("#ff6b6b"))


func _mostrar_mensaje(texto: String, color: Color) -> void:
	mensaje_estacion.text = texto
	mensaje_estacion.modulate = color
	segundos_mensaje = 3.0


func _actualizar_mensaje(delta: float) -> void:
	if segundos_mensaje <= 0.0:
		return

	segundos_mensaje -= delta
	if segundos_mensaje <= 0.0:
		mensaje_estacion.text = ""


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
