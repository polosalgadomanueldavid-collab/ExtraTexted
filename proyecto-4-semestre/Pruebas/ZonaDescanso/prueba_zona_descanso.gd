extends SceneTree
## Ejecutar con --headless --fixed-fps 60 --script res://Pruebas/ZonaDescanso/prueba_zona_descanso.gd.
## Comprueba medidas, apoyo, paso del jugador y navegación en la oficina real.

const OFICINA := "res://Mundo/Oficina.tscn"
const GRUPO_OBSTACULOS := &"obstaculos_navegacion"
const PUNTOS_LIBRES := [Vector2(-3.25, 7.65), Vector2(-4.05, 9.2), Vector2(-3.3, 10.5)]

var _errores: Array[String] = []
var _comprobaciones: int = 0
var _escena: Node3D
var _zona: Node3D
var _jugador: CharacterBody3D
var _grafo: GrafoPiso
var _altura_piso: float


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var configuracion_inicial: String = ProjectSettings.get_setting("application/run/main_scene", "")
	var nodos_antes := get_nodes_in_group(GRUPO_OBSTACULOS).size()
	for carga: int in range(2):
		_escena = (load(OFICINA) as PackedScene).instantiate() as Node3D
		root.add_child(_escena)
		current_scene = _escena
		await _cuadros(3)
		root.get_node("MenuGlobal").call("cerrar_ayuda")
		paused = false
		for nombre: String in ["temporizador_denuncias", "temporizador_bloqueos"]:
			(_escena.get(nombre) as Timer).stop()
		var computador: Node = _escena.get("computador")
		(computador.get("timer_nuevo_problema") as Timer).stop()
		await _fisicas(45)
		_zona = _escena.get_node_or_null("ZonaDescanso") as Node3D
		_verificar(_zona != null, "La oficina carga la zona de descanso en la entrada %d" % carga)
		if _zona == null:
			await _descargar()
			continue
		_jugador = _escena.get("jugador") as CharacterBody3D
		_grafo = _escena.get("grafo_piso") as GrafoPiso
		var piso := _escena.get_node("Pared, suelo, techo/Suelo") as CSGBox3D
		var limites_piso: AABB = piso.global_transform * AABB(-piso.size * 0.5, piso.size)
		_altura_piso = limites_piso.end.y
		_verificar(_jugador.is_on_floor(), "El jugador aterriza normalmente con los muebles nuevos")
		_jugador.set_physics_process(false)
		if carga == 0:
			_probar_medidas_y_apoyo()
			_probar_estructura_estatica()
			await _probar_colisiones_y_paso()
			await _probar_navegacion()
		else:
			_verificar(get_nodes_in_group(GRUPO_OBSTACULOS).size() == nodos_antes + 3, "Reentrar carga solo las tres formas físicas previstas")
		var referencia: WeakRef = weakref(_zona)
		await _descargar()
		_verificar(referencia.get_ref() == null, "Salir libera la instancia de descanso sin dejarla persistente")
		_verificar(get_nodes_in_group(GRUPO_OBSTACULOS).size() == nodos_antes, "Salir retira las formas del grupo de navegación")
	_verificar(str(ProjectSettings.get_setting("application/run/main_scene", "")) == configuracion_inicial, "La integración conserva el menú como escena inicial")
	var limite := Time.get_ticks_msec() + 500
	while Time.get_ticks_msec() < limite:
		await process_frame
	print("[ZONA DESCANSO] %d comprobaciones, %d errores." % [_comprobaciones, _errores.size()])
	quit(0 if _errores.is_empty() else 1)


func _probar_medidas_y_apoyo() -> void:
	var mueble := _zona.get_node("RinconCafe/MuebleCafeVisual") as MeshInstance3D
	var cafetera := _zona.get_node("RinconCafe/Cafetera") as Node3D
	var limites_mueble := _limites_visuales(mueble)
	var limites_cafe := _limites_visuales(cafetera)
	_verificar(absf(limites_mueble.position.y - _altura_piso) < 0.005, "El mueble está apoyado sobre el suelo real")
	_verificar(absf(limites_cafe.position.y - limites_mueble.end.y) < 0.008, "La cafetera apoya en el tablero sin flotar ni hundirse")
	_verificar(_huella_contiene(limites_mueble, limites_cafe), "La cafetera cabe completa sobre el mueble")
	_verificar(limites_cafe.size.y > 0.30 and limites_cafe.size.y < 0.50, "La cafetera mantiene una escala de sobremesa")
	for nombre: String in ["TazaAmarilla", "TazaBlanca"]:
		var taza := _zona.get_node("RinconCafe/" + nombre) as MeshInstance3D
		var limites := _limites_visuales(taza)
		_verificar(absf(limites.position.y - limites_mueble.end.y) < 0.004, "La %s se apoya sobre el tablero" % nombre)
		_verificar(_huella_contiene(limites_mueble, limites), "La %s queda dentro del tablero" % nombre)
		_verificar(limites.size.y > 0.07 and limites.size.y < 0.11, "La %s conserva el tamaño original del pack" % nombre)
	var limites_sofa := _limites_visuales(_zona.get_node("SofaL") as Node3D)
	_verificar(absf(limites_sofa.position.y - _altura_piso) < 0.005, "El sofá se apoya en el suelo real")
	_verificar(limites_sofa.size.x > 1.30 and limites_sofa.size.x < 1.55 and limites_sofa.size.z > 1.30 and limites_sofa.size.z < 1.55, "La composición en L ocupa una huella compacta y proporcionada")
	_verificar(limites_sofa.position.x > -4.40 and limites_mueble.position.x > -4.40, "Los muebles quedan delante de la pared, sin atravesarla")
	_verificar(limites_sofa.end.z < limites_mueble.position.z - 1.5, "El hueco entre sofá y cafetera reserva espacio para la expendedora")


func _probar_estructura_estatica() -> void:
	var mallas := _zona.find_children("*", "MeshInstance3D", true, false)
	_verificar(mallas.size() >= 6 and mallas.size() <= 10, "La zona solo instancia sus mallas necesarias, sin cargar todos los muebles del pack")
	_verificar(_zona.find_children("*", "CollisionShape3D", true, false).size() == 3, "El mobiliario usa tres colisiones sencillas")
	for nodo: Node in _zona.find_children("*", "", true, false):
		_verificar(not nodo.is_processing() and not nodo.is_physics_processing(), "El nodo estático %s no añade trabajo por cuadro" % nodo.name)
	for forma: CollisionShape3D in get_nodes_in_group(GRUPO_OBSTACULOS):
		if _zona.is_ancestor_of(forma):
			_verificar(forma.shape is BoxShape3D and forma.get_parent() is StaticBody3D, "El obstáculo de descanso usa una caja física estática")
			_verificar(not forma.disabled and ((forma.get_parent() as StaticBody3D).collision_layer & _jugador.collision_mask) != 0, "La caja física interactúa con la máscara real del jugador")


func _probar_colisiones_y_paso() -> void:
	var puntos_bloqueados := [Vector2(-4.0, 10.5), Vector2(-4.05, 7.65), Vector2(-3.3, 6.95)]
	for punto: Vector2 in puntos_bloqueados:
		_verificar(not _cabe_jugador(punto), "El jugador no puede ocupar el volumen del mueble en %s" % punto)
	for punto: Vector2 in PUNTOS_LIBRES:
		_verificar(_cabe_jugador(punto), "El jugador cabe en el acceso de descanso %s" % punto)
	var posicion_original := _jugador.global_position
	(_escena.get_node("Gameplay/Camera3D") as Node3D).set_physics_process(false)
	var colision := _jugador.get_node("Colision") as CollisionShape3D
	var limites_jugador: AABB = colision.global_transform * colision.shape.get_debug_mesh().get_aabb()
	var semiancho := limites_jugador.size.x * 0.5
	var frente_cafe := _limites_visuales(_zona.get_node("RinconCafe/MuebleCafeVisual") as Node3D).end.x
	var cafe := await _caminar_desde(Vector2(-3.0, 10.5), 120)
	_verificar(cafe.x >= frente_cafe + semiancho - 0.02 and cafe.x < frente_cafe + semiancho + 0.06, "Caminar normalmente hacia el mueble detiene al jugador frente a su colisión")
	_verificar(_jugador.is_on_floor(), "El jugador continúa sobre el suelo después de empujar el mueble")
	var frente_sofa := _limites_visuales(_zona.get_node("SofaL") as Node3D).end.x
	var sofa := await _caminar_desde(Vector2(-2.5, 6.95), 120)
	_verificar(sofa.x >= frente_sofa + semiancho - 0.03 and sofa.x < frente_sofa + semiancho + 0.06, "Caminar hacia el retorno del sofá detiene al jugador sin atravesarlo")
	var interior := await _caminar_desde(Vector2(-2.5, 7.65), 40)
	_verificar(interior.x < -3.05 and interior.x > -3.50 and _cabe_jugador(Vector2(interior.x, interior.z)), "El movimiento normal permite entrar por el lado abierto de la L")
	_jugador.global_position = posicion_original
	_jugador.velocity = Vector3.ZERO
	for paso: int in range(17):
		var punto := Vector2(-2.5, 7.5 + paso * 0.25)
		_verificar(_cabe_jugador(punto), "El corredor delante del descanso permanece libre en %s" % punto)


func _caminar_desde(punto: Vector2, cuadros: int) -> Vector3:
	_jugador.global_position = Vector3(punto.x, _altura_piso + 0.03, punto.y)
	_jugador.velocity = Vector3.ZERO
	_jugador.set_physics_process(true)
	Input.action_press(&"policia_prueba_izquierda")
	await _fisicas(cuadros)
	Input.action_release(&"policia_prueba_izquierda")
	_jugador.set_physics_process(false)
	return _jugador.global_position


func _probar_navegacion() -> void:
	var celdas: Array[Vector2i] = []
	for punto: Vector2 in PUNTOS_LIBRES:
		celdas.append(_grafo.posicion_a_celda(Vector3(punto.x, _altura_piso, punto.y)))
	var objetivos: Array[Vector2i] = [Vector2i(12, 16)]
	for celda: Vector2i in GrafoPiso.DESTINOS.values():
		objetivos.append(celda)
	for distribucion: int in range(6):
		var azar: RandomNumberGenerator = _escena.get("generador_aleatorio")
		azar.seed = 1560 + distribucion
		_escena.call("_cambiar_bloqueo_temporal")
		await _fisicas(2)
		for indice: int in range(celdas.size()):
			var origen := celdas[indice]
			_verificar(_grafo.es_transitable(origen) and not _grafo.bloqueos_temporales.has(origen), "La distribución %d conserva el acceso %s" % [distribucion, origen])
			for destino: Vector2i in objetivos:
				_verificar(not _grafo.calcular_ruta(origen, destino).is_empty(), "La distribución %d conserva la ruta de %s a %s" % [distribucion, origen, destino])
		for punto: Vector2 in [Vector2(-4.0, 10.5), Vector2(-4.05, 7.65), Vector2(-3.3, 6.95)]:
			var celda := _grafo.posicion_a_celda(Vector3(punto.x, 0, punto.y))
			_verificar(not _grafo.es_transitable(celda), "El grafo respeta el volumen ocupado en %s" % celda)
	_escena.call("_limpiar_bloqueos_temporales")
	await _fisicas(2)


func _cabe_jugador(punto: Vector2) -> bool:
	var colision := _jugador.get_node("Colision") as CollisionShape3D
	var transformacion := _jugador.global_transform
	transformacion.origin = Vector3(punto.x, _altura_piso + 0.015, punto.y)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = colision.shape
	consulta.transform = transformacion * colision.transform
	consulta.collision_mask = _jugador.collision_mask
	consulta.exclude = [_jugador.get_rid()]
	return _escena.get_world_3d().direct_space_state.intersect_shape(consulta).is_empty()


func _limites_visuales(nodo: Node3D) -> AABB:
	var mallas: Array[Node] = nodo.find_children("*", "MeshInstance3D", true, false)
	if nodo is MeshInstance3D:
		mallas.append(nodo)
	var resultado := AABB()
	var iniciado := false
	for malla: MeshInstance3D in mallas:
		var limites: AABB = malla.global_transform * malla.get_aabb()
		resultado = resultado.merge(limites) if iniciado else limites
		iniciado = true
	return resultado


func _huella_contiene(base: AABB, objeto: AABB) -> bool:
	return objeto.position.x >= base.position.x - 0.005 and objeto.end.x <= base.end.x + 0.005 and objeto.position.z >= base.position.z - 0.005 and objeto.end.z <= base.end.z + 0.005


func _descargar() -> void:
	if is_instance_valid(_escena):
		_escena.queue_free()
	await _cuadros(4)


func _cuadros(cantidad: int) -> void:
	for cuadro: int in range(cantidad):
		await process_frame


func _fisicas(cantidad: int) -> void:
	for cuadro: int in range(cantidad):
		await physics_frame
		await process_frame


func _verificar(condicion: bool, descripcion: String) -> void:
	_comprobaciones += 1
	if not condicion:
		_errores.append(descripcion)
		push_error("[ZONA DESCANSO] " + descripcion)
