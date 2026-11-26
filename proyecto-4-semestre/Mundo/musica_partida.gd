class_name MusicaPartida
extends AudioStreamPlayer

const PISTA_CLATTER: AudioStream = preload("res://Audios/Careful_With_The_Clatter.mp3")
const PISTA_DONUTS: AudioStream = preload("res://Audios/Three_Donuts_One_Badge.mp3")
const PISTA_KITCHEN: AudioStream = preload("res://Audios/The_Kitchen_Collapse.mp3")
const PISTA_CLOCKWORK: AudioStream = preload("res://Audios/Feeding_The_Clockwork_Mouth.mp3")
const VOLUMEN_NORMAL_DB := -6.0
const VOLUMEN_ENTRADA_DB := -22.0
const VOLUMEN_SILENCIO_DB := -60.0
const DURACION_CRUCE := 1.8
const DURACION_CAMBIO := 0.7

var _musica_calma_baja := false
var _en_rango := false
var _indice_pista_actual := -1
var _pista_uno: AudioStream
var _pista_dos: AudioStream
var _alterno: AudioStreamPlayer
var _activo: AudioStreamPlayer
var _fundidos: Array[Tween] = []
var _cruzando := false


func _ready() -> void:
	bus = "Musica"
	_activo = self
	_alterno = AudioStreamPlayer.new()
	_alterno.name = "PistaSiguiente"
	_alterno.bus = "Musica"
	add_child(_alterno)
	finished.connect(_al_terminar_pista)
	_alterno.finished.connect(_al_terminar_pista)
	set_process(false)


func configurar(sistema: SistemaDespacho, para_calma_baja: bool = false) -> void:
	_musica_calma_baja = para_calma_baja
	_pista_uno = PISTA_KITCHEN if para_calma_baja else PISTA_CLATTER
	_pista_dos = PISTA_CLOCKWORK if para_calma_baja else PISTA_DONUTS
	if not sistema.calma_actualizada.is_connected(_al_actualizar_calma):
		sistema.calma_actualizada.connect(_al_actualizar_calma)
	_al_actualizar_calma(sistema.calma_operativa)


func _al_actualizar_calma(nueva_calma: int) -> void:
	var dentro_del_rango := nueva_calma < 50 if _musica_calma_baja else nueva_calma >= 50
	if dentro_del_rango == _en_rango:
		return
	_en_rango = dentro_del_rango
	_cancelar_fundidos()
	if _en_rango:
		_cruzando = false
		var inactivo := _otro_reproductor()
		if inactivo.playing:
			_fundir(inactivo, VOLUMEN_SILENCIO_DB, DURACION_CAMBIO, true)
		if _activo.playing:
			_fundir(_activo, VOLUMEN_NORMAL_DB, DURACION_CAMBIO)
		else:
			_indice_pista_actual = randi_range(0, 1)
			_iniciar_en(_activo, _indice_pista_actual)
			_fundir(_activo, VOLUMEN_NORMAL_DB, DURACION_CAMBIO)
		set_process(true)
	else:
		set_process(false)
		for reproductor in [self, _alterno]:
			if reproductor.playing:
				_fundir(reproductor, VOLUMEN_SILENCIO_DB, DURACION_CAMBIO, true)


func _process(_delta: float) -> void:
	if not _en_rango or _cruzando or not _activo.playing or _activo.stream == null:
		return
	var restante := _activo.stream.get_length() - _activo.get_playback_position()
	if restante <= DURACION_CRUCE and restante > 0.0:
		_cruzar_pistas()


func _cruzar_pistas() -> void:
	_cruzando = true
	var saliente := _activo
	var entrante := _otro_reproductor()
	_indice_pista_actual = 1 - _indice_pista_actual
	_iniciar_en(entrante, _indice_pista_actual)
	_fundir(entrante, VOLUMEN_NORMAL_DB, DURACION_CRUCE)
	_fundir(saliente, VOLUMEN_SILENCIO_DB, DURACION_CRUCE, true)
	_activo = entrante
	get_tree().create_timer(DURACION_CRUCE).timeout.connect(func() -> void:
		_cruzando = false
		_al_terminar_pista()
	)


func _iniciar_en(reproductor: AudioStreamPlayer, indice: int) -> void:
	reproductor.stream = _pista_uno if indice == 0 else _pista_dos
	reproductor.volume_db = VOLUMEN_ENTRADA_DB
	reproductor.play()


func _otro_reproductor() -> AudioStreamPlayer:
	return _alterno if _activo == self else self


func _al_terminar_pista() -> void:
	if not _en_rango or _cruzando or _activo.playing:
		return
	_indice_pista_actual = 1 - _indice_pista_actual
	_iniciar_en(_activo, _indice_pista_actual)
	_fundir(_activo, VOLUMEN_NORMAL_DB, DURACION_CAMBIO)


func detener_para_final() -> void:
	_en_rango = false
	set_process(false)
	_cancelar_fundidos()
	# La pantalla final pausa el árbol; la salida de la música debe seguir sonando.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for reproductor in [self, _alterno]:
		if reproductor.playing:
			_fundir(reproductor, VOLUMEN_SILENCIO_DB, DURACION_CAMBIO, true)


func _fundir(reproductor: AudioStreamPlayer, destino: float, duracion: float, detener := false) -> void:
	if not reproductor.playing:
		return
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(reproductor, "volume_db", destino, duracion).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if detener:
		tween.finished.connect(func() -> void:
			if not _en_rango or reproductor != _activo:
				reproductor.stop()
		)
	_fundidos.append(tween)


func _cancelar_fundidos() -> void:
	for tween in _fundidos:
		if is_instance_valid(tween) and tween.is_running():
			tween.kill()
	_fundidos.clear()
