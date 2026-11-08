extends Node
## El brillo debe coincidir con el objetivo físico real de la tecla E.
## Ejecutar esta escena; -- --capturas guarda lejos/cerca/salida en la oficina.

const MODELOS := preload("res://MarcadoresEstaciones/modelos_marcador.gd")
const INDICADOR := preload("res://Scripts/indicador_proxima_estacion.gd")
const CLASIFICADOR := preload("res://UI/Despacho/clasificador_evidencias.gd")

var _errores: Array[String] = []
var _comprobaciones: int = 0
var _oficina: Node3D
var _jugador: Player
var _sistema: SistemaDespacho
var _indicadores: Dictionary
var _estaciones: Dictionary = {}
var _camara: Camera3D
var _altura_pies: float


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	call_deferred("_probar")


func _probar() -> void:
	_oficina = preload("res://Oficina.tscn").instantiate()
	_oficina.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_oficina)
	await _fisicas(3)
	_oficina.temporizador_denuncias.stop()
	_oficina.temporizador_bloqueos.stop()
	_oficina.probabilidad_atasco_reporte = 0.0
	_oficina.computador.timer_nuevo_problema.stop()
	_sistema = _oficina.sistema_despacho
	_sistema.set_process(false)
	_jugador = _oficina.jugador
	_camara = _oficina.get_node("Gameplay/Camera3D") as Camera3D
	_indicadores = _oficina.indicadores_estaciones
	for nodo: Node in _oficina.find_children("*", "Estacion", true, false):
		var estacion := nodo as Estacion
		_estaciones[estacion.estacion_id] = estacion
	# Deja que el cuerpo real aterrice antes de fijar su posición para el piloto.
	await _fisicas(60)
	_verificar(_jugador.is_on_floor(), "El personaje real está apoyado en el suelo de la oficina")
	_altura_pies = _jugador.global_position.y
	_jugador.set_physics_process(false)
	_camara.set_physics_process(false)
	_oficina.depurador_grafo.hide()
	await get_tree().process_frame
	await get_tree().process_frame
	_verificar(not (_oficina.get("_aviso_apagon") as Label).visible, "Luz restaurada se oculta fuera de la vista F3")
	_verificar(not _oficina.indicador_papel.visible, "El medallón empieza oculto sin papel en mano")
	_validar_geometria()
	_validar_interactuables("", "sin denuncia activa")
	var materiales_originales := _estado_materiales(_indicadores["reporte"] as Node3D)
	var modelo_reserva := MODELOS.crear("bienestar")
	var materiales_reserva := _estado_materiales(modelo_reserva)
	var caso := _recibir_caso("ALCANCE-REAL", ["bienestar"])
	var bienestar := _indicadores["bienestar"] as IndicadorProximaEstacion
	var normal_bienestar := _estado_materiales(bienestar)
	var postura := _buscar_postura(_estaciones["bienestar"] as Estacion)
	_verificar(not postura.is_empty(), "El ShapeCast3D existente alcanza bienestar desde su aproximación")
	if not postura.is_empty():
		await _probar_entrada_y_salida(bienestar, postura, normal_bienestar)
		await _probar_estacion_incorrecta(postura)
		await _probar_bloqueos(bienestar, postura, normal_bienestar)
		_verificar(_estado_materiales(_indicadores["reporte"] as Node3D) == materiales_originales, "Iluminar bienestar conserva los materiales de otra estación")
		_verificar(_estado_materiales(modelo_reserva) == materiales_reserva, "El efecto conserva los materiales compartidos de modelos nuevos")
		await _probar_protocolo_con_tecla(caso, postura)
	else:
		_sistema.resolver_denuncia(caso.id)
	modelo_reserva.free()
	await _probar_vencimiento()
	await _probar_orden_libre_con_tecla()
	await _probar_cancelar_seguridad()
	await _probar_cancelar_evidencias()
	await _probar_atasco_reporte()
	await _probar_silla_computador()
	await _probar_papel_sin_mesa_encima()
	await _probar_caida_sobre_mesa_temporal()
	await _probar_reconfiguracion()
	get_tree().paused = false
	_oficina.queue_free()
	await get_tree().process_frame
	print("[INTERACCION MARCADORES] %d comprobaciones, %d errores." % [_comprobaciones, _errores.size()])
	get_tree().quit(0 if _errores.is_empty() else 1)


func _probar_entrada_y_salida(indicador: IndicadorProximaEstacion, postura: Dictionary, normales: Dictionary) -> void:
	_colocar(postura["lejos"], float(postura["giro"]))
	await _esperar_efecto()
	_verificar(_jugador.obtener_objetivo_interaccion() != _estaciones["bienestar"], "Fuera del alcance real E no apunta a bienestar")
	_validar_interactuables("", "lejos de la estación objetivo")
	_verificar(_estado_materiales(indicador) == normales, "Lejos conserva la emisión normal sin contorno")
	await _capturar("01_fuera_de_alcance")
	_colocar(postura["cerca"], float(postura["giro"]))
	await _esperar_efecto()
	_verificar(_jugador.obtener_objetivo_interaccion() == _estaciones["bienestar"], "Al entrar E alcanza exactamente la estación objetivo")
	_validar_interactuables("bienestar", "al entrar mirando hacia la estación")
	_verificar(_emision_maxima(indicador) > _emision_estado(normales) + 0.001, "Entrar eleva la emisión del modelo real")
	_verificar(_tiene_contorno(indicador), "Entrar añade el contorno de disponibilidad")
	var energia_primera := _emision_maxima(indicador)
	await get_tree().create_timer(0.19).timeout
	_verificar(not is_equal_approx(_emision_maxima(indicador), energia_primera), "La iluminación pulsa mientras la estación es interactuable")
	await _capturar("02_dentro_de_alcance")
	_colocar(postura["cerca"], float(postura["giro"]) + PI)
	await _esperar_efecto()
	_verificar(_jugador.global_position.is_equal_approx(postura["cerca"]), "Mirar hacia otro lado no altera la distancia del personaje")
	_verificar(_jugador.obtener_objetivo_interaccion() != _estaciones["bienestar"], "La orientación contraria retira el objetivo físico de E")
	_validar_interactuables("", "cerca pero mirando hacia otro lado")
	_verificar(_estado_materiales(indicador) == normales, "Mirar hacia otro lado retira emisión y contorno")
	_colocar(postura["cerca"], float(postura["giro"]))
	await _esperar_efecto()
	_validar_interactuables("bienestar", "al volver a mirar hacia la estación")
	_colocar(postura["lejos"], float(postura["giro"]))
	await _esperar_efecto()
	_validar_interactuables("", "al salir del alcance físico")
	_verificar(_estado_materiales(indicador) == normales, "Salir restaura el material normal tras la transición")
	await _capturar("03_al_salir")
	_colocar(postura["cerca"], float(postura["giro"]))
	await _esperar_efecto()
	_validar_interactuables("bienestar", "al volver a entrar")


func _probar_estacion_incorrecta(postura_bienestar: Dictionary) -> void:
	var incorrecta := _estaciones["reporte"] as Estacion
	var postura := _buscar_postura(incorrecta)
	_verificar(not postura.is_empty(), "El ShapeCast3D existente puede apuntar a otra estación física")
	if not postura.is_empty():
		_colocar(postura["cerca"], float(postura["giro"]))
		await _esperar_efecto()
		_verificar(_jugador.obtener_objetivo_interaccion() == incorrecta, "E apunta a reporte, aunque el protocolo requiere bienestar")
		_validar_interactuables("", "junto a una estación que no es la requerida")
		_verificar((_indicadores["bienestar"] as Node3D).visible and not (_indicadores["reporte"] as Node3D).visible, "La estación incorrecta conserva el único marcador del objetivo real")
	_colocar(postura_bienestar["cerca"], float(postura_bienestar["giro"]))
	await _esperar_efecto()


func _probar_bloqueos(indicador: IndicadorProximaEstacion, postura: Dictionary, normales: Dictionary) -> void:
	_jugador.input_locked = true
	await _esperar_efecto()
	_verificar(_jugador.obtener_objetivo_interaccion() == null, "Bloquear la entrada elimina el objetivo de E")
	_validar_interactuables("", "con entrada bloqueada")
	_verificar(_estado_materiales(indicador) == normales, "La entrada bloqueada apaga el efecto")
	_jugador.input_locked = false
	await _esperar_efecto()
	_validar_interactuables("bienestar", "al recuperar la entrada")
	_jugador.set_process_input(false)
	await _esperar_efecto()
	_verificar(_jugador.obtener_objetivo_interaccion() == null, "Desactivar el procesamiento de entrada elimina el objetivo de E")
	_validar_interactuables("", "sin procesamiento de entrada")
	_jugador.set_process_input(true)
	await _esperar_efecto()
	# Aísla la guarda del computador: aquí E aún alcanzaría físicamente la estación.
	_oficina.computador.is_using = true
	await _esperar_efecto()
	_verificar(not _oficina.indicador_papel.visible, "El computador oculta el aviso de soltar")
	_verificar(_jugador.obtener_objetivo_interaccion() == _estaciones["bienestar"], "La comprobación del computador no cambia el alcance del ShapeCast3D")
	_validar_interactuables("", "mientras se usa el computador")
	_oficina.computador.is_using = false
	await _esperar_efecto()
	_verificar(_oficina.indicador_papel.visible, "Cerrar el computador recupera el medallón del papel llevado")
	_validar_interactuables("bienestar", "al cerrar el computador")
	get_tree().paused = true
	_verificar(_jugador.obtener_objetivo_interaccion() == null, "La pausa impide que E devuelva un objetivo")
	var energia_pausada := _emision_maxima(indicador)
	await get_tree().create_timer(0.15).timeout
	_verificar(is_equal_approx(_emision_maxima(indicador), energia_pausada), "La pausa congela el pulso junto con la partida")
	get_tree().paused = false
	_colocar(postura["cerca"], float(postura["giro"]))
	await _esperar_efecto()
	_validar_interactuables("bienestar", "tras reanudar la partida")


func _probar_protocolo_con_tecla(caso: Denuncia, postura: Dictionary) -> void:
	_colocar(postura["cerca"], float(postura["giro"]))
	await _esperar_efecto()
	_pulsar_interaccion()
	await get_tree().process_frame
	_verificar(caso.estaciones_completadas == ["bienestar"], "La misma tecla E completa la estación iluminada")
	_verificar(caso.estado == Denuncia.Estado.RESUELTA, "E en bienestar resuelve su protocolo completo")
	_verificar(not _oficina.indicador_papel.visible, "Resolver el caso retira el medallón junto con la hoja")
	_validar_interactuables("", "al resolver el primer protocolo")
	for indicador: IndicadorProximaEstacion in _indicadores.values():
		_verificar(not indicador.visible and is_zero_approx(float(indicador.get("_intensidad_interaccion"))), "Resolver oculta y reinicia el efecto de " + indicador.estacion_id)
	var caso_reporte := _recibir_caso("REPORTE-CON-TECLA", ["reporte"])
	_validar_interactuables("", "al pasar a reporte estando aún en bienestar")
	var postura_reporte := _buscar_postura(_estaciones["reporte"] as Estacion)
	_verificar(not postura_reporte.is_empty(), "Reporte es físicamente accesible para terminar el protocolo")
	if postura_reporte.is_empty():
		_sistema.resolver_denuncia(caso_reporte.id)
		return
	_colocar(postura_reporte["cerca"], float(postura_reporte["giro"]))
	await _esperar_efecto()
	_validar_interactuables("reporte", "antes de resolver la última estación")
	_pulsar_interaccion()
	await get_tree().process_frame
	_verificar(caso_reporte.estado == Denuncia.Estado.RESUELTA, "E en reporte también resuelve el caso")
	_validar_interactuables("", "al resolver el caso completo")
	for indicador: IndicadorProximaEstacion in _indicadores.values():
		_verificar(not indicador.visible and is_zero_approx(float(indicador.get("_intensidad_interaccion"))), "Resolver oculta y reinicia el efecto de " + indicador.estacion_id)


func _probar_orden_libre_con_tecla() -> void:
	var caso := _recibir_caso("ORDEN-LIBRE-CON-TECLA", ["evidencias", "verificacion", "privacidad", "reporte"])
	await _probar_hud_papel_adaptable()
	var hoja := _jugador.papel_en_mano
	_verificar(is_instance_valid(hoja) and hoja.denuncia_id == caso.id, "El computador entrega una hoja vinculada al caso")
	_verificar(_oficina.panel_despacho.mensaje_estacion.text == "Ve con la denuncia.", "El aviso verde muestra solo la instrucción breve")
	if is_instance_valid(hoja):
		hoja.lanzar()
		_verificar(_jugador.papel_en_mano == null and hoja.portador == null and not hoja.freeze, "E puede lanzar la hoja física")
		_verificar((_jugador.collision_mask & hoja.collision_layer) == 0 and (hoja.collision_mask & 1) != 0, "La hoja choca con el suelo pero no con el jugador")
		_verificar((hoja.get_node("HojaVisual") as MeshInstance3D).material_overlay != null, "La hoja suelta usa el contorno de interacción")
		var marcador := hoja.get_node("MarcadorRecoger") as Node3D
		_verificar(marcador.visible and marcador.has_node("ManoRecoger/ManoGuante") and (marcador.get_node("LetraE") as Label3D).text == "E", "La hoja suelta muestra una mano modelada y la tecla E")
		_verificar(Vector2(hoja.linear_velocity.x, hoja.linear_velocity.z).length() <= 1.5, "La hoja sale con un impulso corto")
		_oficina.interactuar_estacion_con_papel(_jugador, "reporte")
		_verificar(caso.estaciones_completadas.is_empty(), "Sin llevar la hoja, las estaciones rechazan el trámite")
		await get_tree().process_frame
		_verificar(_jugador.obtener_objetivo_interaccion() == hoja, "La hoja lanzada queda al alcance de E")
		_verificar(not _oficina.indicador_papel.visible, "Soltar la hoja oculta el medallón")
		var aviso := _oficina.get("_aviso_apagon") as Label
		_verificar(aviso.get_global_rect().end.y > get_viewport().get_visible_rect().size.y * 0.95, "Sin papel, el aviso de luz regresa al borde inferior")
		await _capturar("06_hoja_suelta")
		_pulsar_interaccion()
		await get_tree().process_frame
		_verificar(_jugador.papel_en_mano == hoja and hoja.freeze, "E recoge la hoja y conserva su caso")
		_verificar(_oficina.indicador_papel.visible, "Recoger la hoja con E vuelve a mostrar el medallón")
		_verificar((hoja.get_node("HojaVisual") as MeshInstance3D).material_overlay == null, "La hoja en mano retira el contorno del suelo")
		_verificar(not (hoja.get_node("MarcadorRecoger") as Node3D).visible, "La mano de recogida desaparece al llevar la hoja")
	var panel := _oficina.panel_despacho as PanelDespacho
	var saldo := _sistema.puntuacion.puntos
	var orden: Array[String] = ["reporte", "privacidad", "verificacion", "evidencias"]
	await _capturar("04_todas_pendientes")
	for estacion_id: String in orden:
		var postura := _buscar_postura(_estaciones[estacion_id] as Estacion)
		_verificar(not postura.is_empty(), "La estación %s es accesible para completarla fuera de orden" % estacion_id)
		if postura.is_empty():
			return
		_colocar(postura["cerca"], float(postura["giro"]))
		await _esperar_efecto()
		_validar_interactuables(estacion_id, "al elegir libremente " + estacion_id)
		_pulsar_interaccion()
		await get_tree().process_frame
		if estacion_id == "privacidad":
			_verificar(not caso.estaciones_completadas.has("privacidad") and _oficina.temporizador_seguridad.time_left > 5.0 and _oficina.progreso_seguridad.visible, "Seguridad empieza seis segundos de desencriptado sin completar la mesa al instante")
			var tiempo_inicial: float = _oficina.temporizador_seguridad.time_left
			_pulsar_interaccion()
			await get_tree().process_frame
			_verificar(_oficina.temporizador_seguridad.time_left <= tiempo_inicial and not caso.estaciones_completadas.has("privacidad"), "Repetir E no reinicia ni duplica el desencriptado")
			await get_tree().create_timer(1.0).timeout
			_verificar(_oficina.progreso_seguridad.proporcion > 0.1 and _oficina.progreso_seguridad.proporcion < 0.5, "La barra aumenta mientras transcurre el desencriptado")
			await _capturar("10_seguridad_desencriptando")
			_colocar(postura["lejos"], float(postura["giro"]))
			_verificar(_jugador.obtener_objetivo_interaccion() != _estaciones["privacidad"] and _oficina.temporizador_seguridad.time_left > 0.0, "El desencriptado sigue mientras el jugador se aleja de la mesa")
			var restante: float = _oficina.temporizador_seguridad.time_left
			get_tree().paused = true
			await get_tree().create_timer(0.25).timeout
			_verificar(absf(_oficina.temporizador_seguridad.time_left - restante) < 0.05, "La pausa detiene el desencriptado")
			get_tree().paused = false
			await _oficina.temporizador_seguridad.timeout
			await get_tree().process_frame
			_verificar(_oficina.progreso_seguridad.visible and _oficina.progreso_seguridad.listo_para_recoger and not caso.estaciones_completadas.has("privacidad"), "Al terminar, seguridad queda lista y exige volver a recoger")
			await _capturar("13_seguridad_lista")
			_colocar(postura["cerca"], float(postura["giro"]))
			await get_tree().process_frame
			_pulsar_interaccion()
			await get_tree().process_frame
			_verificar(not _oficina.progreso_seguridad.visible, "Recoger con E oculta ambas barras")
		elif estacion_id == "evidencias":
			var clasificador: CLASIFICADOR = _oficina.clasificador_evidencias
			_verificar(clasificador.visible and caso.estaciones_completadas.has("evidencias") == false, "E en evidencias abre tres documentos por clasificar")
			await _capturar("11_evidencias_clasificacion")
			clasificador.seleccion = (clasificador.documentos[0] + 1) % 3
			_pulsar_tecla(KEY_E)
			await get_tree().process_frame
			_verificar(clasificador.archivados == 0, "Una bandeja equivocada no archiva el documento")
			clasificador.seleccion = clasificador.documentos[0]
			_pulsar_tecla(KEY_E)
			await get_tree().process_frame
			_pulsar_tecla(KEY_ESCAPE)
			await get_tree().process_frame
			_verificar(not clasificador.visible and clasificador.archivados == 1 and not _jugador.input_locked, "Salir del clasificador conserva el primer documento archivado")
			_pulsar_interaccion()
			await get_tree().process_frame
			_verificar(clasificador.visible and clasificador.archivados == 1, "Volver a evidencias reanuda la clasificación")
			for numero: int in range(1, 3):
				clasificador.seleccion = clasificador.documentos[numero]
				_pulsar_tecla(KEY_E)
				await get_tree().process_frame
			_verificar(not clasificador.visible and not _jugador.input_locked, "Archivar tres documentos cierra el clasificador y libera al jugador")
		_verificar(caso.estaciones_completadas.has(estacion_id), "E completa %s sin exigir otra estación primero" % estacion_id)
		for id: String in _indicadores:
			_verificar((_indicadores[id] as Node3D).visible == caso.obtener_estaciones_pendientes().has(id), "Solo permanecen visibles las estaciones pendientes")
		if caso.estado == Denuncia.Estado.EN_PROCESO:
			_verificar(panel.protocolo.completadas == caso.estaciones_completadas, "El panel marca la estación realmente visitada")
			_verificar(_sistema.puntuacion.puntos == saldo, "Un caso incompleto no da puntos")
			_pulsar_interaccion()
			await get_tree().process_frame
			_verificar(panel.mensaje_estacion.text.begins_with("Ya completaste"), "Repetir una estación muestra un aviso específico")
			_verificar(caso.estaciones_completadas.size() == orden.find(estacion_id) + 1, "Repetir E conserva el avance")
			if estacion_id == "reporte":
				await _capturar("05_reporte_primero")
	_verificar(caso.estado == Denuncia.Estado.RESUELTA and _sistema.obtener_denuncia_activa() == null, "La última estación pendiente cierra el caso sin volver al computador")
	_verificar(_jugador.papel_en_mano == null and _oficina.papel_actual == null, "Resolver retira la hoja del caso")
	_verificar(_sistema.puntuacion.puntos == saldo + caso.obtener_puntaje_recompensa(), "El cierre libre concede una sola recompensa")
	_verificar(not panel.denuncia_activa_detalle.visible and not _oficina.guia_estacion.visible and _oficina.ruta_actual.is_empty(), "Cerrar retira tarjeta, guía y ruta")


func _probar_cancelar_seguridad() -> void:
	var caso := _recibir_caso("SEGURIDAD-VENCE", ["privacidad"])
	var postura := _buscar_postura(_estaciones["privacidad"] as Estacion)
	_verificar(not postura.is_empty(), "La mesa de seguridad es accesible para el caso de vencimiento")
	if postura.is_empty():
		_sistema.vencer_denuncia(caso.id)
		return
	_colocar(postura["cerca"], float(postura["giro"]))
	await _esperar_efecto()
	_pulsar_interaccion()
	await get_tree().process_frame
	_verificar(_oficina.temporizador_seguridad.time_left > 0.0 and _oficina.progreso_seguridad.visible, "La barra está activa antes de vencer el caso")
	_sistema.vencer_denuncia(caso.id)
	_verificar(_oficina.temporizador_seguridad.is_stopped() and not _oficina.progreso_seguridad.visible and caso.estaciones_completadas.is_empty(), "Vencer el caso cancela la tarea sin completar la estación")


func _probar_cancelar_evidencias() -> void:
	var caso := _recibir_caso("EVIDENCIAS-VENCE", ["evidencias"])
	var postura := _buscar_postura(_estaciones["evidencias"] as Estacion)
	_verificar(not postura.is_empty(), "Evidencias es accesible antes de vencer")
	if postura.is_empty():
		_sistema.vencer_denuncia(caso.id)
		return
	_colocar(postura["cerca"], float(postura["giro"]))
	await _esperar_efecto()
	_pulsar_interaccion()
	await get_tree().process_frame
	_verificar(_oficina.clasificador_evidencias.visible and _jugador.input_locked, "La clasificación inmoviliza al jugador mientras está abierta")
	_sistema.vencer_denuncia(caso.id)
	_verificar(not _oficina.clasificador_evidencias.visible and not _jugador.input_locked and caso.estaciones_completadas.is_empty(), "Vencer cancela el clasificador y devuelve el control")


func _probar_atasco_reporte() -> void:
	_oficina.probabilidad_atasco_reporte = 1.0
	var caso := _recibir_caso("REPORTE-ATASCADO", ["reporte"])
	var postura := _buscar_postura(_estaciones["reporte"] as Estacion)
	_verificar(not postura.is_empty(), "Reporte sigue accesible cuando se atasca")
	if postura.is_empty():
		_sistema.vencer_denuncia(caso.id)
		return
	_colocar(postura["cerca"], float(postura["giro"]))
	await _esperar_efecto()
	_pulsar_interaccion()
	await get_tree().process_frame
	_verificar(caso.estaciones_completadas.is_empty() and _oficina.herramienta_reporte.activa, "El atasco impide completar reporte y hace aparecer la herramienta")
	await _capturar("12_reporte_atascado")
	_pulsar_interaccion()
	await get_tree().process_frame
	_verificar(caso.estaciones_completadas.is_empty(), "Insistir sin herramienta conserva el atasco")
	var herramienta := _oficina.herramienta_reporte as StaticBody3D
	var alcanzable := false
	for distancia: float in [0.55, 0.45, 0.35, 0.25]:
		_colocar(Vector3(herramienta.global_position.x, _altura_pies, herramienta.global_position.z - distancia), 0.0)
		await get_tree().physics_frame
		if _jugador.obtener_objetivo_interaccion() == herramienta:
			alcanzable = true
			break
	_verificar(alcanzable, "La herramienta se puede recoger con E en una casilla del suelo")
	if alcanzable:
		await _esperar_efecto()
		_verificar(_jugador.obtener_objetivo_interaccion() == herramienta, "E conserva la herramienta como objetivo tras entrar en alcance")
		await _capturar("14_herramienta_impresora")
		_pulsar_interaccion()
	else:
		_oficina.herramienta_reporte.interactuar(_jugador)
	await get_tree().process_frame
	_verificar(not _oficina.herramienta_reporte.activa, "Recoger la herramienta retira su objeto físico")
	_colocar(postura["cerca"], float(postura["giro"]))
	await get_tree().process_frame
	_pulsar_interaccion()
	await get_tree().process_frame
	_verificar(caso.estado == Denuncia.Estado.RESUELTA and not _oficina._aviso_reporte_atasco.visible, "Volver con la herramienta repara la impresora y completa reporte")
	var caso_vencido := _recibir_caso("REPORTE-VENCE", ["reporte"])
	_colocar(postura["cerca"], float(postura["giro"]))
	await _esperar_efecto()
	_pulsar_interaccion()
	await get_tree().process_frame
	_verificar(_oficina.herramienta_reporte.activa, "Un nuevo atasco activa su herramienta")
	_sistema.vencer_denuncia(caso_vencido.id)
	_verificar(not _oficina.herramienta_reporte.activa and not _oficina._aviso_reporte_atasco.visible, "Vencer retira la herramienta y el aviso de atasco")
	_oficina.probabilidad_atasco_reporte = 0.0


func _probar_silla_computador() -> void:
	var silla := _oficina.get_node("Mesas Horizontales UP/Table_010/Chair_002/InteraccionComputador") as SillaComputador
	_verificar(is_instance_valid(silla), "La silla frente al computador ofrece la interacción")
	if not is_instance_valid(silla):
		return
	_verificar((_jugador.collision_mask & silla.collision_layer) == 0, "La zona de interacción de la silla no bloquea al personaje")
	var caso := Denuncia.new()
	caso.id = "PC-DESDE-SILLA"
	caso.protocolo_estaciones = ["reporte"]
	caso.tiempo_limite_segundos = 120.0
	_sistema.recibir_denuncia(caso)
	var al_alcance := false
	var colision := _jugador.get_node("Colision") as CollisionShape3D
	for distancia: float in [0.55, 0.65, 0.75, 0.85]:
		_colocar(Vector3(silla.global_position.x, _altura_pies, silla.global_position.z + distancia), PI)
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = colision.shape
		consulta.transform = colision.global_transform
		consulta.collision_mask = 1
		consulta.exclude = [_jugador.get_rid()]
		var espacio_libre := _jugador.get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty()
		if espacio_libre and _jugador.obtener_objetivo_interaccion() == silla:
			al_alcance = true
			break
	_verificar(al_alcance, "E alcanza la silla desde delante sin pegarse a la pantalla")
	if al_alcance:
		_pulsar_interaccion()
		await get_tree().process_frame
		_verificar(_sistema.obtener_denuncia_activa() == caso and is_instance_valid(_jugador.papel_en_mano), "E en la silla entrega la denuncia del computador")
		_verificar(not _oficina.computador.is_using and not _jugador.input_locked, "La silla no abre el panel ni inmoviliza al jugador")
	_sistema.resolver_denuncia(caso.id)


func _probar_papel_sin_mesa_encima() -> void:
	_oficina._limpiar_bloqueos_temporales()
	var grafo_original := _oficina.grafo_piso as GrafoPiso
	_jugador.global_position = grafo_original.celda_a_posicion(Vector2i(7, 15)) + Vector3.UP * _altura_pies
	_jugador.visual.rotation.y = 0.0
	var papel := PapelDenuncia.new()
	_oficina.add_child(papel)
	_oficina.papel_actual = papel
	papel.tomar(_jugador)
	var salida := _jugador.global_position
	papel.lanzar()
	await _fisicas(90)
	var distancia := Vector2(papel.global_position.x - salida.x, papel.global_position.z - salida.z).length()
	_verificar(distancia < 1.2, "La hoja cae cerca del jugador después del lanzamiento completo")
	papel.freeze = true
	papel.linear_velocity = Vector3.ZERO
	papel.angular_velocity = Vector3.ZERO
	var limitado := GrafoPiso.new()
	var libres: Array[Vector2i] = [Vector2i(7, 15)]
	for x: int in range(4, 11):
		libres.append(Vector2i(x, 14))
	var huecos: Array[Vector2i] = [Vector2i(5, 13), Vector2i(7, 13), Vector2i(9, 13)]
	libres.append_array(huecos)
	limitado.bloqueos_fijos.clear()
	for fila: int in range(GrafoPiso.FILAS):
		for columna: int in range(GrafoPiso.COLUMNAS):
			var celda := Vector2i(columna, fila)
			if not libres.has(celda):
				limitado.bloqueos_fijos[celda] = true
	limitado.construir_adyacencia()
	_oficina.grafo_piso = limitado
	_oficina.depurador_grafo.grafo = limitado
	_jugador.global_position = limitado.celda_a_posicion(Vector2i(7, 15)) + Vector3.UP * _altura_pies
	papel.global_position = limitado.celda_a_posicion(huecos[1]) + Vector3.UP * 0.1
	_oficina._cambiar_bloqueo_temporal()
	_verificar(limitado.bloqueos_temporales.size() == 2, "Los otros dos huecos reciben mesa cuando el tercero contiene la hoja")
	_verificar(not limitado.bloqueos_temporales.has(huecos[1]), "La casilla donde cayó la hoja queda libre")
	_oficina.papel_actual = null
	papel.queue_free()
	_oficina._limpiar_bloqueos_temporales()
	_oficina.grafo_piso = grafo_original
	_oficina.depurador_grafo.grafo = grafo_original
	await get_tree().process_frame


func _probar_caida_sobre_mesa_temporal() -> void:
	var centro: Vector3 = _oficina.grafo_piso.celda_a_posicion(Vector2i(7, 15))
	var mesa := preload("res://BloqueoTemporal.tscn").instantiate() as StaticBody3D
	_oficina.add_child(mesa)
	mesa.global_position = centro
	await _fisicas(3)
	var hoja := PapelDenuncia.new()
	_oficina.add_child(hoja)
	_oficina.papel_actual = hoja
	_oficina.bloqueos_visuales[Vector2i(7, 15)] = mesa
	_colocar(centro - Vector3(0.0, 0.0, 0.5) + Vector3.UP * _altura_pies, 0.0)
	hoja.tomar(_jugador)
	hoja.lanzar()
	await _fisicas(90)
	_verificar(hoja.global_position.y >= 0.91 and absf(hoja.global_position.x - centro.x) < 0.25 and absf(hoja.global_position.z - centro.z) < 0.25, "La hoja lanzada desde la casilla vecina reposa sobre la superficie visible de la mesa temporal")
	_verificar(_jugador.obtener_objetivo_interaccion() == hoja, "La hoja sobre la mesa temporal sigue al alcance de E")
	await _capturar("07_hoja_sobre_mesa")
	_oficina._limpiar_bloqueos_temporales()
	await get_tree().process_frame
	await _fisicas(90)
	_verificar(hoja.global_position.y < 0.45, "Al desaparecer la mesa temporal, la hoja cae al piso")
	await _capturar("08_hoja_tras_mesa")
	_oficina.papel_actual = null
	hoja.queue_free()
	await get_tree().process_frame


func _probar_vencimiento() -> void:
	var caso := _recibir_caso("VENCIMIENTO-AL-ALCANCE", ["bienestar"])
	var postura := _buscar_postura(_estaciones["bienestar"] as Estacion)
	if not postura.is_empty():
		_colocar(postura["cerca"], float(postura["giro"]))
		await _esperar_efecto()
		_validar_interactuables("bienestar", "antes de vencer un caso al alcance")
	_sistema.vencer_denuncia(caso.id)
	_verificar(not _oficina.indicador_papel.visible, "Vencer el caso retira inmediatamente el medallón")
	_validar_interactuables("", "inmediatamente al vencer el caso")
	var indicador := _indicadores["bienestar"] as IndicadorProximaEstacion
	_verificar(not indicador.visible and is_zero_approx(float(indicador.get("_intensidad_interaccion"))), "Vencer reinicia el efecto incluso estando junto a la mesa")


func _probar_hud_papel_adaptable() -> void:
	var hud := _oficina.indicador_papel as Control
	var aviso := _oficina.get("_aviso_apagon") as Label
	var original := get_window().size
	_verificar(hud.visible and hud.rotulo.text == "E - soltar", "Llevar el papel muestra el diseño con E - soltar")
	for resolucion: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1024, 768), Vector2i(2560, 1080), Vector2i(640, 360)]:
		get_window().size = resolucion
		await get_tree().process_frame
		await get_tree().process_frame
		var pantalla := get_viewport().get_visible_rect()
		var medallon := hud.get_global_rect()
		var luz := aviso.get_global_rect()
		_verificar(pantalla.encloses(medallon) and pantalla.encloses(luz), "Medallón y aviso caben en %s" % resolucion)
		_verificar(luz.end.y < medallon.position.y and not luz.intersects(medallon), "El aviso de luz queda por encima sin tapar el papel en %s" % resolucion)
		if resolucion == Vector2i(1280, 720):
			await _capturar("09_medallon_papel")
	get_window().size = original
	await get_tree().process_frame
	await get_tree().process_frame


func _probar_reconfiguracion() -> void:
	var indicador := INDICADOR.new() as IndicadorProximaEstacion
	indicador.configurar("bienestar", "Piloto aislado")
	add_child(indicador)
	indicador.establecer_activo(true)
	indicador.establecer_interactuable(true)
	await _esperar_efecto()
	_verificar(indicador.interactuable and _tiene_contorno(indicador), "El efecto se puede activar en un marcador independiente")
	indicador.configurar("evidencias", "Piloto reconfigurado")
	_verificar(not indicador.interactuable and is_zero_approx(float(indicador.get("_intensidad_interaccion"))), "Reconfigurar reinicia la disponibilidad y la transición")
	_verificar(not _tiene_contorno(indicador), "El modelo reconfigurado no conserva el contorno anterior")
	indicador.establecer_interactuable(true)
	await _esperar_efecto()
	indicador.establecer_activo(false)
	_verificar(not indicador.interactuable and not _tiene_contorno(indicador), "Desactivar limpia el efecto sin esperar otro cuadro")
	indicador.establecer_interactuable(true)
	_verificar(not indicador.interactuable, "Un marcador oculto rechaza el estado interactuable")
	indicador.queue_free()
	await get_tree().process_frame


func _buscar_postura(estacion: Estacion) -> Dictionary:
	var grafo := _oficina.grafo_piso as GrafoPiso
	var aproximacion := grafo.celda_a_posicion(GrafoPiso.DESTINOS[estacion.estacion_id])
	aproximacion.y = _altura_pies
	var objetivos: Array[Vector3] = [
		estacion.global_position,
		estacion.to_global(Vector3(0.5, 0.0, 0.0)),
		estacion.to_global(Vector3(-0.5, 0.0, 0.0))
	]
	# Busca la primera colisión del ShapeCast3D original sobre la aproximación real.
	# Este muestreo coloca el piloto; no crea una regla alternativa de proximidad.
	# Incluye los extremos de la mesa: su collider cóncavo contiene las patas.
	for centro: Vector3 in objetivos:
		centro.y = _altura_pies
		var hacia := centro - aproximacion
		var giro := atan2(hacia.x, hacia.z)
		for paso: int in range(81):
			var candidato := aproximacion.lerp(centro, float(paso) / 80.0)
			_colocar(candidato, giro)
			if _jugador.obtener_objetivo_interaccion() != estacion:
				continue
			var cerca := candidato
			var afuera := (aproximacion - centro).normalized()
			var paso_cast := _jugador.shape_cast_3d.target_position.length() * _jugador.shape_cast_3d.global_basis.z.length()
			for salida: int in range(1, 33):
				var lejos := cerca + afuera * paso_cast * float(salida)
				_colocar(lejos, giro)
				if _jugador.obtener_objetivo_interaccion() != estacion:
					return {"cerca": cerca, "lejos": lejos, "giro": giro}
	return {}


func _colocar(posicion: Vector3, giro: float) -> void:
	_jugador.global_position = posicion
	_jugador.visual.rotation.y = giro
	_jugador.velocity = Vector3.ZERO
	var deseada: Vector3 = posicion + _camara.offset
	deseada.x = clampf(deseada.x, _camara.limite_min_x, _camara.limite_max_x)
	deseada.z = clampf(deseada.z, _camara.limite_min_z, _camara.limite_max_z)
	_camara.global_position = deseada


func _recibir_caso(id: String, protocolo: Array[String]) -> Denuncia:
	var caso := Denuncia.new()
	caso.id = id
	caso.titulo = "Comprobación de disponibilidad de estaciones"
	caso.tiempo_limite_segundos = 120.0
	caso.protocolo_estaciones = protocolo
	_verificar(_sistema.recibir_denuncia(caso), "El despacho recibe " + id)
	_oficina._entregar_papel(_jugador)
	_verificar(_sistema.obtener_denuncia_activa() == caso and is_instance_valid(_jugador.papel_en_mano), "El computador activa el caso y entrega su hoja " + id)
	return caso


func _pulsar_interaccion() -> void:
	var pulsacion := InputEventAction.new()
	pulsacion.action = &"Interactuar"
	pulsacion.pressed = true
	Input.parse_input_event(pulsacion)
	var liberacion := InputEventAction.new()
	liberacion.action = &"Interactuar"
	liberacion.pressed = false
	Input.parse_input_event(liberacion)


func _pulsar_tecla(codigo: Key) -> void:
	var pulsacion := InputEventKey.new()
	pulsacion.keycode = codigo
	pulsacion.physical_keycode = codigo
	pulsacion.pressed = true
	Input.parse_input_event(pulsacion)
	var liberacion := InputEventKey.new()
	liberacion.keycode = codigo
	liberacion.physical_keycode = codigo
	liberacion.pressed = false
	Input.parse_input_event(liberacion)


func _validar_geometria() -> void:
	for indicador: IndicadorProximaEstacion in _indicadores.values():
		for nodo: Node in indicador.find_children("*", "", true, false):
			_verificar(not nodo is CollisionObject3D and not nodo is CollisionShape3D, "El marcador y su efecto no añaden colisiones: %s/%s" % [indicador.estacion_id, nodo.name])
			if nodo is MeshInstance3D:
				_verificar((nodo as MeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "El modelo no proyecta sombras sobre la mesa: " + str(nodo.name))


func _validar_interactuables(esperado: String, momento: String) -> void:
	for estacion_id: String in _indicadores:
		var indicador := _indicadores[estacion_id] as IndicadorProximaEstacion
		_verificar(indicador.interactuable == (estacion_id == esperado), "Disponibilidad de %s %s" % [estacion_id, momento])


func _estado_materiales(raiz: Node3D) -> Dictionary:
	var estado: Dictionary = {}
	for nodo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		var pieza := nodo as MeshInstance3D
		var material := pieza.material_override as StandardMaterial3D
		if material != null:
			estado[str(raiz.get_path_to(pieza))] = [material.get_instance_id(), material.emission_energy_multiplier, material.albedo_color, pieza.material_overlay != null]
	return estado


func _emision_estado(estado: Dictionary) -> float:
	var energia := 0.0
	for valores: Array in estado.values():
		energia = maxf(energia, float(valores[1]))
	return energia


func _emision_maxima(raiz: Node3D) -> float:
	return _emision_estado(_estado_materiales(raiz))


func _tiene_contorno(raiz: Node3D) -> bool:
	for nodo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
		if (nodo as MeshInstance3D).material_overlay != null:
			return true
	return false


func _esperar_efecto() -> void:
	await get_tree().create_timer(0.27).timeout
	await get_tree().process_frame


func _fisicas(cantidad: int) -> void:
	for cuadro: int in range(cantidad):
		await get_tree().physics_frame


func _capturar(nombre: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--capturas" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var directorio := "res://.godot/interaccion_marcadores_qa"
	DirAccess.make_dir_recursive_absolute(directorio)
	get_viewport().get_texture().get_image().save_png(directorio.path_join(nombre + ".png"))


func _verificar(condicion: bool, descripcion: String) -> void:
	_comprobaciones += 1
	if not condicion:
		_errores.append(descripcion)
		push_error("[INTERACCION MARCADORES] " + descripcion)
