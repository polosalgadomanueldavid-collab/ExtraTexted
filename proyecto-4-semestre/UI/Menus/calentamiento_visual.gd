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
	if is_instance_valid(oficina) and DisplayServer.get_name() != "headless":
		await _preparar_vision_apagon(oficina)

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
