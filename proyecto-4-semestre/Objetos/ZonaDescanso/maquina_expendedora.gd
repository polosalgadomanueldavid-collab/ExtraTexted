extends StaticBody3D
## Cada compra guarda una carga; se consume al contacto del gesto, nunca al pulsar.
const PODERES := preload("res://Objetos/ZonaDescanso/poderes_expendedora.gd")
const AVISO := preload("res://UI/Descanso/aviso_descanso.gd")
const PANEL := preload("res://UI/Descanso/panel_expendedora.gd")
const SEGUNDOS_ENTREGA := 1.5
const TECLAS := [KEY_Z, KEY_X, KEY_V, KEY_N]
const ATAJOS := ["Z", "X", "V", "N"]
const ATAJOS_MANDO := ["LB", "RB", "LT", "RT"]
const NOMBRES := ["Chocolate", "Dona", "Papa tiempo", "El Avatar"]
const DETALLES := ["Velocidad ×1,65 durante 25 s", "Barriguita y salto alto durante 10 s", "ZA WARUDO · detiene el mundo durante 12 s", "Una carga para resolver un evento con los cuatro elementos"]
const PESOS := [45, 45, 9, 1]
@export_range(1, 1000) var precio := 50
var _proximo_producto := -1
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
var _pendiente := -1
var _objeto_mano: Node3D
var _pago_red_pendiente := false
var _consumo_red_pendiente := false
var _gatillos_mando_activos := [false, false]

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
	return is_instance_valid(despacho) and despacho.esta_activo(despacho.jugador_local_id) and not despacho.terminada and not get_tree().paused and not MenuGlobal.capa.visible and not oficina.clasificacion_partida.visible

func interactuar(quien: Player) -> void:
	if quien != jugador or not _disponible() or jugador.obtener_objetivo_interaccion() != self or jugador.realizando_gesto() or jugador.input_locked:
		if SesionLAN.en_partida: SesionLAN.puente.liberar_local("tienda")
		return
	if despacho.tiempo_detenido:
		_mostrar("La máquina también está detenida.")
		return
	if SesionLAN.en_partida and oficina.espera_compra("snack", despacho.jugador_local_id) > 0:
		return
	if SesionLAN.en_partida and not SesionLAN.puente.reservar_confirmada("tienda"):
		SesionLAN.puente.reservar_local("tienda", func(): interactuar(quien))
		return
	jugador.cerrar_menu_emotes(true)
	jugador.input_locked = true
	jugador.velocity = Vector3.ZERO
	panel.abrir()
	_actualizar_tienda()
	if not panel.boton_sortear.disabled:
		panel.boton_sortear.grab_focus()
	elif panel.boton_usar.visible:
		panel.boton_usar.grab_focus()

func cerrar() -> void:
	if not is_instance_valid(panel) or not panel.visible:
		return
	panel.cerrar()
	if SesionLAN.en_partida:
		SesionLAN.puente.liberar_local("tienda")
	producto_en_entrega = -1
	producto_listo = false
	_tiempo_entrega = 0.0
	if is_instance_valid(jugador):
		jugador.input_locked = is_instance_valid(despacho) and despacho.terminada

func sortear_producto() -> int:
	return oficina.generador_aleatorio.rand_weighted(PESOS)

func comprar() -> bool:
	if not _disponible() or not panel.visible or despacho.tiempo_detenido or producto_en_entrega >= 0 or _pago_red_pendiente:
		return false
	if global_position.distance_to(jugador.global_position) > 2.4:
		cerrar()
		return false
	if oficina.espera_compra("snack", despacho.jugador_local_id) > 0:
		return false
	if despacho.puntuacion.puntos < precio:
		panel.mostrar_error("SIN\nSALDO")
		return false
	if SesionLAN.en_partida:
		producto_en_entrega = SesionLAN.puente.reservas.get("tienda", {}).get("premio", -1)
		if producto_en_entrega < 0:
			return false
	elif despacho.en_practica:
		producto_en_entrega = 0 # La lección enseña a usar chocolate.
	else:
		if _proximo_producto < 0:
			_proximo_producto = sortear_producto()
		producto_en_entrega = _proximo_producto
	producto_listo = false
	_tiempo_entrega = 0.0
	panel.dispensar(producto_en_entrega)
	_actualizar_tienda()
	return true

func recoger_producto() -> bool:
	if _pago_red_pendiente:
		return false
	if not _disponible() or not panel.visible or not producto_listo or producto_en_entrega < 0 or despacho.tiempo_detenido:
		return false
	if global_position.distance_to(jugador.global_position) > 2.4:
		cerrar()
		return false
	var indice := producto_en_entrega
	if SesionLAN.en_partida:
		_pago_red_pendiente = true
		SesionLAN.solicitar("comprar", {"producto": "snack"}, func(resultado: Dictionary):
			_pago_red_pendiente = false
			if resultado.get("ok", false):
				_entregar_producto(int(resultado.indice))
			else:
				cerrar()
		)
		return true
	if not despacho.puntuacion.gastar_puntos(precio):
		cerrar()
		_mostrar("No se pudo recoger el producto; conservas tu saldo.")
		return false
	_proximo_producto = -1
	oficina.registrar_compra("snack", despacho.jugador_local_id)
	_entregar_producto(indice)
	return true

func _entregar_producto(indice: int) -> void:
	inventario[indice] += 1
	producto_en_entrega = -1
	producto_listo = false
	_tiempo_entrega = 0.0
	_actualizar_tienda()
	var atajo: String = ATAJOS_MANDO[indice] if ControladorInterfaz.dispositivo_mando >= 0 else ATAJOS[indice]
	if SesionLAN.en_partida:
		cerrar()
		_mostrar("%s guardado. Pulsa %s para usarlo." % [NOMBRES[indice], atajo])
		return
	panel.recogido(indice, atajo)
	_mostrar("%s guardado. Pulsa USAR aquí o %s al salir." % [NOMBRES[indice], atajo])

func usar(indice: int) -> bool:
	if _consumo_red_pendiente:
		return false
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
	if SesionLAN.en_partida:
		if _consumo_red_pendiente:
			return
		_consumo_red_pendiente = true
		SesionLAN.solicitar("consumir", {"indice": indice, "evento": SesionLAN.puente._evento_id}, func(resultado: Dictionary):
			_consumo_red_pendiente = false
			if resultado.get("ok", false):
				_aplicar_consumo(indice, evento)
			else:
				_pendiente = -1
				_limpiar_snack()
		)
		return
	_aplicar_consumo(indice, evento)

func _aplicar_consumo(indice: int, evento: Node) -> void:
	inventario[indice] -= 1
	_pendiente = -1
	match indice:
		0: jugador.chocolate_restante = 25.0
		1: jugador.dona_restante = 10.0
		2:
			if not SesionLAN.en_partida: poderes.detener_tiempo()
		3:
			if not SesionLAN.en_partida: evento.resolver_con_avatar(jugador.global_position)
	_limpiar_snack()
	_mostrar("%s activado" % NOMBRES[indice])

func _input(evento: InputEvent) -> void:
	if not _disponible():
		return
	if evento is InputEventJoypadButton and evento.device == ControladorInterfaz.dispositivo_mando and evento.pressed and not panel.visible:
		var mapa_botones := {JOY_BUTTON_LEFT_SHOULDER: 0, JOY_BUTTON_RIGHT_SHOULDER: 1}
		if mapa_botones.has(evento.button_index):
			get_viewport().set_input_as_handled()
			usar(int(mapa_botones[evento.button_index]))
		return
	if evento is InputEventJoypadMotion and evento.device == ControladorInterfaz.dispositivo_mando and not panel.visible:
		var ejes := [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]
		for i in 2:
			if evento.axis != ejes[i]:
				continue
			var intensidad: float = evento.axis_value
			if intensidad < 0.30:
				_gatillos_mando_activos[i] = false
			elif intensidad > 0.65 and not _gatillos_mando_activos[i]:
				_gatillos_mando_activos[i] = true
				get_viewport().set_input_as_handled()
				usar(i + 2)
			return
	if not evento is InputEventKey or not evento.pressed or evento.echo:
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
	var titulo := "BOLSILLO"
	if _mensaje_restante > 0.0:
		detalle = _mensaje
	elif jugador.obtener_objetivo_interaccion() == self:
		titulo = "MÁQUINA EXPENDEDORA"
		var espera: int = oficina.espera_compra("snack", despacho.jugador_local_id)
		detalle = "Tu próxima compra en %d s" % espera if espera > 0 else "Producto al azar · %d puntos" % precio
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
	panel.pesos = PESOS
	capa.add_child(panel)
	panel.producto_solicitado.connect(comprar)
	panel.recoger_solicitado.connect(recoger_producto)
	panel.usar_solicitado.connect(_usar_desde_panel)
	panel.cerrar_solicitado.connect(cerrar)

func _usar_desde_panel(indice: int) -> void:
	if indice < 0 or indice >= inventario.size() or inventario[indice] <= 0:
		return
	cerrar()
	call_deferred("usar", indice)

func _actualizar_tienda() -> void:
	panel.actualizar(despacho.puntuacion.puntos, precio, inventario, producto_en_entrega >= 0, oficina.espera_compra("snack", despacho.jugador_local_id))

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
