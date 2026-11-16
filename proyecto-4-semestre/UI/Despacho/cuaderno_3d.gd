extends Control
## Los controles originales se imprimen en hojas 3D. El puntero se proyecta
## de vuelta al papel para conservar botones, foco y listas desplazables.

signal apertura_terminada

const HOJA := preload("res://UI/Despacho/hoja_cuaderno.gdshader")
const TAMANO := Vector2i(1280, 720)
const DURACION_PAGINA := 0.62

var contenido: Control
var ocupado: bool = false
var acercado: bool = false
var _papel: SubViewport
var _vista: SubViewport
var _libro: Node3D
var _camara: Camera3D
var _hojas: Array[MeshInstance3D] = []
var _materiales: Array[ShaderMaterial] = []
var _hoja_movil: MeshInstance3D
var _material_movil: ShaderMaterial
var _animacion: Tween
var _animacion_zoom: Tween
var _entrada: float = 1.0
var _zoom: float = 0.0
var _centro_zoom := Vector2.ZERO
var _puntero := Vector2.ZERO
var _ultimo_papel := Vector2(-100, -100)
var _balanceo := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_papel = SubViewport.new()
	_papel.name = "ContenidoImpreso"
	_papel.size = TAMANO * 2
	_papel.size_2d_override = TAMANO
	_papel.size_2d_override_stretch = true
	_papel.transparent_bg = true
	_papel.disable_3d = true
	_papel.gui_disable_input = false
	_papel.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_papel)
	contenido = Control.new()
	contenido.size = TAMANO
	contenido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_papel.add_child(contenido)
	_vista = SubViewport.new()
	_vista.name = "VolumenCuaderno"
	_vista.own_world_3d = true
	_vista.transparent_bg = true
	_vista.msaa_3d = Viewport.MSAA_2X
	_vista.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vista)
	var imagen := TextureRect.new()
	imagen.texture = _vista.get_texture()
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(imagen)
	_libro = Node3D.new()
	_vista.add_child(_libro)
	_camara = Camera3D.new()
	_camara.fov = 28.0
	_camara.near = 0.1
	_vista.add_child(_camara)
	_camara.make_current()
	var entorno := WorldEnvironment.new()
	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = Color(0, 0, 0, 0)
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color("c8d6df")
	ambiente.ambient_light_energy = 0.65
	ambiente.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	entorno.environment = ambiente
	_vista.add_child(entorno)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-28, -32, 0)
	luz.light_energy = 1.1
	_vista.add_child(luz)
	_construir_volumen()
	resized.connect(_ajustar)
	visibility_changed.connect(_actualizar_visibilidad)
	_ajustar()
	_actualizar_visibilidad()


func _construir_volumen() -> void:
	var cubierta := _material(Color("d4833d"))
	var canto := _material(Color("d2cfc3"))
	var linea_canto := _material(Color("aca99f"))
	var metal := _material(Color("aebec5"), 0.5, 0.23)
	for lado: int in [-1, 1]:
		_caja(Vector3(lado * 2.88, 0.10, -0.19), Vector3(5.72, 6.27, 0.07), cubierta)
		_caja(Vector3(lado * 2.88, 0.08, -0.05), Vector3(5.56, 6.16, 0.16), canto)
		for capa: int in range(4):
			_caja(Vector3(lado * 2.88, -3.002, -0.11 + capa * 0.038), Vector3(5.54, 0.003, 0.004), linea_canto)
		var material := ShaderMaterial.new()
		material.shader = HOJA
		material.set_shader_parameter("lado", float(lado))
		material.set_shader_parameter("frente", _papel.get_texture())
		material.set_shader_parameter("reverso", _papel.get_texture())
		var hoja := MeshInstance3D.new()
		hoja.mesh = _malla_hoja(lado)
		hoja.material_override = material
		hoja.custom_aabb = AABB(Vector3(-7, -4, -0.5), Vector3(14, 8, 8))
		_libro.add_child(hoja)
		_hojas.append(hoja)
		_materiales.append(material)
	for indice: int in range(32):
		var anillo := MeshInstance3D.new()
		var toro := TorusMesh.new()
		toro.inner_radius = 0.22
		toro.outer_radius = 0.266
		toro.rings = 24
		toro.ring_segments = 8
		anillo.mesh = toro
		anillo.material_override = metal
		anillo.position = Vector3(0, 2.85 - indice * 0.185, 0.13)
		anillo.scale = Vector3(1, 1, 0.90)
		anillo.rotation.z = deg_to_rad(-7)
		_libro.add_child(anillo)
	_material_movil = ShaderMaterial.new()
	_material_movil.shader = HOJA
	_material_movil.set_shader_parameter("pasando", true)
	_hoja_movil = MeshInstance3D.new()
	_hoja_movil.material_override = _material_movil
	_hoja_movil.custom_aabb = AABB(Vector3(-7, -4, -0.5), Vector3(14, 8, 8))
	_hoja_movil.hide()
	_libro.add_child(_hoja_movil)


func _malla_hoja(lado: int) -> ArrayMesh:
	var superficie := SurfaceTool.new()
	superficie.begin(Mesh.PRIMITIVE_TRIANGLES)
	for fila: int in range(9):
		for columna: int in range(49):
			var uv := Vector2(float(columna) / 48.0, float(fila) / 8.0)
			superficie.set_uv(uv)
			superficie.set_normal(Vector3.FORWARD)
			superficie.add_vertex(Vector3(lado * uv.x * 6.4, 3.6 - uv.y * 7.2, 0.0))
	for fila: int in range(8):
		for columna: int in range(48):
			var a := fila * 49 + columna
			var triangulos := [a, a + 1, a + 49, a + 1, a + 50, a + 49]
			if lado == -1:
				triangulos = [a, a + 49, a + 1, a + 1, a + 49, a + 50]
			for indice: int in triangulos:
				superficie.add_index(indice)
	return superficie.commit()


func _material(color: Color, metalico: float = 0.0, rugosidad: float = 0.8) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metalico
	material.roughness = rugosidad
	return material


func _caja(posicion: Vector3, medidas: Vector3, material: Material) -> void:
	var instancia := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = medidas
	instancia.mesh = caja
	instancia.material_override = material
	instancia.position = posicion
	_libro.add_child(instancia)


func _ajustar() -> void:
	if not is_instance_valid(_vista):
		return
	# Limita el coste en pantallas 4K; el papel conserva su textura de 2560 x 1440.
	var escala := minf(1.0, 1920.0 / maxf(size.x, 1.0))
	_vista.size = Vector2i((size * escala).max(Vector2.ONE))
	_actualizar_pose(0.0)


func _actualizar_visibilidad() -> void:
	var activo := is_visible_in_tree()
	set_process(activo)
	_papel.render_target_update_mode = SubViewport.UPDATE_ALWAYS if activo else SubViewport.UPDATE_DISABLED
	_vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS if activo else SubViewport.UPDATE_DISABLED


func abrir() -> void:
	show()
	ocupado = true
	acercado = false
	_zoom = 0.0
	_entrada = 0.0
	_animacion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_animacion.tween_property(self, "_entrada", 1.0, 0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_animacion.finished.connect(func() -> void:
		ocupado = false
		apertura_terminada.emit()
	)


func fotografiar() -> Texture2D:
	if DisplayServer.get_name() == "headless":
		return _papel.get_texture()
	return ImageTexture.create_from_image(_papel.get_texture().get_image())


func congelar_paginas(foto: Texture2D) -> void:
	for material: ShaderMaterial in _materiales:
		material.set_shader_parameter("frente", foto)


func pasar_pagina(anterior: Texture2D, siguiente: Texture2D, direccion: int, origen: int, destino: int) -> void:
	ocupado = true
	var movil := 1 if direccion > 0 else 0
	_materiales[movil].set_shader_parameter("frente", siguiente)
	_materiales[1 - movil].set_shader_parameter("frente", anterior)
	_material_movil.set_shader_parameter("frente", anterior)
	_material_movil.set_shader_parameter("reverso", siguiente)
	_material_movil.set_shader_parameter("lado", float(direccion))
	_material_movil.set_shader_parameter("giro", 0.0)
	_material_movil.set_shader_parameter("pestana_desde", mini(origen, destino) + 1)
	_material_movil.set_shader_parameter("pestana_hasta", maxi(origen, destino))
	_hoja_movil.mesh = _hojas[movil].mesh
	_hoja_movil.show()
	_animacion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_animacion.tween_method(_girar_hoja, 0.0, 1.0, DURACION_PAGINA).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _animacion.finished
	_hoja_movil.hide()
	for material: ShaderMaterial in _materiales:
		material.set_shader_parameter("frente", _papel.get_texture())
		material.set_shader_parameter("sombra", 0.0)
	# Libera las fotografías: nunca se conservan capturas de turnos anteriores.
	_material_movil.set_shader_parameter("frente", null)
	_material_movil.set_shader_parameter("reverso", null)
	ocupado = false


func _girar_hoja(progreso: float) -> void:
	_material_movil.set_shader_parameter("giro", progreso)
	for material: ShaderMaterial in _materiales:
		material.set_shader_parameter("sombra", sin(progreso * PI))


func _process(delta: float) -> void:
	_actualizar_pose(delta)


func _actualizar_pose(delta: float) -> void:
	var ajustes := get_node_or_null("/root/AjustesAccesibilidad")
	var balanceo_permitido: bool = ajustes == null or ajustes.balanceo_camara
	var objetivo := _puntero if balanceo_permitido and not ocupado else Vector2.ZERO
	_balanceo = _balanceo.lerp(objetivo, 1.0 - exp(-delta * 7.0))
	_libro.rotation_degrees = Vector3(-13.0 + _balanceo.y * 1.2 + (1.0 - _entrada) * 48.0, _balanceo.x * 2.0, -0.65 - _balanceo.x * 0.35)
	_libro.position = Vector3(0.0, -0.1 - (1.0 - _entrada) * 6.5, -1.0 * (1.0 - _entrada))
	var aspecto := maxf(size.x / maxf(size.y, 1.0), 0.1)
	var alto := maxf(8.15, 13.8 / aspecto)
	var distancia := alto * 0.5 / tan(deg_to_rad(_camara.fov * 0.5))
	_camara.position = Vector3(_centro_zoom.x * _zoom, _centro_zoom.y * _zoom, distancia * lerpf(1.0, 0.62, _zoom))


func alternar_zoom(punto: Vector2 = Vector2(640, 360)) -> void:
	if ocupado:
		return
	acercado = not acercado
	if acercado:
		_centro_zoom = Vector2(clampf((punto.x - 640.0) / 100.0, -2.8, 2.8), clampf((360.0 - punto.y) / 100.0, -1.3, 1.3))
	if is_instance_valid(_animacion_zoom):
		_animacion_zoom.kill()
	_animacion_zoom = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_animacion_zoom.tween_property(self, "_zoom", 1.0 if acercado else 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func proyectar_papel(punto: Vector2) -> Vector2:
	var u := absf(punto.x - 640.0) / 640.0
	var local := Vector3((punto.x - 640.0) / 100.0, (360.0 - punto.y) / 100.0, 0.10 + 0.12 * sin(u * PI))
	return _camara.unproject_position(_libro.to_global(local)) * size / Vector2(_vista.size)


func _posicion_en_papel(punto: Vector2) -> Vector2:
	var pantalla := punto * Vector2(_vista.size) / size.max(Vector2.ONE)
	var origen := _libro.to_local(_camara.project_ray_origin(pantalla))
	var direccion := _libro.global_basis.inverse() * _camara.project_ray_normal(pantalla)
	if absf(direccion.z) < 0.0001:
		return Vector2(-100, -100)
	# Tres iteraciones resuelven la pequeña curvatura de la hoja en reposo.
	var z := 0.16
	var interseccion := Vector3.ZERO
	for paso: int in range(3):
		interseccion = origen + direccion * ((z - origen.z) / direccion.z)
		z = 0.10 + 0.12 * sin(clampf(absf(interseccion.x) / 6.4, 0, 1) * PI)
	return Vector2(interseccion.x * 100.0 + 640.0, 360.0 - interseccion.y * 100.0)


func _gui_input(evento: InputEvent) -> void:
	if not evento is InputEventMouse:
		return
	var raton := evento as InputEventMouse
	_puntero = (raton.position / size.max(Vector2.ONE) - Vector2(0.5, 0.5)) * 2.0
	var punto := _posicion_en_papel(raton.position)
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_RIGHT:
		if evento.pressed:
			alternar_zoom(punto)
		accept_event()
		return
	if ocupado:
		accept_event()
		return
	var copia := evento.duplicate() as InputEventMouse
	copia.position = punto
	copia.global_position = punto
	if copia is InputEventMouseMotion:
		copia.relative = punto - _ultimo_papel
	_ultimo_papel = punto
	_papel.push_input(copia, true)
	var control := _papel.gui_get_hovered_control()
	mouse_default_cursor_shape = control.mouse_default_cursor_shape if is_instance_valid(control) else Control.CURSOR_ARROW
	accept_event()


func enviar_tecla(evento: InputEventKey) -> void:
	if not ocupado or not evento.pressed:
		_papel.push_input(evento, true)
