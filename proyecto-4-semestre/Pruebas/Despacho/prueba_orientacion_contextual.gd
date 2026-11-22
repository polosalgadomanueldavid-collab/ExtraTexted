extends SceneTree
## --script res://Pruebas/Despacho/prueba_orientacion_contextual.gd
## Añadir -- --capturas sin --headless para revisar la oficina real.

var oficina
var sistema
var errores := 0
var pruebas := 0
var capturas := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	capturas = OS.get_cmdline_user_args().has("--capturas")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 800)
	var menu = root.get_node("MenuGlobal")
	menu.omitir_tutorial_siguiente_partida = true
	menu.capa.hide()
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	while not oficina.oficina_preparada: await process_frame
	await _cuadros(5)
	oficina._turno_anunciado = true
	oficina.anuncios.hide()
	oficina.temporizador_denuncias.stop()
	oficina.temporizador_bloqueos.stop()
	oficina.temporizador_eventos.stop()
	sistema = oficina.sistema_despacho
	sistema.tiempo_detenido = true
	_verificar(oficina.respuestas_mesas.size() == 5, "Cada mesa real tiene un receptor físico")
	var caso = load("res://Casos/Despacho/denuncia_suplantacion.tres").duplicate(true)
	caso.id = "VISUAL-A"
	sistema.recibir_denuncia(caso)
	var otro = load("res://Casos/Despacho/denuncia_uso_excesivo.tres").duplicate(true)
	otro.id = "VISUAL-B"
	sistema.recibir_denuncia(otro)
	sistema.iniciar_denuncia_prioritaria()
	await _cuadros(3)
	var requisitos = oficina.panel_despacho.tarjetas[otro.id].find_child("RequisitosVisuales", true, false)
	_verificar(requisitos != null and requisitos.estaciones == otro.obtener_estaciones_requeridas(), "La cola muestra los símbolos propios de cada denuncia")
	_validar(caso)
	_verificar(oficina.respuestas_mesas.privacidad.pendiente and oficina.respuestas_mesas.reporte.pendiente, "Privacidad y reporte están disponibles desde el principio")
	_verificar(not oficina.respuestas_mesas.bienestar.pendiente, "Bienestar no invita a trabajar en suplantación")
	oficina.jugador.global_position = oficina.computador.global_position + Vector3(0, .1, 1.2)
	await _cuadros(18)
	oficina._entregar_papel(oficina.jugador)
	await _cuadros(70)
	_verificar(is_instance_valid(oficina.jugador.papel_en_mano), "El expediente sigue siendo el papel real del jugador")
	if capturas:
		for id in ["verificacion", "evidencias", "reporte"]:
			await _situar(id)
			await _captura("mesa_" + id)
			await _detalle(id)
	await _situar("privacidad")
	await _captura("01_pendientes")
	await _detalle("privacidad")
	var mesa = oficina.respuestas_mesas.privacidad
	mesa.actualizar(caso, true, true)
	_verificar(mesa.cercana, "Acercarse con el caso válido prepara el receptor")
	for respuesta in oficina.respuestas_mesas.values():
		var huella := Rect2(Vector2(respuesta.position.x - .15, respuesta.position.z - .10), Vector2(.30, .20))
		_verificar(Rect2(-.66, -.30, 1.32, .60).encloses(huella), "La planilla queda completamente dentro del tablero: " + respuesta.estacion_id)
		_verificar(respuesta._hoja.position.y < .01, "El papel queda apoyado, sin animación en el aire: " + respuesta.estacion_id)
	mesa.actualizar(caso, false, true)
	_verificar(not mesa.cercana and is_zero_approx(mesa._piloto.emission_energy_multiplier), "Un apagón desactiva la invitación sin borrar el protocolo")
	_verificar(caso.estaciones_completadas.is_empty(), "La señal visual no completa tareas")
	_verificar(not sistema.interactuar_estacion("bienestar"), "Una mesa ajena no avanza el caso")
	for id in ["privacidad", "reporte", "verificacion", "evidencias"]:
		_verificar(sistema.interactuar_estacion(id), "Acepta el orden libre: " + id)
		await _cuadros(2)
		_validar(caso)
		if id == "privacidad":
			await _cuadros(95)
			await _captura("02_sello_privacidad")
			var completadas = caso.estaciones_completadas.duplicate()
			_verificar(not sistema.interactuar_estacion(id) and caso.estaciones_completadas == completadas, "Repetir una tarea no altera los sellos")
	_verificar(caso.estado == Denuncia.Estado.RESUELTA, "El último requisito cierra la denuncia")
	_verificar(oficina.respuestas_mesas.evidencias._hoja.visible, "La confirmación física permanece después del cierre")
	await _cuadros(95)
	sistema.iniciar_denuncia_prioritaria()
	await _cuadros(3)
	_validar(otro)
	_verificar(not oficina.respuestas_mesas.privacidad.completada and not oficina.respuestas_mesas.privacidad.pendiente, "El nuevo caso no hereda los sellos del anterior")
	await _situar("bienestar")
	oficina._entregar_papel(oficina.jugador)
	await _cuadros(70)
	await _captura("03_otro_protocolo")
	await _detalle("bienestar")
	_verificar(sistema.interactuar_estacion("reporte"), "Uso excesivo también puede comenzar por reporte")
	await _cuadros(3)
	_validar(otro)
	sistema.vencer_denuncia(otro.id)
	await _cuadros(3)
	for respuesta in oficina.respuestas_mesas.values():
		_verificar(not respuesta.pendiente and not respuesta.completada, "Vencer limpia la señal del caso " + respuesta.estacion_id)
	# Un receptor animado no sigue moviéndose al pausar.
	var respuesta = oficina.respuestas_mesas.verificacion
	respuesta.actualizar(caso, true, false)
	paused = true
	var posicion: Vector3 = respuesta._hoja.position
	await _cuadros(10)
	_verificar(respuesta._hoja.position == posicion, "La respuesta física respeta la pausa")
	paused = false
	oficina.queue_free()
	await _cuadros(3)
	print("[ORIENTACION CONTEXTUAL] %d comprobaciones, %d errores" % [pruebas, errores])
	quit(1 if errores else 0)

func _validar(caso) -> void:
	for id in oficina.respuestas_mesas:
		var respuesta = oficina.respuestas_mesas[id]
		_verificar(respuesta.completada == caso.estaciones_completadas.has(id), "Sello vinculado al ID: " + id)
		_verificar(respuesta.pendiente == (caso.estado == Denuncia.Estado.EN_PROCESO and caso.obtener_estaciones_pendientes().has(id)), "Todas las pendientes simultáneas: " + id)

func _situar(id: String) -> void:
	var jugador = oficina.jugador
	var camara = oficina.get_node("Gameplay/Camera3D")
	jugador.set_physics_process(false)
	camara.set_physics_process(false)
	jugador.global_position = oficina.grafo_piso.celda_a_posicion(GrafoPiso.DESTINOS[id]) + Vector3.UP * .075
	var destino: Vector3 = oficina.respuestas_mesas[id].global_position
	jugador.visual.look_at(Vector3(destino.x, jugador.visual.global_position.y, destino.z), Vector3.UP, true)
	camara.global_position = jugador.global_position + camara.offset
	await _cuadros(18)

func _captura(nombre: String) -> void:
	if not capturas: return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/denuncias_visuales_qa")
	root.get_texture().get_image().save_png("res://.godot/denuncias_visuales_qa/" + nombre + ".png")

func _detalle(id: String) -> void:
	if not capturas: return
	var camara = oficina.get_node("Gameplay/Camera3D")
	var respuesta = oficina.respuestas_mesas[id]
	var detalle := Camera3D.new()
	detalle.near = .01
	detalle.fov = 55
	oficina.add_child(detalle)
	var hacia: Vector3 = oficina.jugador.global_position - respuesta.global_position
	hacia.y = 0.0
	detalle.global_position = respuesta.global_position + hacia.normalized() * .85 + Vector3.UP * .85
	detalle.look_at(respuesta.global_position)
	detalle.make_current()
	await _cuadros(3)
	await _captura("receptor_" + id)
	camara.make_current()
	detalle.queue_free()
	await _cuadros(3)

func _cuadros(n: int) -> void:
	for i in n: await physics_frame
	await process_frame

func _verificar(condicion: bool, mensaje: String) -> void:
	pruebas += 1
	if not condicion:
		errores += 1
		push_error("[ORIENTACION CONTEXTUAL] " + mensaje)
