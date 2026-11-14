extends SceneTree
## --headless --fixed-fps 60 --script res://Pruebas/ZonaDescanso/prueba_indicador_bolsillo.gd
## Sin --headless y con -- --capturas guarda el HUD real en .godot/bolsillo_qa.
var oficina: Node3D
var jugador
var maquina
var zona
var hud
var errores := 0
var comprobaciones := 0

func _initialize() -> void:
	_probar.call_deferred()

func _probar() -> void:
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	await _cuadros(12)
	root.get_node("MenuGlobal").cerrar_ayuda()
	paused = false
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	jugador = oficina.jugador
	maquina = oficina.get_node("MaquinaExpendedora")
	zona = oficina.get_node("ZonaDescanso")
	hud = oficina.indicador_bolsillo
	for reloj: Timer in [oficina.temporizador_denuncias, oficina.temporizador_bloqueos, oficina.temporizador_eventos, oficina.computador.timer_nuevo_problema]:
		reloj.stop()
	oficina.anuncios.detener()
	await _cuadros(60)
	oficina.anuncios.detener()
	_verificar(not hud.visible and hud.entradas.is_empty(), "Sin objetos ni café el bolsillo se oculta")
	_verificar(hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "El HUD no intercepta interacciones")
	maquina.inventario.assign([1, 1, 1, 1])
	await _cuadros(3)
	_verificar(hud.visible and hud.entradas.size() == 4, "Los cuatro objetos aparecen desde el inventario real")
	_verificar(_entrada(3).etiqueta == "SIN EVENTO", "Avatar indica que espera un evento")
	maquina._mensaje_restante = 0
	await _cuadros(3)
	_verificar(not maquina.aviso.visible, "El inventario no duplica el antiguo cartel de texto")
	_verificar(maquina.usar(0), "El medallón deja funcionar el chocolate")
	await _cuadros(2)
	_verificar(_entrada(0).estado == "usando", "La animación de consumo aparece como USANDO")
	await _cuadros(95)
	_verificar(_entrada(0).estado == "activo" and _entrada(0).cantidad == 0 and _entrada(0).progreso > .9, "El chocolate consumido permanece con su cuenta atrás")
	maquina.inventario[0] = 1
	await _cuadros(2)
	_verificar(_entrada(0).cantidad == 1 and _entrada(0).estado == "activo", "Una reserva nueva no oculta el efecto en curso")
	maquina.inventario[0] = 0
	# Café comprado, servido y recogido por los mismos métodos de la partida.
	var premio := Denuncia.new()
	premio.id = "HUD-CAFE"
	premio.estado = Denuncia.Estado.RESUELTA
	oficina.sistema_despacho.puntuacion.registrar_resolucion(premio)
	oficina.sistema_despacho.calma_operativa = 60
	var cafetera: Node3D = zona.get_node("RinconCafe/MuebleCafe")
	var encontrada := false
	for direccion: Vector3 in [Vector3.RIGHT, Vector3.BACK, Vector3.FORWARD, Vector3.LEFT]:
		for paso in 130:
			jugador.global_position = cafetera.global_position + direccion * (1.6 - paso * .01)
			jugador.global_position.y = .38
			jugador.visual.rotation.y = atan2(-direccion.x, -direccion.z)
			if jugador.obtener_objetivo_interaccion() == cafetera:
				encontrada = true
				break
		if encontrada:
			break
	_verificar(encontrada and zona.interactuar_cafetera(jugador), "El café se solicita desde la cafetera real")
	_verificar(zona.preparar_cafe(), "La preparación conserva su flujo habitual")
	await _cuadros(3)
	_verificar(not hud.visible, "La interfaz de la cafetera oculta los medallones")
	await _cuadros(115)
	_verificar(zona.recoger_cafe(), "El café se añade solo al recoger la taza")
	jugador.global_position = Vector3(-1.0, .38, 5.5)
	jugador.velocity = Vector3.ZERO
	await _cuadros(15)
	zona._mensaje_restante = 0
	maquina._mensaje_restante = 0
	await _cuadros(12)
	_verificar(hud.entradas.size() == 5 and _entrada(4).etiqueta == "F · BEBER", "Café ocupa el quinto medallón con F para beber")
	_verificar(not zona._aviso.visible, "El café no duplica el aviso permanente anterior")
	await _captura("01_cinco_medallones")
	for pantalla: Vector2 in [Vector2(960, 540), Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1080)]:
		hud.ajustar_pantalla(pantalla)
		var fin: Vector2 = hud.position + hud.size * hud.scale
		_verificar(hud.position.x >= 0 and hud.position.y >= 0 and fin.x < pantalla.x * .72 and fin.y < pantalla.y, "Cinco medallones caben en %s" % pantalla)
	paused = true
	var tiempo: float = jugador.chocolate_restante
	await _cuadros(10)
	_verificar(not hud.visible and jugador.chocolate_restante == tiempo, "Pausa oculta el HUD y conserva el tiempo real")
	paused = false
	await _cuadros(3)
	_verificar(hud.visible, "El HUD vuelve al reanudar")
	_tecla(KEY_F)
	await _cuadros(10)
	_verificar(_entrada(4).etiqueta == "BEBIENDO", "F funciona y muestra el sorbo en curso")
	await _cuadros(110)
	_verificar(_entrada(4).is_empty() and oficina.sistema_despacho.calma_operativa == 75, "Consumir café retira el medallón y concede la calma una vez")
	# Una hoja real conserva su espacio junto al bolsillo.
	var caso := Denuncia.new()
	caso.id = "HUD-HOJA"
	caso.protocolo_estaciones.assign(["bienestar"])
	oficina.sistema_despacho.recibir_denuncia(caso)
	oficina.sistema_despacho.iniciar_denuncia_prioritaria()
	oficina._entregar_papel(jugador)
	await _cuadros(60)
	_verificar(oficina.indicador_papel.visible and hud.position.x > oficina.indicador_papel.position.x + oficina.indicador_papel.size.x * oficina.indicador_papel.scale.x, "La hoja y los objetos no se superponen")
	await _captura("02_hoja_y_objetos")
	maquina.poderes.detener_tiempo()
	await _cuadros(4)
	_verificar(hud.can_process() and _entrada(2).estado == "activo", "El HUD sigue actualizando durante ZA WARUDO")
	maquina.poderes.reanudar_tiempo(false)
	jugador.chocolate_restante = 0
	await _cuadros(3)
	_verificar(_entrada(0).is_empty(), "Al caducar desaparece el objeto consumido")
	oficina.clasificacion_partida.show()
	await _cuadros(3)
	_verificar(not hud.visible, "Clasificación oculta el bolsillo")
	oficina.clasificacion_partida.hide()
	maquina.inventario.assign([0, 0, 0, 0])
	await _cuadros(3)
	_verificar(not hud.visible, "Vaciar el bolsillo retira todos los medallones")
	zona.queue_free()
	maquina.queue_free()
	await _cuadros(3)
	_verificar(not hud.visible, "Retirar los controladores no deja iconos ni referencias inválidas")
	oficina.queue_free()
	await _cuadros(8)
	print("[HUD_BOLSILLO] %d comprobaciones, %d errores" % [comprobaciones, errores])
	quit(0 if errores == 0 else 1)

func _entrada(id: int) -> Dictionary:
	for entrada: Dictionary in hud.entradas:
		if entrada.id == id:
			return entrada
	return {}

func _captura(nombre: String) -> void:
	if not OS.get_cmdline_user_args().has("--capturas"):
		return
	await RenderingServer.frame_post_draw
	var carpeta := "res://.godot/bolsillo_qa"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta))
	root.get_texture().get_image().save_png(carpeta.path_join(nombre + ".png"))

func _tecla(tecla: Key) -> void:
	for presionada: bool in [true, false]:
		var evento := InputEventKey.new()
		evento.physical_keycode = tecla
		evento.pressed = presionada
		Input.parse_input_event(evento)

func _cuadros(cantidad: int) -> void:
	for i in cantidad:
		await process_frame

func _verificar(condicion: bool, mensaje: String) -> void:
	comprobaciones += 1
	if condicion:
		print("OK: " + mensaje)
	else:
		errores += 1
		push_error("[HUD_BOLSILLO] " + mensaje)
