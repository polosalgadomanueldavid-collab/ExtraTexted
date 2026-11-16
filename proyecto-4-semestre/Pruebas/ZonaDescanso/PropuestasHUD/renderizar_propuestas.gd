extends SceneTree
## Propuestas de diseño: captura los modelos reales y monta tres HUD aislados.
var oficina: Node3D
var vistas: Array[SubViewport] = []
var carpeta := "res://.godot/propuestas_hud_objetos"

func _initialize() -> void:
	_ejecutar.call_deferred()

func _ejecutar() -> void:
	root.size = Vector2i(1280, 720)
	root.mode = Window.MODE_WINDOWED
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	await _cuadros(12)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.get_node("MenuGlobal").cerrar_ayuda()
	paused = false
	for reloj: Timer in [oficina.temporizador_denuncias, oficina.temporizador_bloqueos, oficina.temporizador_eventos]:
		reloj.stop()
	oficina.anuncios.detener()
	await _cuadros(50)
	oficina.anuncios.detener()
	# Pausar la oficina mantiene exactamente el mismo fondo en cada alternativa.
	oficina.process_mode = Node.PROCESS_MODE_DISABLED
	var capa := CanvasLayer.new()
	capa.layer = 60
	root.add_child(capa)
	var papel = load("res://UI/Despacho/indicador_papel.gd").new()
	capa.add_child(papel)
	papel.ajustar_pantalla(Vector2(1280, 720))
	papel.show()
	var propuesta = load("res://Pruebas/ZonaDescanso/PropuestasHUD/propuesta_objetos.gd").new()
	capa.add_child(propuesta)
	var fabrica = load("res://UI/Descanso/panel_expendedora.gd").new()
	for i in 4:
		var vista := SubViewport.new()
		vista.size = Vector2i(256, 256)
		vista.own_world_3d = true
		vista.transparent_bg = true
		vista.msaa_3d = Viewport.MSAA_4X
		vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vista)
		vistas.append(vista)
		var producto: Node3D = fabrica._crear_producto(i)
		vista.add_child(producto)
		producto.rotation_degrees = Vector3(-6, -15, -12 if i == 0 else 8)
		var camara := Camera3D.new()
		vista.add_child(camara)
		camara.projection = Camera3D.PROJECTION_ORTHOGONAL
		camara.size = .82
		camara.position = Vector3(0, .08, 2)
		camara.look_at(Vector3.ZERO)
		camara.current = true
		var entorno := WorldEnvironment.new()
		entorno.environment = Environment.new()
		entorno.environment.background_mode = Environment.BG_CLEAR_COLOR
		entorno.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		entorno.environment.ambient_light_color = Color("fff1d8")
		entorno.environment.ambient_light_energy = .65
		vista.add_child(entorno)
		var luz := DirectionalLight3D.new()
		luz.rotation_degrees = Vector3(-30, -30, 0)
		luz.light_energy = 1.4
		vista.add_child(luz)
	fabrica.free()
	await _cuadros(10)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta))
	for i in 4:
		await RenderingServer.frame_post_draw
		var imagen := vistas[i].get_texture().get_image()
		imagen.save_png(carpeta.path_join("producto_%d.png" % i))
		propuesta.iconos.append(ImageTexture.create_from_image(imagen))
	for opcion in 3:
		for activo: bool in [false, true]:
			propuesta.alternativa = opcion
			propuesta.activo = activo
			propuesta.queue_redraw()
			await _cuadros(3)
			await RenderingServer.frame_post_draw
			var archivo := "%s_%s.png" % [char(65 + opcion), "activo" if activo else "listo"]
			root.get_texture().get_image().save_png(carpeta.path_join(archivo))
			print("PROPUESTA: " + archivo)
	oficina.queue_free()
	capa.queue_free()
	for vista in vistas:
		vista.queue_free()
	await _cuadros(8)
	quit()

func _cuadros(cantidad: int) -> void:
	for i in cantidad:
		await process_frame
