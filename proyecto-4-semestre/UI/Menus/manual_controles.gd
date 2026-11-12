extends VBoxContainer
## Manual de controles: contenido nativo y navegación de foco dentro del modal.

signal pagina_cambiada(indice: int)

const TINTA := Color("173b50")
const CREMA := Color("fff1d8")
const CORAL := Color("ff785f")
const FUENTE := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
const TITULAR := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const CATEGORIAS := ["Movimiento", "Acciones", "Menús"]

var pestanas: Array[Button] = []
var paginas: Array[VBoxContainer] = []
var pagina_actual: int = 0


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 8)
	add_child(cabecera)
	var enfasis := FontVariation.new()
	enfasis.base_font = FUENTE
	enfasis.variation_opentype = {2003265652: 800.0}
	for indice: int in range(CATEGORIAS.size()):
		var boton := Button.new()
		boton.text = CATEGORIAS[indice]
		boton.custom_minimum_size = Vector2(0, 64)
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		boton.add_theme_font_override("font", enfasis)
		boton.add_theme_font_size_override("font_size", 26)
		boton.pressed.connect(seleccionar.bind(indice))
		boton.focus_entered.connect(seleccionar.bind(indice))
		boton.gui_input.connect(_entrada_pestana.bind(indice))
		cabecera.add_child(boton)
		pestanas.append(boton)

	var hoja := PanelContainer.new()
	hoja.custom_minimum_size = Vector2(0, 510)
	hoja.add_theme_stylebox_override("panel", _caja(CREMA, 0, 32))
	add_child(hoja)
	for indice: int in range(CATEGORIAS.size()):
		var pagina := VBoxContainer.new()
		pagina.name = CATEGORIAS[indice]
		pagina.add_theme_constant_override("separation", 20)
		hoja.add_child(pagina)
		paginas.append(pagina)
	_crear_movimiento(paginas[0])
	_crear_acciones(paginas[1])
	_crear_menus(paginas[2])
	seleccionar(0)


func seleccionar(indice: int) -> void:
	pagina_actual = clampi(indice, 0, CATEGORIAS.size() - 1)
	for i: int in range(pestanas.size()):
		var activa := i == pagina_actual
		paginas[i].visible = activa
		var boton := pestanas[i]
		boton.add_theme_stylebox_override("normal", _caja(CREMA if activa else Color("2a5062"), 12, 12, true))
		boton.add_theme_stylebox_override("hover", _caja(CREMA if activa else Color("365e70"), 12, 12, true))
		boton.add_theme_stylebox_override("pressed", _caja(CREMA, 12, 12, true))
		for estado: String in ["font_color", "font_hover_color", "font_focus_color"]:
			boton.add_theme_color_override(estado, TINTA if activa else CREMA)
		boton.add_theme_color_override("font_pressed_color", TINTA)
		var foco := _caja(Color.TRANSPARENT, 10, 0, true)
		foco.draw_center = false
		foco.border_color = CORAL
		foco.set_border_width_all(3)
		boton.add_theme_stylebox_override("focus", foco)
	pagina_cambiada.emit(pagina_actual)


func _entrada_pestana(evento: InputEvent, indice: int) -> void:
	if not evento is InputEventKey or not evento.pressed:
		return
	var destino := indice
	match evento.keycode:
		KEY_LEFT:
			destino = (indice + pestanas.size() - 1) % pestanas.size()
		KEY_RIGHT:
			destino = (indice + 1) % pestanas.size()
		KEY_HOME:
			destino = 0
		KEY_END:
			destino = pestanas.size() - 1
		_:
			return
	get_viewport().set_input_as_handled()
	pestanas[destino].grab_focus()


func _crear_movimiento(pagina: VBoxContainer) -> void:
	pagina.add_child(_texto("DOMINA LA OFICINA", 38, true))
	var grupos := HBoxContainer.new()
	grupos.add_theme_constant_override("separation", 72)
	pagina.add_child(grupos)
	for teclas: Array in [["W", "A", "S", "D"], ["↑", "←", "↓", "→"]]:
		var grupo := VBoxContainer.new()
		grupo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grupo.add_theme_constant_override("separation", 16)
		grupos.add_child(grupo)
		var cruz := GridContainer.new()
		cruz.columns = 3
		cruz.add_theme_constant_override("h_separation", 8)
		cruz.add_theme_constant_override("v_separation", 8)
		grupo.add_child(cruz)
		for celda: String in ["", teclas[0], "", teclas[1], teclas[2], teclas[3]]:
			if celda.is_empty():
				cruz.add_child(Control.new())
			else:
				cruz.add_child(_tecla(celda, Vector2(62, 60), 32))
		grupo.add_child(_texto("Moverse" if teclas[0] == "W" else "También con flechas", 25))
	pagina.add_child(_fila("Correr", ["Mayús"], "Mientras te mueves"))
	pagina.add_child(_fila("Saltar", ["Espacio"]))


func _crear_acciones(pagina: VBoxContainer) -> void:
	var interaccion := HBoxContainer.new()
	interaccion.add_theme_constant_override("separation", 28)
	pagina.add_child(interaccion)
	interaccion.add_child(_tecla("E", Vector2(112, 112), 68))
	var detalle := VBoxContainer.new()
	detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detalle.add_theme_constant_override("separation", 8)
	interaccion.add_child(detalle)
	detalle.add_child(_texto("MANOS A LA OBRA", 38, true))
	detalle.add_child(_texto("Imprimir, usar una estación, lanzar o recoger la hoja.", 27))
	pagina.add_child(_fila("Apagar incendios", ["Mantener", "E"], "Con el extintor recogido"))
	pagina.add_child(_fila("Cambiar cámara", ["C", "o", "1", "2", "3"], "Actual, frontal o desde arriba"))
	pagina.add_child(_fila("Ver clasificación", ["Mantener", "Tab"]))
	pagina.add_child(_fila("Emotes", ["Mantener", "G"], "En desarrollo"))


func _crear_menus(pagina: VBoxContainer) -> void:
	pagina.add_child(_texto("ENTRE PANTALLAS", 38, true))
	pagina.add_child(_fila("Siguiente opción", ["Tab"]))
	pagina.add_child(_fila("Opción anterior", ["Mayús", "+", "Tab"]))
	pagina.add_child(_fila("Confirmar", ["Enter", "o", "Espacio"]))
	pagina.add_child(_fila("Pausar / volver", ["Esc"], "Regresar a la pantalla anterior"))


func _fila(accion: String, teclas: Array, nota: String = "") -> VBoxContainer:
	var bloque := VBoxContainer.new()
	bloque.add_theme_constant_override("separation", 12)
	var linea := HSeparator.new()
	var trazo := StyleBoxLine.new()
	trazo.color = Color(TINTA, 0.18)
	trazo.thickness = 1
	linea.add_theme_stylebox_override("separator", trazo)
	bloque.add_child(linea)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 18)
	bloque.add_child(fila)
	var descripcion := VBoxContainer.new()
	descripcion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	descripcion.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	descripcion.add_theme_constant_override("separation", 3)
	fila.add_child(descripcion)
	descripcion.add_child(_texto(accion, 27))
	if not nota.is_empty():
		descripcion.add_child(_texto(nota, 22))
	var combinacion := HBoxContainer.new()
	combinacion.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	combinacion.add_theme_constant_override("separation", 8)
	fila.add_child(combinacion)
	for tecla: String in teclas:
		if tecla in ["o", "+", "Mantener"]:
			var operador := _texto(tecla, 21)
			operador.autowrap_mode = TextServer.AUTOWRAP_OFF
			operador.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			combinacion.add_child(operador)
		else:
			combinacion.add_child(_tecla(tecla))
	return bloque


func _tecla(etiqueta: String, minimo := Vector2(48, 48), tamano: int = 25) -> PanelContainer:
	var tecla := PanelContainer.new()
	tecla.custom_minimum_size = minimo
	tecla.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var estilo := _caja(TINTA, 7, 10)
	estilo.border_color = CREMA
	estilo.set_border_width_all(2)
	estilo.shadow_color = Color("0c2839")
	estilo.shadow_offset = Vector2(0, 3)
	estilo.shadow_size = 1
	tecla.add_theme_stylebox_override("panel", estilo)
	var texto := _texto(etiqueta, tamano, true)
	texto.add_theme_color_override("font_color", CREMA)
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto.autowrap_mode = TextServer.AUTOWRAP_OFF
	tecla.add_child(texto)
	return tecla


func _texto(valor: String, tamano: int, titular: bool = false) -> Label:
	var texto := Label.new()
	texto.text = valor
	if titular:
		texto.add_theme_font_override("font", TITULAR)
	else:
		var lectura := FontVariation.new()
		lectura.base_font = FUENTE
		lectura.variation_opentype = {2003265652: 700.0 if tamano >= 25 else 600.0}
		texto.add_theme_font_override("font", lectura)
	texto.add_theme_font_size_override("font_size", tamano)
	texto.add_theme_color_override("font_color", TINTA)
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return texto


func _caja(color: Color, radio: int, margen: int, solo_arriba: bool = false) -> StyleBoxFlat:
	var caja := StyleBoxFlat.new()
	caja.bg_color = color
	caja.set_corner_radius_all(radio)
	if solo_arriba:
		caja.corner_radius_bottom_left = 0
		caja.corner_radius_bottom_right = 0
	caja.content_margin_left = margen
	caja.content_margin_right = margen
	caja.content_margin_top = margen
	caja.content_margin_bottom = margen
	return caja
