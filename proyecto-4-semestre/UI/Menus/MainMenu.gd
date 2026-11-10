extends Control

const TAMANO_DISENO := Vector2(1920, 1080)
const DURACION_REVELADO := 0.85
const DIALOGO := [
	["CONSEJO", "Mira bien qué puedes resolver primero."],
	["OFICIAL 1", "¿El piso es lava?"],
	["OFICIAL 2", "Qué frío que hace, hermano."],
	["OFICIAL 1", "Wiiiiji ji."],
	["OFICIAL 2", "¡Aún no sabemos cómo se llama el policía!"],
	["OFICIAL 1", "¿Cristian, eres tú?"],
	["CONSEJO", "Pulsa E en el computador para recibir la denuncia más urgente."],
	["CONSEJO", "Lleva la hoja a las estaciones marcadas. Puedes completarlas en cualquier orden."],
	["CONSEJO", "La flecha señala la estación pendiente más cercana."],
	["CONSEJO", "Si sueltas la hoja con E, acércate y pulsa E para recogerla."],
	["CONSEJO", "En Seguridad, espera a que termine el desencriptado y vuelve a pulsar E."],
	["CONSEJO", "Si la impresora se atasca, busca la herramienta en la zona de descanso."],
	["CONSEJO", "En Evidencias, usa A y D para cambiar de hoja y E para elegir."],
	["CONSEJO", "En Verificación, pulsa E cuando la luz cruce la franja verde."],
	["CONSEJO", "Vigila el tiempo de cada denuncia: las que esperan también pueden vencer."],
	["CONSEJO", "Descansar o beber en la zona de descanso recupera la calma."],
]
const SEGUNDOS_POR_FRASE := 2.8
@export var desplazamiento_horizontal: float = 0.0
@export var desplazamiento_vertical: float = 0.0
@export var escala_presentacion: float = 1.0

@onready var play_button: Button = %PlayButton
@onready var presentacion: Control = $CenterContainer
@onready var fondo: Control = $FondoOficina
@onready var pantalla_discusion: Control = $PantallaDiscusion
@onready var hablante: Label = $PantallaDiscusion/Dialogo/Contenido/Hablante
@onready var frase: Label = $PantallaDiscusion/Dialogo/Contenido/Frase
@onready var estado_carga: Label = $PantallaDiscusion/Dialogo/Contenido/EstadoCarga
@onready var progreso_carga: ProgressBar = $PantallaDiscusion/Dialogo/Contenido/ProgresoCarga
@onready var entrada_negra: ColorRect = $EntradaNegra

var _dialogo_activo := false
var _tiempo_dialogo := 0.0
var _linea := -1
var _primera_linea := 0


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
	var linea := (_primera_linea + floori(_tiempo_dialogo / SEGUNDOS_POR_FRASE)) % DIALOGO.size()
	if linea != _linea:
		_linea = linea
		hablante.text = DIALOGO[linea][0]
		frase.text = DIALOGO[linea][1]
		fondo.call("gesticular", linea % 2)


func iniciar_discusion() -> void:
	if _dialogo_activo:
		return
	_dialogo_activo = true
	_tiempo_dialogo = 0.0
	_linea = -1
	_primera_linea = randi_range(0, DIALOGO.size() - 1)
	presentacion.hide()
	pantalla_discusion.show()
	estado_carga.text = "Preparando el turno..."
	progreso_carga.value = 0.0
	fondo.call("establecer_discusion", true)
	_process(0.0)


func cancelar_discusion() -> void:
	if not _dialogo_activo:
		return
	_dialogo_activo = false
	pantalla_discusion.hide()
	presentacion.show()
	fondo.call("establecer_discusion", false)
	play_button.grab_focus()


func confirmar_discusion() -> void:
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
	var factor_texto := clampf(factor, 0.5, 1.0)
	hablante.add_theme_font_size_override("font_size", roundi(26.0 * factor_texto))
	frase.add_theme_font_size_override("font_size", roundi(34.0 * factor_texto))
	estado_carga.add_theme_font_size_override("font_size", roundi(19.0 * factor_texto))


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
