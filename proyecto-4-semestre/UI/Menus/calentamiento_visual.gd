extends SubViewport
## Muestras dibujadas detrás del overlay: no instancian eventos ni sus reglas.
## El primer dibujo prepara variantes básicas, no garantiza todas las variantes.
const SHADERS := [
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

func preparar() -> void:
	for ruta in SHADERS:
		var shader := load(ruta) as Shader
		if shader.get_mode() != Shader.MODE_SPATIAL:
			continue
		var muestra := MeshInstance3D.new()
		muestra.mesh = SphereMesh.new()
		var material := ShaderMaterial.new()
		material.shader = shader
		muestra.material_override = material
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
