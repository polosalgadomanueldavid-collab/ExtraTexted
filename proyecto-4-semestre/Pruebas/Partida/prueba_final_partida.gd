extends SceneTree

var fallos: int = 0


func _initialize() -> void:
	probar.call_deferred()


func probar() -> void:
	var oficina: Variant = (load("res://Mundo/Oficina.tscn") as PackedScene).instantiate()
	root.add_child(oficina)
	current_scene = oficina
	var intentos := 0
	while oficina.final_partida == null and intentos < 20:
		await physics_frame
		intentos += 1
	_verificar(oficina.final_partida != null, "La oficina crea la secuencia final")
	if oficina.final_partida == null:
		quit(1)
		return
	await process_frame
	var menu_global: Variant = root.get_node_or_null("MenuGlobal")
	if menu_global != null and menu_global.panel_ayuda.visible:
		menu_global.cerrar_ayuda()

	var despacho: SistemaDespacho = oficina.sistema_despacho
	var resuelta := Denuncia.new()
	resuelta.id = "resuelta-prueba"
	resuelta.titulo = "Caso resuelto"
	resuelta.protocolo_estaciones = ["evidencias"]
	despacho.recibir_denuncia(resuelta)
	resuelta.estaciones_completadas = ["evidencias"]
	despacho.resolver_denuncia(resuelta.id)
	var vencida := Denuncia.new()
	vencida.id = "vencida-prueba"
	vencida.titulo = "Suplantación pendiente"
	vencida.protocolo_estaciones = ["evidencias", "reporte"]
	vencida.penalidad_calma = 10
	vencida.tiempo_limite_segundos = 1.0
	despacho.recibir_denuncia(vencida)
	vencida.estaciones_completadas = ["evidencias"]
	var abierta := Denuncia.new()
	abierta.id = "abierta-prueba"
	abierta.titulo = "Caso abierto"
	abierta.protocolo_estaciones = ["verificacion"]
	abierta.tiempo_limite_segundos = 100.0
	despacho.recibir_denuncia(abierta)
	despacho.calma_operativa = 10
	despacho.actualizar_tiempos(2.0)

	_verificar(oficina.partida_finalizada and despacho.terminada and paused, "El primer vencimiento fatal detiene la partida")
	_verificar(oficina.final_partida._fase == 1, "La denuncia causante aparece antes del cuaderno")
	_verificar(oficina.final_partida._titulo_caso.text == "Suplantación pendiente", "El cierre muestra el caso correcto")
	_verificar(oficina.final_partida._detalle.text.contains("Reporte"), "La denuncia enseña lo que faltaba")
	_verificar(oficina._resueltas.size() == 1 and oficina._vencidas.size() == 1, "El historial guarda resueltos y vencidos")
	_verificar(despacho.obtener_denuncias_ordenadas().size() == 1, "El caso abierto permanece para el cuaderno")
	var tardia := Denuncia.new()
	tardia.id = "tardia-prueba"
	_verificar(not despacho.recibir_denuncia(tardia) and not despacho.interactuar_estacion("verificacion"), "No se puede avanzar tras el final")
	await create_timer(2.5, true, false, true).timeout
	_verificar(oficina.final_partida._dialogo.text.contains("Yo me encargo"), "El compañero toma el relevo")
	if OS.get_environment("CAPTURAR_FINAL") == "1":
		await RenderingServer.frame_post_draw
		var ruta_relevo := ProjectSettings.globalize_path("user://prueba_relevo.png")
		get_root().get_texture().get_image().save_png(ruta_relevo)
		print("Captura relevo: ", ruta_relevo)
	await create_timer(3.9, true, false, true).timeout
	_verificar(oficina.final_partida._fase == 2 and oficina.final_partida._cuaderno.visible, "El cuaderno se abre al terminar el relevo")
	_verificar(oficina.final_partida._estadisticas.text.contains("RESUELTAS  1") and oficina.final_partida._estadisticas.text.contains("SIN CERRAR  1"), "Las estadísticas reflejan el turno")
	if OS.get_environment("CAPTURAR_FINAL") == "1":
		await RenderingServer.frame_post_draw
		var ruta := ProjectSettings.globalize_path("user://prueba_final_partida.png")
		get_root().get_texture().get_image().save_png(ruta)
		print("Captura: ", ruta)
	oficina._reiniciar_despues_del_final()
	for indice: int in range(20):
		if is_instance_valid(current_scene) and current_scene != oficina:
			break
		await process_frame
	_verificar(not paused and current_scene != oficina and is_instance_valid(current_scene), "Jugar de nuevo abre una partida limpia")
	var nueva_oficina: Variant = current_scene
	for indice: int in range(20):
		if nueva_oficina.final_partida != null:
			break
		await physics_frame
	await create_timer(0.3, true, false, true).timeout
	nueva_oficina._volver_al_menu_despues_del_final()
	for indice: int in range(20):
		if is_instance_valid(current_scene) and current_scene.scene_file_path == "res://UI/Menus/MainMenu.tscn":
			break
		await process_frame
	_verificar(is_instance_valid(current_scene) and current_scene.scene_file_path == "res://UI/Menus/MainMenu.tscn", "El cuaderno permite volver al menú")
	quit(1 if fallos > 0 else 0)


func _verificar(condicion: bool, descripcion: String) -> void:
	if condicion:
		print("OK: ", descripcion)
	else:
		fallos += 1
		push_error("FALLO: " + descripcion)
