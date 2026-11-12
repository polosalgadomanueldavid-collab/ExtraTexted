extends Node3D

@onready var panel_despacho: PanelDespacho = $CanvasLayer/PanelDespacho
@onready var computador: PCStatic = $Computer
@onready var jugador: Player = $Gameplay/Node3D
@onready var evento_apagon: EventoApagonScript = $EventoApagon
@onready var evento_terremoto: EventoTerremoto = $EventoTerremoto
@onready var musica_partida: MusicaPartida = $MusicaPartida
@onready var musica_cordura_baja: MusicaPartida = $MusicaCorduraBaja

const TIEMPO_MINIMO_ENTRE_DENUNCIAS: float = 12.0
const TIEMPO_MAXIMO_ENTRE_DENUNCIAS: float = 20.0
const MAX_DENUNCIAS_PENDIENTES: int = 5
const DURACION_BLOQUEO_SEGUNDOS: float = 10.0
const BLOQUEOS_SIMULTANEOS: int = 30
const BLOQUEO_TEMPORAL_ESCENA: PackedScene = preload(
	"res://Eventos/Bloqueos/BloqueoTemporal.tscn"
)
const INDICADOR_PROXIMA_ESTACION_SCRIPT: Script = preload(
	"res://MarcadoresEstaciones/indicador_proxima_estacion.gd"
)
const GUIA_ESTACION_ESCENA := preload("res://UI/Despacho/GuiaEstacion.tscn")
const PAPEL_DENUNCIA_SCRIPT := preload("res://Scripts/Despacho/papel_denuncia.gd")
const IndicadorPapel := preload("res://UI/Despacho/indicador_papel.gd")
const ProgresoSeguridad := preload("res://UI/Despacho/progreso_seguridad.gd")
const ClasificadorEvidencias := preload("res://UI/Despacho/clasificador_evidencias.gd")
const EscanerVerificacion := preload("res://UI/Despacho/escaner_verificacion.gd")
const SonidosMesas := preload("res://UI/Despacho/sonidos_mesas.gd")
const HerramientaReporte := preload("res://Scripts/Despacho/herramienta_reporte.gd")
const CLASIFICACION_PARTIDA_ESCENA := preload("res://UI/Despacho/ClasificacionPartida.tscn")
const ClasificacionPartida := preload("res://UI/Despacho/clasificacion_partida.gd")
const FinalPartidaScript := preload("res://UI/Despacho/final_partida.gd")
const MODELO_RELEVO := preload("res://Personajes/PoliciaRelevo/ModeloRelevo.tscn")
const VER_CLASIFICACION := &"VerClasificacion"
const ALTURA_INDICADOR_ESTACION: float = 1.25
const DURACION_DESENCRIPTADO: float = 6.0
@export_range(0.0, 1.0, 0.05) var probabilidad_atasco_reporte: float = 0.35
const EventoApagonScript := preload("res://Eventos/Apagon/evento_apagon.gd")
const EventoTerremoto := preload("res://Eventos/Terremoto/evento_terremoto.gd")


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
var estacion_sugerida: String = ""
var _estaciones_pendientes: Array[String] = []
var _denuncia_orientada_id: String = ""
var _celda_ruta := Vector2i(-1, -1)
var temporizador_bloqueos: Timer
var bloqueos_iniciados: bool = false
var bloqueos_visuales: Dictionary = {}
var _bloqueos_pool: Array[StaticBody3D] = []
var _bloqueos_disponibles: Array[StaticBody3D] = []
var depurador_grafo: GrafoDebugVisual
var indicadores_estaciones: Dictionary = {}
var guia_estacion: Control
var clasificacion_partida: ClasificacionPartida
var _nombre_partida: String = ""
var _aviso_apagon: Label
var indicador_papel: IndicadorPapel
var progreso_seguridad: ProgresoSeguridad
var temporizador_seguridad: Timer
var _denuncia_en_descriptado: String = ""
var _mesa_seguridad: Estacion
var _seguridad_lista: bool = false
var clasificador_evidencias: ClasificadorEvidencias
var escaner_verificacion: EscanerVerificacion
var sonidos_mesas: SonidosMesas
var herramienta_reporte: HerramientaReporte
var _aviso_reporte_atasco: Label3D
var _reporte_atascado_id: String = ""
var _reporte_herramienta_recogida: bool = false
var papel_actual: PapelDenuncia = null
var partida_finalizada: bool = false
var final_partida: FinalPartida
var _duracion_partida: float = 0.0
var _resueltas: Array[Dictionary] = []
var _vencidas: Array[Dictionary] = []
var _ultima_vencida: Dictionary = {}


func _ready() -> void:
	add_to_group("gestor_partida")
	sonidos_mesas = SonidosMesas.new()
	add_child(sonidos_mesas)
	generador_aleatorio.randomize()

	sistema_despacho = SistemaDespacho.new()
	add_child(sistema_despacho)
	musica_partida.configurar(sistema_despacho)
	musica_cordura_baja.configurar(sistema_despacho, true)
	_nombre_partida = MenuGlobal.nombre_partida
	clasificacion_partida = CLASIFICACION_PARTIDA_ESCENA.instantiate()
	panel_despacho.add_child(clasificacion_partida)
	sistema_despacho.puntuacion.puntos_actualizados.connect(_al_actualizar_puntaje)
	evento_apagon.estado_cambiado.connect(_al_cambiar_estado_apagon)
	evento_apagon.apagon_iniciado.connect(_al_iniciar_apagon)
	evento_terremoto.inicio_solicitado.connect(_iniciar_terremoto)
	evento_terremoto.temblor_actualizado.connect($Gameplay/Camera3D.actualizar_temblor)
	evento_terremoto.suelo_roto.connect(_al_romper_suelo)
	evento_terremoto.terminado.connect(_al_terminar_terremoto)
	grafo_piso = GrafoPiso.new()
	depurador_grafo = GrafoDebugVisual.new()
	depurador_grafo.name = "DepuradorGrafo"
	add_child(depurador_grafo)
	# Espera a que las colisiones de las mesas entren al espacio físico.
	await get_tree().physics_frame
	depurador_grafo.configurar(grafo_piso, jugador)
	_crear_indicadores_estaciones()
	guia_estacion = GUIA_ESTACION_ESCENA.instantiate()
	panel_despacho.add_child(guia_estacion)
	sistema_despacho.denuncias_actualizadas.connect(_on_denuncias_actualizadas)
	sistema_despacho.estacion_completada.connect(_on_estacion_completada)
	sistema_despacho.denuncia_resuelta.connect(_on_caso_finalizado)
	sistema_despacho.denuncia_vencida.connect(_on_caso_finalizado)
	sistema_despacho.partida_terminada.connect(_al_terminar_partida)
	
	panel_despacho.configurar_sistema(sistema_despacho)
	indicador_papel = IndicadorPapel.new()
	$CanvasLayer.add_child(indicador_papel)
	progreso_seguridad = ProgresoSeguridad.new()
	$CanvasLayer.add_child(progreso_seguridad)
	clasificador_evidencias = ClasificadorEvidencias.new()
	$CanvasLayer.add_child(clasificador_evidencias)
	clasificador_evidencias.terminado.connect(_al_archivar_evidencias)
	clasificador_evidencias.cerrado.connect(_al_cerrar_tarea_estacion)
	escaner_verificacion = EscanerVerificacion.new()
	$CanvasLayer.add_child(escaner_verificacion)
	escaner_verificacion.verificacion_terminada.connect(_al_terminar_verificacion)
	escaner_verificacion.cerrado.connect(_al_cerrar_tarea_estacion)
	herramienta_reporte = HerramientaReporte.new()
	herramienta_reporte.position = grafo_piso.celda_a_posicion(Vector2i(7, 15)) + Vector3.UP * 0.26
	add_child(herramienta_reporte)
	_aviso_reporte_atasco = Label3D.new()
	_aviso_reporte_atasco.text = "IMPRESORA ATASCADA"
	_aviso_reporte_atasco.font = preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
	_aviso_reporte_atasco.font_size = 24
	_aviso_reporte_atasco.pixel_size = 0.004
	_aviso_reporte_atasco.modulate = Color("ff785f")
	_aviso_reporte_atasco.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_aviso_reporte_atasco.visible = false
	add_child(_aviso_reporte_atasco)
	for nodo: Node in find_children("*", "Estacion", true, false):
		var estacion_reporte := nodo as Estacion
		if estacion_reporte.estacion_id == "reporte":
			_aviso_reporte_atasco.global_position = estacion_reporte.global_position + Vector3.UP * 2.0
			break
	final_partida = FinalPartidaScript.new() as FinalPartida
	$CanvasLayer.add_child(final_partida)
	final_partida.relevo_iniciado.connect(_mostrar_companero_relevo)
	final_partida.reiniciar_solicitado.connect(_reiniciar_despues_del_final)
	final_partida.menu_solicitado.connect(_volver_al_menu_despues_del_final)
	temporizador_seguridad = Timer.new()
	temporizador_seguridad.one_shot = true
	temporizador_seguridad.wait_time = DURACION_DESENCRIPTADO
	temporizador_seguridad.timeout.connect(_completar_descriptado)
	add_child(temporizador_seguridad)
	for nodo: Node in find_children("*", "Estacion", true, false):
		var estacion := nodo as Estacion
		if estacion.estacion_id == "privacidad":
			_mesa_seguridad = estacion
			break
	_crear_aviso_apagon()
	# Desactiva el flujo antiguo de preguntas del computador.
	computador.lista_problemas.clear()
	computador.entregar_papel = true
	computador.papel_solicitado.connect(_entregar_papel)

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
	_preparar_pool_bloqueos.call_deferred()


func _preparar_pool_bloqueos() -> void:
	# Reparte la creación inicial; los temporizadores siguen pausados durante el tutorial.
	while is_inside_tree() and _bloqueos_pool.size() < BLOQUEOS_SIMULTANEOS:
		var bloqueo := _crear_bloqueo_pool()
		_bloqueos_disponibles.append(bloqueo)
		if _bloqueos_pool.size() % 3 == 0:
			await get_tree().process_frame


func _crear_bloqueo_pool() -> StaticBody3D:
	var bloqueo := BLOQUEO_TEMPORAL_ESCENA.instantiate() as StaticBody3D
	bloqueo.call("preparar_para_pool")
	add_child(bloqueo)
	_bloqueos_pool.append(bloqueo)
	return bloqueo


func _process(_delta: float) -> void:
	if partida_finalizada:
		return
	_duracion_partida += _delta
	# Reorientar al cambiar de celda, sin buscar rutas en cada cuadro.
	if not _estaciones_pendientes.is_empty() and grafo_piso.posicion_a_celda(jugador.global_position) != _celda_ruta:
		_calcular_ruta_a_proxima_estacion()
	# La misma consulta que procesa E determina si el icono ofrece interacción.
	var objetivo: Node3D = null
	if is_instance_valid(jugador) and not computador.is_using:
		objetivo = jugador.obtener_objetivo_interaccion()
	for estacion_id: String in indicadores_estaciones:
		var indicador := indicadores_estaciones[estacion_id] as IndicadorProximaEstacion
		if is_instance_valid(indicador):
			var disponible := indicador.visible and objetivo is Estacion and (objetivo as Estacion).estacion_id == estacion_id
			indicador.establecer_interactuable(disponible)
	if is_instance_valid(guia_estacion):
		guia_estacion.actualizar(panel_despacho.contenido, computador.is_using or evento_apagon.estado == EventoApagonScript.Estado.REPARANDO)
	_actualizar_indicador_papel()
	_actualizar_aviso_apagon(objetivo)
	if not _denuncia_en_descriptado.is_empty() and is_instance_valid(_mesa_seguridad):
		var avance := 1.0 if _seguridad_lista else 1.0 - temporizador_seguridad.time_left / DURACION_DESENCRIPTADO
		progreso_seguridad.actualizar(avance, get_viewport().get_camera_3d(), _mesa_seguridad.global_position + Vector3.UP * 2.05)


func _input(evento: InputEvent) -> void:
	if partida_finalizada:
		return
	if evento.is_action_released(VER_CLASIFICACION) and clasificacion_partida.visible:
		clasificacion_partida.hide()
		get_viewport().set_input_as_handled()
		return
	if evento_apagon.estado == EventoApagonScript.Estado.REPARANDO:
		return
	if evento.is_action_pressed(VER_CLASIFICACION, true, true):
		if not evento.is_echo() and not clasificacion_partida.visible:
			_presentar_clasificacion()
			clasificacion_partida.show()
		get_viewport().set_input_as_handled()


func _unhandled_key_input(evento: InputEvent) -> void:
	if partida_finalizada:
		return
	if not OS.is_debug_build() or not is_instance_valid(depurador_grafo) or not depurador_grafo.visible_debug:
		return
	if not evento is InputEventKey or not evento.pressed or evento.echo:
		return
	if get_tree().paused or computador.is_using or jugador.input_locked or clasificacion_partida.visible or MenuGlobal.capa.visible:
		return
	if evento.physical_keycode == KEY_T or evento.keycode == KEY_T:
		_iniciar_terremoto()
	elif evento.physical_keycode == KEY_B or evento.keycode == KEY_B:
		if not evento_terremoto.activo:
			evento_apagon.iniciar_apagon()
	else:
		return
	get_viewport().set_input_as_handled()


func _crear_aviso_apagon() -> void:
	_aviso_apagon = Label.new()
	_aviso_apagon.name = "AvisoApagon"
	_aviso_apagon.theme = panel_despacho.theme
	_aviso_apagon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso_apagon.add_theme_font_size_override("font_size", 22)
	_aviso_apagon.add_theme_color_override("font_color", Color("fff1d8"))
	_aviso_apagon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.06, 0.15, 0.2, 0.94)
	fondo.border_color = Color("ffc969")
	fondo.border_width_left = 4
	fondo.set_corner_radius_all(10)
	fondo.content_margin_left = 16
	fondo.content_margin_right = 16
	fondo.content_margin_top = 12
	fondo.content_margin_bottom = 12
	_aviso_apagon.add_theme_stylebox_override("normal", fondo)
	$CanvasLayer.add_child(_aviso_apagon)
	get_viewport().size_changed.connect(_ajustar_aviso_apagon)
	_ajustar_aviso_apagon()


func _ajustar_aviso_apagon() -> void:
	var tamano := get_viewport().get_visible_rect().size
	indicador_papel.ajustar_pantalla(tamano)
	var factor := minf(tamano.x / 1920.0, tamano.y / 1080.0)
	_aviso_apagon.scale = Vector2.ONE * factor
	_aviso_apagon.size = Vector2(590, 80)
	_aviso_apagon.position = Vector2(28.0 * factor, tamano.y - 108.0 * factor)
	if indicador_papel.visible:
		var separacion := 14.0 * indicador_papel.scale.y
		_aviso_apagon.position = Vector2(indicador_papel.position.x, indicador_papel.position.y - separacion - _aviso_apagon.size.y * factor)


func _actualizar_indicador_papel() -> void:
	if not is_instance_valid(indicador_papel):
		return
	var papel := jugador.papel_en_mano
	var llevando := is_instance_valid(papel) and not papel.is_queued_for_deletion() and papel.portador == jugador
	var disponible := llevando and not computador.is_using and evento_apagon.estado != EventoApagonScript.Estado.REPARANDO
	if indicador_papel.visible != disponible:
		indicador_papel.visible = disponible
		_ajustar_aviso_apagon()


func _actualizar_aviso_apagon(objetivo: Node3D) -> void:
	if not is_instance_valid(_aviso_apagon):
		return
	_aviso_apagon.visible = not computador.is_using and not clasificador_evidencias.visible and not escaner_verificacion.visible and evento_apagon.estado != EventoApagonScript.Estado.REPARANDO and (evento_apagon.estado != EventoApagonScript.Estado.RESTAURADO or (OS.is_debug_build() and depurador_grafo.visible_debug))
	if evento_apagon.estado == EventoApagonScript.Estado.RESTAURADO:
		_aviso_apagon.text = "[B] PROBAR APAGÓN  ·  [T] PROBAR TERREMOTO"
	elif objetivo == evento_apagon.taco:
		_aviso_apagon.text = "[E] REPARAR EL CIRCUITO\nTACO DE LUZ"
	else:
		_aviso_apagon.text = "APAGÓN  ·  BUSCA EL TACO DE LUZ\nPARED DERECHA  ·  ZONA DE DESCANSO"


func _al_cambiar_estado_apagon(nuevo_estado: EventoApagonScript.Estado) -> void:
	if nuevo_estado == EventoApagonScript.Estado.REPARANDO:
		clasificacion_partida.hide()


func _al_iniciar_apagon(_tipo: int) -> void:
	jugador.reproducir_expresion(&"sorpresa")


func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		if is_instance_valid(clasificacion_partida):
			clasificacion_partida.hide()


func _al_actualizar_puntaje(_saldo: int) -> void:
	if not _nombre_partida.is_empty():
		MenuGlobal.registrar_puntaje(sistema_despacho.puntuacion.puntos_ganados, _nombre_partida)
	if clasificacion_partida.visible:
		_presentar_clasificacion()


func _presentar_clasificacion() -> void:
	var consulta: Dictionary = MenuGlobal.consultar_clasificacion()
	clasificacion_partida.presentar(consulta.entradas, _nombre_partida, sistema_despacho.puntuacion.puntos_ganados, consulta.error)


func _recibir_denuncia_aleatoria() -> void:
	if partida_finalizada:
		return
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
			evento_terremoto.programar()
			
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


func _entregar_papel(portador: Player) -> void:
	if not is_instance_valid(portador):
		return
	if _manos_ocupadas_con_cafe():
		return
	if is_instance_valid(portador.papel_en_mano):
		panel_despacho._mostrar_mensaje("Ya llevas una denuncia. Usa E en una estación o lánzala en un espacio libre.", PanelDespacho.CORAL)
		return
	if is_instance_valid(papel_actual):
		panel_despacho._mostrar_mensaje("La denuncia ya está impresa. Recoge la hoja con E.", PanelDespacho.CORAL)
		return
	var denuncia := sistema_despacho.iniciar_denuncia_prioritaria()
	if denuncia == null:
		panel_despacho._mostrar_mensaje("No hay denuncias pendientes para imprimir.", PanelDespacho.CORAL)
		return
	papel_actual = PAPEL_DENUNCIA_SCRIPT.new() as PapelDenuncia
	papel_actual.denuncia_id = denuncia.id
	add_child(papel_actual)
	papel_actual.global_position = computador.global_position + Vector3.UP * 0.7
	papel_actual.freeze = true
	if not portador.ejecutar_gesto(&"recibir", _tomar_papel_si_vigente.bind(portador, papel_actual.get_instance_id()), computador):
		papel_actual.freeze = false


func recoger_papel(portador: Player, papel: PapelDenuncia) -> void:
	if _manos_ocupadas_con_cafe():
		return
	var denuncia := sistema_despacho.obtener_denuncia_activa()
	if papel != papel_actual or denuncia == null or denuncia.id != papel.denuncia_id:
		return
	portador.ejecutar_gesto(&"recoger", _tomar_papel_si_vigente.bind(portador, papel.get_instance_id()), papel)


func _manos_ocupadas_con_cafe() -> bool:
	var descanso := get_node_or_null("ZonaDescanso")
	if descanso != null and descanso.tiene_cafe():
		descanso.mostrar_mensaje("Termina el café con F antes de recoger una denuncia.")
		return true
	return false


func _tomar_papel_si_vigente(portador: Player, papel_id: int) -> void:
	# El gesto puede terminar después de que la denuncia haya liberado la hoja.
	if not is_instance_valid(portador) or not is_instance_valid(papel_actual) or papel_actual.is_queued_for_deletion():
		return
	var papel := papel_actual
	if papel.get_instance_id() != papel_id:
		return
	var denuncia := sistema_despacho.obtener_denuncia_activa()
	if denuncia == null or denuncia.id != papel.denuncia_id:
		return
	if is_instance_valid(portador.papel_en_mano) or is_instance_valid(papel.portador):
		return
	papel.tomar(portador)
	_actualizar_indicador_papel()
	panel_despacho._mostrar_mensaje("Ve con la denuncia.", Color("86efac"))


func recuperar_papel_perdido(papel: PapelDenuncia) -> void:
	if papel != papel_actual:
		return
	papel.freeze = true
	papel.linear_velocity = Vector3.ZERO
	papel.angular_velocity = Vector3.ZERO
	papel.global_position = computador.global_position + Vector3.UP * 0.7
	papel.freeze = false


func _iniciar_terremoto() -> void:
	if partida_finalizada or not bloqueos_iniciados or computador.is_using or jugador.input_locked:
		return
	if evento_apagon.estado != EventoApagonScript.Estado.RESTAURADO:
		return
	if not evento_terremoto.iniciar(grafo_piso, jugador, bloqueos_visuales, _huella_papel_suelto()):
		return
	temporizador_bloqueos.paused = true
	jugador.reproducir_expresion(&"estres")
	panel_despacho._mostrar_mensaje("El suelo empieza a temblar…", PanelDespacho.CORAL)


func _al_romper_suelo() -> void:
	if is_instance_valid(papel_actual) and papel_actual.portador == null:
		papel_actual.sleeping = false
	if not grafo_piso.es_zona_segura(grafo_piso.posicion_a_celda(jugador.global_position)):
		panel_despacho._mostrar_mensaje("¡Terremoto! Cuida la hoja y rodea la grieta grande.", PanelDespacho.CORAL)
	depurador_grafo.actualizar_mapa()
	_calcular_ruta_a_proxima_estacion()


func _physics_process(_delta: float) -> void:
	if partida_finalizada or not evento_terremoto.activo or not is_instance_valid(papel_actual):
		return
	if papel_actual.portador == null and evento_terremoto.atrapo_hoja(papel_actual.global_position):
		sistema_despacho.vencer_denuncia(papel_actual.denuncia_id, Denuncia.MotivoPerdida.TERREMOTO)


func _al_terminar_terremoto() -> void:
	for bloqueo in evento_terremoto.caidos:
		bloqueo.call("desactivar")
		_bloqueos_disponibles.append(bloqueo)
	evento_terremoto.caidos.clear()
	temporizador_bloqueos.paused = false
	depurador_grafo.actualizar_mapa()
	_calcular_ruta_a_proxima_estacion()


func _on_caso_finalizado(denuncia: Denuncia) -> void:
	var registro := _resumen_denuncia(denuncia)
	if denuncia.estado == Denuncia.Estado.RESUELTA:
		_resueltas.append(registro)
	elif denuncia.estado == Denuncia.Estado.VENCIDA:
		_vencidas.append(registro)
		_ultima_vencida = registro
	if _denuncia_en_descriptado == denuncia.id:
		_cancelar_descriptado()
	if _reporte_atascado_id == denuncia.id:
		_limpiar_atasco_reporte()
	if clasificador_evidencias.caso_id == denuncia.id:
		clasificador_evidencias.cancelar()
	if escaner_verificacion.caso_id == denuncia.id:
		escaner_verificacion.cancelar()
	if is_instance_valid(papel_actual) and papel_actual.denuncia_id == denuncia.id:
		if is_instance_valid(papel_actual.portador):
			papel_actual.portador.papel_en_mano = null
		papel_actual.queue_free()
		papel_actual = null
		_actualizar_indicador_papel()


func _resumen_denuncia(denuncia: Denuncia) -> Dictionary:
	return {
		"id": denuncia.id,
		"titulo": denuncia.titulo,
		"terremoto": denuncia.estado == Denuncia.Estado.VENCIDA and denuncia.motivo_perdida == Denuncia.MotivoPerdida.TERREMOTO,
		"completadas": denuncia.estaciones_completadas.duplicate(),
		"pendientes": denuncia.obtener_estaciones_pendientes()
	}


func _al_terminar_partida() -> void:
	if partida_finalizada:
		return
	partida_finalizada = true
	MenuGlobal.final_de_partida_activo = true
	jugador.input_locked = true
	temporizador_denuncias.stop()
	temporizador_bloqueos.stop()
	var abiertas: Array[Dictionary] = []
	for denuncia: Denuncia in sistema_despacho.obtener_denuncias_ordenadas():
		abiertas.append(_resumen_denuncia(denuncia))
	var datos := {
		"causa": _ultima_vencida.duplicate(true),
		"resueltas": _resueltas.duplicate(true),
		"vencidas": _vencidas.duplicate(true),
		"pendientes": abiertas,
		"duracion": _duracion_partida,
		"puntos_ganados": sistema_despacho.puntuacion.puntos_ganados,
		"saldo": sistema_despacho.puntuacion.puntos
	}
	panel_despacho.hide()
	depurador_grafo.hide()
	for indicador: IndicadorProximaEstacion in indicadores_estaciones.values():
		indicador.hide()
	indicador_papel.hide()
	progreso_seguridad.hide()
	_aviso_apagon.hide()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	final_partida.presentar(datos)


func _mostrar_companero_relevo() -> void:
	# El modelo existente aparece junto al jugador y se acerca durante el relevo.
	var celda := grafo_piso.celda_de_acceso(jugador.global_position)
	var offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var destino_celda := Vector2i(-1, -1)
	var inicio_celda := Vector2i(-1, -1)
	for offset: Vector2i in offsets:
		if grafo_piso.es_transitable(celda + offset):
			destino_celda = celda + offset
			inicio_celda = celda + offset * 2 if grafo_piso.es_transitable(celda + offset * 2) else destino_celda
			break
	if destino_celda == Vector2i(-1, -1):
		return
	var companero := MODELO_RELEVO.instantiate() as Node3D
	companero.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(companero)
	companero.scale = jugador.scale
	var inicio := grafo_piso.celda_a_posicion(inicio_celda)
	var destino := grafo_piso.celda_a_posicion(destino_celda)
	inicio.y = jugador.global_position.y
	destino.y = inicio.y
	companero.global_position = inicio
	var direccion := jugador.global_position - destino
	companero.rotation.y = atan2(direccion.x, direccion.z)
	var animador := companero.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if inicio_celda != destino_celda:
		_reproducir_animacion_relevo(animador, "walk")
		var movimiento := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		movimiento.tween_property(companero, "global_position", destino, 1.35)
		movimiento.finished.connect(_reproducir_animacion_relevo.bind(animador, "idle"))
	else:
		_reproducir_animacion_relevo(animador, "idle")


func _reproducir_animacion_relevo(animador: AnimationPlayer, nombre: String) -> void:
	if not is_instance_valid(animador):
		return
	for clip: StringName in animador.get_animation_list():
		if String(clip).to_lower().ends_with(nombre):
			animador.play(clip)
			return


func _reiniciar_despues_del_final() -> void:
	MenuGlobal.final_de_partida_activo = false
	MenuGlobal.omitir_tutorial_siguiente_partida = true
	get_tree().paused = false
	var error := get_tree().reload_current_scene()
	if error != OK:
		MenuGlobal.omitir_tutorial_siguiente_partida = false
		push_error("No se pudo reiniciar la partida: %s" % error_string(error))


func _volver_al_menu_despues_del_final() -> void:
	MenuGlobal.final_de_partida_activo = false
	MenuGlobal.volver_al_menu()


func interactuar_estacion_con_papel(portador: Player, estacion_id: String, objetivo: Node3D = null) -> void:
	var denuncia := sistema_despacho.obtener_denuncia_activa()
	if denuncia == null or not is_instance_valid(portador.papel_en_mano) or portador.papel_en_mano != papel_actual or portador.papel_en_mano.denuncia_id != denuncia.id:
		panel_despacho._mostrar_mensaje("Necesitas llevar la hoja de la denuncia para usar esta estación.", PanelDespacho.CORAL)
		return
	var tipo: StringName = &"interactuar"
	if estacion_id == "reporte" and _reporte_atascado_id == denuncia.id and _reporte_herramienta_recogida:
		tipo = &"reparar"
	portador.ejecutar_gesto(tipo, _resolver_gesto_estacion.bind(portador, estacion_id, denuncia.id), objetivo)


func _resolver_gesto_estacion(portador: Player, estacion_id: String, caso_id: String) -> void:
	# Un caso puede vencer durante el gesto: no completar ni puntuar uno distinto.
	var denuncia := sistema_despacho.obtener_denuncia_activa()
	if not is_instance_valid(portador) or denuncia == null or denuncia.id != caso_id:
		return
	if not is_instance_valid(portador.papel_en_mano) or portador.papel_en_mano != papel_actual:
		return
	interactuar_estacion(estacion_id)

func interactuar_estacion(estacion_id: String) -> void:
	if estacion_id == "reporte" and _interactuar_reporte():
		return
	if estacion_id == "evidencias" and _interactuar_evidencias():
		return
	if estacion_id == "verificacion" and _interactuar_verificacion():
		return
	if estacion_id == "privacidad":
		var denuncia := sistema_despacho.obtener_denuncia_activa()
		if denuncia != null and denuncia.obtener_estaciones_pendientes().has(estacion_id):
			if _denuncia_en_descriptado.is_empty():
				_denuncia_en_descriptado = denuncia.id
				_seguridad_lista = false
				progreso_seguridad.listo_para_recoger = false
				temporizador_seguridad.start()
				sonidos_mesas.iniciar_seguridad()
				progreso_seguridad.show()
				progreso_seguridad.actualizar(0.0, get_viewport().get_camera_3d(), _mesa_seguridad.global_position + Vector3.UP * 2.05)
				panel_despacho._mostrar_mensaje("Seguridad está desencriptando. Vuelve a recoger el archivo cuando termine.", Color("86efac"))
			elif _seguridad_lista and _denuncia_en_descriptado == denuncia.id:
				_cancelar_descriptado()
				_aplicar_estacion("privacidad")
			else:
				panel_despacho._mostrar_mensaje("Aún se está desencriptando. Vuelve cuando esté listo.", PanelDespacho.CORAL)
			return
	_aplicar_estacion(estacion_id)


func _interactuar_reporte() -> bool:
	var denuncia := sistema_despacho.obtener_denuncia_activa()
	if denuncia == null or not denuncia.obtener_estaciones_pendientes().has("reporte"):
		return false
	if _reporte_atascado_id == denuncia.id:
		if not _reporte_herramienta_recogida:
			panel_despacho._mostrar_mensaje("Impresora atascada. Busca la herramienta junto a la zona de descanso.", PanelDespacho.CORAL)
			return true
		_limpiar_atasco_reporte()
		sonidos_mesas.reparar_impresora()
		panel_despacho._mostrar_mensaje("Impresora reparada. Reporte entregado.", Color("86efac"))
		return false
	if generador_aleatorio.randf() < probabilidad_atasco_reporte:
		_reporte_atascado_id = denuncia.id
		_reporte_herramienta_recogida = false
		herramienta_reporte.establecer_activa(true)
		_aviso_reporte_atasco.visible = true
		sonidos_mesas.atascar_impresora()
		panel_despacho._mostrar_mensaje("Impresora atascada. Busca la herramienta junto a la zona de descanso y vuelve.", PanelDespacho.CORAL)
		return true
	sonidos_mesas.imprimir()
	return false


func recoger_herramienta_reporte(portador: Player) -> void:
	if portador != jugador or _reporte_atascado_id.is_empty() or not herramienta_reporte.activa:
		return
	_reporte_herramienta_recogida = true
	herramienta_reporte.establecer_activa(false)
	panel_despacho._mostrar_mensaje("Herramienta recogida. Vuelve a la mesa de reportes y pulsa E.", Color("86efac"))


func _limpiar_atasco_reporte() -> void:
	_reporte_atascado_id = ""
	_reporte_herramienta_recogida = false
	herramienta_reporte.establecer_activa(false)
	_aviso_reporte_atasco.visible = false


func _interactuar_evidencias() -> bool:
	var denuncia := sistema_despacho.obtener_denuncia_activa()
	if denuncia == null or not denuncia.obtener_estaciones_pendientes().has("evidencias"):
		return false
	clasificador_evidencias.iniciar(denuncia.id)
	jugador.input_locked = true
	panel_despacho._mostrar_mensaje("Elige las hojas solicitadas del planillero.", Color("86efac"))
	return true


func _al_archivar_evidencias(caso_id: String) -> void:
	var denuncia := sistema_despacho.obtener_denuncia_activa()
	if denuncia != null and denuncia.id == caso_id and denuncia.obtener_estaciones_pendientes().has("evidencias"):
		_aplicar_estacion("evidencias")


func _interactuar_verificacion() -> bool:
	var denuncia := sistema_despacho.obtener_denuncia_activa()
	if denuncia == null or not denuncia.obtener_estaciones_pendientes().has("verificacion"):
		return false
	escaner_verificacion.iniciar(denuncia.id)
	jugador.input_locked = true
	panel_despacho._mostrar_mensaje("Detén la línea coral dentro de la zona verde.", Color("86efac"))
	return true


func _al_terminar_verificacion(caso_id: String) -> void:
	var denuncia := sistema_despacho.obtener_denuncia_activa()
	if denuncia != null and denuncia.id == caso_id and denuncia.obtener_estaciones_pendientes().has("verificacion"):
		_aplicar_estacion("verificacion")


func _al_cerrar_tarea_estacion() -> void:
	jugador.input_locked = computador.is_using or evento_apagon.estado == EventoApagonScript.Estado.REPARANDO


func _aplicar_estacion(estacion_id: String) -> void:
	print("[Despacho] Se solicitó usar la estación: ", estacion_id)
	var fue_correcta: bool = sistema_despacho.interactuar_estacion(estacion_id)

	if fue_correcta:
		if estacion_id == "bienestar":
			sonidos_mesas.bienestar.play()
		print("Estación correcta: ", estacion_id)
	else:
		print("Estación incorrecta o no hay denuncia activa: ", estacion_id)


func _completar_descriptado() -> void:
	var denuncia := sistema_despacho.obtener_denuncia_activa()
	var validar := denuncia != null and denuncia.id == _denuncia_en_descriptado and denuncia.obtener_estaciones_pendientes().has("privacidad")
	if validar:
		_seguridad_lista = true
		sonidos_mesas.terminar_seguridad()
		progreso_seguridad.listo_para_recoger = true
		panel_despacho._mostrar_mensaje("Archivo listo. Vuelve a seguridad y pulsa E para recogerlo.", Color("86efac"))
	else:
		_cancelar_descriptado()


func _cancelar_descriptado() -> void:
	sonidos_mesas.cancelar_seguridad()
	temporizador_seguridad.stop()
	_denuncia_en_descriptado = ""
	_seguridad_lista = false
	progreso_seguridad.listo_para_recoger = false
	progreso_seguridad.hide()




func _calcular_ruta_a_proxima_estacion() -> void:
	var denuncia: Denuncia = sistema_despacho.obtener_denuncia_activa()
	_denuncia_orientada_id = denuncia.id if denuncia != null else ""
	_estaciones_pendientes.clear()
	if denuncia != null:
		_estaciones_pendientes = denuncia.obtener_estaciones_pendientes()
	_celda_ruta = grafo_piso.posicion_a_celda(jugador.global_position)
	var destinos: Array[Vector2i] = []
	for estacion_id: String in _estaciones_pendientes:
		if GrafoPiso.DESTINOS.has(estacion_id):
			destinos.append(GrafoPiso.DESTINOS[estacion_id])
	var origen: Vector2i = grafo_piso.celda_de_acceso(jugador.global_position)
	ruta_actual = grafo_piso.calcular_ruta_a_mas_cercana(origen, destinos)
	estacion_sugerida = ""
	if not ruta_actual.is_empty():
		for estacion_id: String in _estaciones_pendientes:
			if GrafoPiso.DESTINOS.get(estacion_id) == ruta_actual.back():
				estacion_sugerida = estacion_id
				break
	depurador_grafo.actualizar_ruta(ruta_actual)
	_actualizar_indicadores_estaciones()


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


func _actualizar_indicadores_estaciones() -> void:
	for estacion_id: String in indicadores_estaciones:
		var indicador := indicadores_estaciones[estacion_id] as IndicadorProximaEstacion
		if is_instance_valid(indicador):
			var activo := _estaciones_pendientes.has(estacion_id)
			if indicador.visible != activo or indicador.is_processing() != activo:
				indicador.establecer_activo(activo)
	guia_estacion.establecer_objetivo(indicadores_estaciones.get(estacion_sugerida) as IndicadorProximaEstacion)


func _on_denuncias_actualizadas(_denuncias: Array[Denuncia]) -> void:
	# Esta señal llega después de limpiar el caso activo al resolver o vencer.
	# Los cambios en otros casos de la cola no alteran la orientación del activo.
	_sincronizar_indicador_con_despacho()


func _on_estacion_completada(_denuncia: Denuncia, _estacion_id: String) -> void:
	jugador.reproducir_expresion(&"alegria")
	_sincronizar_indicador_con_despacho()


func _sincronizar_indicador_con_despacho() -> void:
	var denuncia := sistema_despacho.obtener_denuncia_activa()
	var id := denuncia.id if denuncia != null else ""
	var pendientes: Array[String] = []
	if denuncia != null:
		pendientes = denuncia.obtener_estaciones_pendientes()
	if id != _denuncia_orientada_id or pendientes != _estaciones_pendientes:
		_calcular_ruta_a_proxima_estacion()


func _on_temporizador_bloqueos_timeout() -> void:
	_cambiar_bloqueo_temporal()
	
func _cambiar_bloqueo_temporal() -> void:
	if evento_terremoto.activo:
		return
	_limpiar_bloqueos_temporales()

	var celda_jugador: Vector2i = grafo_piso.celda_de_acceso(
		jugador.global_position
	)

	var destinos_protegidos: Array[Vector2i] = []
	var libres_al_inicio := grafo_piso.celdas_alcanzables(celda_jugador)
	var minimo_libres := mini(2, libres_al_inicio.size())
	for destino: Vector2i in GrafoPiso.DESTINOS.values():
		if libres_al_inicio.has(destino):
			destinos_protegidos.append(destino)
	# Mantiene conectada la zona de descanso aunque el jugador esté en el laberinto.
	for acceso: Node in get_tree().get_nodes_in_group("accesos_navegacion"):
		if acceso is Node3D and is_ancestor_of(acceso):
			var destino := grafo_piso.posicion_a_celda((acceso as Node3D).global_position)
			if libres_al_inicio.has(destino) and not destinos_protegidos.has(destino):
				destinos_protegidos.append(destino)

	var colision := jugador.get_node("Colision") as CollisionShape3D
	var limites := colision.global_transform * colision.shape.get_debug_mesh().get_aabb()
	var huella_jugador := Rect2(
		Vector2(limites.position.x, limites.position.z),
		Vector2(limites.size.x, limites.size.z)
	).grow(jugador.safe_margin)
	var tamano_celda := Vector2.ONE * GrafoPiso.TAMANO_CELDA
	var huella_papel := _huella_papel_suelto()

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
			# El cajón ocupa toda su celda. El jugador puede estar apoyado
			# sobre el borde de la celda vecina al cambiar la distribución.
			var centro := grafo_piso.celda_a_posicion(celda)
			var huella_cajon := Rect2(Vector2(centro.x, centro.z) - tamano_celda * 0.5, tamano_celda)
			if huella_cajon.intersects(huella_jugador):
				continue
			if huella_papel.has_area() and huella_cajon.intersects(huella_papel):
				continue

			candidatos.append(celda)

	var bloqueos_colocados: int = 0
	while not candidatos.is_empty() and bloqueos_colocados < BLOQUEOS_SIMULTANEOS:
		var indice: int = generador_aleatorio.randi_range(
			0,
			candidatos.size() - 1
		)

		var candidata: Vector2i = candidatos[indice]
		candidatos.remove_at(indice)

		grafo_piso.bloqueos_temporales[candidata] = true
		var libres := grafo_piso.celdas_alcanzables(celda_jugador)
		var hay_ruta := libres.size() >= minimo_libres
		for destino: Vector2i in destinos_protegidos:
			if not libres.has(destino):
				hay_ruta = false
				break

		if hay_ruta:
			_mostrar_bloqueo_temporal(candidata)
			bloqueos_colocados += 1
			continue

		grafo_piso.bloqueos_temporales.erase(candidata)

	grafo_piso.construir_adyacencia()
	depurador_grafo.actualizar_mapa()
	_calcular_ruta_a_proxima_estacion()

	if bloqueos_colocados < BLOQUEOS_SIMULTANEOS:
		print(
			"Solo se colocaron %d de %d bloqueos sin cerrar la ruta."
			% [bloqueos_colocados, BLOQUEOS_SIMULTANEOS]
		)
	else:
		print("Bloqueos temporales activos: ", bloqueos_colocados)


func _huella_papel_suelto() -> Rect2:
	if not is_instance_valid(papel_actual) or papel_actual.portador != null:
		return Rect2()
	var posicion := Vector2(papel_actual.global_position.x, papel_actual.global_position.z)
	var tamano := Vector2(PapelDenuncia.TAMANO.x, PapelDenuncia.TAMANO.z)
	var actual := Rect2(posicion - tamano * 0.5, tamano)
	# Reservar también el trayecto breve si cambia la distribución durante el vuelo.
	var avance := Vector2(papel_actual.linear_velocity.x, papel_actual.linear_velocity.z) * 0.65
	return actual.merge(Rect2(actual.position + avance, tamano)).grow(0.15)

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
	var bloqueo_visual: StaticBody3D
	if _bloqueos_disponibles.is_empty():
		bloqueo_visual = _crear_bloqueo_pool()
	else:
		bloqueo_visual = _bloqueos_disponibles.pop_back()
	bloqueos_visuales[celda] = bloqueo_visual
	bloqueo_visual.call("activar_en", grafo_piso.celda_a_posicion(celda))


func _limpiar_bloqueos_temporales() -> void:
	var habia_bloqueos := not bloqueos_visuales.is_empty()
	for bloqueo_visual: Node3D in bloqueos_visuales.values():
		if is_instance_valid(bloqueo_visual):
			if _bloqueos_pool.has(bloqueo_visual):
				bloqueo_visual.call("desactivar")
				_bloqueos_disponibles.append(bloqueo_visual as StaticBody3D)
			else:
				bloqueo_visual.queue_free()
	# Despierta la hoja si perdió el apoyo de un cajón reciclado.
	if habia_bloqueos and is_instance_valid(papel_actual) and papel_actual.portador == null:
		papel_actual.sleeping = false

	bloqueos_visuales.clear()
	grafo_piso.bloqueos_temporales.clear()
	grafo_piso.construir_adyacencia()
