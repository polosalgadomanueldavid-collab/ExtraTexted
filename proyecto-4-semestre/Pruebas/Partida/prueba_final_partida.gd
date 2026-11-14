extends SceneTree

var fallos: int = 0


func _initialize() -> void:
	probar.call_deferred()


func probar() -> void:
	var oficina: Variant = (load("res://Mundo/Oficina.tscn") as PackedScene).instantiate()
	root.add_child(oficina)
	current_scene = oficina
	var intentos := 0
	while oficina.final_partida == null and intentos < 20:
		await physics_frame
		intentos += 1
	_verificar(oficina.final_partida != null, "La oficina crea la secuencia final")
	if oficina.final_partida == null:
		quit(1)
		return
	await process_frame
	var menu_global: Variant = root.get_node_or_null("MenuGlobal")
	if menu_global != null and menu_global.panel_ayuda.visible:
		menu_global.cerrar_ayuda()

	var despacho: SistemaDespacho = oficina.sistema_despacho
	var resuelta := Denuncia.new()
	resuelta.id = "resuelta-prueba"
	resuelta.titulo = "Caso resuelto"
	resuelta.protocolo_estaciones = ["evidencias"]
	despacho.recibir_denuncia(resuelta)
	resuelta.estaciones_completadas = ["evidencias"]
	despacho.resolver_denuncia(resuelta.id)
	var vencida := Denuncia.new()
	vencida.id = "vencida-prueba"
	vencida.titulo = "Suplantación pendiente"
	vencida.protocolo_estaciones = ["evidencias", "reporte"]
	vencida.penalidad_calma = 10
	vencida.tiempo_limite_segundos = 1.0
	despacho.recibir_denuncia(vencida)
	vencida.estaciones_completadas = ["evidencias"]
	var abierta := Denuncia.new()
	abierta.id = "abierta-prueba"
	abierta.titulo = "Caso abierto"
	abierta.protocolo_estaciones = ["verificacion"]
	abierta.tiempo_limite_segundos = 100.0
	despacho.recibir_denuncia(abierta)
	var posicion_inicial: Vector3 = oficina.jugador.global_position
	despacho.calma_operativa = 10
	despacho.actualizar_tiempos(2.0)

	_verificar(oficina.partida_finalizada and despacho.terminada and paused, "El primer vencimiento fatal detiene la partida")
	_verificar(oficina.final_partida._fase == 1 and not oficina.final_partida._relevo_finalizado, "El final empieza por la cinemática de relevo")
	_verificar(oficina.jugador.input_locked, "El jugador deja de aceptar movimiento durante el final")
	_verificar(not oficina.final_partida._saltar.is_visible_in_tree() and oficina.final_partida._saltar.disabled, "La opción del cuaderno permanece oculta y bloqueada durante la cinemática")
	_verificar(not oficina.final_partida._tarjeta.visible and not oficina.final_partida._cuaderno.visible, "Ninguna tarjeta tapa la llegada del compañero")
	_verificar(oficina.final_partida._aviso_cinematica.visible and oficina.final_partida._titulo_caso.text == "El equipo toma el relevo", "El aviso de relevo acompaña la cinemática")
	_verificar(oficina.final_partida._datos["causa"]["titulo"] == "Suplantación pendiente", "La denuncia causante se conserva para el cuaderno")
	await process_frame
	var cinematica: Variant = oficina.cinematica_relevo
	_verificar(is_instance_valid(cinematica), "La oficina crea la escena de relevo")
	if not is_instance_valid(cinematica):
		quit(1)
		return
	var puerta: Node3D = oficina.get_node("PuertaRelevo")
	_verificar(not _cabe_en_el_umbral(puerta, oficina.jugador, 0.0), "La hoja cerrada impide el paso al pasillo")
	_verificar(root.get_camera_3d() == cinematica.camara, "La cámara de la cinemática toma el control")
	_verificar(puerta.to_local(cinematica.companero.global_position).z < 0.0, "El compañero comienza detrás de la puerta")
	await create_timer(0.2, true).timeout
	var posicion_quieto: Vector3 = oficina.jugador.global_position
	_verificar(Vector2(posicion_inicial.x, posicion_inicial.z).distance_to(Vector2(posicion_quieto.x, posicion_quieto.z)) < 0.01 and oficina.jugador.velocity.is_zero_approx(), "El jugador permanece quieto mientras la cámara descubre la puerta")
	oficina.final_partida._abrir_cuaderno()
	_verificar(oficina.final_partida._fase == 1 and not oficina.final_partida._cuaderno.visible, "No se puede saltar la cinemática abriendo el cuaderno")
	_verificar(oficina._resueltas.size() == 1 and oficina._vencidas.size() == 1, "El historial guarda resueltos y vencidos")
	_verificar(despacho.obtener_denuncias_ordenadas().size() == 1, "El caso abierto permanece para el cuaderno")
	var tardia := Denuncia.new()
	tardia.id = "tardia-prueba"
	_verificar(not despacho.recibir_denuncia(tardia) and not despacho.interactuar_estacion("verificacion"), "No se puede avanzar tras el final")
	var dialogo_visible := await _esperar_condicion(func() -> bool: return cinematica.burbuja.visible, 150)
	_verificar(dialogo_visible, "El compañero habla en una burbuja durante la cinemática")
	_verificar(puerta.pivote.rotation.y > deg_to_rad(80.0) and puerta._colision_hoja.disabled, "La puerta está abierta y deja libre el paso del relevo")
	_verificar(_cabe_en_el_umbral(puerta, oficina.jugador, -0.16) and _cabe_en_el_umbral(puerta, oficina.jugador, 0.16), "El cuerpo entero cabe en el vano al entrar y al salir")
	_verificar(puerta.to_local(cinematica.companero.global_position).z > 0.0, "El compañero ha atravesado la puerta al hablar")
	_verificar(not oficina.final_partida._cuaderno.visible and not oficina.final_partida._relevo_finalizado, "El cuaderno sigue cerrado mientras se representa el relevo")
	if _capturas_habilitadas():
		await RenderingServer.frame_post_draw
		var ruta_relevo := ProjectSettings.globalize_path("user://prueba_relevo.png")
		get_root().get_texture().get_image().save_png(ruta_relevo)
		print("Captura relevo: ", ruta_relevo)
	var relevo_terminado := await _esperar_relevo(oficina.final_partida)
	_verificar(relevo_terminado, "La cinemática termina mientras la partida está pausada")
	if not relevo_terminado:
		quit(1)
		return
	_verificar(cinematica.finalizada and cinematica.jugador_salio and cinematica.companero_llego, "La tarjeta espera a que ambos personajes completen el recorrido")
	_verificar(not oficina.jugador.visible and puerta.to_local(oficina.jugador.global_position).z < 0.0, "El jugador desaparece solo tras salir al pasillo")
	var puesto_relevo: Vector3 = cinematica.companero.global_position
	_verificar(Vector2(puesto_relevo.x, puesto_relevo.z).distance_to(Vector2(posicion_inicial.x, posicion_inicial.z)) < 0.05, "El compañero ocupa el puesto que dejó el jugador")
	_verificar(is_zero_approx(puerta.pivote.rotation.y) and not puerta._colision_hoja.disabled, "La puerta se cierra después de la salida")
	_verificar(oficina.final_partida._fase == 1 and not oficina.final_partida._cuaderno.visible, "Terminar la cinemática espera la decisión de ir al cuaderno")
	_verificar(oficina.final_partida._tarjeta.visible and oficina.final_partida._saltar.is_visible_in_tree() and not oficina.final_partida._saltar.disabled, "La tarjeta final habilita el cuaderno solo después del relevo")
	_verificar(not oficina.final_partida._aviso_cinematica.visible and oficina.final_partida._detalle.text == "Tu turno termina aquí.", "La tarjeta final reemplaza el aviso con el cierre del turno")
	if _capturas_habilitadas():
		await create_timer(0.5, true, false, true).timeout
		await RenderingServer.frame_post_draw
		var ruta_tarjeta := ProjectSettings.globalize_path("user://prueba_fin_turno.png")
		get_root().get_texture().get_image().save_png(ruta_tarjeta)
		print("Captura fin del turno: ", ruta_tarjeta)
	await create_timer(1.0, true, false, true).timeout
	_verificar(not oficina.final_partida._cuaderno.visible, "La tarjeta final no abre el cuaderno automáticamente")
	oficina.final_partida._saltar.emit_signal("pressed")
	await process_frame
	_verificar(oficina.final_partida._fase == 2 and oficina.final_partida._cuaderno.visible, "Ir al cuaderno abre el balance después de la cinemática")
	_verificar(oficina.final_partida._estadisticas.text.contains("1 de 3"), "Las estadísticas reflejan el turno")
	if _capturas_habilitadas():
		await RenderingServer.frame_post_draw
		var ruta := ProjectSettings.globalize_path("user://prueba_final_partida.png")
		get_root().get_texture().get_image().save_png(ruta)
		print("Captura: ", ruta)
	oficina.final_partida._siguiente.emit_signal("pressed")
	await create_timer(0.8, true, false, true).timeout
	_verificar(oficina.final_partida._pagina_actual == 1 and (oficina.final_partida._paginas[0]["titulo"] as Label).text == "Lo que hiciste", "Las páginas muestran resueltos y vencidos")
	if _capturas_habilitadas():
		await RenderingServer.frame_post_draw
		var ruta_casos := ProjectSettings.globalize_path("user://prueba_cuaderno_casos.png")
		get_root().get_texture().get_image().save_png(ruta_casos)
		print("Captura casos: ", ruta_casos)
	oficina.final_partida._pestanas[2].emit_signal("pressed")
	await create_timer(0.8, true, false, true).timeout
	_verificar(oficina.final_partida._pagina_actual == 2 and (oficina.final_partida._paginas[1]["titulo"] as Label).text == "Estadísticas", "La última apertura muestra pendientes y gráficos")
	_verificar(oficina.final_partida._cuerpo(1).get_child_count() >= 9, "Los gráficos incluyen resultados y estaciones")
	if _capturas_habilitadas():
		await RenderingServer.frame_post_draw
		var ruta_graficos := ProjectSettings.globalize_path("user://prueba_cuaderno_graficos.png")
		get_root().get_texture().get_image().save_png(ruta_graficos)
		print("Captura gráficos: ", ruta_graficos)
	oficina.final_partida._pestanas[0].emit_signal("pressed")
	await create_timer(0.8, true, false, true).timeout
	_verificar(oficina.final_partida._pagina_actual == 0, "Las pestañas regresan al balance")
	oficina._reiniciar_despues_del_final()
	for indice: int in range(20):
		if is_instance_valid(current_scene) and current_scene != oficina:
			break
		await process_frame
	_verificar(not paused and current_scene != oficina and is_instance_valid(current_scene), "Jugar de nuevo abre una partida limpia")
	var nueva_oficina: Variant = current_scene
	for indice: int in range(20):
		if nueva_oficina.final_partida != null:
			break
		await physics_frame
	await create_timer(0.3, true, false, true).timeout
	nueva_oficina._volver_al_menu_despues_del_final()
	for indice: int in range(20):
		if is_instance_valid(current_scene) and current_scene.scene_file_path == "res://UI/Menus/MainMenu.tscn":
			break
		await process_frame
	_verificar(is_instance_valid(current_scene) and current_scene.scene_file_path == "res://UI/Menus/MainMenu.tscn", "El cuaderno permite volver al menú")
	quit(1 if fallos > 0 else 0)


func _esperar_relevo(final: FinalPartida) -> bool:
	# Espera el estado real de la escena, con límite incluso si falla su señal final.
	return await _esperar_condicion(func() -> bool: return final._relevo_finalizado)


func _cabe_en_el_umbral(puerta: Node3D, jugador: CharacterBody3D, lateral: float) -> bool:
	var colision := jugador.get_node("Colision") as CollisionShape3D
	var caja := colision.shape as BoxShape3D
	var medidas := caja.size * colision.global_basis.get_scale()
	var consulta := PhysicsShapeQueryParameters3D.new()
	var cuerpo := BoxShape3D.new()
	cuerpo.size = medidas
	consulta.shape = cuerpo
	consulta.collision_mask = 1
	consulta.transform = Transform3D(puerta.global_basis, puerta.to_global(Vector3(lateral, medidas.y * 0.5 + 0.02, 0)))
	return puerta.get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty()


func _esperar_condicion(condicion: Callable, intentos: int = 450) -> bool:
	for intento: int in range(intentos):
		if condicion.call():
			return true
		await create_timer(0.1, true, false, true).timeout
	return false


func _capturas_habilitadas() -> bool:
	return OS.get_environment("CAPTURAR_FINAL") == "1" and DisplayServer.get_name() != "headless"


func _verificar(condicion: bool, descripcion: String) -> void:
	if condicion:
		print("OK: ", descripcion)
	else:
		fallos += 1
		push_error("FALLO: " + descripcion)
