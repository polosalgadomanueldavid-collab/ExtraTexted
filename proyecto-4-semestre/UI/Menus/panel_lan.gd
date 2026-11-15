extends CanvasLayer

var fondo: ColorRect
var panel: PanelContainer
var alias_jugador: LineEdit
var direccion: LineEdit
var estado: Label
var lista: Label
var listo: CheckButton
var iniciar: Button
var crear: Button
var unir: Button
var individual: Button
var menu: Control

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	fondo = ColorRect.new()
	fondo.color = Color(0.03, 0.09, 0.12, 0.86)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(centro)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(490, 0)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("fff1d8")
	estilo.border_color = Color("173b50")
	estilo.set_border_width_all(4)
	estilo.set_corner_radius_all(12)
	estilo.content_margin_left = 28
	estilo.content_margin_right = 28
	estilo.content_margin_top = 24
	estilo.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", estilo)
	panel.add_theme_font_override("font", preload("res://UI/Menus/ArtePiloto/Nunito.ttf"))
	centro.add_child(panel)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 12)
	panel.add_child(columna)
	var titulo := Label.new()
	titulo.text = "COMPARTE EL TURNO"
	titulo.add_theme_color_override("font_color", Color("173b50"))
	titulo.add_theme_font_size_override("font_size", 28)
	columna.add_child(titulo)
	individual = _boton(columna, "Individual", _individual)
	alias_jugador = LineEdit.new()
	alias_jugador.placeholder_text = "Tu alias (máximo 10 caracteres)"
	alias_jugador.max_length = 10
	columna.add_child(alias_jugador)
	direccion = LineEdit.new()
	direccion.placeholder_text = "IP del anfitrión · Ej. 192.168.1.10"
	columna.add_child(direccion)
	crear = _boton(columna, "Crear partida LAN", func(): SesionLAN.crear(alias_jugador.text); _actualizar())
	unir = _boton(columna, "Unirse por IP", func(): SesionLAN.unirse(direccion.text, alias_jugador.text); _actualizar())
	lista = Label.new()
	lista.add_theme_color_override("font_color", Color("173b50"))
	columna.add_child(lista)
	listo = CheckButton.new()
	listo.text = "Estoy listo"
	listo.add_theme_color_override("font_color", Color("173b50"))
	listo.toggled.connect(SesionLAN.establecer_listo)
	columna.add_child(listo)
	iniciar = _boton(columna, "Iniciar turno", SesionLAN.iniciar)
	estado = Label.new()
	estado.custom_minimum_size.x = 420
	estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	estado.add_theme_color_override("font_color", Color("173b50"))
	columna.add_child(estado)
	_boton(columna, "Volver", cerrar)
	SesionLAN.sala_actualizada.connect(_actualizar)
	SesionLAN.aviso.connect(func(_texto: String): _actualizar())
	fondo.hide()

func _boton(padre: Node, texto: String, accion: Callable) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size.y = 40
	boton.pressed.connect(accion)
	padre.add_child(boton)
	return boton

func abrir(origen: Control) -> void:
	menu = origen
	fondo.show()
	_actualizar()
	individual.grab_focus()

func cerrar() -> void:
	if SesionLAN.activa and not SesionLAN.en_partida:
		SesionLAN.cerrar()
	SesionLAN.ultimo_aviso = ""
	fondo.hide()

func _individual() -> void:
	cerrar()
	menu.jugar_individual()

func _actualizar() -> void:
	if estado == null:
		return
	var activa: bool = SesionLAN.activa
	crear.disabled = activa
	unir.disabled = activa
	alias_jugador.editable = not activa
	direccion.editable = not activa
	listo.visible = activa and SesionLAN.participantes.has(SesionLAN.id_local())
	listo.set_pressed_no_signal(bool(SesionLAN.participantes.get(SesionLAN.id_local(), {}).get("listo", false)))
	iniciar.visible = SesionLAN.es_anfitrion()
	var preparados := SesionLAN.participantes.size() == 2
	var filas := PackedStringArray()
	for id: int in SesionLAN.participantes:
		var jugador: Dictionary = SesionLAN.participantes[id]
		preparados = preparados and bool(jugador.listo)
		filas.append("%s · %s" % [jugador.alias, "LISTO" if jugador.listo else "Preparándose"])
	lista.text = "\n".join(filas)
	iniciar.disabled = not preparados
	estado.text = SesionLAN.ultimo_aviso
	if SesionLAN.es_anfitrion():
		var direcciones := PackedStringArray()
		for ip: String in IP.get_local_addresses():
			if ip.contains(".") and not ip.begins_with("127.") and not ip.begins_with("169.254."):
				direcciones.append(ip)
		estado.text += "\nIP de este equipo: " + ", ".join(direcciones)

func _unhandled_input(event: InputEvent) -> void:
	if fondo.visible and event.is_action_pressed("Cancel"):
		cerrar()
		get_viewport().set_input_as_handled()
