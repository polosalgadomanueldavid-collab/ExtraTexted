extends SceneTree
## --headless --fixed-fps 60 --script res://Pruebas/Partida/prueba_relevo_eventos.gd

var fallos := 0


func _initialize() -> void:
	probar.call_deferred()


func probar() -> void:
	for escenario: String in ["junto_puerta", "reparando_apagon", "caida_terremoto"]:
		await _probar_escenario(escenario)
	print("[RELEVO EVENTOS] %d fallos" % fallos)
	quit(0 if fallos == 0 else 1)


func _probar_escenario(escenario: String) -> void:
	var menu: Node = root.get_node("MenuGlobal")
	menu.final_de_partida_activo = false
	menu.omitir_tutorial_siguiente_partida = true
	paused = false
	change_scene_to_file("res://Mundo/Oficina.tscn")
	await scene_changed
	var oficina: Node3D = current_scene
	for cuadro: int in range(5):
		await physics_frame
	menu.cerrar_ayuda()
	oficina.temporizador_denuncias.stop()
	oficina.temporizador_bloqueos.stop()
	oficina.computador.timer_nuevo_problema.stop()
	oficina.sistema_despacho.set_process(false)
	oficina.jugador.set_physics_process(false)
	var puerta: Node3D = oficina.get_node("PuertaRelevo")
	var luces: Dictionary = {}

	match escenario:
		"junto_puerta":
			oficina.jugador.global_position = puerta.to_global(Vector3(0.24, 0.0, 0.95))
		"reparando_apagon":
			oficina.tutoriales_vistos[&"apagon"] = true
			for luz: Light3D in oficina.evento_apagon.luces:
				luces[luz] = luz.visible
			_verificar(oficina.evento_apagon.iniciar_apagon(), "Se prepara el apagón real")
			oficina.evento_apagon._al_interactuar_taco(oficina.jugador)
			_verificar(oficina.evento_apagon.panel.visible and oficina.jugador.input_locked, "El final puede ocurrir reparando un circuito")
		"caida_terremoto":
			oficina.tutoriales_vistos[&"terremoto"] = true
			oficina.generador_aleatorio.seed = 1414
			oficina.evento_terremoto._azar.seed = 8762
			oficina._recibir_denuncia_aleatoria()
			oficina.temporizador_denuncias.stop()
			oficina._iniciar_terremoto()
			_verificar(oficina.evento_terremoto.activo, "Se prepara el terremoto real")
			if oficina.evento_terremoto.activo:
				oficina.evento_terremoto._abrir_suelo()
				_verificar(not oficina.grafo_piso.grietas.is_empty(), "La pérdida del turno ocurre con el suelo roto")
				oficina.jugador.global_position.y = puerta.global_position.y - 0.4

	var fatal := Denuncia.new()
	fatal.id = "final-" + escenario
	fatal.titulo = "Cierre durante " + escenario
	fatal.penalidad_calma = 10
	fatal.protocolo_estaciones = ["reporte"]
	oficina.sistema_despacho.recibir_denuncia(fatal)
	oficina.sistema_despacho.calma_operativa = 10
	oficina.sistema_despacho.vencer_denuncia(fatal.id)
	await process_frame
	_verificar(oficina.partida_finalizada and paused and is_instance_valid(oficina.cinematica_relevo), escenario + ": se inicia el relevo con la partida detenida")
	_verificar(not oficina.final_partida._tarjeta.visible and not oficina.final_partida._cuaderno.visible, escenario + ": el cierre espera la escena")
	if escenario == "reparando_apagon":
		_verificar(not oficina.evento_apagon.panel.visible and not oficina.evento_apagon.mascara.visible and not oficina.evento_apagon.indicador_luz.visible, "El circuito y la oscuridad dejan ver la cinemática")
		var luces_restauradas := true
		for luz: Light3D in luces:
			luces_restauradas = luces_restauradas and luz.visible == luces[luz]
		_verificar(luces_restauradas, "El relevo recupera la iluminación de la oficina")
	elif escenario == "caida_terremoto":
		_verificar(not oficina.evento_terremoto.activo and oficina.grafo_piso.grietas.is_empty(), "El relevo recompone el suelo antes de caminar")
		_verificar(oficina.bloqueos_visuales.is_empty(), "Los cajones temporales dejan libre la ruta de salida")

	for intento: int in range(450):
		if oficina.final_partida._relevo_finalizado:
			break
		await create_timer(0.1, true, false, true).timeout
	_verificar(oficina.final_partida._relevo_finalizado, escenario + ": la cinemática alcanza el cierre")
	if oficina.final_partida._relevo_finalizado:
		_verificar(oficina.cinematica_relevo.jugador_salio and oficina.cinematica_relevo.companero_llego, escenario + ": ambos actores completan su recorrido")
		_verificar(oficina.final_partida._saltar.is_visible_in_tree() and not oficina.final_partida._cuaderno.visible, escenario + ": se ofrece el cuaderno sin abrirlo automáticamente")


func _verificar(condicion: bool, detalle: String) -> void:
	if condicion:
		print("OK: ", detalle)
	else:
		fallos += 1
		push_error("FALLO: " + detalle)
