extends Control
## Medallones del inventario y café. Solo observa: las acciones siguen en sus controladores.
const FUENTE := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const ICONOS := [preload("res://UI/Descanso/Arte/chocolate.png"), preload("res://UI/Descanso/Arte/dona.png"), preload("res://UI/Descanso/Arte/papa_tiempo.svg"), preload("res://UI/Descanso/Arte/avatar_piedra.png"), preload("res://UI/Descanso/Arte/cafe.png")]
const TECLAS := ["Z · USAR", "X · USAR", "V · USAR", "N · USAR", "F · BEBER"]
const MANDO := ["LB · USAR", "RB · USAR", "LT · USAR", "RT · USAR", "F · BEBER"]
const TINTA := Color("182a3d")
const CREMA := Color("e5ebf0")
const CORAL := Color("c8974c")
const MENTA := Color("79bbca")
const SOMBRA := Color("0d2736aa")
var oficina: Node3D
var entradas: Array[Dictionary] = []
var _firma := ""
var _leyenda: StyleBoxFlat
var _sombra: StyleBoxFlat
var _cantidad: StyleBoxFlat

func _ready() -> void:
	name = "IndicadorBolsillo"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Permite ocultarlo al abrir pausa/ayuda. No avanza ningún reloj propio.
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_leyenda = _estilo(TINTA, CREMA, 2, 9)
	_sombra = _estilo(SOMBRA, SOMBRA, 0, 9)
	_cantidad = _estilo(CREMA, TINTA, 2, 8)
	hide()

func configurar(mundo: Node3D) -> void:
	oficina = mundo
	actualizar()

func _process(_delta: float) -> void:
	actualizar()

func actualizar() -> void:
	if not is_instance_valid(oficina) or not is_instance_valid(oficina.jugador):
		hide()
		return
	var maquina = oficina.get_node_or_null("MaquinaExpendedora")
	var descanso = oficina.get_node_or_null("ZonaDescanso")
	var jugador = oficina.jugador
	entradas.clear()
	if is_instance_valid(maquina) and is_instance_valid(maquina.poderes):
		var tiempos: Array[float] = [jugador.chocolate_restante, jugador.dona_restante, maquina.poderes.restante, 0.0]
		var duraciones := [25.0, 10.0, 12.0, 1.0]
		for i in 4:
			var cantidad: int = maquina.inventario[i]
			if cantidad <= 0 and tiempos[i] <= 0:
				continue
			var etiqueta: String = MANDO[i] if ControladorInterfaz.dispositivo_mando >= 0 else TECLAS[i]
			var estado := "listo"
			if tiempos[i] > 0:
				etiqueta = "%d s" % ceili(tiempos[i])
				estado = "activo"
			elif maquina._pendiente == i:
				etiqueta = "USANDO"
				estado = "usando"
			elif i == 3 and maquina.poderes.evento_actual() == null:
				etiqueta = "SIN EVENTO"
				estado = "espera"
			entradas.append({"id": i, "cantidad": cantidad, "etiqueta": etiqueta, "estado": estado, "progreso": clampf(tiempos[i] / duraciones[i], 0, 1)})
	if is_instance_valid(descanso) and descanso.tiene_cafe():
		var bebiendo: bool = descanso.obtener_estado().bebiendo
		entradas.append({"id": 4, "cantidad": 1, "etiqueta": "BEBIENDO" if bebiendo else TECLAS[4], "estado": "usando" if bebiendo else "listo", "progreso": 0.0})
	visible = not entradas.is_empty() and not _interfaz_ocupada(maquina, descanso)
	ajustar_pantalla(get_viewport().get_visible_rect().size)
	# El aro necesita redibujarse durante los efectos; el inventario en reposo no.
	var firma := str(entradas)
	if firma != _firma:
		_firma = firma
		queue_redraw()

func _interfaz_ocupada(maquina: Node, descanso: Node) -> bool:
	if get_tree().paused or MenuGlobal.capa.visible or oficina.partida_finalizada or oficina.computador.is_using:
		return true
	for interfaz: Node in [oficina.clasificacion_partida, oficina.clasificador_evidencias, oficina.escaner_verificacion, oficina.depurador_recursos]:
		if is_instance_valid(interfaz) and interfaz.visible:
			return true
	if is_instance_valid(maquina) and is_instance_valid(maquina.panel) and maquina.panel.visible:
		return true
	if is_instance_valid(descanso) and is_instance_valid(descanso.panel_cafetera) and descanso.panel_cafetera.visible:
		return true
	return oficina.evento_apagon.estado == 2 or oficina.evento_inundacion.reparando or oficina.evento_hielo.reparando

func ajustar_pantalla(pantalla: Vector2) -> void:
	var factor := minf(pantalla.x / 1280.0, pantalla.y / 720.0)
	scale = Vector2.ONE * factor
	var con_papel: bool = is_instance_valid(oficina) and is_instance_valid(oficina.indicador_papel) and oficina.indicador_papel.visible
	position = Vector2((192.0 if con_papel else 24.0) * factor, pantalla.y - 200.0 * factor)
	size = Vector2(maxf(80, entradas.size() * 96 - 16), 176)

func _estilo(color: Color, borde: Color, grosor: int, radio: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.border_color = borde
	estilo.set_border_width_all(grosor)
	estilo.set_corner_radius_all(radio)
	return estilo

func _draw() -> void:
	if entradas.is_empty():
		return
	draw_string(FUENTE, Vector2(0, 15), "REFUERZOS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, CREMA)
	for numero in entradas.size():
		var entrada := entradas[numero]
		var x := float(numero * 96)
		var centro := Vector2(x + 40, 68)
		var activo: bool = entrada.estado in ["activo", "usando"]
		draw_circle(centro + Vector2(0, 5), 39, SOMBRA, true, -1, true)
		draw_circle(centro, 39, TINTA, true, -1, true)
		draw_circle(centro, 35, MENTA if activo else CORAL, true, -1, true)
		draw_circle(centro - Vector2(0, 2), 31, CREMA, true, -1, true)
		draw_circle(centro, 25, Color("eddec5"), true, -1, true)
		draw_arc(centro - Vector2(0, 2), 29, PI * 1.1, PI * 1.72, 32, Color("fffaf0"), 2, true)
		draw_texture_rect(ICONOS[entrada.id], Rect2(centro - Vector2.ONE * 31.5, Vector2.ONE * 63), false)
		if entrada.estado == "activo":
			draw_arc(centro, 38, -PI/2, -PI/2 + TAU * entrada.progreso, 64, MENTA, 4, true)
		if entrada.cantidad > 0 and entrada.estado != "usando":
			draw_style_box(_cantidad, Rect2(x + 54, 30, 24, 22))
			draw_string(FUENTE, Vector2(x + 54, 47), str(entrada.cantidad), HORIZONTAL_ALIGNMENT_CENTER, 24, 15, TINTA)
		draw_style_box(_sombra, Rect2(x, 119, 80, 28))
		draw_style_box(_leyenda, Rect2(x, 115, 80, 28))
		var tamano := 13 if entrada.etiqueta.length() > 8 else 16
		draw_string(FUENTE, Vector2(x, 136), entrada.etiqueta, HORIZONTAL_ALIGNMENT_CENTER, 80, tamano, MENTA if activo else CREMA)
		if entrada.estado == "espera":
			draw_string(FUENTE, Vector2(x, 162), "N · AVATAR", HORIZONTAL_ALIGNMENT_CENTER, 80, 12, CREMA)
