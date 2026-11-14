extends Control
## Máquina 3D aislada sobre la oficina. La lógica de compra vive en el controlador.

signal producto_solicitado(indice: int)
signal recoger_solicitado
signal cerrar_solicitado

const CREMA := Color("fff1d8")
const PETROLEO := Color("173b50")
const CORAL := Color("ff785f")
const METAL := Color("a0b5ba")
const OSCURO := Color("0b2533")
const CODIGOS := ["A1", "A2", "B1", "B2"]
const NOMBRES := ["CHOCOLATE", "DONA", "PAPA TIEMPO", "EL AVATAR"]
const EFECTOS := ["VELOCIDAD · 25 s", "SALTO ALTO · 10 s", "DETIENE EL TIEMPO", "RESUELVE UN EVENTO"]
const FUENTE := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")

var vista: SubViewport
var camara: Camera3D
var botones: Array[Button] = []
var boton_recoger: Button
var _modelo: Node3D
var _productos: Array[Node3D] = []
var _pulsadores: Array[MeshInstance3D] = []
var _etiquetas: Array[Label3D] = []
var _espirales: Array[Node3D] = []
var _pantalla: Label3D
var _saldo: Label3D
var _bandeja: MeshInstance3D
var _indice := -1
var _raton_anterior: Input.MouseMode


func _ready() -> void:
	name = "ExpendedoraPrimeraPersona"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fondo := ColorRect.new()
	fondo.name = "EscenarioTraslucido"
	fondo.color = Color(0.025, 0.06, 0.085, 0.48)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var contenedor := SubViewportContainer.new()
	contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenedor.stretch = true
	add_child(contenedor)
	contenedor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vista = SubViewport.new()
	vista.name = "ObjetoSinFondo"
	vista.own_world_3d = true
	vista.transparent_bg = true
	vista.handle_input_locally = false
	vista.gui_disable_input = true
	vista.msaa_3d = Viewport.MSAA_4X
	contenedor.add_child(vista)
	_modelo = Node3D.new()
	vista.add_child(_modelo)
	camara = Camera3D.new()
	camara.fov = 32.0
	vista.add_child(camara)
	camara.current = true
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_CLEAR_COLOR
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color("dce9ee")
	ambiente.environment.ambient_light_energy = 0.65
	vista.add_child(ambiente)
	for i in 2:
		var luz := DirectionalLight3D.new()
		vista.add_child(luz)
		luz.position = Vector3(-3, 6, 5) if i == 0 else Vector3(4, 4, 2)
		luz.look_at(Vector3(0, 2, 0))
		luz.light_energy = 1.5 if i == 0 else 0.75
		luz.light_color = Color("fff1da") if i == 0 else Color("c5e5ff")
		luz.shadow_enabled = i == 0
	_crear_maquina()
	for i in 4:
		var boton := _boton("Producto%s" % CODIGOS[i], "%s: %s" % [CODIGOS[i], NOMBRES[i]], producto_solicitado.emit.bind(i))
		boton.mouse_entered.connect(_resaltar.bind(i, true))
		boton.mouse_exited.connect(_resaltar.bind(i, false))
		boton.focus_entered.connect(_resaltar.bind(i, true))
		boton.focus_exited.connect(_resaltar.bind(i, false))
		botones.append(boton)
	boton_recoger = _boton("RecogerProducto", "Recoger el producto de la bandeja", recoger_solicitado.emit)
	boton_recoger.hide()
	resized.connect(_ajustar)
	visibility_changed.connect(_actualizar_render)
	hide()
	_ajustar.call_deferred()


func _malla(padre: Node3D, forma: Mesh, posicion: Vector3, color: Color, metal: float = 0.0) -> MeshInstance3D:
	var objeto := MeshInstance3D.new()
	objeto.mesh = forma
	objeto.position = posicion
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = 0.35 if metal > 0 else 0.55
	objeto.material_override = material
	padre.add_child(objeto)
	return objeto


func _caja(padre: Node3D, tamano: Vector3, posicion: Vector3, color: Color, metal: float = 0.0) -> MeshInstance3D:
	var forma := BoxMesh.new()
	forma.size = tamano
	return _malla(padre, forma, posicion, color, metal)


func _letrero(padre: Node3D, texto: String, posicion: Vector3, escala: float, color: Color = PETROLEO) -> Label3D:
	var etiqueta := Label3D.new()
	etiqueta.text = texto
	var fuente := FontVariation.new()
	fuente.base_font = FUENTE
	fuente.variation_embolden = 1.0
	etiqueta.font = fuente
	etiqueta.font_size = 64
	etiqueta.pixel_size = escala
	etiqueta.modulate = color
	etiqueta.outline_size = 0
	etiqueta.position = posicion
	padre.add_child(etiqueta)
	return etiqueta


func _crear_maquina() -> void:
	_caja(_modelo, Vector3(3.1, 0.2, 1.6), Vector3(0, 0.13, 0), PETROLEO)
	_caja(_modelo, Vector3(3.0, 4.1, 0.3), Vector3(0, 2.23, -0.6), PETROLEO)
	_caja(_modelo, Vector3(0.17, 4.05, 1.42), Vector3(-1.42, 2.23, 0), PETROLEO)
	_caja(_modelo, Vector3(0.72, 4.05, 1.42), Vector3(1.14, 2.23, 0), CORAL)
	_caja(_modelo, Vector3(3, 0.43, 1.5), Vector3(0, 4.13, 0), CREMA)
	_letrero(_modelo, "REFUERZOS DE TURNO", Vector3(0, 4.15, 0.762), 0.0025)
	_caja(_modelo, Vector3(2.08, 3.0, 0.05), Vector3(-0.32, 2.4, -0.4), OSCURO)
	for x: float in [-1.3, 0.66]:
		var luz_interior := _caja(_modelo, Vector3(0.035, 2.9, 0.05), Vector3(x, 2.4, 0.25), Color("c8ece3"))
		var mat := luz_interior.material_override as StandardMaterial3D
		mat.emission_enabled = true
		mat.emission = Color("8dbab2")
		mat.emission_energy_multiplier = 0.5
	for y: float in [1.91, 3.12]:
		# El estante termina antes del canal frontal por donde cae el producto.
		_caja(_modelo, Vector3(2.0, 0.08, 0.52), Vector3(-0.32, y, -0.09), METAL, 0.6)
	for i in 4:
		var centro := _origen_producto(i)
		_crear_espiral(centro + Vector3(0, -0.07, -0.45))
		var producto := _crear_producto(i)
		producto.position = centro
		_modelo.add_child(producto)
		_productos.append(producto)
		var y := 3.06 if i < 2 else 1.85
		_caja(_modelo, Vector3(0.94, 0.19, 0.03), Vector3(centro.x, y, 0.25), CREMA)
		_etiquetas.append(_letrero(_modelo, CODIGOS[i], Vector3(centro.x, y, 0.272), 0.00185))
		_letrero(_modelo, NOMBRES[i], Vector3(centro.x, y - 0.21, 0.26), 0.0014, CREMA)
		_letrero(_modelo, EFECTOS[i], Vector3(centro.x, y - 0.36, 0.26), 0.0012, Color("b8d3d5"))
		var boton_y := 2.85 - i * 0.48
		_pulsadores.append(_caja(_modelo, Vector3(0.5, 0.34, 0.09), Vector3(1.14, boton_y, 0.76), CREMA))
		_letrero(_modelo, CODIGOS[i], Vector3(1.14, boton_y, 0.815), 0.0027)
	for x: float in [-1.38, 0.74]:
		_caja(_modelo, Vector3(0.065, 2.65, 0.1), Vector3(x, 2.575, 0.77), METAL, 0.7)
	for y: float in [1.25, 3.9]:
		_caja(_modelo, Vector3(2.18, 0.07, 0.1), Vector3(-0.32, y, 0.77), METAL, 0.7)
	var cristal := _caja(_modelo, Vector3(2.05, 2.56, 0.005), Vector3(-0.32, 2.575, 0.79), Color(0.65, 0.85, 0.91, 0.045))
	(cristal.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cristal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_caja(_modelo, Vector3(2.17, 0.16, 1.36), Vector3(-0.32, 0.39, 0.06), PETROLEO)
	_caja(_modelo, Vector3(2.08, 0.4, 0.05), Vector3(-0.32, 0.65, -0.35), OSCURO)
	_bandeja = _caja(_modelo, Vector3(2.12, 0.08, 0.12), Vector3(-0.32, 0.48, 0.77), METAL, 0.6)
	_letrero(_modelo, "RECOGE AQUÍ", Vector3(-0.32, 0.3, 0.765), 0.0018, CREMA)
	_caja(_modelo, Vector3(0.57, 0.7, 0.08), Vector3(1.14, 3.42, 0.76), OSCURO)
	_caja(_modelo, Vector3(0.49, 0.6, 0.01), Vector3(1.14, 3.42, 0.808), Color("bfd5b4"))
	_saldo = _letrero(_modelo, "0 PTS", Vector3(1.14, 3.57, 0.82), 0.0016)
	_pantalla = _letrero(_modelo, "ELIGE", Vector3(1.14, 3.29, 0.82), 0.0016)
	_caja(_modelo, Vector3(0.35, 0.04, 0.02), Vector3(1.14, 0.95, 0.722), OSCURO)
	_letrero(_modelo, "ESC / E\nSALIR", Vector3(1.14, 0.61, 0.725), 0.0014)


func _crear_espiral(posicion: Vector3) -> void:
	var espiral := Node3D.new()
	espiral.position = posicion
	_modelo.add_child(espiral)
	_espirales.append(espiral)
	for j in 60:
		var a := float(j) / 60.0 * TAU * 3.0
		var b := float(j + 1) / 60.0 * TAU * 3.0
		var inicio := Vector3(cos(a) * 0.15, sin(a) * 0.15, float(j) / 60.0 * 0.38)
		var fin := Vector3(cos(b) * 0.15, sin(b) * 0.15, float(j + 1) / 60.0 * 0.38)
		var tramo := CylinderMesh.new()
		tramo.top_radius = 0.009
		tramo.bottom_radius = 0.009
		tramo.height = inicio.distance_to(fin)
		tramo.radial_segments = 6
		var pieza := _malla(espiral, tramo, (inicio + fin) * 0.5, METAL, 0.65)
		pieza.quaternion = Quaternion(Vector3.UP, (fin - inicio).normalized())


func _crear_producto(indice: int) -> Node3D:
	var producto := Node3D.new()
	match indice:
		0:
			_caja(producto, Vector3(0.38, 0.62, 0.16), Vector3.ZERO, Color("653a28"))
			for x: float in [-0.095, 0.095]:
				for y: float in [0.14, 0.26]:
					_caja(producto, Vector3(0.16, 0.10, 0.035), Vector3(x, y, 0.093), Color("945c3a"))
			_caja(producto, Vector3(0.40, 0.36, 0.18), Vector3(0, -0.13, 0), CORAL)
			_letrero(producto, "CHOCO", Vector3(0, -0.11, 0.098), 0.0014)
		1:
			var dona := TorusMesh.new()
			dona.inner_radius = 0.12
			dona.outer_radius = 0.32
			_malla(producto, dona, Vector3.ZERO, Color("d79c55")).rotation.x = PI / 2.0
			var glaseado := TorusMesh.new()
			glaseado.inner_radius = 0.13
			glaseado.outer_radius = 0.30
			_malla(producto, glaseado, Vector3(0, 0, 0.04), Color("efa6b3")).rotation.x = PI / 2.0
			for j in 10:
				var a := float(j) * 2.4
				var chispa := _caja(producto, Vector3(0.045, 0.016, 0.015), Vector3(cos(a) * 0.22, sin(a) * 0.22, 0.126), CREMA if j % 2 else CORAL)
				chispa.rotation.z = a
		2:
			_caja(producto, Vector3(0.46, 0.59, 0.22), Vector3.ZERO, Color("e9b75e"))
			for y: float in [-0.28, 0.28]:
				_caja(producto, Vector3(0.48, 0.04, 0.18), Vector3(0, y, 0), CREMA)
			_letrero(producto, "PAPA\nTIEMPO", Vector3(0, 0.02, 0.118), 0.0014)
		3:
			var lata := CylinderMesh.new()
			lata.top_radius = 0.22
			lata.bottom_radius = 0.22
			lata.height = 0.54
			lata.radial_segments = 32
			_malla(producto, lata, Vector3.ZERO, Color("80bcb1"), 0.3)
			var tapa := CylinderMesh.new()
			tapa.top_radius = 0.225
			tapa.bottom_radius = 0.225
			tapa.height = 0.035
			_malla(producto, tapa, Vector3(0, 0.28, 0), METAL, 0.7)
			_letrero(producto, "AVATAR", Vector3(0, 0.02, 0.224), 0.0013)
	return producto


func _origen_producto(indice: int) -> Vector3:
	return Vector3(-0.84 if indice % 2 == 0 else 0.20, 3.46 if indice < 2 else 2.25, 0.12)


func _boton(nombre: String, descripcion: String, accion: Callable) -> Button:
	var boton := Button.new()
	boton.name = nombre
	boton.accessibility_name = descripcion
	boton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for estilo: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		boton.add_theme_stylebox_override(estilo, StyleBoxEmpty.new())
	boton.pressed.connect(accion)
	add_child(boton)
	return boton


func _resaltar(indice: int, activo: bool) -> void:
	var mat := _pulsadores[indice].material_override as StandardMaterial3D
	mat.emission_enabled = activo and not botones[indice].disabled
	mat.emission = Color("ffd187")
	mat.emission_energy_multiplier = 0.28


func abrir() -> void:
	_raton_anterior = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cancelar_visual()
	show()
	_ajustar()


func cerrar() -> void:
	if not visible:
		return
	hide()
	_cancelar_visual()
	Input.mouse_mode = _raton_anterior
	if is_inside_tree():
		var foco := get_viewport().gui_get_focus_owner()
		if foco != null and is_ancestor_of(foco):
			foco.release_focus()


func actualizar(saldo: int, precios: Array[int], inventario: Array[int], ocupado: bool) -> void:
	_saldo.text = "%d\nPTS" % saldo
	_saldo.pixel_size = minf(0.0016, 0.44 / maxf(1.0, _saldo.font.get_string_size(str(saldo), HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x))
	for i in 4:
		_etiquetas[i].text = "%s · %s" % [CODIGOS[i], "BOLSILLO" if inventario[i] > 0 else "%d PTS" % precios[i]]
		botones[i].disabled = ocupado or inventario[i] > 0 or saldo < precios[i]
		if botones[i].disabled:
			_resaltar(i, false)


func dispensar(indice: int) -> void:
	_indice = indice
	_pantalla.text = "ESPERA"
	boton_recoger.hide()


func actualizar_caida(avance: float) -> void:
	if _indice < 0:
		return
	var objeto := _productos[_indice]
	var inicio := _origen_producto(_indice)
	_espirales[_indice].rotation.z = minf(1.0, avance / 0.27) * TAU
	_pulsadores[_indice].position.z = 0.76 - sin(minf(avance * 5.0, 1.0) * PI) * 0.045
	if avance < 0.27:
		objeto.position = inicio + Vector3(0, 0, avance / 0.27 * 0.44)
	else:
		var caida := (avance - 0.27) / 0.73
		objeto.position.z = 0.56
		objeto.position.x = lerpf(inicio.x, -0.32, minf(caida * 1.6, 1.0))
		if caida < 0.76:
			objeto.position.y = lerpf(inicio.y, 0.85, pow(caida / 0.76, 2))
		else:
			objeto.position.y = 0.85 + sin((caida - 0.76) / 0.24 * PI) * 0.13
		objeto.rotation.z = caida * 0.4


func listo() -> void:
	actualizar_caida(1.0)
	_pantalla.text = "RETIRA"
	boton_recoger.show()
	boton_recoger.grab_focus()
	var mat := _bandeja.material_override as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = Color("d9ae62")
	mat.emission_energy_multiplier = 0.35


func recogido(indice: int, atajo: String) -> void:
	_cancelar_visual()
	_pantalla.text = "%s\nUSAR %s" % [CODIGOS[indice], atajo]
	for boton: Button in botones:
		if not boton.disabled:
			boton.grab_focus()
			break


func mostrar_error(texto: String) -> void:
	_pantalla.text = texto


func _cancelar_visual() -> void:
	_indice = -1
	boton_recoger.hide()
	_pantalla.text = "ELIGE"
	(_bandeja.material_override as StandardMaterial3D).emission_enabled = false
	for i in 4:
		_productos[i].position = _origen_producto(i)
		_productos[i].rotation = Vector3.ZERO
		_pulsadores[i].position.z = 0.76
		_espirales[i].rotation.z = 0.0


func _actualizar_render() -> void:
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	set_process(visible)
	set_process_input(visible)
	set_process_unhandled_input(visible)


func _ajustar() -> void:
	if not is_instance_valid(camara) or size.y <= 0:
		return
	camara.position = Vector3(0, 2.75, maxf(8.9, 1.9 / (tan(deg_to_rad(16.0)) * size.x / size.y)))
	camara.look_at(Vector3(0, 2.22, 0))
	for i in botones.size():
		_colocar_boton(botones[i], Vector3(1.14, 2.85 - i * 0.48, 0.82), Vector2(0.52, 0.35))
	_colocar_boton(boton_recoger, Vector3(-0.32, 0.85, 0.79), Vector2(1.9, 0.65))


func _colocar_boton(boton: Button, centro: Vector3, medidas: Vector2) -> void:
	if not is_instance_valid(boton):
		return
	var inicio := camara.unproject_position(centro + Vector3(-medidas.x, medidas.y, 0) * 0.5)
	var fin := camara.unproject_position(centro + Vector3(medidas.x, -medidas.y, 0) * 0.5)
	boton.position = inicio
	boton.size = (fin - inicio).max(Vector2(32, 32))


func _process(_delta: float) -> void:
	_ajustar()


func _input(evento: InputEvent) -> void:
	if not visible or get_tree().paused or not evento is InputEventKey:
		return
	var tecla: int = evento.physical_keycode if evento.physical_keycode != 0 else evento.keycode
	if tecla in [KEY_ESCAPE, KEY_E]:
		get_viewport().set_input_as_handled()
		if evento.pressed and not evento.echo:
			cerrar_solicitado.emit()
	elif tecla >= KEY_1 and tecla <= KEY_4:
		get_viewport().set_input_as_handled()
		if evento.pressed and not evento.echo:
			producto_solicitado.emit(tecla - KEY_1)


func _unhandled_input(_evento: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if visible:
		Input.mouse_mode = _raton_anterior
