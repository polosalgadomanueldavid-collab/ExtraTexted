extends Node
## Comprobación integrada del HUD sin modificar el flujo de la oficina.

var errores: int = 0
var oficina: Node3D
var sistema: SistemaDespacho
var panel: PanelDespacho


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	call_deferred("_probar")


func _probar() -> void:
	oficina = (load("res://Oficina.tscn") as PackedScene).instantiate()
	oficina.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().root.add_child(oficina)
	await _esperar()
	oficina.temporizador_denuncias.stop()
	oficina.temporizador_bloqueos.stop()
	sistema = oficina.sistema_despacho
	sistema.set_process(false)
	panel = oficina.panel_despacho
	_verificar(panel.tarjetas.is_empty() and not panel.denuncia_activa_detalle.visible, "Estado inicial sin denuncias")
	var plantillas: Array[String] = ["amenaza_critica", "acoso_persistente", "suplantacion", "enlace_sospechoso", "uso_excesivo"]
	for plantilla: String in plantillas:
		var denuncia := (load("res://Casos/Despacho/denuncia_%s.tres" % plantilla) as Denuncia).duplicate(true) as Denuncia
		sistema.recibir_denuncia(denuncia)
	var critica := sistema.iniciar_denuncia_prioritaria()
	_verificar(critica.nivel_riesgo == 5, "Se conserva la prioridad del despacho")
	sistema.tiempos_restantes[critica.id] = 28.0
	sistema.interactuar_estacion("evidencias")
	# Completar el ejemplo del boceto con tiempos deterministas.
	sistema.tiempos_restantes["D-004"] = 42.0
	sistema.tiempos_restantes["D-003"] = 56.0
	sistema.tiempos_restantes["D-002"] = 72.0
	await _esperar()
	_verificar(panel.tarjetas.size() == 4 and not panel.tarjetas.has(critica.id), "El caso activo sale de la cola")
	_verificar(panel.denuncia_activa_tiempo.text == "00:28", "El temporizador muestra los segundos reales")
	_verificar(is_equal_approx(panel.reloj_activo.proporcion_restante, 0.7), "Arena sincronizada al 70% restante")
	_verificar(panel.reloj_activo.animado and panel.reloj_activo.is_processing(), "Solo el reloj activo procesa animación")
	_verificar(panel.protocolo.indice_actual == 1 and panel.protocolo.estaciones.size() == 3, "Las etapas reflejan el avance real")
	_verificar(panel.icono_actividad.tipo == panel.IconoDespacho.Tipo.VERIFICACION, "La lupa corresponde a la estación actual")
	for tarjeta: PanelContainer in panel.tarjetas.values():
		var reloj: Control = tarjeta.get_meta("reloj")
		_verificar(not reloj.animado and not reloj.is_processing(), "Reloj en espera inmóvil: " + tarjeta.name)
	var reloj_espera: Control = panel.tarjetas["D-004"].get_meta("reloj")
	var fase_espera: float = reloj_espera.fase_arena
	var fase_activa: float = panel.reloj_activo.fase_arena
	await _esperar()
	_verificar(panel.reloj_activo.fase_arena != fase_activa and reloj_espera.fase_arena == fase_espera, "Solo cae arena en el caso activo")
	await _capturar("01_activo_y_cola")

	# El mismo reloj visual acompaña el tiempo del juego durante pausa/reanudación.
	sistema.set_process(true)
	await _esperar()
	var escena_anterior := get_tree().current_scene
	get_tree().current_scene = oficina
	MenuGlobal.abrir_pausa()
	_verificar(get_tree().paused and MenuGlobal.panel_pausa.visible, "La pausa real de la oficina está abierta")
	var tiempo_pausado := sistema.obtener_tiempo_restante(critica.id)
	var arena_pausada: float = panel.reloj_activo.fase_arena
	await _esperar()
	_verificar(is_equal_approx(sistema.obtener_tiempo_restante(critica.id), tiempo_pausado) and is_equal_approx(panel.reloj_activo.fase_arena, arena_pausada), "Pausa congela tiempo y animación juntos")
	MenuGlobal.reanudar_juego()
	get_tree().current_scene = escena_anterior
	await _esperar()
	_verificar(sistema.obtener_tiempo_restante(critica.id) < tiempo_pausado and panel.reloj_activo.fase_arena != arena_pausada, "Reanudar continúa sin reiniciar el reloj")
	sistema.set_process(false)

	# Un caso que ya consumió tiempo empieza a animarse con esa proporción.
	sistema.resolver_denuncia(critica.id)
	await _esperar()
	_verificar(not panel.reloj_activo.animado and not panel.reloj_activo.is_processing(), "Al resolver se detiene el reloj activo")
	var siguiente := sistema.iniciar_denuncia_prioritaria()
	await _esperar()
	_verificar(siguiente.id == "D-004" and panel.reloj_activo.animado, "El siguiente caso empieza a animarse al activarse")
	_verificar(is_equal_approx(panel.reloj_activo.proporcion_restante, sistema.obtener_tiempo_restante(siguiente.id) / siguiente.tiempo_limite_segundos), "El cambio de caso no reinicia la arena a lleno")
	_verificar(panel.icono_actividad.tipo == panel.IconoDespacho.Tipo.EVIDENCIAS, "Cambia el icono de actividad con el nuevo protocolo")
	sistema.interactuar_estacion("evidencias")
	await _esperar()
	_verificar(panel.icono_actividad.tipo == panel.IconoDespacho.Tipo.PRIVACIDAD, "Privacidad muestra su candado")
	sistema.interactuar_estacion("privacidad")
	await _esperar()
	_verificar(panel.icono_actividad.tipo == panel.IconoDespacho.Tipo.REPORTE, "Reporte muestra su documento")
	sistema.tiempos_restantes[siguiente.id] = 0.1
	sistema.actualizar_tiempos(0.2)
	await _esperar()
	_verificar(not panel.denuncia_activa_detalle.visible and not panel.reloj_activo.animado, "El vencimiento oculta y detiene el reloj")
	var cuatro_pasos := sistema.iniciar_denuncia_prioritaria()
	await _esperar()
	_verificar(cuatro_pasos.protocolo_estaciones.size() == 4 and panel.protocolo.estaciones.size() == 4, "El panel admite protocolos de cuatro estaciones")

	# Cola completa, nombres largos, todas las estaciones y distintos tamaños de pantalla.
	for indice: int in range(5):
		var adicional := (load("res://Casos/Despacho/denuncia_suplantacion.tres") as Denuncia).duplicate(true) as Denuncia
		adicional.id = "extra-%d" % indice
		sistema.recibir_denuncia(adicional)
	for dimensiones: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1024, 768), Vector2i(2560, 1080)]:
		get_window().size = dimensiones
		await _esperar()
		var pantalla := Rect2(Vector2.ZERO, panel.size)
		_verificar(pantalla.encloses(panel.contenido.get_global_rect()), "HUD dentro de pantalla en %s" % dimensiones)
		_verificar(is_equal_approx(panel.contenido.size.x, panel.ANCHO_DISENO), "Ancho compacto independiente del contenido")
		for tarjeta: PanelContainer in panel.tarjetas.values():
			_verificar(tarjeta.size.x <= panel.ANCHO_DISENO + 1, "Nombre largo respeta el ancho disponible")
		await _capturar("02_cola_%dx%d" % [dimensiones.x, dimensiones.y])
		var scroll: ScrollContainer = panel.get_node("%ScrollContainer")
		scroll.scroll_vertical = int(panel.lista_denuncias.size.y)
		await _esperar()
		var ultima: Control = panel.lista_denuncias.get_child(panel.lista_denuncias.get_child_count() - 1)
		_verificar(pantalla.encloses(ultima.get_global_rect()), "El desplazamiento permite ver la última denuncia")
		scroll.scroll_vertical = 0
	panel.configurar_sistema(sistema)
	_verificar(sistema.denuncias_actualizadas.get_connections().size() == 1, "Configurar de nuevo no duplica conexiones")
	print("PRUEBA BARRA LATERAL: %d errores" % errores)
	get_tree().quit(0 if errores == 0 else 1)


func _esperar() -> void:
	for cuadro: int in range(5):
		await get_tree().process_frame


func _capturar(nombre: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--capturas" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var directorio := "res://.godot/barra_lateral_qa"
	DirAccess.make_dir_recursive_absolute(directorio)
	get_viewport().get_texture().get_image().save_png(directorio.path_join(nombre + ".png"))


func _verificar(condicion: bool, descripcion: String) -> void:
	if condicion:
		print("OK: ", descripcion)
	else:
		errores += 1
		push_error("FALLO: " + descripcion)
