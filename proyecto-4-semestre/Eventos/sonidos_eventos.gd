extends Node
## Ambiente original de los eventos; hereda la pausa y se libera con la oficina.

const SonidosMesas := preload("res://UI/Despacho/sonidos_mesas.gd")
const RETUMBO := preload("res://Audios/Eventos/terremoto_retumbo.wav")
const CRUJIDOS := preload("res://Audios/Eventos/terremoto_crujidos.wav")
const RUPTURA := preload("res://Audios/Eventos/terremoto_ruptura.wav")
const CIERRE := preload("res://Audios/Eventos/terremoto_cierre.wav")
const CORTE := preload("res://Audios/Eventos/apagon_corte.wav")
const EMERGENCIA := preload("res://Audios/Eventos/apagon_ambiente.wav")

var retumbo: AudioStreamPlayer
var crujidos: AudioStreamPlayer
var impacto: AudioStreamPlayer
var corte: AudioStreamPlayer
var ambiente: AudioStreamPlayer


func _ready() -> void:
	name = "SonidosEventos"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	retumbo = SonidosMesas.crear_reproductor(self, "Retumbo", RETUMBO, -28.0, true)
	crujidos = SonidosMesas.crear_reproductor(self, "Crujidos", CRUJIDOS, -32.0, true)
	impacto = SonidosMesas.crear_reproductor(self, "Suelo", RUPTURA, -13.0)
	corte = SonidosMesas.crear_reproductor(self, "CorteElectrico", CORTE, -12.0)
	ambiente = SonidosMesas.crear_reproductor(self, "Emergencia", EMERGENCIA, -23.0, true)


func iniciar_terremoto() -> void:
	detener()
	actualizar_terremoto(0.14, 0.14)
	retumbo.play()
	crujidos.play()


func actualizar_terremoto(intensidad: float, intensidad_local: float) -> void:
	# En descanso se oye el edificio a distancia, sin sacudir la zona segura.
	var peso := clampf(intensidad * 0.22 + intensidad_local * 0.78, 0.0, 1.0)
	retumbo.volume_db = linear_to_db(maxf(0.0001, db_to_linear(-10.0) * peso))
	crujidos.volume_db = linear_to_db(maxf(0.0001, db_to_linear(-16.0) * peso * peso))
	retumbo.pitch_scale = lerpf(0.85, 1.0, intensidad)


func romper_suelo() -> void:
	impacto.stream = RUPTURA
	impacto.volume_db = -13.0
	impacto.play()


func cerrar_suelo() -> void:
	impacto.stream = CIERRE
	impacto.volume_db = -19.0
	impacto.play()


func iniciar_apagon() -> void:
	detener()
	corte.play()
	ambiente.play()


func detener() -> void:
	for hijo: Node in get_children():
		if hijo is AudioStreamPlayer:
			(hijo as AudioStreamPlayer).stop()


func _exit_tree() -> void:
	detener()
