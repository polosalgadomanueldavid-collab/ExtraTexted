extends SceneTree
## --headless --script res://Pruebas/ZonaDescanso/prueba_taza_remota.gd
## Presentación remota real con datos locales: no crea una sesión ni abre puertos.

const CONTENIDO_CAFE := preload("res://Objetos/ZonaDescanso/contenido_cafe.gd")
const ID_REMOTO := 2
var _errores := 0
var _comprobaciones := 0
var _oficina: Node3D
var _red: Node
var _jugador: CharacterBody3D

func _initialize() -> void:
	_probar.call_deferred()

func _probar() -> void:
	_oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(_oficina)
	current_scene = _oficina
	for i in 3:
		await process_frame
	root.get_node("MenuGlobal").cerrar_ayuda()
	paused = false
	_oficina.process_mode = Node.PROCESS_MODE_DISABLED
	_jugador = load("res://Personajes/PoliciaAzul/Policia.tscn").instantiate()
	_jugador.remoto_red = true
	_jugador.id_red = ID_REMOTO
	_oficina.add_child(_jugador)
	_red = load("res://Scripts/Red/partida_lan.gd").new()
	_oficina.add_child(_red)
	# Evita configurar/comenzar el adaptador: solo ejercita su presentación.
	_red.oficina = _oficina
	_red.despacho = _oficina.sistema_despacho
	_red.despacho.jugadores[ID_REMOTO] = {"cordura": 100, "eliminado": false}
	_red.jugadores = {ID_REMOTO: _jugador}
	var sesion := root.get_node("SesionLAN")
	_verificar(not sesion.activa and not sesion.en_partida, "La prueba funciona sin conexión LAN")
	for indice in 2:
		_probar_taza(indice)
		await process_frame
	_probar_inactivo()
	_verificar(not sesion.activa and not sesion.en_partida, "La presentación no inicia una conexión")
	_oficina.queue_free()
	for i in 3:
		await process_frame
	print("TAZA_REMOTA: %d comprobaciones, %d errores" % [_comprobaciones, _errores])
	quit(0 if _errores == 0 else 1)

func _probar_taza(indice: int) -> void:
	var original: MeshInstance3D = _oficina.get_node("ZonaDescanso")._tazas[indice]
	var contenido_original := original.get_node("ContenidoCafe") as MeshInstance3D
	CONTENIDO_CAFE.establecer_llenado(contenido_original, 0.37)
	_red.tazas_cafe[ID_REMOTO] = indice
	_red.cafes[ID_REMOTO] = true
	_red._actualizar_objetos_remotos()
	_verificar(_red._tazas_remotas.has(ID_REMOTO), "Crea la taza remota %d" % indice)
	if not _red._tazas_remotas.has(ID_REMOTO):
		return
	var taza: MeshInstance3D = _red._tazas_remotas[ID_REMOTO]
	var contenido := taza.get_node("ContenidoCafe") as MeshInstance3D
	_verificar(taza != original and taza.mesh == original.mesh and taza.get_parent() == _jugador.anclaje_taza(), "Usa el modelo elegido en la mano remota")
	_verificar(contenido.material_override != contenido_original.material_override, "El material de café pertenece a su propia taza")
	_verificar(contenido.visible and is_equal_approx(_llenado(contenido), 1.0), "La taza remota nueva está llena aunque su original tenga otro nivel")
	_verificar(_jugador._taza_en_mano and _jugador.gestos.lleva_taza, "Activa la pose de sostener la taza")
	_jugador.gestos.iniciar(&"beber")
	_jugador.gestos.tiempo = _jugador.gestos.duracion * 0.46
	_red._actualizar_objetos_remotos()
	_verificar(_llenado(contenido) > 0.0 and _llenado(contenido) < 1.0, "El líquido desciende durante el sorbo")
	_verificar(is_equal_approx(_llenado(contenido_original), 0.37), "Beber remotamente conserva el nivel de la taza original")
	# Si un gesto se interrumpe antes de consumir, reutiliza la misma taza llena.
	_jugador.gestos.cancelar()
	_red._actualizar_objetos_remotos()
	_verificar(_red._tazas_remotas[ID_REMOTO] == taza and is_equal_approx(_llenado(contenido), 1.0), "Cancelar el gesto sin consumo repone el café de la misma taza")
	_jugador.gestos.iniciar(&"beber")
	_jugador.gestos.tiempo = _jugador.gestos.duracion * 0.60
	_red._actualizar_objetos_remotos()
	_verificar(is_zero_approx(_llenado(contenido)), "El sorbo vacía el líquido antes de bajar el brazo")
	_red.cafes[ID_REMOTO] = false
	_red._actualizar_objetos_remotos()
	_verificar(_red._tazas_remotas.get(ID_REMOTO) == taza and not contenido.visible and _jugador.gestos.lleva_taza, "Consumir conserva la taza vacía y el agarre durante el gesto")
	_jugador.gestos.tiempo = _jugador.gestos.duracion * 0.90
	_red._actualizar_objetos_remotos()
	_verificar(_red._tazas_remotas.get(ID_REMOTO) == taza and _jugador._taza_en_mano, "La taza acompaña el descenso del brazo")
	_jugador.gestos.cancelar()
	_red._actualizar_objetos_remotos()
	_verificar(not _red._tazas_remotas.has(ID_REMOTO) and taza.is_queued_for_deletion() and not _jugador._taza_en_mano and not _jugador.gestos.lleva_taza, "Al terminar el gesto retira la taza y libera la mano")

func _probar_inactivo() -> void:
	_red.cafes[ID_REMOTO] = true
	_red._actualizar_objetos_remotos()
	var taza: Node3D = _red._tazas_remotas[ID_REMOTO]
	_jugador.gestos.iniciar(&"beber")
	_jugador.gestos.tiempo = _jugador.gestos.duracion * 0.60
	_red.despacho.jugadores[ID_REMOTO].eliminado = true
	_red._actualizar_objetos_remotos()
	_verificar(not _red._tazas_remotas.has(ID_REMOTO) and taza.is_queued_for_deletion() and not _jugador.gestos.lleva_taza, "Un jugador eliminado pierde inmediatamente la taza aunque esté bebiendo")
	_jugador.gestos.cancelar()

func _llenado(contenido: MeshInstance3D) -> float:
	return float((contenido.material_override as ShaderMaterial).get_shader_parameter("llenado"))

func _verificar(condicion: bool, mensaje: String) -> void:
	_comprobaciones += 1
	if not condicion:
		_errores += 1
		push_error(mensaje)
