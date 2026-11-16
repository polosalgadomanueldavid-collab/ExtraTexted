extends CanvasLayer
## Único propietario de las transiciones. La generación invalida continuaciones
## pendientes cuando se cancela, se desconecta o se abre otra ronda.
signal fase_cambiada(fase: String, progreso: float)
signal terminada(ruta: String)
signal fallo(mensaje: String)

const OFICINA := "res://Mundo/Oficina.tscn"
const MENU := "res://UI/Menus/MainMenu.tscn"
var activa := false
var progreso := 0.0
var fase := ""
var mediciones := {}
var _ruta := ""
var _generacion := 0
var _instancia: Node
var _escena_preparandose: Node
var _fase := ""
var _cuadros := 0
var _inicio := 0
var _inicio_fase := 0
var _limite := 0
var _fondo: ColorRect
var _texto: Label
var _barra: ProgressBar
var _cancelar: Button
var _precargas := {}
var _centro: CenterContainer
var _calentamiento: SubViewport

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	_fondo = ColorRect.new()
	_fondo.color = Color("102c3b")
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fondo)
	_centro = CenterContainer.new()
	var centro := _centro
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fondo.add_child(centro)
	var caja := VBoxContainer.new()
	caja.custom_minimum_size.x = 540
	caja.add_theme_constant_override("separation", 24)
	centro.add_child(caja)
	var titulo := Label.new()
	titulo.text = "EXTRATEXTED"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_override("font", preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf"))
	titulo.add_theme_font_size_override("font_size", 48)
	titulo.add_theme_color_override("font_color", Color("fff1d8"))
	caja.add_child(titulo)
	_texto = Label.new()
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.add_theme_color_override("font_color", Color("83e0ed"))
	caja.add_child(_texto)
	_barra = ProgressBar.new()
	_barra.custom_minimum_size.y = 18
	_barra.show_percentage = false
	for tipo in ["background", "fill"]:
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Color("ff785f") if tipo == "fill" else Color("284e60")
		estilo.set_corner_radius_all(8)
		_barra.add_theme_stylebox_override(tipo, estilo)
	caja.add_child(_barra)
	var consejo := Label.new()
	consejo.text = "Una hoja por policía. El saldo lo comparte el equipo."
	consejo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	consejo.add_theme_color_override("font_color", Color("fff1d8"))
	caja.add_child(consejo)
	_cancelar = Button.new()
	_cancelar.text = "Volver al menú"
	_cancelar.pressed.connect(cancelar)
	caja.add_child(_cancelar)
	hide()

func precargar(ruta: String) -> Error:
	if _precargas.has(ruta):
		return OK
	if not ResourceLoader.exists(ruta):
		return ERR_FILE_NOT_FOUND
	var error := ResourceLoader.load_threaded_request(ruta)
	if error == OK:
		_precargas[ruta] = true
	return error

func cargar(ruta: String) -> void:
	if activa and ruta == _ruta:
		return
	_invalidar()
	_ruta = ruta
	activa = true
	progreso = 0
	mediciones = {}
	_inicio = Time.get_ticks_usec()
	_inicio_fase = _inicio
	_limite = Time.get_ticks_msec() + 60000
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cancelar.visible = ruta != MENU
	_fondo.color.a = 1.0
	_centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var menu := get_tree().current_scene
	if is_instance_valid(menu) and menu.scene_file_path == MENU and menu._dialogo_activo:
		_fondo.color.a = 0.15
		_centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_centro.anchor_left = 0.5
		_centro.anchor_top = 0.5
	show()
	_cambiar_fase("presentacion", "Preparando el turno…", 0)
	_cuadros = 2 # El overlay se dibuja antes de solicitar/instanciar recursos.

func _process(_delta: float) -> void:
	_liberar_precargas_descartadas()
	if not activa:
		return
	if Time.get_ticks_msec() >= _limite:
		_error("La preparación agotó el tiempo de espera.")
		return
	match _fase:
		"presentacion":
			_cuadros -= 1
			if _cuadros <= 0:
				if precargar(_ruta) != OK:
					_error("No se pudo solicitar la escena.")
					return
				_cambiar_fase("recursos", "Cargando recursos…", 0)
		"recursos":
			var avance := []
			var estado := ResourceLoader.load_threaded_get_status(_ruta, avance)
			if not avance.is_empty():
				_actualizar("Cargando recursos…", float(avance[0]) * 60)
			if estado == ResourceLoader.THREAD_LOAD_LOADED:
				_cambiar_fase("instancia", "Montando la oficina…" if _ruta == OFICINA else "Abriendo el menú…", 60)
			elif estado in [ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
				_error("No se pudo cargar la escena.")
		"instancia":
			var recurso := ResourceLoader.load_threaded_get(_ruta) as PackedScene
			_precargas.erase(_ruta)
			if recurso == null:
				_error("El recurso no es una escena.")
				return
			_instancia = recurso.instantiate()
			_cambiar_fase("pool", "Preparando los cajones…", 65)
		"pool":
			if _instancia.has_method("preparar_lote_de_cajones"):
				var listo: bool = _instancia.preparar_lote_de_cajones()
				_actualizar("Preparando los cajones…", 65 + 15.0 * _instancia._bloqueos_pool.size() / _instancia.BLOQUEOS_SIMULTANEOS)
				if not listo:
					return
			_cambiar_fase("entrada", "Preparando estaciones e interfaces…", 80)
		"entrada":
			_fondo.color.a = 1.0
			_centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var escena := _instancia
			_instancia = null # El árbol adquiere la propiedad; nunca liberar desde cancelar.
			_escena_preparandose = escena
			_cambiar_fase("preparacion", "Preparando estaciones e interfaces…", 80)
			if get_tree().change_scene_to_node(escena) != OK:
				escena.free()
				_error("No se pudo abrir la escena.")
		"preparacion":
			var escena := get_tree().current_scene
			if not is_instance_valid(escena) or escena.scene_file_path != _ruta:
				return
			if _ruta == OFICINA and not escena.oficina_preparada:
				return
			_cambiar_fase("render", "Preparando la primera imagen…", 95)
			_esperar_dibujo(_generacion)
		"listo":
			_cuadros -= 1
			if _cuadros <= 0:
				_finalizar()

func _esperar_dibujo(generacion: int) -> void:
	if _ruta == OFICINA and DisplayServer.get_name() != "headless":
		_calentamiento = preload("res://UI/Menus/calentamiento_visual.gd").new()
		add_child(_calentamiento)
		await _calentamiento.preparar()
		if generacion != _generacion or not activa:
			return
		_calentamiento.queue_free()
		_calentamiento = null
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	if generacion != _generacion or not activa:
		return
	_cambiar_fase("listo", "Oficina lista" if _ruta == OFICINA else "Menú listo", 100)
	_cuadros = 2

func _finalizar() -> void:
	if _ruta == OFICINA and SesionLAN.cargando:
		_cambiar_fase("compañero", "Tu oficina está lista; esperando al compañero…", 100)
		SesionLAN.oficina_lista(get_tree().current_scene.red)
		return
	finalizar_espera()

func finalizar_espera() -> void:
	if not activa:
		return
	mediciones[_fase + "_ms"] = (Time.get_ticks_usec() - _inicio_fase) / 1000.0
	mediciones["total_ms"] = (Time.get_ticks_usec() - _inicio) / 1000.0
	print("[CARGA] ", _ruta, " ", JSON.stringify(mediciones))
	activa = false
	_escena_preparandose = null
	hide()
	if not SesionLAN.activa:
		get_tree().paused = false
	MenuGlobal._cambiando_escena = false
	MenuGlobal._abrir_tutorial_inicial.call_deferred()
	terminada.emit(_ruta)

func _actualizar(texto: String, valor: float) -> void:
	progreso = maxf(progreso, valor)
	fase = texto
	_texto.text = texto
	_barra.value = progreso
	_barra.indeterminate = _fase in ["instancia", "entrada", "preparacion", "render", "compañero"]
	fase_cambiada.emit(fase, progreso)

func _cambiar_fase(nueva: String, texto: String, valor: float) -> void:
	if not _fase.is_empty():
		mediciones[_fase + "_ms"] = (Time.get_ticks_usec() - _inicio_fase) / 1000.0
	_inicio_fase = Time.get_ticks_usec()
	_fase = nueva
	_actualizar(texto, valor)

func _invalidar() -> void:
	_generacion += 1
	activa = false
	_fase = ""
	if is_instance_valid(_calentamiento):
		_calentamiento.queue_free()
	_calentamiento = null
	if is_instance_valid(_instancia):
		_instancia.free()
	_instancia = null
	# Detener también el _ready progresivo de una escena que ya entró al árbol.
	# queue_free respeta el cambio de escena pendiente y cancela sus corutinas.
	if is_instance_valid(_escena_preparandose):
		_escena_preparandose.queue_free()
	_escena_preparandose = null

func _liberar_precargas_descartadas() -> void:
	# ResourceLoader no cancela solicitudes: recogerlas SOLO al terminar evita
	# bloquear el hilo principal o retener recursos de una carga abandonada.
	for ruta: String in _precargas.keys():
		if activa and ruta == _ruta:
			continue
		var estado := ResourceLoader.load_threaded_get_status(ruta)
		if estado == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(ruta)
			_precargas.erase(ruta)
		elif estado in [ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
			_precargas.erase(ruta)

func cancelar() -> void:
	_invalidar()
	if SesionLAN.activa:
		SesionLAN.cerrar("Se canceló la preparación de la partida.")
	else:
		cargar(MENU)

func _error(mensaje: String) -> void:
	_invalidar()
	MenuGlobal._cambiando_escena = false
	fallo.emit(mensaje)
	if SesionLAN.activa:
		SesionLAN.cerrar(mensaje)
	else:
		# Un menú ausente no debe provocar un bucle de reintentos.
		_texto.text = mensaje
		_barra.indeterminate = false
		_cancelar.visible = _ruta != MENU

func _exit_tree() -> void:
	_invalidar()
