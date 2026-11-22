extends SceneTree
## --headless --fixed-fps 60 --script res://Pruebas/ZonaDescanso/prueba_transiciones_avatar.gd
## Sin headless, -- --capturas guarda antes, avance y final de los seis eventos.
var oficina: Node3D
var jugador
var errores := 0
var comprobaciones := 0
var finales := 0
var capturas := false

func _initialize() -> void:
	_probar.call_deferred()

func _probar() -> void:
	capturas = OS.get_cmdline_user_args().has("--capturas")
	if capturas:
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 800)
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	await _cuadros(90)
	root.get_node("MenuGlobal").cerrar_ayuda()
	paused = false
	jugador = oficina.jugador
	for nombre: StringName in [&"inundacion", &"lava", &"hielo", &"incendio", &"terremoto", &"apagon"]:
		oficina.tutoriales_vistos[nombre] = true
	for reloj: Timer in [oficina.temporizador_denuncias, oficina.temporizador_bloqueos, oficina.temporizador_eventos]:
		reloj.stop()
	oficina.anuncios.detener()
	if capturas:
		oficina.get_node("CanvasLayer").hide()
	for nombre: String in ["inundacion", "lava", "hielo", "incendio", "terremoto", "apagon"]:
		var seleccion := ""
		for argumento: String in OS.get_cmdline_user_args():
			if argumento.begins_with("--evento="):
				seleccion = argumento.trim_prefix("--evento=")
		if not seleccion.is_empty() and not nombre in seleccion.split(","):
			continue
		finales = 0
		var evento: Node = oficina.get("evento_" + nombre)
		var senal := "luz_restaurada" if nombre == "apagon" else "terminado"
		evento.connect(senal, _al_finalizar)
		jugador.global_position = Vector3(-1, .38, 8.5)
		jugador.velocity = Vector3.ZERO
		await _cuadros(5)
		_verificar(_iniciar(nombre), "Inicia " + nombre)
		# Preparar eventos maduros sin esperar diez segundos en cada captura.
		match nombre:
			"inundacion": evento.nivel = evento.NIVEL_MAXIMO
			"lava": evento._tiempo = 4.0
			"hielo": evento.tiempo = 3.0
			"incendio": evento.tiempo = 11.0
			"terremoto": evento.tiempo = 11.0
		await _cuadros(70 if nombre in ["incendio", "terremoto"] else 4)
		oficina.anuncios.detener()
		await _captura(nombre + "_00_antes")
		var nivel_inicial: float = evento.nivel if nombre == "inundacion" else 0.0
		evento.resolver_con_avatar(jugador.global_position)
		var frente: Node3D = evento._resolucion_avatar
		_verificar(evento.resolviendo_avatar and finales == 0, "No elimina el evento al recibir el impulso: " + nombre)
		await _cuadros(30)
		await _captura(nombre + "_01_frente")
		var tiempo: float = frente.tiempo
		evento.resolver_con_avatar(jugador.global_position)
		_verificar(evento._resolucion_avatar == frente and frente.tiempo == tiempo, "Repetir no reinicia la transición: " + nombre)
		paused = true
		await _cuadros(8)
		_verificar(frente.tiempo == tiempo, "La pausa congela la restauración: " + nombre)
		paused = false
		await _cuadros(40)
		_verificar(finales == 0 and evento.resolviendo_avatar, "Mantiene una fase intermedia visible: " + nombre)
		match nombre:
			"inundacion":
				_verificar(evento.nivel > evento.PISO and evento.nivel < nivel_inicial and evento.superficie.visible, "Desciende el agua real con los muebles todavía presentes")
			"incendio":
				var minimo := 1.0
				var maximo := 0.0
				for foco in evento.focos:
					minimo = minf(minimo, foco.apagado)
					maximo = maxf(maximo, foco.apagado)
				_verificar(maximo > minimo + .2 and minimo < 1.0, "Las mesas se apagan por cercanía al Avatar")
			"lava", "hielo":
				_verificar(evento.superficie.is_visible_in_tree() and evento._material.get_shader_parameter("avatar_tiempo") > 0.0, "Transforma la superficie antes de retirarla: " + nombre)
			"terremoto":
				_verificar(not evento.grietas.is_empty() and not evento.escombros.is_empty(), "Reconstruye losas y recoge escombros antes de limpiar")
			"apagon":
				var encendidas := 0
				for luz: Light3D in evento.luces:
					if is_instance_valid(luz) and luz.visible: encendidas += 1
				var apertura: float = evento.mascara.material.get_shader_parameter("apertura_avatar")
				_verificar(encendidas > 0 and apertura > 0 and apertura < 1, "Las luces vuelven mientras se abre la visión")
		await _captura(nombre + "_02_transformacion")
		await _cuadros(50)
		await _captura(nombre + "_03_retirada")
		if nombre == "terremoto":
			var ocultos := 0
			var paso_libre := true
			for escombro in evento.escombros:
				if escombro._restos.global_position.y + escombro.ALTURA < .372:
					ocultos += 1
					paso_libre = paso_libre and escombro.collision_layer == 0
			_verificar(ocultos > 0 and paso_libre, "Los escombros recogidos no dejan obstáculos invisibles")
		await _cuadros(48)
		_verificar(finales == 1 and not evento.resolviendo_avatar and not is_instance_valid(frente), "Termina una sola vez y retira el efecto: " + nombre)
		_verificar(not jugador.nadando and not jugador.hielo_activo and not jugador.lava_activa, "Restaura los estados del jugador: " + nombre)
		await _captura(nombre + "_04_despues")
		evento.disconnect(senal, _al_finalizar)
		for reloj: Timer in [oficina.temporizador_bloqueos, oficina.temporizador_eventos]:
			reloj.stop()
		# Una limpieza inmediata durante la transición cancela el callback antiguo.
		_verificar(_iniciar(nombre), "Puede iniciar otra vez: " + nombre)
		var energia_inicial: Array[float] = []
		if nombre == "lava":
			for luz in evento._luces_calor:
				energia_inicial.append(luz.light_energy)
		evento.resolver_con_avatar(jugador.global_position)
		await _cuadros(5)
		if nombre == "lava":
			var sin_destello := true
			for i in energia_inicial.size():
				sin_destello = sin_destello and evento._luces_calor[i].light_energy <= energia_inicial[i] + .0001
			_verificar(sin_destello, "Resolver lava recién iniciada no aumenta de golpe su iluminación")
		var cancelado: Node3D = evento._resolucion_avatar
		evento.resolver_con_avatar()
		await _cuadros(4)
		_verificar(not evento.resolviendo_avatar and not is_instance_valid(cancelado), "La limpieza inmediata cancela la transición: " + nombre)
		oficina.anuncios.detener()
		oficina.temporizador_eventos.stop()
	await _probar_red()
	oficina.queue_free()
	await _cuadros(8)
	print("[TRANSICIONES_AVATAR] %d comprobaciones, %d errores" % [comprobaciones, errores])
	quit(0 if errores == 0 else 1)

func _probar_red() -> void:
	var puente = load("res://Scripts/Red/partida_lan.gd").new()
	puente.oficina = oficina
	puente._evento_id = 7
	puente.jugadores[1] = jugador
	_iniciar("inundacion")
	var punto := Vector3(1, .38, 2)
	var datos := {"jugador": 1, "evento": 7, "origen": punto}
	puente.aplicar_evento("avatar", datos)
	var frente: Node3D = oficina.evento_inundacion._resolucion_avatar
	_verificar(frente.origen == punto, "LAN usa el origen confirmado del jugador que lanzó Avatar")
	puente.aplicar_evento("avatar", datos)
	_verificar(oficina.evento_inundacion._resolucion_avatar == frente, "LAN ignora una confirmación duplicada")
	oficina.evento_inundacion.resolver_con_avatar()
	puente.free()

func _iniciar(nombre: String) -> bool:
	jugador.input_locked = false
	jugador.cancelar_gesto()
	var evento: Node = oficina.get("evento_" + nombre)
	match nombre:
		"apagon": return evento.iniciar_apagon()
		"terremoto": return evento.iniciar(oficina.grafo_piso, jugador, oficina.bloqueos_visuales, Rect2())
		"incendio": return evento.iniciar(oficina.bloqueos_visuales)
	return evento.iniciar()

func _al_finalizar() -> void:
	finales += 1

func _captura(nombre: String) -> void:
	if not capturas:
		return
	await RenderingServer.frame_post_draw
	var ruta := "res://.godot/transiciones_avatar_qa"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ruta))
	root.get_texture().get_image().save_png(ruta.path_join(nombre + ".png"))
	print("CAPTURA: " + nombre)

func _cuadros(cantidad: int) -> void:
	for i in cantidad:
		await physics_frame
	await process_frame

func _verificar(condicion: bool, mensaje: String) -> void:
	comprobaciones += 1
	if condicion:
		print("OK: " + mensaje)
	else:
		errores += 1
		push_error("[TRANSICIONES_AVATAR] " + mensaje)
