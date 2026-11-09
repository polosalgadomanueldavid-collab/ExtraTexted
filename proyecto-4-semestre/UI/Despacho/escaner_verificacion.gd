extends Control
## Escáner visto de cerca: detener la luz sobre la franja válida del documento.

signal verificacion_terminada(caso_id: String)
signal cerrado

const FUENTE := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const TINTA := Color("173b50")
const CREMA := Color("fff1d8")
const CORAL := Color("ff785f")
const VERDE := Color("79d693")
const METAL := Color("b9c5c0")
const DURACION_ENTRADA: float = 0.48
const VELOCIDAD: float = 0.55
const DURACION_FALLO: float = 0.55
const ANCHO_ZONA: float = 0.16
const SonidosMesas := preload("res://UI/Despacho/sonidos_mesas.gd")

var caso_id: String = ""
var marcador: float = 0.0
var direccion: float = 1.0
var zona_centro: float = 0.5
var error_restante: float = 0.0
var entrada_restante: float = 0.0
var aleatorio := RandomNumberGenerator.new()
var sonido_barrido: AudioStreamPlayer
var sonido_error: AudioStreamPlayer


func _ready() -> void:
	name = "EscanerVerificacion"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	aleatorio.randomize()
	sonido_barrido = SonidosMesas.crear_reproductor(self, "MotorEscaner", SonidosMesas.ESCANER, -15.0, true)
	sonido_error = SonidosMesas.crear_reproductor(self, "ErrorEscaner", SonidosMesas.RECHAZO, -12.0)
	visibility_changed.connect(_al_cambiar_visibilidad)
	hide()


func iniciar(id: String) -> void:
	sonido_barrido.stop()
	sonido_error.stop()
	if caso_id != id:
		caso_id = id
		zona_centro = aleatorio.randf_range(0.27, 0.73)
	marcador = 0.0
	direccion = 1.0
	error_restante = 0.0
	entrada_restante = DURACION_ENTRADA
	show()
	queue_redraw()


func cancelar() -> void:
	hide()
	caso_id = ""
	error_restante = 0.0
	entrada_restante = 0.0
	cerrado.emit()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if entrada_restante > 0.0:
		entrada_restante = maxf(0.0, entrada_restante - delta)
		queue_redraw()
		return
	if error_restante > 0.0:
		error_restante = maxf(0.0, error_restante - delta)
	else:
		if not sonido_barrido.playing:
			sonido_barrido.play()
		marcador += direccion * VELOCIDAD * delta
		if marcador >= 1.0:
			marcador = 2.0 - marcador
			direccion = -1.0
		elif marcador <= 0.0:
			marcador = -marcador
			direccion = 1.0
	queue_redraw()


func _input(evento: InputEvent) -> void:
	if not is_visible_in_tree() or not evento is InputEventKey or not evento.pressed or evento.echo:
		return
	var tecla: int = evento.physical_keycode if evento.physical_keycode != 0 else evento.keycode
	if tecla == KEY_ESCAPE:
		hide()
		entrada_restante = 0.0
		cerrado.emit()
	elif tecla == KEY_E:
		if entrada_restante <= 0.0:
			_detener()
	else:
		return
	get_viewport().set_input_as_handled()
	queue_redraw()


func _detener() -> void:
	if error_restante > 0.0:
		return
	sonido_barrido.stop()
	if absf(marcador - zona_centro) > ANCHO_ZONA * 0.5:
		marcador = 0.0
		direccion = 1.0
		error_restante = DURACION_FALLO
		sonido_error.play()
		return
	var id_terminado := caso_id
	hide()
	caso_id = ""
	cerrado.emit()
	verificacion_terminada.emit(id_terminado)


func _al_cambiar_visibilidad() -> void:
	if not is_visible_in_tree():
		sonido_barrido.stop()
		sonido_error.stop()


func _draw() -> void:
	var factor := minf(size.x / 1280.0, size.y / 720.0)
	var centro := size * 0.5
	var t := clampf(1.0 - entrada_restante / DURACION_ENTRADA, 0.0, 1.0)
	var avance := t * t * (3.0 - 2.0 * t)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.10, 0.14, 0.73 * minf(1.0, t * 3.0)))
	var panel := Rect2(centro - Vector2(430, 255) * factor, Vector2(860, 510) * factor)
	panel.position.y += (1.0 - avance) * (size.y - panel.position.y + 42.0 * factor)
	_dibujar_caja(panel, TINTA, Color("426473"), 12.0, 2.0, factor)
	_texto("VERIFICACIÓN", panel.position + Vector2(30, 48) * factor, 29, CREMA, factor)
	_texto("DETÉN LA LUZ CORAL DENTRO DE LA FRANJA VERDE DEL DOCUMENTO.", panel.position + Vector2(30, 78) * factor, 17, CREMA, factor)
	_dibujar_escaner(panel, factor)
	if error_restante > 0.0:
		_texto("FUERA DE ZONA · INTENTA DE NUEVO", panel.position + Vector2(240, 486) * factor, 18, CORAL, factor)
	else:
		_texto("BARRIDO EN CURSO", panel.position + Vector2(305, 486) * factor, 18, VERDE, factor)
	_dibujar_tecla(panel.position + Vector2(674, 460) * factor, 59.0, "ESC", factor)
	_texto("SALIR", panel.position + Vector2(746, 486) * factor, 16, CREMA, factor)


func _dibujar_escaner(panel: Rect2, factor: float) -> void:
	var origen := panel.position
	var sombra := Rect2(origen + Vector2(34, 163) * factor, Vector2(804, 301) * factor)
	_dibujar_caja(sombra, Color(0.02, 0.07, 0.09, 0.65), TINTA, 11.0, 0.0, factor)
	var tapa := PackedVector2Array([
		origen + Vector2(51, 113) * factor,
		origen + Vector2(808, 113) * factor,
		origen + Vector2(827, 151) * factor,
		origen + Vector2(33, 151) * factor
	])
	draw_colored_polygon(tapa, Color("e9eee5"))
	for i: int in range(tapa.size()):
		draw_line(tapa[i], tapa[(i + 1) % tapa.size()], TINTA, 5.0 * factor, true)
	draw_line(origen + Vector2(45, 145) * factor, origen + Vector2(815, 145) * factor, Color("869d99"), 5.0 * factor, true)
	var cuerpo := Rect2(origen + Vector2(25, 150) * factor, Vector2(810, 300) * factor)
	_dibujar_caja(cuerpo, METAL, TINTA, 11.0, 8.0, factor)
	var cristal_marco := Rect2(cuerpo.position + Vector2(23, 16) * factor, Vector2(764, 230) * factor)
	draw_rect(cristal_marco, Color("5a7374"))
	var cristal := Rect2(cristal_marco.position + Vector2(10, 9) * factor, cristal_marco.size - Vector2(20, 18) * factor)
	draw_rect(cristal, Color("193b4b"))
	_dibujar_documento(cristal, factor)
	var zona_y := cristal.position.y + cristal.size.y * (zona_centro - ANCHO_ZONA * 0.5)
	var alto_zona := cristal.size.y * ANCHO_ZONA
	var zona := Rect2(Vector2(cristal.position.x, zona_y), Vector2(cristal.size.x, alto_zona))
	draw_rect(zona, Color(VERDE, 0.56))
	draw_line(zona.position, zona.position + Vector2(zona.size.x, 0), VERDE, 3.0 * factor, true)
	draw_line(Vector2(zona.position.x, zona.end.y), zona.end, VERDE, 3.0 * factor, true)
	var etiqueta := Rect2(Vector2(cristal.end.x - 142.0 * factor, zona_y + 4.0 * factor), Vector2(130, 27) * factor)
	draw_rect(etiqueta, Color(CREMA, 0.83))
	_texto("ZONA VÁLIDA", etiqueta.position + Vector2(8, 20) * factor, 15, TINTA, factor)
	var haz_y := cristal.position.y + cristal.size.y * marcador
	draw_rect(Rect2(Vector2(cristal.position.x, haz_y - 11.0 * factor), Vector2(cristal.size.x, 22.0 * factor)), Color(CORAL, 0.14))
	draw_rect(Rect2(Vector2(cristal.position.x, haz_y - 5.0 * factor), Vector2(cristal.size.x, 10.0 * factor)), Color(CORAL, 0.38))
	draw_line(Vector2(cristal.position.x, haz_y), Vector2(cristal.end.x, haz_y), CORAL, 6.0 * factor, true)
	_texto("ESCÁNER DE DOCUMENTOS", cuerpo.position + Vector2(26, 284) * factor, 16, TINTA, factor)
	_dibujar_tecla(cuerpo.position + Vector2(605, 256) * factor, 34.0, "E", factor)
	_texto("DETENER", cuerpo.position + Vector2(652, 282) * factor, 17, TINTA, factor)


func _dibujar_documento(cristal: Rect2, factor: float) -> void:
	var centro_papel := cristal.position + Vector2(cristal.size.x * 0.5, cristal.size.y * 0.5)
	draw_set_transform(centro_papel, -0.028, Vector2.ONE * factor)
	var contorno := PackedVector2Array([
		Vector2(-266, -95), Vector2(245, -95), Vector2(266, -74),
		Vector2(266, 95), Vector2(-266, 95)
	])
	var sombra := PackedVector2Array()
	for punto: Vector2 in contorno:
		sombra.append(punto + Vector2(6, 7))
	draw_colored_polygon(sombra, Color(0.01, 0.06, 0.08, 0.55))
	draw_colored_polygon(contorno, Color("f7f4eb"))
	for i: int in range(contorno.size()):
		draw_line(contorno[i], contorno[(i + 1) % contorno.size()], Color("33494b"), 3.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(245, -95), Vector2(245, -74), Vector2(266, -74)]), Color("d8ddd3"))
	draw_line(Vector2(245, -95), Vector2(245, -74), Color("33494b"), 2.0, true)
	draw_line(Vector2(245, -74), Vector2(266, -74), Color("33494b"), 2.0, true)
	draw_string(FUENTE, Vector2(-237, -59), "DOCUMENTO EN REVISIÓN", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, TINTA)
	for i: int in range(5):
		var y := -35.0 + 19.0 * i
		var ancho := 435.0 if i % 2 == 0 else 325.0
		draw_line(Vector2(-235, y), Vector2(-235 + ancho, y), Color(TINTA, 0.29), 4.0, true)
	draw_string(FUENTE, Vector2(-237, 77), "ESTACIÓN DE VERIFICACIÓN · CASO ACTIVO", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TINTA)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _dibujar_caja(caja: Rect2, fondo: Color, borde: Color, radio: float, grosor: float, factor: float) -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(maxi(0, roundi(grosor * factor)))
	estilo.set_corner_radius_all(maxi(2, roundi(radio * factor)))
	draw_style_box(estilo, caja)


func _dibujar_tecla(posicion: Vector2, ancho: float, etiqueta: String, factor: float) -> void:
	var caja := Rect2(posicion, Vector2(ancho, 34.0) * factor)
	_dibujar_caja(caja, TINTA, CREMA, 7.0, 2.0, factor)
	var tamano := maxi(10, roundi(18.0 * factor))
	var ancho_texto := FUENTE.get_string_size(etiqueta, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
	draw_string(FUENTE, Vector2(caja.position.x + (caja.size.x - ancho_texto) * 0.5, caja.position.y + 25.0 * factor), etiqueta, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, CREMA)


func _texto(valor: String, posicion: Vector2, tamano: int, color: Color, factor: float) -> void:
	draw_string(FUENTE, posicion, valor, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(10, roundi(tamano * factor)), color)
