extends Node
## El brillo debe coincidir con el objetivo físico real de la tecla E.
## Ejecutar esta escena; -- --capturas guarda lejos/cerca/salida en la oficina.

const MODELOS := preload("res://MarcadoresEstaciones/modelos_marcador.gd")
const INDICADOR := preload("res://Scripts/indicador_proxima_estacion.gd")

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
	_verificar(_jugador.obtener_objetivo_interaccion() == _estaciones["bienestar"], "La comprobación del computador no cambia el alcance del ShapeCast3D")
	_validar_interactuables("", "mientras se usa el computador")
	_oficina.computador.is_using = false
	await _esperar_efecto()
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
	_verificar(caso.indice_estacion_actual == 1, "La misma tecla E completa la estación iluminada")
	_verificar(caso.estado == Denuncia.Estado.RESUELTA, "E en bienestar resuelve su protocolo completo")
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


func _probar_vencimiento() -> void:
	var caso := _recibir_caso("VENCIMIENTO-AL-ALCANCE", ["bienestar"])
	var postura := _buscar_postura(_estaciones["bienestar"] as Estacion)
	if not postura.is_empty():
		_colocar(postura["cerca"], float(postura["giro"]))
		await _esperar_efecto()
		_validar_interactuables("bienestar", "antes de vencer un caso al alcance")
	_sistema.vencer_denuncia(caso.id)
	_validar_interactuables("", "inmediatamente al vencer el caso")
	var indicador := _indicadores["bienestar"] as IndicadorProximaEstacion
	_verificar(not indicador.visible and is_zero_approx(float(indicador.get("_intensidad_interaccion"))), "Vencer reinicia el efecto incluso estando junto a la mesa")


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
	_verificar(_sistema.iniciar_denuncia_prioritaria() == caso, "El despacho activa " + id)
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
