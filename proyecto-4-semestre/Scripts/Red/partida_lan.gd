extends Node
## Adaptador de la oficina: reglas compartidas en el anfitrión, presentación local.
const POLICIA := preload("res://Personajes/PoliciaAzul/Policia.tscn")
const POLICIA_RELEVO := preload("res://Personajes/PoliciaRelevo/PoliciaRelevo.tscn")
const CONTENIDO_CAFE := preload("res://Objetos/ZonaDescanso/contenido_cafe.gd")
const CAMPOS_CASO := ["id", "titulo", "descripcion_despacho", "nivel_riesgo", "hora_reporte", "tiempo_limite_segundos", "penalidad_calma", "puntaje_recompensa", "protocolo_estaciones", "estado", "motivo_perdida", "estaciones_completadas"]
var oficina: Node3D
var despacho: SistemaDespacho
var jugadores: Dictionary = {}
var papeles: Dictionary = {}
var reservas: Dictionary = {}
var proximos_snacks := {}
var bolsillos: Dictionary = {}
var cafes: Dictionary = {}
var tazas_cafe: Dictionary = {}
var _remotos: Dictionary = {}
var _ultimo_movimiento: Dictionary = {}
var _reloj := 0.0
var _envio := 0.0
var _estado := 0.0
var _listo := false
var aplicando := false
var iniciando_evento := false
var _revision := 0
var _revision_recibida := -1
var _resueltos: Dictionary = {}
var _vencidos: Dictionary = {}
var _eliminados: Dictionary = {}
var _esperas: Dictionary = {}
var _evento_id := 0
var _sismo_secuencia := 0
var _sismo_pendiente: Dictionary = {}
var _sismo_listos: Dictionary = {}
var _sismo_espera := 0.0
var _activacion_tiempo := 0
var _evento_resuelto_id := -1
var _ultima_distribucion: Array = []
var _ultimo_fuego := 0.0
var anuncio_pendiente: Array = []
var _tazas_remotas: Dictionary = {}
var _capsulas_remotas: Dictionary = {}
var _estaciones := {}
var _casos_recibidos := {}
var _estado_enviado := {}
var _estado_recibido := {}
var _base_recibida := 0
var _finales_pendientes: Array = []
var _numero_final := 0
var _ultimo_final := 0
var bytes_estado := 0
var snapshots_completos := 0
var snapshots_delta := 0
var _hud_previo := {}
var _contexto_previo: Array = []
var _duelo := {}
var _duelo_ultimo_pulso := {}
var _duelo_aviso: Label

func configurar(mundo: Node3D) -> void:
	oficina = mundo
	oficina.evento_terremoto.preparacion_terminada.connect(_preparacion_sismo_terminada)
	despacho = oficina.sistema_despacho
	for estacion in oficina.find_children("*", "Estacion", true, false):
		_estaciones[estacion.estacion_id] = estacion
	process_mode = Node.PROCESS_MODE_ALWAYS
	var ids: Array = SesionLAN.participantes.keys()
	ids.sort()
	despacho.configurar_jugadores(ids, SesionLAN.id_local())
	despacho.autoridad = SesionLAN.es_anfitrion()
	despacho.solicitar_cambio = SesionLAN.solicitar
	var titulo_saldo := oficina.panel_despacho.get_node("Contenido/Puntuacion/Detalle/Cabecera/Titulo") as Label
	titulo_saldo.text = "SALDO DEL EQUIPO"
	titulo_saldo.add_theme_font_size_override("font_size", 15)
	for id: int in ids:
		var jugador: Player
		if id == SesionLAN.id_local():
			jugador = oficina.jugador
		else:
			# La identidad depende del participante, no de qué equipo lo representa.
			jugador = (POLICIA if id == 1 else POLICIA_RELEVO).instantiate() as Player
			jugador.name = "JugadorLAN_%d" % id
			jugador.remoto_red = true
			oficina.get_node("Gameplay").add_child(jugador)
		jugador.id_red = id
		_preparar_colision(jugador)
		jugadores[id] = jugador
		jugador.global_position = oficina.jugador._spawn_transform.origin + Vector3(0.72 * ids.find(id), 0, 0)
		jugador._spawn_transform = jugador.global_transform
		bolsillos[id] = [0, 0, 0, 0]
		cafes[id] = false
		var etiqueta := Label3D.new()
		etiqueta.text = "%d\n%s" % [ids.find(id) + 1, SesionLAN.participantes[id].alias]
		etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		etiqueta.font_size = 40
		etiqueta.pixel_size = 0.0018
		etiqueta.outline_size = 8
		etiqueta.no_depth_test = true
		etiqueta.modulate = Color("83e0ed") if ids.find(id) == 0 else Color("ffd28e")
		etiqueta.position.y = 1.2
		jugador.add_child(etiqueta)
	despacho.jugador_eliminado.connect(_eliminar)
	despacho.denuncia_resuelta.connect(_registrar_final.bind("resuelto"))
	despacho.denuncia_vencida.connect(_registrar_final.bind("vencido"))
	if not SesionLAN.es_anfitrion():
		oficina.temporizador_denuncias.stop()
		oficina.temporizador_bloqueos.stop()
		oficina.temporizador_eventos.stop()
	_actualizar_hud()

func comenzar() -> void:
	_listo = true
	if SesionLAN.es_anfitrion():
		oficina.temporizador_denuncias.start(3.0)
		publicar()

func _process(delta: float) -> void:
	if not _listo or not is_instance_valid(oficina):
		return
	if SesionLAN.es_anfitrion() and not _duelo.is_empty() and Time.get_ticks_msec() >= int(_duelo.get("vence", 0)):
		_terminar_duelo(0)
	if SesionLAN.es_anfitrion() and not _duelo.is_empty() and not oficina.emotes_permitidos():
		_terminar_duelo(0)
	if SesionLAN.es_anfitrion() and not _sismo_pendiente.is_empty() and not get_tree().paused:
		_sismo_espera += delta
		if _sismo_espera > 30.0:
			_cancelar_sismo()
		else:
			_intentar_autorizar_sismo()
	_actualizar_visual_duelo()
	_envio += delta
	_estado += delta
	if not get_tree().paused:
		_reloj += delta
		_interpolar(delta)
	if _envio >= 0.05:
		_envio = 0.0
		var j: Player = oficina.jugador
		SesionLAN.enviar_movimiento({"pos": j.global_position, "vel": j.velocity, "giro": j.visual.rotation.y, "anim": str(j.current_animation), "sentado": j.esta_sentado(), "cafe": j._taza_en_mano, "chocolate": j.chocolate_restante, "dona": j.dona_restante, "bloqueado": j.input_locked, "nado": j.nadando, "extintor": j.usando_extintor, "quemando": j.quemandose_pies, "congelado": j.congelado, "tick": Time.get_ticks_msec()})
	if SesionLAN.es_anfitrion() and _estado >= 0.1:
		_estado = 0.0
		_limpiar_papeles()
		_liberar_reservas_invalidas()
		publicar()
	_actualizar_contexto()
	_actualizar_hud()
	_actualizar_objetos_remotos()
	if not despacho.esta_activo(SesionLAN.id_local()):
		oficina.jugador.input_locked = true
		for id: int in jugadores:
			if despacho.esta_activo(id):
				oficina.get_node("Gameplay/Camera3D").objetivo = jugadores[id]

func recibir_movimiento(id: int, datos: Dictionary, validar: bool) -> bool:
	if not jugadores.has(id) or id == SesionLAN.id_local() or not datos.get("pos") is Vector3 or not datos.get("vel") is Vector3:
		return false
	var posicion: Vector3 = datos.pos
	if not posicion.is_finite() or not (datos.vel as Vector3).is_finite():
		return false
	var tick := int(datos.get("tick", 0))
	var previo: Dictionary = _ultimo_movimiento.get(id, {})
	if tick <= int(previo.get("tick", -1)):
		return false
	var j: Player = jugadores[id]
	if validar:
		if get_tree().paused or not despacho.esta_activo(id):
			return false
		var segundos := clampf((Time.get_ticks_msec() - int(previo.get("recibido", Time.get_ticks_msec() - 100))) / 1000.0, 0.05, 1.0)
		# Incluye salto, rescate de grietas y transiciones del sofá; nunca acepta fuera de la oficina.
		if posicion.x < -5.5 or posicion.x > 3.6 or posicion.z < -1.5 or posicion.z > 13.8 or posicion.y < -4.0 or posicion.y > 6.0:
			return false
		if not previo.is_empty() and posicion.distance_to(j.global_position) > 14.0 * segundos + 2.0:
			return false
	_ultimo_movimiento[id] = {"tick": tick, "recibido": Time.get_ticks_msec()}
	_remotos[id] = datos.duplicate()
	if validar:
		# La validación de interacciones usa la posición más reciente; el modelo se suaviza aparte.
		var visual_anterior := j.visual.global_position
		j.velocity = datos.vel
		_mover_cuerpo_remoto(j, posicion)
		j.visual.global_position = visual_anterior
	return true

func _interpolar(delta: float) -> void:
	for id: int in _remotos:
		if not jugadores.has(id) or _eliminados.has(id):
			continue
		var j: Player = jugadores[id]
		var datos: Dictionary = _remotos[id]
		j.velocity = datos.vel
		_mover_cuerpo_remoto(j, j.global_position.lerp(datos.pos, minf(1.0, delta / 0.1)))
		j.visual.position = j.visual.position.lerp(Vector3.ZERO, minf(1.0, delta / 0.1))
		j.visual.rotation.y = lerp_angle(j.visual.rotation.y, float(datos.giro), minf(1.0, delta / 0.1))
		j.nadando = bool(datos.get("nado", false))
		j.nivel_agua = oficina.evento_inundacion.nivel if oficina.evento_inundacion.activo else -INF
		j.chocolate_restante = float(datos.get("chocolate", 0.0))
		j.dona_restante = float(datos.get("dona", 0.0))
		j._peso_dona = move_toward(j._peso_dona, float(j.dona_restante > 0.0), delta * 3.0)
		j._descanso_sentado = bool(datos.get("sentado", false))
		j.gestos.establecer_sentado(j._descanso_sentado)
		j.usando_extintor = bool(datos.get("extintor", false))
		j.gestos.rociando_extintor = j.usando_extintor
		j.quemandose_pies = bool(datos.get("quemando", false))
		j.congelado = bool(datos.get("congelado", false))
		j._rapidez_real = Vector2(j.velocity.x, j.velocity.z).length()
		j._actualizar_pose_nado(delta)
		j.sonido_pasos.actualizar(delta, j._rapidez_real > 0.1 and not j.nadando and not j.congelado and not j._descanso_sentado, j._rapidez_real > j.walk_speed + 0.1)
		var anim := StringName(str(datos.get("anim", "idle")))
		if j.animation_player.has_animation(anim):
			j._play_animation(anim)

func _preparar_colision(j: Player) -> void:
	# Mantener el cuerpo físico a escala 1: las consultas de movimiento de Jolt
	# no detectan bien el contacto entre estos cuerpos con escala 0.3.
	# Trasladar la escala a los hijos conserva exactamente el aspecto y tamaño.
	var factor := j.scale.x
	if not is_equal_approx(factor, 1.0):
		for hijo: Node in j.get_children():
			if hijo is CollisionShape3D and hijo.shape is BoxShape3D:
				hijo.shape = hijo.shape.duplicate()
				hijo.shape.size *= factor
				hijo.position *= factor
			elif hijo is Node3D:
				hijo.position *= factor
				hijo.scale *= factor
		j.scale = Vector3.ONE
	j.set_collision_mask_value(2, true)
	j.choque.habilitado = true

func _mover_cuerpo_remoto(j: Player, destino: Vector3) -> void:
	# El remoto ya resuelve el escenario en su equipo. Aquí barrer su cuerpo
	# contra jugadores evita que la interpolación atraviese al jugador local.
	var mascara := j.collision_mask
	j.collision_mask = 2
	var choque := j.move_and_collide(destino - j.global_position)
	if choque != null:
		j.choque.registrar(choque.get_collider(), j.velocity)
		j.move_and_collide(choque.get_remainder().slide(choque.get_normal()))
	j.collision_mask = mascara

func procesar(id: int, tipo: String, datos: Dictionary) -> Dictionary:
	if not _listo or not jugadores.has(id):
		return _error("La oficina todavía está cargando.")
	if tipo == "sismo_listo":
		if _sismo_pendiente.is_empty() or int(datos.get("plan_id", -1)) != int(_sismo_pendiente.plan_id) or int(datos.get("huella", 0)) != int(_sismo_pendiente.get("huella", -1)):
			return _error("El plan de terremoto ya no está pendiente.")
		_sismo_listos[id] = true
		return {"ok": true}
	if tipo == "liberar":
		var clave := str(datos.get("objetivo", ""))
		if int(reservas.get(clave, {}).get("jugador", 0)) == id:
			reservas.erase(clave)
		return {"ok": true}
	if get_tree().paused or despacho.terminada or not despacho.esta_activo(id):
		return _error("No puedes actuar durante la pausa o fuera del turno.")
	var j: Player = jugadores[id]
	match tipo:
		"duelo_kamehameha":
			return _solicitar_duelo(id)
		"duelo_pulso":
			return _pulso_duelo(id)
		"gesto":
			var gesto := str(datos.get("tipo", ""))
			if gesto in ["recibir", "recoger", "lanzar", "interactuar", "reparar", "comer", "beber", "za_warudo", "control_agua", "control_tierra", "control_fuego", "control_aire", "kamehameha", "genkidama", "rasengan", "explosion_final", "saludar"]:
				if gesto in ["kamehameha", "genkidama", "rasengan", "explosion_final"] and not oficina.emotes_permitidos():
					return _error("No se pueden hacer emotes durante un evento.")
				SesionLAN.difundir("gesto", {"jugador": id, "tipo": gesto, "segundos": clampf(float(datos.get("segundos", 0.0)), 0.0, 5.0)})
			return {"ok": true}
		"aura_emote":
			if not oficina.emotes_permitidos():
				return _error("No se pueden hacer emotes durante un evento.")
			SesionLAN.difundir("aura_emote", {"jugador": id, "activa": bool(datos.get("activa", false))})
			return {"ok": true}
		"grieta":
			var caso := str(datos.get("caso", ""))
			if oficina.evento_terremoto.activo and is_instance_valid(j.papel_en_mano) and j.papel_en_mano.denuncia_id == caso and oficina.evento_terremoto.atrapo_hoja(j.global_position):
				despacho.vencer_denuncia(caso, Denuncia.MotivoPerdida.TERREMOTO)
				_limpiar_papeles()
				return {"ok": true}
			return _error("La hoja sigue a salvo.")
		"tomar":
			if not _cerca(j, oficina.computador) or is_instance_valid(j.papel_en_mano) or cafes.get(id, false) or oficina.evento_incendio.arde_estacion("computador"):
				return _error("Acércate al computador con las manos libres.")
			var caso := despacho.iniciar_denuncia_prioritaria(id)
			if caso == null:
				return _error("No hay denuncias disponibles; recoge las hojas ya impresas.")
			var papel := _crear_papel(caso.id)
			aplicando = true
			papel.tomar(j)
			aplicando = false
			return {"ok": true, "caso": caso.id}
		"recoger":
			var papel: PapelDenuncia = papeles.get(str(datos.get("caso", "")))
			if not is_instance_valid(papel) or is_instance_valid(papel.portador) or not _cerca(j, papel, 1.5) or is_instance_valid(j.papel_en_mano) or cafes.get(id, false):
				return _error("La hoja no está disponible.")
			aplicando = true
			papel.tomar(j)
			aplicando = false
			despacho.establecer_portador(papel.denuncia_id, id)
			return {"ok": true}
		"lanzar":
			if not is_instance_valid(j.papel_en_mano) or _tiene_tarea(id):
				return _error("Termina la interacción antes de soltar la hoja.")
			var papel: PapelDenuncia = j.papel_en_mano
			aplicando = true
			papel.lanzar()
			aplicando = false
			despacho.establecer_portador(papel.denuncia_id, 0)
			return {"ok": true}
		"estacion", "completar":
			return _estacion(id, tipo, datos)
		"reservar":
			return _reservar_objeto(id, str(datos.get("objetivo", "")))
		"comprar":
			return _comprar(id, str(datos.get("producto", "")), int(datos.get("indice", -1)))
		"consumir":
			return _consumir(id, int(datos.get("indice", -1)), int(datos.get("evento", -1)))
		"beber":
			if not cafes.get(id, false):
				return _error("No tienes café.")
			cafes[id] = false
			despacho.recuperar_calma(oficina.get_node("ZonaDescanso").calma_cafe, id)
			return {"ok": true}
		"cordura":
			return _cordura(id, datos)
		"reparar":
			return _reparar(id, str(datos.get("objetivo", "")))
		"rociar":
			return _rociar(id, int(datos.get("foco", -1)), float(datos.get("delta", 0.0)))
		"herramienta":
			var indice := int(datos.get("indice", 0))
			if indice < 0 or indice >= oficina.herramientas_reporte.size():
				return _error("Herramienta desconocida.")
			if not _cerca(j, oficina.herramientas_reporte[indice]):
				return _error("Acércate a la herramienta.")
			var reserva: Dictionary = reservas.get("estacion:reporte", {})
			var portadores: Array = reserva.get("herramientas", [])
			if not reserva.get("atasco", false) or indice >= portadores.size() or int(portadores[indice]) != 0 or portadores.has(id):
				return _error("La herramienta no está disponible.")
			portadores[indice] = id
			return {"ok": true}
	return _error("Acción desconocida.")

func _estacion(id: int, tipo: String, datos: Dictionary) -> Dictionary:
	var estacion := str(datos.get("estacion", ""))
	var caso_id := str(datos.get("caso", ""))
	var caso := despacho.arbol.buscar_por_id(caso_id)
	var j: Player = jugadores[id]
	var objetivo: Node3D = _buscar_estacion(estacion)
	if caso == null or objetivo == null or not _cerca(j, objetivo) or not is_instance_valid(j.papel_en_mano) or j.papel_en_mano.denuncia_id != caso_id or not caso.obtener_estaciones_pendientes().has(estacion) or oficina.evento_incendio.arde_estacion(estacion):
		return _error("La estación o la hoja ya no están disponibles.")
	var clave := "estacion:" + estacion
	var reserva: Dictionary = reservas.get(clave, {})
	if not reserva.is_empty() and str(reserva.caso) != caso_id:
		return _error("Estación ocupada por otro caso.")
	if tipo == "estacion":
		if reserva.is_empty():
			reserva = {"jugador": id, "caso": caso_id, "inicio": _reloj, "atasco": false, "herramientas": [0, 0]}
			if estacion == "reporte":
				reserva.atasco = oficina.generador_aleatorio.randf() < oficina.probabilidad_atasco_reporte
			reservas[clave] = reserva
		elif estacion in ["evidencias", "verificacion"] and int(reserva.jugador) != id:
			return _error("El compañero está usando esa estación.")
		if estacion == "privacidad":
			if _reloj - float(reserva.inicio) < oficina.DURACION_DESENCRIPTADO:
				return {"ok": true, "tarea": "esperar", "restante": oficina.DURACION_DESENCRIPTADO - (_reloj - float(reserva.inicio))}
		elif estacion == "reporte" and reserva.atasco:
			if not reserva.herramientas.has(id):
				return {"ok": true, "tarea": "atasco"}
		elif estacion in ["evidencias", "verificacion"]:
			return {"ok": true, "tarea": estacion}
	else:
		if reserva.is_empty() or int(reserva.jugador) != id or estacion not in ["evidencias", "verificacion"] or _reloj - float(reserva.inicio) < 0.2:
			return _error("La tarea ya no está reservada.")
	reservas.erase(clave)
	var correcto := despacho.interactuar_estacion(estacion, caso_id, id)
	if correcto:
		SesionLAN.difundir("tarea", {"jugador": id, "caso": caso_id, "estacion": estacion})
	_limpiar_papeles()
	return {"ok": correcto, "tarea": "completada"}

func _reservar_objeto(id: int, clave: String) -> Dictionary:
	var objetivo := _objeto(clave)
	if objetivo == null or not _cerca(jugadores[id], objetivo, 2.5):
		return _error("Acércate al objeto.")
	if not _objeto_disponible(clave):
		return _error("El objeto ya no necesita atención.")
	if clave in ["extintor", "extintor:1"] and (cafes.get(id, false) or (tiene_extintor(id) and int(reservas.get(clave, {}).get("jugador", 0)) != id)):
		return _error("Solo puedes llevar un extintor y necesitas las manos sin café.")
	if despacho.tiempo_detenido and not clave.begins_with("sofa:"):
		return _error("El mundo está detenido.")
	var actual: Dictionary = reservas.get(clave, {})
	if not actual.is_empty() and int(actual.jugador) != id:
		return _error("El compañero lo está usando.")
	reservas[clave] = {"jugador": id, "inicio": _reloj}
	if clave == "tienda":
		if not proximos_snacks.has(id):
			proximos_snacks[id] = oficina.get_node("MaquinaExpendedora").sortear_producto()
		reservas[clave].premio = proximos_snacks[id]
	return {"ok": true}

func _objeto_disponible(clave: String) -> bool:
	match clave:
		"apagon": return oficina.evento_apagon.estado != 0
		"inundacion": return oficina.evento_inundacion.activo and not oficina.evento_inundacion.drenando
		"hielo": return oficina.evento_hielo.activo and not oficina.evento_hielo.descongelando
		"extintor", "extintor:1": return oficina.evento_incendio.activo
	return true

func tiene_extintor(id: int) -> bool:
	for clave: String in ["extintor", "extintor:1"]:
		if int(reservas.get(clave, {}).get("jugador", 0)) == id:
			return true
	return false

func _comprar(id: int, producto: String, indice: int) -> Dictionary:
	var clave := "cafetera" if producto == "cafe" else "tienda"
	var reserva: Dictionary = reservas.get(clave, {})
	if reserva.is_empty() or int(reserva.jugador) != id or not _cerca(jugadores[id], _objeto(clave), 2.5) or despacho.tiempo_detenido:
		return _error("La compra ya no está disponible.")
	if producto not in ["snack", "cafe"] or oficina.espera_compra(producto, id) > 0:
		return _error("Espera antes de volver a comprar.")
	var precio: int
	if producto == "cafe":
		if cafes.get(id, false) or is_instance_valid(jugadores[id].papel_en_mano) or despacho.obtener_cordura(id) >= 100 or oficina.evento_apagon.estado != 0:
			return _error("No puedes recoger este café.")
		if indice < -1 or indice >= oficina.get_node("ZonaDescanso")._tazas.size():
			return _error("Taza no válida.")
		precio = oficina.get_node("ZonaDescanso").costo_cafe
	else:
		indice = int(reserva.premio)
		precio = oficina.get_node("MaquinaExpendedora").precio
	if not despacho.puntuacion.gastar_puntos(precio):
		return _error("Saldo compartido insuficiente.")
	oficina.registrar_compra(producto, id)
	if producto == "cafe":
		cafes[id] = true
		tazas_cafe[id] = maxi(0, indice)
		return {"ok": true, "taza": tazas_cafe[id]}
	bolsillos[id][indice] += 1
	proximos_snacks[id] = oficina.get_node("MaquinaExpendedora").sortear_producto()
	reserva.premio = proximos_snacks[id]
	return {"ok": true, "indice": indice}

func _consumir(id: int, indice: int, evento: int) -> Dictionary:
	if indice < 0 or indice > 3 or bolsillos[id][indice] <= 0 or despacho.tiempo_detenido:
		return _error("El objeto no está disponible; conservas tu carga.")
	var maquina: Node = oficina.get_node("MaquinaExpendedora")
	if indice == 3 and (evento != _evento_id or _evento_resuelto_id == _evento_id or maquina.poderes.evento_actual() == null or (oficina.evento_incendio.activo and oficina.evento_incendio._todas_apagadas())):
		return _error("El evento ya terminó; conservas el Avatar.")
	bolsillos[id][indice] -= 1
	if indice == 2:
		_activacion_tiempo += 1
		SesionLAN.difundir("tiempo", {"jugador": id, "activacion": _activacion_tiempo})
	elif indice == 3:
		SesionLAN.difundir("avatar", {"jugador": id, "evento": _evento_id, "origen": jugadores[id].global_position})
	return {"ok": true}

func _cordura(id: int, datos: Dictionary) -> Dictionary:
	var cantidad := int(datos.get("cantidad", 0))
	var causa := str(datos.get("causa", ""))
	if cantidad < 0 and causa == "lava" and oficina.evento_lava.activo and not oficina.evento_lava.resolviendo_avatar and jugadores[id].global_position.y < 0.5:
		var clave := "lava:%d" % id
		if _reloj - float(_esperas.get(clave, -10.0)) >= 0.65:
			_esperas[clave] = _reloj
			despacho.perder_calma(mini(2, -cantidad), &"lava", id)
			return {"ok": true}
	if cantidad == 1:
		for asiento: String in ["sofa:AsientoTramo", "sofa:AsientoRetorno"]:
			if int(reservas.get(asiento, {}).get("jugador", 0)) == id and _cerca(jugadores[id], _objeto(asiento), 0.7):
				var clave := "sofa:%d" % id
				if _reloj - float(_esperas.get(clave, -2.0)) >= 1.9:
					_esperas[clave] = _reloj
					despacho.recuperar_calma(1, id)
					return {"ok": true}
	return _error("Recuperación o daño no disponible.")

func _buscar_estacion(id: String) -> Node3D:
	return _estaciones.get(id)

func _objeto(clave: String) -> Node3D:
	match clave:
		"tienda": return oficina.get_node("MaquinaExpendedora")
		"cafetera": return oficina.get_node("ZonaDescanso/RinconCafe")
		"apagon": return oficina.evento_apagon.taco
		"inundacion": return oficina.evento_inundacion.tuberias
		"hielo": return oficina.evento_hielo.tuberia
		"extintor": return oficina.evento_incendio.extintores[0]
		"extintor:1": return oficina.evento_incendio.extintores[1] if oficina.evento_incendio.extintores.size() > 1 else null
	if clave in ["sofa:AsientoTramo", "sofa:AsientoRetorno"]:
		return oficina.get_node("ZonaDescanso/SofaL/" + clave.get_slice(":", 1))
	return null

func _cerca(j: Node3D, objeto: Node3D, distancia := 2.4) -> bool:
	return is_instance_valid(objeto) and j.global_position.distance_to(objeto.global_position) <= distancia

func _tiene_tarea(id: int) -> bool:
	for clave: String in reservas:
		if clave in ["estacion:evidencias", "estacion:verificacion"] and int(reservas[clave].jugador) == id:
			return true
	return false

func _error(texto: String) -> Dictionary:
	return {"ok": false, "mensaje": texto}

func mensaje(texto: String) -> void:
	if is_instance_valid(oficina.panel_despacho):
		oficina.panel_despacho._mostrar_mensaje(texto, PanelDespacho.CORAL)

func _crear_papel(caso_id: String) -> PapelDenuncia:
	if is_instance_valid(papeles.get(caso_id)):
		return papeles[caso_id]
	var papel := PapelDenuncia.new()
	papel.denuncia_id = caso_id
	papel.red = self
	oficina.add_child(papel)
	papel.name = "Hoja_" + caso_id.validate_node_name()
	papel.global_position = oficina.computador.global_position + Vector3.UP * 0.7
	papeles[caso_id] = papel
	return papel

func _limpiar_papeles() -> void:
	for caso: String in papeles.keys():
		if despacho.arbol.buscar_por_id(caso) != null:
			continue
		var papel: PapelDenuncia = papeles[caso]
		if is_instance_valid(papel):
			if is_instance_valid(papel.portador):
				papel.portador.papel_en_mano = null
			papel.queue_free()
		papeles.erase(caso)
	_liberar_reservas_invalidas()

func _actualizar_contexto() -> void:
	var papel: PapelDenuncia = oficina.jugador.papel_en_mano
	oficina.papel_actual = papel if is_instance_valid(papel) else null
	var nuevo := papel.denuncia_id if is_instance_valid(papel) else ""
	if despacho.denuncia_activa_id != nuevo:
		despacho.denuncia_activa_id = nuevo
		oficina._on_denuncias_actualizadas(despacho.obtener_denuncias_ordenadas())
	var reporte: Dictionary = reservas.get("estacion:reporte", {})
	oficina._reporte_atascado_id = str(reporte.get("caso", "")) if reporte.get("atasco", false) else ""
	var portadores: Array = reporte.get("herramientas", [0, 0])
	oficina._reporte_herramienta_recogida = portadores.has(SesionLAN.id_local())
	var contexto := [oficina._reporte_atascado_id, portadores.duplicate(), oficina.evento_apagon.estado]
	if contexto == _contexto_previo:
		return
	_contexto_previo = contexto
	for indice in oficina.herramientas_reporte.size():
		oficina.herramientas_reporte[indice].establecer_activa(not oficina._reporte_atascado_id.is_empty() and int(portadores[indice]) == 0)
	oficina._aviso_reporte_atasco.visible = not oficina._reporte_atascado_id.is_empty() and oficina.evento_apagon.estado == 0

func _actualizar_hud() -> void:
	var ids: Array = SesionLAN.participantes.keys()
	ids.sort()
	for indice in ids.size():
		var id: int = ids[indice]
		var nombre := str(SesionLAN.participantes[id].alias)
		if not despacho.esta_activo(id):
			nombre += " · FUERA"
		var estado_hud := [despacho.obtener_cordura(id), nombre]
		if _hud_previo.get(id, []) != estado_hud:
			_hud_previo[id] = estado_hud
			oficina.panel_despacho.calma_jugadores.actualizar_jugador(indice + 1, estado_hud[0], nombre)

func _serializar_caso(caso: Denuncia) -> Dictionary:
	var datos := {}
	for campo: String in CAMPOS_CASO:
		datos[campo] = caso.get(campo)
	return datos

func _leer_caso(datos: Dictionary) -> Denuncia:
	var caso := Denuncia.new()
	for campo: String in CAMPOS_CASO:
		if campo in ["protocolo_estaciones", "estaciones_completadas"]:
			caso.get(campo).assign(datos.get(campo, []))
		else:
			caso.set(campo, datos[campo])
	return caso

func publicar() -> void:
	if not _listo or not SesionLAN.es_anfitrion():
		return
	_revision += 1
	var casos: Array = []
	for caso: Denuncia in despacho.obtener_denuncias_ordenadas():
		casos.append(_serializar_caso(caso))
	var hojas := {}
	for caso: String in papeles:
		var papel: PapelDenuncia = papeles[caso]
		if is_instance_valid(papel):
			hojas[caso] = {"portador": papel.portador.id_red if is_instance_valid(papel.portador) else 0, "transform": papel.global_transform, "velocidad": papel.linear_velocity}
	var estado_actual := {"revision": _revision, "jugadores": despacho.jugadores, "casos": casos, "tiempos": despacho.tiempos_restantes, "activos": despacho.casos_en_proceso, "participantes": despacho.participantes, "portadores": despacho.ultimos_portadores, "asignados": despacho.casos_por_jugador, "saldo": despacho.puntuacion.puntos, "ganados": despacho.puntuacion.puntos_ganados, "terminada": despacho.terminada, "causa": str(despacho.causa_agotamiento), "hojas": hojas, "reservas": reservas, "bolsillos": bolsillos, "proximas_compras": oficina.proximas_compras, "cafes": cafes, "tazas_cafe": tazas_cafe, "resueltos": {}, "vencidos": {}, "duracion": oficina._duracion_partida, "mundo": _estado_mundo()}
	estado_actual["aportes"] = despacho.aportes_jugadores
	_enviar_estado(estado_actual)

func aplicar(datos: Dictionary) -> void:
	if int(datos.revision) <= _revision_recibida:
		return
	_revision_recibida = int(datos.revision)
	aplicando = true
	_cambio_interfaz = despacho.jugadores != datos.jugadores or despacho.casos_en_proceso != datos.activos or despacho.casos_por_jugador != datos.asignados
	despacho.jugadores = datos.jugadores.duplicate(true)
	_actualizar_casos(datos.casos)
	despacho.tiempos_restantes = datos.tiempos.duplicate()
	despacho.casos_en_proceso = datos.activos.duplicate()
	despacho.participantes = datos.participantes.duplicate(true)
	despacho.aportes_jugadores = datos.get("aportes", {}).duplicate(true)
	despacho.ultimos_portadores = datos.portadores.duplicate()
	despacho.casos_por_jugador = datos.asignados.duplicate()
	reservas = datos.reservas.duplicate(true)
	bolsillos = datos.bolsillos.duplicate(true)
	oficina.proximas_compras = datos.proximas_compras.duplicate(true)
	cafes = datos.cafes.duplicate()
	tazas_cafe = datos.get("tazas_cafe", {}).duplicate()
	var saldo_anterior := despacho.puntuacion.puntos
	despacho.puntuacion._puntos = int(datos.saldo)
	despacho.puntuacion._puntos_ganados = int(datos.ganados)
	if saldo_anterior != despacho.puntuacion.puntos:
		despacho.puntuacion.puntos_actualizados.emit(despacho.puntuacion.puntos)
	for caso: String in datos.hojas:
		var papel := _crear_papel(caso)
		var hoja: Dictionary = datos.hojas[caso]
		var id := int(hoja.portador)
		if id != 0 and jugadores.has(id):
			if papel.portador != jugadores[id]:
				if is_instance_valid(papel.portador):
					papel.portador.papel_en_mano = null
				papel.tomar(jugadores[id])
		else:
			if is_instance_valid(papel.portador):
				papel.lanzar()
			papel.freeze = true
			papel.global_transform = hoja.transform
			papel.linear_velocity = hoja.velocidad
	for caso: String in datos.resueltos:
		if not _resueltos.has(caso):
			_resueltos[caso] = datos.resueltos[caso]
			despacho.denuncia_resuelta.emit(_leer_caso(datos.resueltos[caso]))
	for caso: String in datos.vencidos:
		if not _vencidos.has(caso):
			_vencidos[caso] = datos.vencidos[caso]
			despacho.denuncia_vencida.emit(_leer_caso(datos.vencidos[caso]))
	_limpiar_papeles()
	_actualizar_contexto()
	oficina._duracion_partida = float(datos.duracion)
	_aplicar_mundo(datos.mundo)
	for id: int in despacho.jugadores:
		if not despacho.esta_activo(id):
			_eliminar(id)
	if _cambio_interfaz:
		despacho._notificar_cambios()
	_cambio_interfaz = false
	_actualizar_hud()
	if datos.terminada and not despacho.terminada:
		despacho.terminada = true
		despacho.causa_agotamiento = StringName(datos.causa)
		despacho.partida_terminada.emit()
	aplicando = false

func _liberar_reservas_invalidas() -> void:
	for clave: String in reservas.keys():
		var dato: Dictionary = reservas[clave]
		if dato.has("caso"):
			if despacho.arbol.buscar_por_id(str(dato.caso)) == null:
				reservas.erase(clave)
		elif not despacho.esta_activo(int(dato.jugador)) or not _objeto_disponible(clave):
			reservas.erase(clave)
		elif clave in ["tienda", "cafetera", "sofa:AsientoTramo", "sofa:AsientoRetorno", "apagon", "inundacion", "hielo"] and not _cerca(jugadores[int(dato.jugador)], _objeto(clave), 3.0):
			reservas.erase(clave)

func _eliminar(id: int) -> void:
	if _eliminados.has(id) or not jugadores.has(id):
		return
	_eliminados[id] = true
	var j: Player = jugadores[id]
	if SesionLAN.es_anfitrion() and is_instance_valid(j.papel_en_mano):
		aplicando = true
		var hoja: PapelDenuncia = j.papel_en_mano
		hoja.lanzar()
		hoja.global_position = oficina.computador.global_position + Vector3.UP * 0.7
		despacho.establecer_portador(hoja.denuncia_id, 0)
		aplicando = false
	for clave: String in reservas.keys():
		if clave == "estacion:reporte":
			var portadores: Array = reservas[clave].get("herramientas", [])
			for indice in portadores.size():
				if int(portadores[indice]) == id:
					portadores[indice] = 0
		if int(reservas[clave].jugador) == id:
			if clave == "estacion:reporte" and reservas[clave].get("atasco", false):
				reservas[clave].jugador = 0
			elif clave == "estacion:privacidad":
				reservas[clave].jugador = 0
			else:
				reservas.erase(clave)
	j.cancelar_gesto()
	j.terminar_descanso_sentado(true)
	j.input_locked = true
	j.velocity = Vector3.ZERO
	j.collision_layer = 0
	j.set_physics_process(false)
	j.set_process_input(false)
	var esqueleto := j.visual.find_child("Skeleton3D", true, false) as Skeleton3D
	if esqueleto != null:
		var pose := preload("res://Personajes/PoliciaAzul/pose_agotada.gd").new()
		pose.name = "AgotamientoLAN"
		pose.peso = 1.0
		esqueleto.add_child(pose)
	if id == SesionLAN.id_local():
		oficina.clasificador_evidencias.cancelar()
		oficina.escaner_verificacion.cancelar()
		oficina.evento_apagon._al_cerrar_panel()
		oficina.evento_apagon.panel.hide()
		oficina.evento_inundacion._cerrar_reparacion()
		oficina.evento_hielo._cerrar_reparacion()
		oficina.evento_incendio.soltar()
		oficina.get_node("ZonaDescanso")._al_reiniciar_jugador()
		oficina.get_node("MaquinaExpendedora").cerrar()
		j.input_locked = true
		mensaje("Sin cordura. Observas a tu compañero hasta la siguiente partida.")
	# La limpieza del sofá restaura las capas anteriores; el agotado no bloquea pasos.
	j.collision_layer = 0

func solicitar_estacion(estacion: String, caso: String) -> void:
	SesionLAN.solicitar("estacion", {"estacion": estacion, "caso": caso}, func(resultado: Dictionary):
		if not resultado.get("ok", false) or not despacho.esta_activo(SesionLAN.id_local()):
			return
		_actualizar_contexto()
		match str(resultado.get("tarea", "")):
			"evidencias": oficina._interactuar_evidencias()
			"verificacion": oficina._interactuar_verificacion()
			"esperar":
				oficina._denuncia_en_descriptado = caso
				oficina._seguridad_lista = false
				oficina.temporizador_seguridad.start(float(resultado.restante))
				oficina.progreso_seguridad.show()
				mensaje("Seguridad está desencriptando. Vuelve a recoger el archivo.")
			"atasco": mensaje("Impresora atascada. Recoge la herramienta en descanso.")
			"completada":
				if estacion == "privacidad": oficina._cancelar_descriptado()
				if estacion == "reporte": oficina.sonidos_mesas.imprimir()
	)

func reservar_local(clave: String, continuar: Callable) -> void:
	SesionLAN.solicitar("reservar", {"objetivo": clave}, func(resultado: Dictionary):
		if resultado.get("ok", false) and continuar.is_valid():
			continuar.call()
	)

func liberar_local(clave: String) -> void:
	SesionLAN.solicitar("liberar", {"objetivo": clave})

func reservar_confirmada(clave: String) -> bool:
	return int(reservas.get(clave, {}).get("jugador", 0)) == SesionLAN.id_local()

func proteger_celda(celda: Vector2i, ensayo: AStarGrid2D = null) -> bool:
	var centro: Vector3 = oficina.grafo_piso.celda_a_posicion(celda)
	for j: Player in jugadores.values():
		if not despacho.esta_activo(j.id_red):
			continue
		if absf(j.global_position.x - centro.x) < 0.65 and absf(j.global_position.z - centro.z) < 0.65:
			return false
		if ensayo != null:
			var origen: Vector2i = oficina.grafo_piso.celda_de_acceso(j.global_position)
			for destino: Vector2i in GrafoPiso.DESTINOS.values():
				if ensayo.get_id_path(origen, destino).is_empty():
					return false
	for papel: PapelDenuncia in papeles.values():
		if is_instance_valid(papel) and papel.portador == null and Vector2(papel.global_position.x - centro.x, papel.global_position.z - centro.z).length() < 0.8:
			return false
	return true

func iniciar_evento(tipo: String) -> bool:
	if not SesionLAN.es_anfitrion() or not _listo or get_tree().paused or not oficina._puede_iniciar_evento():
		return false
	if not _sismo_pendiente.is_empty(): return false
	if tipo == "terremoto":
		_sismo_secuencia += 1
		_sismo_pendiente = {"id": _evento_id + 1, "plan_id": _sismo_secuencia}
		_sismo_listos.clear()
		_sismo_espera = 0.0
		oficina.evento_terremoto._azar.seed = randi()
		if not oficina.evento_terremoto.iniciar(oficina.grafo_piso, oficina.jugador, oficina.bloqueos_visuales, oficina._huella_papel_suelto(), true):
			_sismo_pendiente.clear()
			return false
		return true
	var posiciones: Array = []
	for j: Player in jugadores.values():
		posiciones.append(j.global_position)
	var datos := {"tipo": tipo, "semilla": randi(), "posicion": oficina.jugador.global_position, "posiciones": posiciones, "id": _evento_id + 1}
	datos["hojas"] = []
	for papel: PapelDenuncia in papeles.values():
		if is_instance_valid(papel) and papel.portador == null:
			datos.hojas.append(papel.global_position)
	if not _arrancar_evento(datos):
		return false
	if tipo == "lava":
		datos["charcos"] = oficina.evento_lava.charcos.duplicate()
	_evento_id = int(datos.id)
	publicar()
	SesionLAN.difundir("inicio", datos)
	return true

func _preparacion_sismo_terminada(correcta: bool) -> void:
	if _sismo_pendiente.is_empty(): return
	if not correcta:
		if SesionLAN.es_anfitrion(): _cancelar_sismo()
		return
	if SesionLAN.es_anfitrion():
		var plan: Dictionary = oficina.evento_terremoto.exportar_trazado_red()
		# Enviar los mismos bytes que se firman evita diferencias de tipado o
		# precisión al codificar diccionarios anidados mediante RPC.
		var serializado := var_to_bytes(plan)
		_sismo_pendiente["plan_serializado"] = serializado
		_sismo_pendiente["huella"] = hash(serializado)
		_sismo_listos[SesionLAN.id_local()] = true
		SesionLAN.difundir("sismo_plan", _sismo_pendiente.duplicate(true))
	else:
		SesionLAN.solicitar("sismo_listo", {"plan_id": _sismo_pendiente.plan_id, "huella": _sismo_pendiente.huella})


func _intentar_autorizar_sismo() -> void:
	if not _sismo_pendiente.has("plan_serializado"): return
	for id: int in SesionLAN.participantes:
		if not _sismo_listos.has(id): return
	# Última validación con las posiciones actuales del anfitrión. Ningún cliente
	# inicia el reloj hasta recibir la autorización para este mismo plan.
	if not oficina.evento_terremoto.validar_plan_actual():
		_cancelar_sismo()
		return
	var datos := {"id": _sismo_pendiente.id, "plan_id": _sismo_pendiente.plan_id, "huella": _sismo_pendiente.huella}
	SesionLAN.difundir("sismo_inicio", datos)


func _cancelar_sismo() -> void:
	if _sismo_pendiente.is_empty(): return
	var plan_id: int = _sismo_pendiente.plan_id
	_sismo_pendiente.clear()
	_sismo_listos.clear()
	oficina.evento_terremoto.cancelar_preparacion()
	SesionLAN.difundir("sismo_cancelar", {"plan_id": plan_id})
	if not oficina.partida_finalizada: oficina.temporizador_eventos.start(2.0)


func _arrancar_evento(datos: Dictionary) -> bool:
	iniciando_evento = true
	var rng_anterior: int = oficina.generador_aleatorio.state
	oficina.generador_aleatorio.seed = int(datos.semilla)
	oficina.evento_apagon._azar.seed = int(datos.semilla)
	oficina.evento_terremoto._azar.seed = int(datos.semilla)
	oficina.evento_terremoto.posiciones_red.assign(datos.posiciones)
	oficina.evento_lava.posiciones_protegidas_red.assign(datos.posiciones + datos.hojas)
	oficina.evento_lava.usar_charcos_red = datos.has("charcos")
	oficina.evento_lava.charcos_red.assign(datos.get("charcos", []))
	oficina.evento_terremoto.hojas_red.clear()
	for hoja: PapelDenuncia in papeles.values():
		if is_instance_valid(hoja) and hoja.portador == null:
			oficina.evento_terremoto.hojas_red.append(hoja.global_position)
	var j: Player = oficina.jugador
	var posicion := j.global_position
	var bloqueo := j.input_locked
	j.global_position = datos.posicion
	j.input_locked = false
	var resultado := false
	match str(datos.tipo):
		"apagon": resultado = oficina.evento_apagon.iniciar_apagon()
		"terremoto":
			# El terremoto usa la barrera de plan/montaje/autorización.
			resultado = false
		"incendio": resultado = oficina.evento_incendio.iniciar(oficina.bloqueos_visuales)
		"inundacion": resultado = oficina.evento_inundacion.iniciar()
		"lava": resultado = oficina.evento_lava.iniciar()
		"hielo": resultado = oficina.evento_hielo.iniciar()
	j.global_position = posicion
	j.input_locked = bloqueo
	oficina.generador_aleatorio.state = rng_anterior
	iniciando_evento = false
	return resultado

func aplicar_evento(tipo: String, datos: Dictionary) -> void:
	match tipo:
		"sismo_plan":
			if SesionLAN.es_anfitrion() or int(datos.id) <= _evento_id or int(datos.plan_id) <= _sismo_secuencia: return
			_sismo_secuencia = int(datos.plan_id)
			if hash(datos.plan_serializado) != int(datos.huella):
				SesionLAN.cerrar("El plan de terremoto no coincide con el del anfitrión.")
				return
			var plan: Dictionary = bytes_to_var(datos.plan_serializado)
			_sismo_pendiente = datos.duplicate(true)
			if not oficina.evento_terremoto.importar_trazado_red(plan, oficina.grafo_piso, oficina.jugador, oficina.bloqueos_visuales):
				SesionLAN.cerrar("No se pudo preparar el terremoto compartido.")
		"sismo_cancelar":
			if int(_sismo_pendiente.get("plan_id", -1)) != int(datos.plan_id): return
			_sismo_pendiente.clear()
			_sismo_listos.clear()
			oficina.evento_terremoto.cancelar_preparacion()
		"sismo_inicio":
			if _sismo_pendiente.is_empty() or int(datos.plan_id) != int(_sismo_pendiente.plan_id) or int(datos.huella) != int(_sismo_pendiente.huella) or int(datos.id) <= _evento_id: return
			iniciando_evento = true
			# El anfitrión acaba de validar en _intentar_autorizar_sismo, sin cesión.
			var autorizado: bool = oficina.evento_terremoto.autorizar_plan(false)
			iniciando_evento = false
			if not autorizado:
				SesionLAN.cerrar("No se pudo autorizar el terremoto compartido.")
				return
			_evento_id = int(datos.id)
			_sismo_pendiente.clear()
			_sismo_listos.clear()
			if anuncio_pendiente.size() == 4:
				oficina._anunciar_inicio_evento.callv(anuncio_pendiente)
				anuncio_pendiente.clear()
			if SesionLAN.es_anfitrion(): publicar()
		"duelo":
			_aplicar_duelo(datos)
		"tarea":
			if int(datos.jugador) == SesionLAN.id_local():
				oficina.panel_despacho.mostrar_tarea_local(str(datos.caso), str(datos.estacion))
				oficina.jugador.reproducir_expresion(&"alegria")
		"inicio":
			if not SesionLAN.es_anfitrion():
				if int(datos.id) <= _evento_id:
					return
				_evento_id = int(datos.id)
				if not _arrancar_evento(datos):
					SesionLAN.cerrar("No se pudo sincronizar el evento. Vuelve a crear la partida.")
			if anuncio_pendiente.size() == 4:
				oficina._anunciar_inicio_evento.callv(anuncio_pendiente)
				anuncio_pendiente.clear()
		"tiempo":
			oficina.get_node("MaquinaExpendedora").poderes.detener_tiempo(int(datos.get("activacion", 0)))
		"avatar":
			if int(datos.get("evento", -1)) != _evento_id or _evento_resuelto_id == _evento_id:
				return
			_evento_resuelto_id = _evento_id
			var evento: Node = oficina.get_node("MaquinaExpendedora").poderes.evento_actual()
			if evento != null:
				aplicando = true
				evento.resolver_con_avatar(datos.get("origen", jugadores[int(datos.jugador)].global_position))
				aplicando = false
			reservas.erase("apagon")
			reservas.erase("inundacion")
			reservas.erase("hielo")
			reservas.erase("extintor")
			reservas.erase("extintor:1")
		"reparado":
			_evento_resuelto_id = _evento_id
			aplicando = true
			match str(datos.objetivo):
				"apagon": oficina.evento_apagon.resolver_con_avatar()
				"inundacion":
					var evento: Node = oficina.evento_inundacion
					evento._cerrar_reparacion()
					evento.drenando = true
					evento.tuberias.sellar()
					evento.indicador.hide()
					oficina.anuncios.mostrar_evento("TUBERÍAS", "REPARADAS", "El agua está bajando")
				"hielo":
					var evento: Node = oficina.evento_hielo
					evento._cerrar_reparacion()
					evento.descongelando = true
					evento._tiempo_deshielo = 0.0
					evento._presencia_al_reparar = minf(1.0, evento.tiempo / evento.ENTRADA)
					evento._jugador.congelado = false
					evento.tuberia.sellar()
					evento._nieve.emitting = false
					oficina.anuncios.mostrar_evento("¡FUGA", "SELLADA!", "El hielo se está derritiendo")
			aplicando = false
		"gesto":
			var id := int(datos.jugador)
			if id != SesionLAN.id_local() and jugadores.has(id):
				var j: Player = jugadores[id]
				if is_instance_valid(j.gestos):
					j.gestos.iniciar(StringName(datos.tipo), null, float(datos.segundos))
				if str(datos.tipo).begins_with("control_"):
					var elemento := preload("res://Objetos/ZonaDescanso/efecto_elemental.gd").new()
					elemento.jugador = j
					elemento.tipo = StringName(datos.tipo)
					oficina.add_child(elemento)
					elemento.global_position = j.global_position
					elemento.rotation.y = j.visual.global_rotation.y
		"aura_emote":
			var id := int(datos.jugador)
			if id != SesionLAN.id_local() and jugadores.has(id):
				var j: Player = jugadores[id]
				if is_instance_valid(j.gestos) and j.gestos.aura_persistente_activada != bool(datos.activa):
					j.gestos.alternar_aura_persistente()

func _reparar(id: int, clave: String) -> Dictionary:
	if clave not in ["apagon", "inundacion", "hielo"] or int(reservas.get(clave, {}).get("jugador", 0)) != id or not _cerca(jugadores[id], _objeto(clave), 2.5):
		return _error("La reparación ya no está disponible.")
	var vigente: bool = (clave == "apagon" and oficina.evento_apagon.estado != 0) or (clave == "inundacion" and oficina.evento_inundacion.activo and not oficina.evento_inundacion.drenando) or (clave == "hielo" and oficina.evento_hielo.activo and not oficina.evento_hielo.descongelando)
	if not vigente:
		return _error("El evento ya fue reparado.")
	reservas.erase(clave)
	SesionLAN.difundir("reparado", {"objetivo": clave})
	return {"ok": true}

func _rociar(id: int, indice: int, paso: float) -> Dictionary:
	var evento: Node = oficina.evento_incendio
	if not evento.activo or not tiene_extintor(id) or indice < 0 or indice >= evento.focos.size() or despacho.tiempo_detenido:
		return _error("El extintor no está disponible.")
	var foco: Node3D = evento.focos[indice]
	var p: Vector3 = jugadores[id].global_position
	var punto := Vector3(clampf(p.x, foco.limites.position.x, foco.limites.end.x), p.y + 0.42, clampf(p.z, foco.limites.position.z, foco.limites.end.z))
	if not evento._al_alcance(punto, foco, jugadores[id]):
		return _error("Acércate al fuego.")
	var clave := "fuego:%d" % id
	var transcurrido := clampf(_reloj - float(_esperas.get(clave, _reloj - 0.05)), 0.0, 0.15)
	_esperas[clave] = _reloj
	if foco.apagado < 1.0 and foco.rociar(minf(paso, transcurrido), evento.SEGUNDOS_POR_MESA):
		evento._recuperar_mesa_y_adyacentes(foco)
	return {"ok": true}

func rociar_local(foco: Node, delta: float) -> bool:
	_ultimo_fuego += delta
	if _ultimo_fuego >= 0.05:
		SesionLAN.solicitar("rociar", {"foco": oficina.evento_incendio.focos.find(foco), "delta": _ultimo_fuego})
		_ultimo_fuego = 0.0
	return foco.apagado >= 1.0

func _estado_mundo() -> Dictionary:
	var fuegos: Array = []
	for foco: Node in oficina.evento_incendio.focos:
		fuegos.append(float(foco.apagado))
	return {"progresion_mesas": oficina.tiempo_progresion_mesas, "mesas_debug": oficina.mesas_extra_debug, "bloqueos": oficina.grafo_piso.bloqueos_temporales.keys(), "bloqueos_iniciados": oficina.bloqueos_iniciados, "incendio": oficina.evento_incendio.activo, "fuegos": fuegos, "incendio_t": oficina.evento_incendio.tiempo, "inundacion": oficina.evento_inundacion.activo, "nivel": oficina.evento_inundacion.nivel, "agua_t": oficina.evento_inundacion.tiempo, "hielo": oficina.evento_hielo.activo, "hielo_t": oficina.evento_hielo.tiempo, "lava": oficina.evento_lava.activo, "lava_t": oficina.evento_lava.tiempo_restante, "sismo_t": oficina.evento_terremoto.tiempo, "papa_t": oficina.get_node("MaquinaExpendedora").poderes.restante}

func _aplicar_mundo(datos: Dictionary) -> void:
	if despacho.tiempo_detenido:
		var poderes: Node = oficina.get_node("MaquinaExpendedora").poderes
		poderes.restante = float(datos.papa_t)
		if poderes.restante <= 0.0:
			poderes.reanudar_tiempo()
	if oficina.evento_terremoto.activo and not oficina.evento_terremoto.resolviendo_avatar:
		oficina.evento_terremoto.tiempo = float(datos.sismo_t)
	oficina.tiempo_progresion_mesas = float(datos.get("progresion_mesas", 0.0))
	oficina.mesas_extra_debug = int(datos.get("mesas_debug", 0))
	oficina.bloqueos_iniciados = bool(datos.bloqueos_iniciados)
	var celdas: Array = datos.bloqueos
	if celdas != _ultima_distribucion:
		_ultima_distribucion = celdas.duplicate()
		# El anfitrión publica celdas concretas: no se sortea otra distribución en el cliente.
		for celda: Vector2i in oficina.bloqueos_visuales.keys():
			if not celdas.has(celda):
				var bloqueo: Node = oficina.bloqueos_visuales[celda]
				bloqueo.desactivar()
				oficina._bloqueos_disponibles.append(bloqueo)
				oficina.bloqueos_visuales.erase(celda)
		oficina.grafo_piso.bloqueos_temporales.clear()
		for celda: Vector2i in celdas:
			oficina.grafo_piso.bloqueos_temporales[celda] = true
			if not oficina.bloqueos_visuales.has(celda):
				oficina._mostrar_bloqueo_temporal(celda)
		oficina.grafo_piso.construir_adyacencia()
		oficina.depurador_grafo.actualizar_mapa()
	if oficina.evento_incendio.activo and not oficina.evento_incendio.resolviendo_avatar:
		oficina.evento_incendio.tiempo = float(datos.incendio_t)
		for i in mini(datos.fuegos.size(), oficina.evento_incendio.focos.size()):
			oficina.evento_incendio.focos[i]._establecer_apagado(float(datos.fuegos[i]))
		if not datos.incendio:
			oficina.evento_incendio.resolver_con_avatar()
	if oficina.evento_inundacion.activo and not oficina.evento_inundacion.resolviendo_avatar:
		oficina.evento_inundacion.nivel = float(datos.nivel)
		oficina.evento_inundacion.tiempo = float(datos.agua_t)
		if not datos.inundacion:
			oficina.evento_inundacion.resolver_con_avatar()
	if oficina.evento_hielo.activo and not oficina.evento_hielo.resolviendo_avatar:
		oficina.evento_hielo.tiempo = float(datos.hielo_t)
		if not datos.hielo:
			oficina.evento_hielo.resolver_con_avatar()
	if oficina.evento_lava.activo and not oficina.evento_lava.resolviendo_avatar:
		oficina.evento_lava.tiempo_restante = float(datos.lava_t)
		if not datos.lava:
			oficina.evento_lava.resolver_con_avatar()

func perder_por_grieta(caso: String) -> void:
	SesionLAN.solicitar("grieta", {"caso": caso})

func _solicitar_duelo(id: int) -> Dictionary:
	if not oficina.emotes_permitidos():
		return _error("No se pueden hacer emotes durante un evento.")
	if jugadores.size() != 2:
		return _error("El duelo requiere dos jugadores.")
	var solicitante: Player = jugadores[id]
	if solicitante.input_locked or solicitante.realizando_gesto() or (id == SesionLAN.id_local() and not solicitante.is_on_floor()):
		return _error("El jugador debe estar libre y en el suelo.")
	var ahora := Time.get_ticks_msec()
	if _duelo.is_empty():
		_duelo = {"fase": "espera", "invitador": id, "vence": ahora + 5000}
		SesionLAN.difundir("duelo", {"fase": "espera", "invitador": id})
		return {"ok": true}
	if _duelo.get("fase") != "espera" or int(_duelo.get("invitador", 0)) == id:
		return _error("Ya hay un duelo en curso.")
	var primero := int(_duelo.invitador)
	if not despacho.esta_activo(primero):
		_terminar_duelo(0)
		return _error("El otro jugador no puede iniciar el duelo.")
	var primero_jugador: Player = jugadores[primero]
	if primero_jugador.input_locked or primero_jugador.realizando_gesto() or (primero == SesionLAN.id_local() and not primero_jugador.is_on_floor()):
		_terminar_duelo(0)
		return _error("El otro jugador ya no está disponible.")
	_duelo = {"fase": "choque", "primero": primero, "segundo": id, "avance": 0, "disparo": ahora + 1800, "vence": ahora + 13800}
	_duelo_ultimo_pulso.clear()
	SesionLAN.difundir("duelo", {"fase": "choque", "primero": primero, "segundo": id, "avance": 0})
	return {"ok": true}

func _pulso_duelo(id: int) -> Dictionary:
	if _duelo.get("fase", "") != "choque":
		return _error("No hay choque activo.")
	var ahora := Time.get_ticks_msec()
	if ahora < int(_duelo.get("disparo", 0)):
		return {"ok": true}
	if ahora - int(_duelo_ultimo_pulso.get(id, 0)) < 85:
		return {"ok": true}
	_duelo_ultimo_pulso[id] = ahora
	_duelo.avance = clampi(int(_duelo.avance) + (1 if id == int(_duelo.primero) else -1), -14, 14)
	SesionLAN.difundir("duelo", {"fase": "avance", "avance": int(_duelo.avance)})
	if absi(int(_duelo.avance)) >= 14:
		_terminar_duelo(int(_duelo.primero) if int(_duelo.avance) > 0 else int(_duelo.segundo))
	return {"ok": true}

func _terminar_duelo(ganador: int) -> void:
	if _duelo.is_empty():
		return
	var perdedor := 0
	if ganador != 0 and _duelo.has("segundo"):
		perdedor = int(_duelo.segundo) if ganador == int(_duelo.primero) else int(_duelo.primero)
	_duelo.clear()
	SesionLAN.difundir("duelo", {"fase": "fin", "ganador": ganador, "perdedor": perdedor})

func _aplicar_duelo(datos: Dictionary) -> void:
	var fase := str(datos.get("fase", ""))
	if fase == "espera":
		_mostrar_duelo("DUELO KAMEHAMEHA · 5 s para aceptar en la ruleta")
	elif fase == "choque":
		if not SesionLAN.es_anfitrion():
			_duelo = {"fase": "choque", "primero": int(datos.primero), "segundo": int(datos.segundo), "avance": 0}
		for id: int in [int(datos.primero), int(datos.segundo)]:
			var j: Player = jugadores.get(id)
			var rival: Player = jugadores.get(int(datos.segundo) if id == int(datos.primero) else int(datos.primero))
			if is_instance_valid(j) and is_instance_valid(j.gestos) and is_instance_valid(rival):
				j.input_locked = true
				j.velocity = Vector3.ZERO
				j.gestos.iniciar_duelo_kamehameha(rival)
				j.gestos.actualizar_choque_duelo(j.global_position.lerp(rival.global_position, 0.5) + Vector3.UP * 0.7)
				var direccion: Vector3 = rival.global_position - j.global_position
				j.visual.rotation.y = atan2(direccion.x, direccion.z)
		_mostrar_duelo("¡CARGANDO KAMEHAMEHA!")
		get_tree().create_timer(1.8).timeout.connect(_mostrar_pulsos_duelo)
	elif fase == "avance":
		_duelo.avance = int(datos.avance)
	elif fase == "fin":
		for jugador_duelo: int in jugadores:
			var actor: Player = jugadores[jugador_duelo]
			if is_instance_valid(actor) and is_instance_valid(actor.gestos) and actor.gestos.gesto == &"kamehameha":
				actor.cancelar_gesto()
				actor.input_locked = false
		var perdedor := int(datos.get("perdedor", 0))
		if perdedor != 0 and jugadores.has(perdedor):
			var j: Player = jugadores[perdedor]
			j.cancelar_gesto()
			if is_instance_valid(j.gestos):
				j.gestos.mostrar_impacto_duelo(j.global_position + Vector3.UP)
			if perdedor == SesionLAN.id_local():
				var ganador: Player = jugadores.get(int(datos.ganador))
				var direccion := (j.global_position - ganador.global_position).normalized() if is_instance_valid(ganador) else Vector3.FORWARD
				j.velocity = direccion * 9.0 + Vector3.UP * 7.0
		_mostrar_duelo("¡IMPACTO!" if perdedor != 0 else "Duelo cancelado")
		_duelo.clear()
		get_tree().create_timer(2.0).timeout.connect(_ocultar_duelo)

func _actualizar_visual_duelo() -> void:
	if _duelo.get("fase", "") != "choque":
		return
	var a: Player = jugadores.get(int(_duelo.primero))
	var b: Player = jugadores.get(int(_duelo.segundo))
	if is_instance_valid(a) and is_instance_valid(b):
		var punto: Vector3 = a.global_position.lerp(b.global_position, 0.5 + float(_duelo.avance) / 32.0) + Vector3.UP * 0.7
		for j: Player in [a, b]:
			if is_instance_valid(j.gestos) and j.gestos.duelo_kamehameha_activo:
				j.gestos.actualizar_choque_duelo(punto)

func _mostrar_duelo(mensaje: String) -> void:
	if not is_instance_valid(_duelo_aviso):
		_duelo_aviso = Label.new()
		_duelo_aviso.add_theme_font_size_override("font_size", 26)
		_duelo_aviso.add_theme_color_override("font_color", Color(1, 0.9, 0.55))
		_duelo_aviso.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_duelo_aviso.position = Vector2(-330, 100)
		_duelo_aviso.custom_minimum_size.x = 660
		_duelo_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		oficina.get_node("CanvasLayer").add_child(_duelo_aviso)
	_duelo_aviso.text = mensaje
	_duelo_aviso.show()

func _ocultar_duelo() -> void:
	if is_instance_valid(_duelo_aviso):
		_duelo_aviso.hide()

func _mostrar_pulsos_duelo() -> void:
	if _duelo.get("fase", "") == "choque":
		_mostrar_duelo("¡CHOQUE! Pulsa ESPACIO o A rápidamente")

func _input(event: InputEvent) -> void:
	if _duelo.get("fase", "") != "choque" or get_tree().paused:
		return
	if (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A) or (event is InputEventAction and event.pressed and event.action == &"policia_prueba_saltar"):
		SesionLAN.solicitar("duelo_pulso", {})
		get_viewport().set_input_as_handled()

func preparar_salida() -> void:
	_listo = false
	_sismo_pendiente.clear()
	_sismo_listos.clear()
	oficina.evento_terremoto.cancelar_preparacion()
	_duelo.clear()
	if is_instance_valid(_duelo_aviso):
		_duelo_aviso.queue_free()
	set_process(false)
	oficina.get_node("MaquinaExpendedora").poderes.limpiar()
	for tween: Tween in get_tree().get_processed_tweens():
		tween.kill()
	for j: Player in jugadores.values():
		j.cancelar_gesto()
		j.input_locked = true
		j.set_physics_process(false)
	oficina.set_process(false)
	oficina.set_physics_process(false)
	despacho.set_process(false)

func _actualizar_objetos_remotos() -> void:
	for id: int in jugadores:
		if id == SesionLAN.id_local():
			continue
		var j: Player = jugadores[id]
		var activo := despacho.esta_activo(id)
		var tiene_cafe := bool(cafes.get(id, false)) and activo
		var bebiendo: bool = activo and is_instance_valid(j.gestos) and j.gestos.gesto == &"beber"
		if not _capsulas_remotas.has(id):
			var capsula := preload("res://Eventos/Hielo/capsula_hielo.gd").new()
			capsula.jugador = j
			oficina.add_child(capsula)
			_capsulas_remotas[id] = capsula
		var indice_taza := int(tazas_cafe.get(id, 0))
		if _tazas_remotas.has(id) and int(_tazas_remotas[id].get_meta("indice_taza", 0)) != indice_taza:
			_tazas_remotas[id].queue_free()
			_tazas_remotas.erase(id)
		if tiene_cafe and not _tazas_remotas.has(id):
			var descanso: Node = oficina.get_node("ZonaDescanso")
			if not descanso._tazas.is_empty():
				var taza: Node3D = descanso._tazas[clampi(indice_taza, 0, descanso._tazas.size() - 1)].duplicate()
				taza.set_meta("indice_taza", indice_taza)
				j.anclaje_taza().add_child(taza)
				taza.position = Vector3.ZERO
				taza.rotation = Vector3.ZERO
				taza.scale = Vector3.ONE / j.anclaje_taza().global_basis.get_scale()
				taza.show()
				var contenido_nuevo := taza.get_node("ContenidoCafe") as MeshInstance3D
				# Cada jugador vacía su propia taza, sin alterar el material del mueble.
				contenido_nuevo.material_override = contenido_nuevo.material_override.duplicate()
				_tazas_remotas[id] = taza
		if not tiene_cafe and not bebiendo and _tazas_remotas.has(id):
			_tazas_remotas[id].queue_free()
			_tazas_remotas.erase(id)
		if _tazas_remotas.has(id):
			var contenido := _tazas_remotas[id].get_node("ContenidoCafe") as MeshInstance3D
			contenido.visible = tiene_cafe
			if tiene_cafe and bebiendo:
				CONTENIDO_CAFE.actualizar_sorbo(contenido, j.gestos.tiempo / j.gestos.duracion)
			else:
				CONTENIDO_CAFE.establecer_llenado(contenido, 1.0 if tiene_cafe else 0.0)
		# Conserva el agarre de la taza vacía hasta que el brazo termina de bajar.
		j.establecer_taza_en_mano(_tazas_remotas.has(id))


var _cambio_interfaz := false

func _actualizar_casos(casos: Array) -> void:
	var presentes := {}
	for dato: Dictionary in casos:
		var id := str(dato.id)
		presentes[id] = true
		if _casos_recibidos.get(id, {}) == dato:
			continue
		_cambio_interfaz = true
		var caso := despacho.arbol.buscar_por_id(id)
		if caso == null:
			caso = _leer_caso(dato)
			despacho.arbol.insertar(caso)
		else:
			var reordenar: bool = caso.nivel_riesgo != dato.nivel_riesgo or caso.hora_reporte != dato.hora_reporte
			if reordenar:
				despacho.arbol.eliminar_por_id(id)
			for campo: String in CAMPOS_CASO:
				if campo in ["protocolo_estaciones", "estaciones_completadas"]:
					caso.get(campo).assign(dato[campo])
				else:
					caso.set(campo, dato[campo])
			if reordenar:
				despacho.arbol.insertar(caso)
		_casos_recibidos[id] = dato.duplicate(true)
	for id: String in _casos_recibidos.keys():
		if not presentes.has(id):
			despacho.arbol.eliminar_por_id(id)
			_casos_recibidos.erase(id)
			_cambio_interfaz = true

func _registrar_final(caso: Denuncia, tipo: String) -> void:
	if not SesionLAN.es_anfitrion():
		return
	_numero_final += 1
	_finales_pendientes.append({"numero": _numero_final, "tipo": tipo, "caso": _serializar_caso(caso).duplicate(true)})

func confirmar_finales(numero: int) -> void:
	if numero > _numero_final:
		return
	while not _finales_pendientes.is_empty() and int(_finales_pendientes[0].numero) <= numero:
		_finales_pendientes.pop_front()

func _enviar_estado(actual: Dictionary) -> void:
	var completo := _estado_enviado.is_empty() or _revision % 20 == 0
	var paquete := {"revision": _revision, "completo": completo, "finales": _finales_pendientes}
	if completo:
		paquete.datos = actual
		snapshots_completos += 1
	else:
		var cambios := {}
		for clave in actual:
			if actual[clave] != _estado_enviado.get(clave):
				cambios[clave] = actual[clave]
		paquete.base = int(_estado_enviado.revision)
		paquete.datos = cambios
		snapshots_delta += 1
	_estado_enviado = actual.duplicate(true)
	if "--perfil" in OS.get_cmdline_user_args():
		bytes_estado += var_to_bytes(paquete).size()
	SesionLAN.publicar(paquete)

func recibir_estado(paquete: Dictionary) -> void:
	if int(paquete.revision) <= _revision_recibida:
		return
	if paquete.completo:
		_estado_recibido = paquete.datos.duplicate(true)
	elif int(paquete.base) == _base_recibida:
		_estado_recibido.merge(paquete.datos, true)
	else:
		SesionLAN.pedir_estado_completo()
		return
	_base_recibida = int(paquete.revision)
	var resueltos := {}
	var vencidos := {}
	for final: Dictionary in paquete.finales:
		if int(final.numero) <= _ultimo_final:
			continue
		_ultimo_final = int(final.numero)
		if final.tipo == "resuelto":
			resueltos[str(final.caso.id)] = final.caso
		else:
			vencidos[str(final.caso.id)] = final.caso
	_estado_recibido.resueltos = resueltos
	_estado_recibido.vencidos = vencidos
	aplicar(_estado_recibido)
	# La revisión monotónica evita duplicados; no conservar historial por caso.
	_resueltos.clear()
	_vencidos.clear()
	if not paquete.finales.is_empty():
		SesionLAN.confirmar_finales(_ultimo_final)
