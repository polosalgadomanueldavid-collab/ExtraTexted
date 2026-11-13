extends SceneTree
## Comprueba las guías por evento, su consulta desde pausa y el indicador de luz.
## --headless --fixed-fps 60 --script res://Pruebas/prueba_integracion_eventos.gd

var oficina: Node3D
var errores := 0


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	# También en headless: el indicador se oculta si no cabe en el viewport mínimo.
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var menu := root.get_node("MenuGlobal")
	menu.omitir_tutorial_siguiente_partida = true
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	await _fisicas(12)
	menu.cerrar_ayuda()
	oficina.generador_aleatorio.seed = 1414
	oficina.evento_terremoto._azar.seed = 8762
	oficina._recibir_denuncia_aleatoria()
	oficina.temporizador_denuncias.stop()
	oficina.computador.timer_nuevo_problema.stop()
	oficina.sistema_despacho.set_process(false)
	var apagon: Node = oficina.evento_apagon
	var incendio: Node3D = oficina.evento_incendio
	var reloj: Timer = oficina.temporizador_eventos
	_verificar(oficina.tutoriales_vistos.is_empty(), "Una partida nueva tiene pendientes todas las guías")
	_verificar(apagon.iniciar_apagon(), "El primer apagón inicia con el coordinador compartido")
	_verificar(paused and menu.panel_ayuda.tutorial_apagon.is_visible_in_tree(), "El primer apagón abre el tutorial nuevo y pausa la partida")
	_verificar(menu.panel_ayuda.boton_cerrar.text == "ENTENDIDO" and not menu.fondo_modal.visible, "La guía conserva el diseño del compañero y deja ver la oficina")
	_verificar(reloj.is_stopped() and not oficina._iniciar_incendio(), "El tutorial no permite iniciar un incendio paralelo")
	var tiempo_bloqueos: float = oficina.temporizador_bloqueos.time_left
	var demostracion: Node = menu.panel_ayuda.tutorial_apagon.find_child("DemostracionCircuitos", true, false)
	var circuito_inicial: int = demostracion.tipo_actual
	await _fisicas(490)
	_verificar(is_equal_approx(tiempo_bloqueos, oficina.temporizador_bloqueos.time_left), "La guía congela los bloqueos y el tiempo de juego")
	_verificar(demostracion.tipo_actual != circuito_inicial, "La demostración de circuitos sigue animándose durante el tutorial")
	_verificar(apagon.sonidos.ambiente.stream_paused, "El audio restaurado del apagón respeta la pausa")
	menu.panel_ayuda.boton_cerrar.pressed.emit()
	await _fisicas(4)
	_verificar(not paused and not menu.capa.visible, "Entendido devuelve el control a la partida")
	_probar_consulta(menu, "APAGÓN")
	_verificar(apagon.indicador_luz.visible and apagon.indicador_luz.rotulo.text == "Activar Luz", "El rayo y su rótulo originales del compañero guían al taco")
	_verificar(apagon.sonidos.ambiente.playing and not apagon.sonidos.ambiente.stream_paused, "El apagón conserva su ambiente después de la guía")
	apagon._al_interactuar_taco(oficina.jugador)
	_verificar(apagon.estado == apagon.Estado.REPARANDO and not apagon.indicador_luz.visible, "Al reparar se abre el circuito y se oculta el rayo")
	apagon._al_resolver_circuito()
	_verificar(apagon.estado == apagon.Estado.RESTAURADO and not apagon.sonidos.ambiente.playing and reloj.time_left >= 40.0, "La reparación detiene el sonido y programa el próximo evento")
	_verificar(apagon.iniciar_apagon() and not paused and not menu.capa.visible, "El segundo apagón no repite la guía automática")
	apagon._al_interactuar_taco(oficina.jugador)
	apagon._al_resolver_circuito()
	_verificar(oficina._iniciar_incendio() and incendio.indicador_extintor.visible, "Después del apagón puede iniciarse el incendio con su marcador C")
	_verificar(not apagon.iniciar_apagon(), "Un incendio activo bloquea también el inicio directo del apagón")
	_verificar(incendio.panel.has_method("_dibujar_arco_mesa"), "La interfaz conserva el arco abierto de apagado por mesa")
	for evento: StringName in [&"incendio", &"terremoto", &"inundacion", &"hielo", &"lava"]:
		if evento != &"incendio":
			oficina.call("_iniciar_" + evento)
		var guia: Dictionary = menu.panel_ayuda.GuiasEventos.GUIAS[evento]
		var panel: Control = menu.panel_ayuda
		_verificar(paused and panel.tutorial_evento.is_visible_in_tree() and panel.titulo.text == guia.titulo, "Se abre la guía de " + evento)
		_verificar(panel.tutorial_evento.get_child_count() == 3 and panel.boton_cerrar.text == "ENTENDIDO", "Tres pasos y cierre en " + evento)
		var cajas: Dictionary = oficina.bloqueos_visuales.duplicate()
		var segundos: float = oficina.temporizador_bloqueos.time_left
		await _fisicas(12)
		_verificar(cajas == oficina.bloqueos_visuales and is_equal_approx(segundos, oficina.temporizador_bloqueos.time_left), "Las cajas y su reloj se conservan al leer " + evento)
		if DisplayServer.get_name() != "headless" and "--capturas" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/guia_%s.png" % evento)
		_pulsar_escape()
		_verificar(not paused and not menu.capa.visible, "Esc reanuda " + evento)
		_probar_consulta(menu, guia.nombre)
		_terminar(evento)
		oficina.call("_iniciar_" + evento)
		_verificar(oficina.evento_para_consultar() == evento and not paused and not menu.capa.visible, "La repetición de %s conserva el anuncio sin abrir la guía" % evento)
		_terminar(evento)
		await _fisicas(4)
	menu.abrir_pausa()
	menu.abrir_tutorial()
	_verificar(menu.panel_ayuda.tutorial.is_visible_in_tree(), "Sin evento, la pausa abre el tutorial del turno")
	menu.cerrar_ayuda()
	menu.reanudar_juego()
	await _fisicas(90)
	oficina.queue_free()
	await process_frame
	print("[INTEGRACION EVENTOS] %d errores" % errores)
	quit(1 if errores else 0)


func _probar_consulta(menu: Node, nombre: String) -> void:
	menu.abrir_pausa()
	menu.get_node("%TutorialPausa").pressed.emit()
	var panel: Control = menu.panel_ayuda
	_verificar(paused and panel.is_visible_in_tree() and panel.seccion.text.ends_with(nombre) and panel.boton_cerrar.text == "VOLVER", "La pausa permite consultar " + nombre)
	panel.boton_cerrar.pressed.emit()
	_verificar(paused and menu.panel_pausa.is_visible_in_tree() and menu.get_node("%TutorialPausa").has_focus(), "Volver regresa a pausa en " + nombre)
	menu.reanudar_juego()


func _terminar(evento: StringName) -> void:
	if evento == &"terremoto":
		oficina.evento_terremoto._abrir_suelo()
		oficina.evento_terremoto._cerrar()
	elif evento == &"incendio":
		for foco in oficina.evento_incendio.focos:
			foco.rociar(1.0, 1.0)
		oficina.evento_incendio._finalizar()
	else:
		oficina.get("evento_" + evento).detener()


func _pulsar_escape() -> void:
	var tecla := InputEventKey.new()
	tecla.keycode = KEY_ESCAPE
	tecla.physical_keycode = KEY_ESCAPE
	tecla.pressed = true
	root.push_input(tecla)
	tecla.pressed = false
	root.push_input(tecla)


func _fisicas(cantidad: int) -> void:
	for i in cantidad:
		await physics_frame
		await process_frame


func _verificar(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("[OK] " + mensaje)
	else:
		errores += 1
		push_error(mensaje)
