class_name PanelCircuitos
extends Control
## El progreso del circuito actual se conserva al cerrar y reabrir su tipo y semilla.

signal circuito_resuelto
signal cerrado

const TAMANO_DISENO := Vector2(1080, 630)
const VERDE := Color("83efb4")
const AMBAR := Color("f2c66e")
const TEXTO := Color("e9f2ec")
const SECUNDARIO := Color("99afa9")
const FONDO := Color("101d20")
const COLORES_CABLE := [Color("83efb4"), Color("74c9f1"), Color("f2c66e"), Color("f496a6")]
const NOMBRES_CABLE := ["VERDE", "AZUL", "ÁMBAR", "ROSA"]
const NOMBRES_LINEA := ["ALUMBRADO", "DESPACHO", "RESERVA", "AUXILIARES"]
const TITULOS := ["REARMAR INTERRUPTORES", "DISTRIBUIR ENERGÍA", "SINCRONIZAR ANILLOS", "CONECTAR CABLEADO"]
const INSTRUCCIONES := [
	"Activa los cinco interruptores. Todas las líneas deben quedar en verde.",
	"Mueve cada regulador hasta igualar su objetivo. Cada marca equivale a 10 unidades.",
	"Pulsa FIJAR cuando el indicador blanco entre en el arco verde. Sincroniza los tres anillos.",
	"Selecciona un origen y después su destino con el mismo color y número. Une los cuatro pares."
]

# Controles ordinarios disponibles para automatización y navegación por teclado.
var interruptores: Array[Button] = []
var reguladores: Array[HSlider] = []
var botones_anillos: Array[Button] = []
var origenes_cables: Array[Button] = []
var destinos_cables: Array[Button] = []

var _clave_estado: String = ""
var _estado: Dictionary = {}
var _tipo: int = 0
var _armado: bool = false
var _abierto: bool = false
var _seleccion_cable: int = -1
var _lienzo: Control
var _contenido: Control
var _grafico: TableroGrafico
var _titulo: Label
var _instruccion: Label
var _estado_cabecera: Label
var _mensaje: Label
var _progreso_texto: Label
var _progreso: ProgressBar
var _boton_cerrar: Button
var _indicadores: Array[Label] = []


class TableroGrafico extends Control:
	var tipo: int = 0
	var estado: Dictionary = {}
	var seleccion: int = -1

	func _draw() -> void:
		for columna: int in range(23):
			var x := float(columna * 46)
			draw_line(Vector2(x, 0), Vector2(x, 322), Color(0.6, 0.8, 0.75, 0.035))
		for fila: int in range(8):
			var y := float(fila * 46)
			draw_line(Vector2(0, y), Vector2(1016, y), Color(0.6, 0.8, 0.75, 0.035))
		if estado.is_empty():
			return
		if tipo == 2:
			_dibujar_anillos()
		elif tipo == 3:
			_dibujar_cables()

	func _dibujar_anillos() -> void:
		for indice: int in range(3):
			var centro := Vector2(174 + indice * 334, 135)
			var objetivo: float = estado.objetivos[indice]
			var fase: float = estado.fases[indice]
			var fijo: bool = estado.fijados[indice]
			var color := PanelCircuitos.VERDE if fijo else PanelCircuitos.SECUNDARIO
			draw_circle(centro, 88, Color("142b2d"))
			draw_arc(centro, 87, 0, TAU, 80, Color("35514e"), 2, true)
			draw_arc(centro, 71, 0, TAU, 80, Color("304844"), 13, true)
			draw_arc(centro, 71, objetivo - 0.4, objetivo + 0.4, 24, PanelCircuitos.VERDE, 13, true)
			for marca: int in range(24):
				var direccion := Vector2.from_angle(float(marca) * TAU / 24.0)
				draw_line(centro + direccion * 81, centro + direccion * 86, Color("627c76"), 1, true)
			var aguja := Vector2.from_angle(fase)
			draw_line(centro + aguja * 37, centro + aguja * 77, color if fijo else Color.WHITE, 4, true)
			draw_circle(centro + aguja * 71, 6, color if fijo else Color.WHITE, true, -1, true)
			draw_circle(centro, 28, Color("0d1c1f"))
			draw_circle(centro, 6, color, true, -1, true)

	func _dibujar_cables() -> void:
		for origen: int in range(4):
			var inicio := Vector2(255, 48 + origen * 68)
			var color: Color = PanelCircuitos.COLORES_CABLE[origen]
			draw_circle(inicio, 9, color.darkened(0.5), true, -1, true)
			draw_circle(inicio, 4, color, true, -1, true)
			var destino: int = estado.conexiones[origen]
			if destino >= 0:
				var fin := Vector2(761, 48 + destino * 68)
				var curva := Curve2D.new()
				curva.add_point(inicio, Vector2.ZERO, Vector2(185, 0))
				curva.add_point(fin, Vector2(-185, 0), Vector2.ZERO)
				var puntos := curva.get_baked_points()
				draw_polyline(puntos, Color("081315"), 10, true)
				draw_polyline(puntos, color, 5, true)
			elif seleccion == origen:
				draw_line(inicio, inicio + Vector2(74, 0), color, 5, true)
				draw_circle(inicio + Vector2(74, 0), 7, Color.WHITE, false, 2, true)
		for fila: int in range(4):
			var color: Color = PanelCircuitos.COLORES_CABLE[estado.destinos[fila]]
			var fin := Vector2(761, 48 + fila * 68)
			draw_circle(fin, 9, color.darkened(0.5), true, -1, true)
			draw_circle(fin, 4, color, true, -1, true)


func _ready() -> void:
	_construir_interfaz()
	if not _abierto:
		hide()


func abrir(tipo: int, semilla: int) -> void:
	_construir_interfaz()
	_tipo = clampi(tipo, 0, 3)
	var clave := "%d/%d" % [_tipo, semilla]
	if _clave_estado != clave:
		_estado = _crear_estado(_tipo, semilla)
		_clave_estado = clave
	_seleccion_cable = int(_estado.get("seleccion", -1))
	_abierto = true
	_reconstruir_circuito()
	show()
	_ajustar_presentacion()
	_boton_cerrar.grab_focus.call_deferred()


func cerrar() -> void:
	if not _abierto:
		return
	_abierto = false
	hide()
	cerrado.emit()


func obtener_estado() -> Dictionary:
	return _estado.duplicate(true)


func _input(evento: InputEvent) -> void:
	if not _abierto or not is_visible_in_tree():
		return
	# E también figura como ui_accept/ui_right en el proyecto. La apertura no
	# debe accionar controles, y dentro del panel se confirma con Enter/Espacio.
	if evento is InputEventKey and (evento.physical_keycode == KEY_E or evento.keycode == KEY_E):
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("ui_cancel") or evento.is_action_pressed("Cancel"):
		get_viewport().set_input_as_handled()
		cerrar()


func _process(delta: float) -> void:
	if not _abierto or not is_visible_in_tree() or _tipo != 2 or _estado.resuelto:
		return
	for indice: int in range(3):
		if not _estado.fijados[indice]:
			_estado.fases[indice] = fposmod(float(_estado.fases[indice]) + float(_estado.velocidades[indice]) * delta, TAU)
	_grafico.queue_redraw()


func _crear_estado(tipo: int, semilla: int) -> Dictionary:
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	var estado := {"resuelto": false}
	match tipo:
		0:
			estado.interruptores = [false, azar.randf() > 0.5, false, azar.randf() > 0.5, false]
		1:
			estado.objetivos = []
			estado.valores = []
			for indice: int in range(4):
				var objetivo := azar.randi_range(2, 8) * 10
				estado.objetivos.append(objetivo)
				estado.valores.append((objetivo + azar.randi_range(2, 5) * 10) % 110)
		2:
			estado.objetivos = []
			estado.fases = []
			estado.velocidades = []
			estado.fijados = [false, false, false]
			for indice: int in range(3):
				estado.objetivos.append(azar.randf_range(0, TAU))
				estado.fases.append(azar.randf_range(0, TAU))
				estado.velocidades.append((0.8 + indice * 0.22) * (1.0 if indice % 2 == 0 else -1.0))
		3:
			estado.destinos = [0, 1, 2, 3]
			for indice: int in range(3, 0, -1):
				var otro := azar.randi_range(0, indice)
				var anterior: int = estado.destinos[indice]
				estado.destinos[indice] = estado.destinos[otro]
				estado.destinos[otro] = anterior
			if estado.destinos == [0, 1, 2, 3]:
				estado.destinos = [2, 0, 3, 1]
			estado.conexiones = [-1, -1, -1, -1]
			estado.seleccion = -1
	return estado


func _construir_interfaz() -> void:
	if _armado:
		return
	_armado = true
	name = "PanelCircuitos"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fondo := ColorRect.new()
	fondo.color = Color(0.015, 0.035, 0.04, 0.9)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fondo)
	_lienzo = Control.new()
	_lienzo.size = TAMANO_DISENO
	add_child(_lienzo)
	var carcasa := Panel.new()
	carcasa.size = TAMANO_DISENO
	carcasa.add_theme_stylebox_override("panel", _estilo(FONDO, Color("45655c"), 18, 2))
	_lienzo.add_child(carcasa)
	var franja := ColorRect.new()
	franja.position = Vector2(32, 0)
	franja.size = Vector2(96, 4)
	franja.color = VERDE
	_lienzo.add_child(franja)
	_etiqueta(_lienzo, "SUBESTACIÓN  /  RESTABLECIMIENTO MANUAL", Vector2(32, 24), Vector2(650, 26), 15, AMBAR)
	_estado_cabecera = _etiqueta(_lienzo, "SIN SUMINISTRO", Vector2(754, 24), Vector2(294, 26), 15, AMBAR)
	_estado_cabecera.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_titulo = _etiqueta(_lienzo, "", Vector2(32, 61), Vector2(1016, 45), 31, TEXTO)
	_instruccion = _etiqueta(_lienzo, "", Vector2(32, 115), Vector2(1016, 48), 18, SECUNDARIO)
	_instruccion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var placa := Panel.new()
	placa.position = Vector2(24, 176)
	placa.size = Vector2(1032, 330)
	placa.add_theme_stylebox_override("panel", _estilo(Color("0c191c"), Color("2b4440"), 9, 1))
	_lienzo.add_child(placa)
	_contenido = Control.new()
	_contenido.position = Vector2(32, 180)
	_contenido.size = Vector2(1016, 322)
	_lienzo.add_child(_contenido)
	_mensaje = _etiqueta(_lienzo, "", Vector2(32, 522), Vector2(1016, 26), 18, TEXTO)
	_progreso_texto = _etiqueta(_lienzo, "", Vector2(32, 560), Vector2(470, 24), 15, SECUNDARIO)
	_progreso = ProgressBar.new()
	_progreso.position = Vector2(32, 594)
	_progreso.size = Vector2(530, 6)
	_progreso.show_percentage = false
	_progreso.add_theme_font_size_override("font_size", 1)
	_progreso.add_theme_stylebox_override("background", _estilo(Color("29403b"), Color.TRANSPARENT, 3, 0))
	_progreso.add_theme_stylebox_override("fill", _estilo(VERDE, Color.TRANSPARENT, 3, 0))
	_lienzo.add_child(_progreso)
	_boton_cerrar = _boton(_lienzo, "VOLVER AL TABLERO  ·  ESC", Vector2(686, 556), Vector2(362, 46))
	_boton_cerrar.pressed.connect(cerrar)
	resized.connect(_ajustar_presentacion)
	_ajustar_presentacion()


func _reconstruir_circuito() -> void:
	for nodo: Node in _contenido.get_children():
		_contenido.remove_child(nodo)
		nodo.queue_free()
	interruptores.clear()
	reguladores.clear()
	botones_anillos.clear()
	origenes_cables.clear()
	destinos_cables.clear()
	_indicadores.clear()
	_titulo.text = TITULOS[_tipo]
	_instruccion.text = INSTRUCCIONES[_tipo]
	_grafico = TableroGrafico.new()
	_grafico.size = _contenido.size
	_grafico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grafico.tipo = _tipo
	_grafico.estado = _estado
	_grafico.seleccion = _seleccion_cable
	_contenido.add_child(_grafico)
	match _tipo:
		0: _crear_interruptores()
		1: _crear_reguladores()
		2: _crear_anillos()
		3: _crear_cables()
	_actualizar_presentacion()


func _crear_interruptores() -> void:
	for indice: int in range(5):
		var x := 14.0 + indice * 201
		var tarjeta := Panel.new()
		tarjeta.position = Vector2(x, 16)
		tarjeta.size = Vector2(184, 288)
		tarjeta.add_theme_stylebox_override("panel", _estilo(Color("152629"), Color("324c46"), 8, 1))
		_contenido.add_child(tarjeta)
		var linea := _etiqueta(tarjeta, "LÍNEA %02d" % (indice + 1), Vector2(0, 19), Vector2(184, 25), 16, SECUNDARIO)
		linea.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var interruptor := _boton(tarjeta, "", Vector2(48, 67), Vector2(88, 139))
		interruptor.name = "Interruptor%d" % (indice + 1)
		interruptor.toggle_mode = true
		interruptor.add_theme_font_size_override("font_size", 43)
		interruptor.toggled.connect(_cambiar_interruptor.bind(indice))
		interruptores.append(interruptor)
		var indicador := _etiqueta(tarjeta, "", Vector2(0, 232), Vector2(184, 25), 16, VERDE)
		indicador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_indicadores.append(indicador)


func _crear_reguladores() -> void:
	for indice: int in range(4):
		var y := 18.0 + indice * 75
		_etiqueta(_contenido, NOMBRES_LINEA[indice], Vector2(18, y + 4), Vector2(178, 26), 17, TEXTO)
		_etiqueta(_contenido, "OBJETIVO  %d" % int(_estado.objetivos[indice]), Vector2(18, y + 32), Vector2(178, 24), 15, AMBAR)
		var regulador := HSlider.new()
		regulador.name = "Regulador%d" % (indice + 1)
		regulador.position = Vector2(208, y + 9)
		regulador.size = Vector2(638, 40)
		regulador.min_value = 0
		regulador.max_value = 100
		regulador.step = 10
		regulador.tick_count = 11
		regulador.ticks_on_borders = true
		regulador.value = float(_estado.valores[indice])
		for estilo_nombre: String in ["slider", "grabber_area", "grabber_area_highlight"]:
			var color := Color("2f4944") if estilo_nombre == "slider" else VERDE.darkened(0.25)
			var carril := _estilo(color, Color.TRANSPARENT, 3, 0)
			carril.content_margin_top = 3
			carril.content_margin_bottom = 3
			regulador.add_theme_stylebox_override(estilo_nombre, carril)
		regulador.value_changed.connect(_cambiar_regulador.bind(indice))
		_contenido.add_child(regulador)
		reguladores.append(regulador)
		var valor := _etiqueta(_contenido, "", Vector2(874, y + 5), Vector2(120, 44), 28, TEXTO)
		valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_indicadores.append(valor)


func _crear_anillos() -> void:
	for indice: int in range(3):
		var x := 24.0 + indice * 334
		var titulo := _etiqueta(_contenido, "FASE %02d" % (indice + 1), Vector2(x, 6), Vector2(300, 24), 16, SECUNDARIO)
		titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var indicador := _etiqueta(_contenido, "", Vector2(x, 227), Vector2(300, 23), 15, SECUNDARIO)
		indicador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_indicadores.append(indicador)
		var fijar := _boton(_contenido, "FIJAR", Vector2(x + 48, 263), Vector2(204, 44))
		fijar.name = "FijarAnillo%d" % (indice + 1)
		fijar.pressed.connect(_fijar_anillo.bind(indice))
		botones_anillos.append(fijar)


func _crear_cables() -> void:
	_etiqueta(_contenido, "ORIGEN", Vector2(22, 1), Vector2(212, 22), 14, SECUNDARIO)
	var destino_titulo := _etiqueta(_contenido, "DESTINO", Vector2(782, 1), Vector2(212, 22), 14, SECUNDARIO)
	destino_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for indice: int in range(4):
		var y := 27.0 + indice * 68
		var origen := _boton(_contenido, "", Vector2(22, y), Vector2(212, 42), COLORES_CABLE[indice])
		origen.name = "OrigenCable%d" % (indice + 1)
		origen.pressed.connect(_seleccionar_cable.bind(indice))
		origenes_cables.append(origen)
		var identidad: int = _estado.destinos[indice]
		var destino := _boton(_contenido, "", Vector2(782, y), Vector2(212, 42), COLORES_CABLE[identidad])
		destino.name = "DestinoCable%d" % (indice + 1)
		destino.pressed.connect(_conectar_cable.bind(indice))
		destinos_cables.append(destino)
	var ayuda := _etiqueta(_contenido, "COLOR + NÚMERO  /  CUATRO PARES", Vector2(255, 291), Vector2(506, 22), 13, SECUNDARIO)
	ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _cambiar_interruptor(activado: bool, indice: int) -> void:
	if _estado.resuelto:
		return
	_estado.interruptores[indice] = activado
	_actualizar_presentacion()
	_comprobar_solucion()


func _cambiar_regulador(valor: float, indice: int) -> void:
	if _estado.resuelto:
		return
	_estado.valores[indice] = roundi(valor)
	_actualizar_presentacion()
	_comprobar_solucion()


func _fijar_anillo(indice: int) -> void:
	if _estado.resuelto or _estado.fijados[indice]:
		return
	var distancia := absf(angle_difference(float(_estado.fases[indice]), float(_estado.objetivos[indice])))
	if distancia > 0.4:
		_mensaje.text = "Fuera del arco verde. Espera el próximo paso del indicador y vuelve a fijar."
		_mensaje.add_theme_color_override("font_color", AMBAR)
		return
	_estado.fijados[indice] = true
	_actualizar_presentacion()
	_comprobar_solucion()


func _seleccionar_cable(indice: int) -> void:
	if _estado.resuelto or int(_estado.conexiones[indice]) >= 0:
		return
	_seleccion_cable = indice
	_estado.seleccion = indice
	_actualizar_presentacion()


func _conectar_cable(fila: int) -> void:
	if _estado.resuelto or _estado.conexiones.has(fila):
		return
	if _seleccion_cable < 0:
		_mensaje.text = "Primero selecciona un cable de la columna ORIGEN."
		_mensaje.add_theme_color_override("font_color", AMBAR)
		return
	if int(_estado.destinos[fila]) != _seleccion_cable:
		_mensaje.text = "Ese destino no coincide. Busca el mismo número y color del origen seleccionado."
		_mensaje.add_theme_color_override("font_color", AMBAR)
		return
	_estado.conexiones[_seleccion_cable] = fila
	_seleccion_cable = -1
	_estado.seleccion = -1
	_actualizar_presentacion()
	_comprobar_solucion()


func _cantidad_completada() -> int:
	var cantidad := 0
	match _tipo:
		0:
			for activo: bool in _estado.interruptores:
				cantidad += int(activo)
		1:
			for indice: int in range(4):
				cantidad += int(int(_estado.valores[indice]) == int(_estado.objetivos[indice]))
		2:
			for fijo: bool in _estado.fijados:
				cantidad += int(fijo)
		3:
			for destino: int in _estado.conexiones:
				cantidad += int(destino >= 0)
	return cantidad


func _comprobar_solucion() -> void:
	if _estado.resuelto:
		return
	var total: int = [5, 4, 3, 4][_tipo]
	if _cantidad_completada() != total:
		return
	_estado.resuelto = true
	_actualizar_presentacion()
	circuito_resuelto.emit()


func _actualizar_presentacion() -> void:
	var resuelto: bool = _estado.resuelto
	var completados := _cantidad_completada()
	var total: int = [5, 4, 3, 4][_tipo]
	_estado_cabecera.text = "CIRCUITO ESTABLE" if resuelto else "SIN SUMINISTRO  /  %02d" % (_tipo + 1)
	_estado_cabecera.add_theme_color_override("font_color", VERDE if resuelto else AMBAR)
	_progreso_texto.text = "%02d / %02d  ·  %s" % [completados, total, "RESTABLECIDO" if resuelto else "CONEXIONES ESTABLES"]
	_progreso.value = float(completados) / total * 100.0
	_mensaje.add_theme_color_override("font_color", VERDE if resuelto else TEXTO)
	_mensaje.text = "Circuito restablecido. El suministro vuelve a estar disponible." if resuelto else "Completa las conexiones para devolver la luz. Tu progreso se conserva al salir."
	match _tipo:
		0:
			for indice: int in range(5):
				var activo: bool = _estado.interruptores[indice]
				interruptores[indice].set_pressed_no_signal(activo)
				interruptores[indice].disabled = resuelto
				interruptores[indice].text = "I" if activo else "O"
				interruptores[indice].add_theme_color_override("font_color", VERDE if activo else AMBAR)
				_indicadores[indice].text = "ACTIVO" if activo else "SIN CORRIENTE"
				_indicadores[indice].add_theme_color_override("font_color", VERDE if activo else AMBAR)
		1:
			for indice: int in range(4):
				var correcto: bool = int(_estado.valores[indice]) == int(_estado.objetivos[indice])
				reguladores[indice].editable = not resuelto
				_indicadores[indice].text = "%d%s" % [int(_estado.valores[indice]), "  ✓" if correcto else ""]
				_indicadores[indice].add_theme_color_override("font_color", VERDE if correcto else TEXTO)
		2:
			for indice: int in range(3):
				var fijo: bool = _estado.fijados[indice]
				botones_anillos[indice].disabled = fijo or resuelto
				botones_anillos[indice].text = "SINCRONIZADO" if fijo else "FIJAR"
				_indicadores[indice].text = "FASE ESTABLE" if fijo else "ESPERA EL ARCO VERDE"
				_indicadores[indice].add_theme_color_override("font_color", VERDE if fijo else SECUNDARIO)
		3:
			for indice: int in range(4):
				var conectado: bool = int(_estado.conexiones[indice]) >= 0
				origenes_cables[indice].disabled = conectado or resuelto
				origenes_cables[indice].text = "%s%02d  ·  %s" % ["> " if _seleccion_cable == indice else "", indice + 1, NOMBRES_CABLE[indice]]
				var identidad: int = _estado.destinos[indice]
				destinos_cables[indice].text = "%02d  ·  %s" % [identidad + 1, NOMBRES_CABLE[identidad]]
				destinos_cables[indice].disabled = _estado.conexiones.has(indice) or resuelto
			if _seleccion_cable >= 0 and not resuelto:
				_mensaje.text = "Origen %02d seleccionado. Conéctalo al destino %02d · %s." % [_seleccion_cable + 1, _seleccion_cable + 1, NOMBRES_CABLE[_seleccion_cable]]
	_grafico.seleccion = _seleccion_cable
	_grafico.queue_redraw()


func _ajustar_presentacion() -> void:
	if not is_instance_valid(_lienzo):
		return
	var espacio := size - Vector2(40, 32)
	var escala := maxf(0.1, minf(espacio.x / TAMANO_DISENO.x, espacio.y / TAMANO_DISENO.y))
	escala = minf(escala, 1.6)
	_lienzo.scale = Vector2.ONE * escala
	_lienzo.position = (size - TAMANO_DISENO * escala) * 0.5


func _etiqueta(padre: Node, texto: String, posicion: Vector2, tamano: Vector2, fuente: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.position = posicion
	etiqueta.size = tamano
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_size_override("font_size", fuente)
	etiqueta.add_theme_color_override("font_color", color)
	padre.add_child(etiqueta)
	return etiqueta


func _boton(padre: Node, texto: String, posicion: Vector2, tamano: Vector2, acento: Color = VERDE) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.position = posicion
	boton.size = tamano
	boton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	boton.add_theme_font_size_override("font_size", 17)
	boton.add_theme_color_override("font_color", acento)
	boton.add_theme_color_override("font_hover_color", Color.WHITE)
	boton.add_theme_color_override("font_pressed_color", Color.WHITE)
	boton.add_theme_color_override("font_disabled_color", acento.darkened(0.05))
	boton.add_theme_stylebox_override("normal", _estilo(Color("1b302e"), acento.darkened(0.6), 7, 1))
	boton.add_theme_stylebox_override("hover", _estilo(Color("29483d"), acento, 7, 2))
	boton.add_theme_stylebox_override("pressed", _estilo(Color("305943"), acento, 7, 2))
	boton.add_theme_stylebox_override("disabled", _estilo(Color("1d3e32"), acento.darkened(0.25), 7, 1))
	boton.add_theme_stylebox_override("focus", _estilo(Color.TRANSPARENT, AMBAR, 7, 2))
	padre.add_child(boton)
	return boton


func _estilo(color: Color, borde: Color, radio: int, ancho: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.border_color = borde
	estilo.set_corner_radius_all(radio)
	estilo.set_border_width_all(ancho)
	return estilo
