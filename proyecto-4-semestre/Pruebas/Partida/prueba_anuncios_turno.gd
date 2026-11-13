extends SceneTree
## --headless --fixed-fps 60 --script res://Pruebas/Partida/prueba_anuncios_turno.gd
## Añadir -- --capturas con renderizado para revisar los diseños en la oficina.

var oficina: Node3D
var fallos := 0


func _initialize() -> void:
	probar.call_deferred()


func probar() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var menu := root.get_node("MenuGlobal")
	menu.nombre_partida = ""
	change_scene_to_file("res://Mundo/Oficina.tscn")
	await scene_changed
	oficina = current_scene
	await _cuadros(5)
	_verificar(paused and menu.panel_ayuda.visible, "La entrada normal abre el tutorial")
	_verificar(not oficina.anuncios.visible and not oficina._turno_anunciado, "El sello espera al botón Empezar turno")
	menu.cerrar_ayuda()
	await _cuadros(3)
	oficina.temporizador_denuncias.stop()
	oficina.computador.timer_nuevo_problema.stop()
	var anuncio: Control = oficina.anuncios
	_verificar(anuncio.visible and anuncio.es_inicio and anuncio.titulo == "COMIENZO", "Empezar turno reproduce Sello de guardia")
	var instante: float = anuncio.tiempo
	menu.abrir_pausa()
	await _cuadros(12)
	_verificar(is_equal_approx(instante, anuncio.tiempo), "La pausa congela la animación")
	menu.reanudar_juego()
	await _cuadros(38)
	await _capturar("sello_guardia")
	await _cuadros(180)
	_verificar(not anuncio.visible, "El sello se retira solo")
	menu.abrir_tutorial()
	menu.cerrar_ayuda()
	menu.reanudar_juego()
	await _cuadros(3)
	_verificar(not anuncio.visible, "Reabrir el tutorial conserva el inicio ya mostrado")

	var despacho: SistemaDespacho = oficina.sistema_despacho
	despacho.set_process(false)
	var denuncia := Denuncia.new()
	denuncia.id = "aviso-primera"
	denuncia.titulo = "Denuncia de prueba"
	despacho.recibir_denuncia(denuncia)
	await _cuadros(38)
	var indicador: Control = oficina.indicador_denuncia_pc
	_verificar(indicador.visible and indicador.pendientes == ["aviso-primera"] and indicador.puede_recoger, "La denuncia nueva activa el sobre y la tecla")
	await _capturar("sobre_urgente")
	oficina.computador.interactuar(oficina.jugador)
	await _cuadros(65)
	_verificar(is_instance_valid(oficina.jugador.papel_en_mano), "La interacción del PC sigue entregando la hoja")
	_verificar(indicador.pendientes.is_empty() and not indicador.visible, "Recoger la denuncia retira el sobre")
	var segunda := Denuncia.new()
	segunda.id = "aviso-segunda"
	despacho.recibir_denuncia(segunda)
	await _cuadros(3)
	_verificar(indicador.pendientes == ["aviso-segunda"] and not indicador.puede_recoger, "La llegada durante otro caso muestra la espera")
	despacho.resolver_denuncia(denuncia.id)
	await _cuadros(3)
	_verificar(indicador.puede_recoger, "Al terminar el caso se habilita la siguiente denuncia")
	despacho.vencer_denuncia(segunda.id)
	await _cuadros(3)
	_verificar(not indicador.visible, "Vencer la última denuncia elimina el aviso")

	_verificar(oficina.evento_apagon.iniciar_apagon(), "Se inicia el primer apagón real")
	_verificar(paused and menu.panel_ayuda.visible and not anuncio.visible, "El primer apagón presenta el tutorial antes de los avisos de eventos")
	menu.cerrar_ayuda()
	oficina.evento_apagon._al_interactuar_taco(oficina.jugador)
	oficina.evento_apagon._al_resolver_circuito()
	_verificar(not paused and oficina.evento_apagon.estado == 0, "Cerrar el tutorial permite reparar el primer apagón")
	_verificar(oficina.evento_apagon.iniciar_apagon(), "Se inicia un segundo apagón real")
	_verificar(anuncio.visible and not anuncio.es_inicio and anuncio.titulo == "¡APAGÓN!", "El apagón reproduce Golpe de cómic")
	await _cuadros(40)
	await _capturar("comic_apagon")
	oficina.evento_apagon._al_interactuar_taco(oficina.jugador)
	oficina.evento_apagon._al_resolver_circuito()
	_verificar(anuncio.titulo == "LUZ" and anuncio.segunda_linea == "RESTABLECIDA", "La reparación anuncia la luz restaurada")
	oficina._recibir_denuncia_aleatoria()
	oficina.temporizador_denuncias.stop()
	oficina.temporizador_bloqueos.stop()
	oficina._iniciar_terremoto()
	_verificar(oficina.evento_terremoto.activo and anuncio.titulo == "¡TERREMOTO!", "El terremoto usa la entrada de cómic")
	await _cuadros(40)
	await _capturar("comic_terremoto")
	_verificar(not indicador.visible, "El aviso de evento evita superponerse con el sobre")
	await _cuadros(150)
	_verificar(indicador.visible, "El sobre pendiente vuelve al retirarse el anuncio")
	# Los dos renglones más largos deben caber a resolución reducida.
	root.size = Vector2i(800, 600)
	anuncio.mostrar_evento("IMPRESORA", "ATASCADA", "Busca la herramienta para repararla")
	await _cuadros(40)
	await _capturar("comic_impresora_800")
	oficina._al_terminar_partida()
	_verificar(not anuncio.visible and not indicador.visible, "El final retira los anuncios y el sobre")
	# Completa el relevo antes de liberar sus temporizadores y recursos.
	for intento: int in range(450):
		if oficina.final_partida._relevo_finalizado:
			break
		await create_timer(0.1, true, false, true).timeout
	_verificar(oficina.final_partida._relevo_finalizado, "El relevo termina sin depender de los anuncios de partida")
	paused = false
	oficina.queue_free()
	menu.musica_menu.stop()
	# El mezclador libera las voces en tiempo real aunque --fixed-fps acelere el juego.
	var limite_audio := Time.get_ticks_msec() + 500
	while Time.get_ticks_msec() < limite_audio:
		await process_frame
	print("[ANUNCIOS TURNO] %d fallos" % fallos)
	quit(0 if fallos == 0 else 1)


func _cuadros(cantidad: int) -> void:
	for i in range(cantidad):
		await process_frame


func _capturar(nombre: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--capturas" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var carpeta := "res://.godot/anuncios_qa"
	DirAccess.make_dir_recursive_absolute(carpeta)
	root.get_texture().get_image().save_png(carpeta.path_join(nombre + ".png"))


func _verificar(condicion: bool, detalle: String) -> void:
	if not condicion:
		fallos += 1
		push_error(detalle)
