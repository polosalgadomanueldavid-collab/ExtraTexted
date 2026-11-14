extends Node
## Prueba aislada del manual y su encuadre; --capturas guarda las tres páginas.

var errores := 0

func _ready() -> void:
	call_deferred("_probar")

func _probar() -> void:
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://UI/Menus/MainMenu.tscn")
	await get_tree().scene_changed
	get_window().mode = Window.MODE_WINDOWED
	MenuGlobal.abrir_opciones()
	MenuGlobal.abrir_controles()
	var panel := MenuGlobal.panel_ayuda
	for dimensiones: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1024, 768), Vector2i(1920, 1080)]:
		get_window().size = dimensiones
		for indice: int in range(panel.leyenda.paginas.size()):
			panel.leyenda.pestanas[indice].grab_focus()
			for cuadro: int in range(8):
				await get_tree().process_frame
			var pantalla := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
			if not pantalla.encloses(panel.get_global_rect()):
				errores += 1
				push_error("Manual fuera de pantalla: %s / %d: %s" % [dimensiones, indice, panel.get_global_rect()])
			if DisplayServer.get_name() != "headless" and "--capturas" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				var carpeta := "res://.godot/manual_qa"
				DirAccess.make_dir_recursive_absolute(carpeta)
				get_viewport().get_texture().get_image().save_png(carpeta.path_join("manual_%dx%d_%d.png" % [dimensiones.x, dimensiones.y, indice]))
			print("MANUAL: %s / %s / %s" % [dimensiones, indice, panel.get_global_rect()])
	MenuGlobal.cerrar_ayuda()
	if not MenuGlobal.panel_opciones.visible:
		errores += 1
	MenuGlobal.abrir_controles()
	if panel.leyenda.pagina_actual != 0:
		errores += 1
	MenuGlobal.cerrar_ayuda()
	MenuGlobal.cerrar_opciones()
	MenuGlobal.abrir_tutorial()
	if not panel.tutorial.visible or panel.leyenda.visible:
		errores += 1
	print("PRUEBA MANUAL: %d errores" % errores)
	get_tree().quit(0 if errores == 0 else 1)
