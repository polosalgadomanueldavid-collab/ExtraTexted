extends SceneTree
## Sin --headless: guarda vistas de tienda, silueta, ZA WARUDO y cuatro elementos.
var oficina: Node3D
var jugador
var maquina
var camara: Camera3D
var carpeta := "res://.godot/expendedora_qa"

func _initialize() -> void:
	_probar.call_deferred()

func _probar() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 800)
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	await _cuadros(10)
	root.get_node("MenuGlobal").cerrar_ayuda()
	paused = false
	jugador = oficina.jugador
	maquina = oficina.get_node("MaquinaExpendedora")
	for reloj: Timer in [oficina.temporizador_denuncias, oficina.temporizador_bloqueos, oficina.temporizador_eventos, oficina.computador.timer_nuevo_problema]:
		reloj.stop()
	oficina.anuncios.detener()
	await _cuadros(60)
	oficina.anuncios.detener()
	for i in 100:
		jugador.global_position = maquina.global_position + Vector3(1.6 - i * 0.01, 0.01, 0)
		jugador.visual.rotation.y = -PI / 2.0
		if jugador.obtener_objetivo_interaccion() == maquina:
			break
	await _cuadros(5)
	maquina.interactuar(jugador)
	await _cuadros(5)
	await _captura("01_tienda")
	maquina.cerrar()
	jugador.global_position = Vector3(-1.0, 0.38, 8.5)
	jugador.visual.rotation.y = 0.0
	camara = Camera3D.new()
	oficina.add_child(camara)
	camara.global_position = Vector3(0.7, 2.1, 11.4)
	camara.look_at(Vector3(-1.0, 0.95, 8.5))
	camara.current = true
	maquina.aviso.hide()
	maquina.set_process(false)
	oficina.get_node("CanvasLayer").hide()
	await _cuadros(30)
	await _captura("02_normal")
	jugador.dona_restante = 10.0
	await _cuadros(40)
	await _captura("03_dona")
	jugador.dona_restante = 0.0
	await _cuadros(40)
	jugador.ejecutar_gesto(&"za_warudo", maquina.poderes.detener_tiempo)
	await _cuadros(58)
	await _captura("04_pose_za_warudo")
	await _cuadros(15)
	await _captura("05_burbuja")
	await _cuadros(45)
	await _captura("06_tiempo_detenido")
	maquina.poderes.reanudar_tiempo()
	await _cuadros(40)
	camara.global_position = Vector3(.15, 1.45, 10.55)
	camara.look_at(Vector3(-1.0, .90, 8.5))
	var duelo := OS.get_cmdline_user_args().has("--aire-fuego")
	var secuencia := OS.get_cmdline_user_args().has("--secuencia")
	var gestos := [&"control_fuego", &"control_aire"] if duelo else [&"control_agua", &"control_fuego", &"control_tierra", &"control_aire"]
	if duelo:
		camara.fov = 42
	for gesto: StringName in gestos:
		jugador.ejecutar_gesto(gesto)
		maquina.poderes.animar_elemento(gesto)
		var fases := [.12, .18, .24, .32, .38, .46, .50, .56, .64, .72, .82, .95] if duelo else [.14, .24, .32, .46, .56, .72, .90]
		if secuencia:
			fases.clear()
			for i in 60:
				fases.append(float(i) / 60.0)
		var indice := 0
		for fase: float in fases:
			while jugador.gestos.tiempo / jugador.gestos.duracion < fase:
				await process_frame
			await _captura("%s_frame_%03d" % [gesto, indice] if secuencia else "%s_%02d" % [gesto, roundi(fase * 100)])
			indice += 1
		while jugador.realizando_gesto():
			await process_frame
		await _cuadros(30)
	oficina.queue_free()
	await _cuadros(8)
	quit()

func _captura(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta))
	root.get_texture().get_image().save_png(carpeta.path_join(nombre + ".png"))
	print("CAPTURA: " + nombre)

func _cuadros(cantidad: int) -> void:
	for i in cantidad:
		await process_frame
