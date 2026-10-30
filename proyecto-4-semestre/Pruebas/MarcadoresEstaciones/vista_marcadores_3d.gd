extends Node3D
## F6 muestra las cinco mallas reales. -- --capturas guarda una imagen y sale.

const INDICADOR := preload("res://Scripts/indicador_proxima_estacion.gd")
const FUENTE := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const ESTACIONES := ["evidencias", "verificacion", "privacidad", "reporte", "bienestar"]
const NOMBRES := ["EVIDENCIAS", "VERIFICACIÓN", "PRIVACIDAD", "REPORTE", "BIENESTAR"]
const POSICIONES := [Vector2(-1.22, 0.45), Vector2(0, 0.45), Vector2(1.22, 0.45), Vector2(-0.63, -0.65), Vector2(0.63, -0.65)]

var _camara: Camera3D
var _titulo: Label
var _etiquetas: Array[Label] = []


func _ready() -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	var entorno := WorldEnvironment.new()
	entorno.environment = Environment.new()
	entorno.environment.background_mode = Environment.BG_COLOR
	entorno.environment.background_color = Color("173b50")
	entorno.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.environment.ambient_light_color = Color("dcebf2")
	entorno.environment.ambient_light_energy = 0.18
	entorno.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(entorno)
	var camara := Camera3D.new()
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.size = 2.5
	camara.position.z = 6.0
	add_child(camara)
	camara.make_current()
	_camara = camara
	for giro: Vector3 in [Vector3(-30, -25, 0), Vector3(15, 35, 0)]:
		var luz := DirectionalLight3D.new()
		luz.rotation_degrees = giro
		luz.light_energy = 0.65 if giro.x < 0 else 0.15
		add_child(luz)
	var capa := CanvasLayer.new()
	add_child(capa)
	var titulo := _etiqueta("MARCADORES 3D · EXTRA TEXTED", 34)
	titulo.position = Vector2(0, 12)
	capa.add_child(titulo)
	_titulo = titulo
	for indice: int in range(ESTACIONES.size()):
		var marcador := INDICADOR.new() as IndicadorProximaEstacion
		marcador.alto_maximo_pantalla = 0.36
		marcador.configurar(ESTACIONES[indice], NOMBRES[indice])
		marcador.position = Vector3(POSICIONES[indice].x, POSICIONES[indice].y, 0)
		add_child(marcador)
		marcador.establecer_activo(true)
		if "--interactuables" in OS.get_cmdline_user_args():
			marcador.establecer_interactuable(true)
		var etiqueta := _etiqueta(NOMBRES[indice], 22)
		capa.add_child(etiqueta)
		etiqueta.size.x = 280
		_etiquetas.append(etiqueta)
	get_viewport().size_changed.connect(_acomodar_etiquetas)
	call_deferred("_capturar")


func _acomodar_etiquetas() -> void:
	_titulo.size.x = get_viewport().get_visible_rect().size.x
	for indice: int in range(_etiquetas.size()):
		var punto := Vector3(POSICIONES[indice].x, POSICIONES[indice].y - 0.49, 0)
		_etiquetas[indice].position = _camara.unproject_position(punto) - Vector2(140, 0)


func _etiqueta(texto: String, tamano: int) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_override("font", FUENTE)
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", Color("fff1d8"))
	return etiqueta


func _capturar() -> void:
	for cuadro: int in range(8):
		await get_tree().process_frame
	_acomodar_etiquetas()
	if DisplayServer.get_name() == "headless":
		get_tree().quit()
	elif "--capturas" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var directorio := "res://.godot/marcadores_qa"
		DirAccess.make_dir_recursive_absolute(directorio)
		var nombre := "01_galeria_interactuable.png" if "--interactuables" in OS.get_cmdline_user_args() else "00_galeria_3d.png"
		get_viewport().get_texture().get_image().save_png(directorio.path_join(nombre))
		get_tree().quit()
