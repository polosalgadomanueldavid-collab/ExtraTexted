extends Control
## Una presentación persistente, independiente de la escena que se descarga.
const ESCRITORIO := preload("res://UI/Menus/ArtePiloto/carga_escritorio.webp")
const TEMA := preload("res://UI/Menus/tema_ajustes.tres")
const LECTURA := preload("res://UI/Menus/fuente_lectura.tres")
var imagen: TextureRect
var vapor: Node2D
var lienzo: Control
var logo: TextureRect
var texto: Label
var barra: ProgressBar
var cancelar: Button
var voz: Label
var frase: Label
var mensajes: Array = []
var indice := 0
var tiempo := 0.0
var fundido: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	imagen = TextureRect.new()
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	imagen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(imagen)
	vapor = Node2D.new()
	imagen.add_child(vapor)
	vapor.draw.connect(_dibujar_vapor)
	var velo := TextureRect.new()
	var gradiente := Gradient.new()
	gradiente.set_color(0, Color("071923b0"))
	gradiente.set_color(1, Color("07192300"))
	var textura := GradientTexture2D.new()
	textura.gradient = gradiente
	textura.fill_to = Vector2(1, 0)
	velo.texture = textura
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(velo)
	lienzo = Control.new()
	lienzo.size = Vector2(1280, 720)
	add_child(lienzo)
	logo = TextureRect.new()
	logo.texture = preload("res://UI/Menus/ArtePiloto/extra_texted_logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.position = Vector2(68, 120)
	logo.size = Vector2(400, 260)
	lienzo.add_child(logo)
	voz = _etiqueta(Vector2(76, 380), Vector2(500, 32), 24)
	voz.add_theme_font_override("font", TEMA.default_font)
	voz.add_theme_color_override("font_color", Color("ffd28e"))
	frase = _etiqueta(Vector2(76, 420), Vector2(510, 100), 28)
	frase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto = _etiqueta(Vector2(76, 554), Vector2(510, 42), 26)
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	barra = ProgressBar.new()
	barra.position = Vector2(76, 610)
	barra.show_percentage = false
	barra.add_theme_font_size_override("font_size", 1)
	for tipo in ["background", "fill"]:
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Color("ff785f") if tipo == "fill" else Color("365360")
		estilo.set_corner_radius_all(4)
		barra.add_theme_stylebox_override(tipo, estilo)
	lienzo.add_child(barra)
	barra.set_deferred("size", Vector2(510, 8))
	cancelar = Button.new()
	cancelar.text = "Volver al menú"
	cancelar.theme = TEMA
	cancelar.position = Vector2(76, 644)
	cancelar.size = Vector2(250, 48)
	cancelar.add_theme_font_size_override("font_size", 21)
	lienzo.add_child(cancelar)
	resized.connect(_ajustar)
	_ajustar()

func _etiqueta(posicion: Vector2, dimensiones: Vector2, tamano: int) -> Label:
	var etiqueta := Label.new()
	etiqueta.position = posicion
	etiqueta.size = dimensiones
	etiqueta.add_theme_font_override("font", LECTURA)
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", Color("fff1d8"))
	lienzo.add_child(etiqueta)
	return etiqueta

func preparar(es_menu: bool, oficina: Texture2D, dialogos: Array) -> void:
	if is_instance_valid(fundido): fundido.kill()
	modulate.a = 1.0
	imagen.texture = ESCRITORIO if es_menu or oficina == null else oficina
	logo.visible = es_menu
	vapor.visible = es_menu
	cancelar.visible = not es_menu
	mensajes = [] if es_menu else dialogos.duplicate(true)
	indice = 0
	tiempo = 0
	voz.visible = not mensajes.is_empty()
	frase.visible = voz.visible
	_mostrar_frase()
	texto.text = "Abriendo menú…" if es_menu else "Preparando turno…"
	barra.value = 0
	barra.indeterminate = false

func _process(delta: float) -> void:
	if is_visible_in_tree() and vapor.visible:
		vapor.queue_redraw()
	if not is_visible_in_tree() or mensajes.size() < 2: return
	tiempo += delta
	if tiempo >= 5.0:
		tiempo = 0
		indice = (indice + 1) % mensajes.size()
		_mostrar_frase()

func _mostrar_frase() -> void:
	if mensajes.is_empty(): return
	voz.text = mensajes[indice][0]
	frase.text = mensajes[indice][1]

func _ajustar() -> void:
	if lienzo == null: return
	var factor := minf(size.x / 1280.0, size.y / 720.0)
	lienzo.scale = Vector2.ONE * factor
	lienzo.position = (size - Vector2(1280, 720) * factor) * 0.5
	var escritorio := ESCRITORIO.get_size()
	var escala := maxf(size.x / escritorio.x, size.y / escritorio.y)
	vapor.position = (size - escritorio * escala) * 0.5 + escritorio * Vector2(0.862, 0.422) * escala
	vapor.scale = Vector2.ONE * escala

func _dibujar_vapor() -> void:
	var reloj := Time.get_ticks_msec() * 0.001
	for hilo in 2:
		var anterior := Vector2.ZERO
		for paso in 21:
			var t := paso / 20.0
			var punto := Vector2(hilo * 13 - 6 + sin(t * 5 + reloj + hilo) * (2 + 5 * t), -t * 65)
			if paso > 0:
				vapor.draw_line(anterior, punto, Color(1, 0.94, 0.85, 0.19 * sin(PI * t)), 2.2, true)
			anterior = punto
