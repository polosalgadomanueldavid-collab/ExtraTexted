extends SceneTree

const FRECUENCIA_MUESTREO := 44100
const DURACION_TOTAL := 16.8
const RUTA_SALIDA := "res://Audios/melodia_derrota_sutil.wav"


func _initialize() -> void:
	var eventos: Array[Dictionary] = [
		# Una caída cromática breve: reconocible como derrota, pero sin caricatura.
		_nota(0.15, 0.72, 392.00, 0.16, 0.010, 0.38),
		_nota(0.78, 0.72, 369.99, 0.15, 0.010, 0.40),
		_nota(1.41, 0.78, 349.23, 0.15, 0.012, 0.43),
		_nota(2.08, 1.10, 329.63, 0.16, 0.014, 0.58),
		# La frase se desploma una octava y deja respirar el silencio.
		_nota(2.82, 1.35, 246.94, 0.13, 0.018, 0.72),
		_nota(3.58, 1.55, 196.00, 0.12, 0.022, 0.90),
		_nota(4.42, 1.75, 164.81, 0.12, 0.025, 1.05),
		# Acordes muy suaves que acompañan el relevo y el resumen final.
		_nota(5.55, 2.20, 146.83, 0.075, 0.18, 1.20, true),
		_nota(5.55, 2.20, 220.00, 0.055, 0.20, 1.15, true),
		_nota(5.55, 2.20, 293.66, 0.047, 0.16, 1.05, true),
		_nota(7.42, 2.15, 130.81, 0.072, 0.18, 1.15, true),
		_nota(7.42, 2.15, 196.00, 0.052, 0.20, 1.10, true),
		_nota(7.42, 2.15, 261.63, 0.044, 0.16, 1.00, true),
		_nota(9.18, 2.75, 110.00, 0.078, 0.22, 1.45, true),
		_nota(9.18, 2.75, 164.81, 0.054, 0.24, 1.35, true),
		_nota(9.18, 2.75, 233.08, 0.046, 0.20, 1.25, true),
		# Última nota sin resolución completa: la derrota queda pesando.
		_nota(10.55, 1.65, 146.83, 0.068, 0.08, 1.20, true),
		# Una segunda respiración prolonga el cierre sin repetir la frase inicial.
		_nota(11.82, 2.25, 98.00, 0.070, 0.24, 1.30, true),
		_nota(11.82, 2.25, 146.83, 0.048, 0.26, 1.25, true),
		_nota(11.82, 2.25, 196.00, 0.040, 0.22, 1.15, true),
		# Cadencia final grave y contenida; se apaga lentamente en lugar de cortar.
		_nota(13.62, 2.85, 73.42, 0.075, 0.28, 1.55, true),
		_nota(13.62, 2.85, 110.00, 0.052, 0.30, 1.45, true),
		_nota(13.62, 2.85, 146.83, 0.044, 0.26, 1.35, true),
		_nota(14.08, 2.30, 220.00, 0.034, 0.22, 1.30, true),
	]

	var cantidad := int(DURACION_TOTAL * FRECUENCIA_MUESTREO)
	var mezcla := PackedFloat32Array()
	mezcla.resize(cantidad)
	for evento: Dictionary in eventos:
		_renderizar_nota(mezcla, evento)

	# Dos repeticiones discretas crean espacio sin convertirla en una pieza épica.
	_aplicar_eco(mezcla, 0.19, 0.17)
	_aplicar_eco(mezcla, 0.37, 0.09)
	var datos := PackedByteArray()
	datos.resize(cantidad * 2)
	for indice: int in range(cantidad):
		var salida := tanh(mezcla[indice] * 1.18) * _fundido_maestro(indice, cantidad)
		datos.encode_s16(indice * 2, int(clampf(salida, -0.96, 0.96) * 32767.0))

	var pista := AudioStreamWAV.new()
	pista.format = AudioStreamWAV.FORMAT_16_BITS
	pista.mix_rate = FRECUENCIA_MUESTREO
	pista.stereo = false
	pista.data = datos
	var ruta_absoluta := ProjectSettings.globalize_path(RUTA_SALIDA.trim_suffix(".wav"))
	var error := pista.save_to_wav(ruta_absoluta)
	if error != OK:
		push_error("No se pudo guardar la melodía de derrota: %s" % error_string(error))
		quit(1)
		return
	print("Melodía de derrota creada en %s" % RUTA_SALIDA)
	quit()


func _nota(inicio: float, duracion: float, frecuencia: float, amplitud: float, ataque: float, salida: float, fondo: bool = false) -> Dictionary:
	return {
		"inicio": inicio,
		"duracion": duracion,
		"frecuencia": frecuencia,
		"amplitud": amplitud,
		"ataque": ataque,
		"salida": salida,
		"fondo": fondo,
	}


func _renderizar_nota(mezcla: PackedFloat32Array, evento: Dictionary) -> void:
	var inicio := int(float(evento.inicio) * FRECUENCIA_MUESTREO)
	var muestras := int(float(evento.duracion) * FRECUENCIA_MUESTREO)
	var frecuencia := float(evento.frecuencia)
	var amplitud := float(evento.amplitud)
	var ataque := float(evento.ataque)
	var salida := float(evento.salida)
	var fondo := bool(evento.fondo)
	for local: int in range(muestras):
		var indice := inicio + local
		if indice >= mezcla.size():
			break
		var tiempo := float(local) / FRECUENCIA_MUESTREO
		var restante := float(muestras - local) / FRECUENCIA_MUESTREO
		var envolvente := minf(1.0, tiempo / maxf(ataque, 0.001))
		envolvente *= minf(1.0, restante / maxf(salida, 0.001))
		var fase := TAU * frecuencia * tiempo
		var timbre: float
		if fondo:
			timbre = sin(fase) + sin(fase * 2.01) * 0.16 + sin(fase * 0.501) * 0.10
		else:
			# Piano apagado: ataque claro, armónicos que desaparecen rápidamente.
			timbre = sin(fase) * 0.74
			timbre += sin(fase * 2.0) * 0.20 * exp(-tiempo * 2.4)
			timbre += sin(fase * 3.01) * 0.09 * exp(-tiempo * 3.2)
			timbre += sin(fase * 0.499) * 0.06
		mezcla[indice] += timbre * amplitud * envolvente


func _aplicar_eco(mezcla: PackedFloat32Array, retraso: float, ganancia: float) -> void:
	var desplazamiento := int(retraso * FRECUENCIA_MUESTREO)
	for indice: int in range(desplazamiento, mezcla.size()):
		mezcla[indice] += mezcla[indice - desplazamiento] * ganancia


func _fundido_maestro(indice: int, cantidad: int) -> float:
	var tiempo := float(indice) / FRECUENCIA_MUESTREO
	var restante := float(cantidad - indice) / FRECUENCIA_MUESTREO
	return minf(1.0, tiempo / 0.08) * minf(1.0, restante / 0.75)
