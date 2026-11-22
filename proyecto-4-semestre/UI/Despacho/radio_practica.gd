extends Control
## Radio ilustrada con los mismos materiales, fuentes y escalado del HUD.
signal omitir
const TITULO := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const TEXTO := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
const TINTA := Color("173b50")
const CREMA := Color("fff1d8")
const CORAL := Color("ff785f")
const CARTON := Color("c79e6d")
var objetivo: Node3D
var etiqueta_objetivo := ""
var detalle_objetivo := ""
var compacta := false
var _titulo := ""
var _mensaje := ""
var _paso := 0
var _precio := 50
var _entrada := 0.0
var _etiqueta: Label
var _cuerpo: Label
var _salida: Button
var _sonido: AudioStreamPlayer
var _factor := 1.0
var _caja := Rect2()

func _ready() -> void:
	name = "RadioPractica"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	_etiqueta = Label.new()
	_etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_etiqueta.add_theme_font_override("font", TITULO)
	_etiqueta.add_theme_color_override("font_color", TINTA)
	add_child(_etiqueta)
	_cuerpo = Label.new()
	_cuerpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cuerpo.add_theme_font_override("font", TEXTO)
	_cuerpo.add_theme_color_override("font_color", TINTA)
	_cuerpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_cuerpo)
	_salida = Button.new()
	_salida.text = "F2 · OMITIR PRÁCTICA"
	_salida.add_theme_font_override("font", TEXTO)
	_salida.add_theme_font_size_override("font_size", 13)
	for estado in ["normal", "hover", "pressed", "focus"]:
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = TINTA.lightened(.10) if estado == "hover" else TINTA
		estilo.border_color = CORAL if estado == "focus" else CREMA
		estilo.set_border_width_all(2 if estado == "focus" else 0)
		estilo.set_corner_radius_all(5)
		estilo.content_margin_left = 10
		estilo.content_margin_right = 10
		_salida.add_theme_stylebox_override(estado, estilo)
	_salida.add_theme_color_override("font_color", CREMA)
	_salida.add_theme_color_override("font_hover_color", CREMA)
	_salida.pressed.connect(func(): omitir.emit())
	add_child(_salida)
	_sonido = AudioStreamPlayer.new()
	_sonido.bus = "Interacciones"
	_sonido.volume_db = -23
	_sonido.stream = _crear_entrada_radio()
	add_child(_sonido)

func presentar(titulo: String, mensaje: String, paso: int, precio: int) -> void:
	var cambio := titulo != _titulo or mensaje != _mensaje
	_titulo = titulo
	_mensaje = mensaje
	_paso = paso
	_precio = precio
	_etiqueta.text = titulo
	_cuerpo.text = mensaje
	if cambio:
		_entrada = .35 if AjustesAccesibilidad.balanceo_camara else 0.0
		_sonido.play()

func _process(delta: float) -> void:
	_entrada = maxf(0.0, _entrada - delta)
	_factor = minf(size.x / 1280.0, size.y / 720.0)
	# Centro inferior: deja libres la hoja/inventario y la lista lateral de casos.
	var ancho := minf(650.0, size.x / _factor - 32.0)
	var alto := 153.0
	var y := size.y / _factor - alto - 24.0 + smoothstep(0.0, .35, _entrada) * 20.0
	_caja = Rect2((size.x / _factor - ancho) * .5, y, ancho, alto)
	_etiqueta.visible = not compacta
	_cuerpo.visible = not compacta
	_salida.visible = not compacta and _paso != 5
	_etiqueta.position = (_caja.position + Vector2(91, 28)) * _factor
	_etiqueta.size = Vector2(ancho - 112, 25) * _factor
	_etiqueta.add_theme_font_size_override("font_size", maxi(13, roundi(21 * _factor)))
	_cuerpo.position = (_caja.position + Vector2(91, 57)) * _factor
	_cuerpo.size = Vector2(ancho - 112, 60) * _factor
	_cuerpo.add_theme_font_size_override("font_size", maxi(12, roundi(17 * _factor)))
	_salida.scale = Vector2.ONE * _factor
	_salida.size = Vector2(185, 26)
	_salida.position = (_caja.end - Vector2(199, 34)) * _factor
	_salida.text = "VISTA · OMITIR" if ControladorInterfaz.dispositivo_mando >= 0 else "F2 · OMITIR PRÁCTICA"
	queue_redraw()

func _unhandled_input(evento: InputEvent) -> void:
	if not visible or compacta or _paso == 5:
		return
	var tecla: bool = evento is InputEventKey and evento.pressed and not evento.echo and evento.physical_keycode == KEY_F2
	var mando: bool = evento is InputEventJoypadButton and evento.pressed and evento.device == ControladorInterfaz.dispositivo_mando and evento.button_index == JOY_BUTTON_BACK
	if tecla or mando:
		get_viewport().set_input_as_handled()
		omitir.emit()

func _draw() -> void:
	if _factor <= 0:
		return
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * _factor)
	if compacta:
		var caja := Rect2(size.x / _factor * .5 - 290, size.y / _factor - 45, 580, 30)
		_panel(caja, CREMA, TINTA)
		_letra("PRÁCTICA · COMPARA LA REFERENCIA. PUEDES REINTENTAR.", caja.position + Vector2(12, 20), 14, TINTA)
		draw_set_transform(Vector2.ZERO)
		return
	_panel(Rect2(_caja.position + Vector2(65, 0), _caja.size - Vector2(65, 0)), CREMA, TINTA)
	for i in 5:
		var altura := _caja.position.y + 54 + i * 19
		draw_line(Vector2(_caja.position.x + 87, altura), Vector2(_caja.end.x - 16, altura), Color(CARTON, .22), 1.0, true)
	_letra("DESPACHO · CANAL 01", _caja.position + Vector2(91, 19), 12, CORAL)
	_dibujar_radio(_caja.position + Vector2(12, 18))
	var leyenda := "PRÁCTICA · SIN PLAZO NI EMERGENCIAS" if _paso != 5 else "PRÁCTICA COMPLETADA"
	_letra(leyenda, Vector2(_caja.position.x + 100, _caja.end.y - 13), 11, TINTA)
	draw_set_transform(Vector2.ZERO)
	_dibujar_objetivo()

func _dibujar_radio(origen: Vector2) -> void:
	draw_set_transform(origen * _factor, -.09, Vector2.ONE * _factor)
	_panel(Rect2(12, -31, 8, 47), TINTA, Color("657d85"))
	_panel(Rect2(0, 5, 72, 117), TINTA, Color("657d85"))
	_panel(Rect2(11, 19, 49, 24), Color("c2c6a5"), TINTA)
	_letra("01", Vector2(23, 37), 17, TINTA)
	for i in 6:
		draw_line(Vector2(14, 55 + i * 6), Vector2(57, 55 + i * 6), Color("65808a"), 2, true)
	draw_circle(Vector2(52, 106), 6, CARTON, true, -1, true)
	draw_circle(Vector2(20, 106), 3, CORAL, true, -1, true)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * _factor)

func _dibujar_objetivo() -> void:
	if not is_instance_valid(objetivo) or not objetivo.is_inside_tree():
		return
	var camara := get_viewport().get_camera_3d()
	if camara == null:
		return
	var punto := objetivo.global_position + Vector3.UP * 1.1
	var destino := camara.unproject_position(punto)
	if camara.is_position_behind(punto):
		destino = size - destino
	var ancho := maxf(244, TITULO.get_string_size(etiqueta_objetivo, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 28) * _factor
	ancho = maxf(ancho, TEXTO.get_string_size(detalle_objetivo, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x * _factor + 24 * _factor)
	destino.x = clampf(destino.x, ancho * .5 + 12, size.x - ancho * .5 - 12)
	destino.y = clampf(destino.y, 110 * _factor, _caja.position.y * _factor - 40 * _factor)
	var caja := Rect2(destino - Vector2(ancho * .5, 62 * _factor), Vector2(ancho, 56 * _factor))
	_panel(caja, CREMA, TINTA)
	draw_string(TITULO, caja.position + Vector2(12, 23) * _factor, etiqueta_objetivo, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(11, roundi(17 * _factor)), TINTA)
	draw_string(TEXTO, caja.position + Vector2(12, 44) * _factor, detalle_objetivo, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(11, roundi(14 * _factor)), TINTA)
	draw_colored_polygon(PackedVector2Array([destino + Vector2(-6, 0) * _factor, destino + Vector2(6, 0) * _factor, destino + Vector2(0, 9) * _factor]), CORAL)

func _panel(caja: Rect2, color: Color, borde: Color) -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.border_color = borde
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(7)
	estilo.shadow_color = Color(0.02, .09, .13, .25)
	estilo.shadow_size = 3
	estilo.shadow_offset = Vector2(3, 5)
	draw_style_box(estilo, caja)

func _letra(texto: String, punto: Vector2, tamano: int, color: Color) -> void:
	draw_string(TITULO, punto, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, color)

func _crear_entrada_radio() -> AudioStreamWAV:
	var muestras := PackedByteArray()
	muestras.resize(6615 * 2)
	for i in 6615:
		var t := i / 44100.0
		var envolvente := sin(PI * clampf(t / .15, 0.0, 1.0)) * .24
		var valor := sin(TAU * (740 if t < .075 else 920) * t) * envolvente
		muestras.encode_s16(i * 2, int(valor * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.data = muestras
	return stream
