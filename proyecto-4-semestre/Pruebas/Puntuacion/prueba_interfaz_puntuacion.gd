extends Node
## Comprueba el saldo real del HUD, su reconexión y su distribución en pantalla.

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
	add_child(oficina)
	await _esperar()
	oficina.temporizador_denuncias.stop()
	oficina.temporizador_bloqueos.stop()
	sistema = oficina.sistema_despacho
	sistema.set_process(false)
	panel = oficina.panel_despacho
	_verificar(panel.puntos_valor.text == "0" and panel.puntos_valor.is_visible_in_tree(), "Saldo cero visible sin casos")
	_verificar(panel.puntos_ganancia.text.is_empty(), "No anuncia recompensa al iniciar")

	var critica := _recibir("amenaza_critica", "UI-CRITICA")
	sistema.iniciar_denuncia_prioritaria()
	await _esperar()
	_verificar(panel.puntos_valor.text == "0", "Aceptar un caso no suma puntos")
	_verificar("500" in panel.recompensa_caso.text, "El caso activo anticipa su recompensa de 500")
	await _capturar("01_caso_activo")
	for estacion: String in critica.protocolo_estaciones:
		sistema.interactuar_estacion(estacion)
	await _esperar()
	_verificar(panel.puntos_valor.text == "500", "Completar el protocolo actualiza el saldo")
	_verificar(panel.puntos_ganancia.text == "+500 PTS", "Confirma los puntos reales obtenidos")
	_verificar(not panel.denuncia_activa_detalle.visible, "La recompensa permanece al cerrar el caso")
	await _capturar("02_recompensa")

	var leve := _recibir("uso_excesivo", "UI-LEVE")
	sistema.iniciar_denuncia_prioritaria()
	for estacion: String in leve.protocolo_estaciones:
		sistema.interactuar_estacion(estacion)
	await _esperar()
	_verificar(panel.puntos_valor.text == "600" and panel.puntos_ganancia.text == "+100 PTS", "Acumula otro caso y anuncia solo su recompensa")
	var vencida := _recibir("suplantacion", "UI-VENCIDA")
	sistema.vencer_denuncia(vencida.id)
	_verificar(panel.puntos_valor.text == "600", "El vencimiento conserva el saldo")
	# Reinserción defensiva: un mismo ID no se puede premiar dos veces en la partida.
	sistema.recibir_denuncia(critica)
	sistema.resolver_denuncia(critica.id)
	_verificar(panel.puntos_valor.text == "600" and panel.puntos_ganancia.text == "+100 PTS", "No muestra una ganancia falsa por ID repetido")
	panel._process(3.1)
	_verificar(panel.puntos_ganancia.text.is_empty(), "El aviso de ganancia desaparece")

	# Cambiar a un despacho con saldo precargado no debe fingir una nueva ganancia.
	var otro := SistemaDespacho.new()
	add_child(otro)
	otro.set_process(false)
	var grande := Denuncia.new()
	grande.id = "UI-SALDO-GRANDE"
	grande.puntaje_recompensa = 9223372036854775806
	otro.recibir_denuncia(grande)
	otro.resolver_denuncia(grande.id)
	panel.configurar_sistema(otro)
	panel.configurar_sistema(otro)
	await _esperar()
	_verificar(panel.puntos_valor.text == "9.223.372.036.854.775.806", "Muestra el saldo completo con separadores")
	_verificar(panel.puntos_ganancia.text.is_empty(), "Reconfigurar no anuncia el saldo como ganancia")
	_verificar(otro.puntuacion.puntos_actualizados.get_connections().size() == 1, "No duplica conexiones de puntuación")
	_verificar(sistema.puntuacion.puntos_actualizados.get_connections().is_empty(), "Desconecta el despacho anterior")
	for dimensiones: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1024, 768), Vector2i(2560, 1080)]:
		get_window().size = dimensiones
		await _esperar()
		var pantalla := Rect2(Vector2.ZERO, panel.size)
		_verificar(pantalla.encloses(panel.contenido.get_global_rect()), "HUD dentro de pantalla en %s" % dimensiones)
		var fuente := panel.puntos_valor.get_theme_font("font")
		var ancho := fuente.get_string_size(panel.puntos_valor.text, HORIZONTAL_ALIGNMENT_LEFT, -1, panel.puntos_valor.get_theme_font_size("font_size")).x
		_verificar(ancho <= panel.puntos_valor.size.x, "Saldo largo legible sin recorte en %s" % dimensiones)
		await _capturar("03_saldo_%dx%d" % [dimensiones.x, dimensiones.y])
	panel.configurar_sistema(null)
	_verificar(panel.puntos_valor.text == "0" and panel.puntos_ganancia.text.is_empty(), "Desvincular limpia saldo y avisos")
	_verificar(otro.puntuacion.puntos_actualizados.get_connections().is_empty(), "Desvincular retira la conexión")
	oficina.queue_free()
	otro.queue_free()
	await get_tree().process_frame
	print("PRUEBA INTERFAZ PUNTUACION: %d errores" % errores)
	get_tree().quit(0 if errores == 0 else 1)


func _recibir(plantilla: String, id: String) -> Denuncia:
	var denuncia := (load("res://Casos/Despacho/denuncia_%s.tres" % plantilla) as Denuncia).duplicate(true) as Denuncia
	denuncia.id = id
	sistema.recibir_denuncia(denuncia)
	return denuncia


func _esperar() -> void:
	for cuadro: int in range(5):
		await get_tree().process_frame


func _capturar(nombre: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--capturas" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var directorio := "res://.godot/puntuacion_qa"
	DirAccess.make_dir_recursive_absolute(directorio)
	get_viewport().get_texture().get_image().save_png(directorio.path_join(nombre + ".png"))


func _verificar(condicion: bool, descripcion: String) -> void:
	if condicion:
		print("OK: ", descripcion)
	else:
		errores += 1
		push_error("FALLO: " + descripcion)
