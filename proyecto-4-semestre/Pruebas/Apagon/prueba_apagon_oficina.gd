extends "res://Pruebas/Apagon/prueba_apagon_smoke.gd"
## Ejecutar con --headless --path <proyecto> --script res://Pruebas/Apagon/prueba_apagon_oficina.gd.
## El caso activo sigue consumiendo tiempo. Se detienen las llegadas aleatorias para repetir la prueba.

var _menu: Node
var _hud: Control
var _grafo: GrafoPiso
var _calma_inicial: int
var _caso_activo: Denuncia


func _probar() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	_menu = root.get_node("MenuGlobal")
	_menu.set("nombre_partida", "")
	_escena = (load("res://Mundo/Oficina.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_escena)
	current_scene = _escena
	await _cuadros(3)
	_menu.call("cerrar_ayuda")
	await _fisicas(60)
	_jugador = _escena.get_node("Gameplay/Node3D") as CharacterBody3D
	_camara = _escena.get_node("Gameplay/Camera3D") as Camera3D
	_taco = _escena.get_node_or_null("TacoLuz") as StaticBody3D
	_evento = _escena.get_node_or_null("EventoApagon")
	_verificar(_taco != null and _evento != null, "La oficina real instancia el taco y el evento de apagón")
	if _taco == null or _evento == null:
		await _finalizar()
		return
	_panel = _evento.get("panel") as Control
	_hud = _escena.get_node("CanvasLayer/PanelDespacho") as Control
	_despacho = _escena.get("sistema_despacho") as SistemaDespacho
	_grafo = _escena.get("grafo_piso") as GrafoPiso
	(_escena.get("temporizador_denuncias") as Timer).stop()
	(_escena.get("temporizador_bloqueos") as Timer).stop()
	var computador: Node = _escena.get("computador")
	(computador.get("timer_nuevo_problema") as Timer).stop()
	(_escena.get("depurador_grafo") as Node3D).hide()
	_verificar(not (_escena.get("depurador_grafo") as GrafoDebugVisual).visible_debug, "La partida comienza sin modo debug")
	await _pulsar_tecla(KEY_B)
	_verificar(int(_evento.get("estado")) == 0, "B no activa la prueba antes de F3")
	await _pulsar_tecla(KEY_F3)
	_verificar((_escena.get("depurador_grafo") as GrafoDebugVisual).visible_debug, "F3 activa el modo debug en desarrollo")
	(_escena.get("depurador_grafo") as Node3D).hide()
	_verificar(bool(_menu.call("es_escena_de_juego")), "MenuGlobal reconoce Oficina como la partida real")
	_verificar(_jugador.is_on_floor(), "El jugador aterriza en el suelo de Oficina")
	_altura_pies = _jugador.global_position.y
	_jugador.set_physics_process(false)
	_camara.set_physics_process(false)
	_evento.connect("luz_restaurada", _contar_restauracion)
	_preparar_saldo()
	_validar_hud_y_estaciones()
	_postura = _buscar_postura()
	_verificar(not _postura.is_empty(), "Existe una aproximación sin solape físico que alcanza el taco con E")
	if _postura.is_empty():
		await _finalizar()
		return
	_colocar(_postura["cerca"], float(_postura["giro"]))
	await _capturar("00_oficina_con_luz")
	_guardar_luces()
	await _probar_cajones()
	for tipo: int in TIPOS_CIRCUITO:
		await _probar_circuito(tipo)
	_verificar(_restauraciones == 3, "Los tres circuitos restauran la oficina exactamente una vez")
	_verificar(float(_despacho.tiempos_restantes[_caso_activo.id]) < 300.0, "El tiempo de la denuncia sigue avanzando durante las reparaciones")
	_verificar(_caso_activo.estaciones_completadas.is_empty(), "Reparar la luz conserva el protocolo de la denuncia")
	await _probar_salida_durante_apagon()
	await _finalizar()


func _preparar_saldo() -> void:
	var resuelta := Denuncia.new()
	resuelta.id = "OFICINA-SALDO-APAGON"
	resuelta.nivel_riesgo = 3
	_verificar(_despacho.recibir_denuncia(resuelta) and _despacho.resolver_denuncia(resuelta.id), "El despacho real acumula una recompensa de denuncia")
	_saldo_inicial = _despacho.puntuacion.puntos
	_despacho.calma_operativa = 65
	_despacho.calma_actualizada.emit(65)
	_calma_inicial = _despacho.calma_operativa
	_caso_activo = Denuncia.new()
	_caso_activo.id = "OFICINA-CASO-DURANTE-APAGON"
	_caso_activo.tiempo_limite_segundos = 300.0
	_caso_activo.protocolo_estaciones = ["bienestar"]
	_verificar(_despacho.recibir_denuncia(_caso_activo), "La partida recibe un caso que permanece activo durante el apagón")
	_verificar(_despacho.iniciar_denuncia_prioritaria() == _caso_activo, "El despacho activa su protocolo normal")
	_escena.call("_calcular_ruta_a_proxima_estacion")
	_verificar(_saldo_inicial == 300, "La oficina conserva su recompensa inicial de 300 puntos")


func _validar_hud_y_estaciones() -> void:
	var capa_hud := _escena.get_node("CanvasLayer") as CanvasLayer
	var capa_mascara := (_evento.get("mascara") as ColorRect).get_parent() as CanvasLayer
	var capa_circuito := _panel.get_parent() as CanvasLayer
	_verificar(capa_hud.layer > capa_mascara.layer, "El HUD de denuncias se dibuja por encima de la máscara")
	_verificar(capa_circuito.layer > capa_hud.layer, "El circuito se dibuja por encima del HUD")
	_verificar(_hud.is_visible_in_tree(), "El HUD de la partida permanece visible")
	var indicadores: Dictionary = _escena.get("indicadores_estaciones")
	_verificar(indicadores.size() == 5 and not indicadores.has("taco_luz"), "El taco conserva los cinco marcadores de estaciones separados")
	_verificar(_escena.find_children("*", "Estacion", true, false).size() == 5, "El tablero eléctrico conserva las cinco estaciones de denuncias")
	for celda: Vector2i in [Vector2i(13, 15), Vector2i(13, 16), Vector2i(13, 17)]:
		_verificar(not _grafo.es_transitable(celda), "El grafo respeta la ocupación física del taco en %s" % celda)


func _buscar_postura() -> Dictionary:
	var centro := _taco.global_position
	centro.y = _altura_pies
	var frente := _taco.global_basis.z.normalized()
	frente.y = 0.0
	for direccion: Vector3 in [frente, -frente, _taco.global_basis.x.normalized(), -_taco.global_basis.x.normalized()]:
		var giro := atan2(-direccion.x, -direccion.z)
		for paso: int in range(151):
			var candidato := centro + direccion * (1.6 - float(paso) * 0.01)
			_colocar(candidato, giro)
			var celda := _grafo.posicion_a_celda(candidato)
			if _grafo.es_transitable(celda) and _posicion_libre() and _jugador.obtener_objetivo_interaccion() == _taco:
				return {"cerca": candidato, "lejos": candidato + direccion * 1.2, "giro": giro}
	return {}


func _posicion_libre() -> bool:
	var colision := _jugador.get_node("Colision") as CollisionShape3D
	var caja := colision.global_transform * colision.shape.get_debug_mesh().get_aabb()
	var forma := BoxShape3D.new()
	forma.size = caja.size * Vector3(0.98, 0.94, 0.98)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = Transform3D(Basis.IDENTITY, caja.get_center())
	consulta.collision_mask = _jugador.collision_mask
	consulta.exclude = [_jugador.get_rid()]
	return _escena.get_world_3d().direct_space_state.intersect_shape(consulta).is_empty()


func _probar_cajones() -> void:
	var destino := _grafo.posicion_a_celda(_postura["cerca"])
	_verificar(_grafo.es_zona_segura(destino), "La aproximación del tablero pertenece a la zona protegida de cajones")
	for distribucion: int in range(6):
		var azar: RandomNumberGenerator = _escena.get("generador_aleatorio")
		azar.seed = 950 + distribucion
		_escena.call("_cambiar_bloqueo_temporal")
		await _fisicas(2)
		_verificar(not _grafo.bloqueos_temporales.has(destino), "La distribución %d deja libre la aproximación del tablero" % distribucion)
		_verificar(_posicion_libre() and _jugador.obtener_objetivo_interaccion() == _taco, "Los cajones %d conservan la interacción física con el tablero" % distribucion)
		for estacion: String in GrafoPiso.DESTINOS:
			var ruta := _grafo.calcular_ruta(GrafoPiso.DESTINOS[estacion], destino)
			_verificar(not ruta.is_empty(), "Los cajones %d mantienen acceso desde %s al tablero" % [distribucion, estacion])
	_escena.call("_limpiar_bloqueos_temporales")
	_grafo.construir_adyacencia()
	await _fisicas(2)


func _probar_circuito(tipo: int) -> void:
	_colocar(_postura["cerca"], float(_postura["giro"]))
	_guardar_energia_actual()
	_evento.connect("luz_restaurada", _comprobar_luces, CONNECT_ONE_SHOT)
	await _pulsar_tecla(KEY_B)
	_verificar(int(_evento.get("estado")) == 1, "B inicia el apagón %d dentro de Oficina" % tipo)
	var semilla: int = _evento.get("semilla_circuito")
	await _pulsar_tecla(KEY_B)
	_verificar(int(_evento.get("semilla_circuito")) == semilla, "B repetida conserva el circuito activo")
	_evento.set("tipo_circuito", tipo)
	_evento.set("semilla_circuito", 4950 + tipo)
	if tipo == 0:
		await _probar_alcance()
		_colocar(_postura["cerca"], float(_postura["giro"]))
		await _capturar("01_oficina_apagon")
		await _probar_pc()
		await _enviar_tab(true)
		_verificar((_escena.get("clasificacion_partida") as Control).visible, "Mantener Tab antes de interactuar abre la clasificación normal")
		await _pulsar_tecla(KEY_E)
		await _enviar_tab(false)
		_verificar(not (_escena.get("clasificacion_partida") as Control).visible, "Soltar Tab al abrir el circuito oculta la clasificación anterior")
	await _pulsar_tecla(KEY_E)
	_verificar(int(_evento.get("estado")) == 2 and _panel.visible, "E abre el circuito %d desde la aproximación real de Oficina" % tipo)
	if not _panel.visible:
		return
	await _esperar_entrada()
	_verificar(_jugador.get("input_locked") and not paused, "El circuito bloquea movimiento mientras la denuncia sigue activa")
	await _comprobar_clasificacion()
	await _probar_reapertura(tipo)
	if tipo == 0:
		await _probar_pausa()
	if tipo == 0:
		await _capturar("02_oficina_circuito")
	await _resolver_circuito(tipo)
	await _cuadros(3)
	_verificar(int(_evento.get("estado")) == 0 and not _panel.visible, "Resolver el circuito %d restaura la oficina" % tipo)
	_verificar(_despacho.puntuacion.puntos == _saldo_inicial, "El circuito %d conserva los puntos reales de la partida" % tipo)
	_verificar(_despacho.calma_operativa == _calma_inicial, "El circuito %d conserva la calma de la partida" % tipo)
	_verificar((_hud.get("puntos_valor") as Label).text == "300", "El HUD conserva el saldo al reparar")
	if tipo == 3:
		await _capturar("03_oficina_restaurada")


func _guardar_energia_actual() -> void:
	# Los focos pueden parpadear entre dos apagones.
	for luz: Light3D in _luces_iniciales:
		_luces_iniciales[luz]["energia"] = luz.light_energy


func _probar_salida_durante_apagon() -> void:
	_guardar_energia_actual()
	await super._probar_salida_durante_apagon()


func _comprobar_clasificacion() -> void:
	await _enviar_tab(true)
	_verificar(not (_escena.get("clasificacion_partida") as Control).visible, "Mantener Tab conserva la clasificación cerrada sobre el circuito")
	await _enviar_tab(false)


func _enviar_tab(presionada: bool) -> void:
	var evento := InputEventKey.new()
	evento.physical_keycode = KEY_TAB
	evento.keycode = KEY_TAB
	evento.pressed = presionada
	Input.parse_input_event(evento)
	await process_frame


func _probar_pausa() -> void:
	await _pulsar_tecla(KEY_ESCAPE)
	_verificar(int(_evento.get("estado")) == 1 and not paused, "El primer Escape cierra el circuito sin abrir pausa")
	await _pulsar_tecla(KEY_ESCAPE)
	_verificar(paused and (_menu.get("panel_pausa") as Control).visible, "Escape con circuito cerrado abre la pausa normal")
	var tiempo: float = _despacho.tiempos_restantes[_caso_activo.id]
	await create_timer(0.2).timeout
	_verificar(is_equal_approx(float(_despacho.tiempos_restantes[_caso_activo.id]), tiempo), "La pausa normal detiene el tiempo de denuncia")
	await _pulsar_tecla(KEY_B)
	_verificar(not _panel.visible and int(_evento.get("estado")) == 1 and _jugador.obtener_objetivo_interaccion() == null, "La pausa impide interacciones del mundo y rechaza B")
	await _pulsar_tecla(KEY_ESCAPE)
	_verificar(not paused, "Escape reanuda la partida")
	await _pulsar_tecla(KEY_E)
	_verificar(_panel.visible and int(_evento.get("estado")) == 2, "Tras reanudar E recupera el circuito pendiente")
	await _esperar_entrada()


func _probar_pc() -> void:
	var computador: Node = _escena.get("computador")
	var taco_original := _taco
	_taco = _escena.find_child("InteraccionComputador", true, false) as StaticBody3D
	var postura_silla := _buscar_postura() if _taco != null else {}
	_taco = taco_original
	_verificar(not postura_silla.is_empty(), "La silla ofrece una aproximación física válida para recibir la denuncia")
	if postura_silla.is_empty():
		return
	_colocar(postura_silla["cerca"], float(postura_silla["giro"]))
	await _pulsar_tecla(KEY_E)
	await create_timer(0.85).timeout
	var papel := _jugador.get("papel_en_mano") as Node3D
	_verificar(not bool(computador.get("is_using")) and is_instance_valid(papel), "E en la silla entrega el papel al contacto del gesto durante el apagón")
	_verificar(root.get_camera_3d() == _camara, "Imprimir conserva la cámara de la oficina")
	_verificar((_evento.get("mascara") as ColorRect).visible, "La visión limitada permanece al imprimir")
	var semilla: int = _evento.get("semilla_circuito")
	await _pulsar_tecla(KEY_B)
	_verificar(int(_evento.get("semilla_circuito")) == semilla and not bool(_evento.call("iniciar_apagon")), "El apagón activo rechaza otro inicio")
	for luz: Light3D in _luces_iniciales:
		_verificar(not luz.visible, "Imprimir conserva apagadas las luces de la oficina")
	await _capturar("01b_oficina_pc_apagon")
	await _pulsar_tecla(KEY_ESCAPE)
	_verificar(paused and not bool(computador.get("is_using")), "Escape abre la pausa normal con el papel en mano")
	var tiempo: float = _despacho.tiempos_restantes[_caso_activo.id]
	await create_timer(0.2).timeout
	_verificar(is_equal_approx(float(_despacho.tiempos_restantes[_caso_activo.id]), tiempo), "La pausa detiene el tiempo de denuncia")
	await _pulsar_tecla(KEY_ESCAPE)
	_verificar(not paused and is_instance_valid(_jugador.get("papel_en_mano")), "Reanudar conserva la hoja")
	_jugador.set_physics_process(false)
	await _cuadros(3)
	_verificar(not bool(computador.get("is_using")) and root.get_camera_3d() == _camara, "La pantalla del computador permanece deshabilitada")
	_verificar((_evento.get("mascara") as ColorRect).visible and int(_evento.get("estado")) == 1, "El papel no altera el apagón")
	_colocar(_postura["cerca"], float(_postura["giro"]))


func _colocar(posicion: Vector3, giro: float) -> void:
	super._colocar(posicion, giro)
	var desplazamiento: Vector3 = _camara.get("offset")
	var deseada := posicion + desplazamiento
	deseada.x = clampf(deseada.x, float(_camara.get("limite_min_x")), float(_camara.get("limite_max_x")))
	deseada.z = clampf(deseada.z, float(_camara.get("limite_min_z")), float(_camara.get("limite_max_z")))
	_camara.global_position = deseada


func _capturar(nombre: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--capturas" in OS.get_cmdline_user_args():
		return
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var directorio := "res://.godot/apagon_oficina_qa"
	DirAccess.make_dir_recursive_absolute(directorio)
	_verificar(root.get_texture().get_image().save_png(directorio.path_join(nombre + ".png")) == OK, "Se guarda la captura " + nombre)


func _finalizar() -> void:
	paused = false
	if is_instance_valid(_escena):
		_escena.queue_free()
		await process_frame
	await _esperar_audio_al_salir()
	print("[APAGON OFICINA] %d comprobaciones, %d errores." % [_comprobaciones, _errores.size()])
	quit(0 if _errores.is_empty() else 1)
