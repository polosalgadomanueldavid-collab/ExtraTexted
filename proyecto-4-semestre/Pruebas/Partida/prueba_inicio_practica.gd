extends SceneTree
## Entrada directa desde el editor y partidas nuevas con un perfil ya utilizado.
var fallos := 0
var pruebas := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var menu = root.get_node("MenuGlobal")
	var carga = root.get_node("CargaEscenas")
	var original: String = menu.archivo_practica
	menu.archivo_practica = "user://inicio_practica_%d.cfg" % OS.get_process_id()
	menu._clasificacion = ClasificacionLocal.new("user://inicio_marca_%d.json" % OS.get_process_id())
	menu.guardar_practica_vista()
	menu.omitir_tutorial_siguiente_partida = false
	menu.practica_siguiente_partida = false
	change_scene_to_file(menu.ESCENA_JUEGO)
	await scene_changed
	for i in 120: await physics_frame
	var mundo = current_scene
	_verificar(mundo.en_practica() and not paused, "Abrir Oficina directamente inicia la práctica aunque el perfil la haya visto")
	_verificar(mundo.sistema_despacho.arbol.buscar_por_id("PRACTICA-001") != null, "La entrada directa muestra el caso real en el despacho")
	menu._abrir_tutorial_inicial()
	_verificar(mundo.sistema_despacho.obtener_denuncias_ordenadas().size() == 1, "Revisar la entrada no duplica el caso")
	mundo.practica.omitir()
	for i in 5: await process_frame
	menu.volver_al_menu()
	while carga.activa: await process_frame
	for i in 5: await process_frame
	for ronda in 2:
		menu.pedir_nombre_partida()
		menu._iniciar_partida("Agente QA")
		var limite := Time.get_ticks_msec() + 20000
		while Time.get_ticks_msec() < limite:
			await process_frame
			if not carga.activa and current_scene.scene_file_path == menu.ESCENA_JUEGO: break
		for i in 90: await physics_frame
		mundo = current_scene
		_verificar(mundo.has_method("en_practica") and mundo.en_practica() and not paused, "Una partida individual nueva ofrece la práctica, ronda %d" % ronda)
		if mundo.has_method("en_practica") and mundo.en_practica():
			mundo.practica.omitir()
		for i in 4: await process_frame
		menu.volver_al_menu()
		while carga.activa: await process_frame
		for i in 5: await process_frame
	DirAccess.remove_absolute(menu.archivo_practica)
	DirAccess.remove_absolute("user://inicio_marca_%d.json" % OS.get_process_id())
	menu.archivo_practica = original
	current_scene.queue_free()
	for i in 8: await process_frame
	print("[INICIO PRACTICA] %d comprobaciones, %d errores" % [pruebas, fallos])
	await preload("res://Pruebas/cierre_pruebas.gd").cerrar(self)
	quit(fallos)

func _verificar(condicion: bool, mensaje: String) -> void:
	pruebas += 1
	if condicion: print("OK: " + mensaje)
	else:
		fallos += 1
		push_error(mensaje)
