extends SceneTree
## Verifica anclajes del esqueleto real, pausa y contactos, no las curvas de datos.
## --headless --fixed-fps 60 --script res://Pruebas/ZonaDescanso/prueba_coreografias_avatar.gd
var oficina: Node3D
var jugador
var errores := 0
var comprobaciones := 0
var contactos := 0

func _initialize() -> void:
	_probar.call_deferred()

func _probar() -> void:
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	await _cuadros(8)
	root.get_node("MenuGlobal").cerrar_ayuda()
	paused = false
	jugador = oficina.jugador
	for reloj: Timer in [oficina.temporizador_denuncias, oficina.temporizador_bloqueos, oficina.temporizador_eventos, oficina.computador.timer_nuevo_problema]:
		reloj.stop()
	oficina.anuncios.detener()
	jugador.global_position = Vector3(-1, .38, 8.5)
	jugador.visual.rotation.y = 0
	await _cuadros(65)
	var origen: Vector3 = jugador.global_position
	var piso: float = minf(jugador.gestos.posicion_pie("L").y, jugador.gestos.posicion_pie("R").y)
	for tipo: StringName in [&"control_tierra", &"control_agua", &"control_aire", &"control_fuego"]:
		contactos = 0
		_verificar(jugador.ejecutar_gesto(tipo, _contactar), "Inicia " + tipo)
		var poderes = oficina.get_node("MaquinaExpendedora").poderes
		poderes.animar_elemento(tipo)
		var efecto = poderes._elemento
		var muestras: Array[Dictionary] = []
		var error_apoyo := 0.0
		var error_cuerpo := 0.0
		var fases := [.14, .24, .32, .46, .56, .72, .90]
		while jugador.realizando_gesto():
			await process_frame
			var l: Vector3 = jugador.gestos.posicion_pie("L")
			var r: Vector3 = jugador.gestos.posicion_pie("R")
			error_apoyo = maxf(error_apoyo, absf(minf(l.y, r.y) - piso))
			error_cuerpo = maxf(error_cuerpo, jugador.global_position.distance_to(origen))
			if muestras.size() < fases.size() and jugador.gestos.tiempo / 3.6 >= fases[muestras.size()]:
				muestras.append({"l": l, "r": r, "mano_l": jugador.gestos.mano_izquierda.global_position, "mano_r": jugador.gestos.mano_derecha.global_position, "frente": jugador.gestos.pie_izquierdo.global_basis.x.normalized()})
				if muestras.size() == 3:
					var tiempo: float = jugador.gestos.tiempo
					var tiempo_efecto: float = efecto.tiempo
					paused = true
					await _cuadros(10)
					_verificar(is_equal_approx(tiempo, jugador.gestos.tiempo), "La pausa conserva la fase de " + tipo)
					_verificar(is_equal_approx(tiempo_efecto, efecto.tiempo), "La pausa conserva el efecto de " + tipo)
					paused = false
				if tipo == &"control_fuego" and muestras.size() == 2:
					var llama: Node3D = efecto._llamas[1]
					var direccion: Vector3 = jugador.gestos.direcciones_antebrazos["R"]
					_verificar(llama.visible and llama.global_position.distance_to(jugador.gestos.mano_derecha.global_position) < .05 and llama.global_basis.y.normalized().dot(direccion) > .95, "El chorro de fuego nace de la mano y sigue el puñetazo")
				if tipo == &"control_fuego" and muestras.size() == 5:
					var llama: Node3D = efecto._llamas[6]
					_verificar(llama.visible and llama.global_position.distance_to(jugador.gestos.posicion_pie("R")) < .05, "La patada emite fuego desde el pie")
		_verificar(contactos == 1, "Un solo contacto resolutivo en " + tipo)
		_verificar(error_cuerpo < .01, "La coreografía no mueve las colisiones: " + tipo)
		_verificar(error_apoyo < .025, "Conserva un pie de apoyo: " + tipo)
		match tipo:
			&"control_tierra":
				_verificar(muestras[1].l.y - muestras[2].l.y > .025, "Primera pisada: eleva y baja el pie izquierdo")
				_verificar(muestras[3].r.y - muestras[4].r.y > .025, "Segunda pisada: eleva y baja el pie derecho")
			&"control_agua":
				_verificar(muestras[2].mano_l.y - muestras[0].mano_l.y > .15 and muestras[3].mano_r.y - muestras[0].mano_r.y > .15, "Ambos brazos dibujan barridos amplios de agua")
			&"control_aire":
				# Las manos alternan arriba/abajo; su separación ya no representa
				# la orientación del cuerpo. Medir el pie que pivota con la raíz.
				var inicial: Vector3 = muestras[0].frente
				var girado: Vector3 = muestras[3].frente
				_verificar(inicial.dot(girado) < 0, "El giro de aire pasa por la orientación opuesta")
				_verificar(muestras[0].mano_l.y > muestras[0].mano_r.y + .05 and muestras[2].mano_r.y > muestras[2].mano_l.y + .05, "Aire alterna los barridos alto y bajo de las palmas")
			&"control_fuego":
				_verificar(muestras[4].r.y - muestras[0].r.y > .05, "La patada de fuego levanta el pie")
		await _cuadros(20)
		_verificar(not is_instance_valid(efecto), "El efecto se retira al terminar: " + tipo)
		_verificar(not jugador.input_locked and absf(minf(jugador.gestos.posicion_pie("L").y, jugador.gestos.posicion_pie("R").y) - piso) < .025, "Recupera postura y controles: " + tipo)
		jugador.ejecutar_gesto(tipo, _contactar)
		await _cuadros(30)
		jugador.cancelar_gesto()
		await _cuadros(5)
		_verificar(contactos == 1 and not jugador.input_locked, "Cancelar no resuelve ni bloquea: " + tipo)
	oficina.queue_free()
	await _cuadros(8)
	print("[COREOGRAFIAS_AVATAR] %d comprobaciones, %d errores" % [comprobaciones, errores])
	quit(0 if errores == 0 else 1)

func _contactar() -> void:
	contactos += 1

func _cuadros(cantidad: int) -> void:
	for i in cantidad:
		await process_frame

func _verificar(condicion: bool, mensaje: String) -> void:
	comprobaciones += 1
	if condicion:
		print("OK: " + mensaje)
	else:
		errores += 1
		push_error("[COREOGRAFIAS_AVATAR] " + mensaje)
