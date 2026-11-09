extends SceneTree
## Ejecutar sin --headless, con --path proyecto-4-semestre y --script este archivo.
## Genera una sola textura desde el modelo real; el HUD no necesita una cámara 3D.

const MODELOS := preload("res://MarcadoresEstaciones/modelos_marcador.gd")
const SALIDA := "res://UI/Despacho/Arte/papel_medallon.png"


func _initialize() -> void:
	_renderizar.call_deferred()


func _renderizar() -> void:
	var vista := SubViewport.new()
	vista.size = Vector2i(384, 384)
	vista.transparent_bg = true
	vista.own_world_3d = true
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vista)
	var entorno := WorldEnvironment.new()
	entorno.environment = Environment.new()
	entorno.environment.background_mode = Environment.BG_COLOR
	entorno.environment.background_color = Color.TRANSPARENT
	entorno.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.environment.ambient_light_color = Color.WHITE
	entorno.environment.ambient_light_energy = 0.65
	vista.add_child(entorno)
	var camara := Camera3D.new()
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.size = 0.88
	camara.position = Vector3(0, 0, 3)
	vista.add_child(camara)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-25, -30, 0)
	luz.light_energy = 1.2
	vista.add_child(luz)
	var modelo := MODELOS.crear("reporte")
	modelo.rotation_degrees = Vector3(4, -18, -7)
	vista.add_child(modelo)
	for i: int in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(SALIDA.get_base_dir())
	var error := vista.get_texture().get_image().save_png(SALIDA)
	print("Papel del HUD: ", error_string(error))
	quit(error)
