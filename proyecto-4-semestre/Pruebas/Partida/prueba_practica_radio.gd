extends SceneTree
## --headless --fixed-fps 60 --script res://Pruebas/Partida/prueba_practica_radio.gd
## Sin headless: añadir -- --capturas para revisar las fases reales.
var oficina
var practica
var jugador
var maquina
var errores := 0
var pruebas := 0
var capturas := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	capturas = OS.get_cmdline_user_args().has("--capturas")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 800)
	var menu = root.get_node("MenuGlobal")
	var archivo_anterior = menu.archivo_practica
	menu.archivo_practica = "user://practica_qa_%d.cfg" % OS.get_process_id()
	menu.omitir_tutorial_siguiente_partida = true
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	_verificar(oficina.iniciar_practica(), "Puede iniciar la práctica real")
	await _cuadros(100)
	practica = oficina.practica
	jugador = oficina.jugador
	maquina = oficina.get_node("MaquinaExpendedora")
	var sistema = oficina.sistema_despacho
	_verificar(practica.activa and not paused and not jugador.input_locked, "La radio deja libre al jugador")
	_verificar(sistema.obtener_denuncias_ordenadas().size() == 1 and practica.caso.es_practica, "Una denuncia real está registrada en el despacho")
	var plazo = sistema.obtener_tiempo_restante(practica.CASO)
	sistema.actualizar_tiempos(500)
	_verificar(sistema.obtener_tiempo_restante(practica.CASO) == plazo, "La denuncia de práctica no vence")
	_verificar(sistema.perder_calma(100) == 0 and sistema.calma_operativa == 100, "La práctica protege la calma")
	_verificar(not oficina._puede_iniciar_evento() and oficina.temporizador_denuncias.is_stopped(), "Emergencias y casos aleatorios esperan")
	_verificar(not oficina.iniciar_practica(), "No duplica la introducción")
	var posicion = jugador.global_position
	_tecla(KEY_W, true)
	await _cuadros(25)
	_tecla(KEY_W, false)
	_verificar(jugador.global_position.distance_to(posicion) > .1, "W mueve al policía durante la radio")
	await _captura("01_recoger")
	# La entrega pasa por la misma animación de recibir y el mismo papel físico.
	jugador.global_position = Vector3(oficina.computador.global_position.x, .38, oficina.computador.global_position.z + 1.2)
	jugador.velocity = Vector3.ZERO
	await _cuadros(12)
	oficina.computador.interactuar(jugador)
	await _cuadros(90)
	_verificar(is_instance_valid(jugador.papel_en_mano) and practica.paso == practica.Paso.EVIDENCIAS, "Recibir la hoja real avanza la guía")
	if not is_instance_valid(jugador.papel_en_mano):
		quit(1)
		return
	var papel = jugador.papel_en_mano
	papel.lanzar()
	await _cuadros(12)
	practica._actualizar_mensaje(true)
	_verificar(practica.radio._mensaje.contains("hoja") and practica.radio.objetivo == papel, "Soltar la hoja redirige la ayuda a su recuperación")
	oficina.recoger_papel(jugador, papel)
	await _cuadros(90)
	_verificar(jugador.papel_en_mano == papel, "La hoja se recupera con el gesto habitual")
	_verificar(not sistema.interactuar_estacion("verificacion"), "Una estación ajena no completa la práctica")
	await _captura("02_evidencias")
	var mesa
	for estacion in oficina.find_children("*", "Estacion", true, false):
		if estacion.estacion_id == "evidencias": mesa = estacion
	jugador.global_position = Vector3(mesa.global_position.x - .9, .38, mesa.global_position.z)
	jugador.velocity = Vector3.ZERO
	await _cuadros(30)
	oficina.interactuar_estacion_con_papel(jugador, "evidencias", mesa)
	await _cuadros(90)
	var clasificador = oficina.clasificador_evidencias
	_verificar(clasificador.visible and clasificador.objetivos == [0], "Evidencias usa una referencia sencilla y fija")
	clasificador.seleccion = 0
	clasificador._archivar()
	_verificar(clasificador.error_restante > 0 and practica.paso == practica.Paso.EVIDENCIAS, "Equivocarse permite reintentar sin avanzar")
	await _captura("03_archivador")
	clasificador.seleccion = 1
	clasificador._archivar()
	await _cuadros(3)
	_verificar(practica.paso == practica.Paso.PREMIO and sistema.puntuacion.puntos == maquina.precios[0], "El caso real concede exactamente el precio del chocolate")
	_verificar(not practica.radio.visible and oficina.panel_despacho.efecto_tarea.visible and oficina.panel_despacho.efecto_tarea.modo_expediente, "Al completar aparece la entrega del resultado, sin radio ni avisos superpuestos")
	_verificar(sistema.puntuacion.puntos_ganados == 0 and oficina._resueltas.is_empty(), "La práctica no infla el récord ni las estadísticas del turno")
	_verificar(not is_instance_valid(oficina.papel_actual), "Resolver retira la hoja real")
	await _cuadros(26)
	await _captura("04_premio")
	paused = true
	var espera = practica._espera
	await _cuadros(12)
	_verificar(practica._espera == espera, "La pausa congela la radio y sus transiciones")
	paused = false
	await _cuadros(215)
	_verificar(practica.paso == practica.Paso.TIENDA, "Después de felicitar, indica la tienda")
	for i in 100:
		jugador.global_position = maquina.global_position + Vector3(1.6 - i * .01, .01, 0)
		jugador.velocity = Vector3.ZERO
		jugador.visual.rotation.y = -PI / 2.0
		if jugador.obtener_objetivo_interaccion() == maquina: break
	await _cuadros(8)
	_tecla(KEY_E, true)
	_tecla(KEY_E, false)
	await _cuadros(5)
	_verificar(maquina.panel.visible, "E abre la tienda desde el pasillo")
	_verificar(maquina.comprar(0), "Compra con el saldo ganado por el caso")
	await _cuadros(100)
	_verificar(maquina.producto_listo and maquina.recoger_producto(), "Recoge el producto físico de la bandeja")
	await _cuadros(5)
	_verificar(practica.paso == practica.Paso.USAR and sistema.puntuacion.puntos == 0, "La guía espera al consumo después de cobrar una sola vez")
	await _captura("05_tienda")
	maquina.cerrar()
	await _cuadros(5)
	_tecla(KEY_Z, true)
	_tecla(KEY_Z, false)
	await _cuadros(15)
	_verificar(practica.paso == practica.Paso.USAR, "El gesto de comer debe llegar al contacto")
	await _cuadros(80)
	_verificar(jugador.chocolate_restante > 0 and practica.paso == practica.Paso.FINAL, "Z activa el poder real y finaliza la lección")
	await _captura("06_final")
	await _cuadros(220)
	_verificar(not oficina.en_practica() and not sistema.en_practica and not oficina.temporizador_denuncias.is_stopped(), "El turno se reanuda al terminar")
	_verificar(menu.practica_vista(), "Recuerda la práctica completada en el perfil")
	await _cuadros(190)
	_verificar(oficina.contador_denuncias > 0 and oficina.bloqueos_iniciados, "El turno normal vuelve a generar casos y bloqueos")
	# Una oficina nueva para probar omisión con la hoja en medio del gesto.
	oficina.queue_free()
	await _cuadros(8)
	menu.omitir_tutorial_siguiente_partida = true
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	oficina.iniciar_practica()
	await _cuadros(90)
	practica = oficina.practica
	jugador = oficina.jugador
	oficina._entregar_papel(jugador)
	practica.omitir()
	await _cuadros(90)
	_verificar(not oficina.en_practica() and not is_instance_valid(oficina.papel_actual) and not is_instance_valid(jugador.papel_en_mano), "Omitir durante la entrega cancela caso, hoja y gesto pendientes")
	_verificar(not jugador.input_locked and oficina.sistema_despacho.calma_operativa == 100, "Omitir conserva controles y calma")
	# El acceso de Ayuda debe cambiar a una oficina nueva y seguir siendo jugable.
	menu.repetir_practica()
	for i in 3000:
		await process_frame
		if not root.get_node("CargaEscenas").activa and current_scene != oficina:
			break
	oficina = current_scene
	await _cuadros(90)
	_verificar(oficina != null and oficina.has_method("en_practica") and oficina.en_practica(), "Repetir desde Ayuda carga una oficina nueva con la práctica activa")
	_verificar(not paused and not menu.panel_ayuda.visible, "La entrada por carga no abre un tutorial estático sobre la práctica")
	if oficina != null and oficina.has_method("en_practica") and oficina.en_practica():
		oficina.practica.omitir()
		await _cuadros(4)
	menu.abrir_pausa()
	menu.abrir_tutorial()
	await _cuadros(4)
	_verificar(menu.panel_ayuda.boton_practica.is_visible_in_tree() and menu.panel_ayuda.controles_foco().has(menu.panel_ayuda.boton_practica), "Ayuda expone la práctica con navegación de teclado y mando")
	await _captura("07_ayuda")
	menu.cerrar_ayuda()
	menu.reanudar_juego()
	oficina.queue_free()
	await _cuadros(8)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(menu.archivo_practica))
	menu.archivo_practica = archivo_anterior
	print("[PRACTICA RADIO] %d comprobaciones, %d errores" % [pruebas, errores])
	quit(1 if errores else 0)

func _tecla(codigo: Key, pulsada: bool) -> void:
	var evento := InputEventKey.new()
	evento.physical_keycode = codigo
	evento.pressed = pulsada
	Input.parse_input_event(evento)

func _cuadros(cantidad: int) -> void:
	for i in cantidad:
		await physics_frame
	await process_frame

func _captura(nombre: String) -> void:
	if not capturas: return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/practica_radio_qa")
	root.get_texture().get_image().save_png("res://.godot/practica_radio_qa/" + nombre + ".png")

func _verificar(condicion: bool, mensaje: String) -> void:
	pruebas += 1
	if condicion: print("OK: " + mensaje)
	else:
		errores += 1
		push_error(mensaje)
