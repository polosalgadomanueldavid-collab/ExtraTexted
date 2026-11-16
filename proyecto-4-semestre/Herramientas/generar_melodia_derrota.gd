extends SceneTree

const FRECUENCIA_MUESTREO := 44100
const DURACION_TOTAL := 36.4
const RUTA_SALIDA := "res://Audios/melodia_derrota_sutil.wav"


func _initialize() -> void:
	# Motivo menor descendente y rítmico: insiste en la caída sin sonar de terror.
	var motivo: Array[float] = [293.66, 233.08, 220.00, 174.61, 196.00, 174.61, 155.56, 146.83]
	var transposiciones: Array[int] = [0, 0, -2, -2, -3, -3, -5, -5, -7, -12]
	var eventos: Array[Dictionary] = []
	for frase: int in range(transposiciones.size()):
		for paso: int in range(motivo.size()):
			var inicio := float(frase) * 3.6 + float(paso) * 0.45
			var intensidad := 0.22 - float(frase) * 0.012
			var frecuencia := motivo[paso] * pow(2.0, float(transposiciones[frase]) / 12.0)
			var duracion := 1.45 if frase == transposiciones.size() - 1 and paso == motivo.size() - 1 else 0.58
			eventos.append(_nota(inicio, duracion, frecuencia, intensidad, 0.006, 0.20))
			# Golpe grave breve en el pulso para reforzar el peso de la frase.
			if paso == 0 or paso == 4:
				eventos.append(_nota(inicio, 0.22, frecuencia * 0.5, intensidad * 0.42, 0.003, 0.14))

	var cantidad := int(DURACION_TOTAL * FRECUENCIA_MUESTREO)
	var mezcla := PackedFloat32Array()
	mezcla.resize(cantidad)
	for evento: Dictionary in eventos:
		if evento.has("tono"):
			_renderizar_ruido(mezcla, evento, int(float(evento.inicio) * 100000.0) + 7163)
		else:
			_renderizar_nota(mezcla, evento)

	# Sin eco ni capas ambientales: la melodía queda al frente y es fácil de reconocer.
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
		envolvente *= minf(1.0, restante / maxf(salida, 0.001)) * exp(-0.72 * tiempo)
		var fase := TAU * frecuencia * tiempo
		var timbre: float
		if fondo:
			timbre = sin(fase) + sin(fase * 2.01) * 0.16 + sin(fase * 0.501) * 0.10
		else:
			# Ataque de piano seco y definido; la armonía menor da una caída emocional clara.
			timbre = sin(fase) * 0.68
			timbre += sin(fase * 2.0) * 0.23 * exp(-tiempo * 1.8)
			timbre += sin(fase * 3.0) * 0.08 * exp(-tiempo * 3.0)
			timbre += sin(fase * 4.0) * 0.025 * exp(-tiempo * 4.0)
		mezcla[indice] += timbre * amplitud * envolvente


func _ruido(inicio: float, duracion: float, amplitud: float, ataque: float, salida: float, tono: float) -> Dictionary:
	return {"inicio": inicio, "duracion": duracion, "amplitud": amplitud, "ataque": ataque, "salida": salida, "tono": tono}


func _renderizar_ruido(mezcla: PackedFloat32Array, evento: Dictionary, semilla: int) -> void:
	var inicio := int(float(evento.inicio) * FRECUENCIA_MUESTREO)
	var muestras := int(float(evento.duracion) * FRECUENCIA_MUESTREO)
	var amplitud := float(evento.amplitud)
	var ataque := float(evento.ataque)
	var salida := float(evento.salida)
	var tono := float(evento.tono)
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	var filtro := 0.0
	for local: int in range(muestras):
		var indice := inicio + local
		if indice >= mezcla.size():
			break
		var tiempo := float(local) / FRECUENCIA_MUESTREO
		var restante := float(muestras - local) / FRECUENCIA_MUESTREO
		var envolvente := minf(1.0, tiempo / maxf(ataque, 0.001))
		envolvente *= minf(1.0, restante / maxf(salida, 0.001))
		var blanco := azar.randf_range(-1.0, 1.0)
		filtro += (blanco - filtro) * (0.035 + tono * 0.15)
		mezcla[indice] += (blanco * (1.0 - tono) + filtro * tono) * amplitud * envolvente


func _aplicar_eco(mezcla: PackedFloat32Array, retraso: float, ganancia: float) -> void:
	var desplazamiento := int(retraso * FRECUENCIA_MUESTREO)
	for indice: int in range(desplazamiento, mezcla.size()):
		mezcla[indice] += mezcla[indice - desplazamiento] * ganancia


func _fundido_maestro(indice: int, cantidad: int) -> float:
	var tiempo := float(indice) / FRECUENCIA_MUESTREO
	var restante := float(cantidad - indice) / FRECUENCIA_MUESTREO
	return minf(1.0, tiempo / 0.08) * minf(1.0, restante / 0.75)
