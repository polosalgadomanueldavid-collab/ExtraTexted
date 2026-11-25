extends SceneTree
## --headless --fixed-fps 60 --script res://Pruebas/ZonaDescanso/prueba_guia_shop.gd
## Sin headless: añadir -- --capturas para revisar recompensa, radio y proximidad.
var oficina
var guia
var maquina
var jugador
var pruebas := 0
var errores := 0
var capturas := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	capturas = OS.get_cmdline_user_args().has("--capturas")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 800)
	await _oficina()
	var panel = oficina.panel_despacho
	_verificar(not guia.visible and not guia.pendiente, "El turno empieza sin invitación ni marcador")
	_premiar("SHOP-1", 25)
	await _cuadros(3)
	_verificar(not guia.pendiente and panel.puntos_ganancia.text == "+25", "Un saldo insuficiente solo actualiza los puntos del HUD")
	panel.efecto_tarea.reproducir("Evidencias", "SHOP-2")
	_premiar("SHOP-2", 25)
	await _cuadros(4)
	_verificar(guia.pendiente and not guia.ofrecida, "Cruzar el precio reserva una invitación tras la recompensa")
	_verificar(panel.puntos_valor.text == "50" and panel.puntos_animados.visible and panel._saldo_visual < 50, "El saldo real es inmediato y su cifra visible cuenta suavemente")
	await _captura("01_recompensa")
	var espera = guia._demora
	var valor = panel._saldo_visual
	paused = true
	await _cuadros(15)
	_verificar(guia._demora == espera and panel._saldo_visual == valor, "La pausa congela demora y contador")
	paused = false
	oficina.clasificador_evidencias.iniciar("SHOP-UI")
	await _cuadros(30)
	_verificar(not guia.is_visible_in_tree() and guia._demora == espera, "Evidencias aplaza el aviso sin gastar su duración")
	oficina.clasificador_evidencias.cancelar()
	await _cuadros(20)
	_verificar(not guia.visible and panel.efecto_tarea.visible, "La señal de tienda espera a que termine ¡Hecho!")
	await _cuadros(95)
	_verificar(guia.visible and guia.ofrecida, "La primera compra disponible señala la tienda")
	_verificar(guia.get_child_count() == 0, "No hay un segundo mensaje de radio ni un sello superpuesto")
	_verificar(maquina.precio == 50, "El marcador utiliza el producto y su precio real")
	_verificar(guia.restante > 0 and not jugador.input_locked and not paused, "La invitación deja continuar el turno")
	_verificar(panel.puntos_valor.self_modulate.a == 1 and not panel.puntos_animados.visible, "El contador termina mostrando la cifra exacta")
	await _captura("02_tienda_descriptiva")
	for dimensiones: Vector2i in [Vector2i(960, 540), Vector2i(1024, 768), Vector2i(1920, 1080), Vector2i(1280, 800)]:
		root.size = dimensiones
		await _cuadros(3)
		_verificar(Rect2(Vector2.ZERO, guia.size).encloses(guia.marcador), "El indicador queda dentro de la pantalla en %s" % dimensiones)
	var restante = guia.restante
	root.get_node("MenuGlobal").abrir_pausa()
	await _cuadros(8)
	_verificar(not guia.is_visible_in_tree() and guia.restante == restante, "Abrir pausa oculta la guía y conserva su duración")
	root.get_node("MenuGlobal").reanudar_juego()
	await _cuadros(2)
	_verificar(guia.visible, "Al volver de pausa reaparece el aviso pendiente")
	for i in 100:
		jugador.global_position = maquina.global_position + Vector3(1.6 - i * .01, .01, 0)
		jugador.velocity = Vector3.ZERO
		jugador.visual.rotation.y = -PI / 2
		if jugador.obtener_objetivo_interaccion() == maquina: break
	await _cuadros(12)
	_verificar(guia.interactuable, "Cerca de SHOP se ofrece la interacción real de E")
	await _captura("03_cerca")
	maquina.interactuar(jugador)
	_verificar(maquina.panel.visible and not guia.visible and guia.restante == 0, "Abrir la tienda retira radio e indicador inmediatamente")
	await _captura("04_tienda")
	_verificar(maquina.comprar(), "La recompensa sirve para comprar de verdad")
	await _cuadros(100)
	_verificar(maquina.recoger_producto() and oficina.sistema_despacho.puntuacion.puntos == 0, "La entrega cobra una sola vez el producto")
	maquina.cerrar()
	_premiar("SHOP-3", 100)
	await _cuadros(3)
	_verificar(not guia.pendiente and not guia.visible and panel.puntos_ganancia.text == "+100", "Los siguientes casos solo actualizan el saldo")
	await _captura("05_segundo_caso")
	_verificar(oficina.sistema_despacho.puntuacion.gastar_puntos(25), "Puede gastar saldo mientras la recompensa está contando")
	_verificar(panel.puntos_valor.text == "75" and not panel.puntos_animados.visible and panel.puntos_valor.self_modulate.a == 1.0, "Un gasto interrumpe el conteo y muestra el saldo exacto")
	await _cuadros(100)
	_verificar(panel.puntos_valor.text == "75" and not panel.puntos_animados.visible, "El conteo cancelado no repone un saldo visual antiguo")
	# Nueva oficina: productos propios y precios personalizados.
	await _oficina()
	_verificar(not guia.ofrecida, "Un turno nuevo permite otra invitación")
	maquina.inventario.assign([1, 1, 1, 1])
	maquina.precio = 63
	_premiar("SHOP-PRECIO", 70)
	await _cuadros(100)
	_verificar(guia.visible and maquina.precio == 63 and guia._compra_disponible(), "Ofrece el sorteo al precio único configurado aunque ya haya cargas de todos los productos")
	await _cuadros(370)
	_verificar(guia.ofrecida and not guia.visible and guia.restante == 0, "El aviso desaparece solo después de seis segundos visibles")
	_premiar("SHOP-OTRO", 100)
	await _cuadros(100)
	_verificar(not guia.visible and not guia.pendiente, "Ignorar la invitación tampoco provoca repeticiones")
	# Nueva oficina: la práctica no lanza ayudas de turno normal.
	await _oficina()
	_premiar("SHOP-PRACTICA", 50, true)
	await _cuadros(100)
	_verificar(not guia.visible and not guia.pendiente, "La práctica conserva su propia guía y celebración")
	ofrecida_antes_de_saldo()
	await _cuadros(3)
	_verificar(guia.ofrecida and not guia.pendiente, "Visitar SHOP antes de cobrar ya completa su descubrimiento")
	maquina.queue_free()
	await _cuadros(5)
	_verificar(not guia.visible and not guia.is_processing(), "Retirar la máquina desactiva limpiamente su guía")
	oficina.queue_free()
	await _cuadros(8)
	# El mezclador de audio libera voces en tiempo real, incluso con fixed-fps.
	var limite := Time.get_ticks_msec() + 500
	while Time.get_ticks_msec() < limite:
		await process_frame
	print("[GUIA SHOP] %d comprobaciones, %d errores" % [pruebas, errores])
	quit(1 if errores else 0)

func ofrecida_antes_de_saldo() -> void:
	maquina.panel.show()
	maquina.panel.hide()
	_premiar("SHOP-VISITADA", 100)

func _oficina() -> void:
	if is_instance_valid(oficina):
		oficina.queue_free()
		await _cuadros(8)
	root.get_node("MenuGlobal").omitir_tutorial_siguiente_partida = true
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	await _cuadros(100)
	for reloj in [oficina.temporizador_denuncias, oficina.temporizador_bloqueos, oficina.temporizador_eventos]: reloj.stop()
	oficina.anuncios.detener()
	guia = oficina.guia_shop
	maquina = oficina.get_node("MaquinaExpendedora")
	jugador = oficina.jugador
	jugador.global_position = Vector3(-1, .38, 2)
	await _cuadros(8)

func _premiar(id: String, puntos: int, practica := false) -> void:
	var caso := Denuncia.new()
	caso.id = id
	caso.titulo = "Caso de comprobación"
	caso.puntaje_recompensa = puntos
	caso.es_practica = practica
	oficina.sistema_despacho.recibir_denuncia(caso)
	oficina.sistema_despacho.resolver_denuncia(id)

func _cuadros(cantidad: int) -> void:
	for i in cantidad: await physics_frame
	await process_frame

func _captura(nombre: String) -> void:
	if not capturas: return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/guia_shop_qa")
	root.get_texture().get_image().save_png("res://.godot/guia_shop_qa/" + nombre + ".png")

func _verificar(condicion: bool, mensaje: String) -> void:
	pruebas += 1
	if condicion: print("OK: " + mensaje)
	else:
		errores += 1
		push_error(mensaje)
