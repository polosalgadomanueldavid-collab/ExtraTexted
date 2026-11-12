extends Node
## Catálogo compartido y sonidos de las mesas que no tienen panel propio.

const HOJAS := [
	preload("res://Audios/Mesas/pasar_hoja_1.ogg"),
	preload("res://Audios/Mesas/pasar_hoja_2.ogg"),
	preload("res://Audios/Mesas/pasar_hoja_3.ogg")
]
const ARCHIVAR := preload("res://Audios/Mesas/archivar_hoja.ogg")
const ESCANER := preload("res://Audios/Mesas/escaner_barrido.wav")
const RECHAZO := preload("res://Audios/Mesas/rechazo.wav")
const IMPRESORA := preload("res://Audios/Mesas/impresora.wav")
const ATASCO := preload("res://Audios/Mesas/impresora_atasco.wav")
const REPARAR := preload("res://Audios/Mesas/reparar_impresora.wav")
const TECLAS := preload("res://Audios/Mesas/desencriptado.wav")
const LISTO := preload("res://Audios/Mesas/archivo_listo.wav")
const BIENESTAR := preload("res://Audios/Mesas/bienestar.wav")

var impresora: AudioStreamPlayer
var seguridad: AudioStreamPlayer
var aviso_seguridad: AudioStreamPlayer
var bienestar: AudioStreamPlayer


func _ready() -> void:
	name = "SonidosMesas"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	impresora = crear_reproductor(self, "Impresora", IMPRESORA, -9.0)
	seguridad = crear_reproductor(self, "Desencriptado", TECLAS, -11.0, true)
	aviso_seguridad = crear_reproductor(self, "ArchivoListo", LISTO, -13.0)
	bienestar = crear_reproductor(self, "Bienestar", BIENESTAR, -10.0)


static func crear_reproductor(padre: Node, nombre: String, pista: AudioStream, volumen: float, bucle: bool = false) -> AudioStreamPlayer:
	var reproductor := AudioStreamPlayer.new()
	reproductor.name = nombre
	reproductor.process_mode = Node.PROCESS_MODE_PAUSABLE
	reproductor.bus = "Interacciones"
	reproductor.volume_db = volumen
	reproductor.stream = pista
	if bucle and pista is AudioStreamWAV:
		var repetida := pista.duplicate() as AudioStreamWAV
		repetida.loop_begin = 0
		repetida.loop_end = roundi(repetida.get_length() * repetida.mix_rate)
		repetida.loop_mode = AudioStreamWAV.LOOP_FORWARD
		reproductor.stream = repetida
	padre.add_child(reproductor)
	return reproductor


func imprimir() -> void:
	_reproducir_impresora(IMPRESORA)


func atascar_impresora() -> void:
	_reproducir_impresora(ATASCO)


func reparar_impresora() -> void:
	_reproducir_impresora(REPARAR)


func _reproducir_impresora(pista: AudioStream) -> void:
	impresora.stop()
	impresora.stream = pista
	impresora.play()


func iniciar_seguridad() -> void:
	aviso_seguridad.stop()
	if not seguridad.playing:
		seguridad.play()


func terminar_seguridad() -> void:
	seguridad.stop()
	aviso_seguridad.play()


func cancelar_seguridad() -> void:
	seguridad.stop()
	aviso_seguridad.stop()
