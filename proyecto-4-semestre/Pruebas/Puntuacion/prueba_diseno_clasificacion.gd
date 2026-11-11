extends SceneTree
## --headless --script res://Pruebas/Puntuacion/prueba_diseno_clasificacion.gd
## Con renderizado, añadir -- --capturas para revisar ambos diseños en .godot/clasificacion_qa.

var fallos := 0
var menu: Node
const VACIAS: Array[Dictionary] = []
const ENTRADAS: Array[Dictionary] = [
	{"nombre": "Andrés", "puntos": 1300},
	{"nombre": "Lina", "puntos": 1100},
	{"nombre": "Cristian", "puntos": 800},
	{"nombre": "DAM", "puntos": 500},
]


func _initialize() -> void:
	probar.call_deferred()


func probar() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	menu = root.get_node("MenuGlobal")
	change_scene_to_file("res://UI/Menus/MainMenu.tscn")
	await scene_changed
	await cuadros(12)
	menu.abrir_clasificacion()
	var panel: PanelContainer = menu.panel_clasificacion
	panel.presentar_tabla(ENTRADAS, OK, "Lina")
	await cuadros(5)
	verificar(panel.filas.get_child_count() == 4, "La carpeta muestra los registros")
	verificar(panel.marca.visible and panel.marca.get_node("Valor").text == "1100", "La ficha del menú muestra el mejor puntaje del alias")
	await capturar("01_menu_expediente")
	panel.presentar_tabla(VACIAS, OK)
	await cuadros(3)
	verificar(panel.estado.visible and not panel.tabla.visible, "El estado vacío conserva su mensaje")
	panel.presentar_tabla(VACIAS, ERR_FILE_CORRUPT)
	verificar(panel.estado.text.contains("No se pudo"), "El error de lectura sigue visible")
	var muchas: Array[Dictionary] = ENTRADAS.duplicate(true)
	for i in range(20):
		muchas.append({"nombre": "Jugador de prueba %02d" % i, "puntos": 400 - i})
	panel.presentar_tabla(muchas, OK)
	await cuadros(5)
	verificar(panel.lista.get_v_scroll_bar().max_value > panel.lista.size.y, "La lista larga conserva el desplazamiento")
	panel.presentar_nombre("Andrés")
	await cuadros(3)
	verificar(panel.formulario.visible and not panel._modo_tabla, "El formulario de nombre conserva su presentación")
	menu._cerrar_clasificacion()
	menu.nombre_partida = "Lina"
	change_scene_to_file("res://Mundo/Oficina.tscn")
	await scene_changed
	await cuadros(8)
	menu.cerrar_ayuda()
	var oficina := current_scene
	oficina.temporizador_denuncias.stop()
	oficina.temporizador_bloqueos.stop()
	oficina.sistema_despacho.set_process(false)
	oficina._turno_anunciado = true
	oficina.anuncios.detener()
	var calma: PanelCalmaJugadores = oficina.panel_despacho.calma_jugadores
	var primera := calma.filas[1]
	verificar(primera.nombre_jugador == "Lina", "La calma recibe el nombre de la partida")
	var retrato_original := primera._retrato.get_rect()
	var valor_original := primera._valor.get_rect()
	var tabla: Control = oficina.clasificacion_partida
	for resolucion: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1024, 768), Vector2i(1920, 1080)]:
		root.size = resolucion
		tabla.presentar(ENTRADAS, "Lina", 250)
		tabla.show()
		await cuadros(6)
		var y_solo: float = tabla.tarjeta.global_position.y
		calma.actualizar_jugador(2, 100, "Manuel")
		await cuadros(5)
		verificar(calma.filas[2].nombre_jugador == "Manuel", "El compañero conserva su propio nombre")
		verificar(tabla.tarjeta.global_position.y >= calma.filas[2].get_global_rect().end.y + 1, "La viñeta queda debajo de ambos jugadores a %s" % resolucion)
		verificar(is_equal_approx(y_solo, tabla.tarjeta.global_position.y), "La reserva de dos barras mantiene la posición")
		verificar(Rect2(Vector2.ZERO, Vector2(resolucion)).encloses(tabla.tarjeta.get_global_rect()), "La clasificación cabe en %s" % resolucion)
		if resolucion == Vector2i(1280, 720):
			await capturar("02_juego_comic_dos_jugadores")
		calma.quitar_jugador(2)
		await cuadros(3)
	calma.establecer_nombre(1, "Alejandra Fernanda Pérez")
	calma.actualizar_jugador(1, 85)
	verificar(primera.nombre_jugador == "Alejandra Fernanda Pérez", "Actualizar la calma conserva el alias")
	verificar(primera._nombre.get_rect().end.x <= primera._valor.position.x, "El nombre largo no invade la cifra de calma")
	verificar(primera._retrato.get_rect() == retrato_original and primera._valor.get_rect() == valor_original, "El nombre no cambia retrato ni posición de la calma")
	root.size = Vector2i(1280, 720)
	calma.establecer_nombre(1, "Andrés")
	tabla.presentar(ENTRADAS, "Andrés", 250)
	await cuadros(5)
	await capturar("03_juego_comic_un_jugador")
	var largos: Array[Dictionary] = ENTRADAS.duplicate(true)
	largos[0]["nombre"] = "Alejandra Fernanda Pérez"
	largos.append({"nombre": "Quinto jugador", "puntos": 100})
	tabla.presentar(largos, "Alejandra Fernanda Pérez", 250)
	await cuadros(5)
	verificar(tabla.filas.get_child_count() == 5, "Tab mantiene sus cinco puestos")
	await capturar("04_nombres_largos")
	tabla.presentar(VACIAS, "Andrés", 0)
	await cuadros(4)
	verificar(tabla.estado.visible and not tabla.tabla.visible, "Tab admite una clasificación vacía")
	await capturar("05_sin_records")
	paused = false
	current_scene.queue_free()
	await cuadros(3)
	print("DISEÑO CLASIFICACIÓN: %d fallo(s)" % fallos)
	quit(1 if fallos else 0)


func cuadros(cantidad: int) -> void:
	for i in range(cantidad):
		await process_frame


func capturar(nombre: String) -> void:
	if "--capturas" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/clasificacion_qa")
	root.get_texture().get_image().save_png("res://.godot/clasificacion_qa/%s.png" % nombre)


func verificar(condicion: bool, descripcion: String) -> void:
	if not condicion:
		fallos += 1
		push_error(descripcion)
