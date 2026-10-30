extends Node
## Regresión de los modelos flotantes y del objetivo del despacho real.
## Ejecutar PruebaIndicadoresEstaciones.tscn; añadir -- --capturas para QA visual.

const INDICADOR_SCRIPT: Script = preload("res://Scripts/indicador_proxima_estacion.gd")
const ESTACIONES: Array[String] = ["bienestar", "verificacion", "evidencias", "privacidad", "reporte"]
const CASOS: Array[Denuncia] = [
	preload("res://Casos/Despacho/denuncia_uso_excesivo.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_enlace_sospechoso.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_suplantacion.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_acoso_persistente.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_amenaza_critica.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_phishing_repetido.tres") as Denuncia
]

var _errores: Array[String] = []
var _comprobaciones: int = 0
var _capturadas: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# La proyección y la reserva del HUD se prueban con una ventana representativa,
	# también en headless, cuyo tamaño inicial puede ser de solo 64 x 64 píxeles.
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	call_deferred("_probar")


func _probar() -> void:
	var oficina := preload("res://Oficina.tscn").instantiate()
	oficina.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().root.add_child(oficina)
	await get_tree().physics_frame
	await _cuadros(3)
	oficina.temporizador_denuncias.stop()
	oficina.temporizador_bloqueos.stop()
	var sistema := oficina.get("sistema_despacho") as SistemaDespacho
	sistema.set_process(false)
	var indicadores: Dictionary = oficina.get("indicadores_estaciones")
	_validar_estaciones_y_modelos(oficina, indicadores)
	await _probar_reconfiguracion_y_fallback()
	await _probar_protocolos(oficina, indicadores)
	_probar_cierres_directos(sistema, indicadores)
	await _probar_pausa(oficina, sistema, indicadores)
	get_tree().paused = false
	oficina.queue_free()
	await get_tree().process_frame
	print("[INDICADORES] %d comprobaciones, %d errores." % [_comprobaciones, _errores.size()])
	get_tree().quit(0 if _errores.is_empty() else 1)


func _validar_estaciones_y_modelos(oficina: Node, indicadores: Dictionary) -> void:
	var estaciones: Dictionary = {}
	for nodo: Node in oficina.find_children("*", "Estacion", true, false):
		var estacion := nodo as Estacion
		estaciones[estacion.estacion_id] = estacion
	_verificar(estaciones.size() == 5 and indicadores.size() == 5, "La oficina crea las cinco estaciones y sus cinco marcadores")
	_validar_objetivo(indicadores, "", "al iniciar sin caso activo")
	for caso: Denuncia in CASOS:
		for estacion_id: String in caso.protocolo_estaciones:
			_verificar(estaciones.has(estacion_id), "%s tiene estación física %s" % [caso.id, estacion_id])
			_verificar(GrafoPiso.DESTINOS.has(estacion_id), "%s tiene destino navegable %s" % [caso.id, estacion_id])
	var firmas: Dictionary = {}
	for estacion_id: String in ESTACIONES:
		_verificar(indicadores.has(estacion_id), "Existe el marcador de " + estacion_id)
		if not indicadores.has(estacion_id):
			continue
		var indicador := indicadores[estacion_id] as IndicadorProximaEstacion
		_validar_visual(indicador, estacion_id)
		var modelo := indicador.find_child("ModeloEstacion", true, false) as Node3D
		if modelo != null:
			firmas[_firma_geometria(modelo)] = true
	_verificar(firmas.size() == 5, "Las cinco estaciones usan geometrías de modelo diferentes")


func _validar_visual(indicador: IndicadorProximaEstacion, contexto: String) -> void:
	var modelo := indicador.find_child("ModeloEstacion", true, false) as Node3D
	var puntero := indicador.find_child("Puntero", true, false) as Node3D
	_verificar(modelo != null and puntero != null, "Modelo 3D y puntero presentes: " + contexto)
	var orientacion := indicador.get_node_or_null("OrientacionCamara") as Node3D
	_verificar(orientacion != null and modelo != null and puntero != null and orientacion.is_ancestor_of(modelo) and orientacion.is_ancestor_of(puntero), "Modelo y puntero comparten la orientación hacia cámara: " + contexto)
	if modelo != null:
		_verificar(not modelo.find_children("*", "MeshInstance3D", true, false).is_empty(), "El modelo contiene geometría real: " + contexto)
	_verificar(indicador.find_child("AroOrientacion", true, false) == null, "El marcador no conserva el aro provisional: " + contexto)
	_verificar(indicador.find_child("RotuloSiguiente", true, false) == null, "El marcador no conserva el rótulo provisional: " + contexto)
	for nodo: Node in indicador.find_children("*", "", true, false):
		_verificar(not nodo is CollisionObject3D and not nodo is CollisionShape3D, "El marcador no introduce colisiones: %s/%s" % [contexto, nodo.name])
		_verificar(not nodo is Label3D and not nodo is Label, "El marcador no introduce texto: %s/%s" % [contexto, nodo.name])
		if nodo is MeshInstance3D:
			var malla := (nodo as MeshInstance3D).mesh
			_verificar(not malla is TextMesh, "El marcador no usa texto como malla: %s/%s" % [contexto, nodo.name])
			if malla is CylinderMesh:
				var cilindro := malla as CylinderMesh
				_verificar(cilindro.top_radius > 0.0 and cilindro.bottom_radius > 0.0, "El marcador no usa el cono provisional: %s/%s" % [contexto, nodo.name])


func _firma_geometria(modelo: Node3D) -> String:
	var piezas: Array[String] = []
	for nodo: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		var pieza := nodo as MeshInstance3D
		if pieza.mesh == null:
			continue
		var vertices: Array[int] = []
		for superficie: int in range(pieza.mesh.get_surface_count()):
			var datos: Array = pieza.mesh.surface_get_arrays(superficie)
			vertices.append(hash(datos[Mesh.ARRAY_VERTEX]))
		var transformacion := Transform3D.IDENTITY
		var actual: Node3D = pieza
		while actual != modelo:
			transformacion = actual.transform * transformacion
			actual = actual.get_parent() as Node3D
		piezas.append("%s|%s|%s|%s" % [pieza.mesh.get_class(), transformacion, pieza.mesh.get_aabb(), vertices])
	piezas.sort()
	return "\n".join(piezas)


func _probar_reconfiguracion_y_fallback() -> void:
	var indicador := INDICADOR_SCRIPT.new() as IndicadorProximaEstacion
	indicador.configurar("evidencias", "Mesa de evidencias")
	indicador.establecer_activo(false)
	add_child(indicador)
	var cantidad_inicial := indicador.find_children("*", "MeshInstance3D", true, false).size()
	var firma_inicial := _firma_geometria(indicador.find_child("ModeloEstacion", true, false) as Node3D)
	indicador.configurar("evidencias", "Mesa de evidencias")
	await _cuadros(2)
	_verificar(indicador.find_children("ModeloEstacion", "", true, false).size() == 1, "Configurar dos veces conserva un único modelo")
	_verificar(indicador.find_children("Puntero", "", true, false).size() == 1, "Configurar dos veces conserva un único puntero")
	_verificar(indicador.find_children("*", "MeshInstance3D", true, false).size() == cantidad_inicial, "Configurar dos veces no acumula geometría")
	_verificar(_firma_geometria(indicador.find_child("ModeloEstacion", true, false) as Node3D) == firma_inicial, "Reconfigurar conserva la geometría de la estación")
	indicador.configurar("estacion-desconocida", "Estación desconocida")
	await _cuadros(2)
	_validar_visual(indicador, "fallback desconocido")
	_verificar(indicador.estacion_id == "estacion-desconocida", "El fallback conserva el ID solicitado")
	indicador.establecer_activo(true)
	_verificar(indicador.visible and indicador.is_processing(), "Activar habilita visibilidad y animación")
	await get_tree().create_timer(0.12).timeout
	var tiempo_activo: float = indicador.get("_tiempo")
	indicador.establecer_activo(true)
	_verificar(is_equal_approx(float(indicador.get("_tiempo")), tiempo_activo), "Activar un marcador ya activo no reinicia su animación")
	indicador.establecer_activo(false)
	_verificar(not indicador.visible and not indicador.is_processing(), "Desactivar oculta y detiene la animación")
	indicador.establecer_activo(true)
	_verificar(is_zero_approx(float(indicador.get("_tiempo"))), "Reactivar reinicia la fase de animación")
	indicador.queue_free()
	await get_tree().process_frame


func _probar_protocolos(oficina: Node, indicadores: Dictionary) -> void:
	var sistema := oficina.get("sistema_despacho") as SistemaDespacho
	for plantilla: Denuncia in CASOS:
		var caso := plantilla.duplicate(true) as Denuncia
		caso.id = "PROTOCOLO-" + plantilla.id
		_verificar(sistema.recibir_denuncia(caso), "Se recibe el protocolo " + caso.id)
		oficina.call("_on_computador_despacho_abierto")
		for paso: int in range(caso.protocolo_estaciones.size()):
			var objetivo: String = caso.protocolo_estaciones[paso]
			_validar_objetivo(indicadores, objetivo, "%s paso %d" % [caso.id, paso])
			if not _capturadas.has(objetivo):
				await _capturar_estacion(oficina, indicadores[objetivo] as Node3D, objetivo)
				_capturadas[objetivo] = true
			var incorrecta: String = "bienestar" if objetivo != "bienestar" else "evidencias"
			oficina.call("interactuar_estacion", incorrecta)
			_verificar(caso.indice_estacion_actual == paso, "Una estación incorrecta no avanza " + caso.id)
			_validar_objetivo(indicadores, objetivo, "tras estación incorrecta")
			if paso % 2 == 0:
				oficina.call("interactuar_estacion", objetivo)
			else:
				_verificar(sistema.interactuar_estacion(objetivo), "La llamada directa al despacho acepta la estación correcta")
			var siguiente: String = caso.protocolo_estaciones[paso + 1] if paso + 1 < caso.protocolo_estaciones.size() else ""
			_validar_objetivo(indicadores, siguiente, "tras avanzar " + caso.id)
		_verificar(caso.estado == Denuncia.Estado.RESUELTA, "La estación final resuelve " + caso.id)


func _probar_cierres_directos(sistema: SistemaDespacho, indicadores: Dictionary) -> void:
	for vencer: bool in [false, true]:
		var caso := CASOS[0].duplicate(true) as Denuncia
		caso.id = "CIERRE-DIRECTO-%s" % vencer
		sistema.recibir_denuncia(caso)
		sistema.iniciar_denuncia_prioritaria()
		_validar_objetivo(indicadores, "bienestar", "al aceptar directamente en el despacho")
		if vencer:
			sistema.tiempos_restantes[caso.id] = 0.1
			sistema.actualizar_tiempos(0.2)
		else:
			sistema.resolver_denuncia(caso.id)
		_validar_objetivo(indicadores, "", "inmediatamente tras cierre directo, sin esperar bloqueos")
	var activo := CASOS[0].duplicate(true) as Denuncia
	activo.id = "ACTIVO-CONSERVADO"
	sistema.recibir_denuncia(activo)
	sistema.iniciar_denuncia_prioritaria()
	var pendiente := CASOS[1].duplicate(true) as Denuncia
	pendiente.id = "PENDIENTE-QUE-VENCE"
	sistema.recibir_denuncia(pendiente)
	sistema.vencer_denuncia(pendiente.id)
	_validar_objetivo(indicadores, "bienestar", "vencer otro caso pendiente conserva el objetivo activo")
	sistema.resolver_denuncia(activo.id)


func _probar_pausa(oficina: Node, sistema: SistemaDespacho, indicadores: Dictionary) -> void:
	var caso := CASOS[0].duplicate(true) as Denuncia
	caso.id = "PAUSA-MARCADOR"
	sistema.recibir_denuncia(caso)
	sistema.iniciar_denuncia_prioritaria()
	var indicador := indicadores["bienestar"] as IndicadorProximaEstacion
	var orientacion := indicador.get_node_or_null("OrientacionCamara") as Node3D
	_verificar(orientacion != null, "El modelo tiene su nodo de orientación a cámara")
	if orientacion == null:
		sistema.resolver_denuncia(caso.id)
		return
	await get_tree().create_timer(0.12).timeout
	var escena_anterior := get_tree().current_scene
	get_tree().current_scene = oficina
	MenuGlobal.abrir_pausa()
	_verificar(get_tree().paused and MenuGlobal.panel_pausa.visible, "La pausa real está abierta")
	var transformacion_pausada := orientacion.transform
	var fase_pausada: float = indicador.get("_tiempo")
	await get_tree().create_timer(0.15).timeout
	_verificar(orientacion.transform.is_equal_approx(transformacion_pausada) and is_equal_approx(float(indicador.get("_tiempo")), fase_pausada), "Pausa congela posición, orientación y fase del marcador")
	MenuGlobal.reanudar_juego()
	get_tree().current_scene = escena_anterior
	await get_tree().create_timer(0.12).timeout
	_verificar(float(indicador.get("_tiempo")) > fase_pausada, "Reanudar continúa la animación")
	sistema.resolver_denuncia(caso.id)
	_validar_objetivo(indicadores, "", "al terminar la prueba de pausa")


func _validar_objetivo(indicadores: Dictionary, esperado: String, momento: String) -> void:
	var visibles: int = 0
	for estacion_id: String in indicadores:
		var indicador := indicadores[estacion_id] as IndicadorProximaEstacion
		var activo := estacion_id == esperado
		if indicador.visible:
			visibles += 1
		_verificar(indicador.visible == activo and indicador.is_processing() == activo, "Visibilidad y proceso de %s %s" % [estacion_id, momento])
	_verificar(visibles == (0 if esperado.is_empty() else 1), "Solo el objetivo actual está visible " + momento)


func _capturar_estacion(oficina: Node, indicador: Node3D, estacion_id: String) -> void:
	var camara := oficina.get_node("Gameplay/Camera3D") as Camera3D
	var transformacion := camara.global_transform
	var procesaba := camara.is_physics_processing()
	var jugador := oficina.get("jugador") as Player
	var transformacion_jugador := jugador.global_transform
	var velocidad_jugador := jugador.velocity
	var jugador_procesaba := jugador.is_physics_processing()
	var depurador := oficina.get("depurador_grafo") as Node3D
	var depurador_visible := depurador.visible
	depurador.hide()
	camara.set_physics_process(false)
	jugador.set_physics_process(false)
	var grafo := oficina.get("grafo_piso") as GrafoPiso
	jugador.global_position = grafo.celda_a_posicion(GrafoPiso.DESTINOS[estacion_id]) + Vector3.UP * 0.075
	camara.global_position = jugador.global_position + camara.offset
	await _cuadros(3)
	_validar_proyeccion(oficina, indicador, camara, estacion_id)
	await _guardar_captura(estacion_id + "_jugando")
	jugador.global_transform = transformacion_jugador
	var desplazamiento_x := -1.6 if indicador.global_position.x > -1.0 else 1.6
	camara.global_position = indicador.global_position + Vector3(desplazamiento_x, 1.1, 2.6)
	camara.look_at(indicador.global_position + Vector3.UP * 0.2)
	await _guardar_captura(estacion_id)
	camara.global_transform = transformacion
	camara.set_physics_process(procesaba)
	jugador.global_transform = transformacion_jugador
	jugador.velocity = velocidad_jugador
	jugador.set_physics_process(jugador_procesaba)
	depurador.visible = depurador_visible


func _validar_proyeccion(oficina: Node, indicador: Node3D, camara: Camera3D, estacion_id: String) -> void:
	var puntos: Array[Vector2] = []
	var delante_camara: bool = true
	# Incluye los ocho vértices del AABB de cada malla, tanto modelo como puntero.
	for nodo: Node in indicador.find_children("*", "MeshInstance3D", true, false):
		var pieza := nodo as MeshInstance3D
		if pieza.mesh == null:
			continue
		var caja := pieza.mesh.get_aabb()
		for vertice: int in range(8):
			var esquina := caja.position + Vector3(
				caja.size.x if (vertice & 1) != 0 else 0.0,
				caja.size.y if (vertice & 2) != 0 else 0.0,
				caja.size.z if (vertice & 4) != 0 else 0.0
			)
			var posicion := pieza.global_transform * esquina
			delante_camara = delante_camara and not camara.is_position_behind(posicion)
			puntos.append(camara.unproject_position(posicion))
	_verificar(not puntos.is_empty() and delante_camara, "La geometría completa de %s está delante de la cámara" % estacion_id)
	if puntos.is_empty():
		return
	var caja_pantalla := Rect2(puntos[0], Vector2.ZERO)
	for punto: Vector2 in puntos:
		caja_pantalla = caja_pantalla.expand(punto)
	var pantalla := get_viewport().get_visible_rect()
	var limite_alto := pantalla.size.y * 0.18 + 5.0
	var panel := oficina.get("panel_despacho") as PanelDespacho
	var zona_hud := panel.contenido.get_global_rect()
	_verificar(caja_pantalla.size.y <= limite_alto, "La altura total de %s cabe en el 18%% de pantalla: %.1f <= %.1f px" % [estacion_id, caja_pantalla.size.y, limite_alto])
	_verificar(pantalla.encloses(caja_pantalla), "El modelo y puntero de %s están dentro de la pantalla" % estacion_id)
	_verificar(not zona_hud.intersects(caja_pantalla), "El marcador de %s no invade el HUD" % estacion_id)
	print("[INDICADOR PANTALLA] %s: %.1f px; máximo %.1f px." % [estacion_id, caja_pantalla.size.y, limite_alto])


func _guardar_captura(nombre: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--capturas" in OS.get_cmdline_user_args():
		return
	await _cuadros(3)
	await RenderingServer.frame_post_draw
	var directorio := "res://.godot/marcadores_estaciones_qa"
	DirAccess.make_dir_recursive_absolute(directorio)
	get_viewport().get_texture().get_image().save_png(directorio.path_join(nombre + ".png"))


func _cuadros(cantidad: int) -> void:
	for cuadro: int in range(cantidad):
		await get_tree().process_frame


func _verificar(condicion: bool, descripcion: String) -> void:
	_comprobaciones += 1
	if not condicion:
		_errores.append(descripcion)
		push_error("[INDICADORES] " + descripcion)
