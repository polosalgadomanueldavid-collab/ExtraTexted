class_name GrafoDebugVisual
extends Node3D

## Capa de diagnóstico para comparar el mapa lógico con las colisiones reales.
## F3 la muestra/oculta. No modifica el grafo ni las colisiones.

const ALTURA: float = 0.055
const ALTURA_ETIQUETA: float = 0.09
const TAMANO_VISUAL: float = GrafoPiso.TAMANO_CELDA * 0.88
# Medida del modelo de mesa estándar; algunas mesas de estación solo tienen
# decoración hija y no exponen su MeshInstance directamente.
const AABB_MESA_ESTANDAR := AABB(Vector3(-0.675, 0.0, -0.3), Vector3(1.35, 0.525, 0.6))

const COLOR_LIBRE := Color("2ecc71", 0.34)
const COLOR_RUTA := Color("00d9ff", 0.68)
const COLOR_DESTINO := Color("ffe066", 0.80)
const COLOR_JUGADOR := Color("ffffff", 0.92)
const COLOR_BLOQUEO_FIJO := Color("e74c3c", 0.72)
const COLOR_BLOQUEO_TEMPORAL := Color("ff8c00", 0.85)
const COLOR_BLOQUEO_SIN_COLISION := Color("ff3eb5", 0.88)

var grafo: GrafoPiso
var jugador: Node3D
var ruta: Array[Vector2i] = []
var visible_debug: bool = true
var _contenedor: Node3D
var _materiales: Dictionary = {}
var _marcador_jugador: MeshInstance3D
var _mesas_fisicas: Array[Dictionary] = []

func configurar(nuevo_grafo: GrafoPiso, nuevo_jugador: Node3D) -> void:
	grafo = nuevo_grafo
	jugador = nuevo_jugador
	_sincronizar_mesas_con_grafo()
	_reconstruir()
	_crear_marcador_jugador()


func actualizar_ruta(nueva_ruta: Array[Vector2i]) -> void:
	ruta = nueva_ruta.duplicate()
	_reconstruir()


func actualizar_mapa() -> void:
	_reconstruir()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		visible_debug = not visible_debug
		visible = visible_debug
		print("[GRAFO DEBUG] Capa visual ", "visible" if visible_debug else "oculta", " (F3).")
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if is_instance_valid(_marcador_jugador) and is_instance_valid(jugador):
		_marcador_jugador.global_position = grafo.celda_a_posicion(
			grafo.posicion_a_celda(jugador.global_position)
		) + Vector3(0.0, ALTURA + 0.012, 0.0)


func _reconstruir() -> void:
	if not is_instance_valid(grafo):
		return

	if is_instance_valid(_contenedor):
		_contenedor.queue_free()

	_contenedor = Node3D.new()
	_contenedor.name = "CasillasDiagnostico"
	add_child(_contenedor)

	var ruta_como_diccionario: Dictionary = {}
	for celda: Vector2i in ruta:
		ruta_como_diccionario[celda] = true

	for fila: int in range(GrafoPiso.FILAS):
		for columna: int in range(GrafoPiso.COLUMNAS):
			var celda := Vector2i(columna, fila)
			var color := _color_de_celda(celda, ruta_como_diccionario)
			_agregar_casilla(celda, color)

			if grafo.bloqueos_fijos.has(celda) and not _hay_mesa_fisica(celda):
				_agregar_etiqueta(celda, "SIN MESA\n%s" % celda)

	print("[GRAFO DEBUG] Leyenda: verde=libre, cian=ruta, amarillo=destino, rojo=bloqueo fijo/de mesa, naranja=bloqueo temporal, rosa=bloqueo lógico sin mesa, blanco=jugador.")


func _color_de_celda(celda: Vector2i, ruta_como_diccionario: Dictionary) -> Color:
	if grafo.bloqueos_temporales.has(celda):
		return COLOR_BLOQUEO_TEMPORAL
	if grafo.bloqueos_fijos.has(celda) or grafo.bloqueos_mesas.has(celda):
		return COLOR_BLOQUEO_FIJO if _hay_mesa_fisica(celda) else COLOR_BLOQUEO_SIN_COLISION
	if GrafoPiso.DESTINOS.values().has(celda):
		return COLOR_DESTINO
	if ruta_como_diccionario.has(celda):
		return COLOR_RUTA
	return COLOR_LIBRE


func _sincronizar_mesas_con_grafo() -> void:
	_actualizar_geometrias_de_mesas()
	var celdas_de_mesas: Array[Vector2i] = []
	for fila: int in range(GrafoPiso.FILAS):
		for columna: int in range(GrafoPiso.COLUMNAS):
			var celda := Vector2i(columna, fila)
			if _hay_mesa_fisica(celda):
				celdas_de_mesas.append(celda)

	grafo.establecer_bloqueos_de_mesas(celdas_de_mesas)
	print("[GRAFO DEBUG] Mesas sincronizadas como bloqueos: ", celdas_de_mesas.size())


func _hay_mesa_fisica(celda: Vector2i) -> bool:
	# Las ConcavePolygonShape importadas contienen más geometría de la mesa de
	# la necesaria. Para no bloquear un borde completo, usamos el AABB visual
	# de cada Table_* ya transformado al mundo.
	var posicion := grafo.celda_a_posicion(celda)
	for datos: Dictionary in _mesas_fisicas:
		var caja: AABB = datos["caja"] as AABB
		if (
			posicion.x >= caja.position.x - GrafoPiso.TAMANO_CELDA * 0.5
			and posicion.x <= caja.end.x + GrafoPiso.TAMANO_CELDA * 0.5
			and posicion.z >= caja.position.z - GrafoPiso.TAMANO_CELDA * 0.5
			and posicion.z <= caja.end.z + GrafoPiso.TAMANO_CELDA * 0.5
		):
			return true
	return false


func _actualizar_geometrias_de_mesas() -> void:
	_mesas_fisicas.clear()
	if get_parent() != null:
		_recolectar_geometrias_de_mesas(get_parent())


func _recolectar_geometrias_de_mesas(nodo: Node) -> void:
	if nodo is MeshInstance3D and nodo.name.begins_with("Table_"):
		var mesa := nodo as MeshInstance3D
		var caja := _aabb_en_mundo(mesa)
		_mesas_fisicas.append({"caja": caja})

	for hijo: Node in nodo.get_children():
		_recolectar_geometrias_de_mesas(hijo)


func _aabb_en_mundo(mesa: MeshInstance3D) -> AABB:
	var local := mesa.get_aabb() if mesa.mesh != null else AABB_MESA_ESTANDAR
	var caja_mundo := AABB(mesa.global_transform * local.position, Vector3.ZERO)
	for x: float in [local.position.x, local.end.x]:
		for y: float in [local.position.y, local.end.y]:
			for z: float in [local.position.z, local.end.z]:
				caja_mundo = caja_mundo.expand(mesa.global_transform * Vector3(x, y, z))
	return caja_mundo


func _agregar_casilla(celda: Vector2i, color: Color) -> void:
	var plano := MeshInstance3D.new()
	var malla := PlaneMesh.new()
	malla.size = Vector2(TAMANO_VISUAL, TAMANO_VISUAL)
	plano.mesh = malla
	plano.material_override = _obtener_material(color)
	plano.position = grafo.celda_a_posicion(celda) + Vector3(0.0, ALTURA, 0.0)
	_contenedor.add_child(plano)


func _agregar_etiqueta(celda: Vector2i, texto: String) -> void:
	var etiqueta := Label3D.new()
	etiqueta.text = texto
	etiqueta.font_size = 36
	etiqueta.outline_size = 6
	etiqueta.modulate = Color.WHITE
	etiqueta.outline_modulate = Color.BLACK
	etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiqueta.position = grafo.celda_a_posicion(celda) + Vector3(0.0, ALTURA_ETIQUETA, 0.0)
	_contenedor.add_child(etiqueta)


func _crear_marcador_jugador() -> void:
	if is_instance_valid(_marcador_jugador):
		_marcador_jugador.queue_free()

	_marcador_jugador = MeshInstance3D.new()
	_marcador_jugador.name = "MarcadorJugador"
	var malla := CylinderMesh.new()
	malla.top_radius = GrafoPiso.TAMANO_CELDA * 0.23
	malla.bottom_radius = GrafoPiso.TAMANO_CELDA * 0.23
	malla.height = 0.025
	_marcador_jugador.mesh = malla
	_marcador_jugador.material_override = _obtener_material(COLOR_JUGADOR)
	add_child(_marcador_jugador)


func _obtener_material(color: Color) -> StandardMaterial3D:
	var clave := color.to_html(true)
	if _materiales.has(clave):
		return _materiales[clave] as StandardMaterial3D

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.render_priority = 127
	_materiales[clave] = material
	return material
