extends Node
## Solo se carga con --script prueba_lan.gd; no forma parte de una sesión normal.
signal respuesta(valor: Dictionary)
signal respuesta_cliente(valor: Dictionary)
var fallos := 0
var comprobaciones := 0
var cliente := 0
var red: Node
var oficina: Node
var _terminando := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()
	_timeout()

func _timeout() -> void:
	var limite := Timer.new()
	limite.one_shot = true
	add_child(limite)
	limite.timeout.connect(func():
		if not _terminando:
			push_error("LAN: tiempo de espera agotado")
			get_tree().quit(1)
	)
	limite.start(230.0)

func _esperar(segundos := 0.3) -> void:
	await get_tree().create_timer(segundos).timeout

func _pedir(tipo: String, datos: Dictionary = {}) -> Dictionary:
	SesionLAN.solicitar(tipo, datos, func(valor: Dictionary): respuesta.emit(valor))
	return await respuesta

func _al_cliente(orden: String, datos: Dictionary = {}) -> Dictionary:
	_orden.rpc_id(cliente, orden, datos)
	var resultado: Dictionary = await respuesta_cliente
	if not resultado.get("ok", true):
		print("[LAN RECHAZO] %s %s: %s" % [orden, datos, resultado])
	return resultado

func comprobar(condicion: bool, mensaje: String) -> void:
	comprobaciones += 1
	print("[LAN %s] %s" % ["OK" if condicion else "FALLO", mensaje])
	if not condicion:
		fallos += 1

func _mover_host(posicion: Vector3) -> void:
	oficina.jugador.global_position = posicion
	oficina.jugador.velocity = Vector3.ZERO
	await _esperar()

func _mover_cliente(posicion: Vector3) -> void:
	# Los saltos de posición pertenecen al conductor, no al movimiento jugable.
	# Esperar el acuse evita que un paquete anterior al salto restablezca el
	# historial y haga que el validador rechace el teletransporte de la prueba.
	var confirmacion := await _al_cliente("mover", {"pos": posicion})
	red._ultimo_movimiento.erase(cliente)
	red._remotos.erase(cliente)
	red.jugadores[cliente].global_position = confirmacion.pos
	await _esperar(0.15)

func _run() -> void:
	var escena_oficina: PackedScene
	if OS.get_cmdline_user_args().has("--solo-oficina"):
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = Vector2i(1280, 720)
		escena_oficina = load("res://Mundo/Oficina.tscn")
	_demorar_carga_prueba()
	SesionLAN.aviso.connect(func(mensaje: String) -> void: print("[LAN AVISO] ", mensaje))
	MenuGlobal._clasificacion = ClasificacionLocal.new("user://prueba_lan_%d.json" % OS.get_process_id())
	MenuGlobal.omitir_tutorial_siguiente_partida = false
	if OS.get_cmdline_user_args().has("--host"):
		comprobar(SesionLAN.crear("Anfitrión") == OK, "Crear servidor ENet")
		while SesionLAN.participantes.size() < 2:
			await _esperar(0.1)
		for id: int in SesionLAN.participantes:
			if id != 1: cliente = id
		SesionLAN.establecer_listo(true)
		while not SesionLAN.participantes[cliente].listo:
			await _esperar(0.1)
		SesionLAN.iniciar()
	else:
		await _esperar(0.6)
		SesionLAN.unirse("127.0.0.1", "Compañero")
		while not SesionLAN.participantes.has(SesionLAN.id_local()):
			await _esperar(0.1)
		SesionLAN.establecer_listo(true)
	while not SesionLAN.en_partida:
		await _esperar(0.1)
	while CargaEscenas.activa:
		await _esperar(0.05)
	red = SesionLAN.puente
	oficina = red.oficina
	if escena_oficina != null:
		comprobar(oficina.scene_file_path == escena_oficina.resource_path, "El jugador entra en la oficina prevista")
	oficina.evento_terremoto.preparacion_terminada.connect(func(correcta: bool) -> void: print("[LAN PREPARACION] ", correcta, " motivo=", oficina.evento_terremoto.rechazo_preparacion))
	comprobar(oficina.oficina_preparada and oficina._bloqueos_pool.size() == 30 and not CargaEscenas.activa, "La barrera incluye preparación, pool completo y primer cuadro")
	if not SesionLAN.es_anfitrion():
		return
	await _esperar(0.6)
	comprobar(get_tree().paused and MenuGlobal.panel_ayuda.visible, "El tutorial inicial abre sin bloquear la carga")
	await _probar_confirmaciones_tutorial(true)
	comprobar(red.jugadores.size() == 2 and not get_tree().paused, "Dos jugadores y barrera de carga completada")
	if OS.get_cmdline_user_args().has("--solo-duelo"):
		await _probar_duelo_y_cordura()
		return
	if OS.get_cmdline_user_args().has("--solo-senales"):
		await _probar_senales()
		return
	if OS.get_cmdline_user_args().has("--solo-terremoto"):
		await _probar_barrera_terremoto()
		return
	await _comprobar_personajes()
	comprobar(await _probar_colision(), "El cuerpo local choca y la interpolación remota no lo atraviesa")
	var colision_cliente := await _al_cliente("colision")
	comprobar(colision_cliente.ok, "La colisión entre jugadores funciona también en el cliente")
	for evento in ["apagon", "terremoto", "incendio", "inundacion", "lava", "hielo"]:
		oficina.tutoriales_vistos[StringName(evento)] = true
	await _al_cliente("tutoriales")
	oficina.temporizador_denuncias.stop()
	var despacho: SistemaDespacho = oficina.sistema_despacho
	for i in 2:
		var caso := Denuncia.new()
		caso.id = "LAN-%d" % i
		caso.titulo = "Caso LAN %d" % i
		caso.protocolo_estaciones.assign(["evidencias", "bienestar"] if i == 0 else ["evidencias", "verificacion", "bienestar"])
		despacho.recibir_denuncia(caso)
	red.publicar()
	await _mover_host(oficina.computador.global_position + Vector3(0, 0, 1))
	var r: Dictionary = await _pedir("tomar")
	comprobar(r.get("ok", false), "El anfitrión toma una hoja")
	var caso_host := str(r.get("caso", ""))
	await _mover_cliente(oficina.computador.global_position + Vector3(0.5, 0, 1))
	r = await _al_cliente("accion", {"tipo": "tomar"})
	comprobar(r.get("ok", false) and r.get("caso", "") != caso_host, "El cliente toma un caso distinto")
	var caso_cliente := str(r.get("caso", ""))
	await _esperar()
	r = await _al_cliente("inspeccionar")
	comprobar(int(r.get("hojas", 0)) == 2 and int(r.get("casos", 0)) == 2, "Dos hojas y casos replicados")
	if OS.get_cmdline_user_args().has("--solo-oficina"):
		await _probar_oficina_compartida(caso_host, caso_cliente)
		return
	if DisplayServer.get_name() != "headless":
		await _esperar(4.0)
		await _capturar("anfitrion")
		await _al_cliente("capturar")
		if OS.get_cmdline_user_args().has("--solo-captura"):
			await _al_cliente("terminar")
			while SesionLAN.activa:
				await _esperar(0.1)
			await _esperar(1.0)
			_terminando = true
			await _finalizar_prueba(0)
			return
	despacho.perder_calma(20, &"prueba", 1)
	despacho.perder_calma(20, &"prueba", cliente)
	for estacion in ["evidencias", "bienestar"]:
		await _mover_host(red._buscar_estacion(estacion).global_position + Vector3(0, 0, 0.6))
		r = await _pedir("estacion", {"caso": caso_host, "estacion": estacion})
		comprobar(r.get("ok", false), "Reservar estación " + estacion)
		if estacion == "evidencias":
			await _mover_cliente(red._buscar_estacion(estacion).global_position + Vector3(0.5, 0, 0.6))
			r = await _al_cliente("accion", {"tipo": "estacion", "datos": {"caso": caso_cliente, "estacion": estacion}})
			comprobar(not r.get("ok", true), "La misma estación rechaza un segundo caso mientras está reservada")
			oficina._interactuar_evidencias()
			await _esperar(0.3)
			_resolver_minijuego("evidencias")
			await _esperar()
			comprobar(despacho.arbol.buscar_por_id(caso_host).estaciones_completadas.has("evidencias"), "El minijuego real confirma antes de liberar la estación")
	comprobar(despacho.puntuacion.puntos == 100 and despacho.obtener_cordura(1) == 85 and despacho.obtener_cordura(cliente) == 80, "Recompensa única y cordura solo al participante")
	await _esperar()
	r = await _al_cliente("inspeccionar")
	comprobar(int(r.saldo) == 100, "Saldo compartido replicado")
	await _mover_host(red._objeto("tienda").global_position + Vector3(0.5, 0, 0))
	r = await _pedir("reservar", {"objetivo": "tienda"})
	r = await _pedir("comprar", {"producto": "snack"})
	comprobar(r.get("ok", false) and despacho.puntuacion.puntos == 50, "Compra descuenta fondo común")
	r = await _pedir("comprar", {"producto": "snack"})
	comprobar(not r.get("ok", true) and despacho.puntuacion.puntos == 50, "La espera personal no entrega ni cobra")
	comprobar(oficina.espera_compra("snack", cliente) == 0 and oficina.espera_compra("cafe", 1) == 0, "La espera respeta el jugador y el servicio")
	await _pedir("liberar", {"objetivo": "tienda"})
	await _mover_cliente(red._objeto("tienda").global_position + Vector3(0, 0, 0.6))
	await _al_cliente("accion", {"tipo": "reservar", "datos": {"objetivo": "tienda"}})
	r = await _al_cliente("accion", {"tipo": "comprar", "datos": {"producto": "snack"}})
	comprobar(r.get("ok", false) and red.bolsillos[cliente][r.indice] == 1 and despacho.puntuacion.puntos == 0, "El compañero compra su premio durante la espera del anfitrión")
	await _al_cliente("accion", {"tipo": "liberar", "datos": {"objetivo": "tienda"}})
	# El cliente completa ambas interfaces y la resolución llega por RPC.
	for estacion in ["evidencias", "verificacion", "bienestar"]:
		await _mover_cliente(red._buscar_estacion(estacion).global_position + Vector3(0, 0, 0.6))
		r = await _al_cliente("minijuego", {"estacion": estacion, "caso": caso_cliente})
		comprobar(r.get("ok", false), "El cliente completa " + estacion + " con su interfaz")
		if estacion == "evidencias":
			comprobar(r.get("aviso_tarea", "") == caso_cliente and oficina.panel_despacho.efecto_tarea.caso_id != caso_cliente, "El aviso de tarea aparece solo para quien la completó")
	comprobar(despacho.puntuacion.puntos == 100 and despacho.obtener_cordura(cliente) == 85, "Resolución del cliente conserva saldo y participación")
	# Cafetera y expendedora compiten por los últimos 50 puntos en el mismo turno.
	despacho.puntuacion.gastar_puntos(50)
	oficina._duracion_partida += 70.0
	await _mover_host(red._objeto("tienda").global_position + Vector3(0.5, 0, 0))
	await _pedir("reservar", {"objetivo": "tienda"})
	await _mover_cliente(red._objeto("cafetera").global_position + Vector3(0, 0, 0.6))
	r = await _al_cliente("accion", {"tipo": "reservar", "datos": {"objetivo": "cafetera"}})
	comprobar(r.get("ok", false) and red.reservas.has("tienda"), "Ambos compradores tienen una operación reservada antes de competir por el saldo")
	var bolsillo_previo: Array = red.bolsillos[1].duplicate()
	var bolsillo_cliente: Array = red.bolsillos[cliente].duplicate()
	var compras: Array = []
	_orden.rpc_id(cliente, "accion", {"tipo": "comprar", "datos": {"producto": "cafe"}})
	SesionLAN.solicitar("comprar", {"producto": "snack"}, func(valor: Dictionary): compras.append(valor))
	r = await respuesta_cliente
	await _esperar()
	comprobar(compras.size() == 1 and int(compras[0].ok) + int(r.ok) == 1 and despacho.puntuacion.puntos == 0, "Compras concurrentes: se entrega y cobra un solo producto")
	if compras[0].ok:
		bolsillo_previo[int(compras[0].indice)] += 1
	comprobar(red.bolsillos[1] == bolsillo_previo and red.bolsillos[cliente] == bolsillo_cliente and red.cafes[cliente] == r.ok, "Cada producto pertenece exclusivamente a su comprador")
	await _pedir("liberar", {"objetivo": "tienda"})
	await _al_cliente("accion", {"tipo": "liberar", "datos": {"objetivo": "cafetera"}})
	await _probar_colores_cafe()
	SesionLAN.pedir_pausa(true)
	await _esperar()
	r = await _al_cliente("pausar", {"valor": true})
	SesionLAN.pedir_pausa(false)
	await _esperar()
	comprobar(get_tree().paused, "La pausa del cliente mantiene detenido al anfitrión")
	await _al_cliente("pausar", {"valor": false})
	await _esperar()
	comprobar(not get_tree().paused, "Se reanuda cuando ambos cierran pausa")
	var colaborativo := Denuncia.new()
	colaborativo.id = "LAN-COLABORACION"
	colaborativo.tiempo_limite_segundos = 300
	colaborativo.protocolo_estaciones.assign(["evidencias", "privacidad", "bienestar"])
	despacho.recibir_denuncia(colaborativo)
	await _mover_host(oficina.computador.global_position + Vector3(0, 0, 1))
	await _pedir("tomar")
	await _mover_host(red._buscar_estacion("evidencias").global_position + Vector3(0, 0, 0.6))
	red.solicitar_estacion("evidencias", colaborativo.id)
	await _esperar(0.5)
	_resolver_minijuego("evidencias")
	await _esperar()
	await _mover_host(red._buscar_estacion("privacidad").global_position + Vector3(0, 0, 0.6))
	r = await _pedir("estacion", {"caso": colaborativo.id, "estacion": "privacidad"})
	comprobar(r.get("tarea", "") == "esperar", "Seguridad reserva el caso durante el desencriptado")
	await _mover_host(Vector3(-0.5, 0.4, 5.0))
	await _pedir("lanzar")
	await _esperar(0.4)
	await _mover_cliente(red.papeles[colaborativo.id].global_position)
	# Dos solicitudes compiten por la misma hoja en el mismo turno de red.
	var recogidas: Array = []
	_orden.rpc_id(cliente, "accion", {"tipo": "recoger", "datos": {"caso": colaborativo.id}})
	SesionLAN.solicitar("recoger", {"caso": colaborativo.id}, func(valor: Dictionary): recogidas.append(valor))
	r = await respuesta_cliente
	await _esperar()
	comprobar(recogidas.size() == 1 and int(recogidas[0].ok) + int(r.ok) == 1, "La doble recogida confirma un único portador")
	if red.papeles[colaborativo.id].portador == oficina.jugador:
		await _pedir("lanzar")
		await _esperar(0.4)
		await _mover_cliente(red.papeles[colaborativo.id].global_position)
		await _al_cliente("accion", {"tipo": "recoger", "datos": {"caso": colaborativo.id}})
	comprobar(red.papeles[colaborativo.id].portador == red.jugadores[cliente], "El compañero recoge la hoja lanzada con su progreso")
	await _esperar(6.1)
	await _mover_cliente(red._buscar_estacion("privacidad").global_position + Vector3(0, 0, 0.6))
	r = await _al_cliente("accion", {"tipo": "estacion", "datos": {"caso": colaborativo.id, "estacion": "privacidad"}})
	comprobar(r.get("ok", false) and not red.reservas.has("estacion:privacidad"), "El compañero recoge el resultado reservado de Seguridad")
	var corduras := [despacho.obtener_cordura(1), despacho.obtener_cordura(cliente)]
	await _mover_cliente(red._buscar_estacion("bienestar").global_position + Vector3(0, 0, 0.6))
	await _al_cliente("accion", {"tipo": "estacion", "datos": {"caso": colaborativo.id, "estacion": "bienestar"}})
	comprobar(despacho.obtener_cordura(1) == mini(100, corduras[0] + 5) and despacho.obtener_cordura(cliente) == mini(100, corduras[1] + 5), "Colaborar recupera cordura para ambos participantes")
	await _probar_llaves()
	oficina.bloqueos_iniciados = true
	oficina.temporizador_eventos.stop()
	await _mover_host(Vector3(-0.5, 0.4, 5.0))
	await _mover_cliente(Vector3(0.3, 0.4, 5.0))
	for tipo in ["apagon", "incendio", "inundacion", "lava", "hielo", "terremoto"]:
		var inicio: bool = red.iniciar_evento(tipo)
		comprobar(inicio, "Iniciar evento compartido " + tipo)
		if tipo == "terremoto":
			var limite := Time.get_ticks_msec() + 20000
			while oficina.evento_terremoto.preparando and Time.get_ticks_msec() < limite:
				await _esperar(0.05)
			comprobar(oficina.evento_terremoto.activo, "La distribución normal LAN permite iniciar el terremoto")
			if not oficina.evento_terremoto.activo:
				await _al_cliente("terminar")
				_terminando = true
				await _finalizar_prueba(1)
				return
		await _esperar(0.6)
		r = await _al_cliente("inspeccionar")
		comprobar(str(r.evento) == tipo, "Cliente recibe " + tipo)
		if tipo in ["apagon", "inundacion", "hielo"]:
			var celda: Vector2i = oficina.grafo_piso.celda_de_acceso(red._objeto(tipo).global_position)
			await _mover_cliente(oficina.grafo_piso.celda_a_posicion(celda) + Vector3.UP * 0.4)
			r = await _al_cliente("accion", {"tipo": "reservar", "datos": {"objetivo": tipo}})
			comprobar(r.get("ok", false), "Cliente reserva reparación de " + tipo)
			r = await _al_cliente("accion", {"tipo": "reparar", "datos": {"objetivo": tipo}})
			comprobar(r.get("ok", false), "Cliente confirma reparación de " + tipo)
			red.bolsillos[1][3] = 1
			r = await _pedir("consumir", {"indice": 3, "evento": red._evento_id})
			comprobar(not r.get("ok", true) and red.bolsillos[1][3] == 1, "Avatar conserva su carga si la reparación ganó en " + tipo)
		if tipo == "incendio":
			comprobar(oficina.evento_incendio.extintores.size() == 2 and int(r.extintores) == 2, "Dos extintores visibles en ambos equipos")
			await _mover_cliente(red._objeto("extintor").global_position + Vector3(0, 0, 0.5))
			r = await _al_cliente("accion", {"tipo": "reservar", "datos": {"objetivo": "extintor"}})
			comprobar(r.get("ok", false), "El cliente reserva el primer extintor")
			await _mover_host(red._objeto("extintor:1").global_position + Vector3(0, 0, 0.5))
			r = await _pedir("reservar", {"objetivo": "extintor"})
			comprobar(not r.ok, "Dos jugadores no pueden tomar el mismo extintor")
			r = await _al_cliente("accion", {"tipo": "reservar", "datos": {"objetivo": "extintor:1"}})
			comprobar(not r.ok, "Un jugador no puede acaparar los dos extintores")
			r = await _pedir("reservar", {"objetivo": "extintor:1"})
			comprobar(r.ok and red.tiene_extintor(1) and red.tiene_extintor(cliente), "Ambos jugadores llevan un extintor independiente")
			await _esperar()
			r = await _al_cliente("inspeccionar")
			comprobar(int(r.extintores_recogidos) == 2, "Ambos extintores siguen a sus portadores en el cliente")
			var foco: Node3D = oficina.evento_incendio.focos[0]
			await _mover_cliente(foco.acceso.global_position + Vector3.UP * 0.02)
			r = await _al_cliente("rociar", {"foco": 0})
			comprobar(r.get("ok", false) and foco.apagado >= 1.0, "El extintor del cliente apaga la mesa en el anfitrión")
			var otro_foco: Node3D = oficina.evento_incendio.focos[oficina.evento_incendio.focos.size() / 2]
			await _mover_host(otro_foco.acceso.global_position + Vector3.UP * 0.02)
			var hacia: Vector3 = otro_foco.global_position - oficina.jugador.global_position
			oficina.jugador.visual.rotation.y = atan2(hacia.x, hacia.z)
			r = await _pedir("rociar", {"foco": oficina.evento_incendio.focos.find(otro_foco), "delta": 0.1})
			comprobar(r.ok and otro_foco.apagado > 0, "El segundo extintor también apaga fuego")
		if tipo == "lava":
			r = await _al_cliente("charcos")
			comprobar(r.charcos == oficina.evento_lava.charcos, "El anfitrión publica los charcos exactos de lava")
		if tipo == "terremoto":
			r = await _al_cliente("trazado")
			var formas: Array = oficina.evento_terremoto.exportar_trazado_red().get("formas", [])
			comprobar(not formas.is_empty() and r.get("formas", []) == formas, "Ambos equipos usan exactamente las mismas grietas")
		if tipo not in ["apagon", "inundacion", "hielo"]:
			red.bolsillos[1][3] = 1
			r = await _pedir("consumir", {"indice": 3, "evento": red._evento_id})
			comprobar(r.get("ok", false), "Avatar inicia la transición compartida de " + tipo)
			await _esperar(0.4)
			var evento: Node = oficina.get("evento_" + tipo)
			comprobar(evento.resolviendo_avatar, "El evento mantiene su transición visible: " + tipo)
		# Reparación normal: hasta 4 s de drenaje. Avatar: 2,6 s de transición.
		await _esperar(4.3)
		oficina.temporizador_eventos.stop()
		r = await _al_cliente("inspeccionar")
		comprobar(str(r.evento).is_empty(), "La resolución termina " + tipo + " en ambos")
		if tipo == "incendio":
			comprobar(not red.tiene_extintor(1) and not red.tiene_extintor(cliente) and int(r.extintores) == 0, "Avatar retira ambos extintores y libera sus reservas")
	red.bolsillos[cliente][2] = 1
	r = await _al_cliente("accion", {"tipo": "consumir", "datos": {"indice": 2}})
	comprobar(r.get("ok", false), "El cliente activa papa tiempo mediante la acción autorizada")
	await _esperar()
	r = await _al_cliente("inspeccionar")
	comprobar(bool(r.tiempo) and despacho.tiempo_detenido, "Papa tiempo compartida")
	var audio_host: AudioStreamPlayer = oficina.get_node("MaquinaExpendedora").poderes._sonido_detener
	comprobar(audio_host.playing and int(r.audios_tiempo) == 1, "Za Warudo tiene un solo reproductor activo por equipo")
	var posicion_audio := audio_host.get_playback_position()
	var posicion_cliente := float(r.posicion_audio)
	# Reenviar la misma confirmación no reinicia la pista, ni ahora ni al terminar.
	SesionLAN.difundir("tiempo", {"jugador": cliente, "activacion": red._activacion_tiempo})
	await _esperar(0.3)
	r = await _al_cliente("inspeccionar")
	comprobar(audio_host.get_playback_position() >= posicion_audio and float(r.posicion_audio) >= posicion_cliente and int(r.audios_tiempo) == 1, "Confirmación repetida: Za Warudo continúa sin volver a empezar")
	await _esperar(12.4)
	comprobar(not despacho.tiempo_detenido, "El tiempo se restaura")
	SesionLAN.difundir("tiempo", {"jugador": cliente, "activacion": red._activacion_tiempo})
	await _esperar(0.3)
	r = await _al_cliente("inspeccionar")
	comprobar(not despacho.tiempo_detenido and not audio_host.playing and not r.tiempo and int(r.audios_tiempo) == 0, "Confirmación tardía: no vuelve a activar ni reproducir Za Warudo")
	await _probar_llaves(false)
	comprobar(red.iniciar_evento("incendio"), "Nuevo incendio repone las dos herramientas")
	await _mover_host(red._objeto("extintor").global_position + Vector3(0, 0, 0.5))
	await _pedir("reservar", {"objetivo": "extintor"})
	await _mover_cliente(red._objeto("extintor:1").global_position + Vector3(0, 0, 0.5))
	await _al_cliente("accion", {"tipo": "reservar", "datos": {"objetivo": "extintor:1"}})
	despacho.perder_calma(100, &"prueba", 1)
	await _esperar()
	r = await _al_cliente("inspeccionar")
	comprobar(not despacho.terminada and bool(r.activo_local), "El anfitrión eliminado mantiene vivo al cliente")
	comprobar(not red.tiene_extintor(1) and red.tiene_extintor(cliente), "Eliminar al anfitrión libera solo su extintor")
	comprobar(red.reservas["estacion:reporte"].herramientas == [0, cliente] and int(r.llaves) == 1, "La llave del eliminado reaparece sin quitar la del compañero")
	comprobar(oficina.jugador.collision_layer == 0, "El eliminado deja de bloquear al compañero")
	await _al_cliente("accion", {"tipo": "liberar", "datos": {"objetivo": "extintor:1"}})
	await _mover_cliente(red._objeto("extintor").global_position + Vector3(0, 0, 0.5))
	r = await _al_cliente("accion", {"tipo": "reservar", "datos": {"objetivo": "extintor"}})
	comprobar(r.ok, "El superviviente puede recuperar el extintor liberado")
	despacho.perder_calma(100, &"prueba", cliente)
	red.publicar()
	await _esperar()
	r = await _al_cliente("inspeccionar")
	comprobar(despacho.terminada and bool(r.final), "Derrota compartida al eliminarse ambos")
	comprobar(r.aportes == despacho.aportes_jugadores, "El cliente recibe los mismos aportes que el anfitrión")
	comprobar(r.equipo_final == oficina.final_partida._datos.get("equipo", []) and not r.equipo_final.is_empty(), "Ambos cuadernos presentan el mismo equipo y MVP al finalizar")
	var limite_cinematica := Time.get_ticks_msec() + 70000
	while not oficina.final_partida._relevo_finalizado and Time.get_ticks_msec() < limite_cinematica:
		await _esperar(0.2)
	r = await _al_cliente("estado_cinematica")
	comprobar(oficina.final_partida._relevo_finalizado and bool(r.finalizada), "La cinemática acaba en ambos equipos")
	comprobar(not red.jugadores[1].visible and not red.jugadores[cliente].visible and bool(r.salieron), "Ambos jugadores salen por la puerta en las dos vistas")
	comprobar(oficina.final_partida._boton_reintentar.text == "Reintentar 0/2" and str(r.reintentar) == "Reintentar 0/2", "Las dos libretas muestran 0/2 antes de votar")
	await _al_cliente("preparar_reinicio")
	MenuGlobal.omitir_tutorial_siguiente_partida = true
	SesionLAN.votar_reintento()
	await _esperar(0.2)
	r = await _al_cliente("estado_reintento")
	comprobar(SesionLAN.votos_reintento.size() == 1 and int(r.votos) == 1 and SesionLAN.en_partida, "El primer voto muestra 1/2 y mantiene la partida")
	await _al_cliente("votar_reintento")
	while not SesionLAN.en_partida:
		await _esperar(0.1)
	red = SesionLAN.puente
	oficina = red.oficina
	await _esperar(0.4)
	r = await _al_cliente("nueva_ronda")
	comprobar(oficina.sistema_despacho.puntuacion.puntos == 0 and int(r.saldo) == 0 and red.papeles.is_empty(), "Reinicio sin saldo ni hojas de la ronda anterior")
	comprobar(oficina.sistema_despacho.obtener_cordura(1) == 100 and bool(r.activo_local), "Ambos vuelven activos en la nueva ronda")
	var aportes_reinicio: Dictionary = oficina.sistema_despacho.aportes_jugadores
	comprobar(r.aportes == aportes_reinicio and aportes_reinicio[1].misiones == 0 and aportes_reinicio[cliente].tareas == 0, "El reinicio borra los aportes en ambos equipos")
	var ronda_actual := SesionLAN.ronda
	var puente_actual := SesionLAN.puente
	SesionLAN._cargar(ronda_actual - 1)
	SesionLAN._comenzar(ronda_actual - 1)
	SesionLAN._cambiar_a_oficina(ronda_actual - 1)
	comprobar(SesionLAN.en_partida and SesionLAN.ronda == ronda_actual and SesionLAN.puente == puente_actual and not CargaEscenas.activa, "Cargas e inicios atrasados no reemplazan la ronda actual")
	r = await _al_cliente("movimiento_antiguo")
	comprobar(bool(r.ok), "Un movimiento de la ronda anterior no altera al jugador remoto")
	await _comprobar_personajes()
	# El primer evento debe abrir su guía en ambos, aunque el anfitrión ya haya pausado.
	oficina.bloqueos_iniciados = true
	comprobar(red.iniciar_evento("apagon"), "Inicio del primer evento con tutorial")
	await _esperar(0.5)
	r = await _al_cliente("inspeccionar")
	comprobar(bool(r.guia) and str(r.evento) == "apagon" and get_tree().paused, "Guía del evento visible y sincronizada en ambos")
	await _probar_confirmaciones_tutorial(false)
	await _al_cliente("desconectar_en_carga")
	SesionLAN.reiniciar()
	while SesionLAN.activa or get_tree().current_scene == oficina or get_tree().current_scene == null:
		await _esperar(0.1)
	while CargaEscenas.activa:
		await _esperar(0.1)
	comprobar(get_tree().current_scene.scene_file_path == CargaEscenas.MENU and not get_tree().paused, "Desconectar durante preparación recupera el menú del anfitrión")
	comprobar(get_tree().get_nodes_in_group("gestor_partida").is_empty(), "La desconexión retira la oficina incompleta")
	print("[LAN RESULTADO] %d comprobaciones, %d errores" % [comprobaciones, fallos])
	_terminando = true
	await _finalizar_prueba(1 if fallos else 0)

func _demorar_carga_prueba() -> void:
	# Primera entrada con cliente lento; reinicio con anfitrión lento.
	var ronda_lenta := 2 if OS.get_cmdline_user_args().has("--host") else 1
	while not (SesionLAN.cargando and SesionLAN.ronda == ronda_lenta and CargaEscenas._fase == "listo"):
		await get_tree().process_frame
	CargaEscenas.set_process(false)
	await _esperar(0.8)
	var preparada := get_tree().current_scene
	comprobar(SesionLAN.cargando and not SesionLAN.en_partida and get_tree().paused and preparada._duracion_partida == 0.0 and preparada.contador_denuncias == 0, "Un equipo lento mantiene relojes, casos y controles detenidos")
	SesionLAN._comenzar(SesionLAN.ronda - 1)
	comprobar(SesionLAN.cargando and not SesionLAN.en_partida, "Un inicio atrasado no libera la barrera de carga")
	CargaEscenas.set_process(true)

@rpc("authority", "call_remote", "reliable")
func _orden(orden: String, datos: Dictionary = {}) -> void:
	var resultado := {"ok": true}
	match orden:
		"radio": resultado = {"marcas": red.senales.marcas.duplicate(true), "abierta": red.senales._panel.visible, "disponible": red.senales.disponible()}
		"abrir_radio": red.senales.alternar()
		"radio_vieja":
			var anterior: Dictionary = red.senales.marcas.duplicate(true)
			SesionLAN._evento(SesionLAN.ronda - 1, "senal", {"numero": 99999, "jugador": 1, "tipo": "ayuda", "posicion": Vector3.ZERO, "texto": "VIEJA"})
			resultado = {"ok": anterior == red.senales.marcas}
		"desconectar_en_carga": _desconectar_en_carga()
		"movimiento_antiguo":
			red._remotos.erase(1)
			SesionLAN._movimiento_confirmado(SesionLAN.ronda - 1, 1, {"pos": Vector3.ZERO, "vel": Vector3.ZERO, "tick": Time.get_ticks_msec() + 10000})
			resultado = {"ok": not red._remotos.has(1)}
		"personajes": resultado = {"ok": _personajes_correctos()}
		"colision": resultado = {"ok": await _probar_colision()}
		"capturar": await _capturar("cliente")
		"cerrar_guia": MenuGlobal.cerrar_ayuda()
		"estado_guia": resultado = _estado_guia()
		"repetir_confirmacion_guia":
			_pulsar_escape_guia()
			SesionLAN._confirmar_tutorial.rpc_id(1, SesionLAN.ronda, SesionLAN.tutorial_actual)
		"confirmacion_guia_antigua":
			SesionLAN._confirmar_tutorial.rpc_id(1, SesionLAN.ronda - 1, SesionLAN.tutorial_actual)
			SesionLAN._confirmar_tutorial.rpc_id(1, SesionLAN.ronda, &"otro_tutorial")
		"preparar_reinicio": MenuGlobal.omitir_tutorial_siguiente_partida = true
		"estado_reintento": resultado = {"votos": SesionLAN.votos_reintento.size()}
		"estado_cinematica": resultado = {"finalizada": oficina.final_partida._relevo_finalizado, "salieron": not red.jugadores[1].visible and not red.jugadores[SesionLAN.id_local()].visible, "reintentar": oficina.final_partida._boton_reintentar.text}
		"votar_reintento": SesionLAN.votar_reintento()
		"nueva_ronda":
			red = SesionLAN.puente
			oficina = red.oficina
			resultado = {"saldo": oficina.sistema_despacho.puntuacion.puntos, "activo_local": oficina.sistema_despacho.esta_activo(SesionLAN.id_local()), "aportes": oficina.sistema_despacho.aportes_jugadores}
		"mover":
			oficina.jugador.global_position = datos.pos
			oficina.jugador.velocity = Vector3.ZERO
			await _esperar(0.35)
			resultado = {"ok": true, "pos": oficina.jugador.global_position}
		"tutoriales":
			for evento in ["apagon", "terremoto", "incendio", "inundacion", "lava", "hielo"]:
				oficina.tutoriales_vistos[StringName(evento)] = true
		"minijuego":
			red.solicitar_estacion(str(datos.estacion), str(datos.caso))
			await _esperar(0.5)
			_resolver_minijuego(str(datos.estacion))
			await _esperar(0.4)
			var caso: Denuncia = oficina.sistema_despacho.arbol.buscar_por_id(str(datos.caso))
			resultado = {"ok": caso == null or caso.estaciones_completadas.has(str(datos.estacion)), "aviso_tarea": oficina.panel_despacho.efecto_tarea.caso_id}
		"charcos": resultado = {"charcos": oficina.evento_lava.charcos}
		"rociar":
			var foco: Node3D = oficina.evento_incendio.focos[int(datos.foco)]
			var hacia: Vector3 = foco.global_position - oficina.jugador.global_position
			oficina.jugador.visual.rotation.y = atan2(hacia.x, hacia.z)
			await _esperar(0.4)
			for i in 70:
				await _pedir("rociar", {"foco": int(datos.foco), "delta": 0.1})
				await _esperar(0.1)
				if foco.apagado >= 1.0: break
			resultado = {"ok": foco.apagado >= 1.0}
		"retener_sismo":
			oficina.evento_terremoto.preparacion_terminada.disconnect(red._preparacion_sismo_terminada)
		"liberar_sismo":
			oficina.evento_terremoto.preparacion_terminada.connect(red._preparacion_sismo_terminada)
			red._preparacion_sismo_terminada(true)
		"estado_sismo": resultado = {"preparando": oficina.evento_terremoto.preparando, "listo": oficina.evento_terremoto.plan_preparado, "activo": oficina.evento_terremoto.activo, "tiempo": oficina.evento_terremoto.tiempo, "plan": oficina.evento_terremoto.exportar_trazado_red()}
		"cerrar_sismo": oficina.evento_terremoto._cerrar()
		"trazado": resultado = oficina.evento_terremoto.exportar_trazado_red()
		"accion": resultado = await _pedir(str(datos.tipo), datos.get("datos", {}))
		"taza_remota":
			var taza = red._tazas_remotas.get(1)
			resultado = {"ok": true, "indice": taza.get_meta("indice_taza", -1) if is_instance_valid(taza) else -1}
		"apuntar": resultado = await _apuntar_a_estacion(str(datos.estacion))
		"inspeccionar":
			var evento := ""
			if oficina.evento_apagon.estado != 0: evento = "apagon"
			for tipo in ["incendio", "inundacion", "lava", "hielo", "terremoto"]:
				if oficina.get("evento_" + tipo).activo: evento = tipo
			resultado = {"saldo": oficina.sistema_despacho.puntuacion.puntos, "casos": oficina.sistema_despacho.casos_en_proceso.size(), "hojas": red.papeles.size(), "evento": evento, "tiempo": oficina.sistema_despacho.tiempo_detenido, "activo_local": oficina.sistema_despacho.esta_activo(SesionLAN.id_local()), "final": oficina.sistema_despacho.terminada, "guia": MenuGlobal.panel_ayuda.visible}
			resultado["hud_cordura"] = [oficina.panel_despacho.calma_jugadores.filas[1].calma, oficina.panel_despacho.calma_jugadores.filas[2].calma]
			resultado["duelo"] = str(red._duelo.get("fase", ""))
			resultado["pilas"] = _pilas_visibles()
			resultado["aportes"] = oficina.sistema_despacho.aportes_jugadores
			resultado["equipo_final"] = oficina.final_partida._datos.get("equipo", [])
			var poderes: Node = oficina.get_node("MaquinaExpendedora").poderes
			resultado["audios_tiempo"] = 0
			for reproductor: AudioStreamPlayer in oficina.find_children("*", "AudioStreamPlayer", true, false):
				if reproductor.stream == poderes.SONIDO_DETENER and reproductor.playing:
					resultado.audios_tiempo += 1
			resultado["posicion_audio"] = poderes._sonido_detener.get_playback_position()
			resultado["extintores"] = 0
			resultado["extintores_recogidos"] = 0
			for unidad in oficina.evento_incendio.extintores:
				if unidad.visible: resultado.extintores += 1
				if unidad.visible and unidad.recogido: resultado.extintores_recogidos += 1
			resultado["llaves"] = 0
			for unidad in oficina.herramientas_reporte:
				if unidad.activa: resultado.llaves += 1
		"pausar": SesionLAN.pedir_pausa(bool(datos.valor))
		"terminar":
			_terminando = true
			_salir_limpio()
	_respuesta.rpc_id(1, resultado)

@rpc("any_peer", "call_remote", "reliable")
func _respuesta(resultado: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() == cliente:
		respuesta_cliente.emit(resultado)

func _preparar_sismo_de_prueba() -> bool:
	for semilla: int in [8762, 14, 927, 951, 1307, 2026, 13, 114]:
		oficina.temporizador_eventos.stop()
		if not red.iniciar_evento("terremoto"): return false
		oficina.evento_terremoto._azar.seed = semilla
		while oficina.evento_terremoto.preparando and not oficina.evento_terremoto.plan_preparado:
			await _esperar(0.05)
		if oficina.evento_terremoto.plan_preparado:
			var presupuesto = oficina.evento_terremoto._presupuesto
			print("[LAN LOTES] media_us=", float(presupuesto.total_lotes_usec) / presupuesto.cuadros, " sobre4ms=", presupuesto.lotes_sobre_4ms, "/", presupuesto.cuadros, " max_us=", presupuesto.maximo_lote_usec)
			return true
		print("[LAN DISTRIBUCION] semilla=", semilla, " rechazo=", oficina.evento_terremoto.rechazo_preparacion)
	return false


func _probar_barrera_terremoto() -> void:
	oficina.tutoriales_vistos[&"terremoto"] = true
	await _al_cliente("tutoriales")
	oficina.temporizador_eventos.stop()
	oficina.temporizador_denuncias.stop()
	oficina.temporizador_bloqueos.stop()
	oficina.bloqueos_iniciados = true
	await _mover_host(Vector3(-2.25, 0.4, 7.1))
	await _mover_cliente(Vector3(-1.5, 0.4, 7.1))
	oficina.generador_aleatorio.seed = 1414
	oficina._cambiar_bloqueo_temporal()
	oficina.temporizador_bloqueos.stop()
	await _probar_distribuciones_reales()
	var posicion: Vector3 = oficina.jugador.global_position
	await _al_cliente("retener_sismo")
	comprobar(await _preparar_sismo_de_prueba(), "Se acepta la preparación LAN sin iniciar el reloj")
	var r: Dictionary = {}
	while not r.get("listo", false):
		if not oficina.evento_terremoto.preparando:
			comprobar(false, "La distribución LAN debe producir un plan válido: " + oficina.evento_terremoto.rechazo_preparacion)
			await _al_cliente("terminar")
			_terminando = true
			await _finalizar_prueba(1)
			return
		await _esperar(0.1)
		r = await _al_cliente("estado_sismo")
	comprobar(oficina.evento_terremoto.plan_preparado and not oficina.evento_terremoto.activo and not r.activo and r.tiempo == 0.0, "Ambos montajes esperan el acuse del mismo plan")
	var plan: Dictionary = oficina.evento_terremoto.exportar_trazado_red()
	comprobar(plan == r.plan, "El cliente monta exactamente el plan del anfitrión")
	var rechazo := await _pedir("sismo_listo", {"plan_id": red._sismo_pendiente.plan_id - 1, "huella": red._sismo_pendiente.huella})
	comprobar(not rechazo.ok, "Un acuse atrasado no libera la barrera")
	rechazo = await _pedir("sismo_listo", {"plan_id": red._sismo_pendiente.plan_id, "huella": 0})
	comprobar(not rechazo.ok, "Un plan distinto no libera la barrera")
	var forma: Dictionary = plan.formas[0]
	oficina.jugador.global_position = Vector3(forma.centro.x, posicion.y, forma.centro.y)
	await _al_cliente("liberar_sismo")
	await _esperar(0.4)
	r = await _al_cliente("estado_sismo")
	comprobar(not oficina.evento_terremoto.preparando and not oficina.evento_terremoto.activo and not r.preparando and not r.activo, "El anfitrión cancela en ambos equipos si cambia una posición protegida")
	oficina.temporizador_eventos.stop()
	await _mover_host(posicion)
	await _al_cliente("retener_sismo")
	comprobar(await _preparar_sismo_de_prueba(), "Se puede preparar otro plan tras cancelar")
	r = {}
	while not r.get("listo", false):
		if not oficina.evento_terremoto.preparando:
			comprobar(false, "La distribución LAN debe producir un plan válido: " + oficina.evento_terremoto.rechazo_preparacion)
			await _al_cliente("terminar")
			_terminando = true
			await _finalizar_prueba(1)
			return
		await _esperar(0.1)
		r = await _al_cliente("estado_sismo")
	SesionLAN.pedir_pausa(true)
	await _esperar(0.2)
	await _al_cliente("liberar_sismo")
	await _esperar(0.3)
	comprobar(get_tree().paused and not oficina.evento_terremoto.activo, "Los acuses durante pausa no adelantan el aviso")
	SesionLAN.pedir_pausa(false)
	await _esperar(0.5)
	r = await _al_cliente("estado_sismo")
	comprobar(oficina.evento_terremoto.activo and r.activo and not r.preparando, "Solo la autorización del anfitrión inicia ambos avisos")
	comprobar(r.plan == oficina.evento_terremoto.exportar_trazado_red(), "La autorización conserva el mismo plan")
	comprobar(absf(float(r.tiempo) - oficina.evento_terremoto.tiempo) < 0.3, "Ambos equipos conservan el reloj del aviso")
	oficina.evento_terremoto._cerrar()
	await _al_cliente("cerrar_sismo")
	print("[LAN TERREMOTO] %d comprobaciones, %d fallos" % [comprobaciones, fallos])
	await _al_cliente("terminar")
	while SesionLAN.activa: await _esperar(0.1)
	_terminando = true
	await _finalizar_prueba(1 if fallos else 0)


func _probar_distribuciones_reales() -> void:
	var evento = oficina.evento_terremoto
	var herramientas: Array[Vector3] = []
	var accesos: Array[Vector3] = []
	for herramienta in oficina.herramientas_reporte: herramientas.append(herramienta.global_position)
	for acceso in get_tree().get_nodes_in_group("accesos_navegacion"): accesos.append(acceso.global_position)
	for semilla: int in [8762, 14, 927, 951, 1307, 2026, 13, 114]:
		oficina.generador_aleatorio.seed = semilla
		oficina._cambiar_bloqueo_temporal()
		oficina.temporizador_bloqueos.stop()
		evento._azar.seed = semilla
		var aceptado: bool = evento.iniciar(oficina.grafo_piso, oficina.jugador, oficina.bloqueos_visuales, Rect2(), true)
		if aceptado: aceptado = await evento.preparacion_terminada
		comprobar(aceptado, "La distribución LAN real admite la semilla %d" % semilla)
		if aceptado:
			comprobar(evento.validar_plan_actual() and evento._trazado.size() >= 10 and evento.escombros.size() >= 14, "El plan conserva mínimos, jugadores y todos los accesos reales")
			evento.cancelar_preparacion()
		await _esperar(.05)
	for i in herramientas.size(): comprobar(herramientas[i] == oficina.herramientas_reporte[i].global_position, "La prueba no reubica herramientas")
	var indice := 0
	for acceso in get_tree().get_nodes_in_group("accesos_navegacion"):
		comprobar(accesos[indice] == acceso.global_position, "La prueba conserva el acceso real")
		indice += 1


func _probar_duelo_y_cordura() -> void:
	var despacho: SistemaDespacho = oficina.sistema_despacho
	comprobar(oficina.emotes_permitidos(), "La oficina habilita emotes fuera de eventos")
	despacho.perder_calma(25, &"prueba", cliente)
	red.publicar()
	await _esperar(0.4)
	var filas: Dictionary = oficina.panel_despacho.calma_jugadores.filas
	comprobar(filas[1].calma == 100 and filas[2].calma == 75, "El anfitrión ve la cordura separada en ambas filas")
	var remoto := await _al_cliente("inspeccionar")
	comprobar(remoto.hud_cordura == [100, 75], "El invitado ve la cordura separada en ambas filas")
	despacho.recuperar_calma(25, cliente)
	despacho.perder_calma(20, &"prueba", 1)
	red.publicar()
	await _esperar(0.4)
	comprobar(filas[1].calma == 80 and filas[2].calma == 100, "El anfitrión ve su propia pérdida sin alterar al compañero")
	remoto = await _al_cliente("inspeccionar")
	comprobar(remoto.hud_cordura == [80, 100], "El invitado con 100 ve la cordura real del anfitrión")
	var respuesta_duelo := await _pedir("duelo_kamehameha")
	comprobar(respuesta_duelo.get("ok", false) and red._duelo.get("fase") == "espera", "El primer jugador invita al duelo")
	respuesta_duelo = await _al_cliente("accion", {"tipo": "duelo_kamehameha"})
	comprobar(respuesta_duelo.get("ok", false) and red._duelo.get("fase") == "choque", "El segundo jugador inicia el choque")
	await _esperar(0.3)
	remoto = await _al_cliente("inspeccionar")
	comprobar(remoto.duelo == "choque", "El choque aparece también en el invitado")
	red._terminar_duelo(0)
	await _esperar(0.2)
	comprobar(red._duelo.is_empty(), "El duelo se cierra sin dejar estado pendiente")
	oficina.tutoriales_vistos[&"apagon"] = true
	await _al_cliente("tutoriales")
	comprobar(red.iniciar_evento("apagon"), "Se inicia el apagón para bloquear los emotes")
	await _esperar(0.3)
	comprobar(not oficina.emotes_permitidos(), "Los emotes quedan deshabilitados durante un evento")
	respuesta_duelo = await _pedir("duelo_kamehameha")
	comprobar(not respuesta_duelo.get("ok", true), "El duelo se rechaza durante un evento")
	print("[LAN DUELO] %d comprobaciones, %d fallos" % [comprobaciones, fallos])
	await _al_cliente("terminar")
	while SesionLAN.activa:
		await _esperar(0.1)
	_terminando = true
	await _finalizar_prueba(1 if fallos else 0)


func _probar_senales() -> void:
	for reloj in [oficina.temporizador_denuncias, oficina.temporizador_eventos, oficina.temporizador_bloqueos]: reloj.stop()
	var r := await _pedir("senal", {"tipo": "estacion", "objetivo": "evidencias", "posicion": Vector3(999, 999, 999)})
	await _esperar(.2)
	var cliente_radio := await _al_cliente("radio")
	comprobar(r.ok and cliente_radio.marcas.has(1) and red.senales.marcas.has(1), "Una estación del anfitrión se marca en ambos equipos")
	comprobar(cliente_radio.marcas[1].posicion == red._buscar_estacion("evidencias").global_position, "La autoridad ignora posiciones enviadas por el cliente")
	r = await _pedir("senal", {"tipo": "ayuda"})
	comprobar(not r.ok, "La radio limita la frecuencia por jugador")
	r = await _al_cliente("accion", {"tipo": "senal", "datos": {"tipo": "ayuda"}})
	await _esperar(.2)
	comprobar(r.ok and red.senales.marcas.has(cliente) and red.senales.marcas[cliente].texto == "NECESITO AYUDA", "El compañero puede pedir ayuda sin esperar el enfriamiento del anfitrión")
	await _esperar(2.1)
	r = await _pedir("senal", {"tipo": "estacion", "objetivo": "../../Mundo"})
	comprobar(not r.ok, "La radio rechaza estaciones desconocidas")
	r = await _pedir("senal", {"tipo": "hoja"})
	comprobar(not r.ok, "No se señala una hoja inexistente")
	r = await _pedir("senal", {"tipo": "reparar"})
	comprobar(not r.ok, "Sin emergencia no se anuncia una reparación ficticia")
	r = await _pedir("senal", {"tipo": "desconocida"})
	comprobar(not r.ok, "Se rechazan opciones ajenas a la radio")
	var caso := Denuncia.new()
	caso.id = "RADIO-HOJA"
	caso.protocolo_estaciones.assign(["evidencias"])
	caso.tiempo_limite_segundos = 300
	red.despacho.recibir_denuncia(caso)
	red.despacho.iniciar_denuncia_prioritaria()
	var papel = red._crear_papel(caso.id)
	papel.freeze = true
	papel.global_position = oficina.jugador.global_position + Vector3(.2, .05, 0)
	red.despacho.establecer_portador(caso.id, 0)
	red.publicar()
	r = await _pedir("senal", {"tipo": "hoja"})
	await _esperar(.2)
	cliente_radio = await _al_cliente("radio")
	comprobar(r.ok and cliente_radio.marcas[1].caso == caso.id, "La hoja cercana conserva su ID en ambos equipos")
	var vieja := await _al_cliente("radio_vieja")
	comprobar(vieja.ok, "Una señal de otra ronda no aparece en pantalla")
	var raton_previo := Input.mouse_mode
	var tecla_radio := InputEventKey.new()
	tecla_radio.physical_keycode = KEY_R
	tecla_radio.keycode = KEY_R
	tecla_radio.pressed = true
	Input.parse_input_event(tecla_radio)
	await _esperar(.1)
	tecla_radio.pressed = false
	Input.parse_input_event(tecla_radio)
	comprobar(red.senales._panel.visible and oficina.jugador.radio_abierta and not get_tree().paused, "La radio abre sin pausar la partida compartida")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await _esperar(.1)
	escape.pressed = false
	Input.parse_input_event(escape)
	comprobar(not red.senales._panel.visible and not oficina.jugador.radio_abierta and not get_tree().paused and Input.mouse_mode == raton_previo, "Escape cierra la radio, devuelve el cursor y no abre la pausa")
	var mando_anterior: int = ControladorInterfaz.dispositivo_mando
	ControladorInterfaz.dispositivo_mando = 0
	var boton_radio := InputEventJoypadButton.new()
	boton_radio.device = 0
	boton_radio.button_index = JOY_BUTTON_B
	boton_radio.pressed = true
	Input.parse_input_event(boton_radio)
	await _esperar(.1)
	comprobar(red.senales._panel.visible and not get_tree().paused, "La entrada B del mando abre la radio en LAN")
	boton_radio.pressed = false
	Input.parse_input_event(boton_radio)
	await _esperar(.05)
	boton_radio = boton_radio.duplicate()
	boton_radio.pressed = true
	Input.parse_input_event(boton_radio)
	await _esperar(.1)
	boton_radio.pressed = false
	Input.parse_input_event(boton_radio)
	ControladorInterfaz.dispositivo_mando = mando_anterior
	comprobar(not red.senales._panel.visible and not get_tree().paused, "B cierra la radio sin abrir otro panel")
	red.senales.alternar()
	Input.action_press(oficina.jugador.JUMP)
	red.senales.enviar("ayuda")
	await _esperar(.1)
	comprobar(oficina.jugador.is_on_floor() and oficina.jugador.velocity.y <= 0.0, "Confirmar la radio con la entrada de salto no hace saltar al personaje")
	Input.action_release(oficina.jugador.JUMP)
	red.senales.alternar()
	MenuGlobal.abrir_pausa()
	await _esperar(.2)
	comprobar(not red.senales._panel.visible and not oficina.jugador.radio_abierta, "La pausa cierra la radio y libera el movimiento local")
	var restante: float = red.senales.marcas[1].restante
	await _esperar(.4)
	comprobar(is_equal_approx(restante, red.senales.marcas[1].restante), "Las señales conservan su tiempo durante la pausa")
	r = await _pedir("senal", {"tipo": "ayuda"})
	comprobar(not r.ok, "El servidor rechaza señales durante la pausa")
	MenuGlobal.reanudar_juego()
	await _esperar(2.2)
	oficina.tutoriales_vistos[&"apagon"] = true
	await _al_cliente("tutoriales")
	comprobar(red.iniciar_evento("apagon"), "Se inicia una emergencia para probar la radio")
	await _esperar(.3)
	r = await _pedir("senal", {"tipo": "reparar"})
	await _esperar(.2)
	cliente_radio = await _al_cliente("radio")
	comprobar(r.ok and cliente_radio.marcas[1].objetivo == "apagon", "Se puede anunciar la reparación durante un evento")
	SesionLAN.difundir("reparado", {"objetivo": "apagon"})
	await _esperar(6.2)
	comprobar(red.senales.marcas.is_empty(), "Las marcas caducan y no se acumulan en pantalla")
	if OS.get_cmdline_user_args().has("--capturas"):
		r = await _pedir("senal", {"tipo": "ayuda"})
		await _esperar(.2)
		await _capturar("radio")
		red.senales.alternar()
		await _esperar(.2)
		await _capturar("radio_menu")
		red.senales.cerrar()
	red.despacho.perder_calma(100, &"prueba", 1)
	r = await _pedir("senal", {"tipo": "ayuda"})
	comprobar(not r.ok, "Un jugador eliminado no puede emitir señales")
	print("[LAN RADIO] %d comprobaciones, %d fallos" % [comprobaciones, fallos])
	await _al_cliente("terminar")
	while SesionLAN.activa: await _esperar(.1)
	_terminando = true
	await _finalizar_prueba(1 if fallos else 0)


func _estado_guia() -> Dictionary:
	var panel := MenuGlobal.panel_ayuda
	return {"visible": panel.is_visible_in_tree(), "pausado": get_tree().paused,
		"contador": panel.contador_confirmaciones.text, "contador_visible": panel.contador_confirmaciones.is_visible_in_tree(),
		"confirmado": panel.boton_cerrar.disabled, "pista": panel.pista.text}

func _pulsar_escape_guia() -> void:
	var tecla := InputEventKey.new()
	tecla.keycode = KEY_ESCAPE
	tecla.physical_keycode = KEY_ESCAPE
	tecla.pressed = true
	get_viewport().push_input(tecla)
	tecla.pressed = false
	get_viewport().push_input(tecla)

func _probar_confirmaciones_tutorial(primero_anfitrion: bool) -> void:
	var panel := MenuGlobal.panel_ayuda
	var remoto := await _al_cliente("estado_guia")
	comprobar(panel.contador_confirmaciones.text == "(0/2)" and remoto.contador == "(0/2)", "Cada tutorial empieza con cero confirmaciones en ambos equipos")
	comprobar(panel.contador_confirmaciones.is_visible_in_tree() and remoto.contador_visible and not panel.boton_cerrar.disabled and not remoto.confirmado, "Ambos pueden leer y confirmar con el contador visible")
	await _al_cliente("confirmacion_guia_antigua")
	await _esperar()
	comprobar(panel.contador_confirmaciones.text == "(0/2)", "Se rechazan confirmaciones de otra ronda o de otro tutorial")
	var segundos: float = oficina.temporizador_denuncias.time_left
	if primero_anfitrion:
		panel.boton_cerrar.pressed.emit()
	else:
		await _al_cliente("cerrar_guia")
	await _esperar()
	remoto = await _al_cliente("estado_guia")
	comprobar(panel.contador_confirmaciones.text == "(1/2)" and remoto.contador == "(1/2)", "La primera confirmación actualiza a (1/2) en ambos equipos")
	comprobar(panel.is_visible_in_tree() and remoto.visible and get_tree().paused and remoto.pausado, "Las dos guías permanecen visibles y el mundo sigue pausado")
	comprobar(panel.boton_cerrar.disabled == primero_anfitrion and remoto.confirmado != primero_anfitrion, "Solo se desactiva el botón del jugador que confirmó")
	comprobar((panel.pista.text if primero_anfitrion else str(remoto.pista)).contains("Esperando a tu compañero"), "Quien confirma ve por qué está esperando")
	if primero_anfitrion:
		_pulsar_escape_guia()
		panel.boton_cerrar.pressed.emit()
		SesionLAN.confirmar_tutorial(SesionLAN.tutorial_actual)
	else:
		await _al_cliente("repetir_confirmacion_guia")
	await _esperar()
	remoto = await _al_cliente("estado_guia")
	comprobar(panel.contador_confirmaciones.text == "(1/2)" and remoto.contador == "(1/2)" and get_tree().paused, "Escape y confirmaciones repetidas no duplican el voto ni reanudan")
	comprobar(is_equal_approx(segundos, oficina.temporizador_denuncias.time_left), "El reloj de casos no avanza mientras falta un jugador")
	if primero_anfitrion:
		await _al_cliente("cerrar_guia")
	else:
		panel.boton_cerrar.pressed.emit()
	await _esperar()
	remoto = await _al_cliente("estado_guia")
	comprobar(panel.contador_confirmaciones.text == "(2/2)" and remoto.contador == "(2/2)", "Se registran exactamente dos confirmaciones")
	comprobar(not panel.visible and not remoto.visible and not get_tree().paused and not remoto.pausado, "Al confirmar ambos se cierran las guías y se reanuda en los dos equipos")
	MenuGlobal.abrir_pausa()
	MenuGlobal.abrir_tutorial()
	comprobar(not panel.contador_confirmaciones.visible and not panel.boton_cerrar.disabled, "Consultar una guía desde pausa no conserva el contador ni el botón desactivado")
	MenuGlobal.cerrar_ayuda()
	MenuGlobal.reanudar_juego()
	await _esperar()

func _comprobar_personajes() -> void:
	comprobar(_personajes_correctos(), "Anfitrión azul e invitado de relevo, con sus rigs completos en el servidor")
	var resultado := await _al_cliente("personajes")
	comprobar(resultado.ok, "El cliente ve los mismos policías y controla el de relevo")

func _personajes_correctos() -> bool:
	if red.jugadores.size() != 2 or red.jugadores.get(SesionLAN.id_local()) != oficina.jugador:
		return false
	var colores: Array[Color] = []
	for id: int in red.jugadores:
		var jugador: Player = red.jugadores[id]
		var modelo := jugador.get_node("Visual/Modelo")
		var esperado := "res://Personajes/PoliciaAzul/ModeloAzul.tscn" if id == 1 else "res://Personajes/PoliciaRelevo/ModeloRelevo.tscn"
		if modelo.scene_file_path != esperado or jugador.id_red != id or jugador.remoto_red != (id != SesionLAN.id_local()):
			return false
		var esqueleto := modelo.get_node("Rig/Skeleton3D")
		if not is_instance_valid(jugador.animation_player) or not modelo.is_ancestor_of(jugador.animation_player):
			return false
		if not is_instance_valid(jugador.gestos) or jugador.gestos.get_parent() != esqueleto:
			return false
		if not esqueleto.is_ancestor_of(jugador.anclaje_papel()) or not esqueleto.is_ancestor_of(jugador.anclaje_taza()):
			return false
		var chaqueta := esqueleto.get_node("Chaqueta") as MeshInstance3D
		colores.append((chaqueta.get_active_material(0) as StandardMaterial3D).albedo_color)
		if modelo.variante != (0 if id == 1 else 1):
			return false
		if esqueleto.has_node("AcabadoUniforme/Radio") != (id != 1):
			return false
		if esqueleto.has_node("AcabadoUniforme/NudoPanuelo") != (id != 1):
			return false
	return not colores[0].is_equal_approx(colores[1]) and oficina.get_node("Gameplay/Camera3D").objetivo == oficina.jugador and oficina.evento_apagon.jugador == oficina.jugador

func _probar_colision() -> bool:
	# Dos cuerpos con las escenas y máscaras reales, aislados del transporte
	# para que un paquete de movimiento no altere la geometría durante la prueba.
	var local: Player = (red.POLICIA if SesionLAN.es_anfitrion() else red.POLICIA_RELEVO).instantiate()
	var remoto: Player = (red.POLICIA_RELEVO if SesionLAN.es_anfitrion() else red.POLICIA).instantiate()
	oficina.add_child(local)
	oficina.add_child(remoto)
	local.set_physics_process(false)
	remoto.set_physics_process(false)
	red._preparar_colision(local)
	red._preparar_colision(remoto)
	local.collision_mask = oficina.jugador.collision_mask
	remoto.collision_mask = oficina.jugador.collision_mask
	local.global_position = Vector3(0, 20, 5)
	remoto.global_position = Vector3(1, 20, 5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var choque := KinematicCollision3D.new()
	var bloquea := local.test_move(local.global_transform, Vector3(2, 0, 0), choque) and choque.get_collider() == remoto
	print("[LAN COLISION] máscara=%d contacto=%s" % [local.collision_mask, bloquea])
	red._mover_cuerpo_remoto(remoto, Vector3(-1, 20, 5))
	print("[LAN COLISION] posición remota tras barrido=%s" % remoto.global_position)
	bloquea = bloquea and remoto.global_position.x > local.global_position.x
	var capa := remoto.collision_layer
	remoto.collision_layer = 0
	await get_tree().physics_frame
	bloquea = bloquea and not local.test_move(local.global_transform, Vector3(2, 0, 0))
	remoto.collision_layer = capa
	local.queue_free()
	remoto.queue_free()
	return bloquea

func _probar_llaves(resolver := true) -> void:
	var caso := Denuncia.new()
	caso.id = "LAN-DOS-LLAVES"
	caso.tiempo_limite_segundos = 300
	caso.protocolo_estaciones.assign(["reporte"])
	var probabilidad: float = oficina.probabilidad_atasco_reporte
	oficina.probabilidad_atasco_reporte = 1.0
	oficina.sistema_despacho.recibir_denuncia(caso)
	await _mover_host(oficina.computador.global_position + Vector3(0, 0, 1))
	await _pedir("tomar")
	await _mover_host(red._buscar_estacion("reporte").global_position + Vector3(0, 0, 0.6))
	var r := await _pedir("estacion", {"caso": caso.id, "estacion": "reporte"})
	comprobar(r.get("tarea", "") == "atasco", "El atasco genera las herramientas")
	await _esperar()
	r = await _al_cliente("inspeccionar")
	comprobar(int(r.llaves) == 2 and oficina.herramientas_reporte.size() == 2, "Dos llaves recogibles en ambos equipos")
	await _mover_host(oficina.herramientas_reporte[0].global_position + Vector3(0, 0, 0.5))
	await _mover_cliente(oficina.herramientas_reporte[1].global_position + Vector3(0, 0, 0.5))
	r = await _pedir("herramienta", {"indice": 0})
	comprobar(r.ok, "El anfitrión recoge la primera llave")
	r = await _al_cliente("accion", {"tipo": "herramienta", "datos": {"indice": 0}})
	comprobar(not r.ok, "La misma llave no tiene dos portadores")
	r = await _pedir("herramienta", {"indice": 1})
	comprobar(not r.ok, "Un jugador no puede acaparar ambas llaves")
	r = await _al_cliente("accion", {"tipo": "herramienta", "datos": {"indice": 1}})
	comprobar(r.ok and red.reservas["estacion:reporte"].herramientas == [1, cliente], "Cada jugador recoge una llave independiente")
	if not resolver:
		oficina.probabilidad_atasco_reporte = probabilidad
		return
	await _mover_host(red._buscar_estacion("reporte").global_position + Vector3(0, 0, 0.6))
	r = await _pedir("estacion", {"caso": caso.id, "estacion": "reporte"})
	comprobar(r.get("tarea", "") == "completada", "La llave permite reparar el caso reservado")
	await _esperar()
	r = await _al_cliente("inspeccionar")
	comprobar(int(r.llaves) == 0 and not red.reservas.has("estacion:reporte"), "Resolver el atasco limpia ambas llaves")
	oficina.probabilidad_atasco_reporte = probabilidad

func _pilas_visibles() -> int:
	var cantidad := 0
	for pila in oficina.get_node("PresionDespacho").pilas:
		if pila.visible:
			cantidad += 1
	return cantidad


func _apuntar_a_estacion(id: String) -> Dictionary:
	var jugador: Player = oficina.jugador
	var mesa: Node3D = red._buscar_estacion(id)
	var inicio: Vector3 = oficina.grafo_piso.celda_a_posicion(GrafoPiso.DESTINOS[id])
	# El traslado anterior al computador puede dejar al actor encima de un cajón.
	# Aquí se consulta la estación desde la altura del piso jugable.
	inicio.y = oficina.evento_hielo.PISO + .025
	jugador.set_physics_process(false)
	for dx: float in [0.0, .4, -.4]:
		var destino := mesa.to_global(Vector3(dx, 0, 0))
		destino.y = inicio.y
		jugador.visual.rotation.y = atan2(destino.x - inicio.x, destino.z - inicio.z)
		for i in 61:
			jugador.global_position = inicio.lerp(destino, i / 60.0)
			if jugador.obtener_objetivo_interaccion() == mesa:
				break
		if jugador.obtener_objetivo_interaccion() == mesa:
			break
	var camara: Camera3D = oficina.get_node("Gameplay/Camera3D")
	camara.set_physics_process(false)
	camara.global_position = jugador.global_position + camara.offset
	await _esperar(.15)
	var guia = oficina.guia_estacion
	return {"ok": guia.objetivo == oficina.respuestas_mesas[id].modelo_original and guia.tarjeta.is_visible_in_tree(), "texto": guia.tecla.text}


func _probar_oficina_compartida(caso_host: String, caso_cliente: String) -> void:
	var estado := await _al_cliente("inspeccionar")
	comprobar(_pilas_visibles() == 2 and int(estado.pilas) == 2, "Las dos oficinas muestran ambos expedientes en proceso")
	var local := await _apuntar_a_estacion("bienestar")
	var remoto := await _al_cliente("apuntar", {"estacion": "evidencias"})
	comprobar(local.ok and local.texto.ends_with("Atender caso") and remoto.ok and remoto.texto.ends_with("Clasificar evidencias"), "Cada policía ve el contorno y el verbo de su propia estación")
	oficina.sistema_despacho.resolver_denuncia(caso_host)
	await _esperar(.5)
	estado = await _al_cliente("inspeccionar")
	comprobar(_pilas_visibles() == 1 and int(estado.pilas) == 1, "Resolver retira una pila en ambos equipos")
	oficina.sistema_despacho.vencer_denuncia(caso_cliente)
	await _esperar(.4)
	estado = await _al_cliente("inspeccionar")
	comprobar(_pilas_visibles() == 0 and int(estado.pilas) == 0, "El vencimiento deja las dos oficinas despejadas")
	print("[OFICINA LAN] %d comprobaciones, %d fallos" % [comprobaciones, fallos])
	await _al_cliente("terminar")
	while SesionLAN.activa:
		await _esperar(.1)
	_terminando = true
	await _finalizar_prueba(1 if fallos else 0)


func _salir_limpio() -> void:
	await _esperar(0.2)
	SesionLAN.cerrar("Prueba de desconexión terminada.")
	await _esperar(2.0)
	await _finalizar_prueba(0)

func _desconectar_en_carga() -> void:
	while not (SesionLAN.cargando and CargaEscenas._fase == "preparacion"):
		await get_tree().process_frame
	SesionLAN.cerrar("Prueba de desconexión durante preparación.")
	while get_tree().current_scene == null or get_tree().current_scene.scene_file_path != CargaEscenas.MENU or CargaEscenas.activa:
		await get_tree().process_frame
	comprobar(not get_tree().paused and get_tree().get_nodes_in_group("gestor_partida").is_empty(), "Desconectar durante preparación recupera el menú del cliente")
	_terminando = true
	await _finalizar_prueba(1 if fallos else 0)

func _finalizar_prueba(codigo: int) -> void:
	# Dar al mezclador tiempo real para liberar el MP3 del menú antes de cerrar.
	MenuGlobal.musica_menu.stop()
	await _esperar(0.3)
	get_tree().quit(codigo)

func _capturar(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/lan_partida_%s.png" % nombre)

func _resolver_minijuego(estacion: String) -> void:
	if estacion == "evidencias":
		var panel: Control = oficina.clasificador_evidencias
		while panel.visible and not panel.objetivos.is_empty():
			panel.seleccion = panel.papeles.find(panel.objetivos[panel.archivados])
			panel._archivar()
	elif estacion == "verificacion":
		var panel: Control = oficina.escaner_verificacion
		panel.marcador = panel.zona_centro
		panel._detener()

func _probar_colores_cafe() -> void:
	var despacho: SistemaDespacho = oficina.sistema_despacho
	var anterior_host := despacho.obtener_cordura(1)
	var anterior_cliente := despacho.obtener_cordura(cliente)
	if red.cafes.get(cliente, false):
		await _al_cliente("accion", {"tipo": "beber"})
	# Dinero solo para estas compras; se conserva el saldo previo al terminar.
	var saldo_anterior := despacho.puntuacion.puntos
	despacho.puntuacion._puntos += 200
	await _mover_host(red._objeto("cafetera").global_position + Vector3(0.5, 0, 0.6))
	for id in [cliente, 1]:
		for indice in [0, 1]:
			oficina._duracion_partida += 60.0
			despacho.perder_calma(20, &"prueba", id)
			if id == cliente:
				await _al_cliente("accion", {"tipo": "reservar", "datos": {"objetivo": "cafetera"}})
				var compra := await _al_cliente("accion", {"tipo": "comprar", "datos": {"producto": "cafe", "indice": indice}})
				comprobar(compra.get("ok", false) and compra.get("taza", -1) == indice, "El servidor confirma el color elegido por el cliente")
				await _esperar()
				var taza = red._tazas_remotas.get(cliente)
				comprobar(is_instance_valid(taza) and taza.mesh == oficina.get_node("ZonaDescanso")._tazas[indice].mesh, "El anfitrión ve la taza correcta del cliente")
				await _al_cliente("accion", {"tipo": "beber"})
				await _al_cliente("accion", {"tipo": "liberar", "datos": {"objetivo": "cafetera"}})
			else:
				await _pedir("reservar", {"objetivo": "cafetera"})
				var compra := await _pedir("comprar", {"producto": "cafe", "indice": indice})
				comprobar(compra.get("ok", false) and compra.get("taza", -1) == indice, "El anfitrión conserva el color elegido")
				await _esperar()
				var remoto := await _al_cliente("taza_remota")
				comprobar(remoto.get("indice", -1) == indice, "El cliente ve la taza correcta del anfitrión")
				await _pedir("beber")
				await _pedir("liberar", {"objetivo": "cafetera"})
			await _esperar()
	comprobar(not red._tazas_remotas.has(cliente), "Al beber desaparece la taza remota")
	comprobar(despacho.puntuacion.puntos == saldo_anterior, "Las cuatro compras de café cobran exactamente 200 puntos compartidos")
	for id in [1, cliente]:
		var diferencia: int = (anterior_host if id == 1 else anterior_cliente) - despacho.obtener_cordura(id)
		if diferencia > 0: despacho.recuperar_calma(diferencia, id)
		elif diferencia < 0: despacho.perder_calma(-diferencia, &"prueba", id)
	red.publicar()
