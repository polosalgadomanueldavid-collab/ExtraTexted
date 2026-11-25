extends Control
## Una silueta local y una acción, ambas sobre el mismo objetivo de E.
const CONTORNO := preload("res://UI/Despacho/contorno_objetivo.gdshader")
@onready var tarjeta: PanelContainer = $Tecla
@onready var tecla: Label = $Tecla/Letra
var objetivo: Node3D
var _accion := ""
var _altura := 0.0
var _mantener := false
var _material := ShaderMaterial.new()
var _originales: Array[MeshInstance3D] = []
var _siluetas: Array[MeshInstance3D] = []


func _ready() -> void:
	_material.shader = CONTORNO


func establecer_objetivo(modelo: Node3D, accion := "", altura := 0.0, mantener := false) -> void:
	_accion = accion
	_altura = altura
	_mantener = mantener
	if is_instance_valid(objetivo) and modelo == objetivo:
		return
	if modelo == null and _originales.is_empty():
		objetivo = null
		hide()
		return

	objetivo = modelo
	_originales.clear()
	for silueta in _siluetas:
		silueta.hide()
	if modelo == null:
		hide()
		return
	if modelo is MeshInstance3D and modelo.mesh != null:
		_originales.append(modelo)
	else:
		for pieza: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
			if pieza.mesh != null:
				_originales.append(pieza)
	# Reutilizar las mallas sin cambiar los materiales (incluida la escarcha).
	for i in _originales.size():
		if i == _siluetas.size():
			var copia := MeshInstance3D.new()
			copia.material_override = _material
			copia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(copia)
			_siluetas.append(copia)
		_siluetas[i].mesh = _originales[i].mesh


func actualizar(barra_despacho: Control) -> void:
	var camara := get_viewport().get_camera_3d()
	if not is_instance_valid(objetivo) or not objetivo.is_visible_in_tree() or not is_instance_valid(camara):
		establecer_objetivo(null)
		return
	for i in _originales.size():
		var pieza := _originales[i]
		var copia := _siluetas[i]
		copia.visible = is_instance_valid(pieza) and pieza.is_visible_in_tree()
		if copia.visible:
			copia.global_transform = pieza.global_transform
	var punto := objetivo.global_position + Vector3.UP * _altura
	show()
	if camara.is_position_behind(punto) or _accion.is_empty():
		tarjeta.hide()
		return
	var boton := "X" if ControladorInterfaz.dispositivo_mando >= 0 else "E"
	if OS.has_feature("mobile") and ControladorInterfaz.dispositivo_mando < 0:
		boton = "Usar"
	if _mantener:
		boton = "Mantener " + boton
	tecla.text = "%s · %s" % [boton, _accion]
	var factor := clampf(minf(size.x / 1280.0, size.y / 720.0), .65, 1.1)
	tarjeta.scale = Vector2.ONE * factor
	tarjeta.size = tarjeta.get_combined_minimum_size()
	var ancla := camara.unproject_position(punto)
	var dimensiones := tarjeta.size * factor
	var lado := 28.0 * factor
	var pantalla := Rect2(Vector2.ONE * 6, size - Vector2.ONE * 12)
	if not pantalla.has_point(ancla):
		tarjeta.hide()
		return
	for x: float in [ancla.x + lado, ancla.x - lado - dimensiones.x]:
		var rect := Rect2(Vector2(x, ancla.y - dimensiones.y * .5), dimensiones)
		if pantalla.encloses(rect) and not (barra_despacho.is_visible_in_tree() and barra_despacho.get_global_rect().intersects(rect)):
			tarjeta.position = rect.position
			tarjeta.show()
			return
	tarjeta.hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and is_node_ready():
		establecer_objetivo(null)
