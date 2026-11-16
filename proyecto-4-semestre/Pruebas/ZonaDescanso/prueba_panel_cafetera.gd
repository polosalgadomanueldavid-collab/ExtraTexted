extends "res://Pruebas/ZonaDescanso/prueba_interacciones_descanso.gd"
## Prueba el flujo real de E -> botón sobre el modelo -> taza, y cancelaciones.
## Añadir -- --capturas para revisar la composición sobre la oficina.

func _probar() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	await _cargar()
	_oficina.temporizador_eventos.stop()
	_oficina.anuncios.detener()
	_oficina.tutoriales_vistos[&"apagon"] = true
	_postura_cafe = _buscar_postura(_cafe)
	_verificar(not _postura_cafe.is_empty(), "Se alcanza la cafetera desde el juego")
	if _postura_cafe.is_empty():
		await _finalizar()
		return
	await _colocar(_postura_cafe)
	_saldo_y_calma(200, 60)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var modo_anterior := Input.mouse_mode # El servidor headless puede no capturar el ratón.
	await _tecla(KEY_E)
	var panel: Control = _zona.panel_cafetera
	_verificar(panel.visible and _jugador.input_locked, "E abre el objeto 3D y bloquea movimiento")
	_verificar(not _estado().preparando and _despacho.puntuacion.puntos == 200, "Abrir no prepara ni cobra")
	_verificar(panel.vista.transparent_bg and panel.vista.own_world_3d, "El objeto tiene transparencia y un mundo separado")
	_verificar(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "El cursor permite pulsar la máquina")
	var blanca: MeshInstance3D = _zona.get_node("RinconCafe/TazaBlanca")
	var amarilla: MeshInstance3D = _zona.get_node("RinconCafe/TazaAmarilla")
	_verificar(panel._taza_visual.mesh == blanca.mesh, "La vista usa la misma malla y textura de la taza blanca")
	_verificar(not panel.boton_retirar.visible and not panel.boton_taza.visible, "No permite retirar antes de preparar")
	var rotulos := ""
	for letrero in panel._modelo.find_children("*", "Label3D", true, false):
		rotulos += letrero.text
	_verificar(not "TURNO" in rotulos and not "CALMA" in rotulos and not "SALIR" in rotulos, "La cafetera conserva solo los rótulos de uso")
	await _captura("01_abierta")
	await _tecla(KEY_ESCAPE)
	_verificar(not panel.visible and not paused and not _jugador.input_locked, "Escape cierra sin abrir la pausa")
	_verificar(Input.mouse_mode == modo_anterior, "Cerrar restaura el cursor anterior")
	await _tecla(KEY_E)
	await _clic_boton(panel.boton_servir)
	_verificar(_estado().preparando, "Clic en el pulsador 3D comienza el servicio")
	await _segundos(0.6)
	await _captura("02_sirviendo")
	paused = true
	var progreso: float = _zona._tiempo_preparacion
	await create_timer(0.15).timeout
	_verificar(is_equal_approx(progreso, _zona._tiempo_preparacion), "Pausa congela preparación")
	paused = false
	await _tecla(KEY_ESCAPE)
	await _segundos(2.0)
	_verificar(not _estado().tiene_cafe and _despacho.puntuacion.puntos == 200, "Cancelar no entrega ni cobra después")
	await _tecla(KEY_E)
	await _clic_boton(panel.boton_servir)
	await _esperar_estado("cafe_listo", true, 3.0)
	_verificar(not _estado().tiene_cafe and _despacho.puntuacion.puntos == 200, "El café espera en la bandeja sin cobro")
	_verificar_liquido(panel, "blanca")
	await _captura("03_lista")
	await _clic_boton(panel.boton_taza)
	_verificar(_estado().tiene_cafe and not panel.visible and not _jugador.input_locked, "Recoger entrega la taza y cierra la vista")
	_verificar(_despacho.puntuacion.puntos == 150 and _despacho.calma_operativa == 60, "Recoger cobra una vez sin adelantar la calma")
	_verificar(_zona.taza_en_mano == blanca and blanca.get_parent() == _jugador.anclaje_taza(), "La taza blanca sale de la mesa y pasa a la mano")
	_zona._actualizar_aviso()
	_verificar(not _zona._aviso.visible, "El café en la mano usa solo el medallón, sin aviso azul")
	await _captura("03_blanca_en_mano")
	_zona.recoger_cafe()
	_verificar(_despacho.puntuacion.puntos == 150, "Una segunda recogida no cobra")
	await _tecla(KEY_F)
	await _esperar_estado("tiene_cafe", false, 4.0)
	await _esperar_estado("bebiendo", false, 3.0)
	_verificar(_despacho.calma_operativa == 75, "F bebe la taza real y recupera quince de calma")
	_verificar(blanca.get_parent() == _zona.get_node("RinconCafe"), "Al terminar vuelve la taza vacía a la mesa")
	await _colocar(_postura_cafe)
	await _tecla(KEY_E)
	_verificar(panel._taza_visual.mesh == amarilla.mesh, "La segunda preparación conserva la malla y textura amarillas")
	await _clic_boton(panel.boton_servir)
	await _segundos(0.6)
	await _captura("05_amarilla_sirviendo")
	await _esperar_estado("cafe_listo", true, 3.0)
	_verificar(panel.boton_retirar.visible and panel.boton_taza.visible, "RETIRA y taza permiten recoger el mismo café listo")
	_verificar_liquido(panel, "amarilla")
	await _captura("06_amarilla_lista")
	await _clic_boton(panel.boton_retirar)
	_verificar(_zona.taza_en_mano == amarilla and not panel.visible, "Clic en RETIRA entrega la taza amarilla y cierra")
	_verificar(amarilla.get_parent() == _jugador.anclaje_taza() and not _zona.has_node("RinconCafe/TazaAmarilla"), "La taza amarilla de la mano desaparece físicamente de la mesa")
	_verificar(_despacho.puntuacion.puntos == 100, "RETIRA cobra una sola compra")
	await _captura("07_amarilla_en_mano")
	await _tecla(KEY_F)
	await _esperar_estado("tiene_cafe", false, 4.0)
	await _esperar_estado("bebiendo", false, 3.0)
	_verificar(_despacho.calma_operativa == 90, "La taza amarilla recupera calma al beberla")
	_verificar(amarilla.get_parent() == _zona.get_node("RinconCafe"), "La amarilla regresa vacía a su mesa")
	_saldo_y_calma(150, 75)
	await _colocar(_postura_cafe)
	await _tecla(KEY_E)
	await _clic_boton(panel.boton_servir)
	await _esperar_estado("cafe_listo", true, 3.0)
	await _tecla(KEY_E)
	_verificar(not panel.visible and _despacho.puntuacion.puntos == 150, "E cierra una taza lista sin cobrar")
	await _tecla(KEY_E)
	await _clic_boton(panel.boton_servir)
	# El planificador evita iniciar apagones con input_locked; simula un corte externo.
	_jugador.input_locked = false
	_oficina.evento_apagon.iniciar_apagon()
	await _cuadros(3)
	_verificar(not panel.visible and not _estado().tiene_cafe and _despacho.puntuacion.puntos == 150, "Un apagón cancela sin entrega ni cobro")
	_oficina.evento_apagon.call("_al_interactuar_taco", _jugador)
	_oficina.evento_apagon.call("_al_resolver_circuito")
	await _cuadros(3)
	await _colocar(_postura_cafe)
	await _tecla(KEY_E)
	_verificar(panel.visible, "Reabre tras restaurar la luz")
	_jugador.reset_to_spawn()
	await _cuadros(3)
	_verificar(not panel.visible and not _jugador.input_locked, "Reinicio cierra y restaura el control")
	_saldo_y_calma(49, 60)
	await _colocar(_postura_cafe)
	await _tecla(KEY_E)
	_verificar(not panel.visible and _despacho.puntuacion.puntos == 49, "Saldo insuficiente no bloquea ni cobra")
	_saldo_y_calma(200, 60)
	await _tecla(KEY_E)
	for dimensiones: Vector2i in [Vector2i(960, 540), Vector2i(1024, 768)]:
		root.size = dimensiones
		await _cuadros(5)
		_verificar(panel.get_global_rect().encloses(panel.boton_servir.get_global_rect()), "Pulsador dentro de pantalla a %s" % dimensiones)
		await _captura("04_%dx%d" % [dimensiones.x, dimensiones.y])
	_zona._al_terminar_partida()
	_verificar(not panel.visible and not _estado().tiene_cafe, "Final de partida limpia la vista")
	await _finalizar()


func _clic_boton(boton: Button) -> void:
	await _cuadros(3)
	var centro := boton.get_global_rect().get_center()
	Input.warp_mouse(centro)
	await _cuadros(3)
	var mover := InputEventMouseMotion.new()
	mover.position = centro
	mover.global_position = centro
	Input.parse_input_event(mover)
	Input.flush_buffered_events()
	await _cuadros(2)
	for pulsado: bool in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.position = centro
		evento.global_position = centro
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.pressed = pulsado
		Input.parse_input_event(evento)
		Input.flush_buffered_events()
		await _cuadros(2)


func _captura(nombre: String) -> void:
	if not "--capturas" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	await _cuadros(4)
	await RenderingServer.frame_post_draw
	var carpeta := "res://.godot/cafetera_qa"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta))
	root.get_texture().get_image().save_png(carpeta.path_join(nombre + ".png"))

func _verificar_liquido(panel: Control, color: String) -> void:
	var taza: MeshInstance3D = _zona._tazas[_zona._siguiente_taza]
	var real: MeshInstance3D = taza.get_node("ContenidoCafe")
	var vista: MeshInstance3D = panel._cafe
	var independiente := vista.material_override != real.material_override
	for avance in [0.0, 0.5, 1.0]:
		panel.actualizar_progreso(avance)
		independiente = independiente and is_equal_approx(real.material_override.get_shader_parameter("llenado"), 1.0)
	_verificar(independiente, "Preparar la taza %s no altera el líquido de la taza real o de las copias remotas" % color)
	_verificar(vista.get_parent() == panel._taza_visual, "El líquido comparte la transformación de la taza %s" % color)
	panel.lista()