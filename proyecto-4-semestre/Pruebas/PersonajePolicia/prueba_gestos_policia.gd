extends SceneTree
## Godot --headless --fixed-fps 60 --path <proyecto> --script res://Pruebas/PersonajePolicia/prueba_gestos_policia.gd
## Añadir -- --capturas (sin --headless) para guardar cuatro poses en .godot/gestos_qa.

var errores: int = 0
var contactos: int = 0
var jugador
var oficina: Node3D


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1000, 760)
	oficina = (load("res://Mundo/Oficina.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(oficina)
	current_scene = oficina
	await _cuadros(4)
	root.get_node("MenuGlobal").call("cerrar_ayuda")
	paused = false
	(oficina.get("temporizador_denuncias") as Timer).stop()
	(oficina.get("temporizador_bloqueos") as Timer).stop()
	var computador = oficina.get("computador")
	computador.timer_nuevo_problema.stop()
	var sistema = oficina.get("sistema_despacho") as SistemaDespacho
	sistema.set_process(false)
	await _cuadros(45)
	jugador = oficina.get_node("Gameplay/Node3D")
	_verificar(jugador.is_on_floor() and jugador.gestos != null, "Controlador y gestos en la oficina real")
	if jugador.gestos == null:
		quit(1)
		return
	var caso = Denuncia.new()
	caso.id = "QA-GESTOS"
	caso.tiempo_limite_segundos = 300.0
	caso.protocolo_estaciones.assign(["reporte", "bienestar"])
	sistema.recibir_denuncia(caso)
	oficina.call("_entregar_papel", jugador)
	_verificar(jugador.realizando_gesto() and jugador.papel_en_mano == null, "Recibir espera el contacto antes de sujetar")
	var origen = jugador.global_position
	Input.action_press(&"policia_prueba_adelante")
	await _cuadros(12)
	_verificar(jugador.global_position.distance_to(origen) < 0.02, "El gesto bloquea el desplazamiento")
	Input.action_release(&"policia_prueba_adelante")
	await _cuadros(45)
	var papel = jugador.papel_en_mano
	_verificar(is_instance_valid(papel) and papel.portador == jugador, "La entrega real conecta el papel con su portador")
	if not is_instance_valid(papel):
		quit(1)
		return
	_verificar(papel.get_parent() == jugador.anclaje_papel(), "La hoja pertenece al anclaje de la mano")
	var local = papel.transform
	var mundial = papel.global_position
	await _cuadros(18)
	_verificar(papel.transform.is_equal_approx(local), "El papel no se desliza respecto a la mano")
	_verificar(papel.global_position.distance_to(mundial) > 0.001, "El papel acompaña el tambaleo real del esqueleto")
	await _capturar("01_sostener")
	_verificar(jugador.ejecutar_gesto(&"interactuar", _contactar), "Inicia la interacción")
	_verificar(not jugador.ejecutar_gesto(&"interactuar", _contactar), "Pulsaciones repetidas no duplican efectos")
	await _cuadros(8)
	var tiempo = jugador.gestos.tiempo
	paused = true
	await create_timer(0.15).timeout
	_verificar(is_equal_approx(jugador.gestos.tiempo, tiempo) and contactos == 0, "La pausa detiene el gesto y su efecto")
	paused = false
	await _cuadros(14)
	await _capturar("02_interactuar")
	await _cuadros(35)
	_verificar(contactos == 1 and not jugador.realizando_gesto(), "Un único efecto y retorno al movimiento")
	# Reparación real: no limpiar el atasco ni puntuar antes del contacto final.
	oficina.set("_reporte_atascado_id", caso.id)
	oficina.set("_reporte_herramienta_recogida", true)
	oficina.call("interactuar_estacion_con_papel", jugador, "reporte")
	await _cuadros(55)
	_verificar(jugador.gestos.gesto == &"reparar", "Reparar mantiene activo el gesto de mecánico")
	_verificar(str(oficina.get("_reporte_atascado_id")) == caso.id and not caso.estaciones_completadas.has("reporte"), "El atasco espera a que termine la reparación")
	await _capturar("03_reparar")
	await _cuadros(100)
	_verificar(str(oficina.get("_reporte_atascado_id")).is_empty() and caso.estaciones_completadas.has("reporte"), "Reparar resuelve el atasco y completa el reporte")
	# El lanzamiento debe salir de la hoja sostenida, conservando tamaño mundial.
	var escala = papel.global_basis.get_scale()
	jugador.ejecutar_gesto(&"lanzar", papel.lanzar)
	_verificar(papel.portador == jugador, "El papel permanece agarrado durante la preparación")
	await _cuadros(20)
	await _capturar("04_lanzar")
	await _cuadros(40)
	_verificar(papel.portador == null and jugador.papel_en_mano == null, "El lanzamiento libera la hoja")
	_verificar(papel.get_parent() == oficina and not papel.freeze and papel.collision_layer == 4, "La hoja lanzada recupera la física y puede recogerse")
	_verificar(papel.global_basis.get_scale().is_equal_approx(escala), "Soltar conserva el tamaño del papel")
	papel.freeze = true
	papel.global_position = jugador.global_position + jugador.visual.global_basis.z.normalized() * 0.25 + Vector3.UP * 0.03
	oficina.call("recoger_papel", jugador, papel)
	_verificar(papel.portador == null, "Recoger espera la llegada de la mano")
	await _cuadros(25)
	await _capturar("05_recoger")
	await _cuadros(55)
	_verificar(papel.portador == jugador and papel.get_parent() == jugador.anclaje_papel(), "Recoger devuelve el papel al anclaje")
	jugador.ejecutar_gesto(&"interactuar", _contactar)
	jugador.reset_to_spawn()
	await _cuadros(50)
	_verificar(contactos == 1 and not jugador.realizando_gesto(), "Reiniciar cancela el efecto pendiente y libera el control")
	# Un caso que vence durante una acción no debe completar otra denuncia.
	oficina.call("interactuar_estacion_con_papel", jugador, "bienestar")
	oficina.call("_on_caso_finalizado", caso)
	await _cuadros(55)
	_verificar(not caso.estaciones_completadas.has("bienestar") and jugador.papel_en_mano == null, "Una hoja retirada durante el gesto no puntúa ni deja referencias activas")
	print("GESTOS_POLICIA: %d errores" % errores)
	oficina.queue_free()
	await _cuadros(3)
	quit(0 if errores == 0 else 1)


func _contactar() -> void:
	contactos += 1


func _cuadros(cantidad: int) -> void:
	for i: int in range(cantidad):
		await physics_frame
		await process_frame


func _verificar(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("OK: " + mensaje)
	else:
		errores += 1
		push_error(mensaje)


func _capturar(nombre: String) -> void:
	if not OS.get_cmdline_user_args().has("--capturas"):
		return
	var camara = Camera3D.new()
	oficina.add_child(camara)
	var grafo = oficina.get("depurador_grafo") as Node3D
	grafo.hide()
	var hud = oficina.get_node("CanvasLayer") as CanvasLayer
	hud.hide()
	camara.fov = 32.0
	camara.global_position = jugador.global_position + jugador.visual.global_basis.orthonormalized() * Vector3(-1.45, 0.95, 1.8)
	camara.look_at(jugador.global_position + Vector3.UP * 0.42)
	camara.current = true
	await RenderingServer.frame_post_draw
	var directorio = "res://.godot/gestos_qa"
	DirAccess.make_dir_recursive_absolute(directorio)
	root.get_texture().get_image().save_png(directorio + "/" + nombre + ".png")
	hud.show()
	camara.queue_free()
