extends SceneTree
## --headless --fixed-fps 60 --script res://Pruebas/Partida/prueba_relevo_eventos.gd
## Muestrea el recorrido entero, no solo las posiciones inicial/final.

var fallos := 0


func _initialize() -> void:
	probar.call_deferred()


func probar() -> void:
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280, 720)
	for escenario: String in ["junto_puerta", "umbral", "pasillo", "reparando_apagon", "caida_terremoto", "aviso_terremoto", "inundacion", "hielo", "inundacion_puerta", "hielo_puerta", "incendio", "lava"]:
		if not OS.get_environment("RELEVO_ESCENARIO").is_empty() and OS.get_environment("RELEVO_ESCENARIO") != escenario:
			continue
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
	for cuadro in 12:
		await physics_frame
	menu.cerrar_ayuda()
	for evento: StringName in [&"apagon", &"terremoto", &"inundacion", &"hielo", &"lava", &"incendio"]:
		oficina.tutoriales_vistos[evento] = true
	oficina.generador_aleatorio.seed = 1414
	oficina.evento_terremoto._azar.seed = 8762
	oficina._recibir_denuncia_aleatoria()
	oficina.temporizador_denuncias.stop()
	oficina.temporizador_eventos.stop()
	oficina.temporizador_bloqueos.stop()
	oficina.computador.timer_nuevo_problema.stop()
	oficina.sistema_despacho.set_process(false)
	oficina.jugador.set_physics_process(false)
	var puerta: Node3D = oficina.get_node("PuertaRelevo")
	match escenario:
		"junto_puerta":
			oficina.jugador.global_position = puerta.to_global(Vector3(0.24, 0.0, 0.95))
		"umbral":
			oficina.jugador.global_position = puerta.to_global(Vector3(0, 0, 0.32))
		"pasillo":
			oficina.jugador.global_position = oficina.grafo_piso.celda_a_posicion(Vector2i(6, 4)) + Vector3.UP * 0.374
		"reparando_apagon":
			_verificar(oficina.evento_apagon.iniciar_apagon(), "Se prepara el apagón real")
			oficina.evento_apagon._al_interactuar_taco(oficina.jugador)
			_verificar(oficina.evento_apagon.panel.visible, "El final ocurre reparando un circuito")
		"caida_terremoto", "aviso_terremoto":
			oficina._iniciar_terremoto()
			_verificar(oficina.evento_terremoto.activo, "Se prepara el terremoto real")
			if oficina.evento_terremoto.activo and escenario == "caida_terremoto":
				oficina.evento_terremoto._abrir_suelo()
				oficina.evento_terremoto.tiempo = 9.0
				oficina.jugador.global_position.y = puerta.global_position.y - 0.4
		"inundacion", "hielo", "incendio", "lava", "inundacion_puerta", "hielo_puerta":
			if escenario.ends_with("_puerta"):
				oficina.jugador.global_position = puerta.to_global(Vector3(0.24, 0.0, 0.95))
			_verificar(oficina.call("_iniciar_" + escenario.trim_suffix("_puerta")), "Se prepara " + escenario)
			for cuadro in 270:
				await physics_frame
	var cajas: int = oficina.bloqueos_visuales.size()
	if escenario == "hielo_puerta":
		oficina.jugador.velocity = Vector3(-0.35, 0, 0.1)
	var fatal := Denuncia.new()
	fatal.id = "final-" + escenario
	fatal.titulo = "Cierre durante " + escenario
	fatal.penalidad_calma = 10
	fatal.protocolo_estaciones = ["reporte"]
	oficina.sistema_despacho.recibir_denuncia(fatal)
	oficina.sistema_despacho.calma_operativa = 10
	oficina.sistema_despacho.vencer_denuncia(fatal.id)
	await process_frame
	var cine: Node3D = oficina.cinematica_relevo
	_verificar(oficina.partida_finalizada and paused and is_instance_valid(cine), escenario + ": relevo con el despacho detenido")
	_verificar(not oficina.final_partida._tarjeta.visible, escenario + ": la tarjeta espera a la escena")
	_verificar(oficina.bloqueos_visuales.size() == cajas, escenario + ": se conservan los obstáculos del momento")
	if escenario == "reparando_apagon":
		_verificar(not oficina.evento_apagon.panel.visible and oficina.evento_apagon.mascara.visible, "Se cierra el circuito y se conserva la oscuridad")
		var apagadas := true
		for luz: Light3D in oficina.evento_apagon.luces:
			apagadas = apagadas and not luz.visible
		_verificar(apagadas and oficina.evento_apagon.estado == 1, "El relevo no restaura la electricidad")
		_verificar(not oficina.evento_apagon.sonidos.ambiente.stream_paused, "El ambiente sonoro acompaña la emergencia")
	elif escenario == "caida_terremoto":
		_verificar(oficina.evento_terremoto.activo and not oficina.grafo_piso.grietas.is_empty(), "El relevo conserva el suelo fracturado")
	elif escenario.trim_suffix("_puerta") in ["inundacion", "hielo", "incendio", "lava"]:
		_verificar(oficina.get("evento_" + escenario.trim_suffix("_puerta")).activo, "La emergencia permanece activa: " + escenario)
	var separacion_minima := INF
	var nado := [false, false]
	var hielo := [false, false]
	var calor := [false, false]
	var peligro := false
	var temblor := false
	var cuadros := 0
	var captura := false
	for intento in 6600:
		await physics_frame
		cuadros += 1
		var actores := [oficina.jugador, cine.companero]
		if actores[0].visible:
			var diferencia: Vector3 = actores[0].global_position - actores[1].global_position
			separacion_minima = minf(separacion_minima, Vector2(diferencia.x, diferencia.z).length())
		for i in 2:
			nado[i] = nado[i] or (actores[i].nadando and actores[i].avance_nado > 0.1)
			hielo[i] = hielo[i] or (actores[i].congelado and is_zero_approx(actores[i].animation_player.speed_scale))
			calor[i] = calor[i] or actores[i].quemandose_pies
			if actores[i].visible and cuadros > 5:
				for grieta: Node in oficina.evento_terremoto.grietas:
					var p: Vector3 = actores[i].global_position
					peligro = peligro or grieta.contiene_hueco(Vector2(p.x, p.z))
		temblor = temblor or cine.ambiente.temblor > 0.1
		if not captura and cine.burbuja.visible and cine.burbuja.modulate.a > 0.99 and OS.get_environment("CAPTURAR_RELEVO") == "1" and DisplayServer.get_name() != "headless":
			captura = true
			await RenderingServer.frame_post_draw
			var ruta := "user://relevo_%s.png" % escenario
			root.get_texture().get_image().save_png(ruta)
			print("CAPTURA: ", ProjectSettings.globalize_path(ruta))
		if oficina.final_partida._relevo_finalizado:
			break
	_verificar(separacion_minima >= cine.SEPARACION - 0.01, "%s: no se atraviesan en ningún cuadro (mínimo %.3f m)" % [escenario, separacion_minima])
	_verificar(oficina.final_partida._relevo_finalizado, escenario + ": ambos completan el relevo")
	if not oficina.final_partida._relevo_finalizado:
		print("DIAGNOSTICO ", escenario, " jugador=", oficina.jugador.global_position, " relevo=", cine.companero.global_position, " movimientos=", cine._movimientos)
	else:
		_verificar(cine.jugador_salio and cine.companero_llego and oficina.final_partida._saltar.is_visible_in_tree(), escenario + ": cierre y cuaderno después de ambos recorridos")
	match escenario.trim_suffix("_puerta"):
		"inundacion":
			_verificar(nado[0] and nado[1], "Los dos policías nadan durante su recorrido")
		"hielo":
			_verificar(hielo[0] and hielo[1], "La congelación afecta a ambos policías")
		"lava":
			_verificar(calor[0] and calor[1], "Ambos reaccionan al contacto con la lava")
		"caida_terremoto", "aviso_terremoto":
			_verificar(temblor and not peligro, "El terremoto sigue temblando y los actores evitan los huecos")
	_verificar(oficina.sistema_despacho.calma_operativa == 0 and oficina.sistema_despacho.terminada, escenario + ": el ambiente no reabre ni altera el resultado")


func _verificar(condicion: bool, detalle: String) -> void:
	if condicion:
		print("OK: ", detalle)
	else:
		fallos += 1
		push_error("FALLO: " + detalle)
