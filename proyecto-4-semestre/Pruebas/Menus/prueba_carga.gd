extends SceneTree

const ESCENA_CARGA := "res://UI/Menus/CargaInicial.tscn"
const ESCENA_MENU := "res://UI/Menus/MainMenu.tscn"
const ESCENA_JUEGO := "res://Mundo/Oficina.tscn"

var _fallos := 0


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	_verificar(change_scene_to_file(ESCENA_CARGA) == OK, "Abre la pantalla inicial")
	await scene_changed
	var pantalla_inicial := current_scene
	var fondo_inicial := pantalla_inicial.get_node("Fondo") as ColorRect
	_verificar(pantalla_inicial.get_child_count() == 1 and fondo_inicial.color == Color.BLACK, "El arranque es completamente negro y sin texto")
	if not await _esperar_escena(ESCENA_MENU):
		_terminar()
		return
	var menu := current_scene
	var entrada := menu.get_node("EntradaNegra") as ColorRect
	_verificar(entrada.visible and is_equal_approx(entrada.modulate.a, 1.0), "El menú empieza cubierto por negro")
	await create_timer(0.35).timeout
	_verificar(entrada.modulate.a > 0.0 and entrada.modulate.a < 1.0, "El menú aparece con un fundido gradual")
	await create_timer(0.8).timeout
	_verificar(not entrada.visible, "El fundido termina y libera el menú")
	var dialogo := menu.get_node("PantallaDiscusion/Dialogo") as Control
	_verificar(dialogo.anchor_right < 0.5, "Las frases de carga quedan a la izquierda")
	var menu_global := root.get_node("MenuGlobal")
	var panel := menu_global.get_node("%PanelClasificacion") as PanelContainer
	menu.get_node("%PlayButton").pressed.emit()
	_verificar(menu.get_node("PantallaDiscusion").visible, "Jugar muestra a los policías discutiendo")
	_verificar(panel.get_node("%Formulario").is_visible_in_tree(), "El formulario permite ingresar el nombre")
	(panel.get_node("%Volver") as Button).pressed.emit()
	_verificar(not menu.get_node("PantallaDiscusion").visible, "Cancelar restaura el menú")
	menu.get_node("%PlayButton").pressed.emit()
	var nombre := panel.get_node("%NombreJugador") as LineEdit
	nombre.text = "Prueba de carga"
	nombre.text_submitted.emit("Prueba de carga")
	_verificar(menu.get_node("PantallaDiscusion").visible and not menu_global.get_node("%CapaModal").visible, "La discusión permanece visible durante la carga")
	if "--capturas" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/carga_discusion_qa.png")
	if not await _esperar_escena(ESCENA_JUEGO):
		_terminar()
		return
	_verificar(menu_global.get("nombre_partida") == "Prueba de carga", "El nombre llega a la partida")
	_verificar(menu_global.get_node("%PanelAyuda").visible and paused, "El tutorial inicial se conserva")
	await create_timer(0.25).timeout
	_verificar((current_scene.get("_bloqueos_pool") as Array).size() == 30, "El pool termina de prepararse durante el tutorial en pausa")
	_terminar()


func _esperar_escena(ruta: String) -> bool:
	var inicio := Time.get_ticks_msec()
	while Time.get_ticks_msec() - inicio < 15000:
		await process_frame
		var escena := current_scene
		if is_instance_valid(escena) and escena.scene_file_path == ruta:
			return true
	_verificar(false, "Tiempo agotado al esperar %s" % ruta)
	return false


func _verificar(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("OK: ", mensaje)
	else:
		_fallos += 1
		push_error("FALLÓ: %s" % mensaje)


func _terminar() -> void:
	paused = false
	print("Resultado: %d fallo(s)" % _fallos)
	quit(0 if _fallos == 0 else 1)
