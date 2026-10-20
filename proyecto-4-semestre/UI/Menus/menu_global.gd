extends Node

const ESCENA_JUEGO := "res://Oficina.tscn"
const ESCENA_MENU := "res://MainMenu.tscn"

@onready var capa: Control = %CapaModal
@onready var panel_pausa: PanelContainer = %PanelPausa
@onready var panel_opciones: PanelContainer = %PanelOpciones
@onready var panel_confirmacion: PanelContainer = %PanelConfirmacion
@onready var reanudar: Button = %Reanudar
@onready var salir_computador: Button = %SalirComputador
@onready var selector_filtro: OptionButton = %SelectorFiltro
@onready var control_intensidad: HSlider = %Intensidad
@onready var control_brillo: HSlider = %Brillo
@onready var valor_intensidad: Label = %ValorIntensidad
@onready var valor_brillo: Label = %ValorBrillo
@onready var filtro_pantalla: ColorRect = %FiltroPantalla

var _opciones_desde_pausa: bool = false
var _foco_anterior: Control
var _raton_anterior: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _cambiando_escena: bool = false


func _ready() -> void:
	%Reanudar.pressed.connect(reanudar_juego)
	%OpcionesPausa.pressed.connect(abrir_opciones)
	%MenuPrincipal.pressed.connect(_pedir_volver_al_menu)
	salir_computador.pressed.connect(_salir_del_computador)
	%VolverOpciones.pressed.connect(cerrar_opciones)
	%Restablecer.pressed.connect(AjustesAccesibilidad.restablecer)
	%CancelarSalida.pressed.connect(_mostrar_pausa)
	%ConfirmarSalida.pressed.connect(volver_al_menu)
	selector_filtro.item_selected.connect(AjustesAccesibilidad.establecer_modo)
	control_intensidad.value_changed.connect(_cambiar_intensidad)
	control_brillo.value_changed.connect(_cambiar_brillo)
	AjustesAccesibilidad.ajustes_cambiados.connect(_sincronizar_ajustes)
	get_tree().scene_changed.connect(_al_cambiar_escena)
	_sincronizar_ajustes()


func es_escena_de_juego() -> bool:
	var escena := get_tree().current_scene
	return is_instance_valid(escena) and escena.scene_file_path == ESCENA_JUEGO


func abrir_pausa() -> void:
	if not es_escena_de_juego() or capa.visible or _cambiando_escena:
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
	if panel_opciones.visible or _cambiando_escena:
		return
	_opciones_desde_pausa = es_escena_de_juego() and get_tree().paused
	if not _opciones_desde_pausa:
		if es_escena_de_juego():
			return
		_guardar_entrada()
	panel_pausa.hide()
	panel_confirmacion.hide()
	_sincronizar_ajustes()
	capa.show()
	panel_opciones.show()
	selector_filtro.grab_focus()


func cerrar_opciones() -> void:
	AjustesAccesibilidad.guardar()
	panel_opciones.hide()
	if _opciones_desde_pausa:
		_mostrar_pausa()
	else:
		capa.hide()
		_restaurar_entrada()


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


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("Cancel") or event.is_echo() or _cambiando_escena:
		return
	if panel_opciones.visible:
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
	var computador := _computador()
	salir_computador.visible = is_instance_valid(computador) and computador.is_using
	var controles: Array[Control] = [reanudar, %OpcionesPausa]
	if salir_computador.visible:
		controles.append(salir_computador)
	controles.append(%MenuPrincipal)
	_confinar_foco(controles)
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


func _salir_del_computador() -> void:
	var computador := _computador()
	if is_instance_valid(computador) and computador.is_using:
		computador.salir_de_uso()
	_foco_anterior = null
	reanudar_juego()


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
	capa.hide()
	panel_pausa.hide()
	panel_opciones.hide()
	panel_confirmacion.hide()
	_foco_anterior = null
	_opciones_desde_pausa = false
	_cambiando_escena = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _cambiar_intensidad(valor: float) -> void:
	AjustesAccesibilidad.establecer_intensidad(valor / 100.0)


func _cambiar_brillo(valor: float) -> void:
	AjustesAccesibilidad.establecer_brillo(valor / 100.0)


func _sincronizar_ajustes() -> void:
	selector_filtro.select(AjustesAccesibilidad.modo)
	control_intensidad.set_value_no_signal(AjustesAccesibilidad.intensidad * 100.0)
	control_brillo.set_value_no_signal(AjustesAccesibilidad.brillo * 100.0)
	control_intensidad.editable = AjustesAccesibilidad.modo != 0
	control_intensidad.focus_mode = Control.FOCUS_ALL if control_intensidad.editable else Control.FOCUS_NONE
	var controles: Array[Control] = [selector_filtro]
	if control_intensidad.editable:
		controles.append(control_intensidad)
	controles.append_array([control_brillo, %Restablecer, %VolverOpciones])
	_confinar_foco(controles)
	valor_intensidad.text = "%d %%" % roundi(control_intensidad.value)
	valor_brillo.text = "%d %%" % roundi(control_brillo.value)
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
