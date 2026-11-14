extends StaticBody3D
## Una unidad por producto; se consume al contacto del gesto, nunca al pulsar.
const PODERES := preload("res://Objetos/ZonaDescanso/poderes_expendedora.gd")
const AVISO := preload("res://UI/Descanso/aviso_descanso.gd")
const PANEL := preload("res://UI/Descanso/panel_expendedora.gd")
const SEGUNDOS_ENTREGA := 1.5
const TECLAS := [KEY_Z, KEY_X, KEY_V, KEY_N]
const ATAJOS := ["Z", "X", "V", "N"]
const NOMBRES := ["Chocolate", "Dona", "Papa tiempo", "El Avatar"]
const DETALLES := ["Velocidad ×1,65 durante 25 s", "Barriguita y salto alto durante 10 s", "ZA WARUDO · detiene el mundo durante 12 s", "Una carga para resolver un evento con los cuatro elementos"]
@export var precios: Array[int] = [50, 75, 150, 250]
var inventario: Array[int] = [0, 0, 0, 0]
var poderes: Node
var oficina: Node3D
var jugador: Player
var despacho: SistemaDespacho
var panel: Control
var aviso: PanelContainer
var _mensaje := ""
var _mensaje_restante := 0.0
var producto_en_entrega := -1
var producto_listo := false
var _tiempo_entrega := 0.0
var _precio_entrega := 0
var _pendiente := -1
var _objeto_mano: Node3D

func _ready() -> void:
	_configurar.call_deferred()

func _configurar() -> void:
	oficina = get_tree().get_first_node_in_group("gestor_partida") as Node3D
	if oficina == null or not oficina.is_ancestor_of(self):
		set_process(false)
		set_process_input(false)
		return
	jugador = oficina.get("jugador") as Player
	despacho = oficina.get("sistema_despacho") as SistemaDespacho
	poderes = PODERES.new()
	add_child(poderes)
	poderes.configurar(oficina, jugador)
	_crear_interfaz()
	jugador.reset_performed.connect(_reiniciar)
	despacho.partida_terminada.connect(_reiniciar)

func _disponible() -> bool:
	return is_instance_valid(despacho) and not despacho.terminada and not get_tree().paused and not MenuGlobal.capa.visible and not oficina.clasificacion_partida.visible

func interactuar(quien: Player) -> void:
	if quien != jugador or not _disponible() or jugador.obtener_objetivo_interaccion() != self or jugador.realizando_gesto() or jugador.input_locked:
		return
	if despacho.tiempo_detenido:
		_mostrar("La máquina también está detenida.")
		return
	jugador.cerrar_menu_emotes(true)
	jugador.input_locked = true
	jugador.velocity = Vector3.ZERO
	panel.abrir()
	_actualizar_tienda()
	for boton: Button in panel.botones:
		if not boton.disabled:
			boton.grab_focus()
			break

func cerrar() -> void:
	if not is_instance_valid(panel) or not panel.visible:
		return
	panel.cerrar()
	producto_en_entrega = -1
	producto_listo = false
	_tiempo_entrega = 0.0
	if is_instance_valid(jugador):
		jugador.input_locked = is_instance_valid(despacho) and despacho.terminada

func comprar(indice: int) -> bool:
	if not _disponible() or not panel.visible or indice < 0 or indice >= 4 or despacho.tiempo_detenido or producto_en_entrega >= 0:
		return false
	if global_position.distance_to(jugador.global_position) > 2.4:
		cerrar()
		return false
	if inventario[indice] > 0:
		panel.mostrar_error("YA LO\nLLEVAS")
		return false
	if precios[indice] <= 0 or despacho.puntuacion.puntos < precios[indice]:
		panel.mostrar_error("SIN\nSALDO")
		return false
	producto_en_entrega = indice
	_precio_entrega = precios[indice]
	producto_listo = false
	_tiempo_entrega = 0.0
	panel.dispensar(indice)
	_actualizar_tienda()
	return true

func recoger_producto() -> bool:
	if not _disponible() or not panel.visible or not producto_listo or producto_en_entrega < 0 or despacho.tiempo_detenido:
		return false
	if global_position.distance_to(jugador.global_position) > 2.4:
		cerrar()
		return false
	var indice := producto_en_entrega
	if inventario[indice] > 0 or not despacho.puntuacion.gastar_puntos(_precio_entrega):
		cerrar()
		_mostrar("No se pudo recoger el producto; conservas tu saldo.")
		return false
	inventario[indice] = 1
	producto_en_entrega = -1
	producto_listo = false
	_tiempo_entrega = 0.0
	_actualizar_tienda()
	panel.recogido(indice, ATAJOS[indice])
	_mostrar("%s guardado. Pulsa %s al salir para usarlo." % [NOMBRES[indice], ATAJOS[indice]])
	return true

func usar(indice: int) -> bool:
	if not _disponible() or panel.visible or indice < 0 or indice >= 4 or inventario[indice] == 0:
		return false
	if jugador.input_locked or jugador.realizando_gesto() or jugador.esta_sentado() or jugador.usando_extintor or jugador._taza_en_mano or not jugador.is_on_floor():
		_mostrar("Termina la acción actual y apóyate en el suelo para usarlo.")
		return false
	if despacho.tiempo_detenido or (indice == 0 and jugador.chocolate_restante > 0.0) or (indice == 1 and jugador.dona_restante > 0.0):
		_mostrar("Espera a que termine el efecto activo; conservas el objeto.")
		return false
	var gesto: StringName = &"comer"
	var evento: Node = null
	if indice == 2:
		gesto = &"za_warudo"
	elif indice == 3:
		evento = poderes.evento_actual()
		if evento == null:
			_mostrar("El Avatar está listo: pulsa N cuando haya un evento.")
			return false
		gesto = poderes.gesto_para(evento)
	_pendiente = indice
	if not jugador.ejecutar_gesto(gesto, _consumir.bind(indice, evento)):
		_pendiente = -1
		return false
	if indice < 2:
		_objeto_mano = poderes.crear_snack(indice)
		jugador.anclaje_taza().add_child(_objeto_mano)
	elif indice == 3:
		poderes.animar_elemento(gesto)
	return true

func _consumir(indice: int, evento: Node) -> void:
	if _pendiente != indice or inventario[indice] == 0 or despacho.terminada:
		return
	if indice == 3 and (not is_instance_valid(evento) or poderes.evento_actual() != evento):
		_mostrar("El evento ya terminó; conservas el Avatar.")
		_pendiente = -1
		return
	inventario[indice] = 0
	_pendiente = -1
	match indice:
		0: jugador.chocolate_restante = 25.0
		1: jugador.dona_restante = 10.0
		2: poderes.detener_tiempo()
		3: evento.resolver_con_avatar()
	_limpiar_snack()
	_mostrar("%s activado" % NOMBRES[indice])

func _input(evento: InputEvent) -> void:
	if not evento is InputEventKey or not evento.pressed or evento.echo or not _disponible():
		return
	var tecla: int = evento.physical_keycode if evento.physical_keycode != 0 else evento.keycode
	if not panel.visible and TECLAS.has(tecla):
		get_viewport().set_input_as_handled()
		usar(TECLAS.find(tecla))

func _process(delta: float) -> void:
	if not is_instance_valid(aviso):
		return
	if _pendiente >= 0 and not jugador.realizando_gesto():
		_pendiente = -1
		_limpiar_snack()
	if panel.visible:
		if not _disponible() or despacho.tiempo_detenido or global_position.distance_to(jugador.global_position) > 2.4:
			cerrar()
		else:
			if producto_en_entrega >= 0 and not producto_listo:
				_tiempo_entrega = minf(_tiempo_entrega + delta, SEGUNDOS_ENTREGA)
				panel.actualizar_caida(_tiempo_entrega / SEGUNDOS_ENTREGA)
				if _tiempo_entrega >= SEGUNDOS_ENTREGA:
					producto_listo = true
					panel.listo()
			_actualizar_tienda()
	_mensaje_restante = maxf(0.0, _mensaje_restante - delta)
	aviso.hide()
	if not _disponible() or panel.visible:
		return
	var detalle := ""
	for i in 4:
		if inventario[i] > 0:
			detalle += ("  ·  " if not detalle.is_empty() else "") + "[%s] %s" % [ATAJOS[i], NOMBRES[i]]
	var titulo := "BOLSILLO"
	if jugador.chocolate_restante > 0.0:
		titulo = "CHOCOLATE · %d s" % ceili(jugador.chocolate_restante)
	if jugador.dona_restante > 0.0:
		titulo += "  ·  DONA %d s" % ceili(jugador.dona_restante)
	if poderes.restante > 0.0:
		titulo = "ZA WARUDO · %d s" % ceili(poderes.restante)
		detalle = "Mundo detenido · puedes completar denuncias"
	elif jugador.obtener_objetivo_interaccion() == self:
		titulo = "[E] MÁQUINA EXPENDEDORA"
		detalle = "Chocolate · Dona · Papa tiempo · El Avatar"
	elif _mensaje_restante > 0.0:
		detalle = _mensaje
	if not detalle.is_empty() or titulo != "BOLSILLO":
		aviso.presentar(titulo, detalle)
		aviso.position = Vector2(24, 110) * aviso.scale.x

func _crear_interfaz() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 36
	add_child(capa)
	aviso = AVISO.new()
	capa.add_child(aviso)
	panel = PANEL.new()
	capa.add_child(panel)
	panel.producto_solicitado.connect(comprar)
	panel.recoger_solicitado.connect(recoger_producto)
	panel.cerrar_solicitado.connect(cerrar)

func _actualizar_tienda() -> void:
	panel.actualizar(despacho.puntuacion.puntos, precios, inventario, producto_en_entrega >= 0)

func _mostrar(texto: String) -> void:
	_mensaje = texto
	_mensaje_restante = 3.0

func _limpiar_snack() -> void:
	if is_instance_valid(_objeto_mano):
		_objeto_mano.queue_free()
	_objeto_mano = null

func _reiniciar() -> void:
	cerrar()
	_pendiente = -1
	_limpiar_snack()
	if is_instance_valid(poderes):
		poderes.limpiar()
	if is_instance_valid(jugador):
		jugador.chocolate_restante = 0.0
		jugador.dona_restante = 0.0
		jugador.cancelar_gesto()
	if is_instance_valid(despacho) and despacho.terminada:
		inventario.assign([0, 0, 0, 0])

func _exit_tree() -> void:
	cerrar()
	_limpiar_snack()
