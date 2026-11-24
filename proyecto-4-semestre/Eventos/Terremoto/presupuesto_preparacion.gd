extends RefCounted
## Presupuesto compartido por planificación y montaje. Todo se ejecuta en el hilo principal.
const MICROSEGUNDOS := 3000
var cancelado := false
var cuadros := 0
var maximo_lote_usec := 0
var total_lotes_usec := 0
var lotes_sobre_4ms := 0
var _inicio := 0
var arbol: SceneTree

func paso(reserva_usec := 0) -> void:
	if _inicio == 0: _inicio = Time.get_ticks_usec()
	var transcurrido := Time.get_ticks_usec() - _inicio
	if transcurrido + reserva_usec < MICROSEGUNDOS and not arbol.paused:
		return
	maximo_lote_usec = maxi(maximo_lote_usec, transcurrido)
	total_lotes_usec += transcurrido
	if transcurrido > 4000: lotes_sobre_4ms += 1
	cuadros += 1
	await arbol.process_frame
	while arbol.paused and not cancelado:
		await arbol.process_frame
	_inicio = Time.get_ticks_usec()
