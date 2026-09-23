extends Control
class_name UIPantalla

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var overlay_negro: ColorRect = $OverlayNegro

# Vistas de la interfaz
@onready var vista_sin_problema: Control = $Vista_Sin_problemas
@onready var vista_problema: Control = $Vista_problema

# Nodos dentro de VistaProblema
@onready var label_texto_caso: Label = $Vista_problema/Label2
@onready var boton_si: Button = $Vista_problema/Button2
@onready var boton_no: Button = $Vista_problema/Button3

var pc_reference: PCStatic


func _ready() -> void:
	apagar_instantaneo()
	
	# Aseguramos que los botones acepten foco y conectamos señales de clic
	if boton_si:
		boton_si.focus_mode = Control.FOCUS_ALL
		boton_si.pressed.connect(_on_boton_si_pressed)
	if boton_no:
		boton_no.focus_mode = Control.FOCUS_ALL
		boton_no.pressed.connect(_on_boton_no_pressed)


# --- CONTROL DE VISTAS (PANTALLAS) ---

func mostrar_vista_sin_problema() -> void:
	if vista_problema:
		vista_problema.hide()
	if vista_sin_problema:
		vista_sin_problema.show()

# Alias en plural por compatibilidad
func mostrar_vista_sin_problemas() -> void:
	mostrar_vista_sin_problema()

func mostrar_vista_problema(texto_caso: String) -> void:
	if vista_sin_problema:
		vista_sin_problema.hide()
	if vista_problema:
		vista_problema.show()
	if label_texto_caso:
		label_texto_caso.text = texto_caso
	
	# Le da el foco/resalte inicial al Botón SÍ
	if boton_si:
		boton_si.grab_focus()


# --- OVERLAY Y ANIMACIÓN (ENCENDIDO/APAGADO DE PC) ---

func encender() -> void:
	if overlay_negro and animation_player:
		overlay_negro.show()
		overlay_negro.modulate.a = 1.0
		animation_player.stop()
		animation_player.play("encender")

func apagar() -> void:
	if animation_player:
		animation_player.play("apagar")

func apagar_instantaneo() -> void:
	if animation_player and overlay_negro:
		animation_player.stop()
		overlay_negro.modulate.a = 1.0


# --- NAVEGACIÓN Y FOCO INVOCADOS DESDE PCSTATIC ---

func mover_foco() -> void:
	if not vista_problema or not vista_problema.visible:
		return
		
	if boton_si and boton_si.has_focus():
		if boton_no: boton_no.grab_focus()
	elif boton_no and boton_no.has_focus():
		if boton_si: boton_si.grab_focus()
	elif boton_si:
		boton_si.grab_focus()

func confirmar_seleccion() -> void:
	if not vista_problema or not vista_problema.visible:
		return
		
	if boton_si and boton_si.has_focus():
		_on_boton_si_pressed()
	elif boton_no and boton_no.has_focus():
		_on_boton_no_pressed()
	else:
		_on_boton_si_pressed()


# --- RESPUESTAS DE BOTONES ---

func _on_boton_si_pressed() -> void:
	if pc_reference and pc_reference.sistema_computador:
		pc_reference.sistema_computador.responder_si()

func _on_boton_no_pressed() -> void:
	if pc_reference and pc_reference.sistema_computador:
		pc_reference.sistema_computador.responder_no()
