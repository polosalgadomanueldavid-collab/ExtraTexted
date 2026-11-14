class_name MusicaPartida
extends AudioStreamPlayer

const PISTA_CLATTER: AudioStream = preload("res://Audios/Careful_With_The_Clatter.mp3")
const PISTA_DONUTS: AudioStream = preload("res://Audios/Three_Donuts_One_Badge.mp3")
const PISTA_KITCHEN: AudioStream = preload("res://Audios/The_Kitchen_Collapse.mp3")
const PISTA_CLOCKWORK: AudioStream = preload("res://Audios/Feeding_The_Clockwork_Mouth.mp3")
const VOLUMEN_NORMAL_DB := -6.0
const VOLUMEN_SILENCIO_DB := -60.0
const DURACION_FUNDIDO := 2.0

var _musica_calma_baja := false
var _en_rango := false
var _indice_pista_actual := -1
var _pista_uno: AudioStream
var _pista_dos: AudioStream
var _fundido: Tween


func _ready() -> void:
	bus = "Musica"
	finished.connect(_al_terminar_pista)


func configurar(sistema: SistemaDespacho, para_calma_baja: bool = false) -> void:
	_musica_calma_baja = para_calma_baja
	_pista_uno = PISTA_KITCHEN if para_calma_baja else PISTA_CLATTER
	_pista_dos = PISTA_CLOCKWORK if para_calma_baja else PISTA_DONUTS
	if not sistema.calma_actualizada.is_connected(_al_actualizar_calma):
		sistema.calma_actualizada.connect(_al_actualizar_calma)
	_al_actualizar_calma(sistema.calma_operativa)


func _al_actualizar_calma(nueva_calma: int) -> void:
	var dentro_del_rango := nueva_calma < 50 if _musica_calma_baja else nueva_calma > 50
	if dentro_del_rango == _en_rango:
		return
	_en_rango = dentro_del_rango

	if _en_rango:
		if playing:
			_detener_fundido()
			_fundir_a(VOLUMEN_NORMAL_DB)
		else:
			_iniciar_pista_aleatoria()
	elif playing:
		_fundir_a(VOLUMEN_SILENCIO_DB, true)


func _iniciar_pista_aleatoria() -> void:
	_indice_pista_actual = randi_range(0, 1)
	_reproducir_pista_actual()


func _reproducir_pista_actual() -> void:
	stream = _pista_uno if _indice_pista_actual == 0 else _pista_dos
	volume_db = VOLUMEN_SILENCIO_DB
	play()
	_fundir_a(VOLUMEN_NORMAL_DB)


func _al_terminar_pista() -> void:
	if not _en_rango:
		return
	_indice_pista_actual = 1 - _indice_pista_actual
	_reproducir_pista_actual()


func _fundir_a(volumen_objetivo_db: float, detener_al_final: bool = false) -> void:
	_detener_fundido()
	_fundido = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fundido.tween_property(self, "volume_db", volumen_objetivo_db, DURACION_FUNDIDO).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if detener_al_final:
		_fundido.finished.connect(_detener_si_silenciosa)


func _detener_fundido() -> void:
	if is_instance_valid(_fundido) and _fundido.is_running():
		_fundido.kill()
	_fundido = null


func _detener_si_silenciosa() -> void:
	if not _en_rango:
		stop()
