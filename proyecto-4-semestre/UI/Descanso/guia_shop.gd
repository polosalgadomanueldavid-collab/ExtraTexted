extends Control
## Una invitación local por turno; solo observa el saldo y las compras reales.
const TITULO := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const TEXTO := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
const TINTA := Color("173b50")
const VERDE := Color("b9f58c")
const CARRITO := preload("res://UI/Descanso/Arte/carrito.svg")
const DURACION := 6.0
var oficina
var maquina
var ofrecida := false
var pendiente := false
var restante := 0.0
var _demora := 0.0
var _saldo := 0
var _saldo_antes := 0
var _casos: Dictionary = {}
var marcador := Rect2()
var en_borde := false
var interactuable := false
var _direccion := Vector2.DOWN

func _ready() -> void:
	name = "GuiaShop"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()

func configurar(mundo: Node3D) -> void:
	oficina = mundo
	maquina = mundo.get_node("MaquinaExpendedora")
	_saldo = mundo.sistema_despacho.puntuacion.puntos
	mundo.sistema_despacho.puntuacion.puntos_actualizados.connect(_al_saldo)
	mundo.sistema_despacho.denuncia_resuelta.connect(_al_resolver)
	maquina.panel.visibility_changed.connect(_al_abrir_tienda)
	mundo.sistema_despacho.partida_terminada.connect(_cancelar)
	MenuGlobal.capa.visibility_changed.connect(_al_cambiar_menu)

func _al_cambiar_menu() -> void:
	if MenuGlobal.capa.visible:
		hide()
	else:
		_process(0.0)

func _al_saldo(total: int) -> void:
	_saldo_antes = _saldo
	_saldo = total
	if (pendiente or restante > 0) and not _compra_disponible():
		_cancelar()

func _compra_disponible() -> bool:
	return is_instance_valid(maquina) and _saldo >= maquina.precio

func _al_resolver(caso: Denuncia) -> void:
	if caso == null or caso.es_practica or oficina.en_practica() or ofrecida or pendiente or _casos.has(caso.id):
		return
	_casos[caso.id] = true
	if _saldo <= _saldo_antes:
		return
	if not _compra_disponible() or _saldo_antes >= maquina.precio:
		return
	# La recompensa y la tarea terminan antes de que entre el mensaje de radio.
	pendiente = true
	_demora = .3

func _al_abrir_tienda() -> void:
	if is_instance_valid(maquina) and is_instance_valid(maquina.panel) and maquina.panel.visible:
		# Visitarla antes de ganar saldo también completa su descubrimiento.
		ofrecida = true
		_cancelar()

func _cancelar() -> void:
	pendiente = false
	restante = 0.0
	hide()
	queue_redraw()

func _ocupado() -> bool:
	return get_tree().paused or MenuGlobal.capa.visible or oficina.en_practica() or oficina.partida_finalizada or oficina.computador.is_using or oficina.clasificacion_partida.visible or oficina.clasificador_evidencias.visible or oficina.escaner_verificacion.visible or oficina.depurador_recursos.visible or not oficina._puede_iniciar_evento()

func _process(delta: float) -> void:
	if not is_instance_valid(oficina) or not is_instance_valid(maquina) or not is_instance_valid(maquina.panel):
		_cancelar()
		set_process(false)
		return
	if maquina.panel.visible or oficina.partida_finalizada:
		_cancelar()
		return
	if _ocupado():
		hide()
		return
	if pendiente:
		if oficina.panel_despacho.efecto_tarea.visible:
			return
		_demora -= delta
		if _demora <= 0.0:
			if not _compra_disponible():
				_cancelar()
				return
			pendiente = false
			ofrecida = true
			restante = DURACION
	if restante <= 0:
		hide()
		return
	show()
	restante = maxf(0.0, restante - delta)
	if restante <= 0.0:
		_cancelar()
		return
	_actualizar_marcador()
	queue_redraw()

func _actualizar_marcador() -> void:
	var camara := get_viewport().get_camera_3d()
	if camara == null:
		return
	var factor := minf(size.x / 1280.0, size.y / 720.0)
	var punto: Vector3 = maquina.global_position + Vector3.UP * 2.0
	var destino := camara.unproject_position(punto)
	var centro := size * .5
	var area := Rect2(Vector2(132, 136) * factor, size - Vector2(264, 326) * factor)
	var detras := camara.is_position_behind(punto)
	en_borde = detras or not area.has_point(destino)
	_direccion = (destino - centro).normalized()
	if detras:
		_direccion = -_direccion
	if en_borde:
		var mitad := area.size * .5
		var proporcion := maxf(absf(_direccion.x) / mitad.x, absf(_direccion.y) / mitad.y)
		destino = area.get_center() + _direccion / maxf(.001, proporcion)
	interactuable = oficina.jugador.obtener_objetivo_interaccion() == maquina and not oficina.jugador.realizando_gesto() and not oficina.jugador.input_locked
	marcador = Rect2(destino - Vector2(120, 34) * factor, Vector2(240, 68) * factor)

func _draw() -> void:
	if restante <= 0:
		return
	var factor := minf(size.x / 1280.0, size.y / 720.0)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = VERDE
	estilo.border_color = TINTA
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	estilo.shadow_color = Color(0, .04, .08, .3)
	estilo.shadow_size = 4
	draw_style_box(estilo, marcador)
	var tecla := "X" if ControladorInterfaz.dispositivo_mando >= 0 else "E"
	var texto := "%s · ABRIR TIENDA" % tecla if interactuable else "SHOP · TIENDA"
	draw_texture_rect(CARRITO, Rect2(marcador.position + Vector2(8, 10) * factor, Vector2(46, 46) * factor), false)
	draw_string(TITULO, marcador.position + Vector2(64, 25) * factor, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(11, roundi(17 * factor)), TINTA)
	draw_string(TEXTO, marcador.position + Vector2(64, 43) * factor, "Snacks y poderes", HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(11, roundi(14 * factor)), TINTA)
	var producto: String = "%s · %d pts" % [maquina.NOMBRES[maxi(0, _indice)], maquina.precios[maxi(0, _indice)]]
	draw_string(TEXTO, marcador.position + Vector2(64, 59) * factor, producto, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(10, roundi(12 * factor)), TINTA)
	var direccion := _direccion if en_borde else Vector2.DOWN
	var tangente := Vector2(-direccion.y, direccion.x)
	var mitad := marcador.size * .5
	var distancia := 1.0 / maxf(.001, maxf(absf(direccion.x) / mitad.x, absf(direccion.y) / mitad.y))
	var origen := marcador.get_center() + direccion * (distancia - factor)
	draw_colored_polygon(PackedVector2Array([origen + direccion * 9 * factor, origen + tangente * 6 * factor, origen - tangente * 6 * factor]), VERDE)
