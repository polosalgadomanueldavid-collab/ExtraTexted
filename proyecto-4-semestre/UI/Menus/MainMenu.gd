extends Control

const TAMANO_DISENO := Vector2(1920, 1080)
const DURACION_REVELADO := 0.85
enum Voz { CONSEJO, OFICIAL_1, OFICIAL_2 }
const FUENTE_CONSEJO := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const COLORES_VOZ := [Color("ffd28e"), Color("83e0ed"), Color("95ead0")]
const DIALOGO := [
	[Voz.CONSEJO, "Mira bien qué puedes resolver primero."],
	[Voz.OFICIAL_1, "¿El piso es lava?"],
	[Voz.OFICIAL_2, "Qué frío que hace, hermano."],
	[Voz.OFICIAL_1, "Wiiiiji ji."],
	[Voz.OFICIAL_2, "¡Aún no sabemos cómo se llama el policía!"],
	[Voz.OFICIAL_1, "¿{compañero}, eres tú?"],
	[Voz.CONSEJO, "Pulsa E en el computador para recibir la denuncia más urgente."],
	[Voz.CONSEJO, "Lleva la hoja a las estaciones marcadas. Puedes completarlas en cualquier orden."],
	[Voz.CONSEJO, "La flecha señala la estación pendiente más cercana."],
	[Voz.CONSEJO, "Si sueltas la hoja con E, acércate y pulsa E para recogerla."],
	[Voz.CONSEJO, "En Seguridad, espera a que termine el desencriptado y vuelve a pulsar E."],
	[Voz.CONSEJO, "Si la impresora se atasca, busca la herramienta en la zona de descanso."],
	[Voz.CONSEJO, "En Evidencias, usa A y D para cambiar de hoja y E para elegir."],
	[Voz.CONSEJO, "En Verificación, pulsa E cuando la luz cruce la franja verde."],
	[Voz.CONSEJO, "Vigila el tiempo de cada denuncia: las que esperan también pueden vencer."],
	[Voz.CONSEJO, "Descansar o beber en la zona de descanso recupera la calma."],
]
const SEGUNDOS_POR_FRASE := 2.8
@export var desplazamiento_horizontal: float = 0.0
@export var desplazamiento_vertical: float = 0.0
@export var escala_presentacion: float = 1.0

@onready var play_button: Button = %PlayButton
@onready var presentacion: Control = $CenterContainer
@onready var fondo: Control = $FondoOficina
@onready var pantalla_discusion: Control = $PantallaDiscusion
@onready var dialogo: VBoxContainer = $PantallaDiscusion/Dialogo
@onready var contenido: VBoxContainer = $PantallaDiscusion/Dialogo/Contenido
@onready var fila_carga: HBoxContainer = $PantallaDiscusion/Dialogo/Carga
@onready var hablante: Label = $PantallaDiscusion/Dialogo/Contenido/Hablante
@onready var frase: Label = $PantallaDiscusion/Dialogo/Contenido/Frase
@onready var estado_carga: Label = $PantallaDiscusion/Dialogo/Carga/EstadoCarga
@onready var progreso_carga: ProgressBar = $PantallaDiscusion/Dialogo/Carga/ProgresoCarga
@onready var entrada_negra: ColorRect = $EntradaNegra

var _dialogo_activo := false
var _tiempo_dialogo := 0.0
var _nombres := PackedStringArray()
var _lineas_activas := PackedInt32Array()
var _indice_activo := 0


func _ready() -> void:
	resized.connect(_ajustar_escala)
	_ajustar_escala()
	play_button.grab_focus()
	_revelar_menu.call_deferred()


func _revelar_menu() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var transicion := create_tween()
	transicion.tween_property(entrada_negra, "modulate:a", 0.0, DURACION_REVELADO).set_trans(Tween.TRANS_SINE)
	await transicion.finished
	if is_instance_valid(entrada_negra):
		entrada_negra.hide()


func _process(delta: float) -> void:
	if not _dialogo_activo:
		return
	_tiempo_dialogo += delta
	if _tiempo_dialogo >= SEGUNDOS_POR_FRASE:
		var pasos := floori(_tiempo_dialogo / SEGUNDOS_POR_FRASE)
		_tiempo_dialogo = fmod(_tiempo_dialogo, SEGUNDOS_POR_FRASE)
		_indice_activo = (_indice_activo + pasos) % _lineas_activas.size()
		_mostrar_frase()


func _preparar_frases(nombre_1: String = "", nombre_2: String = "") -> void:
	_nombres = PackedStringArray(["Consejo", nombre_1.strip_edges(), nombre_2.strip_edges()])
	_lineas_activas.clear()
	var intervenciones: Array[int] = []
	for i in range(DIALOGO.size()):
		var voz: Voz = DIALOGO[i][0]
		if _nombres[voz].is_empty():
			continue
		var texto: String = DIALOGO[i][1]
		if _nombres[Voz.OFICIAL_2].is_empty() and texto.contains("{compañero}"):
			continue
		if voz != Voz.CONSEJO:
			intervenciones.append(_lineas_activas.size())
		_lineas_activas.append(i)
	# La oficina puede estar lista en menos de una frase: muestra el alias al confirmar.
	if intervenciones.is_empty():
		_indice_activo = randi_range(0, _lineas_activas.size() - 1)
	else:
		_indice_activo = intervenciones.pick_random()
	_tiempo_dialogo = 0.0
	_mostrar_frase()


func _mostrar_frase() -> void:
	var linea: Array = DIALOGO[_lineas_activas[_indice_activo]]
	var voz: Voz = linea[0]
	hablante.text = _nombres[voz]
	hablante.add_theme_color_override("font_color", COLORES_VOZ[voz])
	var texto: String = linea[1]
	frase.text = texto.replace("{compañero}", _nombres[Voz.OFICIAL_2])
	if voz == Voz.CONSEJO:
		hablante.add_theme_font_override("font", FUENTE_CONSEJO)
	else:
		hablante.remove_theme_font_override("font")
		fondo.gesticular(voz - 1)


func iniciar_discusion() -> void:
	if _dialogo_activo:
		return
	_dialogo_activo = true
	presentacion.hide()
	pantalla_discusion.show()
	estado_carga.text = "Preparando el turno..."
	progreso_carga.value = 0.0
	fondo.call("establecer_discusion", true)
	_preparar_frases()


func cancelar_discusion() -> void:
	if not _dialogo_activo:
		return
	_dialogo_activo = false
	pantalla_discusion.hide()
	presentacion.show()
	fondo.call("establecer_discusion", false)
	play_button.grab_focus()


func confirmar_discusion(nombre_1: String, nombre_2: String = "") -> void:
	_preparar_frases(nombre_1, nombre_2)
	estado_carga.text = "Abriendo la oficina..."


func actualizar_carga(avance: float) -> void:
	progreso_carga.value = clampf(avance * 90.0, 0.0, 90.0)


func oficina_lista() -> void:
	progreso_carga.value = 90.0
	estado_carga.text = "Ubicando las estaciones..."


func _ajustar_escala() -> void:
	# Escala solo este menú: las pantallas de juego conservan sus coordenadas.
	var factor := minf(size.x / TAMANO_DISENO.x, size.y / TAMANO_DISENO.y) * escala_presentacion
	presentacion.scale = Vector2.ONE * factor
	presentacion.position = (size - TAMANO_DISENO * factor) * 0.5 + Vector2(desplazamiento_horizontal, desplazamiento_vertical) * factor
	var escala := minf(size.x / TAMANO_DISENO.x, size.y / TAMANO_DISENO.y)
	dialogo.anchor_right = 0.77 if size.x < 600 else 0.476
	hablante.add_theme_font_size_override("font_size", maxi(14, roundi(40 * escala)))
	frase.add_theme_font_size_override("font_size", maxi(18, roundi(57 * escala)))
	estado_carga.add_theme_font_size_override("font_size", maxi(11, roundi(27 * escala)))
	contenido.add_theme_constant_override("separation", roundi(6 * escala))
	dialogo.add_theme_constant_override("separation", roundi(30 * escala))
	fila_carga.add_theme_constant_override("separation", roundi(20 * escala))
	progreso_carga.custom_minimum_size.y = maxi(3, roundi(7 * escala))


func _on_play_button_pressed() -> void:
	MenuGlobal.pedir_nombre_partida()
	if MenuGlobal.panel_clasificacion.visible:
		iniciar_discusion()
		MenuGlobal.preparar_oficina()


func _on_options_button_pressed() -> void:
	MenuGlobal.abrir_opciones()


func _on_tutorial_button_pressed() -> void:
	MenuGlobal.abrir_tutorial()


func _on_ranking_button_pressed() -> void:
	MenuGlobal.abrir_clasificacion()


func _on_quit_button_pressed() -> void:
	AjustesAccesibilidad.guardar()
	get_tree().quit()
