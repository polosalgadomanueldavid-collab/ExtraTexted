extends SceneTree
## Colisión real durante el sellado parcial, pausa y limpieza final del Avatar.
var errores := 0
var comprobaciones := 0
var oficina: Node3D
var evento: Node3D

func _initialize() -> void:
	_probar.call_deferred()

func _probar() -> void:
	root.get_node("MenuGlobal").omitir_tutorial_siguiente_partida = true
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	while not oficina.oficina_preparada: await process_frame
	root.get_node("MenuGlobal").cerrar_ayuda()
	for reloj in [oficina.temporizador_eventos, oficina.temporizador_denuncias, oficina.temporizador_bloqueos]: reloj.stop()
	if OS.get_cmdline_user_args().has("--capturas"):
		var camara := Camera3D.new()
		oficina.add_child(camara)
		camara.cull_mask = oficina.get_node("Gameplay/Camera3D").cull_mask
		camara.global_position = Vector3(-1, 16, 8)
		camara.look_at(Vector3(-1, .4, 6))
		camara.projection = Camera3D.PROJECTION_ORTHOGONAL
		camara.size = 14.5
		camara.make_current()
	oficina.tutoriales_vistos[&"terremoto"] = true
	evento = oficina.evento_terremoto
	evento._azar.seed = 8762
	_verificar(evento.iniciar(oficina.grafo_piso, oficina.jugador, oficina.bloqueos_visuales, Rect2()), "Se acepta el plan real")
	if evento.preparando: await evento.preparacion_terminada
	_verificar(evento.activo, "El plan se prepara")
	if not evento.activo:
		quit(1)
		return
	for grieta in evento._trazado:
		_verificar(is_instance_valid(grieta._tapa) and grieta._tapa.collision_layer == 0 and not grieta._tapa_visual.visible, "Cada tapa está preparada sin colisión ni dibujo durante el aviso")
	evento.set_physics_process(false)
	evento._abrir_suelo()
	for i in 65: await physics_frame
	var grieta = evento.grietas[0]
	var otra = evento.grietas[1]
	var centro_original: Vector2 = grieta.centro
	var suma_huecos := 0.0
	for boca in evento.grietas: suma_huecos += _area(boca.contorno_hueco)
	var caras: PackedVector3Array = evento._piso._roto.get_child(0).shape.get_faces()
	var area_firme := 0.0
	for i in range(0, caras.size(), 3): area_firme += (caras[i + 1] - caras[i]).cross(caras[i + 2] - caras[i]).length() * .5
	_verificar(absf(area_firme + suma_huecos - 7.0 * 12.5) < .001, "La triangulación cubre exactamente el piso menos las bocas, sin huecos extra ni solapamientos")
	_verificar(_pisar(grieta.centro).is_empty(), "La boca abierta no tiene una tapa invisible")
	await _capturar("abierto")
	_verificar(grieta.reconstruir_avatar(.84), "El frente sella la primera boca")
	for i in 3: await physics_frame
	var apoyo := _pisar(grieta.centro)
	_verificar(not apoyo.is_empty() and apoyo.collider == grieta._tapa and apoyo.normal.y > .99, "La tapa sostiene cuerpos con la normal hacia arriba")
	_verificar(not is_instance_valid(grieta._corte), "El sellado no modifica CSG ni recompone las otras grietas")
	_verificar(_pisar(otra.centro).is_empty() and not otra.sellada_avatar, "Otra boca continúa abierta física y visualmente")
	_verificar(not grieta.reconstruir_avatar(.90), "Sellar otra vez no repite la transición")
	_verificar(not grieta._losas[0].visible, "Las losas se retiran al mostrar la tapa para evitar superficies coplanares")
	await _capturar("parcial")
	evento.resolver_con_avatar(oficina.jugador.global_position)
	paused = true
	var fase: float = evento._resolucion_avatar.tiempo
	for i in 10: await process_frame
	_verificar(is_equal_approx(fase, evento._resolucion_avatar.tiempo), "La restauración respeta la pausa")
	paused = false
	for i in 420:
		if not evento.activo: break
		await physics_frame
	_verificar(not evento.activo and evento.grietas.is_empty() and evento.escombros.is_empty(), "El Avatar finaliza y retira tapas, cortes y escombros")
	for i in 5: await physics_frame
	_verificar(not _pisar(centro_original).is_empty(), "El piso final vuelve a sostener cuerpos")
	await _capturar("restaurado")
	oficina.queue_free()
	await process_frame
	print("[RESTAURACION SUELO] %d comprobaciones, %d errores" % [comprobaciones, errores])
	await preload("res://Pruebas/cierre_pruebas.gd").cerrar(self)
	quit(1 if errores else 0)

func _pisar(punto: Vector2) -> Dictionary:
	var origen := Vector3(punto.x, evento._altura + .04, punto.y)
	return oficina.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origen, origen + Vector3.DOWN * .7, 1))

func _area(contorno: PackedVector2Array) -> float:
	var suma := 0.0
	for i in contorno.size(): suma += contorno[i].cross(contorno[(i + 1) % contorno.size()])
	return absf(suma) * .5

func _capturar(nombre: String) -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().has("--capturas"): return
	oficina.anuncios.detener()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/qa_cierre_suelo_%s.png" % nombre)

func _verificar(ok: bool, texto: String) -> void:
	comprobaciones += 1
	if not ok:
		errores += 1
		push_error(texto)
