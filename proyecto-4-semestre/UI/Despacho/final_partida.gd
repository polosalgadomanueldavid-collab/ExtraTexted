class_name FinalPartida
extends Control

signal relevo_iniciado
signal reiniciar_solicitado
signal menu_solicitado

const FUENTE_TITULOS := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const FUENTE_TEXTO := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
const ARTE_CUADERNO := preload("res://UI/Despacho/cuaderno_arte.gd")
const SONIDO_ALERTA := preload("res://Audios/Apagon/rechazo.wav")
const SONIDO_RELEVO := preload("res://Audios/VozPersonaje/Gomosa/saludo.wav")
const SONIDO_PAGINA := preload("res://Audios/Mesas/pasar_hoja_1.ogg")
const TAMANO_LIBRO := Vector2(1280, 720)
const PETROLEO := Color("173b50")
const CREMA := Color("fff1d8")
const CORAL := Color("ff785f")
const TINTA := Color("294459")
const COLORES_PESTANAS := [Color("e98944"), Color("e7b342"), Color("69ad91")]
const NOMBRES_ESTACIONES := {
	"privacidad": "Seguridad",
	"evidencias": "Evidencias",
	"verificacion": "Verificación",
	"reporte": "Reporte",
	"bienestar": "Bienestar"
}

var _datos: Dictionary = {}
var _fase: int = 0
var _pagina_actual: int = 0
var _pasando_pagina: bool = false
var _escala_libro: float = 1.0
var _fondo: ColorRect
var _tarjeta: PanelContainer
var _rotulo: Label
var _titulo_caso: Label
var _detalle: Label
var _dialogo: Label
var _saltar: Button
var _cuaderno: Control
var _paginas: Array[Dictionary] = []
var _pestanas: Array[Button] = []
var _anterior: Button
var _siguiente: Button
var _numero_izq: Label
var _numero_der: Label
var _estadisticas: Label
var _alerta: AudioStreamPlayer
var _voz: AudioStreamPlayer
var _sonido_pagina: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_construir_interfaz()
	resized.connect(_ajustar)
	_ajustar()
	hide()


func presentar(datos: Dictionary) -> void:
	if _fase != 0:
		return
	_datos = datos
	_fase = 1
	show()
	_tarjeta.show()
	_cuaderno.hide()
	_rotulo.text = "DENUNCIA VENCIDA · CALMA 0"
	var causa: Dictionary = _datos.get("causa", {})
	if causa.get("terremoto", false):
		_rotulo.text = "DENUNCIA PERDIDA EN EL TERREMOTO · CALMA 0"
	_titulo_caso.text = str(causa.get("titulo", "Denuncia sin resolver"))
	_detalle.text = "Quedó pendiente: %s" % _estaciones(causa.get("pendientes", []))
	_dialogo.text = ""
	_saltar.grab_focus()
	_alerta.play()
	_secuencia()


func _secuencia() -> void:
	await get_tree().create_timer(2.4, true, false, true).timeout
	if not is_inside_tree() or _fase != 1:
		return
	_rotulo.text = "RELEVO DE EMERGENCIA"
	_titulo_caso.text = "El equipo toma el relevo"
	_detalle.text = "Tu turno termina aquí."
	_dialogo.text = "COMPAÑERO · «Déjalo. Yo me encargo desde aquí»"
	_voz.play()
	relevo_iniciado.emit()
	await get_tree().create_timer(3.2, true, false, true).timeout
	if is_inside_tree() and _fase == 1:
		_abrir_cuaderno()


func _construir_interfaz() -> void:
	_fondo = ColorRect.new()
	_fondo.color = Color(0.02, 0.08, 0.12, 0.48)
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fondo)

	_tarjeta = PanelContainer.new()
	_tarjeta.add_theme_stylebox_override("panel", _estilo(PETROLEO, CORAL, 22))
	add_child(_tarjeta)
	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 10)
	_tarjeta.add_child(contenido)
	_rotulo = _etiqueta("", 24, CORAL, FUENTE_TITULOS)
	contenido.add_child(_rotulo)
	_titulo_caso = _etiqueta("", 36, CREMA, FUENTE_TITULOS)
	contenido.add_child(_titulo_caso)
	_detalle = _etiqueta("", 22, CREMA, FUENTE_TEXTO)
	contenido.add_child(_detalle)
	_dialogo = _etiqueta("", 21, Color("ffd279"), FUENTE_TEXTO)
	contenido.add_child(_dialogo)
	_saltar = Button.new()
	_saltar.text = "Ir al cuaderno  ›"
	_saltar.pressed.connect(_abrir_cuaderno)
	contenido.add_child(_saltar)

	_cuaderno = Control.new()
	_cuaderno.size = TAMANO_LIBRO
	_cuaderno.pivot_offset = TAMANO_LIBRO * 0.5
	add_child(_cuaderno)
	var arte := ARTE_CUADERNO.new() as Control
	arte.size = TAMANO_LIBRO
	_cuaderno.add_child(arte)
	_paginas.append(_crear_pagina(105.0))
	_paginas.append(_crear_pagina(694.0))
	_numero_izq = _etiqueta("", 18, CREMA, FUENTE_TITULOS)
	_numero_izq.position = Vector2(77, 607)
	_numero_izq.size = Vector2(32, 30)
	_numero_izq.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_numero_izq.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cuaderno.add_child(_numero_izq)
	_numero_der = _etiqueta("", 18, CREMA, FUENTE_TITULOS)
	_numero_der.position = Vector2(1167, 607)
	_numero_der.size = Vector2(32, 30)
	_numero_der.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_numero_der.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cuaderno.add_child(_numero_der)
	for indice: int in range(3):
		var pestana := _boton(str(indice + 1), COLORES_PESTANAS[indice], 25)
		pestana.tooltip_text = ["Balance", "Casos", "Estadísticas"][indice]
		pestana.position = Vector2(1213, 139 + indice * 72)
		pestana.size = Vector2(54, 48)
		pestana.pressed.connect(_ir_a_pagina.bind(indice))
		_cuaderno.add_child(pestana)
		_pestanas.append(pestana)
	_anterior = _boton("‹  Anterior", PETROLEO, 17)
	_anterior.position = Vector2(422, 609)
	_anterior.size = Vector2(145, 43)
	_anterior.pressed.connect(_ir_a_pagina.bind(-1))
	_cuaderno.add_child(_anterior)
	_siguiente = _boton("Siguiente  ›", PETROLEO, 17)
	_siguiente.position = Vector2(697, 609)
	_siguiente.size = Vector2(145, 43)
	_siguiente.pressed.connect(_ir_a_pagina.bind(-2))
	_cuaderno.add_child(_siguiente)
	var reiniciar := _boton("Reintentar", Color("5f9d88"), 17)
	reiniciar.position = Vector2(868, 609)
	reiniciar.size = Vector2(139, 43)
	reiniciar.pressed.connect(func() -> void: reiniciar_solicitado.emit())
	_cuaderno.add_child(reiniciar)
	var menu := _boton("Menú", Color("60788a"), 17)
	menu.position = Vector2(1024, 609)
	menu.size = Vector2(110, 43)
	menu.pressed.connect(func() -> void: menu_solicitado.emit())
	_cuaderno.add_child(menu)
	_cuaderno.hide()

	_alerta = _crear_sonido(SONIDO_ALERTA, -7.0)
	_voz = _crear_sonido(SONIDO_RELEVO, -4.0)
	_sonido_pagina = _crear_sonido(SONIDO_PAGINA, -5.0)


func _crear_pagina(x: float) -> Dictionary:
	var columna := VBoxContainer.new()
	columna.position = Vector2(x, 86)
	columna.size = Vector2(489, 508)
	columna.add_theme_constant_override("separation", 7)
	_cuaderno.add_child(columna)
	columna.add_child(_etiqueta("EXTRATEXTED  ·  CUADERNO DE TURNO", 13, Color("637988"), FUENTE_TEXTO))
	var titulo := _etiqueta("", 31, TINTA, FUENTE_TITULOS)
	columna.add_child(titulo)
	var subtitulo := _etiqueta("", 17, TINTA, FUENTE_TEXTO)
	columna.add_child(subtitulo)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columna.add_child(scroll)
	var cuerpo := VBoxContainer.new()
	cuerpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 13)
	scroll.add_child(cuerpo)
	return {"columna": columna, "titulo": titulo, "subtitulo": subtitulo, "scroll": scroll, "cuerpo": cuerpo}


func _ajustar() -> void:
	if not is_instance_valid(_tarjeta):
		return
	_tarjeta.size = Vector2(minf(720.0, size.x - 40.0), 260.0)
	_tarjeta.position = Vector2(20.0, maxf(20.0, size.y - _tarjeta.size.y - 25.0))
	_escala_libro = minf(size.x / 1350.0, size.y / 765.0)
	_cuaderno.position = (size - TAMANO_LIBRO * _escala_libro) * 0.5
	_cuaderno.scale = Vector2.ONE * _escala_libro


func _abrir_cuaderno() -> void:
	if _fase != 1:
		return
	_fase = 2
	_tarjeta.hide()
	_fondo.color = Color(0.02, 0.08, 0.12, 0.78)
	_pagina_actual = 0
	_poblar_paginas()
	_sonido_pagina.play()
	_cuaderno.show()
	_cuaderno.scale = Vector2(_escala_libro * 0.94, _escala_libro * 0.08)
	_cuaderno.modulate = Color(1, 1, 1, 0.55)
	var apertura := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	apertura.set_parallel(true)
	apertura.tween_property(_cuaderno, "scale", Vector2.ONE * _escala_libro, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	apertura.tween_property(_cuaderno, "modulate", Color.WHITE, 0.34)
	apertura.finished.connect(func() -> void: _siguiente.grab_focus())


func _poblar_paginas() -> void:
	for pagina: Dictionary in _paginas:
		(pagina["scroll"] as ScrollContainer).scroll_vertical = 0
		var cuerpo := pagina["cuerpo"] as VBoxContainer
		for hijo: Node in cuerpo.get_children():
			cuerpo.remove_child(hijo)
			hijo.queue_free()
	match _pagina_actual:
		0: _llenar_balance()
		1: _llenar_casos()
		2: _llenar_estadisticas()
	_numero_izq.text = "%02d" % (_pagina_actual * 2 + 1)
	_numero_der.text = "%02d" % (_pagina_actual * 2 + 2)
	_anterior.disabled = _pagina_actual == 0
	_siguiente.disabled = _pagina_actual == 2
	for indice: int in range(_pestanas.size()):
		_pestanas[indice].position.x = 1205.0 if indice == _pagina_actual else 1216.0
		_pestanas[indice].modulate = Color.WHITE if indice == _pagina_actual else Color(0.82, 0.85, 0.88)


func _llenar_balance() -> void:
	_encabezado(0, "Fin de turno", "Lo que alcanzaste a hacer")
	_encabezado(1, "El caso final", "La denuncia que agotó la calma")
	var izq := _cuerpo(0)
	var resueltas := _casos("resueltas")
	var vencidas := _casos("vencidas")
	var pendientes := _casos("pendientes")
	var segundos := int(_datos.get("duracion", 0.0))
	_estadisticas = _etiqueta("Cerraste %d de %d denuncias recibidas." % [resueltas.size(), resueltas.size() + vencidas.size() + pendientes.size()], 19, TINTA, FUENTE_TEXTO)
	izq.add_child(_estadisticas)
	var tarjetas := GridContainer.new()
	tarjetas.columns = 2
	tarjetas.add_theme_constant_override("h_separation", 10)
	tarjetas.add_theme_constant_override("v_separation", 10)
	izq.add_child(tarjetas)
	_agregar_metrica(tarjetas, str(resueltas.size()), "RESUELTAS", Color("5b9d82"))
	_agregar_metrica(tarjetas, str(vencidas.size()), "PERDIDAS", CORAL)
	_agregar_metrica(tarjetas, str(pendientes.size()), "SIN CERRAR", Color("e4ae44"))
	_agregar_metrica(tarjetas, "%02d:%02d" % [segundos / 60, segundos % 60], "EN TURNO", PETROLEO)
	izq.add_child(_etiqueta("PUNTOS GANADOS  %d\nSALDO FINAL  %d" % [int(_datos.get("puntos_ganados", 0)), int(_datos.get("saldo", 0))], 19, TINTA, FUENTE_TEXTO))
	izq.add_child(_etiqueta("El equipo continúa con las denuncias que quedaron abiertas.", 18, TINTA, FUENTE_TEXTO))
	var causa: Dictionary = _datos.get("causa", {})
	var der := _cuerpo(1)
	der.add_child(_etiqueta(str(causa.get("titulo", "Denuncia sin resolver")), 27, PETROLEO, FUENTE_TITULOS))
	der.add_child(_etiqueta("CALMA OPERATIVA  0 / 100", 17, CORAL, FUENTE_TITULOS))
	var hechas: Array = causa.get("completadas", [])
	var faltantes: Array = causa.get("pendientes", [])
	_agregar_barra(der, "Protocolo", hechas.size(), maxi(1, hechas.size() + faltantes.size()), Color("5b9d82"))
	der.add_child(_etiqueta("HECHO", 19, Color("2c7c68"), FUENTE_TITULOS))
	der.add_child(_etiqueta(_estaciones(hechas), 19, TINTA, FUENTE_TEXTO))
	der.add_child(_etiqueta("FALTÓ", 19, CORAL, FUENTE_TITULOS))
	der.add_child(_etiqueta(_estaciones(faltantes), 19, TINTA, FUENTE_TEXTO))
	der.add_child(_etiqueta("«Déjalo. Yo me encargo desde aquí»", 18, TINTA, FUENTE_TEXTO))


func _llenar_casos() -> void:
	_encabezado(0, "Lo que hiciste", "Denuncias resueltas")
	_encabezado(1, "Lo que se perdió", "Denuncias vencidas o perdidas en el terremoto")
	_agregar_casos(_cuerpo(0), _casos("resueltas"), Color("5b9d82"), "No se alcanzó a resolver ninguna denuncia.")
	_agregar_casos(_cuerpo(1), _casos("vencidas"), CORAL, "Ninguna denuncia perdida.")


func _llenar_estadisticas() -> void:
	_encabezado(0, "Quedó pendiente", "Casos entregados al equipo")
	_encabezado(1, "Estadísticas", "Así se repartió el trabajo")
	_agregar_casos(_cuerpo(0), _casos("pendientes"), Color("e4ae44"), "No quedaron denuncias abiertas.")
	var der := _cuerpo(1)
	der.add_child(_etiqueta("DENUNCIAS", 20, PETROLEO, FUENTE_TITULOS))
	var resultados := [
		{"nombre": "Resueltas", "valor": _casos("resueltas").size(), "color": Color("5b9d82")},
		{"nombre": "Perdidas", "valor": _casos("vencidas").size(), "color": CORAL},
		{"nombre": "Abiertas", "valor": _casos("pendientes").size(), "color": Color("e4ae44")}
	]
	var maximo := maxi(1, maxi(_casos("resueltas").size(), maxi(_casos("vencidas").size(), _casos("pendientes").size())))
	for resultado: Dictionary in resultados:
		_agregar_barra(der, resultado.nombre, resultado.valor, maximo, resultado.color)
	der.add_child(_etiqueta("ESTACIONES COMPLETADAS", 20, PETROLEO, FUENTE_TITULOS))
	var conteos := {}
	for id: String in NOMBRES_ESTACIONES:
		conteos[id] = 0
	for grupo: String in ["resueltas", "vencidas", "pendientes"]:
		for caso: Dictionary in _casos(grupo):
			for id: String in caso.get("completadas", []):
				conteos[id] = int(conteos.get(id, 0)) + 1
	var maximo_estaciones := 1
	for cantidad: Variant in conteos.values():
		maximo_estaciones = maxi(maximo_estaciones, int(cantidad))
	for id: String in NOMBRES_ESTACIONES:
		_agregar_barra(der, NOMBRES_ESTACIONES[id], int(conteos[id]), maximo_estaciones, Color("5e9cbd"))
	der.add_child(_etiqueta("Puntos ganados: %d  ·  Saldo: %d" % [int(_datos.get("puntos_ganados", 0)), int(_datos.get("saldo", 0))], 18, TINTA, FUENTE_TEXTO))


func _encabezado(indice: int, titulo: String, subtitulo: String) -> void:
	(_paginas[indice]["titulo"] as Label).text = titulo
	(_paginas[indice]["subtitulo"] as Label).text = subtitulo


func _cuerpo(indice: int) -> VBoxContainer:
	return _paginas[indice]["cuerpo"] as VBoxContainer


func _casos(nombre: String) -> Array:
	var casos: Variant = _datos.get(nombre, [])
	return casos if casos is Array else []


func _agregar_casos(padre: VBoxContainer, casos: Array, color: Color, vacio: String) -> void:
	if casos.is_empty():
		padre.add_child(_etiqueta(vacio, 19, TINTA, FUENTE_TEXTO))
		return
	for valor: Variant in casos:
		var caso: Dictionary = valor
		var tarjeta := PanelContainer.new()
		tarjeta.add_theme_stylebox_override("panel", _estilo(Color(1, 1, 1, 0.62), color, 12))
		padre.add_child(tarjeta)
		var texto := VBoxContainer.new()
		texto.add_theme_constant_override("separation", 3)
		tarjeta.add_child(texto)
		texto.add_child(_etiqueta(str(caso.get("titulo", "Denuncia")), 21, PETROLEO, FUENTE_TITULOS))
		if caso.get("terremoto", false):
			texto.add_child(_etiqueta("La hoja cayó en una grieta.", 17, CORAL, FUENTE_TEXTO))
		var hechas: Array = caso.get("completadas", [])
		var faltantes: Array = caso.get("pendientes", [])
		if not hechas.is_empty():
			texto.add_child(_etiqueta("Hecho: %s" % _estaciones(hechas), 17, TINTA, FUENTE_TEXTO))
		if not faltantes.is_empty():
			texto.add_child(_etiqueta("Faltó: %s" % _estaciones(faltantes), 17, TINTA, FUENTE_TEXTO))


func _agregar_metrica(padre: GridContainer, valor: String, nombre: String, color: Color) -> void:
	var tarjeta := PanelContainer.new()
	tarjeta.custom_minimum_size = Vector2(215, 90)
	tarjeta.add_theme_stylebox_override("panel", _estilo(Color(1, 1, 1, 0.72), color, 10))
	padre.add_child(tarjeta)
	var columna := VBoxContainer.new()
	tarjeta.add_child(columna)
	columna.add_child(_etiqueta(valor, 28, color, FUENTE_TITULOS))
	columna.add_child(_etiqueta(nombre, 17, TINTA, FUENTE_TEXTO))


func _agregar_barra(padre: VBoxContainer, nombre: String, valor: int, maximo: int, color: Color) -> void:
	var fila := HBoxContainer.new()
	fila.custom_minimum_size.y = 29
	fila.add_theme_constant_override("separation", 8)
	padre.add_child(fila)
	var etiqueta := _etiqueta(nombre, 16, TINTA, FUENTE_TEXTO)
	etiqueta.custom_minimum_size.x = 119
	fila.add_child(etiqueta)
	var pista := Control.new()
	pista.custom_minimum_size = Vector2(220, 17)
	fila.add_child(pista)
	var fondo := ColorRect.new()
	fondo.color = Color(0.31, 0.40, 0.45, 0.16)
	fondo.size = Vector2(220, 17)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pista.add_child(fondo)
	var relleno := ColorRect.new()
	relleno.color = color
	relleno.size = Vector2(220.0 * float(valor) / float(maxi(1, maximo)), 17)
	relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pista.add_child(relleno)
	fila.add_child(_etiqueta(str(valor), 16, TINTA, FUENTE_TITULOS))


func _ir_a_pagina(destino: int) -> void:
	if _fase != 2 or _pasando_pagina:
		return
	if destino == -1:
		destino = _pagina_actual - 1
	elif destino == -2:
		destino = _pagina_actual + 1
	if destino < 0 or destino > 2 or destino == _pagina_actual:
		return
	_pasando_pagina = true
	_sonido_pagina.play()
	var salida := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	salida.set_parallel(true)
	for pagina: Dictionary in _paginas:
		salida.tween_property(pagina["columna"], "modulate:a", 0.0, 0.12)
	await salida.finished
	if not is_inside_tree():
		return
	_pagina_actual = destino
	_poblar_paginas()
	var entrada := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	entrada.set_parallel(true)
	for pagina: Dictionary in _paginas:
		entrada.tween_property(pagina["columna"], "modulate:a", 1.0, 0.18)
	await entrada.finished
	_pasando_pagina = false
	if destino == 2:
		_anterior.grab_focus()
	else:
		_siguiente.grab_focus()


func _input(evento: InputEvent) -> void:
	if _fase != 2 or not evento is InputEventKey or not evento.pressed or evento.echo:
		return
	if evento.keycode in [KEY_RIGHT, KEY_PAGEDOWN]:
		_ir_a_pagina(-2)
		get_viewport().set_input_as_handled()
	elif evento.keycode in [KEY_LEFT, KEY_PAGEUP]:
		_ir_a_pagina(-1)
		get_viewport().set_input_as_handled()


func _estaciones(ids: Array) -> String:
	if ids.is_empty():
		return "ninguna estación"
	var nombres := PackedStringArray()
	for id: Variant in ids:
		nombres.append(str(NOMBRES_ESTACIONES.get(str(id), str(id).capitalize())))
	return ", ".join(nombres)


func _etiqueta(texto: String, tamano: int, color: Color, fuente: Font) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.add_theme_font_override("font", fuente)
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	return etiqueta


func _boton(texto: String, color: Color, tamano: int) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.add_theme_font_override("font", FUENTE_TITULOS)
	boton.add_theme_font_size_override("font_size", tamano)
	boton.add_theme_color_override("font_color", Color.WHITE)
	boton.add_theme_color_override("font_hover_color", Color.WHITE)
	boton.add_theme_stylebox_override("normal", _estilo(color, color.darkened(0.18), 3))
	boton.add_theme_stylebox_override("hover", _estilo(color.lightened(0.16), color, 3))
	boton.add_theme_stylebox_override("pressed", _estilo(color.darkened(0.15), color, 3))
	return boton


func _estilo(fondo: Color, borde: Color, margen: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(10)
	estilo.content_margin_left = margen
	estilo.content_margin_right = margen
	estilo.content_margin_top = margen
	estilo.content_margin_bottom = margen
	return estilo


func _crear_sonido(clip: AudioStream, volumen: float) -> AudioStreamPlayer:
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = clip
	reproductor.bus = "Interacciones"
	reproductor.volume_db = volumen
	reproductor.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(reproductor)
	return reproductor
