extends AudioStreamPlayer3D
class_name SonidosPasos
## Pisadas individuales de la opción 3, con cadencia de caminar y correr.

signal paso_reproducido(indice: int)

@export var habilitado: bool = true:
	set(valor):
		habilitado = valor
		if not valor:
			detener()
@export var pasos: Array[AudioStream] = [
	preload("res://Audios/Pasos/SuelaGoma/paso_01.wav"),
	preload("res://Audios/Pasos/SuelaGoma/paso_02.wav"),
	preload("res://Audios/Pasos/SuelaGoma/paso_03.wav"),
	preload("res://Audios/Pasos/SuelaGoma/paso_04.wav"),
	preload("res://Audios/Pasos/SuelaGoma/paso_05.wav"),
	preload("res://Audios/Pasos/SuelaGoma/paso_06.wav"),
]
# Dos pisadas por ciclo: walk dura 0.9 s y run dura 0.6 s en el modelo actual.
@export_range(0.15, 1.0, 0.01) var intervalo_caminar: float = 0.45
@export_range(0.15, 1.0, 0.01) var intervalo_correr: float = 0.30
@export_range(0.5, 2.0, 0.01) var tono_base: float = 1.0
@export_range(0.0, 0.15, 0.005) var variacion_tono: float = 0.025

var _restante: float = 0.0
var _intervalo_anterior: float = 0.0
var _ultimo_indice: int = -1
var _azar := RandomNumberGenerator.new()


func _ready() -> void:
	_azar.randomize()
	max_polyphony = 1


func actualizar(delta: float, en_movimiento: bool, corriendo: bool) -> void:
	if not is_inside_tree() or get_tree().paused:
		return
	if not habilitado or not en_movimiento or pasos.is_empty():
		detener()
		return
	var intervalo := intervalo_correr if corriendo else intervalo_caminar
	if _intervalo_anterior > 0.0 and not is_equal_approx(intervalo, _intervalo_anterior):
		_restante *= intervalo / _intervalo_anterior
	_intervalo_anterior = intervalo
	_restante -= delta
	if _restante > 0.0:
		return
	_restante = intervalo
	var indice := _azar.randi_range(0, pasos.size() - 1)
	if pasos.size() > 1 and indice == _ultimo_indice:
		indice = (indice + _azar.randi_range(1, pasos.size() - 1)) % pasos.size()
	if pasos[indice] == null:
		return
	_ultimo_indice = indice
	stop()
	stream = pasos[indice]
	pitch_scale = tono_base * _azar.randf_range(1.0 - variacion_tono, 1.0 + variacion_tono)
	play()
	paso_reproducido.emit(indice)


func detener() -> void:
	if playing:
		stop()
	_restante = 0.0
	_intervalo_anterior = 0.0
