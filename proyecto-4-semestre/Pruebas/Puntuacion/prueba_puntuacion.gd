extends Node
## Ejecutar: Godot --headless --path <proyecto> res://Pruebas/Puntuacion/PruebaPuntuacion.tscn
## Añadir -- --solo-core para omitir la oficina y los cambios reales de escena.

var _errores: Array[String] = []
var _comprobaciones: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_probar")


func _probar() -> void:
	_probar_recompensas()
	_probar_niveles_y_acumulacion()
	_probar_registros_rechazados()
	_probar_integracion_despacho()
	_probar_instancias_independientes()
	if not "--solo-core" in OS.get_cmdline_user_args():
		var clasificacion_real := MenuGlobal._clasificacion
		var ruta := "user://prueba_clasificacion_%d.json" % OS.get_process_id()
		MenuGlobal._clasificacion = ClasificacionLocal.new(ruta)
		await _probar_pausa_y_nueva_partida(ruta)
		MenuGlobal._clasificacion = clasificacion_real
		if FileAccess.file_exists(ruta):
			DirAccess.remove_absolute(ruta)
	get_tree().paused = false
	print("PRUEBAS DE PUNTUACION: %d comprobaciones, %d errores" % [_comprobaciones, _errores.size()])
	get_tree().quit(0 if _errores.is_empty() else 1)


func _probar_recompensas() -> void:
	_verificar(Denuncia.PUNTOS_POR_NIVEL == 100, "La recompensa base es de 100 puntos por nivel")
	var denuncia := _crear_denuncia("recompensa", 1)
	_verificar(denuncia.puntaje_recompensa == 0, "La recompensa predeterminada se calcula automáticamente")
	for nivel: int in range(1, 6):
		denuncia.nivel_riesgo = nivel
		_verificar(denuncia.obtener_puntaje_recompensa() == nivel * 100, "Recompensa automática del nivel %d" % nivel)
	denuncia.nivel_riesgo = 0
	_verificar(denuncia.obtener_puntaje_recompensa() == 100, "Un riesgo inferior al rango usa el nivel mínimo")
	denuncia.nivel_riesgo = 6
	_verificar(denuncia.obtener_puntaje_recompensa() == 500, "Un riesgo superior al rango usa el nivel máximo")
	denuncia.puntaje_recompensa = 725
	_verificar(denuncia.obtener_puntaje_recompensa() == 725, "Una recompensa positiva sustituye el cálculo automático")
	denuncia.estado = Denuncia.Estado.RESUELTA
	var puntuacion := SistemaPuntuacion.new()
	_verificar(puntuacion.registrar_resolucion(denuncia) == 725 and puntuacion.puntos == 725, "El saldo recibe la recompensa personalizada")


func _probar_niveles_y_acumulacion() -> void:
	var puntuacion := SistemaPuntuacion.new()
	var totales_emitidos: Array[int] = []
	puntuacion.puntos_actualizados.connect(func(total: int) -> void: totales_emitidos.append(total))
	_verificar(puntuacion.puntos == 0, "Una puntuación nueva empieza en cero")
	var total_esperado: int = 0
	for nivel: int in range(1, 6):
		var denuncia := _crear_denuncia("nivel-%d" % nivel, nivel)
		denuncia.estado = Denuncia.Estado.RESUELTA
		var premio := puntuacion.registrar_resolucion(denuncia)
		total_esperado += nivel * 100
		_verificar(premio == nivel * 100, "Registrar nivel %d devuelve su recompensa" % nivel)
		_verificar(puntuacion.puntos == total_esperado, "El nivel %d se suma al saldo anterior" % nivel)
	_verificar(puntuacion.puntos == 1500, "Los niveles uno a cinco acumulan 1500 puntos")
	_verificar(totales_emitidos == [100, 300, 600, 1000, 1500], "La señal publica cada total acumulado")


func _probar_registros_rechazados() -> void:
	var puntuacion := SistemaPuntuacion.new()
	var totales_emitidos: Array[int] = []
	puntuacion.puntos_actualizados.connect(func(total: int) -> void: totales_emitidos.append(total))
	_verificar(puntuacion.registrar_resolucion(null) == 0, "Una denuncia nula no otorga puntos")
	var sin_id := _crear_denuncia("", 5)
	sin_id.estado = Denuncia.Estado.RESUELTA
	_verificar(puntuacion.registrar_resolucion(sin_id) == 0, "Una resolución sin ID no otorga puntos")
	var denuncia := _crear_denuncia("estado-rechazado", 3)
	for estado: Denuncia.Estado in [Denuncia.Estado.PENDIENTE, Denuncia.Estado.EN_PROCESO, Denuncia.Estado.VENCIDA]:
		denuncia.estado = estado
		_verificar(puntuacion.registrar_resolucion(denuncia) == 0, "El estado %d no otorga puntos" % estado)
	_verificar(puntuacion.puntos == 0 and totales_emitidos.is_empty(), "Los registros rechazados conservan saldo y señales")
	denuncia.estado = Denuncia.Estado.RESUELTA
	_verificar(puntuacion.registrar_resolucion(denuncia) == 300, "Rechazar un estado previo permite premiar la resolución posterior")
	_verificar(puntuacion.registrar_resolucion(denuncia) == 0, "El mismo recurso resuelto no se premia dos veces")
	var mismo_id := _crear_denuncia(denuncia.id, 5)
	mismo_id.estado = Denuncia.Estado.RESUELTA
	_verificar(puntuacion.registrar_resolucion(mismo_id) == 0, "Otro recurso con el mismo ID tampoco duplica el premio")
	_verificar(puntuacion.puntos == 300 and totales_emitidos == [300], "Los duplicados no modifican el saldo ni emiten actualizaciones")


func _probar_integracion_despacho() -> void:
	var sistema := SistemaDespacho.new()
	var saldos_al_resolver: Array[int] = []
	sistema.denuncia_resuelta.connect(func(_caso: Denuncia) -> void: saldos_al_resolver.append(sistema.puntuacion.puntos))
	var caso := _crear_denuncia("protocolo", 3)
	caso.protocolo_estaciones = ["evidencias", "reporte"]
	_verificar(sistema.recibir_denuncia(caso), "El despacho recibe el caso de protocolo")
	_verificar(sistema.iniciar_denuncia_prioritaria() == caso, "El despacho activa el caso prioritario")
	_verificar(sistema.puntuacion.puntos == 0, "Aceptar un caso conserva el saldo")
	_verificar(not sistema.interactuar_estacion("privacidad"), "Una estación incorrecta se rechaza")
	_verificar(caso.estaciones_completadas.is_empty() and sistema.puntuacion.puntos == 0, "Una estación incorrecta no avanza ni premia")
	_verificar(sistema.interactuar_estacion("reporte"), "Reporte se puede completar primero")
	_verificar(caso.estado == Denuncia.Estado.EN_PROCESO and sistema.puntuacion.puntos == 0, "Un protocolo parcial no otorga puntos")
	_verificar(not sistema.interactuar_estacion("reporte") and caso.estaciones_completadas.size() == 1, "Repetir reporte no completa la estación que falta")
	_verificar(sistema.interactuar_estacion("evidencias"), "La estación pendiente completa el protocolo")
	_verificar(caso.estado == Denuncia.Estado.RESUELTA and sistema.puntuacion.puntos == 300, "La estación final resuelve y premia una sola vez")
	_verificar(saldos_al_resolver == [300], "La señal de resolución observa el saldo ya actualizado")
	_verificar(not sistema.resolver_denuncia(caso.id), "Resolver de nuevo el caso eliminado devuelve false")
	_verificar(not sistema.resolver_denuncia("inexistente"), "Resolver un ID inexistente devuelve false")
	_verificar(sistema.puntuacion.puntos == 300, "Las resoluciones inexistentes conservan el saldo")
	var vencido := _crear_denuncia("vencido", 5)
	vencido.tiempo_limite_segundos = 0.1
	sistema.recibir_denuncia(vencido)
	sistema.actualizar_tiempos(0.2)
	_verificar(vencido.estado == Denuncia.Estado.VENCIDA and sistema.puntuacion.puntos == 300, "Vencer un caso no otorga puntos")
	_verificar(not sistema.resolver_denuncia(vencido.id), "Un caso ya vencido no puede resolverse después")
	var duplicado := _crear_denuncia(caso.id, 5)
	sistema.recibir_denuncia(duplicado)
	sistema.resolver_denuncia(duplicado.id)
	_verificar(sistema.puntuacion.puntos == 300, "Reingresar un ID premiado conserva la deduplicación de la partida")
	sistema.free()


func _probar_instancias_independientes() -> void:
	var primera := SistemaDespacho.new()
	var segunda := SistemaDespacho.new()
	var caso := _crear_denuncia("entre-partidas", 4)
	primera.recibir_denuncia(caso)
	primera.resolver_denuncia(caso.id)
	_verificar(primera.puntuacion != segunda.puntuacion, "Cada despacho tiene su propio sistema de puntuación")
	_verificar(primera.puntuacion.puntos == 400 and segunda.puntuacion.puntos == 0, "Una nueva partida empieza en cero sin alterar la anterior")
	var mismo_id := _crear_denuncia(caso.id, 4)
	segunda.recibir_denuncia(mismo_id)
	segunda.resolver_denuncia(mismo_id.id)
	_verificar(segunda.puntuacion.puntos == 400, "La deduplicación empieza de nuevo en una partida distinta")
	primera.free()
	segunda.free()


func _probar_pausa_y_nueva_partida(ruta_clasificacion: String) -> void:
	# El ejecutor permanece en la raíz mientras el menú reemplaza la escena actual.
	get_tree().current_scene = null
	if not await _cargar_escena(MenuGlobal.ESCENA_MENU):
		return
	if not await _jugar_desde_menu("Lina"):
		return
	var oficina := get_tree().current_scene
	var sistema := oficina.get("sistema_despacho") as SistemaDespacho
	_verificar(sistema != null, "La oficina crea su despacho real")
	if sistema == null:
		return
	var puntuacion_anterior: SistemaPuntuacion = sistema.puntuacion
	_verificar(sistema.puntuacion.puntos == 0, "La oficina comienza con saldo cero")
	var caso := _crear_denuncia("sesion-real", 2)
	sistema.recibir_denuncia(caso)
	sistema.resolver_denuncia(caso.id)
	_verificar(sistema.puntuacion.puntos == 200, "Resolver dentro de la oficina actualiza el saldo de la sesión")
	var pendiente := _crear_denuncia("pausa-puntuacion", 1)
	sistema.recibir_denuncia(pendiente)
	var tabla_partida: Control = oficina.clasificacion_partida
	_enviar_tab(true)
	await get_tree().process_frame
	_verificar(tabla_partida.visible and not get_tree().paused, "Mantener Tab muestra la clasificación sin pausar")
	_verificar(tabla_partida.tus_puntos.text == "200" and tabla_partida.filas.get_child_count() == 1, "La tabla muestra el puntaje actual y el récord guardado")
	var tiempo_con_tabla := sistema.obtener_tiempo_restante(pendiente.id)
	for cuadro: int in range(3):
		await get_tree().process_frame
	_verificar(sistema.obtener_tiempo_restante(pendiente.id) < tiempo_con_tabla, "La denuncia sigue avanzando mientras se consulta la tabla")
	_enviar_tab(false)
	await get_tree().process_frame
	_verificar(not tabla_partida.visible, "Soltar Tab oculta la clasificación")
	_enviar_tab(true)
	await get_tree().process_frame
	MenuGlobal.abrir_pausa()
	_verificar(get_tree().paused and MenuGlobal.panel_pausa.visible, "La pausa real se abre en la oficina")
	_verificar(not tabla_partida.visible, "La pausa oculta la clasificación de la partida")
	var tiempo_antes := sistema.obtener_tiempo_restante(pendiente.id)
	for cuadro: int in range(5):
		await get_tree().process_frame
	_verificar(sistema.puntuacion.puntos == 200, "La pausa conserva los puntos ganados")
	_verificar(is_equal_approx(sistema.obtener_tiempo_restante(pendiente.id), tiempo_antes), "La pausa congela también el tiempo del caso pendiente")
	MenuGlobal.reanudar_juego()
	_verificar(not get_tree().paused and sistema.puntuacion.puntos == 200, "Reanudar conserva el saldo")
	_enviar_tab(true, true)
	await get_tree().process_frame
	_verificar(not tabla_partida.visible, "Reanudar con Tab sostenido requiere una nueva pulsación")
	_enviar_tab(false)
	MenuGlobal.abrir_pausa()
	MenuGlobal.volver_al_menu()
	if not await _esperar_escena(MenuGlobal.ESCENA_MENU):
		return
	_verificar(not get_tree().paused, "Volver al menú termina la pausa de la partida anterior")
	if not await _jugar_desde_menu("Álex"):
		return
	var nuevo_sistema := get_tree().current_scene.get("sistema_despacho") as SistemaDespacho
	_verificar(nuevo_sistema != null, "Jugar de nuevo crea otro despacho")
	if nuevo_sistema == null:
		return
	_verificar(nuevo_sistema.puntuacion != puntuacion_anterior and nuevo_sistema.puntuacion.puntos == 0, "Volver al menú y jugar de nuevo reinicia los puntos")
	_verificar(puntuacion_anterior.puntos == 200, "El nuevo saldo pertenece a una instancia independiente")
	var repetido := _crear_denuncia(caso.id, 2)
	nuevo_sistema.recibir_denuncia(repetido)
	nuevo_sistema.resolver_denuncia(repetido.id)
	_verificar(nuevo_sistema.puntuacion.puntos == 200, "El mismo ID puede ganar puntos en la nueva sesión")
	var extra := _crear_denuncia("segundo-caso", 1)
	_enviar_tab(true)
	await get_tree().process_frame
	nuevo_sistema.recibir_denuncia(extra)
	nuevo_sistema.resolver_denuncia(extra.id)
	var tabla_nueva_partida: Control = get_tree().current_scene.clasificacion_partida
	_verificar(tabla_nueva_partida.tus_puntos.text == "300" and tabla_nueva_partida.tu_puesto.text.ends_with("#1"), "La clasificación abierta actualiza el puntaje y la posición")
	_enviar_tab(false)
	var clasificacion_recargada := ClasificacionLocal.new(ruta_clasificacion)
	_verificar(clasificacion_recargada.cargar() == OK, "Los récords se guardan antes de salir de la partida")
	_verificar(clasificacion_recargada.obtener_clasificacion() == [
		{"nombre": "Álex", "puntos": 300}, {"nombre": "Lina", "puntos": 200},
	], "El archivo conserva los mejores puntajes de ambos jugadores en orden")
	if await _cargar_escena(MenuGlobal.ESCENA_MENU):
		get_tree().current_scene.get_node("%RankingButton").pressed.emit()
		var panel := MenuGlobal.panel_clasificacion
		_verificar(panel.tabla.is_visible_in_tree() and panel.filas.get_child_count() == 2, "La clasificación del menú muestra ambos récords")
		panel.boton_volver.pressed.emit()


func _jugar_desde_menu(nombre: String) -> bool:
	var boton := get_tree().current_scene.get_node_or_null("%PlayButton") as Button
	_verificar(boton != null, "El menú dispone de su botón Jugar")
	if boton == null:
		return false
	boton.pressed.emit()
	var campo := MenuGlobal.panel_clasificacion.nombre_jugador
	_verificar(campo.is_visible_in_tree(), "Jugar permite identificar al jugador")
	campo.text = nombre
	campo.text_submitted.emit(nombre)
	if not await _esperar_escena(MenuGlobal.ESCENA_JUEGO):
		return false
	_verificar(MenuGlobal.nombre_partida == nombre, "La oficina recibe el nombre confirmado")
	MenuGlobal.cerrar_ayuda()
	# El gestor termina de configurar la oficina después de un cuadro físico.
	await get_tree().physics_frame
	for cuadro: int in range(3):
		await get_tree().process_frame
	var oficina := get_tree().current_scene
	var temporizador_denuncias := oficina.get("temporizador_denuncias") as Timer
	var temporizador_bloqueos := oficina.get("temporizador_bloqueos") as Timer
	_verificar(temporizador_denuncias != null and temporizador_bloqueos != null, "La oficina termina de configurar sus temporizadores")
	if temporizador_denuncias == null or temporizador_bloqueos == null:
		return false
	temporizador_denuncias.stop()
	temporizador_bloqueos.stop()
	return true


func _enviar_tab(pulsada: bool, repetida: bool = false) -> void:
	var evento := InputEventKey.new()
	evento.keycode = KEY_TAB
	evento.physical_keycode = KEY_TAB
	evento.pressed = pulsada
	evento.echo = repetida
	Input.parse_input_event(evento)


func _cargar_escena(ruta: String) -> bool:
	var error := get_tree().change_scene_to_file(ruta)
	_verificar(error == OK, "Se solicita la escena %s" % ruta)
	if error != OK:
		return false
	return await _esperar_escena(ruta)


func _esperar_escena(ruta: String) -> bool:
	for cuadro: int in range(120):
		await get_tree().process_frame
		var escena := get_tree().current_scene
		if is_instance_valid(escena) and escena.scene_file_path == ruta:
			return true
	_verificar(false, "La escena %s está disponible después del cambio" % ruta)
	return false


func _crear_denuncia(id: String, nivel: int) -> Denuncia:
	var denuncia := Denuncia.new()
	denuncia.id = id
	denuncia.titulo = "Prueba de puntuación " + id
	denuncia.nivel_riesgo = nivel
	denuncia.tiempo_limite_segundos = 60.0
	return denuncia


func _verificar(condicion: bool, descripcion: String) -> void:
	_comprobaciones += 1
	if condicion:
		print("OK: ", descripcion)
	else:
		_errores.append(descripcion)
		push_error("FALLO: " + descripcion)
