extends Node
## Integración del efecto real con estaciones, cierre de caso, pausa y reconexión.

const PANEL := preload("res://UI/Despacho/PanelDespacho.tscn")
var errores: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	call_deferred("_probar")


func _probar() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color("173b50")
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var panel := PANEL.instantiate() as PanelDespacho
	add_child(panel)
	var sistema := SistemaDespacho.new()
	add_child(sistema)
	sistema.set_process(false)
	panel.configurar_sistema(sistema)
	await get_tree().process_frame
	var efecto: Control = panel.efecto_tarea
	_verificar(not efecto.visible and not efecto.is_processing() and not efecto.sonido.playing, "No celebra al iniciar")
	_verificar(efecto.mouse_filter == Control.MOUSE_FILTER_IGNORE and efecto.focus_mode == Control.FOCUS_NONE, "No captura controles del jugador")
	_verificar(is_equal_approx(efecto.sonido.stream.get_length(), 1.1), "Sonido original de 1,1 s importado")
	var denuncia := _recibir(sistema, "FX-1")
	sistema.iniciar_denuncia_prioritaria()
	_verificar(not sistema.interactuar_estacion("ajena") and not efecto.visible, "Una estación incorrecta no dispara el efecto")
	_verificar(sistema.interactuar_estacion("evidencias"), "La tarea se completa normalmente")
	_verificar(efecto.visible and efecto.is_processing() and efecto.sonido.playing, "Una tarea correcta inicia dibujo y sonido")
	_verificar(efecto.caso_id == denuncia.id and efecto.estacion == "Evidencias", "El aviso identifica la tarea completada")
	await get_tree().create_timer(0.12).timeout
	var tiempo: float = efecto.tiempo
	_verificar(not sistema.interactuar_estacion("evidencias") and efecto.tiempo == tiempo, "Repetir una tarea no reinicia animación ni sonido")
	get_tree().paused = true
	await get_tree().create_timer(0.12).timeout
	_verificar(efecto.tiempo == tiempo and efecto.sonido.stream_paused, "La pausa congela dibujo y sonido juntos")
	get_tree().paused = false
	await get_tree().create_timer(0.1).timeout
	_verificar(efecto.tiempo > tiempo and not efecto.sonido.stream_paused, "Reanudar continúa el efecto")
	await get_tree().create_timer(0.55).timeout
	get_tree().paused = true
	for dimensiones: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1920, 1080)]:
		get_window().size = dimensiones
		await get_tree().process_frame
		await get_tree().process_frame
		_verificar(efecto.size.is_equal_approx(panel.size), "El efecto acompaña el viewport %s" % dimensiones)
		await _capturar("check_%dx%d" % [dimensiones.x, dimensiones.y])
	get_tree().paused = false
	await get_tree().create_timer(0.8).timeout
	_verificar(not efecto.visible and not efecto.is_processing() and not efecto.sonido.playing, "Se retira y deja de procesar al terminar")
	_verificar(sistema.interactuar_estacion("reporte") and denuncia.estado == Denuncia.Estado.RESUELTA, "La última tarea sigue cerrando el caso")
	_verificar(efecto.visible and efecto.estacion == "Reporte" and efecto.sonido.playing, "La última tarea conserva su celebración tras cerrar el caso")
	panel.configurar_sistema(sistema)
	_verificar(efecto.visible, "Reconfigurar el mismo sistema no interrumpe la celebración")
	var nuevo := SistemaDespacho.new()
	add_child(nuevo)
	nuevo.set_process(false)
	panel.configurar_sistema(nuevo)
	_verificar(not efecto.visible and not efecto.sonido.playing, "Cambiar de partida cancela el efecto y el audio anteriores")
	_recibir(sistema, "FX-ANTIGUO")
	sistema.iniciar_denuncia_prioritaria()
	sistema.interactuar_estacion("evidencias")
	_verificar(not efecto.visible, "El despacho desconectado no puede reproducir efectos")
	var nueva := _recibir(nuevo, "FX-NUEVO")
	nuevo.iniciar_denuncia_prioritaria()
	nuevo.interactuar_estacion("evidencias")
	_verificar(efecto.visible and efecto.caso_id == nueva.id, "La partida nueva reproduce sus propias tareas")
	nuevo.vencer_denuncia(nueva.id)
	_verificar(not efecto.visible and not efecto.sonido.playing, "El vencimiento cancela la celebración del mismo caso")
	panel.configurar_sistema(null)
	panel.queue_free()
	sistema.queue_free()
	nuevo.queue_free()
	fondo.queue_free()
	await get_tree().process_frame
	# El mezclador de audio libera las voces detenidas en su siguiente bloque.
	await get_tree().create_timer(0.12).timeout
	print("PRUEBA EFECTO TAREA: %d errores" % errores)
	get_tree().quit(0 if errores == 0 else 1)


func _recibir(sistema: SistemaDespacho, id: String) -> Denuncia:
	var denuncia := Denuncia.new()
	denuncia.id = id
	denuncia.titulo = "Clasificar documentos"
	denuncia.protocolo_estaciones = ["evidencias", "reporte"]
	sistema.recibir_denuncia(denuncia)
	return denuncia


func _capturar(nombre: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--capturas" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var directorio := "res://.godot/efecto_tarea_qa"
	DirAccess.make_dir_recursive_absolute(directorio)
	get_viewport().get_texture().get_image().save_png(directorio.path_join(nombre + ".png"))


func _verificar(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("OK: " + mensaje)
	else:
		errores += 1
		push_error(mensaje)
