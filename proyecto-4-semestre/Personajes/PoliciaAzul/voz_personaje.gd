extends AudioStreamPlayer3D
class_name VozPersonaje
## Voz gomosa provisional. Las pistas, el tono y el volumen siguen siendo editables.

const PRIORIDADES := {&"esfuerzo": 0, &"saludo": 1, &"sorpresa": 2, &"alegria": 3}

@export var habilitada: bool = true:
	set(valor):
		habilitada = valor
		if not valor:
			detener()
@export_category("Expresiones")
@export var saludo: AudioStream = preload("res://Audios/VozPersonaje/Gomosa/saludo.wav")
@export var esfuerzo: AudioStream = preload("res://Audios/VozPersonaje/Gomosa/esfuerzo.wav")
@export var sorpresa: AudioStream = preload("res://Audios/VozPersonaje/Gomosa/sorpresa.wav")
@export var alegria: AudioStream = preload("res://Audios/VozPersonaje/Gomosa/alegria.wav")
@export_category("Ajustes de voz")
@export_range(0.5, 2.0, 0.01) var tono_base: float = 1.0
@export_range(0.0, 0.15, 0.005) var variacion_tono: float = 0.02
@export_range(0.0, 1.0, 0.01) var pausa_minima: float = 0.15

var expresion_actual: StringName = &""
var _pausa_restante: float = 0.0
var _azar := RandomNumberGenerator.new()


func _ready() -> void:
	_azar.randomize()
	max_polyphony = 1
	finished.connect(_al_terminar)


func _process(delta: float) -> void:
	_pausa_restante = maxf(0.0, _pausa_restante - delta)


func reproducir(expresion: StringName) -> bool:
	if not habilitada or not is_inside_tree() or get_tree().paused:
		return false
	var pistas := {&"saludo": saludo, &"esfuerzo": esfuerzo, &"sorpresa": sorpresa, &"alegria": alegria}
	var pista := pistas.get(expresion) as AudioStream
	if pista == null:
		return false
	if playing:
		# Una emoción importante puede sustituir un esfuerzo, nunca acumular otra voz.
		if int(PRIORIDADES[expresion]) <= int(PRIORIDADES.get(expresion_actual, -1)):
			return false
	elif _pausa_restante > 0.0:
		return false
	stop()
	stream = pista
	expresion_actual = expresion
	pitch_scale = tono_base * _azar.randf_range(1.0 - variacion_tono, 1.0 + variacion_tono)
	_pausa_restante = 0.0
	play()
	return true


func detener() -> void:
	stop()
	expresion_actual = &""
	_pausa_restante = 0.0


func _al_terminar() -> void:
	expresion_actual = &""
	_pausa_restante = pausa_minima
