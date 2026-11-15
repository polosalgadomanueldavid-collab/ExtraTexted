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
	red = SesionLAN.puente
	oficina = red.oficina
	if not SesionLAN.es_anfitrion():
		return
	await _esperar(0.6)
	comprobar(get_tree().paused and MenuGlobal.panel_ayuda.visible, "El tutorial inicial abre sin bloquear la carga")
	MenuGlobal.cerrar_ayuda()
	await _esperar()
	comprobar(get_tree().paused, "El tutorial del cliente mantiene la pausa")
	await _al_cliente("cerrar_guia")
	await _esperar()
	comprobar(red.jugadores.size() == 2 and not get_tree().paused, "Dos jugadores y barrera de carga completada")
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
	r = await _pedir("comprar", {"producto": "snack", "indice": 1})
	comprobar(r.get("ok", false) and despacho.puntuacion.puntos == 25, "Compra descuenta fondo común")
	r = await _pedir("comprar", {"producto": "snack", "indice": 0})
	comprobar(not r.get("ok", true) and despacho.puntuacion.puntos == 25, "Saldo insuficiente no entrega ni cobra")
	await _pedir("liberar", {"objetivo": "tienda"})
	# El cliente completa ambas interfaces y la resolución llega por RPC.
	for estacion in ["evidencias", "verificacion", "bienestar"]:
		await _mover_cliente(red._buscar_estacion(estacion).global_position + Vector3(0, 0, 0.6))
		r = await _al_cliente("minijuego", {"estacion": estacion, "caso": caso_cliente})
		comprobar(r.get("ok", false), "El cliente completa " + estacion + " con su interfaz")
	comprobar(despacho.puntuacion.puntos == 125 and despacho.obtener_cordura(cliente) == 85, "Resolución del cliente conserva saldo y participación")
	# Cafetera y expendedora compiten por los últimos 50 puntos en el mismo turno.
	despacho.puntuacion.gastar_puntos(75)
	await _mover_host(red._objeto("tienda").global_position + Vector3(0.5, 0, 0))
	await _pedir("reservar", {"objetivo": "tienda"})
	await _mover_cliente(red._objeto("cafetera").global_position + Vector3(0, 0, 0.6))
	r = await _al_cliente("accion", {"tipo": "reservar", "datos": {"objetivo": "cafetera"}})
	comprobar(r.get("ok", false) and red.reservas.has("tienda"), "Ambos compradores tienen una operación reservada antes de competir por el saldo")
	var compras: Array = []
	_orden.rpc_id(cliente, "accion", {"tipo": "comprar", "datos": {"producto": "cafe"}})
	SesionLAN.solicitar("comprar", {"producto": "snack", "indice": 0}, func(valor: Dictionary): compras.append(valor))
	r = await respuesta_cliente
	await _esperar()
	comprobar(compras.size() == 1 and int(compras[0].ok) + int(r.ok) == 1 and despacho.puntuacion.puntos == 0, "Compras concurrentes: se entrega y cobra un solo producto")
	comprobar(int(red.bolsillos[1][0]) + int(red.cafes[cliente]) == 1 and int(red.bolsillos[cliente][0]) == 0, "Cada producto pertenece exclusivamente a su comprador")
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
			comprobar(r.formas == oficina.evento_terremoto.exportar_trazado_red().formas, "Ambos equipos usan exactamente las mismas grietas")
		SesionLAN.difundir("avatar", {"jugador": 1, "evento": red._evento_id})
		await _esperar(0.4)
		oficina.temporizador_eventos.stop()
		r = await _al_cliente("inspeccionar")
		comprobar(str(r.evento).is_empty(), "Avatar limpia " + tipo + " en ambos")
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
	await _al_cliente("preparar_reinicio")
	MenuGlobal.omitir_tutorial_siguiente_partida = true
	SesionLAN.reiniciar()
	while not SesionLAN.en_partida:
		await _esperar(0.1)
	red = SesionLAN.puente
	oficina = red.oficina
	await _esperar(0.4)
	r = await _al_cliente("nueva_ronda")
	comprobar(oficina.sistema_despacho.puntuacion.puntos == 0 and int(r.saldo) == 0 and red.papeles.is_empty(), "Reinicio sin saldo ni hojas de la ronda anterior")
	comprobar(oficina.sistema_despacho.obtener_cordura(1) == 100 and bool(r.activo_local), "Ambos vuelven activos en la nueva ronda")
	# El primer evento debe abrir su guía en ambos, aunque el anfitrión ya haya pausado.
	oficina.bloqueos_iniciados = true
	comprobar(red.iniciar_evento("apagon"), "Inicio del primer evento con tutorial")
	await _esperar(0.5)
	r = await _al_cliente("inspeccionar")
	comprobar(bool(r.guia) and str(r.evento) == "apagon" and get_tree().paused, "Guía del evento visible y sincronizada en ambos")
	MenuGlobal.cerrar_ayuda()
	await _al_cliente("cerrar_guia")
	await _esperar(0.3)
	comprobar(not get_tree().paused, "Cerrar ambas guías reanuda el evento")
	print("[LAN RESULTADO] %d comprobaciones, %d errores" % [comprobaciones, fallos])
	await _al_cliente("terminar")
	while SesionLAN.activa or get_tree().current_scene == oficina or get_tree().current_scene == null:
		await _esperar(0.1)
	await _esperar(1.0)
	_terminando = true
	await _finalizar_prueba(1 if fallos else 0)

@rpc("authority", "call_remote", "reliable")
func _orden(orden: String, datos: Dictionary = {}) -> void:
	var resultado := {"ok": true}
	match orden:
		"colision": resultado = {"ok": await _probar_colision()}
		"capturar": await _capturar("cliente")
		"cerrar_guia": MenuGlobal.cerrar_ayuda()
		"preparar_reinicio": MenuGlobal.omitir_tutorial_siguiente_partida = true
		"nueva_ronda":
			red = SesionLAN.puente
			oficina = red.oficina
			resultado = {"saldo": oficina.sistema_despacho.puntuacion.puntos, "activo_local": oficina.sistema_despacho.esta_activo(SesionLAN.id_local())}
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
			resultado = {"ok": caso == null or caso.estaciones_completadas.has(str(datos.estacion))}
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
		"trazado": resultado = oficina.evento_terremoto.exportar_trazado_red()
		"accion": resultado = await _pedir(str(datos.tipo), datos.get("datos", {}))
		"taza_remota":
			var taza = red._tazas_remotas.get(1)
			resultado = {"ok": true, "indice": taza.get_meta("indice_taza", -1) if is_instance_valid(taza) else -1}
		"inspeccionar":
			var evento := ""
			if oficina.evento_apagon.estado != 0: evento = "apagon"
			for tipo in ["incendio", "inundacion", "lava", "hielo", "terremoto"]:
				if oficina.get("evento_" + tipo).activo: evento = tipo
			resultado = {"saldo": oficina.sistema_despacho.puntuacion.puntos, "casos": oficina.sistema_despacho.casos_en_proceso.size(), "hojas": red.papeles.size(), "evento": evento, "tiempo": oficina.sistema_despacho.tiempo_detenido, "activo_local": oficina.sistema_despacho.esta_activo(SesionLAN.id_local()), "final": oficina.sistema_despacho.terminada, "guia": MenuGlobal.panel_ayuda.visible}
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

func _probar_colision() -> bool:
	# Dos cuerpos con las escenas y máscaras reales, aislados del transporte
	# para que un paquete de movimiento no altere la geometría durante la prueba.
	var local: Player = red.POLICIA.instantiate()
	var remoto: Player = red.POLICIA.instantiate()
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

func _salir_limpio() -> void:
	await _esperar(0.2)
	SesionLAN.cerrar("Prueba de desconexión terminada.")
	await _esperar(2.0)
	await _finalizar_prueba(0)

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
