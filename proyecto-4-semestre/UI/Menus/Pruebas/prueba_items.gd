extends SceneTree
## --headless --script res://UI/Menus/Pruebas/prueba_items.gd
## Añadir -- --capturas sin headless para revisar la guía en varios tamaños.
var errores := 0
var comprobaciones := 0

func _initialize() -> void:
	_probar.call_deferred()

func _verificar(valor: bool, texto: String) -> void:
	comprobaciones += 1
	if not valor:
		errores += 1
		push_error(texto)

func _cuadros(cantidad: int = 8) -> void:
	for i in cantidad:
		await process_frame

func _probar() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var menus = root.get_node("MenuGlobal")
	var menu = load("res://UI/Menus/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await _cuadros()
	menus.abrir_tutorial()
	await _revisar_guia(menus, false)
	menus.cerrar_ayuda()
	_verificar(not menus.capa.visible and not paused, "Cerrar Ítems desde el menú conserva el control")
	current_scene = null
	menu.queue_free()
	await _cuadros()
	var oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	await _cuadros()
	menus.cerrar_ayuda()
	oficina.temporizador_eventos.stop()
	oficina.anuncios.detener()
	menus.abrir_pausa()
	menus.abrir_tutorial()
	var vistos: Dictionary = oficina.tutoriales_vistos.duplicate()
	await _revisar_guia(menus, true)
	_verificar(oficina.tutoriales_vistos == vistos, "Consultar Ítems no marca eventos como vistos")
	menus.cerrar_ayuda()
	_verificar(menus.panel_pausa.visible and paused, "Volver desde Ítems conserva la pausa")
	paused = false
	oficina.queue_free()
	await _cuadros()
	print("[GUIA ITEMS] %d comprobaciones, %d errores" % [comprobaciones, errores])
	quit(1 if errores else 0)

func _revisar_guia(menus: Node, desde_pausa: bool) -> void:
	var panel = menus.panel_ayuda
	var boton: Button = panel.fila_pestanas.get_node("Pestana_items")
	boton.grab_focus()
	boton.pressed.emit()
	await _cuadros()
	_verificar(panel.tutorial_actual == &"items" and panel.titulo.text == "ÍTEMS Y CAFÉ", "Ítems abre su página desde menú o pausa")
	_verificar(paused == desde_pausa, "La guía conserva el estado de pausa")
	var rejilla: GridContainer = panel.tutorial_evento.get_node("GuiaItems")
	_verificar(rejilla.get_child_count() == 6, "Se explican cuatro productos, café y compra")
	var textos := ""
	for etiqueta in rejilla.find_children("*", "Label", true, false):
		textos += etiqueta.text + " "
	for nombre in ["CHOCOLATE", "DONA", "PAPA TIEMPO", "EL AVATAR", "CAFÉ", "RETIRA"]:
		_verificar(nombre in textos, "La guía contiene " + nombre)
	for dimensiones in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1024, 768)]:
		root.size = dimensiones
		await _cuadros(12)
		_verificar(root.get_visible_rect().encloses(panel.get_global_rect()), "La guía cabe a %s" % dimensiones)
		for tarjeta in rejilla.get_children():
			_verificar(panel.get_global_rect().encloses(tarjeta.get_global_rect()), "Las fichas caben dentro de la guía")
		if "--capturas" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/items_%s_%dx%d.png" % ["pausa" if desde_pausa else "menu", dimensiones.x, dimensiones.y])
	panel.pestanas_tutorial[0].pressed.emit()
	_verificar(panel.tutorial.visible and not panel.tutorial_evento.visible, "Volver a General oculta las fichas")
	boton.pressed.emit()
	_verificar(panel.tutorial_evento.get_node("GuiaItems").get_child_count() == 6, "Reabrir Ítems no duplica las fichas")
