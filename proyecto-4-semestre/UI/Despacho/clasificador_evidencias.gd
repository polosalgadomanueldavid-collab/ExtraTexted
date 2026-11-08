extends Control
## Planillero de cartón con pinza, referencia a la izquierda y tres hojas seleccionables.

signal terminado(caso_id: String)
signal cerrado

const FUENTE := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const TINTA := Color("173b50")
const CREMA := Color("fff1d8")
const CORAL := Color("ff785f")
const CARTON := Color("c79e6d")
const CARTON_OSCURO := Color("a97a4d")
const METAL := Color("8e9d97")
const DURACION_ENTRADA: float = 0.48
const COLORES := [Color("ff785f"), Color("54bfe4"), Color("79d693")]
const TIPOS := ["IDENTIDAD", "MENSAJES", "ENLACES"]

var caso_id: String = ""
var objetivos: Array[int] = []
var papeles: Array[int] = []
var archivados: int = 0
var seleccion: int = 1
var error_restante: float = 0.0
var entrada_restante: float = 0.0


func _ready() -> void:
	name = "ClasificadorEvidencias"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


func iniciar(id: String) -> void:
	if caso_id != id or objetivos.is_empty():
		caso_id = id
		objetivos = [0, 1, 2]
		objetivos.shuffle()
		papeles = [0, 1, 2]
		papeles.shuffle()
		archivados = 0
	seleccion = mini(1, papeles.size() - 1)
	error_restante = 0.0
	entrada_restante = DURACION_ENTRADA
	show()
	queue_redraw()


func cancelar() -> void:
	hide()
	caso_id = ""
	objetivos.clear()
	papeles.clear()
	archivados = 0
	entrada_restante = 0.0
	cerrado.emit()


func _process(delta: float) -> void:
	if not visible:
		return
	if entrada_restante > 0.0:
		entrada_restante = maxf(0.0, entrada_restante - delta)
		queue_redraw()
	if error_restante > 0.0:
		error_restante = maxf(0.0, error_restante - delta)
		queue_redraw()


func _input(evento: InputEvent) -> void:
	if not visible or not evento is InputEventKey or not evento.pressed or evento.echo:
		return
	var tecla: int = evento.physical_keycode if evento.physical_keycode != 0 else evento.keycode
	if entrada_restante > 0.0 and tecla != KEY_ESCAPE:
		if tecla in [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT, KEY_E]:
			get_viewport().set_input_as_handled()
		return
	if tecla == KEY_A or tecla == KEY_LEFT:
		seleccion = posmod(seleccion - 1, papeles.size())
	elif tecla == KEY_D or tecla == KEY_RIGHT:
		seleccion = posmod(seleccion + 1, papeles.size())
	elif tecla == KEY_E:
		_archivar()
	elif tecla == KEY_ESCAPE:
		hide()
		entrada_restante = 0.0
		cerrado.emit()
	else:
		return
	get_viewport().set_input_as_handled()
	queue_redraw()


func _archivar() -> void:
	if papeles.is_empty() or archivados >= objetivos.size():
		return
	if papeles[seleccion] != objetivos[archivados]:
		error_restante = 0.55
		return
	papeles.remove_at(seleccion)
	archivados += 1
	error_restante = 0.0
	if archivados == objetivos.size():
		var id_terminado := caso_id
		hide()
		caso_id = ""
		objetivos.clear()
		papeles.clear()
		cerrado.emit()
		terminado.emit(id_terminado)
	else:
		seleccion = mini(seleccion, papeles.size() - 1)


func _draw() -> void:
	var factor := minf(size.x / 1280.0, size.y / 720.0)
	var centro := size * 0.5
	var t := clampf(1.0 - entrada_restante / DURACION_ENTRADA, 0.0, 1.0)
	var avance := t * t * (3.0 - 2.0 * t)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.10, 0.14, 0.73 * minf(1.0, t * 3.0)))
	var planillero := Rect2(centro - Vector2(370, 260) * factor, Vector2(740, 520) * factor)
	planillero.position.y += (1.0 - avance) * (size.y - planillero.position.y + 40.0 * factor)
	_dibujar_planillero(planillero, factor)
	_texto("REVISA LA REFERENCIA DE LA IZQUIERDA.", planillero.position + Vector2(38, 83) * factor, 20, TINTA, factor)
	_texto("ELIGE LA HOJA QUE COINCIDA CON EL ARCHIVO.", planillero.position + Vector2(38, 110) * factor, 19, TINTA, factor)
	for i: int in range(3):
		draw_circle(planillero.position + Vector2(626 + i * 26, 39) * factor, 7.0 * factor, CORAL if i < archivados else CARTON_OSCURO)
	var tipo_objetivo: int = objetivos[archivados] if archivados < objetivos.size() else 0
	_dibujar_referencia(planillero, factor, tipo_objetivo)
	for i: int in range(papeles.size()):
		if i != seleccion:
			_dibujar_papel(i, planillero, factor, false)
	if not papeles.is_empty():
		_dibujar_papel(seleccion, planillero, factor, true)
	_dibujar_ayuda(planillero, factor)
	if error_restante > 0.0:
		_texto("ESE NO ES EL ARCHIVO", planillero.position + Vector2(335, 430) * factor, 16, Color("a74337"), factor)


func _dibujar_ayuda(tabla: Rect2, factor: float) -> void:
	var origen := tabla.position + Vector2(72, 444) * factor
	_dibujar_tecla(origen, 34.0, "A", factor)
	_texto("/", origen + Vector2(42, 25) * factor, 17, TINTA, factor)
	_dibujar_tecla(origen + Vector2(56, 0) * factor, 34.0, "D", factor)
	_texto("ELEGIR HOJA", origen + Vector2(101, 25) * factor, 16, TINTA, factor)
	origen = tabla.position + Vector2(325, 444) * factor
	_dibujar_tecla(origen, 34.0, "E", factor)
	_texto("TOMAR", origen + Vector2(46, 25) * factor, 16, TINTA, factor)
	origen = tabla.position + Vector2(488, 444) * factor
	_dibujar_tecla(origen, 58.0, "ESC", factor)
	_texto("SALIR", origen + Vector2(70, 25) * factor, 16, TINTA, factor)


func _dibujar_tecla(posicion: Vector2, ancho: float, etiqueta: String, factor: float) -> void:
	var caja := Rect2(posicion, Vector2(ancho, 34.0) * factor)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = TINTA
	estilo.border_color = CREMA
	estilo.set_border_width_all(maxi(1, roundi(2.0 * factor)))
	estilo.set_corner_radius_all(maxi(3, roundi(7.0 * factor)))
	draw_style_box(estilo, caja)
	var tamano := maxi(10, roundi(18.0 * factor))
	var ancho_texto := FUENTE.get_string_size(etiqueta, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
	draw_string(FUENTE, Vector2(caja.position.x + (caja.size.x - ancho_texto) * 0.5, caja.position.y + 25.0 * factor), etiqueta, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, CREMA)


func _dibujar_planillero(tabla: Rect2, factor: float) -> void:
	var sombra := StyleBoxFlat.new()
	sombra.bg_color = Color(0.04, 0.11, 0.14, 0.62)
	sombra.set_corner_radius_all(maxi(4, roundi(10.0 * factor)))
	var sombra_rect := tabla.grow(3.0 * factor)
	sombra_rect.position += Vector2(8, 10) * factor
	draw_style_box(sombra, sombra_rect)
	var carton := StyleBoxFlat.new()
	carton.bg_color = CARTON
	carton.border_color = CARTON_OSCURO
	carton.set_border_width_all(maxi(2, roundi(4.0 * factor)))
	carton.set_corner_radius_all(maxi(4, roundi(10.0 * factor)))
	draw_style_box(carton, tabla)
	for i: int in range(75):
		var mancha := tabla.position + Vector2(15 + (i * 139) % 704, 26 + (i * 83) % 470) * factor
		draw_circle(mancha, (1.0 + float(i % 3) * 0.4) * factor, Color(0.43, 0.31, 0.20, 0.11))
	var cx := tabla.position.x + tabla.size.x * 0.5
	var y := tabla.position.y
	var pinza := PackedVector2Array([
		Vector2(cx - 34.0 * factor, y + 15.0 * factor),
		Vector2(cx - 22.0 * factor, y - 22.0 * factor),
		Vector2(cx - 15.0 * factor, y - 30.0 * factor),
		Vector2(cx + 15.0 * factor, y - 30.0 * factor),
		Vector2(cx + 22.0 * factor, y - 22.0 * factor),
		Vector2(cx + 34.0 * factor, y + 15.0 * factor)
	])
	draw_colored_polygon(pinza, METAL)
	for lado: int in range(pinza.size() - 1):
		draw_line(pinza[lado], pinza[lado + 1], TINTA, 3.0 * factor, true)
	for raya: int in range(5):
		var altura := y - (17.0 - raya * 5.0) * factor
		draw_line(Vector2(cx - 18.0 * factor, altura), Vector2(cx + 18.0 * factor, altura), Color("5c6b68"), 2.0 * factor, true)
	var barra := Rect2(Vector2(cx - 77.0 * factor, y + 10.0 * factor), Vector2(154, 16) * factor)
	draw_rect(barra.grow(3.0 * factor), TINTA)
	draw_rect(barra, Color("b5c0b9"))
	for lado: int in [-1, 1]:
		var tornillo := Vector2(cx + lado * 63.0 * factor, y + 18.0 * factor)
		draw_circle(tornillo, 6.0 * factor, TINTA)
		draw_circle(tornillo, 3.0 * factor, CREMA)


func _dibujar_referencia(tabla: Rect2, factor: float, tipo: int) -> void:
	var origen := tabla.position + Vector2(139, 285) * factor
	draw_set_transform(origen, -0.035, Vector2.ONE * factor)
	var silueta := PackedVector2Array([
		Vector2(-99, -133), Vector2(72, -133), Vector2(99, -106),
		Vector2(99, 133), Vector2(-99, 133)
	])
	var sombra := PackedVector2Array()
	for punto: Vector2 in silueta:
		sombra.append(punto + Vector2(6, 8))
	draw_colored_polygon(sombra, Color(0.22, 0.15, 0.10, 0.25))
	draw_colored_polygon(silueta, CREMA)
	for lado: int in range(silueta.size()):
		draw_line(silueta[lado], silueta[(lado + 1) % silueta.size()], TINTA, 3.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(72, -133), Vector2(72, -106), Vector2(99, -106)]), CARTON)
	draw_line(Vector2(72, -133), Vector2(72, -106), TINTA, 2.0, true)
	draw_line(Vector2(72, -106), Vector2(99, -106), TINTA, 2.0, true)
	draw_string(FUENTE, Vector2(-80, -93), "ARCHIVO SOLICITADO", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TINTA)
	draw_string(FUENTE, Vector2(-80, -44), TIPOS[tipo], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, TINTA)
	draw_line(Vector2(-80, -19), Vector2(78, -19), Color(TINTA, 0.35), 2.0, true)
	draw_line(Vector2(-80, 6), Vector2(70, 6), Color(TINTA, 0.35), 2.0, true)
	draw_line(Vector2(-80, 31), Vector2(42, 31), Color(TINTA, 0.35), 2.0, true)
	draw_rect(Rect2(Vector2(-80, 60), Vector2(112, 29)), CORAL, false, 3.0)
	draw_string(FUENTE, Vector2(-72, 81), "OBJETIVO", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, CORAL)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _dibujar_papel(indice: int, tabla: Rect2, factor: float, elegido: bool) -> void:
	var cantidad := papeles.size()
	var separacion := 128.0 if cantidad == 3 else 154.0
	var x := (float(indice) - float(cantidad - 1) * 0.5) * separacion
	var centro := tabla.position + Vector2(496, 302) * factor
	var altura := -18.0 if elegido else 0.0
	var giro := (float(indice) - float(cantidad - 1) * 0.5) * 0.13
	draw_set_transform(centro + Vector2(x, altura) * factor, giro, Vector2.ONE * factor)
	var contorno := PackedVector2Array([
		Vector2(-82, -110), Vector2(54, -110), Vector2(82, -82),
		Vector2(82, 110), Vector2(-82, 110)
	])
	var sombra := PackedVector2Array()
	for punto: Vector2 in contorno:
		sombra.append(punto + Vector2(7, 9))
	draw_colored_polygon(sombra, Color(0.07, 0.16, 0.20, 0.5))
	if elegido:
		var resalte := PackedVector2Array()
		for punto: Vector2 in contorno:
			resalte.append(punto * 1.055)
		draw_colored_polygon(resalte, CREMA)
	var color: Color = COLORES[papeles[indice]]
	draw_colored_polygon(contorno, color)
	for lado: int in range(contorno.size()):
		draw_line(contorno[lado], contorno[(lado + 1) % contorno.size()], TINTA, 4.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(54, -110), Vector2(54, -82), Vector2(82, -82)]), CREMA)
	draw_line(Vector2(54, -110), Vector2(54, -82), TINTA, 2.5, true)
	draw_line(Vector2(54, -82), Vector2(82, -82), TINTA, 2.5, true)
	draw_string(FUENTE, Vector2(-68, -52), TIPOS[papeles[indice]], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, TINTA)
	for linea: int in range(4):
		var y := -26.0 + linea * 22.0
		draw_line(Vector2(-65, y), Vector2(58 if linea < 3 else 22, y), Color(TINTA, 0.43), 2.0, true)
	draw_rect(Rect2(Vector2(-65, 72), Vector2(25, 25)), CREMA)
	draw_line(Vector2(-59, 84), Vector2(-50, 91), TINTA, 2.5, true)
	draw_line(Vector2(-50, 91), Vector2(-44, 78), TINTA, 2.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if elegido:
		var flecha := PackedVector2Array([
			centro + Vector2(x - 13, altura - 132) * factor,
			centro + Vector2(x + 13, altura - 132) * factor,
			centro + Vector2(x, altura - 115) * factor
		])
		draw_colored_polygon(flecha, CORAL)


func _texto(valor: String, posicion: Vector2, tamano: int, color: Color, factor: float) -> void:
	draw_string(FUENTE, posicion, valor, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(10, roundi(tamano * factor)), color)
