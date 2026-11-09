extends Node
## Sonidos originales del gabinete. El panel controla cuándo iniciar y detener el motor.

const SonidosMesas := preload("res://UI/Despacho/sonidos_mesas.gd")
const GABINETE := preload("res://Audios/Apagon/gabinete.wav")
const PALANCA := preload("res://Audios/Apagon/palanca.wav")
const CABLE_TOMAR := preload("res://Audios/Apagon/cable_tomar.wav")
const CABLE_CONECTAR := preload("res://Audios/Apagon/cable_conectar.wav")
const RECHAZO := preload("res://Audios/Apagon/rechazo.wav")
const FASE_FIJAR := preload("res://Audios/Apagon/fase_fijar.wav")
const MOTOR_FASES := preload("res://Audios/Apagon/motor_fases.wav")
const RESTAURACION := preload("res://Audios/Apagon/restauracion.wav")

var gabinete: AudioStreamPlayer
var palanca: AudioStreamPlayer
var cable: AudioStreamPlayer
var rechazo: AudioStreamPlayer
var fase: AudioStreamPlayer
var motor: AudioStreamPlayer
var restauracion: AudioStreamPlayer
var _azar := RandomNumberGenerator.new()


func _ready() -> void:
	name = "SonidosCircuitos"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_azar.randomize()
	gabinete = SonidosMesas.crear_reproductor(self, "Gabinete", GABINETE, -13.0)
	palanca = SonidosMesas.crear_reproductor(self, "Palanca", PALANCA, -12.0)
	cable = SonidosMesas.crear_reproductor(self, "Cable", CABLE_TOMAR, -13.0)
	rechazo = SonidosMesas.crear_reproductor(self, "Rechazo", RECHAZO, -17.0)
	fase = SonidosMesas.crear_reproductor(self, "FaseFijada", FASE_FIJAR, -14.0)
	motor = SonidosMesas.crear_reproductor(self, "MotorFases", MOTOR_FASES, -23.0, true)
	restauracion = SonidosMesas.crear_reproductor(self, "Restauracion", RESTAURACION, -13.0)


func abrir() -> void:
	detener()
	_reproducir(gabinete, GABINETE, 1.05)


func cerrar() -> void:
	detener()
	_reproducir(gabinete, GABINETE, 0.88)


func interruptor(activo: bool) -> void:
	_reproducir(palanca, PALANCA, 1.04 if activo else 0.94)


func tomar_cable() -> void:
	_reproducir(cable, CABLE_TOMAR)


func conectar_cable() -> void:
	_reproducir(cable, CABLE_CONECTAR)


func error() -> void:
	_reproducir(rechazo, RECHAZO)


func fijar_fase() -> void:
	_reproducir(fase, FASE_FIJAR)


func motor_fases(activo: bool) -> void:
	if not is_instance_valid(motor):
		return
	if activo:
		if not motor.playing:
			motor.play()
	else:
		motor.stop()


func completar() -> void:
	detener()
	_reproducir(restauracion, RESTAURACION, 1.0, 0.0)


func detener() -> void:
	for hijo: Node in get_children():
		if hijo is AudioStreamPlayer:
			(hijo as AudioStreamPlayer).stop()


func _reproducir(reproductor: AudioStreamPlayer, pista: AudioStream, tono: float = 1.0, variacion: float = 0.025) -> void:
	if not is_instance_valid(reproductor) or not is_inside_tree() or get_tree().paused:
		return
	reproductor.stop()
	reproductor.stream = pista
	reproductor.pitch_scale = tono * _azar.randf_range(1.0 - variacion, 1.0 + variacion)
	reproductor.play()


func _exit_tree() -> void:
	detener()
