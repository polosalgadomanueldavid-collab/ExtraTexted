extends Node3D

@onready var panel_despacho: PanelDespacho = $CanvasLayer/PanelDespacho
@onready var computador: PCStatic = $Computer
@onready var jugador: Player = $Gameplay/Node3D

const TIEMPO_MINIMO_ENTRE_DENUNCIAS: float = 12.0
const TIEMPO_MAXIMO_ENTRE_DENUNCIAS: float = 20.0
const MAX_DENUNCIAS_PENDIENTES: int = 5
const DURACION_BLOQUEO_SEGUNDOS: float = 10.0
const BLOQUEOS_SIMULTANEOS: int = 30
const BLOQUEO_TEMPORAL_ESCENA: PackedScene = preload(
	"res://BloqueoTemporal.tscn"
)
const INDICADOR_PROXIMA_ESTACION_SCRIPT: Script = preload(
	"res://Scripts/indicador_proxima_estacion.gd"
)
const ALTURA_INDICADOR_ESTACION: float = 1.90


var sistema_despacho: SistemaDespacho
var temporizador_denuncias: Timer
var generador_aleatorio: RandomNumberGenerator = RandomNumberGenerator.new()
var contador_denuncias: int = 0

var catalogo_denuncias: Array[Denuncia] = [
	preload("res://Casos/Despacho/denuncia_uso_excesivo.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_enlace_sospechoso.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_suplantacion.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_acoso_persistente.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_amenaza_critica.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_phishing_repetido.tres") as Denuncia
]

var grafo_piso: GrafoPiso
var ruta_actual: Array[Vector2i] = []
var temporizador_bloqueos: Timer
var bloqueos_iniciados: bool = false
var bloqueos_visuales: Dictionary = {}
var depurador_grafo: GrafoDebugVisual
var indicadores_estaciones: Dictionary = {}


func _ready() -> void:
	add_to_group("gestor_partida")
	generador_aleatorio.randomize()

	sistema_despacho = SistemaDespacho.new()
	add_child(sistema_despacho)
	grafo_piso = GrafoPiso.new()
	depurador_grafo = GrafoDebugVisual.new()
	depurador_grafo.name = "DepuradorGrafo"
	add_child(depurador_grafo)
	# Espera a que las colisiones de las mesas entren al espacio físico.
	await get_tree().physics_frame
	depurador_grafo.configurar(grafo_piso, jugador)
	_crear_indicadores_estaciones()
	sistema_despacho.denuncias_actualizadas.connect(_on_denuncias_actualizadas)
	sistema_despacho.estacion_completada.connect(_on_estacion_completada)
	
	panel_despacho.configurar_sistema(sistema_despacho)
	# Desactiva el flujo antiguo de preguntas del computador.
	computador.lista_problemas.clear()
	# El computador avisa cuando el jugador interactúa con él.
	computador.computador_despacho_abierto.connect(_on_computador_despacho_abierto)

	temporizador_denuncias = Timer.new()
	temporizador_denuncias.one_shot = true
	temporizador_denuncias.timeout.connect(_recibir_denuncia_aleatoria)
	add_child(temporizador_denuncias)

	# La primera llega pronto para confirmar visualmente la integración.
	temporizador_denuncias.start(3.0)

	temporizador_bloqueos = Timer.new()
	temporizador_bloqueos.wait_time = DURACION_BLOQUEO_SEGUNDOS
	temporizador_bloqueos.timeout.connect(_on_temporizador_bloqueos_timeout)
	add_child(temporizador_bloqueos)


func _process(_delta: float) -> void:
	# La misma consulta que procesa E determina si el icono ofrece interacción.
	var objetivo: Node3D = null
	if is_instance_valid(jugador) and not computador.is_using:
		objetivo = jugador.obtener_objetivo_interaccion()
	for estacion_id: String in indicadores_estaciones:
		var indicador := indicadores_estaciones[estacion_id] as IndicadorProximaEstacion
		if is_instance_valid(indicador):
			var disponible := indicador.visible and objetivo is Estacion and (objetivo as Estacion).estacion_id == estacion_id
			indicador.establecer_interactuable(disponible)


func _recibir_denuncia_aleatoria() -> void:
	if sistema_despacho.obtener_denuncias_ordenadas().size() < MAX_DENUNCIAS_PENDIENTES:
		var plantilla: Denuncia = catalogo_denuncias[
			generador_aleatorio.randi_range(0, catalogo_denuncias.size() - 1)
		]

		# Copia independiente: evita modificar el recurso base .tres.
		var nueva_denuncia: Denuncia = plantilla.duplicate(true) as Denuncia

		contador_denuncias += 1
		nueva_denuncia.id = "%s-%03d" % [plantilla.id, contador_denuncias]
		nueva_denuncia.hora_reporte = Time.get_ticks_msec()

		var denuncia_recibida: bool = sistema_despacho.recibir_denuncia(nueva_denuncia)

		if denuncia_recibida and not bloqueos_iniciados:
			bloqueos_iniciados = true
			_cambiar_bloqueo_temporal()
			temporizador_bloqueos.start()
			
		print(
			"Nueva denuncia: ",
			nueva_denuncia.id,
			" | Nivel ",
			nueva_denuncia.nivel_riesgo,
			" | ",
			nueva_denuncia.titulo
		)

	_programar_siguiente_denuncia()


func _programar_siguiente_denuncia() -> void:
	var espera: float = generador_aleatorio.randf_range(
		TIEMPO_MINIMO_ENTRE_DENUNCIAS,
		TIEMPO_MAXIMO_ENTRE_DENUNCIAS
	)

	temporizador_denuncias.start(espera)

func _on_computador_despacho_abierto() -> void:
	var denuncia: Denuncia = sistema_despacho.iniciar_denuncia_prioritaria()

	if denuncia == null:
		print("No hay denuncias pendientes para atender.")
		return

	print(
		"Denuncia aceptada en despacho: ",
		denuncia.id,
		" - ",
		denuncia.titulo
	)
	_calcular_ruta_a_proxima_estacion()

func interactuar_estacion(estacion_id: String) -> void:
	print("[Despacho] Se solicitó usar la estación: ", estacion_id)
	var fue_correcta: bool = sistema_despacho.interactuar_estacion(estacion_id)

	if fue_correcta:
		print("Estación correcta: ", estacion_id)
		_calcular_ruta_a_proxima_estacion()
	else:
		print("Estación incorrecta o no hay denuncia activa: ", estacion_id)




func _calcular_ruta_a_proxima_estacion() -> void:
	var denuncia: Denuncia = sistema_despacho.obtener_denuncia_activa()

	if denuncia == null:
		ruta_actual.clear()
		_actualizar_indicador_estacion("")
		return

	var indice: int = denuncia.indice_estacion_actual

	if indice >= denuncia.protocolo_estaciones.size():
		ruta_actual.clear()
		_actualizar_indicador_estacion("")
		return

	var estacion_id: String = denuncia.protocolo_estaciones[indice]

	if not GrafoPiso.DESTINOS.has(estacion_id):
		push_warning("La estación no existe en el grafo: " + estacion_id)
		_actualizar_indicador_estacion("")
		return

	var origen: Vector2i = grafo_piso.posicion_a_celda(jugador.global_position)
	var destino: Vector2i = GrafoPiso.DESTINOS[estacion_id]

	ruta_actual = grafo_piso.calcular_ruta(origen, destino)
	depurador_grafo.actualizar_ruta(ruta_actual)
	_actualizar_indicador_estacion(estacion_id)
	_depurar_ruta(origen, destino, ruta_actual)

	print("Ruta hacia ", estacion_id, ": ", ruta_actual)


func _crear_indicadores_estaciones() -> void:
	for nodo: Node in find_children("*", "Estacion", true, false):
		var estacion := nodo as Estacion
		if estacion.estacion_id.is_empty():
			continue

		var indicador := INDICADOR_PROXIMA_ESTACION_SCRIPT.new() as IndicadorProximaEstacion
		indicador.configurar(estacion.estacion_id, estacion.nombre_visible)
		indicador.establecer_activo(false)
		add_child(indicador)
		indicador.global_position = estacion.global_position + Vector3.UP * ALTURA_INDICADOR_ESTACION
		indicadores_estaciones[estacion.estacion_id] = indicador

	print("[Orientación] Indicadores creados: ", indicadores_estaciones.size())


func _actualizar_indicador_estacion(estacion_objetivo: String) -> void:
	for estacion_id: String in indicadores_estaciones:
		var indicador := indicadores_estaciones[estacion_id] as IndicadorProximaEstacion
		if is_instance_valid(indicador):
			var activo := estacion_id == estacion_objetivo
			if indicador.visible != activo or indicador.is_processing() != activo:
				indicador.establecer_activo(activo)

	if not estacion_objetivo.is_empty() and not indicadores_estaciones.has(estacion_objetivo):
		push_warning("No hay indicador visual para la estación: " + estacion_objetivo)


func _on_denuncias_actualizadas(_denuncias: Array[Denuncia]) -> void:
	# Esta señal llega después de limpiar el caso activo al resolver o vencer.
	# Sincronizar solo el marcador evita recalcular rutas al cambiar la cola.
	_sincronizar_indicador_con_despacho()


func _on_estacion_completada(_denuncia: Denuncia, _estacion_id: String) -> void:
	_sincronizar_indicador_con_despacho()


func _sincronizar_indicador_con_despacho() -> void:
	var denuncia := sistema_despacho.obtener_denuncia_activa()
	var estacion_objetivo: String = ""
	if denuncia != null and denuncia.indice_estacion_actual < denuncia.protocolo_estaciones.size():
		var siguiente: String = denuncia.protocolo_estaciones[denuncia.indice_estacion_actual]
		if GrafoPiso.DESTINOS.has(siguiente):
			estacion_objetivo = siguiente
	_actualizar_indicador_estacion(estacion_objetivo)
	if estacion_objetivo.is_empty() and not ruta_actual.is_empty():
		ruta_actual.clear()
		depurador_grafo.actualizar_ruta(ruta_actual)


func _on_temporizador_bloqueos_timeout() -> void:
	_cambiar_bloqueo_temporal()
	
func _cambiar_bloqueo_temporal() -> void:
	_limpiar_bloqueos_temporales()

	var celda_jugador: Vector2i = grafo_piso.posicion_a_celda(
		jugador.global_position
	)

	var destino_activo: Vector2i = Vector2i(-1, -1)
	var denuncia_activa: Denuncia = sistema_despacho.obtener_denuncia_activa()

	if denuncia_activa != null:
		var indice: int = denuncia_activa.indice_estacion_actual

		if indice < denuncia_activa.protocolo_estaciones.size():
			var estacion_id: String = denuncia_activa.protocolo_estaciones[indice]

			if GrafoPiso.DESTINOS.has(estacion_id):
				destino_activo = GrafoPiso.DESTINOS[estacion_id]		

	var candidatos: Array[Vector2i] = []

	for fila: int in range(GrafoPiso.FILAS):
		for columna: int in range(GrafoPiso.COLUMNAS):
			var celda: Vector2i = Vector2i(columna, fila)

			if not grafo_piso.es_transitable(celda):
				continue

			if celda == celda_jugador:
				continue

			if grafo_piso.es_zona_segura(celda):
				continue

			if GrafoPiso.DESTINOS.values().has(celda):
				continue

			candidatos.append(celda)

	if candidatos.is_empty():
		push_warning("No hay celdas disponibles para un bloqueo temporal.")
		return

	var bloqueos_colocados: int = 0
	while not candidatos.is_empty() and bloqueos_colocados < BLOQUEOS_SIMULTANEOS:
		var indice: int = generador_aleatorio.randi_range(
			0,
			candidatos.size() - 1
		)

		var candidata: Vector2i = candidatos[indice]
		candidatos.remove_at(indice)

		grafo_piso.bloqueos_temporales[candidata] = true
		grafo_piso.construir_adyacencia()

		var hay_ruta: bool = (
			destino_activo == Vector2i(-1, -1)
			or not grafo_piso.calcular_ruta(celda_jugador, destino_activo).is_empty()
		)

		if hay_ruta:
			_mostrar_bloqueo_temporal(candidata)
			bloqueos_colocados += 1
			continue

		grafo_piso.bloqueos_temporales.erase(candidata)

	grafo_piso.construir_adyacencia()
	depurador_grafo.actualizar_mapa()
	_calcular_ruta_a_proxima_estacion()

	if bloqueos_colocados < BLOQUEOS_SIMULTANEOS:
		push_warning(
			"Solo se colocaron %d de %d bloqueos sin cerrar la ruta."
			% [bloqueos_colocados, BLOQUEOS_SIMULTANEOS]
		)
	else:
		print("Bloqueos temporales activos: ", bloqueos_colocados)

func _depurar_ruta(
	origen: Vector2i,
	destino: Vector2i,
	ruta: Array[Vector2i]
) -> void:
	if ruta.is_empty():
		push_error(
			"[GRAFO] No existe ruta desde %s hasta %s."
			% [origen, destino]
		)
		return

	if ruta.front() != origen:
		push_error("[GRAFO] La ruta no inicia en la celda del jugador.")
		return

	if ruta.back() != destino:
		push_error("[GRAFO] La ruta no termina en la estación requerida.")
		return

	for celda: Vector2i in ruta:
		if not grafo_piso.es_transitable(celda):
			push_error(
				"[GRAFO] La ruta atraviesa una celda bloqueada: %s."
				% celda
			)
			return

	print(
		"[GRAFO] Ruta válida | Origen: %s | Destino: %s | "
		% [origen, destino]
		+ "Pasos: %d | Bloqueos activos: %d"
		% [ruta.size() - 1, grafo_piso.bloqueos_temporales.size()]
	)

func _mostrar_bloqueo_temporal(celda: Vector2i) -> void:
	var bloqueo_visual := BLOQUEO_TEMPORAL_ESCENA.instantiate() as Node3D
	add_child(bloqueo_visual)
	bloqueos_visuales[celda] = bloqueo_visual
	bloqueo_visual.global_position = grafo_piso.celda_a_posicion(celda)


func _limpiar_bloqueos_temporales() -> void:
	for bloqueo_visual: Node3D in bloqueos_visuales.values():
		if is_instance_valid(bloqueo_visual):
			bloqueo_visual.queue_free()

	bloqueos_visuales.clear()
	grafo_piso.bloqueos_temporales.clear()
	grafo_piso.construir_adyacencia()
