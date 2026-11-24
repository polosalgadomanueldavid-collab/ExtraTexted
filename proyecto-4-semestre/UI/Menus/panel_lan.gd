extends CanvasLayer
## Selección, conexión y sala LAN. La sesión conserva la autoridad del inicio.
const TINTA := Color("173b50")
const CREMA := Color("fff1d8")
const CORAL := Color("ff785f")
const VERDE := Color("c5d6a8")
const TEMA := preload("res://UI/Menus/tema_ajustes.tres")
const ARTE := preload("res://UI/Menus/arte_sala_lan.gd")
const RETRATOS := [preload("res://UI/Despacho/retrato_policia.png"), preload("res://UI/Despacho/retrato_policia_relevo.png")]
const TAMANO := Vector2(1000, 600)

var fondo: ColorRect
var panel: PanelContainer
var alias_jugador: LineEdit
var direccion: LineEdit
var estado: Label
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
var _elegir_unirse: Button
var _etiqueta_ip: Label
var _ayuda_red: Label
var _fila_ip: Control
var _valor_ip: LineEdit
var _ayuda_inicio: Label
var _ip := ""
var _vista_unirse := false
var _vista_anterior := ""
var _tarjetas: Array[Dictionary] = []


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	# La misma jerarquía de Opciones: Luckiest Guy en títulos y botones, Nunito en lectura.
	fondo = ColorRect.new()
	fondo.color = Color("204753")
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var decorado := ARTE.new()
	decorado.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(decorado)
	_lienzo = Control.new()
	_lienzo.size = TAMANO
	_lienzo.theme = TEMA
	fondo.add_child(_lienzo)
	panel = PanelContainer.new()
	panel.size = TAMANO
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var papel := _estilo(CREMA, TINTA, 16, 3)
	papel.shadow_color = Color(0.02, 0.08, 0.10, 0.25)
	papel.shadow_offset = Vector2(0, 5)
	papel.shadow_size = 1
	panel.add_theme_stylebox_override("panel", papel)
	_lienzo.add_child(panel)
	var cinta := ARTE.new()
	cinta.tipo = ARTE.Tipo.CINTA
	cinta.position = Vector2(430, -20)
	cinta.size = Vector2(140, 42)
	_lienzo.add_child(cinta)
	_titulo = _etiqueta(_lienzo, "Multijugador", Vector2(60, 35), Vector2(620, 84), 58, true)
	_subtitulo = _etiqueta(_lienzo, "2 jugadores · LAN", Vector2(682, 59), Vector2(258, 36), 23)
	_subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_plazas = _etiqueta(_lienzo, "", Vector2(828, 46), Vector2(112, 60), 40)
	_plazas.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_conexion = Control.new()
	_lienzo.add_child(_conexion)
	_crear_conexion()
	_sala = Control.new()
	_lienzo.add_child(_sala)
	_crear_sala()
	estado = _etiqueta(_lienzo, "", Vector2(60, 438), Vector2(880, 58), 22)
	estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	estado.add_theme_color_override("font_color", Color("994a3b"))
	_volver = _boton(_lienzo, "← Volver", Vector2(48, 514), Vector2(176, 56), _retroceder)
	SesionLAN.sala_actualizada.connect(_actualizar)
	SesionLAN.aviso.connect(func(_mensaje: String): _actualizar())
	fondo.resized.connect(_ajustar)
	_ajustar()
	fondo.hide()
	_actualizar()


func _crear_conexion() -> void:
	_etiqueta(_conexion, "Tu nombre", Vector2(90, 184), Vector2(256, 64), 28)
	alias_jugador = _campo(_conexion, "Nombre", Vector2(350, 184), Vector2(560, 64))
	alias_jugador.max_length = 10
	alias_jugador.text_submitted.connect(func(_valor: String):
		(direccion if _vista_unirse else crear).grab_focus())
	crear = _boton(_conexion, "Crear partida", Vector2(90, 310), Vector2(402, 68), _crear_partida, true)
	_elegir_unirse = _boton(_conexion, "Unirse", Vector2(514, 310), Vector2(396, 68), _abrir_union)
	_ayuda_red = _etiqueta(_conexion, "Usen la misma red.", Vector2(90, 402), Vector2(820, 36), 24)
	_ayuda_red.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta_ip = _etiqueta(_conexion, "IP del anfitrión", Vector2(90, 286), Vector2(256, 64), 27)
	direccion = _campo(_conexion, "192.168.1.10", Vector2(350, 286), Vector2(560, 64))
	direccion.max_length = 45
	direccion.text_submitted.connect(func(_valor: String): _conectar())
	unir = _boton(_conexion, "Conectar", Vector2(660, 514), Vector2(250, 56), _conectar, true)
	individual = _boton(_conexion, "Individual", Vector2(740, 514), Vector2(190, 56), _individual)
	individual.tooltip_text = "Jugar sin compañero"


func _crear_sala() -> void:
	for indice in 2:
		_crear_tarjeta(indice)
	_fila_ip = Control.new()
	_fila_ip.position = Vector2(140, 386)
	_sala.add_child(_fila_ip)
	_etiqueta(_fila_ip, "IP", Vector2.ZERO, Vector2(58, 52), 27)
	_valor_ip = _campo(_fila_ip, "", Vector2(76, 0), Vector2(424, 52))
	_valor_ip.editable = false
	_valor_ip.focus_mode = Control.FOCUS_NONE
	_copiar = _boton(_fila_ip, "Copiar", Vector2(534, 0), Vector2(186, 52), _copiar_ip, false, 25)
	var separador := ColorRect.new()
	separador.position = Vector2(48, 500)
	separador.size = Vector2(904, 1)
	separador.color = Color("a5b1a6")
	separador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sala.add_child(separador)
	listo = _boton(_sala, "Estoy listo", Vector2(310, 518), Vector2(284, 54), Callable())
	listo.toggle_mode = true
	listo.toggled.connect(SesionLAN.establecer_listo)
	var confirmado := TEMA.get_stylebox("normal", "Button").duplicate() as StyleBoxFlat
	confirmado.bg_color = VERDE
	listo.add_theme_stylebox_override("pressed", confirmado)
	listo.add_theme_stylebox_override("hover_pressed", confirmado)
	listo.add_theme_color_override("font_pressed_color", TINTA)
	listo.add_theme_color_override("font_hover_pressed_color", TINTA)
	iniciar = _boton(_sala, "Empezar", Vector2(700, 518), Vector2(252, 54), SesionLAN.iniciar, true)
	_ayuda_inicio = _etiqueta(_sala, "", Vector2(620, 571), Vector2(332, 25), 18)
	_ayuda_inicio.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _crear_tarjeta(indice: int) -> void:
	var tarjeta := Panel.new()
	tarjeta.position = Vector2(48 + indice * 464, 142)
	tarjeta.size = Vector2(440, 218)
	tarjeta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tarjeta.add_theme_stylebox_override("panel", _estilo(Color("f8f2e2"), TINTA, 12, 2))
	_sala.add_child(tarjeta)
	var foto := Panel.new()
	foto.position = Vector2(16, 16)
	foto.size = Vector2(132, 186)
	foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foto.add_theme_stylebox_override("panel", _estilo(Color("b4d4d6"), Color.TRANSPARENT, 8, 0))
	tarjeta.add_child(foto)
	var retrato := TextureRect.new()
	retrato.texture = RETRATOS[indice]
	retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	retrato.position = Vector2(0, 8)
	retrato.size = Vector2(132, 178)
	retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foto.add_child(retrato)
	var silueta := ARTE.new()
	silueta.tipo = ARTE.Tipo.SILUETA
	silueta.position = foto.position
	silueta.size = foto.size
	tarjeta.add_child(silueta)
	var nombre := _etiqueta(tarjeta, "", Vector2(168, 24), Vector2(254, 48), 32)
	nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var rol := _etiqueta(tarjeta, "", Vector2(168, 78), Vector2(254, 36), 22)
	var sello := _etiqueta(tarjeta, "", Vector2(168, 140), Vector2(254, 46), 24)
	sello.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tarjetas.append({"retrato": retrato, "foto": foto, "silueta": silueta, "nombre": nombre, "rol": rol, "sello": sello})


func _estilo(color: Color, borde: Color, radio: int, ancho: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.border_color = borde
	estilo.set_border_width_all(ancho)
	estilo.set_corner_radius_all(radio)
	return estilo


func _etiqueta(padre: Node, texto: String, punto: Vector2, tamano: Vector2, fuente: int, titular := false) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.position = punto
	etiqueta.size = tamano
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not titular: etiqueta.theme_type_variation = &"Lectura"
	etiqueta.add_theme_font_size_override("font_size", fuente)
	etiqueta.add_theme_color_override("font_color", TINTA)
	padre.add_child(etiqueta)
	return etiqueta


func _campo(padre: Node, texto: String, punto: Vector2, tamano: Vector2) -> LineEdit:
	var campo := LineEdit.new()
	campo.position = punto
	campo.size = tamano
	campo.placeholder_text = texto
	campo.add_theme_font_size_override("font_size", 28)
	for propiedad in ["font_color", "font_uneditable_color", "caret_color"]:
		campo.add_theme_color_override(propiedad, TINTA)
	campo.add_theme_color_override("font_placeholder_color", Color("74817e"))
	var normal := _estilo(Color("f8f2e2"), TINTA, 10, 2)
	normal.content_margin_left = 22
	normal.content_margin_right = 18
	campo.add_theme_stylebox_override("normal", normal)
	campo.add_theme_stylebox_override("read_only", normal)
	campo.add_theme_stylebox_override("focus", _estilo(Color.TRANSPARENT, CORAL, 10, 3))
	padre.add_child(campo)
	return campo


func _boton(padre: Node, texto: String, punto: Vector2, tamano: Vector2, accion: Callable, principal := false, fuente := 28) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.position = punto
	boton.size = tamano
	if principal: boton.theme_type_variation = &"Volver"
	boton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	boton.add_theme_font_size_override("font_size", fuente)
	if accion.is_valid(): boton.pressed.connect(accion)
	padre.add_child(boton)
	# Los estilos normales, foco y pulsación se heredan directamente de Opciones.
	var inactivo := TEMA.get_stylebox("normal", "Button").duplicate() as StyleBoxFlat
	inactivo.bg_color = Color("d7d4c9")
	inactivo.border_color = Color("9b9f96")
	inactivo.shadow_size = 0
	inactivo.shadow_offset = Vector2.ZERO
	boton.add_theme_stylebox_override("disabled", inactivo)
	boton.add_theme_color_override("font_disabled_color", Color("66716d"))
	return boton


func _ajustar() -> void:
	var visible := get_viewport().get_visible_rect().size
	var margen := Vector2(96, 104) if visible.x >= 900 else Vector2(32, 56)
	var factor := minf((visible.x - margen.x) / TAMANO.x, (visible.y - margen.y) / TAMANO.y)
	_lienzo.scale = Vector2.ONE * maxf(0.1, factor)
	_lienzo.position = (visible - TAMANO * _lienzo.scale) * 0.5


func abrir(origen: Control) -> void:
	menu = origen
	menu.presentacion.hide()
	fondo.show()
	_vista_anterior = ""
	_actualizar()


func cerrar() -> void:
	if SesionLAN.activa and not SesionLAN.en_partida:
		SesionLAN.cerrar()
	SesionLAN.ultimo_aviso = ""
	_vista_unirse = false
	fondo.hide()
	if is_instance_valid(menu):
		menu.presentacion.show()
		menu.play_button.grab_focus()


func _retroceder() -> void:
	if SesionLAN.activa and not SesionLAN.participantes.has(SesionLAN.id_local()):
		SesionLAN.cerrar()
		_actualizar()
	elif not SesionLAN.activa and _vista_unirse:
		_vista_unirse = false
		SesionLAN.ultimo_aviso = ""
		_actualizar()
		_elegir_unirse.grab_focus()
	else:
		cerrar()


func _abrir_union() -> void:
	_vista_unirse = true
	SesionLAN.ultimo_aviso = ""
	_actualizar()
	(alias_jugador if alias_jugador.text.is_empty() else direccion).grab_focus()


func _crear_partida() -> void:
	if not SesionLAN.activa:
		SesionLAN.crear(alias_jugador.text)


func _conectar() -> void:
	if SesionLAN.activa:
		return
	_vista_unirse = true
	SesionLAN.unirse(direccion.text, alias_jugador.text)
	_actualizar()


func _copiar_ip() -> void:
	DisplayServer.clipboard_set(_ip)
	_copiar.text = "Copiada"


func _individual() -> void:
	cerrar()
	menu.jugar_individual()


func _actualizar() -> void:
	if estado == null: return
	var activa: bool = SesionLAN.activa
	var conectando: bool = activa and not SesionLAN.participantes.has(SesionLAN.id_local())
	var en_sala := activa and not conectando
	var vista := "sala" if en_sala else ("conectando" if conectando else ("unirse" if _vista_unirse else "entrada"))
	_sala.visible = en_sala
	_conexion.visible = not en_sala
	_titulo.text = "Sala" if en_sala else ("Unirse" if _vista_unirse else "Multijugador")
	_subtitulo.visible = not en_sala and not _vista_unirse
	_plazas.visible = en_sala
	_volver.text = "Salir" if en_sala else ("Cancelar" if conectando else "← Volver")
	alias_jugador.editable = not activa
	direccion.editable = not activa
	direccion.visible = _vista_unirse
	_etiqueta_ip.visible = _vista_unirse
	crear.visible = not _vista_unirse
	_elegir_unirse.visible = not _vista_unirse
	individual.visible = not _vista_unirse
	_ayuda_red.visible = not _vista_unirse and SesionLAN.ultimo_aviso.is_empty()
	unir.visible = _vista_unirse
	unir.disabled = activa
	unir.text = "Conectando…" if conectando else "Conectar"
	var local_listo: bool = SesionLAN.participantes.get(SesionLAN.id_local(), {}).get("listo", false)
	listo.set_pressed_no_signal(local_listo)
	listo.text = "Listo ✓" if local_listo else "Estoy listo"
	listo.disabled = SesionLAN.cargando
	var ids: Array = SesionLAN.participantes.keys()
	ids.sort()
	var preparados := ids.size() == 2
	for indice in 2:
		var tarjeta: Dictionary = _tarjetas[indice]
		var ocupado := indice < ids.size()
		var jugador: Dictionary = SesionLAN.participantes[ids[indice]] if ocupado else {}
		var preparado: bool = jugador.get("listo", false)
		preparados = preparados and preparado
		tarjeta.nombre.text = str(jugador.get("alias", "Esperando…"))
		tarjeta.nombre.tooltip_text = tarjeta.nombre.text
		tarjeta.nombre.position.y = 24 if ocupado else 76
		tarjeta.foto.visible = ocupado
		tarjeta.silueta.visible = not ocupado
		tarjeta.rol.visible = ocupado
		tarjeta.rol.text = "Anfitrión" if indice == 0 else "Compañero"
		if ocupado and ids[indice] == SesionLAN.id_local(): tarjeta.rol.text = "Tú · " + tarjeta.rol.text
		tarjeta.sello.visible = ocupado
		tarjeta.sello.text = "✓ Listo" if preparado else "Sin confirmar"
		tarjeta.sello.add_theme_stylebox_override("normal", _estilo(VERDE if preparado else CREMA, TINTA, 8, 1))
	_plazas.text = "%d/2" % ids.size()
	iniciar.visible = SesionLAN.es_anfitrion()
	iniciar.disabled = not preparados or not SesionLAN.es_anfitrion() or SesionLAN.cargando
	_ayuda_inicio.text = ""
	_ayuda_inicio.position = Vector2(620, 571) if SesionLAN.es_anfitrion() else Vector2(650, 522)
	_ayuda_inicio.size = Vector2(332, 25) if SesionLAN.es_anfitrion() else Vector2(302, 50)
	_ayuda_inicio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if en_sala:
		if not SesionLAN.es_anfitrion():
			_ayuda_inicio.text = "Esperando al anfitrión" if preparados else "Ambos deben estar listos"
		elif not preparados:
			_ayuda_inicio.text = "Falta un jugador" if ids.size() < 2 else "Ambos deben estar listos"
	estado.text = "" if activa else _mensaje_corto(SesionLAN.ultimo_aviso)
	estado.tooltip_text = SesionLAN.ultimo_aviso
	estado.visible = not estado.text.is_empty()
	if en_sala:
		if vista != _vista_anterior: _copiar.text = "Copiar"
		_actualizar_ip()
	_actualizar_foco(conectando, en_sala)
	if fondo.visible and vista != _vista_anterior:
		if en_sala: listo.grab_focus()
		elif conectando: _volver.grab_focus()
		elif _vista_unirse and not alias_jugador.text.is_empty(): direccion.grab_focus()
		else: alias_jugador.grab_focus()
	_vista_anterior = vista


func _actualizar_ip() -> void:
	var direcciones := PackedStringArray()
	if SesionLAN.es_anfitrion():
		for ip: String in IP.get_local_addresses():
			if ip.contains(".") and not ip.begins_with("127.") and not ip.begins_with("169.254."):
				direcciones.append(ip)
		_ip = direcciones[0] if not direcciones.is_empty() else ""
	else:
		_ip = direccion.text.strip_edges()
	if _valor_ip.text != _ip:
		_copiar.text = "Copiar"
	_valor_ip.text = _ip
	_valor_ip.placeholder_text = "Sin conexión LAN"
	_valor_ip.tooltip_text = ", ".join(direcciones)
	_copiar.disabled = _ip.is_empty()
	_copiar.tooltip_text = "Copiar " + _ip


func _mensaje_corto(mensaje: String) -> String:
	if mensaje.contains("IP válida"): return "Escribe una IP válida."
	if mensaje.contains("No se pudo conectar") or mensaje.contains("tiempo de espera"):
		return "No se pudo conectar. Revisa la IP y la red."
	if mensaje.contains("puerto UDP"): return "No se pudo crear la sala. Cierra la otra partida."
	if mensaje.contains("versión incompatible"): return "Sala no disponible. Revisa la versión del juego."
	if mensaje.contains("desconectó"): return "Tu compañero se desconectó."
	if mensaje in ["Sala creada. Esperando al compañero.", "Conectado. Confirma que estás listo.", "Conectando…"]:
		return ""
	return mensaje


func _actualizar_foco(conectando: bool, en_sala: bool) -> void:
	var controles: Array[Control] = []
	if conectando:
		controles = [_volver]
	elif en_sala:
		if not _copiar.disabled: controles.append(_copiar)
		controles.append(_volver)
		if not listo.disabled: controles.append(listo)
		if iniciar.visible and not iniciar.disabled: controles.append(iniciar)
	elif _vista_unirse:
		controles = [alias_jugador, direccion, _volver, unir]
	else:
		controles = [alias_jugador, crear, _elegir_unirse, _volver, individual]
	for i in controles.size():
		var anterior := controles[i].get_path_to(controles[posmod(i - 1, controles.size())])
		var siguiente := controles[i].get_path_to(controles[(i + 1) % controles.size()])
		controles[i].focus_next = siguiente
		controles[i].focus_previous = anterior
		controles[i].focus_neighbor_top = anterior
		controles[i].focus_neighbor_bottom = siguiente
		# Los campos conservan izquierda/derecha para editar el texto.
		if controles[i] is Button:
			controles[i].focus_neighbor_left = anterior
			controles[i].focus_neighbor_right = siguiente


func _input(event: InputEvent) -> void:
	if fondo.visible and event.is_action_pressed("Cancel") and not event.is_echo():
		_retroceder()
		get_viewport().set_input_as_handled()
