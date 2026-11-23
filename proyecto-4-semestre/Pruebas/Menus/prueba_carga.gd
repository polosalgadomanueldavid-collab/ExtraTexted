extends SceneTree

const ESCENA_CARGA := "res://UI/Menus/CargaInicial.tscn"
const ESCENA_MENU := "res://UI/Menus/MainMenu.tscn"
const ESCENA_JUEGO := "res://Mundo/Oficina.tscn"
# Prueba funcional: dejar que el cargador alcance su propio límite de 60 s.
# Los tiempos reales se siguen registrando en AUDITORIA CARGA; 65 s no es
# un objetivo de rendimiento ni convierte una carga lenta en una mejora.
const PLAZO_FUNCIONAL_MS := 65000

var _fallos := 0
var _fase := "arranque"
var _ultimo_cuadro := 0
var _pausas_maximas := {}
var _confirmacion := 0
var _barra_maxima := 0.0


func _initialize() -> void:
	process_frame.connect(_medir_cuadro)
	_probar.call_deferred()

func _medir_cuadro() -> void:
	var ahora := Time.get_ticks_usec()
	if _ultimo_cuadro > 0:
		_pausas_maximas[_fase] = maxf(float(_pausas_maximas.get(_fase, 0.0)), (ahora - _ultimo_cuadro) / 1000.0)
	_ultimo_cuadro = ahora
	var carga := root.get_node_or_null("CargaEscenas")
	if carga != null:
		_barra_maxima = maxf(_barra_maxima, carga.progreso)


func _probar() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	_verificar(change_scene_to_file(ESCENA_CARGA) == OK, "Abre la pantalla inicial")
	await scene_changed
	var pantalla_inicial := current_scene
	var fondo_inicial := pantalla_inicial.get_node("Fondo") as ColorRect
	_verificar(pantalla_inicial.get_child_count() == 1 and fondo_inicial.color == Color.BLACK, "El arranque es completamente negro y sin texto")
	if not await _esperar_escena(ESCENA_MENU):
		_terminar()
		return
	var menu := current_scene
	_fase = "menu"
	var entrada := menu.get_node("EntradaNegra") as ColorRect
	_verificar(entrada.visible and entrada.modulate.a > 0.9, "El menú empieza cubierto por negro")
	await create_timer(0.35).timeout
	_verificar(entrada.modulate.a > 0.0 and entrada.modulate.a < 1.0, "El menú aparece con un fundido gradual")
	await create_timer(0.8).timeout
	_verificar(not entrada.visible, "El fundido termina y libera el menú")
	var dialogo := menu.get_node("PantallaDiscusion/Dialogo") as Control
	_verificar(dialogo.anchor_right < 0.5, "Las frases de carga quedan a la izquierda")
	var menu_global := root.get_node("MenuGlobal")
	var panel := menu_global.get_node("%PanelClasificacion") as PanelContainer
	menu.get_node("%PlayButton").pressed.emit()
	_verificar(menu.panel_lan.fondo.visible, "Jugar abre la selección Individual/LAN")
	menu.panel_lan.individual.pressed.emit()
	_verificar(menu.get_node("PantallaDiscusion").visible, "Jugar muestra a los policías discutiendo")
	_verificar(panel.get_node("%Formulario").is_visible_in_tree(), "El formulario permite ingresar el nombre")
	_verificar(_leer_turno(menu).values().all(func(voz): return voz == "Consejo"), "Antes de confirmar el nombre sólo aparecen consejos")
	menu.confirmar_discusion("Álex", "Lina")
	var pareja := _leer_turno(menu)
	_verificar(pareja.get("¿El piso es lava?") == "Álex" and pareja.get("Qué frío que hace, hermano.") == "Lina", "Cada oficial usa el alias que le corresponde")
	_verificar(pareja.get("¿Lina, eres tú?") == "Álex", "Al hablarle al compañero se usa su alias")
	(panel.get_node("%Volver") as Button).pressed.emit()
	_verificar(not menu.get_node("PantallaDiscusion").visible, "Cancelar restaura el menú")
	menu.get_node("%PlayButton").pressed.emit()
	menu.panel_lan.individual.pressed.emit()
	_verificar(menu.hablante.text == "Consejo", "Reabrir la carga descarta los alias anteriores")
	var nombre := panel.get_node("%NombreJugador") as LineEdit
	nombre.text = "María José"
	_fase = "entrada_individual"
	_confirmacion = Time.get_ticks_usec()
	nombre.text_submitted.emit(nombre.text)
	_verificar(menu.get_node("PantallaDiscusion").visible and not menu_global.get_node("%CapaModal").visible, "La discusión permanece visible durante la carga")
	_verificar(menu.hablante.text == nombre.text, "El primer subtítulo muestra el alias confirmado")
	if "--capturas" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/carga_discusion_qa.png")
	var solo := _leer_turno(menu)
	_verificar(solo.get("¿El piso es lava?") == nombre.text and not solo.has("Qué frío que hace, hermano.") and not solo.values().has("Lina"), "En solitario se omiten las intervenciones del segundo oficial")
	if not await _esperar_escena(ESCENA_JUEGO):
		_terminar()
		return
	_verificar(_barra_maxima == 100.0, "La carga completa alcanza el 100 %")
	_verificar(current_scene.oficina_preparada, "La disponibilidad incluye toda la preparación")
	var apagon: Node = current_scene.evento_apagon
	_verificar(apagon.estado == apagon.Estado.RESTAURADO and not apagon.mascara.visible and not apagon.luz_jugador.visible,
		"El calentamiento restaura la visión sin activar el apagón")
	_verificar(menu_global.get("nombre_partida") == "María José", "El nombre llega a la partida")
	_verificar(current_scene.en_practica() and not paused, "La carga conserva la práctica inicial interactiva")
	_verificar((current_scene.get("_bloqueos_disponibles") as Array).size() == 30, "Los 30 cajones ya están preparados al entrar en la oficina")
	print("[AUDITORIA CARGA] ", JSON.stringify({"render": DisplayServer.get_name(), "confirmacion_a_oficina_ms": (Time.get_ticks_usec() - _confirmacion) / 1000.0, "barra_maxima": _barra_maxima, "intervalos_maximos_ms": _pausas_maximas}))
	_terminar()


func _leer_turno(menu: Node) -> Dictionary:
	var voces := {}
	for i in range(menu.DIALOGO.size()):
		voces[menu.frase.text] = menu.hablante.text
		menu._process(menu.SEGUNDOS_POR_FRASE)
	return voces


func _esperar_escena(ruta: String) -> bool:
	var inicio := Time.get_ticks_msec()
	while Time.get_ticks_msec() - inicio < PLAZO_FUNCIONAL_MS:
		await process_frame
		var escena := current_scene
		if is_instance_valid(escena) and escena.scene_file_path == ruta and not root.get_node("CargaEscenas").activa:
			await process_frame
			return true
	_verificar(false, "Tiempo agotado al esperar %s" % ruta)
	return false


func _verificar(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("OK: ", mensaje)
	else:
		_fallos += 1
		push_error("FALLÓ: %s" % mensaje)


func _terminar() -> void:
	paused = false
	# Permite terminar el _ready de la oficina antes de retirarla del árbol.
	await physics_frame
	await process_frame
	if is_instance_valid(current_scene):
		current_scene.queue_free()
	await process_frame
	print("Resultado: %d fallo(s)" % _fallos)
	root.get_node("MenuGlobal").musica_menu.stop()
	await create_timer(0.3).timeout
	quit(0 if _fallos == 0 else 1)
