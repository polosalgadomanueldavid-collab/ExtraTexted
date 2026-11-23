extends SceneTree
## --script res://Pruebas/Despacho/prueba_orientacion_contextual.gd
## Añadir -- --capturas sin --headless para revisar la oficina real.

var oficina
var sistema
var errores := 0
var pruebas := 0
var capturas := false
var originales: Dictionary = {}

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
	for estacion in oficina.find_children("*", "Estacion", true, false):
		var mesa = estacion.get_parent()
		for modelo in mesa.get_children():
			if not str(modelo.name).begins_with("Diseno_"): continue
			var piezas := []
			for pieza in modelo.find_children("*", "MeshInstance3D", true, false):
				piezas.append([pieza, pieza.mesh, pieza.material_override, pieza.transform, pieza.material_overlay])
			originales[estacion.estacion_id] = {"mesa":mesa.mesh, "modelo":modelo, "transformacion":modelo.transform, "piezas":piezas}
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
	_verificar(oficina.respuestas_mesas.size() == 5, "Cada diseño original tiene respuesta contextual")
	var grafitis = oficina.get_node("GrafitisEstaciones")
	_verificar(grafitis.pinturas.size() == 5, "Las cinco estaciones tienen pintura permanente")
	for id in grafitis.pinturas:
		var pintura: MeshInstance3D = grafitis.pinturas[id]
		var izquierda: bool = grafitis.IZQUIERDA.has(id)
		var normal := Vector3.RIGHT if izquierda else Vector3.LEFT
		_verificar(pintura.global_basis.z.dot(normal) > .99, "La pintura mira hacia el interior: " + id)
		_verificar(pintura.visible and not pintura.material_override.emission_enabled and pintura.find_children("*", "Label3D").is_empty(), "Grafiti sin texto, emisión ni dependencia del caso: " + id)
	await _capturar_grafitis()

	for id in oficina.respuestas_mesas:
		var respuesta = oficina.respuestas_mesas[id]
		var mesa = respuesta.get_parent().get_parent()
		var original: Dictionary = originales[id]
		_verificar(mesa.mesh == original.mesa, "No sustituye el tablero original: "+id)
		_verificar(respuesta.modelo_original == original.modelo and original.modelo.visible and original.modelo.transform == original.transformacion, "Conserva el diseño 3D visible y en su sitio: "+id)
		for datos: Array in original.piezas:
			_verificar(datos[0].mesh == datos[1] and datos[0].material_override == datos[2] and datos[0].transform == datos[3] and datos[0].material_overlay == datos[4], "Conserva todos los materiales originales, sin capa blanca: "+id)
		_verificar(oficina.indicadores_estaciones[id]._orientacion.visible, "Recupera el símbolo 3D descriptivo: "+id)
	await _cuadros(18)
	await _captura("00_inicio_sin_caso")
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
	_verificar(oficina.panel_despacho.denuncia_activa_titulo.visible and oficina.panel_despacho.denuncia_activa_titulo.text == caso.titulo, "El caso conserva su título junto a los símbolos")
	_verificar(oficina.panel_despacho.protocolo.custom_minimum_size.y == 50, "Los requisitos conservan la fila compacta del panel original")
	for id in oficina.indicadores_estaciones:
		var indicador = oficina.indicadores_estaciones[id]
		_verificar(indicador.visible == caso.obtener_estaciones_pendientes().has(id), "Los flotantes muestran todas las pendientes, sin imponer orden: "+id)
	_verificar(oficina.respuestas_mesas.privacidad.pendiente and oficina.respuestas_mesas.reporte.pendiente, "Privacidad y reporte están disponibles desde el principio")
	_verificar(not oficina.respuestas_mesas.bienestar.pendiente, "Bienestar no invita a trabajar en suplantación")
	oficina.jugador.global_position = oficina.computador.global_position + Vector3(0, .1, 1.2)
	oficina.jugador.velocity = Vector3.ZERO
	await _cuadros(70)
	_verificar(oficina.jugador.is_on_floor(), "El jugador está apoyado antes del gesto de recibir")
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
	oficina.set_process(false)
	mesa.actualizar(caso, true, true)
	await _cuadros(15)
	_verificar(mesa.cercana, "Acercarse con el caso válido prepara el receptor")
	for respuesta in oficina.respuestas_mesas.values():
		_verificar(respuesta.find_children("*", "MeshInstance3D", true, false).is_empty(), "La señal no añade aparatos ni piezas flotantes: "+respuesta.estacion_id)
		_verificar(respuesta.piezas_originales.size() > 0 and respuesta.luz_trabajo != null, "La mesa recibe luz real y conserva sus objetos: "+respuesta.estacion_id)
		for datos: Array in originales[respuesta.estacion_id].piezas:
			_verificar(datos[0].material_overlay == datos[4], "La mesa activa tampoco añade la capa blanca: "+respuesta.estacion_id)
	_verificar(mesa.intensidad > 0.45, "La zona útil se ilumina más al poder interactuar")
	mesa.actualizar(caso, false, true)
	await _cuadros(15)
	_verificar(not mesa.cercana and is_zero_approx(mesa.intensidad), "Un apagón desactiva la invitación sin borrar el protocolo")
	oficina.set_process(true)
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
	_verificar(oficina.panel_despacho.denuncia_activa_detalle.visible and oficina.panel_despacho.protocolo.completadas.size() == 4, "El expediente completo permanece mientras llega la última pieza")
	_verificar(oficina.panel_despacho.efecto_tarea.modo_expediente, "La confirmación muestra el resultado que viaja al expediente")
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
	var intensidad: float = respuesta.intensidad
	await _cuadros(10)
	_verificar(respuesta.intensidad == intensidad, "La respuesta sobre el modelo respeta la pausa")
	paused = false
	await _probar_tecla_real()
	oficina.queue_free()
	await _cuadros(3)
	print("[ORIENTACION CONTEXTUAL] %d comprobaciones, %d errores" % [pruebas, errores])
	quit(1 if errores else 0)

func _probar_tecla_real() -> void:
	# El flujo anterior aísla el estado visual; este usa el ShapeCast, los gestos y minijuegos.
	var caso := Denuncia.new()
	caso.id = "EXPEDIENTE-CON-E"
	caso.titulo = "Prueba de atención completa"
	caso.protocolo_estaciones.assign(["evidencias", "verificacion", "privacidad", "bienestar", "reporte"])
	sistema.recibir_denuncia(caso)
	var jugador = oficina.jugador
	jugador.global_position = oficina.computador.global_position + Vector3(0,.1,1.2)
	jugador.velocity = Vector3.ZERO
	jugador.set_physics_process(true)
	await _cuadros(70)
	oficina._entregar_papel(jugador)
	await _cuadros(65)
	_verificar(is_instance_valid(jugador.papel_en_mano), "La entrega animada deja el expediente en la mano")
	jugador.set_physics_process(false)
	var altura: float = jugador.global_position.y
	oficina.probabilidad_atasco_reporte = 0.0
	for id: String in ["reporte", "privacidad", "evidencias", "verificacion", "bienestar"]:
		var estacion = oficina.respuestas_mesas[id].get_parent()
		var aproximacion: Vector3 = oficina.grafo_piso.celda_a_posicion(GrafoPiso.DESTINOS[id])
		aproximacion.y = altura
		var encontrada := false
		for dx: float in [0.0, .4, -.4]:
			if encontrada: break
			var centro: Vector3 = estacion.to_global(Vector3(dx,0,0))
			centro.y = altura
			for i in 61:
				jugador.global_position = aproximacion.lerp(centro, i/60.0)
				jugador.visual.rotation.y = atan2(centro.x-aproximacion.x, centro.z-aproximacion.z)
				if jugador.obtener_objetivo_interaccion() == estacion:
					encontrada = true
					break
		_verificar(encontrada, "La tecla E alcanza la herramienta real: "+id)
		if not encontrada: continue
		oficina.get_node("Gameplay/Camera3D").global_position = jugador.global_position + oficina.get_node("Gameplay/Camera3D").offset
		await _cuadros(2)
		_verificar(oficina.guia_estacion.visible and oficina.guia_estacion.tecla.text in ["E","X"], "Solo la tecla acompaña a la herramienta: "+id)
		_tecla(KEY_E)
		await _cuadros(75)
		if id == "privacidad":
			await _captura("06_seguridad_procesando")
			await _cuadros(370)
			await _captura("07_seguridad_lista")
			_tecla(KEY_E)
			await _cuadros(65)
		elif id == "evidencias":
			var tarea = oficina.clasificador_evidencias
			_verificar(tarea.visible, "Evidencias abre el clasificador real")
			if tarea.visible:
				await _captura("08_evidencias_visual")
				while tarea.visible and tarea.archivados < tarea.objetivos.size():
					tarea.seleccion = tarea.papeles.find(tarea.objetivos[tarea.archivados])
					_tecla(KEY_E)
					await _cuadros(2)
		elif id == "verificacion":
			var tarea = oficina.escaner_verificacion
			_verificar(tarea.visible, "Verificación abre el escáner real")
			if tarea.visible:
				await _captura("09_escaner_visual")
				tarea.marcador = tarea.zona_centro
				_tecla(KEY_E)
				await _cuadros(2)
		_verificar(caso.estaciones_completadas.has(id), "La acción real incorpora su resultado: "+id)
		_verificar(not oficina.indicadores_estaciones[id].visible, "Completar retira solo el flotante de esa tarea: "+id)
		await _cuadros(48)
		if id == "reporte": await _captura("04_reporte_primero_real")
		if id == "verificacion": await _captura("05_expediente_reunido")
	_verificar(caso.estado == Denuncia.Estado.RESUELTA, "Las cinco herramientas resuelven mediante E en orden libre")
	await _cuadros(65)
	_verificar(not oficina.panel_despacho.denuncia_activa_detalle.visible, "La carpeta se retira después de recibir la última pieza")

func _tecla(codigo: Key) -> void:
	var evento := InputEventKey.new()
	evento.keycode = codigo
	evento.physical_keycode = codigo
	evento.pressed = true
	Input.parse_input_event(evento)
	var soltar := InputEventKey.new()
	soltar.keycode = codigo
	soltar.physical_keycode = codigo
	soltar.pressed = false
	Input.parse_input_event(soltar)

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
	var destino: Vector3 = oficina.respuestas_mesas[id].origen_resultado()
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
	var centro: Vector3 = respuesta.origen_resultado()
	detalle.global_position = centro + Vector3(0, .75, 1.0)
	detalle.look_at(centro)
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

func _capturar_grafitis() -> void:
	if not capturas: return
	var principal = oficina.get_node("Gameplay/Camera3D")
	var detalle := Camera3D.new()
	detalle.fov = 70
	oficina.add_child(detalle)
	oficina.get_node("CanvasLayer").hide()
	for lado in ["izquierda", "derecha"]:
		if lado == "izquierda":
			detalle.global_position = Vector3(-.2, 3.0, 4.0)
			detalle.look_at(Vector3(-4.38, 1.55, 3.7))
		else:
			detalle.global_position = Vector3(-2.5, 2.8, 5.0)
			detalle.look_at(Vector3(2.36, 1.55, 4.8))
		detalle.make_current()
		await _cuadros(3)
		await _captura("grafitis_" + lado)
	principal.make_current()
	detalle.queue_free()
	oficina.get_node("CanvasLayer").show()
