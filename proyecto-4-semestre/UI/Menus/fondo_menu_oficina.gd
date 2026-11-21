extends Control
## Fondo 3D independiente: la interfaz y los botones siguen en MainMenu.tscn.

const OFICINA := preload("res://UI/Menus/oficina_menu_animada.gd")
const DEGRADADO := preload("res://UI/Menus/degradado_oficina_menu.gdshader")

var degradado: ColorRect
var escenario: Node3D
var vista: SubViewport
var _calidad := -1
var _discusion_activa := false


func _ready() -> void:
	var contenedor := SubViewportContainer.new()
	contenedor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	contenedor.stretch = true
	contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(contenedor)
	vista = SubViewport.new()
	vista.own_world_3d = true
	vista.size = Vector2i(1280, 720)
	vista.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	contenedor.add_child(vista)
	escenario = OFICINA.new()
	vista.add_child(escenario)
	degradado = ColorRect.new()
	degradado.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	degradado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = DEGRADADO
	degradado.material = material
	add_child(degradado)
	resized.connect(_ajustar_camara)
	visibility_changed.connect(_actualizar_visibilidad)
	_ajustar_camara()
	_actualizar_calidad()


func _process(_delta: float) -> void:
	if _calidad != CalidadVisual.nivel:
		_actualizar_calidad()


func _actualizar_calidad() -> void:
	_calidad = CalidadVisual.nivel
	vista.scaling_3d_scale = CalidadVisual.ESCALAS[_calidad]
	vista.positional_shadow_atlas_size = 4096 if _calidad == 2 else 2048
	vista.msaa_3d = Viewport.MSAA_4X if _calidad == 2 else Viewport.MSAA_2X if _calidad == 1 else Viewport.MSAA_DISABLED
	escenario.configurar_calidad(_calidad)


func _ajustar_camara() -> void:
	if not is_instance_valid(escenario):
		return
	# Conserva la composición aprobada también en ventanas 4:3.
	var proporcion := size.x / maxf(size.y, 1.0)
	var apertura := tan(deg_to_rad(39.0)*0.5)*maxf(1.0,(16.0/9.0)/proporcion)
	escenario.camara.fov = rad_to_deg(2.0*atan(apertura))


func _actualizar_visibilidad() -> void:
	if is_instance_valid(escenario):
		escenario.process_mode = Node.PROCESS_MODE_INHERIT if is_visible_in_tree() else Node.PROCESS_MODE_DISABLED


func establecer_discusion(activa: bool) -> void:
	_discusion_activa = activa


func gesticular(indice: int) -> void:
	if _discusion_activa:
		escenario.gesticular(indice)
