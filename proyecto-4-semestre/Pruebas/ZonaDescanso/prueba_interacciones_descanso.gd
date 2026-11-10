extends SceneTree
## --headless --fixed-fps 60 --script res://Pruebas/ZonaDescanso/prueba_interacciones_descanso.gd
## Interacciones reales de alcance, café, relajación, pausa y salida de escena.

const OFICINA := "res://Mundo/Oficina.tscn"
const PAPEL := "res://Scripts/Despacho/papel_denuncia.gd"
var _errores: Array[String] = []
var _comprobaciones: int = 0
var _oficina: Node3D
var _zona: Node3D
var _jugador: CharacterBody3D
var _despacho: SistemaDespacho
var _cafe: Node3D
var _sofa: Node3D
var _altura: float
var _postura_cafe: Dictionary
var _postura_sofa: Dictionary
var _caso: Denuncia
var _secuencia_saldo: int = 0
var _ids_tazas: Array[int] = []


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	await _cargar()
	if not _zona.has_method("obtener_estado"):
		_verificar(false, "El controlador expone el estado de las interacciones de descanso")
		await _finalizar()
		return
	_postura_cafe = _buscar_postura(_cafe)
	_postura_sofa = _buscar_postura(_sofa)
	_verificar(not _postura_cafe.is_empty(), "La cafetera se alcanza mirando hacia ella desde el suelo libre")
	_verificar(not _postura_sofa.is_empty(), "El sofá se alcanza desde una aproximación física libre")
	if _postura_cafe.is_empty() or _postura_sofa.is_empty():
		await _finalizar()
		return
	await _probar_alcance_y_rechazos()
	await _probar_cancelar_preparacion()
	await _probar_cafetera_sin_luz()
	await _probar_cafe()
	await _probar_cafe_sentado()
	await _probar_pausa_antes_de_beber()
	await _probar_reinicio_sentado_con_cafe()
	await _probar_papel()
	await _probar_sofa()
	await _probar_cero_calma()
	await _probar_salida()
	await _finalizar()


func _cargar() -> void:
	_oficina = (load(OFICINA) as PackedScene).instantiate() as Node3D
	root.add_child(_oficina)
	current_scene = _oficina
	await _cuadros(3)
	root.get_node("MenuGlobal").call("cerrar_ayuda")
	paused = false
	for nombre: String in ["temporizador_denuncias", "temporizador_bloqueos"]:
		(_oficina.get(nombre) as Timer).stop()
	(_oficina.computador.timer_nuevo_problema as Timer).stop()
	await _fisicas(50)
	_zona = _oficina.get_node("ZonaDescanso") as Node3D
	_jugador = _oficina.jugador as CharacterBody3D
	_despacho = _oficina.sistema_despacho as SistemaDespacho
	_cafe = _zona.get_node("RinconCafe/MuebleCafe") as Node3D
	_sofa = _zona.get_node("SofaL/Cuerpo") as Node3D
	_ids_tazas.assign([_zona.get_node("RinconCafe/TazaBlanca").get_instance_id(), _zona.get_node("RinconCafe/TazaAmarilla").get_instance_id()])
	_altura = _jugador.global_position.y
	_jugador.set_physics_process(false)
	(_oficina.get_node("Gameplay/Camera3D") as Node3D).set_physics_process(false)
	_caso = Denuncia.new()
	_caso.id = "QA-DESCANSO-CASO-ACTIVO"
	_caso.tiempo_limite_segundos = 600.0
	_caso.protocolo_estaciones = ["bienestar"]
	_verificar(_despacho.recibir_denuncia(_caso), "La oficina mantiene una denuncia durante el descanso")
	_verificar(_despacho.iniciar_denuncia_prioritaria() == _caso, "Se activa el protocolo normal de denuncia")


func _probar_alcance_y_rechazos() -> void:
	_saldo_y_calma(200, 60)
	var lejos: Vector3 = _postura_cafe.posicion + Vector3.RIGHT * 2.0
	await _colocar({"posicion": lejos, "giro": _postura_cafe.giro})
	await _tecla(KEY_E)
	_verificar(not _estado().preparando and _despacho.puntuacion.puntos == 200, "E fuera del alcance no inicia ni cobra un café")
	await _colocar({"posicion": _postura_cafe.posicion, "giro": float(_postura_cafe.giro) + PI})
	await _tecla(KEY_E)
	_verificar(not _estado().preparando and _despacho.puntuacion.puntos == 200, "E mirando en sentido contrario no compra café")
	await _colocar(_postura_cafe)
	_saldo_y_calma(49, 60)
	await _tecla(KEY_E)
	await _segundos(0.2)
	_verificar(not _estado().preparando and not _estado().tiene_cafe and _despacho.puntuacion.puntos == 49, "Un saldo insuficiente conserva los puntos y las tazas del mueble")
	_saldo_y_calma(200, 100)
	await _tecla(KEY_E)
	await _segundos(0.2)
	_verificar(not _estado().preparando and not _estado().tiene_cafe and _despacho.puntuacion.puntos == 200, "Con calma completa no se cobra un café innecesario")


func _probar_cafe() -> void:
	_saldo_y_calma(200, 60)
	await _colocar(_postura_cafe)
	var tiempo := _despacho.obtener_tiempo_restante(_caso.id)
	await _tecla(KEY_E)
	_verificar(_estado().preparando, "La E normal inicia la preparación de café")
	await _tecla(KEY_E)
	await _segundos(0.25)
	_verificar(_despacho.calma_operativa == 60, "Preparar café no recupera calma antes de beber")
	paused = true
	var anterior := _estado().duplicate(true)
	var puntos := _despacho.puntuacion.puntos
	await create_timer(0.3).timeout
	await _tecla(KEY_F)
	_verificar(_estado() == anterior and _despacho.puntuacion.puntos == puntos and _despacho.calma_operativa == 60, "Pausar congela la preparación y bloquea el consumo")
	paused = false
	await _esperar_estado("tiene_cafe", true, 5.0)
	_verificar(not _estado().preparando and _estado().tiene_cafe, "La preparación entrega una taza de café al jugador")
	_verificar(_despacho.puntuacion.puntos == 150, "La preparación cobra exactamente cincuenta puntos una sola vez")
	_verificar(_despacho.calma_operativa == 60, "Recibir la taza mantiene pendiente su beneficio")
	_verificar(_despacho.obtener_tiempo_restante(_caso.id) < tiempo, "Las denuncias continúan consumiendo tiempo mientras se prepara el café")
	await _tecla(KEY_E)
	await _segundos(0.15)
	_verificar(_estado().tiene_cafe and _despacho.puntuacion.puntos == 150, "Solo puede llevarse un café y repetir E no cobra otro")
	paused = true
	await _tecla(KEY_F)
	await create_timer(0.25).timeout
	_verificar(_estado().tiene_cafe and _despacho.calma_operativa == 60, "F durante pausa conserva la taza y la calma")
	paused = false
	await _tecla(KEY_F)
	await _tecla(KEY_F)
	await _esperar_estado("tiene_cafe", false, 4.0)
	await _segundos(0.8)
	_verificar(_despacho.calma_operativa == 75, "Beber recupera quince de calma exactamente una vez pese a repetir F")
	_verificar(not _estado().tiene_cafe and not _estado().bebiendo, "Al acabar se libera la mano y termina la animación de bebida")
	await _tecla(KEY_F)
	await _segundos(0.1)
	_verificar(_despacho.calma_operativa == 75 and _despacho.puntuacion.puntos == 150, "F sin café no concede calma ni modifica el saldo")
	_saldo_y_calma(150, 95)
	await _colocar(_postura_cafe)
	await _tecla(KEY_E)
	await _esperar_estado("tiene_cafe", true, 5.0)
	await _tecla(KEY_F)
	await _esperar_estado("tiene_cafe", false, 4.0)
	await _segundos(0.8)
	_verificar(_despacho.calma_operativa == 100 and _despacho.puntuacion.puntos == 100, "El café respeta el máximo de cien de calma sin cobros duplicados")


func _probar_cancelar_preparacion() -> void:
	_saldo_y_calma(200, 60)
	await _colocar(_postura_cafe)
	await _tecla(KEY_E)
	_verificar(_estado().preparando and _jugador.input_locked, "Preparar café bloquea el movimiento hasta servir o cancelar")
	await _segundos(0.35)
	await _tecla(KEY_ESCAPE)
	await _segundos(2.0)
	_verificar(not _estado().preparando and not _estado().tiene_cafe and not _estado().bebiendo, "Escape cancela la preparación sin entregar una taza tardía")
	_verificar(_despacho.puntuacion.puntos == 200 and _despacho.calma_operativa == 60, "Cancelar con Escape conserva el saldo y no concede calma")
	_verificar(not _jugador.input_locked and not _jugador.realizando_gesto() and not paused, "Cancelar devuelve el control sin abrir la pausa global")
	for id: int in _ids_tazas:
		var taza := instance_from_id(id) as MeshInstance3D
		_verificar(is_instance_valid(taza) and taza.get_parent() == _zona.get_node("RinconCafe"), "Cancelar mantiene cada taza disponible en su mueble")


func _probar_cafetera_sin_luz() -> void:
	_saldo_y_calma(200, 60)
	await _colocar(_postura_cafe)
	var evento: Node = _oficina.evento_apagon
	_verificar(bool(evento.call("iniciar_apagon")), "La oficina permite probar la cafetera durante un apagón real")
	await _tecla(KEY_E)
	await _segundos(2.0)
	_verificar(not _estado().preparando and not _estado().tiene_cafe and not _jugador.input_locked, "La cafetera sin luz rechaza el servicio sin bloquear al jugador")
	_verificar(_despacho.puntuacion.puntos == 200 and _despacho.calma_operativa == 60, "El rechazo por apagón conserva el saldo y la calma")
	# El puzzle eléctrico tiene su propia suite: repone las luces para los casos siguientes.
	evento.call("_al_interactuar_taco", _jugador)
	evento.call("_al_resolver_circuito")
	await _cuadros(3)
	_verificar(int(evento.get("estado")) == 0 and not _jugador.input_locked, "Restaurar el suministro deja las interacciones de descanso disponibles")


func _probar_pausa_antes_de_beber() -> void:
	_saldo_y_calma(200, 60)
	await _colocar(_postura_cafe)
	await _tecla(KEY_E)
	await _esperar_estado("tiene_cafe", true, 5.0)
	var taza: Node = _zona.get("taza_en_mano")
	var id_taza := taza.get_instance_id()
	await _tecla(KEY_F)
	await _segundos(0.2)
	_verificar(_estado().bebiendo and _estado().tiene_cafe and _despacho.calma_operativa == 60, "La bebida comienza sin aplicar su beneficio antes del contacto")
	var tiempo_gesto: float = _jugador.gestos.tiempo
	paused = true
	await _tecla(KEY_F)
	await create_timer(0.4).timeout
	_verificar(_estado().bebiendo and _estado().tiene_cafe and _despacho.calma_operativa == 60, "La pausa anterior al sorbo conserva el café y retrasa la recuperación")
	_verificar(is_equal_approx(_jugador.gestos.tiempo, tiempo_gesto) and (_zona.get("taza_en_mano") as Node).get_instance_id() == id_taza, "La pausa congela el gesto y conserva la misma taza sin reponerla")
	paused = false
	await _esperar_estado("tiene_cafe", false, 4.0)
	await _esperar_estado("bebiendo", false, 3.0)
	_verificar(_despacho.calma_operativa == 75 and _despacho.puntuacion.puntos == 150, "Reanudar termina el sorbo y concede el beneficio una sola vez")


func _probar_reinicio_sentado_con_cafe() -> void:
	_saldo_y_calma(200, 60)
	await _colocar(_postura_cafe)
	var capa := _jugador.collision_layer
	var mascara := _jugador.collision_mask
	await _tecla(KEY_E)
	await _esperar_estado("tiene_cafe", true, 5.0)
	var taza := _zona.get("taza_en_mano") as MeshInstance3D
	await _colocar(_postura_sofa)
	await _tecla(KEY_E)
	await _esperar_estado("sentado", true, 2.0)
	_verificar(_estado().sentado and _estado().tiene_cafe, "El reinicio se prueba sentado y con un café pagado aún sin consumir")
	_jugador.reset_to_spawn()
	await _cuadros(3)
	_verificar(not _estado().sentado and not _estado().tiene_cafe and not _estado().bebiendo and not _estado().preparando, "Reiniciar sentado limpia el asiento, el café y las operaciones pendientes")
	_verificar(not _jugador.input_locked and not _jugador.esta_sentado() and not _jugador.realizando_gesto(), "Reiniciar devuelve control y postura normal sin gesto residual")
	_verificar(_jugador.collision_layer == capa and _jugador.collision_mask == mascara, "Reiniciar restaura las capas y máscaras físicas del jugador")
	_verificar(_cabe_jugador(_jugador.global_position), "El reinicio termina en una posición física libre")
	_verificar(is_instance_valid(taza) and taza.get_parent() == _zona.get_node("RinconCafe") and not (taza.get_node("ContenidoCafe") as MeshInstance3D).visible, "El reinicio devuelve la taza real vacía a su mueble")
	await _tecla(KEY_F)
	await _segundos(2.1)
	_verificar(_despacho.calma_operativa == 60 and _despacho.puntuacion.puntos == 150, "Reiniciar no devuelve el precio del café ni regala el beneficio o pulsos tardíos del sofá")


func _probar_cafe_sentado() -> void:
	_saldo_y_calma(200, 60)
	await _colocar(_postura_cafe)
	await _tecla(KEY_E)
	await _esperar_estado("tiene_cafe", true, 5.0)
	var taza: Node = _zona.get("taza_en_mano")
	_verificar(taza != null and taza.get_instance_id() in _ids_tazas, "El café usa una de las tazas reales del mueble")
	await _colocar(_postura_sofa)
	await _tecla(KEY_E)
	await _esperar_estado("sentado", true, 2.0)
	_verificar(_estado().sentado and _estado().tiene_cafe, "Puede sentarse llevando la taza de café")
	await _tecla(KEY_F)
	await _esperar_estado("tiene_cafe", false, 4.0)
	await _esperar_estado("bebiendo", false, 3.0)
	_verificar(_estado().sentado and _jugador.input_locked, "Terminar el café sentado conserva la postura de descanso")
	_verificar(_despacho.calma_operativa >= 75 and _despacho.calma_operativa <= 77 and _despacho.puntuacion.puntos == 150, "Beber sentado suma el café una sola vez y solo la recuperación lenta del sofá")
	await _tecla(KEY_E)
	await _esperar_estado("sentado", false, 2.0)
	_verificar(not _jugador.input_locked, "Puede levantarse después de tomar café en el sofá")


func _probar_papel() -> void:
	_saldo_y_calma(200, 50)
	var hoja = load(PAPEL).new()
	hoja.denuncia_id = _caso.id
	_oficina.add_child(hoja)
	hoja.tomar(_jugador)
	_oficina.papel_actual = hoja
	await _colocar(_postura_cafe)
	await _tecla(KEY_E)
	await _segundos(0.2)
	_verificar(_jugador.papel_en_mano == hoja and hoja.portador == _jugador, "La cafetera conserva el papel de la denuncia que está en la mano")
	_verificar(not _estado().preparando and not _estado().tiene_cafe and _despacho.puntuacion.puntos == 200, "Tener las manos ocupadas impide otro café sin gastar puntos")
	await _colocar(_postura_sofa)
	await _tecla(KEY_E)
	await _esperar_estado("sentado", true, 2.0)
	_verificar(_estado().sentado and _jugador.papel_en_mano == hoja and hoja.portador == _jugador, "El sofá permite descansar sin perder el papel de la denuncia")
	await _tecla(KEY_ESCAPE)
	await _esperar_estado("sentado", false, 2.0)
	_verificar(_jugador.papel_en_mano == hoja and not _jugador.input_locked, "Al levantarse conserva el papel y recupera el control")
	_jugador.papel_en_mano = null
	_oficina.papel_actual = null
	hoja.queue_free()
	await _cuadros(2)


func _probar_sofa() -> void:
	_saldo_y_calma(200, 50)
	await _colocar(_postura_sofa)
	var tiempo := _despacho.obtener_tiempo_restante(_caso.id)
	await _tecla(KEY_E)
	await _esperar_estado("sentado", true, 2.0)
	_verificar(_estado().sentado and _jugador.input_locked, "E sienta al jugador y bloquea la locomoción normal")
	_jugador.set_physics_process(true)
	var posicion := _jugador.global_position
	Input.action_press(&"policia_prueba_izquierda")
	await _segundos(0.3)
	Input.action_release(&"policia_prueba_izquierda")
	_verificar(_jugador.global_position.distance_to(posicion) < 0.01, "Sentado no camina ni cae del asiento al pulsar movimiento")
	await _segundos(0.8)
	_verificar(_despacho.calma_operativa == 50, "Sentarse no concede la recuperación completa de inmediato")
	paused = true
	var estado_pausa := _estado().duplicate(true)
	await create_timer(0.4).timeout
	_verificar(_despacho.calma_operativa == 50 and _estado() == estado_pausa, "La pausa congela el descanso y su recuperación")
	paused = false
	await _segundos(1.2)
	_verificar(_despacho.calma_operativa == 51, "El sofá recupera un punto de calma cada dos segundos")
	_verificar(_despacho.obtener_tiempo_restante(_caso.id) < tiempo, "Las denuncias siguen activas durante el descanso")
	await _tecla(KEY_ESCAPE)
	await _esperar_estado("sentado", false, 2.0)
	_verificar(not _estado().sentado and not _jugador.input_locked and not paused, "Escape levanta al jugador sin abrir la pausa global")
	_verificar(_cabe_jugador(_jugador.global_position), "Al levantarse vuelve a un espacio físico libre")
	var calma := _despacho.calma_operativa
	await _segundos(2.1)
	_verificar(_despacho.calma_operativa == calma, "Al levantarse se detiene la regeneración de calma")
	await _colocar(_postura_sofa)
	await _tecla(KEY_E)
	await _esperar_estado("sentado", true, 2.0)
	await _tecla(KEY_E)
	await _esperar_estado("sentado", false, 2.0)
	_verificar(not _estado().sentado and not _jugador.input_locked, "E permite volver a levantarse y reentrar sin dejar bloqueos")


func _probar_cero_calma() -> void:
	_saldo_y_calma(200, 0)
	await _colocar(_postura_cafe)
	await _tecla(KEY_E)
	await _segundos(0.2)
	_verificar(not _estado().preparando and _despacho.puntuacion.puntos == 200, "Una partida sin calma no se revive comprando café")
	await _colocar(_postura_sofa)
	await _tecla(KEY_E)
	await _segundos(2.3)
	_verificar(not _estado().sentado and _despacho.calma_operativa == 0, "El sofá no revive una partida sin calma")


func _probar_salida() -> void:
	_saldo_y_calma(200, 50)
	await _colocar(_postura_sofa)
	await _tecla(KEY_E)
	await _esperar_estado("sentado", true, 2.0)
	_oficina.remove_child(_zona)
	_verificar(not _jugador.input_locked and not _jugador.esta_sentado(), "Retirar la zona mientras está sentado devuelve el control y la postura normal")
	_zona.free()
	_verificar(_cabe_jugador(_jugador.global_position), "Retirar el sofá deja al jugador fuera de los obstáculos restantes")
	_oficina.queue_free()
	await _cuadros(4)
	await _cargar()
	_saldo_y_calma(200, 50)
	_postura_cafe = _buscar_postura(_cafe)
	if _postura_cafe.is_empty():
		_verificar(false, "Reentrar permite volver a alcanzar la cafetera")
		return
	await _colocar(_postura_cafe)
	await _tecla(KEY_E)
	_verificar(_estado().preparando and _despacho.puntuacion.puntos == 200, "Una nueva preparación mantiene pendiente el cobro hasta entregar la taza")
	_oficina.remove_child(_zona)
	_zona.free()
	await _segundos(2.2)
	_verificar(not _jugador.input_locked and not _jugador.esta_sentado(), "Salir durante la preparación no deja bloqueos de movimiento ni de animación")
	_verificar(_despacho.puntuacion.puntos == 200 and _despacho.calma_operativa == 50, "Cancelar al salir no cobra el café ni concede calma")


func _estado() -> Dictionary:
	return _zona.call("obtener_estado") as Dictionary


func _saldo_y_calma(saldo: int, calma: int) -> void:
	while _despacho.puntuacion.puntos < saldo:
		var recompensa := Denuncia.new()
		_secuencia_saldo += 1
		recompensa.id = "QA-RECARGA-SALDO-%d" % _secuencia_saldo
		recompensa.nivel_riesgo = 1
		recompensa.estado = Denuncia.Estado.RESUELTA
		_despacho.puntuacion.registrar_resolucion(recompensa)
	var exceso := _despacho.puntuacion.puntos - saldo
	if exceso > 0:
		_despacho.puntuacion.gastar_puntos(exceso)
	_despacho.calma_operativa = calma
	_despacho.calma_actualizada.emit(calma)


func _buscar_postura(objetivo: Node3D) -> Dictionary:
	var centro := objetivo.global_position
	centro.y = _altura
	for direccion: Vector3 in [Vector3.RIGHT, Vector3.BACK, Vector3.FORWARD, Vector3.LEFT]:
		for paso: int in range(140):
			var candidato := centro + direccion * (1.6 - paso * 0.01)
			if not _cabe_jugador(candidato):
				continue
			_jugador.global_position = candidato
			_jugador.visual.rotation.y = atan2(-direccion.x, -direccion.z)
			var encontrado: Node3D = _jugador.obtener_objetivo_interaccion()
			if encontrado == objetivo or (encontrado != null and (objetivo.is_ancestor_of(encontrado) or encontrado.is_ancestor_of(objetivo))):
				return {"posicion": candidato, "giro": _jugador.visual.rotation.y}
	return {}


func _cabe_jugador(posicion: Vector3) -> bool:
	var forma := _jugador.get_node("Colision") as CollisionShape3D
	var transformacion := _jugador.global_transform
	transformacion.origin = posicion + Vector3.UP * 0.02
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.transform = transformacion * forma.transform
	consulta.exclude = [_jugador.get_rid()]
	consulta.collision_mask = _jugador.collision_mask
	return _oficina.get_world_3d().direct_space_state.intersect_shape(consulta).is_empty()


func _colocar(postura: Dictionary) -> void:
	_jugador.global_position = postura.posicion
	_jugador.visual.rotation.y = float(postura.giro)
	_jugador.velocity = Vector3.ZERO
	_jugador.set_physics_process(true)
	await _fisicas(2)
	_jugador.set_physics_process(false)


func _esperar_estado(clave: String, valor: bool, segundos: float) -> void:
	for i: int in range(ceili(segundos * 60.0)):
		if bool(_estado().get(clave, false)) == valor:
			return
		await process_frame
	_verificar(false, "El estado %s llega a %s antes de %s segundos" % [clave, valor, segundos])


func _tecla(tecla: Key) -> void:
	for pulsada: bool in [true, false]:
		var evento := InputEventKey.new()
		evento.physical_keycode = tecla
		evento.keycode = tecla
		evento.pressed = pulsada
		Input.parse_input_event(evento)
		await process_frame


func _segundos(segundos: float) -> void:
	await create_timer(segundos, false).timeout


func _fisicas(cantidad: int) -> void:
	for i: int in range(cantidad):
		await physics_frame
		await process_frame


func _cuadros(cantidad: int) -> void:
	for i: int in range(cantidad):
		await process_frame


func _finalizar() -> void:
	paused = false
	Input.action_release(&"policia_prueba_izquierda")
	if is_instance_valid(_oficina):
		_oficina.queue_free()
	await _cuadros(4)
	var limite := Time.get_ticks_msec() + 500
	while Time.get_ticks_msec() < limite:
		await process_frame
	print("[INTERACCIONES DESCANSO] %d comprobaciones, %d errores." % [_comprobaciones, _errores.size()])
	quit(0 if _errores.is_empty() else 1)


func _verificar(condicion: bool, descripcion: String) -> void:
	_comprobaciones += 1
	if not condicion:
		_errores.append(descripcion)
		push_error("[INTERACCIONES DESCANSO] " + descripcion)
