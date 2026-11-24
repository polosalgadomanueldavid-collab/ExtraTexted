extends SubViewport
## Muestras dibujadas detrás del overlay: no instancian eventos ni sus reglas.
## El primer dibujo prepara variantes básicas, no garantiza todas las variantes.
const SHADERS := [
	"res://Eventos/Apagon/vision_apagon.gdshader",
	"res://Eventos/Incendio/llama.gdshader",
	"res://Eventos/Inundacion/agua.gdshader",
	"res://Eventos/Inundacion/salpicadura.gdshader",
	"res://Eventos/Inundacion/onda.gdshader",
	"res://Eventos/Lava/magma.gdshader",
	"res://Eventos/Hielo/suelo_hielo.gdshader",
	"res://Eventos/Hielo/monticulos_nieve.gdshader",
	"res://Eventos/Hielo/escarcha.gdshader",
	"res://Eventos/Terremoto/aviso_escombro.gdshader",
]

func _ready() -> void:
	size = Vector2i(96, 96)
	own_world_3d = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var camara := Camera3D.new()
	camara.position = Vector3(0, 0, 4)
	add_child(camara)
	camara.current = true
	var luz := DirectionalLight3D.new()
	add_child(luz)

func preparar(oficina: Node = null) -> void:
	for ruta in SHADERS:
		var shader := load(ruta) as Shader
		var material := ShaderMaterial.new()
		material.shader = shader
		var muestra: Node
		if shader.get_mode() == Shader.MODE_CANVAS_ITEM:
			var pantalla := ColorRect.new()
			pantalla.size = Vector2(size)
			pantalla.material = material
			muestra = pantalla
		else:
			var malla := MeshInstance3D.new()
			malla.mesh = SphereMesh.new()
			malla.material_override = material
			muestra = malla
		add_child(muestra)
		await get_tree().process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		muestra.queue_free()
	# Prepara también la malla procedural compartida de fuego y su material.
	var fuego := preload("res://Eventos/Incendio/fuego_3d.gd").new()
	add_child(fuego)
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	# Dibuja las variantes instanciadas reales antes de descubrir la oficina.
	# Es un efecto aislado: no ejecuta gestos, sonido ni restauración del evento.
	var tierra := preload("res://Objetos/ZonaDescanso/macizos_tierra.gd").new()
	add_child(tierra)
	tierra.scale = Vector3.ONE * .45
	tierra.position.y = -.6
	tierra.actualizar(2.25, Vector3(-.3, .6, 0), Vector3(.3, .6, 0), 0.0)
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	tierra.queue_free()
	if is_instance_valid(oficina) and DisplayServer.get_name() != "headless":
		await _preparar_luces_oficina(oficina)
	if is_instance_valid(oficina) and DisplayServer.get_name() != "headless":
		await _preparar_vision_apagon(oficina)

func _preparar_luces_oficina(oficina: Node) -> void:
	# El cargador mantiene la partida pausada y cubierta. Dibujar ambas zonas
	# prepara las combinaciones reales de focos/sombras/materiales en Compatibility,
	# también las que no entran en el encuadre inicial del personaje.
	var camara := oficina.get_node("Gameplay/Camera3D") as Camera3D
	var transformacion := camara.global_transform
	var apertura := camara.fov
	# La muestra aislada no cubre las combinaciones de focos/sombras reales.
	# Preparar también esos programas mientras el overlay todavía cubre la escena.
	var tierra := preload("res://Objetos/ZonaDescanso/macizos_tierra.gd").new()
	oficina.add_child(tierra)
	tierra.actualizar(2.25, Vector3(-.3, .6, 0), Vector3(.3, .6, 0), 0.0)
	camara.fov = 70.0
	for centro in [Vector3(-1, 0.8, 3.4), Vector3(-1, 0.8, 9.0)]:
		tierra.global_position = centro - Vector3.UP * .4
		camara.global_position = centro + Vector3(0, 5, 3.6)
		camara.look_at(centro)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if not is_instance_valid(oficina) or not is_instance_valid(camara):
			return
	camara.global_transform = transformacion
	camara.fov = apertura
	tierra.queue_free()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _preparar_vision_apagon(oficina: Node) -> void:
	# Dibujar también la oficina con sus luces de emergencia reales prepara
	# variantes que la esfera aislada no comparte. Solo presentación: el árbol
	# sigue pausado y no se inicia el evento, sus sonidos, reglas ni relojes.
	var evento: Node = oficina.evento_apagon
	var visibilidades := {}
	for luz: Light3D in evento.luces:
		if is_instance_valid(luz):
			visibilidades[luz] = luz.visible
			luz.hide()
	var luz_emergencia: OmniLight3D = evento.luz_jugador
	var visible_emergencia := luz_emergencia.visible
	var transformacion := luz_emergencia.transform
	var visible_mascara: bool = evento.mascara.visible
	evento._actualizar_vision()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	for luz: Light3D in visibilidades:
		if is_instance_valid(luz):
			luz.visible = visibilidades[luz]
	if is_instance_valid(luz_emergencia):
		luz_emergencia.visible = visible_emergencia
		luz_emergencia.transform = transformacion
	if is_instance_valid(evento):
		evento.mascara.visible = visible_mascara
