extends RefCounted
## Ilustración de mantenimiento con la tinta, papel y tipografía de las mesas.

const TITULO := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const TEXTO := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
const TAMANO := Vector2(900, 650)
const CENTROS := [Vector2(325, 266), Vector2(575, 266), Vector2(325, 416), Vector2(575, 416)]
const SALIR := Rect2(748, 27, 120, 40)
const RADIO_TUERCA := 54.0
const TINTA := Color("173b50")
const CREMA := Color("fff1d8")
const PAPEL := Color("f6e4bf")
const CORAL := Color("ff785f")
const ORO := Color("ffce67")
const VERDE := Color("79d6b0")
const HIELO := Color("d9f3ff")
const AZUL := Color("79bad4")
var _c: Control
var _lectura := FontVariation.new()


func _init() -> void:
	_lectura.base_font = TEXTO
	_lectura.variation_opentype = {2003265652: 600.0} # wght: Nunito seminegrita.


func dibujar(panel: Control) -> void:
	_c = panel
	_c.draw_rect(Rect2(Vector2.ZERO, panel.size), Color(0.04, 0.10, 0.14, 0.78))
	_c.draw_set_transform(panel._origen, 0, Vector2.ONE * panel._escala)
	_papel()
	_cabecera(panel)
	_secuencia(panel)
	_maquina(panel)
	for i in 4:
		_tuerca(panel, i)
	_resultado(panel)
	_controles()
	_c.draw_set_transform(Vector2.ZERO)
	_c = null


func _papel() -> void:
	_caja(Rect2(7, 9, 900, 650), Color("091f2b"), 20)
	_caja(Rect2(Vector2.ZERO, TAMANO), CREMA, 20, TINTA, 5)
	# Trama de imprenta muy tenue, sin competir con las instrucciones.
	for y in range(22, 640, 18):
		for x in range(20, 890, 18):
			if y > 164 and y < 576 and x > 26 and x < 875:
				continue
			_c.draw_circle(Vector2(x + (y / 18 % 2) * 5, y), 0.75, Color(TINTA, 0.045))
	_c.draw_line(Vector2(28, 102), Vector2(872, 102), Color("dcc6a1"), 2, true)
	_caja(Rect2(350, -8, 200, 15), Color("b6aaa0"), 5, TINTA, 3)
	_c.draw_line(Vector2(365, -3), Vector2(535, -3), CREMA, 3, true)


func _cabecera(panel: Control) -> void:
	_texto("MANTENIMIENTO  /  ZONA DE DESCANSO", Vector2(32, 26), 13, Color("536878"))
	_texto("FUGA DE NITRÓGENO", Vector2(32, 64), 37, TINTA, TITULO)
	_texto("Aprieta las tuercas en cruz y sella la tubería.", Vector2(33, 89), 19, TINTA)
	_caja(Rect2(SALIR.position + Vector2(0, 4), SALIR.size), TINTA, 10)
	var sobre: bool = SALIR.has_point((panel.get_local_mouse_position() - panel._origen) / panel._escala)
	_caja(SALIR, ORO if sobre else PAPEL, 10, TINTA, 3)
	_texto("ESC", Vector2(761, 54), 20, TINTA, TITULO)
	_texto("Salir", Vector2(808, 53), 18, TINTA)


func _secuencia(panel: Control) -> void:
	_texto("ORDEN", Vector2(34, 141), 20, TINTA, TITULO)
	for j in 4:
		var p := Vector2(157 + j * 66, 130)
		var hecho: bool = panel.resuelto or j < panel.paso % 4
		var actual: bool = not panel.resuelto and j == panel.paso % 4
		var color := VERDE if hecho else (ORO if actual else Color("dfd4bc"))
		_caja(Rect2(p - Vector2(21, 19), Vector2(42, 38)), color, 9, TINTA, 2)
		_centrado(str(panel.orden[j] + 1), p + Vector2(0, 9), 24, TINTA, TITULO)
		if actual:
			_poligono(PackedVector2Array([p + Vector2(-5, 24), p + Vector2(5, 24), p + Vector2(0, 19)]), TINTA)
		if j < 3:
			_c.draw_line(p + Vector2(27, 0), p + Vector2(39, 0), TINTA, 2, true)
			_c.draw_polyline(PackedVector2Array([p + Vector2(35, -4), p + Vector2(39, 0), p + Vector2(35, 4)]), TINTA, 2, true)
	_texto("PASADA", Vector2(624, 139), 18, TINTA, TITULO)
	for j in 3:
		var p := Vector2(735 + j * 48, 130)
		var completada: bool = panel.paso >= (j + 1) * 4
		var activa: bool = not panel.resuelto and panel.paso / 4 == j
		_c.draw_circle(p, 17, TINTA, true, -1, true)
		_c.draw_circle(p, 14, VERDE if completada else (ORO if activa else PAPEL), true, -1, true)
		if completada:
			_check(p, 7, TINTA)
		else:
			_centrado(str(j + 1), p + Vector2(0, 7), 18, TINTA, TITULO)


func _maquina(panel: Control) -> void:
	_caja(Rect2(28, 166, 844, 322), Color("547784"), 15, TINTA, 4)
	_caja(Rect2(33, 171, 834, 308), Color("acc8cb"), 12)
	# Chapa con remaches y marcas de desgaste; la tubería ocupa el centro.
	for punto: Vector2 in [Vector2(48, 187), Vector2(852, 187), Vector2(48, 467), Vector2(852, 467)]:
		_tornillo(punto)
	for i in 13:
		var p := Vector2(67 + (i * 137 % 760), 206 + (i * 53 % 237))
		_c.draw_line(p, p + Vector2(12 + i % 4 * 5, -2), Color("7f9fa8"), 1, true)
	# Tubo cilíndrico con reborde, reflejo y sombra inferior.
	_caja(Rect2(62, 306, 776, 91), Color(TINTA, 0.20), 14)
	_caja(Rect2(61, 296, 778, 87), TINTA, 14)
	_caja(Rect2(66, 301, 768, 77), Color("567f95"), 10)
	_caja(Rect2(67, 302, 766, 52), Color("9fc4d0"), 8)
	_c.draw_line(Vector2(78, 311), Vector2(822, 311), HIELO, 6, true)
	_c.draw_line(Vector2(80, 370), Vector2(820, 370), Color("365e75"), 4, true)
	for x: float in [88.0, 790.0]:
		_caja(Rect2(x, 290, 24, 98), Color("6c8e9c"), 6, TINTA, 3)
		_c.draw_line(Vector2(x + 6, 298), Vector2(x + 6, 377), Color("d4e8e7"), 3, true)
	# Dos mitades de la brida dejan a la vista la junta que se está sellando.
	_caja(Rect2(257, 218, 388, 248), Color(TINTA, 0.25), 22)
	_caja(Rect2(252, 208, 396, 249), Color("527587"), 21, TINTA, 5)
	_caja(Rect2(259, 215, 185, 235), Color("88aab6"), 15)
	_caja(Rect2(455, 215, 186, 235), Color("789cab"), 15)
	_c.draw_line(Vector2(276, 220), Vector2(427, 220), Color("cce4e7"), 4, true)
	_c.draw_line(Vector2(471, 220), Vector2(622, 220), Color("b7d9e3"), 4, true)
	_c.draw_line(Vector2(449, 220), Vector2(449, 449), TINTA, 8, true)
	var fuga: float = 1.0 - panel.paso / 12.0
	_c.draw_line(Vector2(450, 315), Vector2(450, 372), VERDE if panel.resuelto else Color("bcecff"), 3 + fuga * 3, true)
	_escarcha(panel, fuga)
	_manometro(Vector2(164, 249), fuga)
	_etiqueta_nitrogeno()
	# El vapor sale de la junta y disminuye con los aprietes.
	for i in 8:
		var fase := fposmod(panel._tiempo * 0.6 + i * 0.131, 1.0)
		var p := Vector2(450 + sin(i * 2.2) * fase * 23, 343 - fase * 102)
		_c.draw_circle(p, 5 + fase * 13, Color(HIELO, (1.0 - fase) * fuga * 0.54), true, -1, true)
	_centrado("JUNTA N₂", Vector2(450, 408), 12, Color("d5e6e8"), TITULO)
	if panel._acierto > 0 and panel._ultima_tuerca >= 0:
		var p: Vector2 = CENTROS[panel._ultima_tuerca] + Vector2(0, -58 - (1.0 - panel._acierto) * 13)
		_centrado("¡CLAC!", p, 19, TINTA, TITULO, 4, CREMA)


func _escarcha(panel: Control, fuga: float) -> void:
	var nieve := PackedVector2Array([Vector2(262, 225), Vector2(270, 210), Vector2(286, 210), Vector2(294, 203), Vector2(307, 207), Vector2(321, 204), Vector2(335, 213), Vector2(367, 212), Vector2(379, 219), Vector2(396, 219), Vector2(403, 229), Vector2(370, 226), Vector2(362, 239), Vector2(354, 226), Vector2(326, 224), Vector2(318, 234), Vector2(309, 225), Vector2(279, 227)])
	_poligono(nieve, HIELO, Color("75a8bd"), 2)
	_c.draw_line(Vector2(276, 213), Vector2(289, 213), Color("f3fcff"), 3, true)
	_poligono(PackedVector2Array([Vector2(521, 445), Vector2(535, 434), Vector2(549, 439), Vector2(564, 430), Vector2(581, 437), Vector2(604, 433), Vector2(627, 445), Vector2(621, 451), Vector2(527, 452)]), HIELO, Color("75a8bd"), 2)
	_copo(Vector2(731, 422), 14, Color("edfaff"))
	_copo(Vector2(191, 419), 9, Color("edfaff"))
	if not panel.resuelto:
		var p := Vector2(450, 184)
		_caja(Rect2(p - Vector2(65, 11), Vector2(130, 28)), CREMA, 6, TINTA, 2)
		_centrado("¡QUÉ FRÍO!" if fuga > 0.5 else "CASI SELLADA", p + Vector2(0, 9), 15, TINTA, TITULO)


func _manometro(centro: Vector2, fuga: float) -> void:
	_c.draw_line(centro + Vector2(0, 34), centro + Vector2(0, 53), TINTA, 16, true)
	_c.draw_line(centro + Vector2(0, 34), centro + Vector2(0, 53), Color("7da0b2"), 10, true)
	_c.draw_circle(centro + Vector2(3, 5), 43, Color(TINTA, 0.20), true, -1, true)
	_c.draw_circle(centro, 42, TINTA, true, -1, true)
	_c.draw_circle(centro, 37, CREMA, true, -1, true)
	_c.draw_arc(centro, 29, PI * 0.83, PI * 1.38, 24, VERDE, 7, true)
	_c.draw_arc(centro, 29, PI * 1.40, PI * 1.76, 18, ORO, 7, true)
	_c.draw_arc(centro, 29, PI * 1.78, PI * 2.17, 18, CORAL, 7, true)
	for i in 7:
		var d := Vector2.from_angle(lerpf(PI * 0.83, PI * 2.17, i / 6.0))
		_c.draw_line(centro + d * 23, centro + d * 28, TINTA, 2, true)
	var aguja := Vector2.from_angle(lerpf(PI * 0.86, PI * 2.12, fuga))
	_c.draw_line(centro, centro + aguja * 25, TINTA, 4, true)
	_c.draw_circle(centro, 5, CORAL if fuga > 0 else VERDE, true, -1, true)
	_centrado("FUGA", centro + Vector2(0, 23), 10, TINTA, TITULO)


func _etiqueta_nitrogeno() -> void:
	_c.draw_polyline(PackedVector2Array([Vector2(769, 299), Vector2(763, 276), Vector2(753, 260)]), TINTA, 2, true)
	_poligono(PackedVector2Array([Vector2(695, 204), Vector2(791, 210), Vector2(797, 260), Vector2(696, 269), Vector2(683, 238)]), CREMA, TINTA, 3)
	_centrado("N₂", Vector2(739, 243), 32, TINTA, TITULO)
	_centrado("NITRÓGENO", Vector2(739, 258), 10, TINTA, TITULO)


func _tuerca(panel: Control, i: int) -> void:
	var centro: Vector2 = CENTROS[i]
	var objetivo: bool = i == panel.objetivo_actual()
	var completa: bool = panel.aprietes[i] == 3
	var sobre: bool = i == panel._sobre_tuerca
	var golpe: float = panel._golpes[i]
	var cara := VERDE if completa else (ORO if objetivo else Color("c4d4d7"))
	if panel._error > 0.0 and i == panel.seleccion:
		cara = CORAL
	_c.draw_circle(centro + Vector2(0, 6), 49, Color("39596c"), true, -1, true)
	_c.draw_circle(centro, 46, TINTA, true, -1, true)
	_c.draw_circle(centro, 41, Color("6d8a99"), true, -1, true)
	var elevacion := Vector2(0, -3.0 * float(sobre) - sin(golpe * PI) * 4.0)
	var angulo: float = panel._giros[i]
	var hexagono := _hexagono(centro + elevacion, 38, angulo)
	_poligono(_hexagono(centro + Vector2(0, 7), 38, angulo), cara.darkened(0.35), TINTA, 3)
	_poligono(hexagono, cara, TINTA, 4)
	var interior := _hexagono(centro + elevacion, 29, angulo)
	_c.draw_polyline(PackedVector2Array([hexagono[3], hexagono[4], hexagono[5]]), cara.lightened(0.32), 3, true)
	_poligono(interior, cara.lightened(0.08), Color(TINTA, 0.25), 1)
	_c.draw_circle(centro + elevacion, 18, TINTA, true, -1, true)
	_centrado(str(i + 1), centro + elevacion + Vector2(0, 8), 24, CREMA, TITULO)
	# Tres marcas por tuerca: apriete conocido incluso sin distinguir colores.
	for j in 3:
		var p := centro + Vector2((j - 1) * 17, 53)
		_caja(Rect2(p - Vector2(6, 4), Vector2(12, 8)), VERDE if j < panel.aprietes[i] else Color("527181"), 3, TINTA, 1)
	if i == panel.seleccion or sobre:
		var color := CORAL if panel._error > 0 and i == panel.seleccion else TINTA
		for signo: float in [-1.0, 1.0]:
			for vertical: float in [-1.0, 1.0]:
				var p := centro + Vector2(signo * 53, vertical * 44)
				_c.draw_polyline(PackedVector2Array([p - Vector2(signo * 10, 0), p, p - Vector2(0, vertical * 9)]), CREMA, 7, true)
				_c.draw_polyline(PackedVector2Array([p - Vector2(signo * 10, 0), p, p - Vector2(0, vertical * 9)]), color, 3, true)
	if objetivo:
		var p := centro + Vector2(-55, -23)
		_poligono(PackedVector2Array([p, p + Vector2(-11, -7), p + Vector2(-11, 7)]), ORO, TINTA, 2)


func _resultado(panel: Control) -> void:
	var fondo := VERDE if panel.resuelto else (CORAL if panel._error > 0 else TINTA)
	_caja(Rect2(28, 503, 844, 54), fondo, 11, TINTA, 3)
	var mensaje := "¡FUGA SELLADA!" if panel.resuelto else "APRIETA LA TUERCA %d" % (panel.objetivo_actual() + 1)
	if panel._error > 0:
		mensaje = "¡EN CRUZ! SIGUE CON LA %d" % (panel.objetivo_actual() + 1)
	_texto(mensaje, Vector2(48, 538), 25, TINTA if panel.resuelto or panel._error > 0 else CREMA, TITULO)
	_texto("%02d / 12 APRIETES" % panel.paso, Vector2(661, 536), 17, TINTA if panel.resuelto or panel._error > 0 else CREMA)
	# Progreso compacto; la secuencia y las tuercas aportan el detalle.
	_caja(Rect2(29, 565, 842, 8), Color("d8c7a9"), 4)
	if panel.paso > 0:
		_caja(Rect2(29, 565, 842 * panel.paso / 12.0, 8), Color("4caa94"), 4)


func _controles() -> void:
	_tecla("CLIC", Vector2(35, 588), 53)
	_texto("Apretar", Vector2(98, 608), 17, TINTA)
	_tecla("WASD / FLECHAS", Vector2(233, 588), 142)
	_texto("Elegir", Vector2(385, 608), 17, TINTA)
	_tecla("E / ESPACIO", Vector2(518, 588), 124)
	_texto("Apretar", Vector2(653, 608), 17, TINTA)
	_texto("Puedes salir y continuar después. Los casos siguen en marcha.", Vector2(35, 636), 15, Color("536878"))


func _tecla(valor: String, p: Vector2, ancho: float) -> void:
	_caja(Rect2(p + Vector2(0, 3), Vector2(ancho, 27)), TINTA, 5)
	_caja(Rect2(p, Vector2(ancho, 27)), PAPEL, 5, TINTA, 2)
	_centrado(valor, p + Vector2(ancho * 0.5, 19), 13, TINTA, TITULO)


func _copo(p: Vector2, radio: float, color: Color) -> void:
	for i in 6:
		var d := Vector2.from_angle(i * TAU / 6.0)
		_c.draw_line(p, p + d * radio, color, 2, true)
		_c.draw_line(p + d * radio * 0.7, p + (d * 0.4 + d.orthogonal() * 0.28) * radio, color, 2, true)


func _tornillo(p: Vector2) -> void:
	_c.draw_circle(p, 7, TINTA, true, -1, true)
	_c.draw_circle(p, 5, Color("d0dfd9"), true, -1, true)
	_c.draw_line(p + Vector2(-2, 2), p + Vector2(2, -2), TINTA, 2, true)


func _check(p: Vector2, radio: float, color: Color) -> void:
	_c.draw_polyline(PackedVector2Array([p + Vector2(-radio, 0), p + Vector2(-radio * 0.2, radio * 0.65), p + Vector2(radio, -radio * 0.65)]), color, 3, true)


func _hexagono(p: Vector2, radio: float, angulo: float) -> PackedVector2Array:
	var puntos := PackedVector2Array()
	for i in 6:
		puntos.append(p + Vector2.from_angle(angulo + i * TAU / 6.0) * radio)
	return puntos


func _poligono(puntos: PackedVector2Array, color: Color, borde := Color.TRANSPARENT, grosor := 0.0) -> void:
	_c.draw_colored_polygon(puntos, color)
	if grosor > 0:
		var contorno := puntos.duplicate()
		contorno.append(contorno[0])
		_c.draw_polyline(contorno, borde, grosor, true)


func _caja(rect: Rect2, color: Color, radio := 0, borde := Color.TRANSPARENT, grosor := 0) -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.border_color = borde
	estilo.set_corner_radius_all(radio)
	estilo.set_border_width_all(grosor)
	_c.draw_style_box(estilo, rect)


func _texto(valor: String, p: Vector2, tamano: int, color: Color, fuente: Font = null) -> void:
	if fuente == null:
		fuente = _lectura
	_c.draw_string(fuente, p, valor, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, color)


func _centrado(valor: String, p: Vector2, tamano: int, color: Color, fuente: Font = null, contorno := 0, tinta := TINTA) -> void:
	if fuente == null:
		fuente = _lectura
	p.x -= fuente.get_string_size(valor, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x * 0.5
	if contorno > 0:
		_c.draw_string_outline(fuente, p, valor, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, contorno, tinta)
	_texto(valor, p, tamano, color, fuente)
