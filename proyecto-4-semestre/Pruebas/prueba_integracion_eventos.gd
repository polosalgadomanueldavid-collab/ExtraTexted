extends SceneTree
## Comprueba la convivencia del incendio con el tutorial y el indicador de luz.
## --headless --fixed-fps 60 --script res://Pruebas/prueba_integracion_eventos.gd

var oficina: Node3D
var errores := 0


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	var menu := root.get_node("MenuGlobal")
	menu.omitir_tutorial_siguiente_partida = true
	oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	await _fisicas(12)
	menu.cerrar_ayuda()
	oficina._recibir_denuncia_aleatoria()
	oficina.temporizador_denuncias.stop()
	oficina.computador.timer_nuevo_problema.stop()
	oficina.sistema_despacho.set_process(false)
	var apagon: Node = oficina.evento_apagon
	var incendio: Node3D = oficina.evento_incendio
	var reloj: Timer = oficina.temporizador_eventos
	_verificar(not oficina._tutorial_apagon_mostrado, "Una partida nueva tiene pendiente la guía del apagón")
	_verificar(apagon.iniciar_apagon(), "El primer apagón inicia con el coordinador compartido")
	_verificar(paused and menu.panel_ayuda.tutorial_apagon.is_visible_in_tree(), "El primer apagón abre el tutorial nuevo y pausa la partida")
	_verificar(menu.panel_ayuda.boton_cerrar.text == "ENTENDIDO" and not menu.fondo_modal.visible, "La guía conserva el diseño del compañero y deja ver la oficina")
	_verificar(reloj.is_stopped() and not oficina._iniciar_incendio(), "El tutorial no permite iniciar un incendio paralelo")
	var tiempo_bloqueos: float = oficina.temporizador_bloqueos.time_left
	var demostracion: Node = menu.panel_ayuda.tutorial_apagon.find_child("DemostracionCircuitos", true, false)
	var circuito_inicial: int = demostracion.tipo_actual
	await _fisicas(490)
	_verificar(is_equal_approx(tiempo_bloqueos, oficina.temporizador_bloqueos.time_left), "La guía congela los bloqueos y el tiempo de juego")
	_verificar(demostracion.tipo_actual != circuito_inicial, "La demostración de circuitos sigue animándose durante el tutorial")
	_verificar(apagon.sonidos.ambiente.stream_paused, "El audio restaurado del apagón respeta la pausa")
	menu.panel_ayuda.boton_cerrar.pressed.emit()
	await _fisicas(4)
	_verificar(not paused and not menu.capa.visible, "Entendido devuelve el control a la partida")
	_verificar(apagon.indicador_luz.visible and apagon.indicador_luz.rotulo.text == "Activar Luz", "El rayo y su rótulo originales del compañero guían al taco")
	_verificar(apagon.sonidos.ambiente.playing and not apagon.sonidos.ambiente.stream_paused, "El apagón conserva su ambiente después de la guía")
	apagon._al_interactuar_taco(oficina.jugador)
	_verificar(apagon.estado == apagon.Estado.REPARANDO and not apagon.indicador_luz.visible, "Al reparar se abre el circuito y se oculta el rayo")
	apagon._al_resolver_circuito()
	_verificar(apagon.estado == apagon.Estado.RESTAURADO and not apagon.sonidos.ambiente.playing and reloj.time_left >= 40.0, "La reparación detiene el sonido y programa el próximo evento")
	_verificar(apagon.iniciar_apagon() and not paused and not menu.capa.visible, "El segundo apagón no repite la guía automática")
	apagon._al_interactuar_taco(oficina.jugador)
	apagon._al_resolver_circuito()
	_verificar(oficina._iniciar_incendio() and incendio.indicador_extintor.visible, "Después del apagón puede iniciarse el incendio con su marcador C")
	_verificar(not apagon.iniciar_apagon(), "Un incendio activo bloquea también el inicio directo del apagón")
	_verificar(incendio.panel.has_method("_dibujar_arco_mesa"), "La interfaz conserva el arco abierto de apagado por mesa")
	incendio.detener()
	oficina.queue_free()
	await process_frame
	print("[INTEGRACION EVENTOS] %d errores" % errores)
	quit(1 if errores else 0)


func _fisicas(cantidad: int) -> void:
	for i in cantidad:
		await physics_frame
		await process_frame


func _verificar(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("[OK] " + mensaje)
	else:
		errores += 1
		push_error(mensaje)
