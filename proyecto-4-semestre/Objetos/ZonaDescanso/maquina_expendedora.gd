extends StaticBody3D
## Una unidad por producto; se consume al contacto del gesto, nunca al pulsar.
const PODERES := preload("res://Objetos/ZonaDescanso/poderes_expendedora.gd")
const AVISO := preload("res://UI/Descanso/aviso_descanso.gd")
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
var panel: PanelContainer
var aviso: PanelContainer
var _saldo: Label
var _estado: Label
var _botones: Array[Button] = []
var _mensaje := ""
var _mensaje_restante := 0.0
var _raton_anterior: Input.MouseMode
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
	_raton_anterior = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	panel.show()
	_actualizar_tienda()
	_botones[0].grab_focus()

func cerrar() -> void:
	if not is_instance_valid(panel) or not panel.visible:
		return
	panel.hide()
	if is_instance_valid(jugador):
		jugador.input_locked = is_instance_valid(despacho) and despacho.terminada
	Input.mouse_mode = _raton_anterior

func comprar(indice: int) -> bool:
	if not _disponible() or not panel.visible or indice < 0 or indice >= 4 or despacho.tiempo_detenido:
		return false
	if global_position.distance_to(jugador.global_position) > 2.4:
		cerrar()
		return false
	if inventario[indice] > 0:
		_estado.text = "Ya llevas este objeto. Úsalo antes de comprar otro."
		return false
	if not despacho.puntuacion.gastar_puntos(precios[indice]):
		_estado.text = "No tienes puntos suficientes. Resuelve más denuncias."
		return false
	inventario[indice] = 1
	_estado.text = "%s guardado. Cierra y pulsa %s para usarlo." % [NOMBRES[indice], ATAJOS[indice]]
	_actualizar_tienda()
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
	if panel.visible:
		if tecla in [KEY_ESCAPE, KEY_E]:
			get_viewport().set_input_as_handled()
			cerrar()
		elif tecla >= KEY_1 and tecla <= KEY_4:
			get_viewport().set_input_as_handled()
			comprar(tecla - KEY_1)
	elif TECLAS.has(tecla):
		get_viewport().set_input_as_handled()
		usar(TECLAS.find(tecla))

func _process(delta: float) -> void:
	if not is_instance_valid(aviso):
		return
	if _pendiente >= 0 and not jugador.realizando_gesto():
		_pendiente = -1
		_limpiar_snack()
	if panel.visible:
		if not _disponible() or global_position.distance_to(jugador.global_position) > 2.4:
			cerrar()
		else:
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
	_ajustar_panel()

func _crear_interfaz() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 36
	add_child(capa)
	aviso = AVISO.new()
	capa.add_child(aviso)
	panel = PanelContainer.new()
	panel.name = "TiendaExpendedora"
	capa.add_child(panel)
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color("102e40f8")
	fondo.border_color = Color("f2c665")
	fondo.set_border_width_all(3)
	fondo.set_corner_radius_all(18)
	fondo.content_margin_left = 28
	fondo.content_margin_right = 28
	fondo.content_margin_top = 22
	fondo.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", fondo)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 14)
	panel.add_child(columna)
	var titulo := Label.new()
	titulo.text = "REFUERZOS DE TURNO"
	titulo.add_theme_font_override("font", preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf"))
	titulo.add_theme_font_size_override("font_size", 30)
	columna.add_child(titulo)
	_saldo = Label.new()
	columna.add_child(_saldo)
	for i in 4:
		var boton := Button.new()
		boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		boton.custom_minimum_size = Vector2(620, 74)
		boton.add_theme_font_size_override("font_size", 19)
		boton.pressed.connect(comprar.bind(i))
		columna.add_child(boton)
		_botones.append(boton)
	_estado = Label.new()
	_estado.text = "Una unidad por producto · Usar: Z chocolate · X dona · V tiempo · N Avatar."
	_estado.add_theme_font_size_override("font_size", 16)
	columna.add_child(_estado)
	var salir := Button.new()
	salir.text = "VOLVER AL TURNO  [E / ESC]"
	salir.custom_minimum_size.y = 42
	salir.pressed.connect(cerrar)
	columna.add_child(salir)
	panel.hide()
	_ajustar_panel()

func _actualizar_tienda() -> void:
	_saldo.text = "SALDO: %d PUNTOS  ·  El mundo sigue avanzando mientras compras" % despacho.puntuacion.puntos
	for i in 4:
		_botones[i].text = "[%d]  %s  ·  %s\n%s" % [i + 1, NOMBRES[i].to_upper(), "EN EL BOLSILLO" if inventario[i] > 0 else "%d PTS" % precios[i], DETALLES[i]]
		_botones[i].disabled = inventario[i] > 0 or despacho.puntuacion.puntos < precios[i]
	_ajustar_panel()

func _ajustar_panel() -> void:
	var pantalla := get_viewport().get_visible_rect().size
	var factor := minf(pantalla.x / 900.0, pantalla.y / 730.0)
	panel.scale = Vector2.ONE * factor
	panel.size = panel.get_combined_minimum_size()
	panel.position = (pantalla - panel.size * factor) * 0.5

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
