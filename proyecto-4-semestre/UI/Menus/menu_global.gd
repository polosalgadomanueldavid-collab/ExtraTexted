extends Node

const ESCENA_JUEGO := "res://Mundo/Oficina.tscn"
const ESCENA_MENU := "res://UI/Menus/MainMenu.tscn"
const TAMANO_DISENO := Vector2(1920, 1080)
const ESCALA_PAUSA := 0.8
const DURACION_MINIMA_DISCUSION := 2.5
const PanelAyuda = preload("res://UI/Menus/panel_ayuda.gd")
const PanelClasificacion := preload("res://UI/Menus/panel_clasificacion.gd")
const ClasificacionLocalScript := preload("res://Scripts/Partida/ClasificacionLocal.gd")

enum OrigenAyuda { MENU, PAUSA, INICIO, OPCIONES, EVENTO }

@onready var capa: Control = %CapaModal
@onready var panel_pausa: PanelContainer = %PanelPausa
@onready var panel_opciones: PanelContainer = %PanelOpciones
@onready var panel_accesibilidad: PanelContainer = %PanelAccesibilidad
@onready var panel_confirmacion: PanelContainer = %PanelConfirmacion
@onready var panel_ayuda: PanelAyuda = %PanelAyuda
@onready var panel_clasificacion: PanelClasificacion = %PanelClasificacion
@onready var reanudar: Button = %Reanudar
@onready var selector_filtro: OptionButton = %SelectorFiltro
@onready var control_intensidad: HSlider = %Intensidad
@onready var control_brillo: HSlider = %Brillo
@onready var control_volumen_general: HSlider = %VolumenGeneral
@onready var control_volumen_musica: HSlider = %VolumenMusica
@onready var control_volumen_interacciones: HSlider = %VolumenInteracciones
@onready var selector_balanceo: OptionButton = %SelectorBalanceo
@onready var valor_intensidad: Label = %ValorIntensidad
@onready var valor_brillo: Label = %ValorBrillo
@onready var valor_volumen_general: Label = %ValorVolumenGeneral
@onready var valor_volumen_musica: Label = %ValorVolumenMusica
@onready var valor_volumen_interacciones: Label = %ValorVolumenInteracciones
@onready var filtro_pantalla: ColorRect = %FiltroPantalla
@onready var margen: MarginContainer = $Interfaz/CapaModal/Margen
@onready var fondo_modal: ColorRect = $Interfaz/CapaModal/Fondo
@onready var musica_menu: AudioStreamPlayer = $MusicaMenu

var nombre_partida: String = ""
var final_de_partida_activo: bool = false
var omitir_tutorial_siguiente_partida: bool = false
var _ultimo_nombre: String = ""
var _clasificacion := ClasificacionLocalScript.new()
var _opciones_desde_pausa: bool = false
var _foco_anterior: Control
var _raton_anterior: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _cambiando_escena: bool = false
var _origen_ayuda := OrigenAyuda.MENU
var _partida_con_tutorial: int = 0
var _carga_juego_activa := false
var _oficina_precargada: PackedScene
var _oficina_en_preparacion: Node
var _inicio_confirmado := false
var _momento_confirmacion := 0.0


func _ready() -> void:
	musica_menu.bus = "Musica"
	%Reanudar.pressed.connect(reanudar_juego)
	%OpcionesPausa.pressed.connect(abrir_opciones)
	%TutorialPausa.pressed.connect(abrir_tutorial)
	%AccesibilidadOpciones.pressed.connect(abrir_accesibilidad)
	%ControlesOpciones.pressed.connect(abrir_controles)
	%MenuPrincipal.pressed.connect(_pedir_volver_al_menu)
	%VolverOpciones.pressed.connect(cerrar_opciones)
	%VolverAccesibilidad.pressed.connect(cerrar_accesibilidad)
	_confinar_foco([
		control_volumen_general,
		control_volumen_musica,
		control_volumen_interacciones,
		%AccesibilidadOpciones,
		%ControlesOpciones,
		%VolverOpciones,
	])
	%Restablecer.pressed.connect(AjustesAccesibilidad.restablecer)
	%CancelarSalida.pressed.connect(_mostrar_pausa)
	%ConfirmarSalida.pressed.connect(volver_al_menu)
	panel_ayuda.boton_cerrar.pressed.connect(cerrar_ayuda)
	panel_clasificacion.boton_volver.pressed.connect(_cerrar_clasificacion)
	panel_clasificacion.volver_expediente.pressed.connect(_cerrar_clasificacion)
	panel_clasificacion.nombre_confirmado.connect(_iniciar_partida)
	selector_filtro.item_selected.connect(AjustesAccesibilidad.establecer_modo)
	selector_balanceo.item_selected.connect(_cambiar_balanceo)
	control_intensidad.value_changed.connect(_cambiar_intensidad)
	control_brillo.value_changed.connect(_cambiar_brillo)
	control_volumen_general.value_changed.connect(_cambiar_volumen_general)
	control_volumen_musica.value_changed.connect(_cambiar_volumen_musica)
	control_volumen_interacciones.value_changed.connect(_cambiar_volumen_interacciones)
	AjustesAccesibilidad.ajustes_cambiados.connect(_sincronizar_ajustes)
	get_tree().scene_changed.connect(_al_cambiar_escena)
	capa.resized.connect(_ajustar_presentacion)
	capa.visibility_changed.connect(_actualizar_musica_menu)
	capa.visibility_changed.connect(_ajustar_presentacion)
	panel_ayuda.visibility_changed.connect(_actualizar_musica_menu)
	panel_ayuda.visibility_changed.connect(_ajustar_presentacion)
	panel_pausa.visibility_changed.connect(_ajustar_presentacion)
	panel_pausa.visibility_changed.connect(_actualizar_musica_menu)
	panel_opciones.visibility_changed.connect(_ajustar_presentacion)
	panel_accesibilidad.visibility_changed.connect(_ajustar_presentacion)
	panel_confirmacion.visibility_changed.connect(_ajustar_presentacion)
	_sincronizar_ajustes()
	_ajustar_presentacion()
	_abrir_tutorial_inicial.call_deferred()
	_actualizar_musica_menu.call_deferred()


func _process(_delta: float) -> void:
	if _carga_juego_activa:
		var avance: Array = []
		var estado := ResourceLoader.load_threaded_get_status(ESCENA_JUEGO, avance)
		var menu := get_tree().current_scene
		if is_instance_valid(menu) and menu.has_method("actualizar_carga") and not avance.is_empty():
			menu.actualizar_carga(float(avance[0]))
		match estado:
			ResourceLoader.THREAD_LOAD_LOADED:
				_carga_juego_activa = false
				_oficina_precargada = ResourceLoader.load_threaded_get(ESCENA_JUEGO) as PackedScene
				if _oficina_precargada == null:
					_fallo_carga("La oficina no está disponible.")
				elif is_instance_valid(menu) and menu.has_method("oficina_lista"):
					menu.oficina_lista()
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_carga_juego_activa = false
				_fallo_carga("No se pudo preparar la oficina.")
	if _inicio_confirmado and _oficina_precargada != null:
		_preparar_entrada()


func preparar_oficina() -> void:
	if _oficina_precargada != null:
		var menu := get_tree().current_scene
		if is_instance_valid(menu) and menu.has_method("oficina_lista"):
			menu.oficina_lista()
		return
	if _carga_juego_activa:
		return
	var error := ResourceLoader.load_threaded_request(ESCENA_JUEGO)
	if error != OK:
		_fallo_carga("No se pudo preparar la oficina.")
		push_error("Error al solicitar la oficina: %s" % error_string(error))
		return
	_carga_juego_activa = true


func _fallo_carga(mensaje: String) -> void:
	_inicio_confirmado = false
	_cambiando_escena = false
	_oficina_precargada = null
	_descartar_oficina_en_preparacion()
	panel_clasificacion.error_inicio.text = mensaje
	panel_clasificacion.error_inicio.show()
	panel_clasificacion.show()
	capa.show()
	push_error(mensaje)


func _preparar_entrada() -> void:
	if _oficina_en_preparacion == null:
		_oficina_en_preparacion = _oficina_precargada.instantiate()
		if _oficina_en_preparacion == null:
			_fallo_carga("No se pudo crear la oficina.")
		return
	if not _oficina_en_preparacion.preparar_lote_de_cajones():
		return
	if Time.get_ticks_msec() / 1000.0 - _momento_confirmacion < DURACION_MINIMA_DISCUSION:
		return
	_inicio_confirmado = false
	var error := get_tree().change_scene_to_node(_oficina_en_preparacion)
	if error == OK:
		_oficina_en_preparacion = null
	else:
		_fallo_carga("No se pudo abrir la oficina.")
		push_error("Error al abrir la oficina: %s" % error_string(error))


func _descartar_oficina_en_preparacion() -> void:
	if _oficina_en_preparacion != null:
		_oficina_en_preparacion.free()
		_oficina_en_preparacion = null


func _exit_tree() -> void:
	_descartar_oficina_en_preparacion()


func _ajustar_presentacion() -> void:
	var tutorial_evento := panel_ayuda.is_visible_in_tree() and _origen_ayuda == OrigenAyuda.EVENTO
	fondo_modal.visible = not tutorial_evento
	var escala_panel := ESCALA_PAUSA if panel_pausa.visible or panel_confirmacion.visible else 1.0
	var factor := minf(capa.size.x / TAMANO_DISENO.x, capa.size.y / TAMANO_DISENO.y)
	margen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	margen.size = TAMANO_DISENO / escala_panel
	margen.scale = Vector2.ONE * factor * escala_panel
	margen.position = (capa.size - margen.size * margen.scale) * 0.5


func es_escena_de_juego() -> bool:
	var escena := get_tree().current_scene
	return is_instance_valid(escena) and escena.scene_file_path == ESCENA_JUEGO


func abrir_pausa() -> void:
	if not es_escena_de_juego() or capa.visible or _cambiando_escena or final_de_partida_activo:
		return
	_guardar_entrada()
	get_tree().paused = true
	capa.show()
	_mostrar_pausa()


func reanudar_juego() -> void:
	if not panel_pausa.visible or _cambiando_escena:
		return
	capa.hide()
	panel_pausa.hide()
	get_tree().paused = false
	_restaurar_entrada()


func abrir_opciones() -> void:
	if (capa.visible and not panel_pausa.visible) or _cambiando_escena:
		return
	_opciones_desde_pausa = es_escena_de_juego() and get_tree().paused
	if not _opciones_desde_pausa:
		if es_escena_de_juego():
			return
		_guardar_entrada()
	panel_pausa.hide()
	panel_confirmacion.hide()
	capa.show()
	panel_opciones.show()
	%AccesibilidadOpciones.grab_focus()


func cerrar_opciones() -> void:
	if not panel_opciones.is_visible_in_tree():
		return
	panel_opciones.hide()
	if _opciones_desde_pausa:
		_mostrar_pausa()
	else:
		capa.hide()
		_restaurar_entrada()


func abrir_accesibilidad() -> void:
	if not panel_opciones.is_visible_in_tree() or _cambiando_escena:
		return
	panel_opciones.hide()
	_sincronizar_ajustes()
	panel_accesibilidad.show()
	selector_filtro.grab_focus()


func cerrar_accesibilidad() -> void:
	if not panel_accesibilidad.is_visible_in_tree():
		return
	AjustesAccesibilidad.guardar()
	panel_accesibilidad.hide()
	panel_opciones.show()
	%AccesibilidadOpciones.grab_focus()


func abrir_tutorial() -> void:
	if _cambiando_escena:
		return
	if panel_pausa.is_visible_in_tree():
		var evento: StringName = get_tree().current_scene.evento_para_consultar()
		if evento != &"":
			_abrir_guia_evento(evento, OrigenAyuda.PAUSA)
		else:
			_mostrar_ayuda(false, OrigenAyuda.PAUSA)
	elif not capa.visible and not es_escena_de_juego():
		_guardar_entrada()
		_mostrar_ayuda(false, OrigenAyuda.MENU)


func mostrar_tutorial_evento(evento: StringName) -> bool:
	if not es_escena_de_juego() or get_tree().paused or capa.visible or _cambiando_escena or final_de_partida_activo:
		return false
	_guardar_entrada()
	get_tree().paused = true
	_abrir_guia_evento(evento, OrigenAyuda.EVENTO)
	return true


func _abrir_guia_evento(evento: StringName, origen: OrigenAyuda) -> void:
	_origen_ayuda = origen
	panel_pausa.hide()
	panel_ayuda.presentar_tutorial_evento(evento, origen == OrigenAyuda.PAUSA)
	_confinar_foco(panel_ayuda.controles_foco())
	panel_ayuda.show()
	capa.show()
	panel_ayuda.boton_cerrar.grab_focus()


func abrir_controles() -> void:
	if not panel_opciones.is_visible_in_tree() or _cambiando_escena:
		return
	panel_opciones.hide()
	_mostrar_ayuda(true, OrigenAyuda.OPCIONES)


func _abrir_tutorial_inicial() -> void:
	if capa.visible or _cambiando_escena or not es_escena_de_juego():
		return
	var id_partida := get_tree().current_scene.get_instance_id()
	if omitir_tutorial_siguiente_partida:
		omitir_tutorial_siguiente_partida = false
		_partida_con_tutorial = id_partida
		return
	if id_partida == _partida_con_tutorial:
		return
	_partida_con_tutorial = id_partida
	_guardar_entrada()
	get_tree().paused = true
	_mostrar_ayuda(false, OrigenAyuda.INICIO)


func _mostrar_ayuda(es_leyenda: bool, origen: OrigenAyuda) -> void:
	_origen_ayuda = origen
	panel_pausa.hide()
	panel_ayuda.presentar(es_leyenda, origen == OrigenAyuda.INICIO)
	panel_ayuda.show()
	capa.show()
	var controles := panel_ayuda.controles_foco()
	_confinar_foco(controles)
	controles[0].grab_focus()


func cerrar_ayuda() -> void:
	if not panel_ayuda.visible:
		return
	if _origen_ayuda in [OrigenAyuda.INICIO, OrigenAyuda.EVENTO]:
		get_tree().paused = false
		capa.hide()
	panel_ayuda.hide()
	if _origen_ayuda == OrigenAyuda.OPCIONES:
		panel_opciones.show()
		%ControlesOpciones.grab_focus()
	elif _origen_ayuda == OrigenAyuda.PAUSA:
		_mostrar_pausa()
		%TutorialPausa.grab_focus()
	else:
		capa.hide()
		_restaurar_entrada()


func pedir_nombre_partida() -> void:
	if not _abrir_panel_clasificacion():
		return
	panel_clasificacion.presentar_nombre(_ultimo_nombre)
	_confinar_foco([
		panel_clasificacion.nombre_jugador,
		panel_clasificacion.boton_continuar,
		panel_clasificacion.boton_volver,
	])
	panel_clasificacion.nombre_jugador.grab_focus()


func abrir_clasificacion() -> void:
	if not _abrir_panel_clasificacion():
		return
	var clasificacion := consultar_clasificacion()
	panel_clasificacion.presentar_tabla(clasificacion.entradas, clasificacion.error, _ultimo_nombre)
	var controles: Array[Control] = [panel_clasificacion.volver_expediente]
	if panel_clasificacion.tabla.visible:
		controles.append(panel_clasificacion.lista)
	_confinar_foco(controles)
	panel_clasificacion.volver_expediente.grab_focus()


func consultar_clasificacion() -> Dictionary:
	var error := _clasificacion.cargar()
	return {"entradas": _clasificacion.obtener_clasificacion(), "error": error}


func registrar_puntaje(total: int, nombre: String) -> void:
	if total <= 0:
		return
	var error := _clasificacion.registrar_puntuacion(nombre, total)
	if error != OK:
		push_warning("No se pudo guardar el puntaje local: %s" % error_string(error))


func _abrir_panel_clasificacion() -> bool:
	if capa.visible or _cambiando_escena or es_escena_de_juego():
		return false
	_guardar_entrada()
	capa.show()
	panel_clasificacion.show()
	return true


func _cerrar_clasificacion() -> void:
	panel_clasificacion.hide()
	capa.hide()
	_restaurar_entrada()
	var menu := get_tree().current_scene
	if is_instance_valid(menu) and menu.has_method("cancelar_discusion"):
		menu.cancelar_discusion()


func _iniciar_partida(nombre: String, nombre_companero: String = "") -> void:
	if not panel_clasificacion.formulario.is_visible_in_tree() or _cambiando_escena:
		return
	nombre = ClasificacionLocalScript.limpiar_nombre(nombre)
	if nombre.is_empty() or nombre.length() > ClasificacionLocalScript.MAX_CARACTERES_NOMBRE:
		return
	_cambiando_escena = true
	nombre_partida = nombre
	_ultimo_nombre = nombre
	_momento_confirmacion = Time.get_ticks_msec() / 1000.0
	_inicio_confirmado = true
	panel_clasificacion.hide()
	capa.hide()
	var menu := get_tree().current_scene
	if is_instance_valid(menu) and menu.has_method("confirmar_discusion"):
		menu.confirmar_discusion(nombre, nombre_companero)
	preparar_oficina()


func volver_al_menu() -> void:
	if _cambiando_escena:
		return
	_cambiando_escena = true
	AjustesAccesibilidad.guardar()
	get_tree().paused = false
	var error := get_tree().change_scene_to_file(ESCENA_MENU)
	if error != OK:
		_cambiando_escena = false
		get_tree().paused = true
		_mostrar_pausa()
		push_error("No se pudo abrir el menu principal: %s" % error)


func _input(event: InputEvent) -> void:
	# LineEdit consume Escape mientras edita; permite cerrar el formulario con esa tecla.
	if _cambiando_escena or not panel_clasificacion.formulario.is_visible_in_tree():
		return
	if event.is_action_pressed("Cancel") and not panel_clasificacion.nombre_jugador.has_ime_text():
		_cerrar_clasificacion()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("Cancel") or event.is_echo() or _cambiando_escena or final_de_partida_activo:
		return
	if panel_ayuda.visible:
		cerrar_ayuda()
	elif panel_clasificacion.visible:
		_cerrar_clasificacion()
	elif panel_accesibilidad.visible:
		cerrar_accesibilidad()
	elif panel_opciones.visible:
		cerrar_opciones()
	elif panel_confirmacion.visible:
		_mostrar_pausa()
	elif capa.visible and panel_pausa.visible:
		reanudar_juego()
	elif es_escena_de_juego():
		abrir_pausa()
	else:
		return
	get_viewport().set_input_as_handled()


func _mostrar_pausa() -> void:
	panel_opciones.hide()
	panel_confirmacion.hide()
	panel_pausa.show()
	_confinar_foco([reanudar, %OpcionesPausa, %TutorialPausa, %MenuPrincipal])
	reanudar.grab_focus()


func _pedir_volver_al_menu() -> void:
	panel_pausa.hide()
	panel_confirmacion.show()
	_confinar_foco([%CancelarSalida, %ConfirmarSalida])
	%CancelarSalida.grab_focus()


func _computador() -> PCStatic:
	if not es_escena_de_juego():
		return null
	return get_tree().current_scene.get_node_or_null("Computer") as PCStatic


func _guardar_entrada() -> void:
	_foco_anterior = get_viewport().gui_get_focus_owner()
	var computador := _computador()
	if is_instance_valid(computador) and computador.is_using:
		_foco_anterior = computador.sub_viewport.gui_get_focus_owner()
	if is_instance_valid(_foco_anterior):
		_foco_anterior.release_focus()
	_raton_anterior = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _restaurar_entrada() -> void:
	Input.mouse_mode = _raton_anterior
	if is_instance_valid(_foco_anterior) and _foco_anterior.is_visible_in_tree():
		_foco_anterior.grab_focus()
	_foco_anterior = null


func _al_cambiar_escena() -> void:
	final_de_partida_activo = false
	capa.hide()
	panel_pausa.hide()
	panel_opciones.hide()
	panel_accesibilidad.hide()
	panel_confirmacion.hide()
	panel_ayuda.hide()
	panel_clasificacion.hide()
	_foco_anterior = null
	_opciones_desde_pausa = false
	_cambiando_escena = false
	_inicio_confirmado = false
	_oficina_precargada = null
	_descartar_oficina_en_preparacion()
	if not es_escena_de_juego():
		nombre_partida = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_actualizar_musica_menu()
	_abrir_tutorial_inicial()


func _actualizar_musica_menu() -> void:
	if not is_instance_valid(musica_menu):
		return
	var escena_menu := get_tree().current_scene != null and get_tree().current_scene.scene_file_path == ESCENA_MENU
	var tutorial_automatico := panel_ayuda.is_visible_in_tree() and _origen_ayuda in [OrigenAyuda.INICIO, OrigenAyuda.EVENTO]
	var pausa_visible := es_escena_de_juego() and get_tree().paused and capa.visible and not tutorial_automatico
	if es_escena_de_juego():
		var musica_partida := get_tree().current_scene.get_node("MusicaPartida") as AudioStreamPlayer
		# El tutorial congela casos y movimiento, pero la pista de la partida continúa.
		musica_partida.process_mode = Node.PROCESS_MODE_ALWAYS if tutorial_automatico else Node.PROCESS_MODE_INHERIT
	if escena_menu or pausa_visible:
		if not musica_menu.playing:
			var pista := musica_menu.stream as AudioStreamMP3
			if pista != null:
				pista.loop = true
			musica_menu.play()
		musica_menu.stream_paused = false
	elif musica_menu.playing:
		musica_menu.stream_paused = true


func _cambiar_intensidad(valor: float) -> void:
	AjustesAccesibilidad.establecer_intensidad(valor / 100.0)


func _cambiar_brillo(valor: float) -> void:
	AjustesAccesibilidad.establecer_brillo(valor / 100.0)


func _cambiar_balanceo(indice: int) -> void:
	AjustesAccesibilidad.establecer_balanceo_camara(indice == 0)


func _cambiar_volumen_general(valor: float) -> void:
	AjustesAccesibilidad.establecer_volumen_general(valor / 100.0)


func _cambiar_volumen_musica(valor: float) -> void:
	AjustesAccesibilidad.establecer_volumen_musica(valor / 100.0)


func _cambiar_volumen_interacciones(valor: float) -> void:
	AjustesAccesibilidad.establecer_volumen_interacciones(valor / 100.0)


func _sincronizar_ajustes() -> void:
	selector_filtro.select(AjustesAccesibilidad.modo)
	control_intensidad.set_value_no_signal(AjustesAccesibilidad.intensidad * 100.0)
	control_brillo.set_value_no_signal(AjustesAccesibilidad.brillo * 100.0)
	control_volumen_general.set_value_no_signal(AjustesAccesibilidad.volumen_general * 100.0)
	control_volumen_musica.set_value_no_signal(AjustesAccesibilidad.volumen_musica * 100.0)
	control_volumen_interacciones.set_value_no_signal(AjustesAccesibilidad.volumen_interacciones * 100.0)
	selector_balanceo.select(0 if AjustesAccesibilidad.balanceo_camara else 1)
	control_intensidad.editable = AjustesAccesibilidad.modo != 0
	control_intensidad.focus_mode = Control.FOCUS_ALL if control_intensidad.editable else Control.FOCUS_NONE
	var controles: Array[Control] = [selector_filtro]
	if control_intensidad.editable:
		controles.append(control_intensidad)
	controles.append_array([control_brillo, selector_balanceo, %Restablecer, %VolverAccesibilidad])
	_confinar_foco(controles)
	valor_intensidad.text = "%d %%" % roundi(control_intensidad.value)
	valor_brillo.text = "%d %%" % roundi(control_brillo.value)
	valor_volumen_general.text = "%d %%" % roundi(control_volumen_general.value)
	valor_volumen_musica.text = "%d %%" % roundi(control_volumen_musica.value)
	valor_volumen_interacciones.text = "%d %%" % roundi(control_volumen_interacciones.value)
	var material_filtro := filtro_pantalla.material as ShaderMaterial
	material_filtro.set_shader_parameter("mode", AjustesAccesibilidad.modo)
	material_filtro.set_shader_parameter("intensity", AjustesAccesibilidad.intensidad)
	material_filtro.set_shader_parameter("brightness", AjustesAccesibilidad.brillo)
	# El estado neutro no necesita copiar ni procesar la pantalla.
	filtro_pantalla.visible = (
		(AjustesAccesibilidad.modo != 0 and AjustesAccesibilidad.intensidad > 0.0)
		or not is_equal_approx(AjustesAccesibilidad.brillo, 1.0)
	)


func _confinar_foco(controles: Array[Control]) -> void:
	for indice: int in range(controles.size()):
		var control := controles[indice]
		var anterior := controles[(indice + controles.size() - 1) % controles.size()]
		var siguiente := controles[(indice + 1) % controles.size()]
		control.focus_previous = control.get_path_to(anterior)
		control.focus_next = control.get_path_to(siguiente)
		control.focus_neighbor_top = control.focus_previous
		control.focus_neighbor_bottom = control.focus_next
		control.focus_neighbor_left = NodePath(".")
		control.focus_neighbor_right = NodePath(".")
