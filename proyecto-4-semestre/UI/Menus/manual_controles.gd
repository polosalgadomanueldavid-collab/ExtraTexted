extends VBoxContainer
class_name ManualControles
signal navegacion_cambiada
## Manual de controles: contenido nativo y navegación de foco dentro del modal.

const TINTA := Color("173b50")
const CREMA := Color("fff1d8")
const CORAL := Color("ff785f")
const FUENTE := preload("res://UI/Menus/fuente_lectura.tres")
const TEMA_AJUSTES := preload("res://UI/Menus/tema_ajustes.tres")
const CATEGORIAS := ["Movimiento", "Acciones", "Menús", "Objetos"]

var pestanas: Array[Button] = []
var paginas: Array[VBoxContainer] = []
var pagina_actual: int = 0
var cabecera: HBoxContainer
var hoja: PanelContainer
var boton_control: Button
var pagina_mando: VBoxContainer
var pestanas_mando: Array[Button] = []
var pagina_mando_actual := 0
var _infografia_mando: Control


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	cabecera = HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 8)
	add_child(cabecera)
	for indice: int in range(CATEGORIAS.size()):
		var boton := Button.new()
		boton.text = CATEGORIAS[indice].to_upper()
		boton.custom_minimum_size = Vector2(0, 64)
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		boton.add_theme_font_override("font", TEMA_AJUSTES.get_font("font", "Button"))
		boton.add_theme_font_size_override("font_size", 32)
		boton.pressed.connect(seleccionar.bind(indice))
		boton.focus_entered.connect(seleccionar.bind(indice))
		boton.focus_entered.connect(_recordar_pestana.bind(boton))
		boton.gui_input.connect(_entrada_pestana.bind(indice))
		cabecera.add_child(boton)
		pestanas.append(boton)

	hoja = PanelContainer.new()
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
	_crear_objetos(paginas[3])
	boton_control = _boton_pie("CONTROL")
	boton_control.pressed.connect(_mostrar_mando)
	add_child(boton_control)
	pagina_mando = _crear_pagina_mando()
	pagina_mando.visible = false
	add_child(pagina_mando)
	seleccionar(0)


func _boton_pie(etiqueta: String) -> Button:
	var boton := Button.new()
	boton.text = etiqueta
	boton.custom_minimum_size = Vector2(0, 54)
	boton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boton.add_theme_font_override("font", TEMA_AJUSTES.get_font("font", "Button"))
	boton.add_theme_font_size_override("font_size", 25)
	_estilo_foco_unico(boton)
	return boton


func _estilo_foco_unico(boton: Button) -> void:
	for estado: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		boton.add_theme_color_override(estado, CREMA)
	var estilo := _caja(TINTA, 12, 14)
	estilo.border_color = Color("54717f")
	estilo.set_border_width_all(1)
	boton.add_theme_stylebox_override("normal", estilo)
	boton.add_theme_stylebox_override("hover", _caja(Color("2a5062"), 12, 14))
	boton.add_theme_stylebox_override("pressed", estilo)
	boton.add_theme_stylebox_override("hover_pressed", _caja(Color("2a5062"), 12, 14))
	var foco := _caja(Color.TRANSPARENT, 12, 14)
	foco.draw_center = false
	foco.border_color = CORAL
	foco.set_border_width_all(4)
	boton.add_theme_stylebox_override("focus", foco)


func _mostrar_mando() -> void:
	cabecera.hide()
	hoja.hide()
	boton_control.hide()
	pagina_mando.show()
	navegacion_cambiada.emit()
	pestanas_mando[0].grab_focus()


func _volver_teclado() -> void:
	pagina_mando.hide()
	cabecera.show()
	hoja.show()
	boton_control.show()
	navegacion_cambiada.emit()
	boton_control.grab_focus()


func _crear_pagina_mando() -> VBoxContainer:
	var pagina := VBoxContainer.new()
	pagina.name = "PanelMando"
	pagina.add_theme_constant_override("separation", 12)
	var titulo := _texto("CONTROLES CON MANDO", 34, true)
	titulo.add_theme_color_override("font_color", CREMA)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pagina.add_child(titulo)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 540)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _caja(CREMA, 0, 18))
	pagina.add_child(panel)
	var infografia := preload("res://UI/Menus/infografia_mando.gd").new()
	_infografia_mando = infografia
	infografia.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	infografia.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(infografia)
	var selector := HBoxContainer.new()
	selector.alignment = BoxContainer.ALIGNMENT_CENTER
	selector.add_theme_constant_override("separation", 12)
	pagina.add_child(selector)
	pagina.move_child(selector, 1)
	var grupo := ButtonGroup.new()
	for i: int in range(3):
		var boton := _boton_pie(["ACCIONES", "MENÚS", "OBJETOS"][i])
		boton.toggle_mode = true
		boton.button_group = grupo
		boton.button_pressed = i == 0
		boton.pressed.connect(_seleccionar_mando.bind(i))
		boton.focus_entered.connect(_seleccionar_mando.bind(i))
		boton.focus_entered.connect(_recordar_pestana.bind(boton))
		selector.add_child(boton)
		pestanas_mando.append(boton)
	var nota := _texto("Un mando por jugador local · En LAN, cada participante controla su propio personaje.", 18)
	nota.add_theme_color_override("font_color", CREMA)
	nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pagina.add_child(nota)
	var volver := _boton_pie("VOLVER A TECLADO")
	volver.name = "BotonVolverMando"
	volver.pressed.connect(_volver_teclado)
	pagina.add_child(volver)
	return pagina


func _seleccionar_mando(indice: int) -> void:
	pagina_mando_actual = indice
	for i in pestanas_mando.size():
		pestanas_mando[i].set_pressed_no_signal(i == indice)
	_infografia_mando.mostrar(indice)


func _recordar_pestana(boton: Button) -> void:
	if not is_instance_valid(pagina_mando):
		return
	var pie: Button = pagina_mando.get_node("BotonVolverMando") if pagina_mando.visible else boton_control
	pie.focus_neighbor_top = pie.get_path_to(boton)


func controles_foco() -> Array[Control]:
	var controles: Array[Control] = []
	if pagina_mando.visible:
		controles.append_array(pestanas_mando)
		controles.append(pagina_mando.get_node("BotonVolverMando"))
	else:
		controles.append_array(pestanas)
		controles.append(boton_control)
	return controles

func configurar_navegacion(cerrar: Button) -> void:
	var fila: Array[Button] = pestanas_mando if pagina_mando.visible else pestanas
	var pie: Button = pagina_mando.get_node("BotonVolverMando") if pagina_mando.visible else boton_control
	_estilo_foco_unico(cerrar)
	for i: int in range(fila.size()):
		var boton := fila[i]
		boton.focus_neighbor_left = boton.get_path_to(fila[posmod(i - 1, fila.size())])
		boton.focus_neighbor_right = boton.get_path_to(fila[(i + 1) % fila.size()])
		boton.focus_neighbor_bottom = boton.get_path_to(pie)
		boton.focus_neighbor_top = boton.get_path_to(cerrar)
	pie.focus_neighbor_top = pie.get_path_to(fila[pagina_mando_actual if pagina_mando.visible else pagina_actual])
	pie.focus_neighbor_bottom = pie.get_path_to(cerrar)
	cerrar.focus_neighbor_top = cerrar.get_path_to(pie)
	cerrar.focus_neighbor_bottom = cerrar.get_path_to(fila[0])

func seleccionar(indice: int) -> void:
	pagina_actual = clampi(indice, 0, CATEGORIAS.size() - 1)
	for i: int in range(pestanas.size()):
		var activa := i == pagina_actual
		paginas[i].visible = activa
		var boton := pestanas[i]
		_estilo_foco_unico(boton)


func _estilo_pestana(color: Color) -> StyleBoxFlat:
	var estilo := _caja(color, 14, 12, true)
	estilo.border_color = Color("102f40")
	estilo.set_border_width_all(3)
	estilo.border_width_bottom = 0
	return estilo


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
	if OS.has_feature("android"):
		pagina.add_child(_texto("MUÉVETE POR LA OFICINA", 38, true))
		pagina.add_child(_fila("Caminar", ["Palanca izquierda"], "Arrastra el círculo en la dirección deseada"))
		pagina.add_child(_fila("Correr", ["CORRER"], "Mantén pulsado mientras te mueves"))
		pagina.add_child(_fila("Saltar", ["SALTAR"]))
		return
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
	if OS.has_feature("android"):
		pagina.add_child(_texto("MANOS A LA OBRA", 38, true))
		pagina.add_child(_fila("Interactuar y recoger", ["USAR"], "También sirve para imprimir y trabajar en estaciones"))
		pagina.add_child(_fila("Emotes", ["GESTOS"], "Toca un gesto en la ruleta; toca afuera para cerrarla"))
		pagina.add_child(_fila("Cámara y puntos", ["CÁMARA", "TABLA"]))
		return
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
	pagina.add_child(_fila("Ruleta de emotes", ["G"], "Elegir con clic · cerrar con G o Esc"))


func _crear_menus(pagina: VBoxContainer) -> void:
	if OS.has_feature("android"):
		pagina.add_child(_texto("ENTRE PANTALLAS", 38, true))
		pagina.add_child(_fila("Menús y tienda", ["Tocar"], "Toca botones y desliza las listas para recorrerlas"))
		pagina.add_child(_fila("Pruebas de estaciones", ["‹", "USAR", "›"], "Cambia de opción y confirma con los botones táctiles"))
		pagina.add_child(_fila("Pausar o volver", ["PAUSA", "VOLVER"]))
		return
	pagina.add_child(_texto("ENTRE PANTALLAS", 38, true))
	pagina.add_child(_fila("Siguiente opción", ["Tab"]))
	pagina.add_child(_fila("Opción anterior", ["Mayús", "+", "Tab"]))
	pagina.add_child(_fila("Confirmar", ["Enter", "o", "Espacio"]))
	pagina.add_child(_fila("Pausar / volver", ["Esc"], "Regresar a la pantalla anterior"))


func _crear_objetos(pagina: VBoxContainer) -> void:
	if OS.has_feature("android"):
		pagina.add_child(_texto("MÁQUINA EXPENDEDORA", 38, true))
		pagina.add_child(_fila("Comprar", ["USAR"], "Toca el producto y recógelo de la bandeja"))
		pagina.add_child(_fila("Usar un objeto", ["TOCA"], "Toca su medallón de inventario en la parte superior izquierda"))
		pagina.add_child(_fila("Café", ["BEBER"], "Toca el medallón cuando lleves café"))
		return
	pagina.add_child(_texto("MÁQUINA EXPENDEDORA", 38, true))
	pagina.add_child(_texto("Abre con E en descanso. Compra con puntos y guarda una unidad.", 25))
	pagina.add_child(_fila("Chocolate", ["Z"], "Corre más rápido durante 25 segundos"))
	pagina.add_child(_fila("Dona", ["X"], "Barriguita y salto sobre mesas durante 10 segundos"))
	pagina.add_child(_fila("Papa tiempo", ["V"], "Detiene el mundo 12 segundos; puedes resolver denuncias"))
	pagina.add_child(_fila("El Avatar", ["N"], "Resuelve el evento activo con su elemento; un solo uso"))


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
	estilo.border_color = Color("3b6675")
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
		texto.add_theme_font_override("font", TEMA_AJUSTES.get_font("font", "Button"))
	else:
		texto.add_theme_font_override("font", FUENTE)
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
