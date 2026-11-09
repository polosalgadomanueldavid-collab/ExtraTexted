extends SceneTree
## Ejecutar con --headless --path <proyecto> --script res://Pruebas/Apagon/prueba_apagon_smoke.gd.
## Sin --headless, añadir -- --capturas para guardar las vistas del piloto.

const ESCENA_PRUEBA := "res://Pruebas/Apagon/PruebaApagon.tscn"
const DIRECTORIO_CAPTURAS := "res://.godot/apagon_qa"
const TIPOS_CIRCUITO := [0, 2, 3]

var _errores: Array[String] = []
var _comprobaciones: int = 0
var _restauraciones: int = 0
var _escena: Node3D
var _evento: Node
var _jugador: CharacterBody3D
var _taco: StaticBody3D
var _camara: Camera3D
var _panel: Control
var _despacho: SistemaDespacho
var _saldo_inicial: int
var _altura_pies: float
var _postura: Dictionary = {}
var _luces_iniciales: Dictionary = {}


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	var principal_inicial: String = ProjectSettings.get_setting("application/run/main_scene", "")
	var recurso := load(ESCENA_PRUEBA) as PackedScene
	if recurso == null:
		push_error("No se pudo cargar el piloto de apagón.")
		quit(1)
		return
	_escena = recurso.instantiate() as Node3D
	root.add_child(_escena)
	current_scene = _escena
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	await _fisicas(60)
	_jugador = _escena.get_node("Jugador") as CharacterBody3D
	_evento = _escena.get_node("EventoApagon")
	_taco = _escena.get_node("TacoLuz") as StaticBody3D
	_camara = _escena.get_node("Camara") as Camera3D
	_panel = _evento.get("panel") as Control
	var tipos: Array = _evento.get_script().get_script_constant_map().get("TIPOS_DISPONIBLES", [])
	tipos = tipos.duplicate()
	tipos.sort()
	_verificar(tipos == TIPOS_CIRCUITO, "El evento ofrece exclusivamente interruptores, fases y cables")
	_verificar(_jugador.is_on_floor(), "El personaje inicia sobre el suelo real del piloto")
	_altura_pies = _jugador.global_position.y
	_jugador.set_physics_process(false)
	_evento.connect("luz_restaurada", _contar_restauracion)
	_preparar_saldo()
	_verificar(int(_evento.get("estado")) == 0, "El piloto comienza con luz restaurada")
	_verificar(not (_evento.get("mascara") as ColorRect).visible, "La visión limitada comienza oculta")
	_verificar(not _panel.visible, "El circuito comienza cerrado")
	await _capturar("00_laboratorio")
	_guardar_luces()
	for tipo: int in TIPOS_CIRCUITO:
		await _probar_circuito(tipo)
	_verificar(_restauraciones == 3, "Cada uno de los tres circuitos restaura la luz una vez")
	_verificar(_despacho.puntuacion.puntos == _saldo_inicial, "Resolver los circuitos conserva el saldo de denuncias")
	_verificar(str(ProjectSettings.get_setting("application/run/main_scene", "")) == principal_inicial, "El piloto conserva la escena principal configurada")
	await _probar_salida_durante_apagon()
	await _esperar_audio_al_salir()
	print("[APAGON SMOKE] %d comprobaciones, %d errores." % [_comprobaciones, _errores.size()])
	quit(0 if _errores.is_empty() else 1)


func _preparar_saldo() -> void:
	_despacho = SistemaDespacho.new()
	_escena.add_child(_despacho)
	var denuncia := Denuncia.new()
	denuncia.id = "SALDO-ANTES-DEL-APAGON"
	denuncia.nivel_riesgo = 3
	_verificar(_despacho.recibir_denuncia(denuncia), "El despacho recibe una denuncia para comprobar su saldo")
	_verificar(_despacho.resolver_denuncia(denuncia.id), "La denuncia normal genera su recompensa")
	_saldo_inicial = _despacho.puntuacion.puntos
	_verificar(_saldo_inicial == 300, "La recompensa inicial corresponde al sistema real de puntuación")


func _guardar_luces() -> void:
	var luces: Array = _evento.get("luces")
	_verificar(not luces.is_empty(), "El evento tiene luces de escenario conectadas")
	for indice: int in range(luces.size()):
		var luz := luces[indice] as Light3D
		luz.light_energy += float(indice + 1) * 0.125
		if luces.size() > 1 and indice == luces.size() - 1:
			luz.visible = false
		_luces_iniciales[luz] = {"visible": luz.visible, "energia": luz.light_energy}


func _probar_circuito(tipo: int) -> void:
	if tipo == 0:
		await _pulsar_tecla(KEY_B)
		_verificar(int(_evento.get("estado")) == 1, "La tecla B normal inicia el apagón del piloto")
	elif tipo == 2:
		(_escena.get("boton_apagon") as Button).pressed.emit()
		await process_frame
		_verificar(int(_evento.get("estado")) == 1, "El botón del piloto inicia un apagón")
	else:
		_verificar(bool(_evento.call("iniciar_apagon")), "El circuito %d inicia un apagón" % tipo)
	_verificar(int(_evento.get("estado")) == 1, "Iniciar cambia al estado APAGADO")
	_verificar(int(_evento.get("tipo_circuito")) in TIPOS_CIRCUITO, "La selección aleatoria elige uno de los tres circuitos disponibles")
	var semilla: int = _evento.get("semilla_circuito")
	var elegido: int = _evento.get("tipo_circuito")
	_verificar(not bool(_evento.call("iniciar_apagon")), "Un apagón activo rechaza un segundo inicio")
	_verificar(int(_evento.get("semilla_circuito")) == semilla and int(_evento.get("tipo_circuito")) == elegido, "Repetir inicio conserva el circuito elegido")
	_evento.set("tipo_circuito", tipo)
	_evento.set("semilla_circuito", 731 + tipo)
	for luz: Light3D in _luces_iniciales:
		_verificar(not luz.visible, "El apagón oculta cada luz conectada")
	_verificar((_evento.get("mascara") as ColorRect).visible, "El apagón activa la máscara de visión")
	_verificar((_evento.get("luz_jugador") as OmniLight3D).visible, "El apagón activa la luz de emergencia")
	if tipo == 0:
		await _probar_vision()
		_postura = _buscar_postura()
		_verificar(not _postura.is_empty(), "El ShapeCast3D real alcanza el taco desde el suelo")
		if _postura.is_empty():
			return
		await _probar_alcance()
	if _postura.is_empty():
		return
	_colocar(_postura["cerca"], float(_postura["giro"]))
	await _pulsar_tecla(KEY_E)
	_verificar(int(_evento.get("estado")) == 2 and _panel.visible, "La tecla E normal abre el circuito %d" % tipo)
	_verificar(_jugador.input_locked, "Abrir el circuito bloquea el movimiento del jugador")
	_verificar(not paused, "El panel del circuito conserva el árbol activo")
	_verificar(not bool(_evento.call("iniciar_apagon")), "Reparar un circuito rechaza un segundo apagón")
	if not _panel.visible:
		return
	await _esperar_entrada()
	await _probar_reapertura(tipo)
	await _capturar("02_circuito_%d" % tipo)
	await _resolver_circuito(tipo)
	await _cuadros(3)
	_verificar(int(_evento.get("estado")) == 0, "Resolver el circuito %d restaura el estado" % tipo)
	_verificar(not _panel.visible and not _jugador.input_locked, "Resolver cierra el panel y devuelve el control")
	_verificar(not (_evento.get("mascara") as ColorRect).visible, "Resolver retira la máscara de visión")
	_verificar(not (_evento.get("luz_jugador") as OmniLight3D).visible, "Resolver oculta la luz de emergencia")
	_comprobar_luces()
	_verificar(_despacho.puntuacion.puntos == _saldo_inicial, "El circuito %d conserva el saldo acumulado" % tipo)
	await _capturar("03_restaurado_%d" % tipo)


func _probar_vision() -> void:
	var material := (_evento.get("mascara") as ColorRect).material as ShaderMaterial
	var posicion_inicial := _jugador.global_position
	await _cuadros(2)
	var centro_inicial: Vector2 = material.get_shader_parameter("centro_uv")
	_jugador.global_position += Vector3(0.6, 0.0, 0.0)
	await _cuadros(2)
	var centro: Vector2 = material.get_shader_parameter("centro_uv")
	var esperado := _camara.unproject_position(_jugador.global_position + Vector3.UP * 0.4) / root.get_visible_rect().size
	_verificar(centro.distance_to(esperado) < 0.001, "La máscara se centra en la proyección del jugador")
	_verificar(centro.distance_to(centro_inicial) > 0.001, "Mover al jugador desplaza la visión limitada")
	_verificar(float(material.get_shader_parameter("radio_pixeles")) > 1.0, "El radio de visión se proyecta en píxeles")
	var emergencia := _evento.get("luz_jugador") as OmniLight3D
	_verificar(emergencia.global_position.is_equal_approx(_jugador.global_position + Vector3.UP * 1.4), "La luz de emergencia sigue al jugador")
	_jugador.global_position = posicion_inicial
	await _cuadros(2)
	await _capturar("01_apagon")


func _buscar_postura() -> Dictionary:
	var centro := _taco.global_position
	centro.y = _altura_pies
	for direccion: Vector3 in [Vector3.BACK, Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT]:
		var giro := atan2(-direccion.x, -direccion.z)
		for paso: int in range(151):
			var candidato := centro + direccion * (1.6 - float(paso) * 0.01)
			_colocar(candidato, giro)
			if _jugador.obtener_objetivo_interaccion() == _taco:
				return {"cerca": candidato, "lejos": candidato + direccion * 2.0, "giro": giro}
	return {}


func _probar_alcance() -> void:
	_colocar(_postura["lejos"], float(_postura["giro"]))
	await _pulsar_tecla(KEY_E)
	_verificar(_jugador.obtener_objetivo_interaccion() != _taco and not _panel.visible, "E fuera del alcance físico conserva el circuito cerrado")
	_colocar(_postura["cerca"], float(_postura["giro"]) + PI)
	await _pulsar_tecla(KEY_E)
	_verificar(_jugador.obtener_objetivo_interaccion() != _taco and not _panel.visible, "E mirando en dirección contraria conserva el circuito cerrado")
	_colocar(_postura["cerca"], float(_postura["giro"]))
	_verificar(_jugador.obtener_objetivo_interaccion() == _taco, "Mirar hacia el taco devuelve el objetivo real de E")


func _probar_reapertura(tipo: int) -> void:
	await _hacer_progreso(tipo)
	# Congela únicamente la simulación de anillos durante la comparación exacta.
	_panel.set_process(false)
	var anterior: Dictionary = _panel.call("obtener_estado")
	await _pulsar_tecla(KEY_ESCAPE)
	_verificar(int(_evento.get("estado")) == 1 and not _panel.visible, "Escape cierra el circuito y mantiene el apagón")
	_verificar(not _jugador.input_locked, "Cerrar el circuito devuelve el control al jugador")
	_verificar(not paused, "Escape del circuito conserva cerrada la pausa global")
	await _pulsar_tecla(KEY_E)
	var actual: Dictionary = _panel.call("obtener_estado")
	_verificar(_panel.visible and actual == anterior, "Reabrir conserva el circuito y su progreso")
	_panel.set_process(true)
	await _esperar_entrada()


func _hacer_progreso(tipo: int) -> void:
	var estado: Dictionary = _panel.call("obtener_estado")
	match tipo:
		0:
			var interruptores: Array = _panel.get("interruptores")
			_verificar(interruptores.size() == 5, "El primer circuito presenta cinco interruptores")
			(interruptores[0] as Button).button_pressed = true
			await create_timer(0.25).timeout
			_verificar(int(_evento.get("estado")) == 2, "Un interruptor activo conserva incompleto el circuito")
			(interruptores[0] as Button).button_pressed = false
			await create_timer(0.25).timeout
			_verificar(not bool((_panel.call("obtener_estado") as Dictionary).interruptores[0]), "Un interruptor puede volver al estado apagado")
			(interruptores[0] as Button).button_pressed = true
			await create_timer(0.25).timeout
		2:
			var botones: Array = _panel.get("botones_anillos")
			_verificar(botones.size() == 3, "El tercer circuito presenta tres anillos")
			await _esperar_anillo(0, false)
			(botones[0] as Button).pressed.emit()
			_verificar(not bool((_panel.call("obtener_estado") as Dictionary).fijados[0]), "Pulsar fuera del arco verde rechaza la sincronización")
			await _esperar_anillo(0, true)
			(botones[0] as Button).pressed.emit()
			_verificar(bool((_panel.call("obtener_estado") as Dictionary).fijados[0]), "Pulsar dentro del arco verde fija el primer anillo")
		3:
			var origenes: Array = _panel.get("origenes_cables")
			var destinos: Array = _panel.get("destinos_cables")
			_verificar(origenes.size() == 4 and destinos.size() == 4, "El cuarto circuito presenta cuatro pares de cable")
			(destinos[0] as Button).pressed.emit()
			_verificar((_panel.call("obtener_estado") as Dictionary).conexiones == [-1, -1, -1, -1], "Un destino sin origen seleccionado conserva los cables libres")
			(origenes[0] as Button).pressed.emit()
			var fila_correcta: int = estado.destinos.find(0)
			(destinos[(fila_correcta + 1) % 4] as Button).pressed.emit()
			_verificar(int((_panel.call("obtener_estado") as Dictionary).conexiones[0]) == -1, "Un destino de identidad distinta rechaza el cable")
			(destinos[fila_correcta] as Button).pressed.emit()
			await create_timer(0.25).timeout
			_verificar(int((_panel.call("obtener_estado") as Dictionary).conexiones[0]) == fila_correcta, "El cable acepta el destino del mismo color")
	var parcial: Dictionary = _panel.call("obtener_estado")
	_verificar(not bool(parcial.resuelto), "El progreso parcial conserva el circuito %d pendiente" % tipo)


func _resolver_circuito(tipo: int) -> void:
	var estado: Dictionary = _panel.call("obtener_estado")
	match tipo:
		0:
			var interruptores: Array = _panel.get("interruptores")
			for interruptor: Button in interruptores:
				interruptor.button_pressed = true
		2:
			var botones: Array = _panel.get("botones_anillos")
			for indice: int in range(3):
				if bool(estado.fijados[indice]):
					continue
				await _esperar_anillo(indice, true)
				(botones[indice] as Button).pressed.emit()
		3:
			var origenes: Array = _panel.get("origenes_cables")
			var destinos: Array = _panel.get("destinos_cables")
			for origen: int in range(4):
				if int(estado.conexiones[origen]) >= 0:
					continue
				(origenes[origen] as Button).pressed.emit()
				(destinos[int(estado.destinos.find(origen))] as Button).pressed.emit()
	await create_timer(0.95).timeout
	_verificar(bool((_panel.call("obtener_estado") as Dictionary).resuelto), "Los controles reales completan el circuito %d" % tipo)


func _esperar_anillo(indice: int, dentro: bool) -> void:
	var limite := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < limite:
		var estado: Dictionary = _panel.call("obtener_estado")
		var distancia := absf(angle_difference(float(estado.fases[indice]), float(estado.objetivos[indice])))
		if (dentro and distancia < 0.25) or (not dentro and distancia > 0.7):
			return
		await process_frame
	_verificar(false, "El anillo %d alcanza la fase solicitada en doce segundos" % indice)


func _comprobar_luces() -> void:
	for luz: Light3D in _luces_iniciales:
		var inicial: Dictionary = _luces_iniciales[luz]
		_verificar(luz.visible == bool(inicial["visible"]), "Restaurar recupera la visibilidad anterior de cada luz")
		_verificar(is_equal_approx(luz.light_energy, float(inicial["energia"])), "Restaurar conserva la energía anterior de cada luz")


func _probar_salida_durante_apagon() -> void:
	_verificar(bool(_evento.call("iniciar_apagon")), "Puede iniciarse otro apagón después de tres reparaciones")
	if not _postura.is_empty():
		_colocar(_postura["cerca"], float(_postura["giro"]))
		await _pulsar_tecla(KEY_E)
		_verificar(_jugador.input_locked, "La salida del evento se prueba con una interacción abierta")
	_escena.set_process(false)
	_escena.remove_child(_evento)
	_comprobar_luces()
	_verificar(not _jugador.input_locked, "Retirar el evento devuelve el control del jugador")
	_verificar(not bool(_taco.get("apagon_activo")) and not bool(_taco.get("abierto")), "Retirar el evento restaura el estado del taco y cierra su tapa")
	_evento.free()
	_escena.queue_free()
	await process_frame


func _contar_restauracion() -> void:
	_restauraciones += 1


func _colocar(posicion: Vector3, giro: float) -> void:
	_jugador.global_position = posicion
	_jugador.visual.rotation.y = giro
	_jugador.velocity = Vector3.ZERO


func _pulsar_tecla(tecla: Key) -> void:
	var pulsacion := InputEventKey.new()
	pulsacion.physical_keycode = tecla
	pulsacion.keycode = tecla
	pulsacion.pressed = true
	Input.parse_input_event(pulsacion)
	await process_frame
	var liberacion := InputEventKey.new()
	liberacion.physical_keycode = tecla
	liberacion.keycode = tecla
	liberacion.pressed = false
	Input.parse_input_event(liberacion)
	await process_frame


func _fisicas(cantidad: int) -> void:
	for cuadro: int in range(cantidad):
		await physics_frame
		await process_frame


func _cuadros(cantidad: int) -> void:
	for cuadro: int in range(cantidad):
		await process_frame


func _esperar_entrada() -> void:
	await create_timer(0.55).timeout


func _esperar_audio_al_salir() -> void:
	# --fixed-fps acelera el tiempo del juego; el mezclador libera las voces en tiempo real.
	var limite := Time.get_ticks_msec() + 500
	while Time.get_ticks_msec() < limite:
		await process_frame


func _capturar(nombre: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--capturas" in OS.get_cmdline_user_args():
		return
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(DIRECTORIO_CAPTURAS)
	var resultado := root.get_texture().get_image().save_png(DIRECTORIO_CAPTURAS.path_join(nombre + ".png"))
	_verificar(resultado == OK, "Se guarda la captura " + nombre)


func _verificar(condicion: bool, descripcion: String) -> void:
	_comprobaciones += 1
	if not condicion:
		_errores.append(descripcion)
		push_error("[APAGON SMOKE] " + descripcion)
