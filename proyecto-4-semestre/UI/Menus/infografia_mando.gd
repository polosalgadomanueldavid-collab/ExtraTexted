extends Control
## Diagrama escalable: las coordenadas de las llamadas corresponden a la foto.
const FOTO := preload("res://UI/Menus/ArtePiloto/mando_recortado.png")
const TITULAR := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const LECTURA := preload("res://UI/Menus/fuente_lectura.tres")
const TINTA := Color("173b50")
const CREMA := Color("fff1d8")
const CORAL := Color("ff785f")
const BASE := Vector2(1120, 540)
const FOTO_RECT := Rect2(350, 120, 420, 264)
var trazos: Trazos
var lienzo: Control
var llamadas: Array[Dictionary] = []
var seccion := 0
var _medallones: Array[Vector2] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo = Control.new()
	lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lienzo)
	resized.connect(_ajustar)
	mostrar(0)

func mostrar(indice: int) -> void:
	seccion = indice
	if not is_instance_valid(lienzo):
		return
	for hijo in lienzo.get_children():
		lienzo.remove_child(hijo)
		hijo.queue_free()
	llamadas.clear()
	_medallones.clear()
	var imagen := TextureRect.new()
	imagen.texture = FOTO
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagen.position = FOTO_RECT.position
	imagen.size = FOTO_RECT.size
	imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo.add_child(imagen)
	trazos = Trazos.new()
	trazos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo.add_child(trazos)
	if indice != 1:
		_visual(indice, imagen)
		_ajustar()
		return
	_llamada("PALANCA IZQUIERDA", "Menús y cuaderno: selecciona.\nApagón: mueve el cursor.", 0, Vector2(0.287, 0.344))
	_llamada("CRUCETA · CUADERNO", "Izquierda / derecha: pasa páginas.\nX: zoom · B: alejar o Menú.", 1, Vector2(0.403, 0.562))
	_llamada("LB / RB · OPCIONES", "Cambia entre las opciones\ndisponibles del panel.", 2, Vector2(0.275, 0.09))
	_llamada("PALANCA DERECHA", "Desplaza las listas largas.\nEn la ruleta, apunta al gesto.", 3, Vector2(0.610, 0.562))
	_llamada("VIEW · CLASIFICACIÓN", "Mantén para ver los puntos\ny el aporte del equipo.", 4, Vector2(0.446, 0.344))
	_llamada("A · CONFIRMAR", "Activa la opción o el gesto.\nTienda: comprar, recoger y usar.", 5, Vector2(0.729, 0.440))
	_llamada("B · VOLVER", "Cierra paneles y la ruleta.\nCuaderno: aleja o elige Menú.", 6, Vector2(0.790, 0.344))
	_llamada("START · PAUSA", "Abre la pausa durante la partida.\nVuelve desde los paneles.", 7, Vector2(0.570, 0.344))
	_rotulo("R3 · CAMBIAR CÁMARA", Vector2(40, 474), 500, 22)
	_rotulo("X · MANTENER PARA USAR EL EXTINTOR", Vector2(570, 474), 530, 22)
	trazos.llamadas = llamadas
	trazos.queue_redraw()
	_ajustar()

func _visual(indice: int, imagen: TextureRect) -> void:
	imagen.position = Vector2(365, 230)
	imagen.size = Vector2(390, 245)
	if indice == 0:
		_accion(Vector2(170, 135), "MOVERSE", "LS / CRUCETA", "walk", Vector2(0.287, 0.344))
		_accion(Vector2(170, 385), "CORRER", "L3 · MANTENER", "run", Vector2(0.287, 0.344))
		_accion(Vector2(950, 385), "SALTAR", "A", "jump", Vector2(0.729, 0.440))
		_accion(Vector2(950, 135), "INTERACTUAR", "X", "idle", Vector2(0.671, 0.344))
		_icono("res://UI/Despacho/Arte/papel_medallon.png", Rect2(975, 123, 64, 64))
		var escena := Simbolos.new()
		escena.position = Vector2(880, 65)
		lienzo.add_child(escena)
		_accion(Vector2(560, 105), "GESTOS", "Y", "wave", Vector2(0.729, 0.264))
		for i in 5:
			var nombre: String = ["aura", "rasengan", "kamehameha", "genkidama", "explosion_final"][i]
			var punto := Vector2(560, 100) + Vector2.from_angle(PI + i * PI / 4.0) * 83
			_icono("res://UI/Menus/ArtePiloto/Emotes/%s.png" % nombre, Rect2(punto - Vector2.ONE * 24, Vector2.ONE * 48))
	else:
		_objeto(Vector2(170, 130), "MÁS VELOCIDAD", "LB · CHOCOLATE", "chocolate", "run", Vector2(0.275, 0.09))
		_objeto(Vector2(950, 130), "SALTO ALTO", "RB · DONA", "dona", "jump", Vector2(0.725, 0.09))
		_objeto(Vector2(170, 380), "DETENER TIEMPO", "LT · PAPA TIEMPO", "papa_tiempo", "reloj", Vector2(0.31, 0.055))
		_objeto(Vector2(950, 380), "RESOLVER EVENTO", "RT · EL AVATAR", "avatar", "resolver", Vector2(0.69, 0.055))
		_accion(Vector2(560, 100), "BEBER CAFÉ", "A · CON TAZA", "idle", Vector2(0.729, 0.440))
		_icono("res://UI/Descanso/Arte/cafe.png", Rect2(571, 94, 65, 65))
		_rotulo("LT / RT · GATILLOS TRASEROS", Vector2(360, 495), 400, 17)
	trazos.llamadas = llamadas
	trazos.queue_redraw()

func _icono(ruta: String, caja: Rect2) -> void:
	var icono := TextureRect.new()
	icono.texture = load(ruta)
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.position = caja.position
	icono.size = caja.size
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo.add_child(icono)

func _rotulo(texto: String, posicion: Vector2, ancho: float, tamano: int) -> void:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.position = posicion
	etiqueta.size = Vector2(ancho, 30)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_override("font", TITULAR)
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", TINTA)
	lienzo.add_child(etiqueta)

func _accion(centro: Vector2, texto: String, tecla: String, pose: String, punto: Vector2) -> void:
	_medallones.append(centro)
	_icono("res://UI/Menus/ArtePiloto/Acciones/%s.png" % pose, Rect2(centro - Vector2(80, 82), Vector2(160, 160)))
	_rotulo(texto, centro + Vector2(-135, 85), 270, 25)
	_rotulo(tecla, centro + Vector2(-135, 115), 270, 20)
	var simbolos := Simbolos.new()
	simbolos.accion = pose
	simbolos.position = centro - Vector2(70, 70)
	lienzo.add_child(simbolos)
	_flecha(centro, punto)

func _objeto(centro: Vector2, titulo: String, boton: String, icono: String, efecto: String, punto: Vector2) -> void:
	_medallones.append(centro)
	_icono("res://UI/Descanso/Arte/%s.png" % icono, Rect2(centro - Vector2(92, 48), Vector2(92, 92)))
	if efecto in ["run", "jump"]:
		_icono("res://UI/Menus/ArtePiloto/Acciones/%s.png" % efecto, Rect2(centro - Vector2(8, 78), Vector2(140, 140)))
	var simbolos := Simbolos.new()
	simbolos.accion = efecto
	simbolos.position = centro - Vector2(20, 70)
	lienzo.add_child(simbolos)
	_rotulo(titulo, centro + Vector2(-135, 85), 270, 25)
	_rotulo(boton, centro + Vector2(-135, 115), 270, 22)
	_flecha(centro, punto)

func _flecha(centro: Vector2, punto: Vector2) -> void:
	var foto := Vector2(390, 245)
	var tamano := FOTO.get_size() * minf(foto.x / FOTO.get_width(), foto.y / FOTO.get_height())
	var destino := Vector2(365, 230) + (foto - tamano) * 0.5 + tamano * punto
	var origen := centro + centro.direction_to(destino) * 93
	llamadas.append({"origen": origen, "destino": destino, "codo": (origen.x + destino.x) * 0.5})

class Simbolos extends Control:
	var accion := "mesa"
	func _draw() -> void:
		var tinta := Color("173b50")
		var acento := Color("ec9f39")
		match accion:
			"mesa":
				draw_style_box(_caja(), Rect2(-25, 70, 55, 40))
				draw_rect(Rect2(-20, 75, 45, 28), Color("66bfc5"))
				draw_line(Vector2(2, 109), Vector2(2, 122), tinta, 4, true)
				draw_line(Vector2(-38, 123), Vector2(42, 123), tinta, 7, true)
			"run":
				for i in 3:
					draw_line(Vector2(-8 - i * 6, 75 + i * 14), Vector2(33, 75 + i * 14), acento, 5, true)
			"walk":
				for lado in [-1, 1]:
					draw_line(Vector2(70, 134), Vector2(70 + lado * 65, 134), acento, 4, true)
					draw_polyline(PackedVector2Array([Vector2(70 + lado * 55, 126), Vector2(70 + lado * 65, 134), Vector2(70 + lado * 55, 142)]), acento, 4, true)
			"jump":
				draw_set_transform(Vector2(65, 124), 0, Vector2(1, 0.3))
				draw_arc(Vector2.ZERO, 27, 0, TAU, 32, Color("b8a786"), 3, true)
				draw_set_transform(Vector2.ZERO)
				draw_line(Vector2(126, 112), Vector2(126, 26), acento, 5, true)
				draw_polyline(PackedVector2Array([Vector2(117, 37),Vector2(126,26),Vector2(135,37)]),acento,4,true)
			"reloj":
				draw_circle(Vector2(75, 73), 42, Color("fff1d8"))
				draw_arc(Vector2(75,73),42,0,TAU,48,tinta,5,true)
				draw_line(Vector2(75,73),Vector2(75,42),tinta,4,true)
				draw_line(Vector2(75,73),Vector2(96,84),tinta,4,true)
				draw_rect(Rect2(54,126,10,23),acento)
				draw_rect(Rect2(77,126,10,23),acento)
			"resolver":
				draw_circle(Vector2(73, 79), 44, Color("89af70"))
				draw_polyline(PackedVector2Array([Vector2(46, 79), Vector2(65, 98), Vector2(100, 58)]), tinta, 9, true)

	func _caja() -> StyleBoxFlat:
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Color("173b50")
		estilo.set_corner_radius_all(4)
		return estilo

func _llamada(titulo: String, descripcion: String, lugar: int, punto: Vector2, icono: String = "") -> void:
	var derecha := lugar >= 4
	var posicion := Vector2(810 if derecha else 10, 16 + (lugar % 4) * 106)
	var panel := PanelContainer.new()
	panel.position = posicion
	panel.size = Vector2(300, 94)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = TINTA
	estilo.border_color = Color("dcac5c")
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(12)
	estilo.content_margin_left = 12
	estilo.content_margin_right = 12
	estilo.content_margin_top = 10
	estilo.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", estilo)
	lienzo.add_child(panel)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 4)
	panel.add_child(columna)
	var fila := HBoxContainer.new()
	columna.add_child(fila)
	if not icono.is_empty():
		var dibujo := TextureRect.new()
		dibujo.texture = load("res://UI/Descanso/Arte/%s.png" % icono)
		dibujo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dibujo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dibujo.custom_minimum_size = Vector2(26, 26)
		fila.add_child(dibujo)
	var rotulo := Label.new()
	rotulo.text = titulo
	rotulo.add_theme_font_override("font", TITULAR)
	rotulo.add_theme_font_size_override("font_size", 20)
	rotulo.add_theme_color_override("font_color", Color("ffcc79"))
	fila.add_child(rotulo)
	var texto := Label.new()
	texto.text = descripcion
	texto.add_theme_font_override("font", LECTURA)
	texto.add_theme_font_size_override("font_size", 16)
	texto.add_theme_color_override("font_color", CREMA)
	columna.add_child(texto)
	var origen := posicion + Vector2(0 if derecha else 300, 47)
	var tamano := FOTO.get_size() * minf(FOTO_RECT.size.x / FOTO.get_width(), FOTO_RECT.size.y / FOTO.get_height())
	var destino := FOTO_RECT.position + (FOTO_RECT.size - tamano) * 0.5 + tamano * punto
	if titulo.begins_with("LT ·"):
		destino = Vector2(470, 108)
	elif titulo.begins_with("RT ·"):
		destino = Vector2(660, 108)
	llamadas.append({"origen": origen, "destino": destino, "codo": 790.0 if derecha else 330.0})

func _ajustar() -> void:
	if not is_instance_valid(lienzo):
		return
	var factor := minf(size.x / BASE.x, size.y / BASE.y)
	lienzo.scale = Vector2.ONE * factor
	lienzo.position = (size - BASE * factor) * 0.5
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(lienzo):
		return
	draw_set_transform(lienzo.position, 0, lienzo.scale)
	draw_circle(Vector2(560, 330 if seccion != 1 else 240), 190, Color("e7d7b8"))
	for centro: Vector2 in _medallones:
		draw_circle(centro, 90, Color("eadbbd"))
		draw_arc(centro, 91, 0, TAU, 64, Color("d2b989"), 2, true)

class Trazos extends Control:
	var llamadas: Array[Dictionary] = []
	func _draw() -> void:
		for llamada: Dictionary in llamadas:
			var origen: Vector2 = llamada.origen
			var destino: Vector2 = llamada.destino
			var codo := Vector2(llamada.codo, origen.y)
			draw_polyline(PackedVector2Array([origen, codo, destino]), Color("ff785f"), 3, true)
			var direccion := (destino - codo).normalized()
			var lateral := Vector2(-direccion.y, direccion.x)
			draw_colored_polygon(PackedVector2Array([destino, destino - direccion * 12 + lateral * 6, destino - direccion * 12 - lateral * 6]), Color("ff785f"))
			draw_circle(destino, 2.5, Color("fff1d8"))
