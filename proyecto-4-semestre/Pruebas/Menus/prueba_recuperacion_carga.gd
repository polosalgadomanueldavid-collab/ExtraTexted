extends SceneTree
## Cancelación real en cada fase, errores recuperables y entradas repetidas.
const MENU := "res://UI/Menus/MainMenu.tscn"
const OFICINA := "res://Mundo/Oficina.tscn"
var carga: Node
var fallos := 0
var comprobaciones := 0
var terminadas: Array[String] = []
var errores: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func comprobar(valor: bool, texto: String) -> void:
	comprobaciones += 1
	if not valor:
		fallos += 1
	print("[RECUPERACION %s] %s" % ["OK" if valor else "FALLO", texto])

func esperar_fase(fase: String) -> bool:
	var limite := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < limite:
		if carga.activa and carga._fase == fase:
			return true
		await process_frame
	comprobar(false, "Tiempo agotado esperando fase " + fase)
	return false

func esperar_fin(ruta: String) -> bool:
	var limite := Time.get_ticks_msec() + 20000
	var anterior := 0.0
	var monotono := true
	while carga.activa and Time.get_ticks_msec() < limite:
		monotono = monotono and carga.progreso >= anterior
		anterior = carga.progreso
		await process_frame
	await process_frame
	var correcto: bool = not carga.activa and is_instance_valid(current_scene) and current_scene.scene_file_path == ruta
	comprobar(correcto and monotono, "Termina %s con progreso monótono" % ruta.get_file())
	return correcto

func _run() -> void:
	carga = root.get_node("CargaEscenas")
	carga.terminada.connect(func(ruta: String): terminadas.append(ruta))
	carga.fallo.connect(func(mensaje: String): errores.append(mensaje))
	var menu := root.get_node("MenuGlobal")
	carga.cargar(MENU)
	await esperar_fin(MENU)
	for fase in ["recursos", "pool", "entrada", "preparacion", "render", "listo"]:
		terminadas.clear()
		carga.cargar(OFICINA)
		var generacion: int = carga._generacion
		carga.cargar(OFICINA)
		comprobar(carga._generacion == generacion, "Doble solicitud conserva una sola carga")
		if not await esperar_fase(fase):
			break
		comprobar(paused, "Controles y relojes pausados en " + fase)
		carga.cancelar()
		await esperar_fin(MENU)
		comprobar(terminadas == [MENU] and not paused, "Cancelar en %s no completa la oficina anterior" % fase)
		comprobar(get_nodes_in_group("gestor_partida").is_empty(), "Se retira la oficina cancelada en " + fase)
	# Una ruta inexistente se rechaza antes de solicitarla al cargador del motor.
	for ruta in ["res://Pruebas/recurso_inexistente.tscn", "res://Casos/Despacho/denuncia_acoso_persistente.tres"]:
		var anteriores := errores.size()
		carga.cargar(ruta)
		var limite := Time.get_ticks_msec() + 10000
		while carga.activa and Time.get_ticks_msec() < limite:
			await process_frame
		comprobar(errores.size() == anteriores + 1 and carga.visible, "Error de recurso visible y recuperable")
		carga.cancelar()
		await esperar_fin(MENU)
	# Plazo monotónico, independiente del delta y de Engine.time_scale.
	carga.cargar(OFICINA)
	carga._limite = Time.get_ticks_msec()
	await process_frame
	await process_frame
	comprobar(not carga.activa and errores.size() == 3, "El plazo de carga vence con el árbol pausado")
	carga.cancelar()
	await esperar_fin(MENU)
	for ronda in 3:
		menu.omitir_tutorial_siguiente_partida = true
		carga.cargar(OFICINA)
		if not await esperar_fin(OFICINA):
			break
		comprobar(current_scene.oficina_preparada and current_scene._bloqueos_pool.size() == 30, "Reentrada %d: preparación completa y 30 cajones" % ronda)
		comprobar(not paused and carga.progreso == 100, "Solo se habilita el juego al completar la carga")
	carga.cargar(MENU)
	await esperar_fin(MENU)
	var limite := Time.get_ticks_msec() + 10000
	while not carga._precargas.is_empty() and Time.get_ticks_msec() < limite:
		await process_frame
	comprobar(carga._precargas.is_empty(), "Se recogen solicitudes descartadas sin bloquear")
	comprobar(get_nodes_in_group("gestor_partida").is_empty(), "No quedan oficinas tras volver al menú")
	menu.musica_menu.stop()
	await create_timer(0.3).timeout
	print("[RECUPERACION RESULTADO] %d comprobaciones, %d errores" % [comprobaciones, fallos])
	quit(0 if fallos == 0 else 1)
