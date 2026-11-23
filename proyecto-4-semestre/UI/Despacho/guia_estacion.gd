extends Control
## Una tecla junto al símbolo, únicamente cuando la interacción está disponible.

@onready var tarjeta: PanelContainer = $Tecla
@onready var tecla: Label = $Tecla/Letra
var objetivo: IndicadorProximaEstacion


func establecer_objetivo(nuevo: IndicadorProximaEstacion) -> void:
	objetivo = nuevo
	if not is_instance_valid(objetivo):
		hide()


func actualizar(barra_despacho: Control, ocupado: bool) -> void:
	var camara := get_viewport().get_camera_3d()
	if ocupado or not is_instance_valid(objetivo) or not objetivo.visible or not objetivo.interactuable or not is_instance_valid(camara) or camara.is_position_behind(objetivo.global_position):
		hide()
		return
	tecla.text = "X" if ControladorInterfaz.dispositivo_mando >= 0 else "E"
	var factor := clampf(minf(size.x / 1280.0, size.y / 720.0), .65, 1.1)
	tarjeta.scale = Vector2.ONE * factor
	tarjeta.size = tarjeta.get_combined_minimum_size()
	var ancla := camara.unproject_position(objetivo.global_position)
	var lado := minf(size.y * .065, 42.0 * factor)
	var posicion := ancla + Vector2(lado, -tarjeta.size.y * factor * .5)
	var rectangulo := Rect2(posicion, tarjeta.size * factor).grow(6.0)
	var pantalla := Rect2(Vector2.ONE * 10, size - Vector2.ONE * 20)
	if not pantalla.encloses(rectangulo) or (barra_despacho.is_visible_in_tree() and barra_despacho.get_global_rect().intersects(rectangulo)):
		hide()
		return
	tarjeta.position = posicion
	show()
