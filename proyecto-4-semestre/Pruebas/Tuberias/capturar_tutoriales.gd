extends SceneTree
## Capturas reproducibles de la oficina vigente. Ejecutar sin --headless, --fixed-fps 60.
## -- tuberias|inundacion|hielo|terremoto|general|apagon|incendio|lava
## Salida: .godot/tuberias_qa; revisar antes de copiar a UI/Menus/ArtePiloto.
var oficina: Node3D
var camara: Camera3D
var jugador: CharacterBody3D
var menu: Node
var carpeta := "res://.godot/tuberias_qa"
var modo := ""
var pies := 0.38

func _initialize() -> void:
	preparar.call_deferred()

func cuadros(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame

func encuadrar(punto: Vector3, distancia: Vector3) -> void:
	camara.global_position = punto + distancia
	camara.look_at(punto)
	camara.make_current()

func foto(nombre: String, punto: Vector3, distancia: Vector3, region := Rect2i()) -> void:
	encuadrar(punto, distancia)
	await cuadros(4)
	await guardar(nombre, region)

func guardar(nombre: String, region := Rect2i()) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(carpeta.path_join(nombre + "_completa.png"))
	if region.has_area():
		# Los ajustes del usuario pueden cambiar el tamaño de ventana al cargar.
		# El recorte se expresa en 1280×720 y acompaña la resolución renderizada.
		var proporcion := Vector2(img.get_size()) / Vector2(1280, 720)
		img = img.get_region(Rect2i(Vector2(region.position) * proporcion, Vector2(region.size) * proporcion))
	img.resize(960, 540, Image.INTERPOLATE_LANCZOS)
	var error := img.save_webp(carpeta.path_join(nombre + ".webp"), true, 0.92)
	print("FOTO ", nombre, " ", error)

func poner(posicion: Vector3, mirar: Vector3) -> void:
	jugador.global_position = posicion
	jugador.velocity = Vector3.ZERO
	var direccion := mirar - posicion
	jugador.visual.rotation.y = atan2(direccion.x, direccion.z)

func solo_hud(objetivo: CanvasItem = null) -> void:
	for hijo: Node in oficina.get_node("CanvasLayer").get_children():
		if hijo is CanvasItem:
			hijo.modulate.a = 1.0 if hijo == objetivo else 0.0
	oficina.get_node("CanvasLayer").show()

func preparar() -> void:
	modo = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "tuberias"
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(carpeta)
	menu = root.get_node("MenuGlobal")
	menu.omitir_tutorial_siguiente_partida = true
	change_scene_to_file("res://Mundo/Oficina.tscn")
	await scene_changed
	oficina = current_scene
	await cuadros(4)
	jugador = oficina.jugador
	for evento: StringName in [&"apagon", &"terremoto", &"incendio", &"inundacion", &"lava", &"hielo"]:
		oficina.tutoriales_vistos[evento] = true
	oficina.temporizador_denuncias.stop()
	oficina.temporizador_eventos.stop()
	oficina.temporizador_bloqueos.stop()
	oficina.computador.timer_nuevo_problema.stop()
	oficina.sistema_despacho.set_process(false)
	await cuadros(100)
	menu.cerrar_ayuda()
	menu.filtro_pantalla.hide()
	oficina.generador_aleatorio.seed = 1414
	oficina.evento_terremoto._azar.seed = 8762
	oficina.anuncios.detener()
	oficina.depurador_grafo.hide()
	solo_hud()
	pies = jugador.global_position.y
	oficina.get_node("Gameplay/Camera3D").set_physics_process(false)
	camara = Camera3D.new()
	camara.cull_mask = 524287
	camara.fov = 46
	oficina.add_child(camara)
	camara.make_current()
	print("POS jugador=", jugador.global_position, " pc=", oficina.computador.global_position, " taco=", oficina.evento_apagon.taco.global_position)
	match modo:
		"tuberias": await tuberias()
		"general": await general()
		"apagon": await apagon()
		"terremoto": await terremoto()
		"incendio": await incendio()
		"inundacion": await inundacion()
		"hielo": await hielo()
		"lava": await lava()
	print("CAPTURAS COMPLETAS ", modo)
	quit()

func recibir_caso() -> void:
	var caso := load("res://Casos/Despacho/denuncia_uso_excesivo.tres").duplicate(true) as Denuncia
	caso.id = "CAPTURA-TUTORIAL"
	oficina.sistema_despacho.recibir_denuncia(caso)
	oficina._entregar_papel(jugador)
	await cuadros(80)

func general() -> void:
	var pc: Node3D = oficina.computador
	var punto := pc.global_position
	oficina._recibir_denuncia_aleatoria()
	oficina._limpiar_bloqueos_temporales()
	oficina.temporizador_bloqueos.stop()
	solo_hud(oficina.indicador_denuncia_pc)
	poner(Vector3(punto.x, pies, punto.z + 0.95), punto)
	jugador.set_physics_process(false)
	await foto("tutorial_denuncia", punto + Vector3(0, 0.3, 0.3), Vector3(1.0, 2.4, 2.3))
	solo_hud()
	await recibir_caso()
	var estaciones := {}
	for estacion: Node in oficina.find_children("*", "Estacion", true, false):
		estaciones[estacion.estacion_id] = estacion
	for id: String in ["bienestar", "reporte"]:
		var estacion: Node3D = estaciones[id]
		var acceso: Vector3 = oficina.grafo_piso.celda_a_posicion(GrafoPiso.DESTINOS[id])
		acceso.y = pies
		poner(acceso, estacion.global_position)
		var centro := acceso.lerp(estacion.global_position, 0.4) + Vector3.UP * 0.65
		print("ESTACION ", id, " pos=", estacion.global_position, " acceso=", acceso)
		await foto("tutorial_estacion" if id == "bienestar" else "tutorial_protocolo", centro, Vector3(0.5, 2.4, 2.3))

func apagon() -> void:
	jugador.set_physics_process(false)
	var evento: Node = oficina.evento_apagon
	var taco: Node3D = evento.taco
	evento.camara = camara
	var p: Vector3 = taco.global_position
	poner(Vector3(p.x - 1.8, pies, p.z + 0.7), p)
	encuadrar(p + Vector3(-0.7, 0.4, 0.1), Vector3(-1.8, 2.8, 3.6))
	evento.iniciar_apagon()
	oficina.anuncios.detener()
	await cuadros(12)
	await guardar("apagon_rayo")
	poner(Vector3(p.x - 0.6, pies, p.z - 0.4), p)
	evento.indicador_luz.modulate.a = 0
	await foto("apagon_taco", p + Vector3(-0.25, 0.45, 0.0), Vector3(-2.2, 1.4, -1.4))

func terremoto() -> void:
	await recibir_caso()
	var evento: Node3D = oficina.evento_terremoto
	evento.iniciar(oficina.grafo_piso, jugador, oficina.bloqueos_visuales, Rect2())
	oficina.anuncios.detener()
	var grieta: Node3D = evento._trazado[0]
	var centro := Vector3(grieta.centro.x, 0.38, grieta.centro.y)
	var gigante: Vector2 = evento.grieta_gigante.centro
	camara.fov = 62
	await foto("sismo_aviso", Vector3(gigante.x, 0.38, gigante.y), Vector3(0.0, 3.1, 2.4))
	camara.fov = 54
	evento._abrir_suelo()
	jugador.set_physics_process(false)
	await cuadros(65)
	evento.set_physics_process(false)
	await foto("sismo_grieta", centro, Vector3(0.15, 3.2, 1.65))
	var papel: RigidBody3D = oficina.papel_actual
	papel.lanzar()
	papel.freeze = true
	papel.mostrar_indicador = false
	var borde: Vector2 = grieta.contorno[4]
	var afuera: Vector2 = (borde - grieta.centro).normalized()
	var lugar := borde + afuera * 0.18
	papel.global_basis = Basis.IDENTITY.rotated(Vector3.UP, 0.25)
	papel.global_position = Vector3(lugar.x, 0.402, lugar.y)
	await foto("sismo_hoja", papel.global_position, Vector3(afuera.x * 0.9, 1.25, afuera.y * 0.9))

func incendio() -> void:
	var evento: Node3D = oficina.evento_incendio
	evento.iniciar(oficina.bloqueos_visuales)
	oficina.anuncios.detener()
	await cuadros(25)
	var extintor: Node3D = evento.extintor
	await foto("fuego_extintor", extintor.global_position + Vector3.UP * 0.35, Vector3(-1.25, 0.9, 1.4))
	var foco: Node3D = evento.focos[0]
	evento._equipar()
	poner(foco.acceso.global_position + Vector3.UP * 0.02, foco.global_position)
	await cuadros(10)
	Input.action_press(jugador.interaction_action)
	evento.solicitar_apagado(foco, jugador)
	await cuadros(23)
	await foto("fuego_mesa", jugador.global_position.lerp(foco.global_position, 0.5) + Vector3.UP * 0.4, Vector3(1.2, 2.1, 1.7))
	Input.action_release(jugador.interaction_action)
	camara.fov = 65
	await foto("fuego_oficina", Vector3(-1.3, 0.7, 1.9), Vector3(0, 3.2, 3.0))

func inundacion() -> void:
	poner(Vector3(-1.3, pies, 8.3), Vector3(-1.3, pies, 6))
	var evento: Node = oficina.evento_inundacion
	evento.iniciar()
	oficina.anuncios.detener()
	await cuadros(255)
	Input.action_press(jugador.FORWARD)
	encuadrar(jugador.global_position + Vector3.UP * 0.35, Vector3(1.5, 1.7, 2.0))
	await cuadros(15)
	await guardar("agua_nado")
	Input.action_release(jugador.FORWARD)
	await foto("agua_tuberia", Vector3(2.12, 1.10, 9.35), Vector3(-2.2, 0.60, 0.15))
	solo_hud(evento.panel)
	evento.tuberias.establecer_abierto(true)
	evento.panel.abrir()
	await cuadros(24)
	await guardar("agua_red", Rect2i(130, 65, 1020, 574))

func hielo() -> void:
	poner(Vector3(-1.3, pies, 8.3), Vector3(-1.3, pies, 6))
	var evento: Node = oficina.evento_hielo
	evento.iniciar()
	oficina.anuncios.detener()
	await cuadros(255)
	evento.set_physics_process(false)
	await foto("hielo_cristal", jugador.global_position + Vector3.UP * 0.47, Vector3(1.5, 1.7, 2.0))
	await foto("hielo_tuberia", Vector3(2.12, 1.10, 9.45), Vector3(-2.2, 0.60, -0.15))
	solo_hud(evento.panel)
	evento.panel.abrir()
	await cuadros(8)
	await guardar("hielo_tuercas", Rect2i(120, 60, 1040, 585))

func lava() -> void:
	oficina._cambiar_bloqueo_temporal()
	await cuadros(40)
	var evento: Node = oficina.evento_lava
	evento.iniciar()
	oficina.anuncios.detener()
	oficina.temporizador_bloqueos.stop()
	await cuadros(196)
	var charco: Vector3 = evento.charcos[0]
	await foto("lava_suelo", Vector3(charco.x, 0.38, charco.y), Vector3(0.0, 3.6, 2.0))
	var cajon: Node3D = oficina.bloqueos_visuales.values()[0]
	poner(cajon.global_position + Vector3.UP * 0.92, Vector3.ZERO)
	await cuadros(8)
	await foto("lava_cajon", jugador.global_position + Vector3.UP * 0.12, Vector3(-0.7, 2.2, 2.6))
	solo_hud(evento.panel)
	# El cronómetro se muestra con su arte actual, ampliado para leerlo en la guía.
	evento.panel.scale = Vector2.ONE * 2.2
	evento.panel.position = Vector2(460, 130)
	await foto("lava_reloj", jugador.global_position + Vector3.UP * 0.1, Vector3(-0.7, 2.2, 2.6))

func tuberias() -> void:
	jugador.hide()
	jugador.set_physics_process(false)
	var agua = oficina.evento_inundacion
	var hielo = oficina.evento_hielo
	var punto := Vector3(2.12, 1.10, 9.35)
	await foto("pared_sana", punto, Vector3(-2.2, 0.55, 0.15))
	await foto("pared_lateral", Vector3(2.22, 1.05, 9.65), Vector3(-0.65, 0.7, 1.8))
	jugador.show()
	for tipo: String in ["agua", "nitrogeno"]:
		var tubo: Node3D = agua.tuberias if tipo == "agua" else hielo.tuberia
		poner(Vector3(1.25, pies, tubo.global_position.z), tubo.global_position)
		for paso in 45:
			await cuadros(1)
			jugador.move_and_collide(Vector3(0.025, 0, 0))
		await foto("colision_" + tipo, Vector3(2.0, 1.0, 9.65), Vector3(-1.2, 1.2, 2.2))
	jugador.hide()
	agua.tuberias.establecer_abierto(true)
	await cuadros(24)
	await foto("puerta_abierta", punto, Vector3(-2.2, 0.55, 0.15))
	agua.tuberias.establecer_abierto(false)
	await cuadros(24)
	await foto("puerta_cerrada", punto, Vector3(-2.2, 0.55, 0.15))
	agua.tuberias.romper()
	agua.tuberias.establecer_abierto(true)
	await cuadros(16)
	await foto("agua_rotura", punto, Vector3(-2.2, 0.55, 0.15))
	await cuadros(42)
	await foto("agua_rota", agua.tuberias.global_position + Vector3(-0.3, 0, 0), Vector3(-1.9, 0.3, 0.3))
	agua.tuberias.sellar()
	await cuadros(100)
	hielo.tuberia.romper()
	await cuadros(54)
	await foto("nitrogeno_roto", hielo.tuberia.global_position + Vector3(-0.3, 0, 0), Vector3(-1.9, 0.3, -0.3))
	hielo.tuberia.sellar()
	await cuadros(100)
	await foto("pared_reparada", punto, Vector3(-2.2, 0.55, 0.15))
	jugador.show()
	poner(Vector3(-0.4, pies, 10.6), Vector3(2.3, pies, 9.5))
	var camara_juego: Camera3D = oficina.get_node("Gameplay/Camera3D")
	camara_juego.make_current()
	camara_juego.set_physics_process(true)
	for hijo: Node in oficina.get_node("CanvasLayer").get_children():
		if hijo is CanvasItem:
			hijo.modulate.a = 1.0
	await cuadros(120)
	await guardar("vista_jugable")
