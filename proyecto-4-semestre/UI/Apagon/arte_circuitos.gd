extends Control
## Representación del tablero. El panel conserva los estados y las interacciones.

const V := preload("res://UI/Apagon/volumen_circuitos.gd")
const TAMANO_DISENO := Vector2(860, 510)
const ORIGEN_INTERIOR := Vector2(60, 110)
const TAMANO_INTERIOR := Vector2(740, 300)
const INTERRUPTORES := 0
const FASES := 2
const CABLES := 3
const TINTA := Color("173b50")
const CREMA := Color("fff1d8")
const CORAL := Color("ff785f")
const METAL := Color("b9c5c0")
const METAL_OSCURO := Color("869d99")
const PINTURA := Color("496b72")
const VERDE := Color("79d693")
const CIAN := Color("36dec8")
const COLORES_CABLE := [VERDE, Color("54bfe4"), Color("e5af42"), CORAL]
const ALTURAS_CABLE := [45.0, 115.0, 185.0, 255.0]

var _tipo: int = INTERRUPTORES
var _estado: Dictionary = {}
var _visual: Dictionary = {}
var _firma_fija: Array = []
var _marco: CapaDibujo
var _hardware: CapaDibujo
var _dinamico: CapaDibujo


class CapaDibujo extends Control:
	var dibujar: Callable

	func _draw() -> void:
		dibujar.call(self)


func _ready() -> void:
	size = TAMANO_DISENO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crear_capas()


func actualizar(tipo: int, estado: Dictionary, visual: Dictionary) -> void:
	_tipo = tipo
	_estado = estado
	_visual = visual
	_crear_capas()
	var firma: Array = [tipo, estado.get("objetivos", []).duplicate(), estado.get("destinos", []).duplicate()]
	if firma != _firma_fija:
		_firma_fija = firma
		_hardware.queue_redraw()
	_dinamico.queue_redraw()


static func rect_interruptor(indice: int) -> Rect2:
	return Rect2(ORIGEN_INTERIOR + Vector2(26 + indice * 142, 22), Vector2(120, 246))


static func rect_fase(indice: int) -> Rect2:
	return Rect2(ORIGEN_INTERIOR + Vector2(76 + indice * 245, 236), Vector2(98, 44))


static func rect_origen(indice: int) -> Rect2:
	return Rect2(ORIGEN_INTERIOR + Vector2(8, ALTURAS_CABLE[indice] - 24), Vector2(150, 48))


static func rect_destino(indice: int) -> Rect2:
	return Rect2(ORIGEN_INTERIOR + Vector2(580, ALTURAS_CABLE[indice] - 24), Vector2(150, 48))


func _crear_capas() -> void:
	if is_instance_valid(_marco):
		return
	_marco = CapaDibujo.new()
	_marco.name = "Carcasa"
	_marco.size = TAMANO_DISENO
	_marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marco.dibujar = _dibujar_marco
	add_child(_marco)
	_hardware = CapaDibujo.new()
	_hardware.name = "ComponentesFijos"
	_hardware.size = TAMANO_DISENO
	_hardware.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hardware.dibujar = _dibujar_hardware
	add_child(_hardware)
	_dinamico = CapaDibujo.new()
	_dinamico.name = "ComponentesMoviles"
	_dinamico.size = TAMANO_DISENO
	_dinamico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dinamico.dibujar = _dibujar_dinamico
	add_child(_dinamico)


func _dibujar_marco(lienzo: CanvasItem) -> void:
	V.dibujar_placa(lienzo, Rect2(0, 0, 860, 510), METAL_OSCURO, 13, 12)
	V.dibujar_placa(lienzo, Rect2(9, 7, 842, 494), PINTURA, 10, 3)
	V.dibujar_placa(lienzo, Rect2(46, 96, 768, 328), METAL_OSCURO, 13, 5)
	V.dibujar_rectangulo_redondeado(lienzo, Rect2(55, 105, 750, 310), TINTA.darkened(0.55), 9)
	V.dibujar_gradiente(lienzo, Rect2(60, 110, 740, 300), Color("153444"), Color("254a56"), 6)
	lienzo.draw_line(Vector2(66, 112), Vector2(794, 112), Color(0.005, 0.02, 0.025, 0.65), 4, true)
	lienzo.draw_line(Vector2(799, 119), Vector2(799, 401), Color(CREMA, 0.2), 2, true)
	lienzo.draw_line(Vector2(65, 409), Vector2(793, 409), Color(CREMA, 0.24), 2, true)
	for x: int in range(100, 800, 40):
		lienzo.draw_line(Vector2(x, 115), Vector2(x, 405), Color(CREMA, 0.035), 1)
	for y: int in range(150, 410, 40):
		lienzo.draw_line(Vector2(65, y), Vector2(795, y), Color(CREMA, 0.035), 1)
	_dibujar_conductos(lienzo)
	_dibujar_caja_auxiliar(lienzo)
	for y: float in [142.0, 337.0]:
		V.dibujar_placa(lienzo, Rect2(826, y, 31, 61), METAL_OSCURO, 4, 5)
		V.dibujar_placa(lienzo, Rect2(836, y + 3, 11, 55), METAL, 3, 3)
		V.dibujar_tornillo(lienzo, Vector2(833, y + 11), 3, 0.4)
		V.dibujar_tornillo(lienzo, Vector2(833, y + 48), 3, -0.8)
	for datos: Array in [[Vector2(25, 26), -0.75], [Vector2(834, 26), 0.35], [Vector2(25, 482), 0.8], [Vector2(834, 482), -0.4]]:
		V.dibujar_tornillo(lienzo, datos[0], 9, datos[1])
	_dibujar_papel_mantenimiento(lienzo)
	V.dibujar_disco(lienzo, Vector2(801, 53), 8, TINTA)
	V.dibujar_disco(lienzo, Vector2(800, 52), 4, CORAL, false)
	V.dibujar_placa(lienzo, Rect2(137, 451, 586, 32), METAL_OSCURO, 10, 4)
	V.dibujar_rectangulo_redondeado(lienzo, Rect2(144, 457, 572, 20), TINTA.darkened(0.5), 7)
	for linea: PackedVector2Array in [
		PackedVector2Array([Vector2(39, 14), Vector2(65, 14), Vector2(74, 16)]),
		PackedVector2Array([Vector2(758, 492), Vector2(776, 488), Vector2(803, 488)]),
		PackedVector2Array([Vector2(19, 461), Vector2(18, 443)])
	]:
		lienzo.draw_polyline(linea, Color("b9ad92"), 2, true)
		lienzo.draw_polyline(linea, Color(CREMA, 0.3), 0.8, true)


func _dibujar_conductos(lienzo: CanvasItem) -> void:
	for datos: Array in [[Color("54bfe4"), 0.0], [CORAL, -18.0]]:
		var desfase: float = datos[1]
		var curva := Curve2D.new()
		curva.add_point(Vector2(248 + desfase, -10), Vector2.ZERO, Vector2(0, 68))
		curva.add_point(Vector2(182 + desfase, 57), Vector2(52, 0), Vector2(-48, 0))
		curva.add_point(Vector2(138 + desfase, 97), Vector2(0, -40), Vector2.ZERO)
		V.dibujar_cable(lienzo, curva.get_baked_points(), datos[0], 10)
	V.dibujar_placa(lienzo, Rect2(192, 36, 30, 42), METAL_OSCURO, 3, 4)
	V.dibujar_tornillo(lienzo, Vector2(207, 45), 5, 0.2)
	V.dibujar_tornillo(lienzo, Vector2(207, 68), 5, -0.8)
	var tubo := Curve2D.new()
	tubo.add_point(Vector2(20, 73), Vector2.ZERO, Vector2(-48, 0))
	tubo.add_point(Vector2(-13, 141), Vector2(0, -44), Vector2.ZERO)
	V.dibujar_cable(lienzo, tubo.get_baked_points(), METAL_OSCURO, 11)
	var tubo_inferior := Curve2D.new()
	tubo_inferior.add_point(Vector2(-1, 262), Vector2.ZERO, Vector2(0, 100))
	tubo_inferior.add_point(Vector2(23, 412), Vector2(-38, 0), Vector2.ZERO)
	V.dibujar_cable(lienzo, tubo_inferior.get_baked_points(), METAL_OSCURO, 11)
	V.dibujar_placa(lienzo, Rect2(12, 400, 26, 28), METAL_OSCURO, 3, 4)
	V.dibujar_tornillo(lienzo, Vector2(25, 412), 4, 0.8)


func _dibujar_caja_auxiliar(lienzo: CanvasItem) -> void:
	V.dibujar_placa(lienzo, Rect2(-31, 143, 65, 122), PINTURA.lightened(0.09), 6, 8)
	for posicion: Vector2 in [Vector2(-22, 154), Vector2(24, 154), Vector2(-22, 252), Vector2(24, 252)]:
		V.dibujar_tornillo(lienzo, posicion, 4, -0.7)
	var triangulo := PackedVector2Array([Vector2(-18, 227), Vector2(1, 184), Vector2(21, 227)])
	lienzo.draw_colored_polygon(triangulo, Color("e5af42"))
	lienzo.draw_polyline(PackedVector2Array([triangulo[0], triangulo[1], triangulo[2], triangulo[0]]), TINTA, 2, true)
	var rayo := PackedVector2Array([Vector2(4, 196), Vector2(-6, 212), Vector2(2, 212), Vector2(-3, 223), Vector2(10, 206), Vector2(1, 206)])
	lienzo.draw_colored_polygon(rayo, TINTA)


func _dibujar_papel_mantenimiento(lienzo: CanvasItem) -> void:
	var papel := PackedVector2Array([Vector2(670, 34), Vector2(744, 31), Vector2(748, 80), Vector2(673, 84)])
	var sombra := PackedVector2Array()
	for punto: Vector2 in papel:
		sombra.append(punto + Vector2(3, 5))
	lienzo.draw_colored_polygon(sombra, Color(0.01, 0.03, 0.04, 0.3))
	lienzo.draw_colored_polygon(papel, CREMA)
	lienzo.draw_polyline(PackedVector2Array([papel[0], papel[1], papel[2], papel[3], papel[0]]), Color("c3bba2"), 1, true)
	for fila: int in range(3):
		lienzo.draw_line(Vector2(682, 51 + fila * 8), Vector2(731 - fila * 8, 49 + fila * 8), Color(TINTA, 0.28), 1.5, true)
	V.dibujar_placa(lienzo, Rect2(698, 26, 21, 15), METAL_OSCURO, 2, 3)
	lienzo.draw_arc(Vector2(708, 27), 6, PI, TAU, 18, TINTA, 2, true)


func _dibujar_hardware(lienzo: CanvasItem) -> void:
	lienzo.draw_set_transform(ORIGEN_INTERIOR)
	match _tipo:
		INTERRUPTORES:
			for indice: int in range(5):
				_dibujar_interruptor_base(lienzo, 26.0 + indice * 142.0)
		FASES:
			var objetivos: Array = _estado.get("objetivos", [0.0, 0.0, 0.0])
			for indice: int in range(3):
				_dibujar_dial_base(lienzo, Vector2(125 + indice * 245, 136), float(objetivos[indice]))
		CABLES:
			var destinos: Array = _estado.get("destinos", [2, 0, 3, 1])
			for indice: int in range(4):
				var y: float = ALTURAS_CABLE[indice]
				_dibujar_terminal(lienzo, Rect2(8, y - 24, 120, 48), COLORES_CABLE[indice])
				_dibujar_terminal(lienzo, Rect2(610, y - 24, 120, 48), COLORES_CABLE[int(destinos[indice])])
	lienzo.draw_set_transform(Vector2.ZERO)


func _dibujar_dinamico(lienzo: CanvasItem) -> void:
	lienzo.draw_set_transform(ORIGEN_INTERIOR)
	match _tipo:
		INTERRUPTORES:
			_dibujar_interruptores(lienzo)
		FASES:
			_dibujar_fases(lienzo)
		CABLES:
			_dibujar_cables(lienzo)
	var brillo := clampf(float(_visual.get("brillo", 0.0)), 0.0, 1.0)
	if brillo > 0.0:
		V.dibujar_rectangulo_redondeado(lienzo, Rect2(Vector2.ZERO, TAMANO_INTERIOR), Color(CREMA, brillo * 0.1), 6)
	lienzo.draw_set_transform(Vector2.ZERO)
	var progreso := clampf(float(_visual.get("progreso", 0.0)), 0.0, 1.0)
	if progreso > 0.0:
		V.dibujar_gradiente(lienzo, Rect2(146, 459, 568 * progreso, 16), CIAN.lightened(0.18), CIAN.darkened(0.18), 6)
		if progreso * 568 > 12:
			lienzo.draw_line(Vector2(152, 461), Vector2(140 + 568 * progreso, 461), Color(CREMA, 0.6), 1.5, true)


func _dibujar_interruptor_base(lienzo: CanvasItem, x: float) -> void:
	V.dibujar_placa(lienzo, Rect2(x, 22, 120, 246), METAL, 8, 8)
	V.dibujar_placa(lienzo, Rect2(x + 13, 39, 94, 210), METAL.darkened(0.20), 6, 3)
	for esquina: Vector2 in [Vector2(x + 10, 32), Vector2(x + 110, 32), Vector2(x + 10, 258), Vector2(x + 110, 258)]:
		V.dibujar_tornillo(lienzo, esquina, 5)
	V.dibujar_placa(lienzo, Rect2(x + 25, 49, 70, 27), TINTA.darkened(0.18), 7, 3)
	V.dibujar_placa(lienzo, Rect2(x + 37, 87, 46, 148), METAL.darkened(0.08), 5, 2)
	var ranura := Rect2(x + 47, 96, 26, 130)
	lienzo.draw_rect(ranura, TINTA.darkened(0.64))
	lienzo.draw_colored_polygon(PackedVector2Array([
		ranura.position, Vector2(ranura.end.x, ranura.position.y),
		Vector2(ranura.end.x - 4, ranura.position.y + 5), ranura.position + Vector2(4, 5)
	]), TINTA.darkened(0.3))
	lienzo.draw_line(ranura.position, Vector2(ranura.position.x, ranura.end.y), TINTA.darkened(0.42), 3)
	lienzo.draw_line(Vector2(ranura.end.x, ranura.position.y + 1), ranura.end, Color(CREMA, 0.35), 2)
	lienzo.draw_line(Vector2(ranura.position.x + 1, ranura.end.y), ranura.end, Color(CREMA, 0.45), 2)
	lienzo.draw_line(Vector2(x + 60, 100), Vector2(x + 60, 221), METAL.darkened(0.4), 6, true)
	lienzo.draw_line(Vector2(x + 58, 101), Vector2(x + 58, 220), Color(CREMA, 0.3), 1.5, true)


func _dibujar_interruptores(lienzo: CanvasItem) -> void:
	var activos: Array = _estado.get("interruptores", [false, false, false, false, false])
	var palancas: Array = _visual.get("palancas", [])
	var seleccion := int(_visual.get("seleccion", -1))
	for indice: int in range(5):
		var x := 26.0 + indice * 142.0
		var color := VERDE if activos[indice] else CORAL
		var desplazamiento := float(palancas[indice]) if indice < palancas.size() else float(activos[indice])
		V.dibujar_placa(lienzo, Rect2(x + 34, 54, 52, 15), color, 5, 1)
		lienzo.draw_line(Vector2(x + 38, 57), Vector2(x + 80, 57), Color(CREMA, 0.34), 2, true)
		var altura_pomo := lerpf(207.0, 107.0, clampf(desplazamiento, 0.0, 1.0))
		V.dibujar_placa(lienzo, Rect2(x + 22, altura_pomo - 19, 76, 38), METAL, 6, 8)
		V.dibujar_placa(lienzo, Rect2(x + 28, altura_pomo - 13, 64, 25), TINTA.darkened(0.14), 4, 2)
		lienzo.draw_line(Vector2(x + 35, altura_pomo - 9), Vector2(x + 85, altura_pomo - 9), Color(color, 0.85), 3, true)
		for nervio: int in range(4):
			var posicion_x := x + 43.0 + nervio * 11.0
			lienzo.draw_line(Vector2(posicion_x + 1, altura_pomo - 4), Vector2(posicion_x + 1, altura_pomo + 7), TINTA.darkened(0.6), 3, true)
			lienzo.draw_line(Vector2(posicion_x, altura_pomo - 5), Vector2(posicion_x, altura_pomo + 6), Color(METAL, 0.42), 1.5, true)
		if indice == seleccion:
			lienzo.draw_rect(Rect2(x - 3, 19, 126, 252), Color(CREMA, 0.65), false, 2)


func _dibujar_dial_base(lienzo: CanvasItem, centro: Vector2, objetivo: float) -> void:
	lienzo.draw_circle(centro + Vector2(1, 6), 86, TINTA.darkened(0.3), true, -1, true)
	V.dibujar_disco(lienzo, centro, 85, METAL)
	lienzo.draw_arc(centro, 81, PI * 1.05, PI * 1.83, 42, CREMA.lightened(0.15), 3, true)
	lienzo.draw_arc(centro, 81, PI * 0.06, PI * 0.91, 42, METAL.darkened(0.42), 3, true)
	lienzo.draw_circle(centro, 74, TINTA.darkened(0.12), true, -1, true)
	lienzo.draw_circle(centro + Vector2(0, 1), 70, CREMA.darkened(0.055), true, -1, true)
	lienzo.draw_arc(centro, 71, PI * 1.02, PI * 1.97, 48, TINTA.darkened(0.13), 5, true)
	lienzo.draw_arc(centro + Vector2(0, 1), 70, 0.08, PI - 0.08, 48, CREMA.lightened(0.22), 2, true)
	lienzo.draw_arc(centro + Vector2(0, 2), 59, objetivo - 0.38, objetivo + 0.38, 25, VERDE.darkened(0.35), 17, true)
	lienzo.draw_arc(centro, 59, objetivo - 0.38, objetivo + 0.38, 25, VERDE, 14, true)
	lienzo.draw_arc(centro, 64, objetivo - 0.35, objetivo + 0.35, 25, VERDE.lightened(0.3), 2, true)
	for limite: float in [objetivo - 0.38, objetivo + 0.38]:
		var radial := Vector2.from_angle(limite)
		lienzo.draw_line(centro + radial * 49, centro + radial * 69, TINTA, 2, true)
	for indice: int in range(24):
		var direccion := Vector2.from_angle(float(indice) * TAU / 24.0)
		var inicio := 55.0 if indice % 3 == 0 else 61.0
		lienzo.draw_line(centro + direccion * inicio, centro + direccion * 67, TINTA, 3 if indice % 3 == 0 else 2, true)
	for indice: int in range(4):
		var direccion := Vector2.from_angle(PI * 0.25 + indice * PI * 0.5)
		V.dibujar_tornillo(lienzo, centro + direccion * 79, 3.6, -0.65)
	var boton := Vector2(centro.x, 258)
	V.dibujar_cable(lienzo, PackedVector2Array([boton + Vector2(0, -36), boton + Vector2(0, -22)]), TINTA.lightened(0.18), 7)
	V.dibujar_placa(lienzo, Rect2(boton - Vector2(49, 22), Vector2(98, 44)), METAL, 7, 5)
	for lado: float in [-1.0, 1.0]:
		V.dibujar_tornillo(lienzo, boton + Vector2(lado * 40, 0), 3.7, -0.7)
	V.dibujar_placa(lienzo, Rect2(boton - Vector2(31, 15), Vector2(51, 30)), TINTA.darkened(0.18), 5, 1)


func _dibujar_fases(lienzo: CanvasItem) -> void:
	var fases: Array = _estado.get("fases", [0.0, 0.0, 0.0])
	var fijados: Array = _estado.get("fijados", [false, false, false])
	var presiones: Array = _visual.get("presiones", [])
	var seleccion := int(_visual.get("seleccion", -1))
	var error_indice := int(_visual.get("error_indice", -1))
	var error := clampf(float(_visual.get("error", 0.0)), 0.0, 1.0)
	for indice: int in range(3):
		var centro := Vector2(125 + indice * 245, 136)
		var fijado: bool = fijados[indice]
		if seleccion == indice:
			lienzo.draw_arc(centro, 93, 0, TAU, 96, Color(CREMA, 0.58), 2, true)
			lienzo.draw_arc(centro, 93, 0.08 * PI, 0.55 * PI, 28, CORAL, 3, true)
		if error_indice == indice and error > 0:
			lienzo.draw_arc(centro, 93, 0, TAU, 96, Color(CORAL, error), 4, true)
		_dibujar_aguja(lienzo, centro, float(fases[indice]))
		V.dibujar_tornillo(lienzo, centro, 13, -0.7)
		var led := centro + Vector2(0, 32)
		V.dibujar_disco(lienzo, led, 7, METAL, false)
		lienzo.draw_circle(led, 4.2, VERDE if fijado else TINTA, true, -1, true)
		if fijado:
			lienzo.draw_arc(led, 3.1, PI * 1.05, PI * 1.75, 12, VERDE.lightened(0.45), 1.2, true)
		var presion := float(presiones[indice]) if indice < presiones.size() else 0.0
		_dibujar_boton_fase(lienzo, Vector2(centro.x, 258), fijado, seleccion == indice, maxf(presion, float(fijado)))


func _dibujar_aguja(lienzo: CanvasItem, centro: Vector2, angulo: float) -> void:
	var direccion := Vector2.from_angle(angulo)
	var normal := direccion.orthogonal()
	var contorno := PackedVector2Array([
		centro + direccion * 58,
		centro + direccion * 7 + normal * 6,
		centro - direccion * 17 + normal * 4,
		centro - direccion * 17 - normal * 4,
		centro + direccion * 7 - normal * 6
	])
	var sombra := PackedVector2Array()
	for punto: Vector2 in contorno:
		sombra.append(punto + Vector2(2, 4))
	lienzo.draw_colored_polygon(sombra, Color(TINTA, 0.3))
	lienzo.draw_colored_polygon(contorno, CORAL.darkened(0.12))
	var cerrado := contorno.duplicate()
	cerrado.append(contorno[0])
	lienzo.draw_polyline(cerrado, TINTA, 2, true)
	lienzo.draw_colored_polygon(PackedVector2Array([
		centro + direccion * 53,
		centro + direccion * 9 - normal * 3.5,
		centro - direccion * 14 - normal * 2,
		centro - direccion * 14
	]), CORAL.lightened(0.3))
	lienzo.draw_line(centro - direccion * 13, centro + direccion * 51, CORAL.lightened(0.4), 1.5, true)


func _dibujar_boton_fase(lienzo: CanvasItem, centro: Vector2, fijado: bool, seleccionado: bool, presion: float) -> void:
	var presion_limitada := clampf(presion, 0.0, 1.0)
	var tecla := Rect2(centro - Vector2(27, 13) + Vector2(0, presion_limitada * 4), Vector2(43, 22))
	V.dibujar_placa(lienzo, tecla, VERDE if fijado else CREMA, 4, lerpf(5, 2, presion_limitada))
	lienzo.draw_line(tecla.position + Vector2(8, 7), tecla.position + Vector2(35, 7), TINTA, 2, true)
	if seleccionado:
		lienzo.draw_line(tecla.position + Vector2(6, 1), tecla.position + Vector2(37, 1), CORAL, 3, true)
	var led := centro + Vector2(28, 0)
	V.dibujar_disco(lienzo, led, 7, TINTA, false)
	var color_led := VERDE if fijado else (CORAL if seleccionado else METAL.darkened(0.25))
	lienzo.draw_circle(led, 4.5, color_led, true, -1, true)
	lienzo.draw_arc(led, 3.2, PI * 1.1, PI * 1.8, 12, color_led.lightened(0.45), 1, true)


func _dibujar_terminal(lienzo: CanvasItem, rectangulo: Rect2, color: Color) -> void:
	V.dibujar_placa(lienzo, rectangulo, METAL, 6, 5)
	var cara := Rect2(rectangulo.position + Vector2(5, 4), rectangulo.size - Vector2(10, 9))
	V.dibujar_placa(lienzo, cara, color, 4, 1.5)


func _dibujar_cables(lienzo: CanvasItem) -> void:
	var destinos: Array = _estado.get("destinos", [2, 0, 3, 1])
	var conexiones: Array = _estado.get("conexiones", [-1, -1, -1, -1])
	var avances: Array = _visual.get("conexiones", [])
	var seleccion := int(_visual.get("seleccion", _estado.get("seleccion", -1)))
	var arrastrado := int(_visual.get("cable_arrastrado", -1))
	var destino_seleccionado := int(_visual.get("destino_seleccionado", -1))
	var activo := arrastrado if arrastrado >= 0 else seleccion
	for indice: int in range(4):
		var inicio := Vector2(144, ALTURAS_CABLE[indice])
		var destino := int(conexiones[indice])
		if destino >= 0:
			var avance := float(avances[indice]) if indice < avances.size() else 1.0
			_dibujar_cable(lienzo, inicio, Vector2(594, ALTURAS_CABLE[destino]), COLORES_CABLE[indice], avance)
		elif indice == activo:
			var raton: Vector2 = _visual.get("raton", inicio + Vector2(110, 0))
			var fin := Vector2(594, ALTURAS_CABLE[destino_seleccionado]) if destino_seleccionado >= 0 and arrastrado < 0 else raton
			_dibujar_cable(lienzo, inicio, fin, COLORES_CABLE[indice], 1.0)
			lienzo.draw_circle(fin + Vector2(2, 3), 13, Color(TINTA, 0.45), true, -1, true)
			lienzo.draw_circle(fin, 12, TINTA.darkened(0.2), true, -1, true)
			lienzo.draw_circle(fin, 8.5, CREMA, false, 3, true)
	for indice: int in range(4):
		var y: float = ALTURAS_CABLE[indice]
		_dibujar_conector(lienzo, Vector2(144, y), Vector2(128, y), COLORES_CABLE[indice], -0.7 + indice * 0.23)
		_dibujar_conector(lienzo, Vector2(594, y), Vector2(610, y), COLORES_CABLE[int(destinos[indice])], 0.45 - indice * 0.29)
	if activo >= 0:
		var rectangulo := rect_origen(activo)
		rectangulo.position -= ORIGEN_INTERIOR
		lienzo.draw_rect(rectangulo.grow(3), Color(CREMA, 0.65), false, 2)
	if destino_seleccionado >= 0:
		var rectangulo := rect_destino(destino_seleccionado)
		rectangulo.position -= ORIGEN_INTERIOR
		lienzo.draw_rect(rectangulo.grow(3), Color(CREMA, 0.65), false, 2)
	var error_indice := int(_visual.get("error_indice", -1))
	var error := clampf(float(_visual.get("error", 0.0)), 0.0, 1.0)
	if error_indice >= 0 and error > 0.0:
		var rectangulo := rect_destino(error_indice)
		rectangulo.position -= ORIGEN_INTERIOR
		lienzo.draw_rect(rectangulo.grow(3), Color(CORAL, error), false, 4)


func _dibujar_conector(lienzo: CanvasItem, centro: Vector2, union: Vector2, color: Color, giro: float) -> void:
	V.dibujar_cable(lienzo, PackedVector2Array([union, centro]), color, 9)
	V.dibujar_disco(lienzo, centro, 14, METAL)
	V.dibujar_tornillo(lienzo, centro, 9, giro)


func _dibujar_cable(lienzo: CanvasItem, inicio: Vector2, fin: Vector2, color: Color, avance: float) -> void:
	var avance_limitado := clampf(avance, 0.0, 1.0)
	if avance_limitado <= 0.0 or inicio.is_equal_approx(fin):
		return
	var curva := Curve2D.new()
	var holgura := minf(150.0, inicio.distance_to(fin) * 0.4)
	curva.bake_interval = 3.0
	curva.add_point(inicio, Vector2.ZERO, Vector2(holgura, 0))
	curva.add_point(fin, Vector2(-holgura, 0), Vector2.ZERO)
	var longitud := curva.get_baked_length() * avance_limitado
	var puntos := PackedVector2Array([inicio])
	for paso: int in range(1, ceili(longitud / 4.0)):
		puntos.append(curva.sample_baked(paso * 4.0))
	puntos.append(curva.sample_baked(longitud))
	V.dibujar_cable(lienzo, puntos, color, 9)
