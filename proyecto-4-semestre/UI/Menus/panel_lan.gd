extends CanvasLayer
## Sala de equipo sobre el fondo de oficina del menú, con controles locales.
const TINTA := Color("173b50")
const CREMA := Color("fff1d8")
const CORAL := Color("ff785f")
const VERDE := Color("5b9176")
const TITULAR := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const TEXTO := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
const RETRATOS := [preload("res://UI/Despacho/retrato_policia.png"), preload("res://UI/Despacho/retrato_policia_relevo.png")]
const TAMANO := Vector2(1000, 660)

var fondo: ColorRect
var panel: PanelContainer
var alias_jugador: LineEdit
var direccion: LineEdit
var estado: Label
var lista: Label
var listo: Button
var iniciar: Button
var crear: Button
var unir: Button
var individual: Button
var menu: Control
var _lienzo: Control
var _conexion: Control
var _sala: Control
var _titulo: Label
var _subtitulo: Label
var _plazas: Label
var _volver: Button
var _copiar: Button
var _ip := ""
var _tarjetas: Array[Dictionary] = []
var _texto: FontVariation

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_texto = FontVariation.new()
	_texto.base_font = TEXTO
	_texto.variation_opentype = {2003265652: 750.0}
	fondo = ColorRect.new()
	fondo.color = Color(0.025, 0.075, 0.10, 0.78)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	_lienzo = Control.new()
	_lienzo.size = TAMANO
	fondo.add_child(_lienzo)
	panel = PanelContainer.new()
	panel.size = TAMANO
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _estilo(CREMA, TINTA, 24, 4))
	_lienzo.add_child(panel)
	_titulo = _etiqueta(_lienzo, "ARMA TU EQUIPO", Vector2(46, 35), Vector2(765, 58), 48)
	_subtitulo = _etiqueta(_lienzo, "Dos policías. Una oficina. El mismo saldo.", Vector2(48, 101), Vector2(904, 28), 20, false)
	_plazas = _etiqueta(_lienzo, "", Vector2(824, 39), Vector2(128, 44), 17)
	_plazas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plazas.add_theme_stylebox_override("normal", _estilo(Color("d7e9e6"), TINTA, 12, 2))
	_conexion = Control.new()
	_lienzo.add_child(_conexion)
	_crear_conexion()
	_sala = Control.new()
	_lienzo.add_child(_sala)
	for indice in 2:
		_crear_tarjeta(indice)
	lista = _etiqueta(_sala, "", Vector2(48, 448), Vector2(904, 24), 17, false)
	lista.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var aviso := Panel.new()
	aviso.position = Vector2(48, 484)
	aviso.size = Vector2(904, 68)
	aviso.add_theme_stylebox_override("panel", _estilo(Color("dce8e1"), Color("b4cec6"), 12, 1))
	aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lienzo.add_child(aviso)
	estado = _etiqueta(_lienzo, "", Vector2(65, 492), Vector2(868, 52), 18, false)
	estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_copiar = _boton(_lienzo, "COPIAR IP", Vector2(782, 499), Vector2(154, 40), func():
		DisplayServer.clipboard_set(_ip)
		_copiar.text = "¡COPIADA!"
	, false, 18)
	_volver = _boton(_lienzo, "VOLVER", Vector2(48, 580), Vector2(236, 52), cerrar)
	individual = _boton(_lienzo, "JUGAR INDIVIDUAL", Vector2(650, 580), Vector2(302, 52), _individual)
	listo = _boton(_lienzo, "ESTOY LISTO", Vector2(310, 580), Vector2(302, 52), Callable())
	listo.toggle_mode = true
	listo.toggled.connect(SesionLAN.establecer_listo)
	listo.add_theme_stylebox_override("pressed", _estilo(VERDE, TINTA, 22, 3))
	listo.add_theme_color_override("font_pressed_color", CREMA)
	iniciar = _boton(_lienzo, "INICIAR TURNO", Vector2(650, 580), Vector2(302, 52), SesionLAN.iniciar, true)
	SesionLAN.sala_actualizada.connect(_actualizar)
	SesionLAN.aviso.connect(func(_texto: String): _actualizar())
	fondo.resized.connect(_ajustar)
	_ajustar()
	fondo.hide()

func _crear_conexion() -> void:
	_encabezado_conexion("TU IDENTIFICACIÓN", Vector2(48, 188))
	_etiqueta(_conexion, "Así te verá tu compañero en la oficina.", Vector2(48, 229), Vector2(425, 28), 18, false)
	alias_jugador = _campo(_conexion, "Tu alias", Vector2(48, 274), Vector2(432, 54))
	alias_jugador.max_length = 10
	crear = _boton(_conexion, "CREAR PARTIDA", Vector2(48, 354), Vector2(432, 60), func(): SesionLAN.crear(alias_jugador.text), true)
	_encabezado_conexion("¿YA HAY UNA SALA?", Vector2(520, 188))
	_etiqueta(_conexion, "Escribe la IP que te comparte el anfitrión.", Vector2(520, 229), Vector2(432, 28), 18, false)
	direccion = _campo(_conexion, "Ej. 192.168.1.10", Vector2(520, 274), Vector2(432, 54))
	unir = _boton(_conexion, "UNIRSE POR IP", Vector2(520, 354), Vector2(432, 60), func(): SesionLAN.unirse(direccion.text, alias_jugador.text))

func _encabezado_conexion(texto: String, punto: Vector2) -> void:
	var vineta := Panel.new()
	vineta.position = punto + Vector2(2, 10)
	vineta.size = Vector2(10, 10)
	vineta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vineta.add_theme_stylebox_override("panel", _estilo(TINTA, TINTA, 5, 0))
	_conexion.add_child(vineta)
	_etiqueta(_conexion, texto, punto + Vector2(24, 0), Vector2(408, 32), 24)

func _crear_tarjeta(indice: int) -> void:
	var tarjeta := Panel.new()
	tarjeta.position = Vector2(48 + indice * 466, 169)
	tarjeta.size = Vector2(438, 268)
	tarjeta.add_theme_stylebox_override("panel", _estilo(Color("fffaf0"), TINTA, 18, 3))
	_sala.add_child(tarjeta)
	var rol := _etiqueta(tarjeta, "ANFITRIÓN" if indice == 0 else "COMPAÑERO", Vector2(20, 17), Vector2(398, 28), 21)
	rol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var retrato := TextureRect.new()
	retrato.texture = RETRATOS[indice]
	retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	retrato.position = Vector2(155, 52)
	retrato.size = Vector2(128, 128)
	retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tarjeta.add_child(retrato)
	var numero := _etiqueta(tarjeta, "%02d" % (indice + 1), Vector2(22, 61), Vector2(60, 45), 32)
	numero.add_theme_color_override("font_color", Color("679fa9") if indice == 0 else Color("ba8a3f"))
	var nombre := _etiqueta(tarjeta, "", Vector2(16, 180), Vector2(406, 37), 27)
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sello := _etiqueta(tarjeta, "", Vector2(76, 224), Vector2(286, 30), 16, false)
	sello.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tarjetas.append({"retrato": retrato, "nombre": nombre, "sello": sello})

func _estilo(color: Color, borde: Color, radio: int, ancho: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.border_color = borde
	estilo.set_border_width_all(ancho)
	estilo.set_corner_radius_all(radio)
	estilo.shadow_color = Color(0.035, 0.10, 0.12, 0.24)
	estilo.shadow_offset = Vector2(0, 4)
	estilo.shadow_size = 2
	return estilo

func _etiqueta(padre: Node, texto: String, punto: Vector2, tamano: Vector2, fuente: int, titular := true) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.position = punto
	etiqueta.size = tamano
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_override("font", TITULAR if titular else _texto)
	etiqueta.add_theme_font_size_override("font_size", fuente)
	etiqueta.add_theme_color_override("font_color", TINTA)
	padre.add_child(etiqueta)
	return etiqueta

func _campo(padre: Node, texto: String, punto: Vector2, tamano: Vector2) -> LineEdit:
	var campo := LineEdit.new()
	campo.position = punto
	campo.size = tamano
	campo.placeholder_text = texto
	campo.add_theme_font_override("font", _texto)
	campo.add_theme_font_size_override("font_size", 23)
	campo.add_theme_color_override("font_color", TINTA)
	campo.add_theme_color_override("font_placeholder_color", Color("526d76"))
	campo.add_theme_color_override("caret_color", TINTA)
	var normal := _estilo(Color("fffaf0"), Color("7fa6aa"), 10, 2)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	campo.add_theme_stylebox_override("normal", normal)
	campo.add_theme_stylebox_override("focus", _estilo(Color.TRANSPARENT, CORAL, 10, 3))
	padre.add_child(campo)
	return campo

func _boton(padre: Node, texto: String, punto: Vector2, tamano: Vector2, accion: Callable, principal := false, fuente := 23) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.position = punto
	boton.size = tamano
	boton.add_theme_font_override("font", TITULAR)
	boton.add_theme_font_size_override("font_size", fuente)
	for modo: String in ["normal", "hover", "pressed", "disabled"]:
		var color := CORAL if principal else Color("d5e9e6")
		if modo == "hover": color = color.lightened(0.12)
		if modo == "pressed": color = color.darkened(0.08)
		if modo == "disabled": color = Color("e0dbce")
		boton.add_theme_stylebox_override(modo, _estilo(color, TINTA if modo != "disabled" else Color("b3b6ac"), 22, 3))
		boton.add_theme_color_override("font_" + modo + "_color" if modo != "normal" else "font_color", CREMA if principal else TINTA)
	boton.add_theme_color_override("font_disabled_color", Color("657875"))
	boton.add_theme_color_override("font_focus_color", CREMA if principal else TINTA)
	var foco := _estilo(Color.TRANSPARENT, Color("e5af4b"), 24, 3)
	foco.set_expand_margin_all(4)
	boton.add_theme_stylebox_override("focus", foco)
	if accion.is_valid(): boton.pressed.connect(accion)
	padre.add_child(boton)
	return boton

func _ajustar() -> void:
	var visible := get_viewport().get_visible_rect().size
	var factor := minf((visible.x - 32) / TAMANO.x, (visible.y - 32) / TAMANO.y)
	_lienzo.scale = Vector2.ONE * maxf(0.1, factor)
	_lienzo.position = (visible - TAMANO * _lienzo.scale) * 0.5

func abrir(origen: Control) -> void:
	menu = origen
	menu.presentacion.hide()
	fondo.show()
	_actualizar()
	(alias_jugador if not SesionLAN.activa else listo).grab_focus()

func cerrar() -> void:
	if SesionLAN.activa and not SesionLAN.en_partida:
		SesionLAN.cerrar()
	SesionLAN.ultimo_aviso = ""
	fondo.hide()
	if is_instance_valid(menu):
		menu.presentacion.show()
		menu.play_button.grab_focus()

func _individual() -> void:
	cerrar()
	menu.jugar_individual()

func _actualizar() -> void:
	if estado == null: return
	var activa: bool = SesionLAN.activa
	var cambio := _sala.visible != activa
	_sala.visible = activa
	_conexion.visible = not activa
	individual.visible = not activa
	_titulo.text = "SALA DE ESPERA" if activa else "ARMA TU EQUIPO"
	_subtitulo.text = "Preparen sus puestos. El turno empieza cuando ambos estén listos." if activa else "Dos policías. Una oficina. El mismo saldo."
	_volver.text = "SALIR DE LA SALA" if activa else "VOLVER"
	crear.disabled = activa
	unir.disabled = activa
	alias_jugador.editable = not activa
	direccion.editable = not activa
	listo.visible = activa and SesionLAN.participantes.has(SesionLAN.id_local())
	var local_listo: bool = SesionLAN.participantes.get(SesionLAN.id_local(), {}).get("listo", false)
	listo.set_pressed_no_signal(local_listo)
	listo.text = "LISTO" if local_listo else "ESTOY LISTO"
	iniciar.visible = activa
	iniciar.text = "INICIAR TURNO" if SesionLAN.es_anfitrion() else "ESPERA AL ANFITRIÓN"
	var ids: Array = SesionLAN.participantes.keys()
	ids.sort()
	var preparados := ids.size() == 2
	for indice in 2:
		var tarjeta: Dictionary = _tarjetas[indice]
		var ocupado := indice < ids.size()
		var jugador: Dictionary = SesionLAN.participantes[ids[indice]] if ocupado else {}
		var preparado: bool = jugador.get("listo", false)
		preparados = preparados and preparado
		tarjeta.nombre.text = str(jugador.get("alias", "Esperando compañero"))
		tarjeta.retrato.modulate = Color.WHITE if ocupado else Color(0.45, 0.55, 0.57, 0.38)
		tarjeta.sello.text = ("LISTO PARA EL TURNO" if preparado else "PREPARÁNDOSE") if ocupado else "PLAZA DISPONIBLE"
		if ocupado and ids[indice] == SesionLAN.id_local(): tarjeta.sello.text += " · TÚ"
		tarjeta.sello.add_theme_color_override("font_color", CREMA if preparado else TINTA)
		tarjeta.sello.add_theme_stylebox_override("normal", _estilo(VERDE if preparado else Color("e7dfca"), Color.TRANSPARENT, 10, 0))
	_plazas.visible = activa
	_plazas.text = "%d / 2 LISTOS" % SesionLAN.participantes.values().filter(func(j: Dictionary): return j.listo).size()
	lista.text = "Saldo compartido · Cordura y bolsillo personales"
	iniciar.disabled = not preparados or not SesionLAN.es_anfitrion() or SesionLAN.cargando
	estado.text = SesionLAN.ultimo_aviso if not SesionLAN.ultimo_aviso.is_empty() else "Crea una sala o únete a tu compañero en la misma red."
	_copiar.visible = SesionLAN.es_anfitrion()
	estado.size.x = 695 if _copiar.visible else 868
	if SesionLAN.es_anfitrion():
		var direcciones := PackedStringArray()
		for ip: String in IP.get_local_addresses():
			if ip.contains(".") and not ip.begins_with("127.") and not ip.begins_with("169.254."):
				direcciones.append(ip)
		_ip = direcciones[0] if not direcciones.is_empty() else ""
		_copiar.tooltip_text = "Copiar " + _ip
		estado.tooltip_text = "Direcciones del equipo: " + ", ".join(direcciones)
		_copiar.disabled = _ip.is_empty()
		_copiar.text = "COPIAR IP"
		estado.text = ("¡Equipo listo! Puedes iniciar el turno." if preparados else "Comparte tu IP y confirma que estás listo.") + "\nIP de este equipo: " + (_ip if not _ip.is_empty() else "Sin dirección LAN disponible")
	elif activa:
		estado.text = "El anfitrión iniciará cuando ambos estén listos." if ids.size() == 2 else SesionLAN.ultimo_aviso
	var controles: Array[Control] = [_volver]
	if not activa: controles.append_array([alias_jugador, crear, direccion, unir, individual])
	if listo.visible: controles.append(listo)
	if iniciar.visible and not iniciar.disabled: controles.append(iniciar)
	if _copiar.visible and not _copiar.disabled: controles.append(_copiar)
	for i in controles.size():
		controles[i].focus_next = controles[i].get_path_to(controles[(i + 1) % controles.size()])
		controles[i].focus_previous = controles[i].get_path_to(controles[(i - 1 + controles.size()) % controles.size()])
	if fondo.visible and cambio:
		(listo if listo.visible else _volver).grab_focus()

func _input(event: InputEvent) -> void:
	if fondo.visible and event.is_action_pressed("Cancel") and not event.is_echo():
		cerrar()
		get_viewport().set_input_as_handled()
