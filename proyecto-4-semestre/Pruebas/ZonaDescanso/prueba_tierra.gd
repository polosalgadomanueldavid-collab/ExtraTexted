extends SceneTree
## Integración real: calidad, recursos compartidos, pausa, descarga y terremoto.
const MACIZOS := preload("res://Objetos/ZonaDescanso/macizos_tierra.gd")
var errores := 0
var comprobaciones := 0

func _initialize() -> void:
	_probar.call_deferred()

func _probar() -> void:
	root.get_node("MenuGlobal").omitir_tutorial_siguiente_partida = true
	var oficina = load("res://Mundo/Oficina.tscn").instantiate()
	root.add_child(oficina)
	current_scene = oficina
	await _cuadros(12)
	root.get_node("MenuGlobal").cerrar_ayuda()
	paused = false
	for reloj in [oficina.temporizador_eventos, oficina.temporizador_bloqueos, oficina.temporizador_denuncias]:
		reloj.stop()
	oficina.anuncios.detener()
	oficina.tutoriales_vistos[&"terremoto"] = true
	var calidad := root.get_node("CalidadVisual")
	var uno := MACIZOS.new()
	var dos := MACIZOS.new()
	oficina.add_child(uno)
	oficina.add_child(dos)
	for nivel in [0, 1, 2, 3]:
		calidad.establecer(nivel, false)
		_verificar(uno.cantidad_visible() == [64, 120, 184, 184][nivel], "Cantidad limitada según calidad %d" % nivel)
		_verificar(uno._grupos[0].multimesh.instance_count == 32, "Conserva los macizos en calidad %d" % nivel)
		_verificar(uno._grupos[0].multimesh == dos._grupos[0].multimesh, "Reutiliza lotes entre efectos en calidad %d" % nivel)
	_verificar(uno._grupos.size() == 3 and uno.get_child_count() == 3, "Tres nodos de dibujo, sin cuerpos físicos ni nodos por roca")
	_verificar(uno._material != dos._material, "Cada jugador conserva un reloj de material independiente")
	uno.actualizar(2.7, Vector3(-.2, .6, 0), Vector3(.2, .6, 0), 0)
	dos.actualizar(1.2, Vector3(-.2, .5, 0), Vector3(.2, .5, 0), 0)
	_verificar(not is_equal_approx(uno._material.get_shader_parameter("fase"), dos._material.get_shader_parameter("fase")), "Dos efectos simultáneos no se cambian la fase")
	var mano_fijada: Vector3 = uno._material.get_shader_parameter("mano_l")
	uno.actualizar(3.0, Vector3(10, 10, 10), Vector3(-10, -10, -10), 0)
	_verificar(uno._material.get_shader_parameter("mano_l") == mano_fijada, "La descarga no vuelve atrás al recuperar los brazos")
	uno.queue_free()
	dos.queue_free()
	var jugador = oficina.jugador
	var maquina = oficina.get_node("MaquinaExpendedora")
	var terremoto = oficina.evento_terremoto
	terremoto._azar.seed = 8762
	_verificar(terremoto.iniciar(oficina.grafo_piso, jugador, {}, Rect2()), "Acepta preparación del terremoto")
	if terremoto.preparando:
		await terremoto.preparacion_terminada
	_verificar(terremoto.activo, "Termina la preparación y activa el terremoto")
	maquina.inventario[3] = 1
	_verificar(maquina.usar(3), "El consumo real activa tierra control")
	await _cuadros(125)
	var efecto = maquina.poderes._elemento
	if not is_instance_valid(efecto) or not is_instance_valid(efecto._tierra):
		_verificar(false, "El efecto sigue activo al levantar la montaña")
		quit(1)
		return
	var fase: float = efecto._tierra._material.get_shader_parameter("fase")
	paused = true
	await _cuadros(15)
	_verificar(is_equal_approx(fase, efecto._tierra._material.get_shader_parameter("fase")), "La pausa congela las trayectorias GPU")
	paused = false
	_verificar(maquina.inventario[3] == 1 and not terremoto.resolviendo_avatar, "Antes del 72 % conserva carga y evento")
	await _cuadros(38)
	_verificar(maquina.inventario[3] == 0 and terremoto.resolviendo_avatar, "El contacto consume una carga y restaura el terremoto")
	await _cuadros(200)
	_verificar(not terremoto.activo and not terremoto.resolviendo_avatar and terremoto.grietas.is_empty() and terremoto.escombros.is_empty(), "Finaliza restauración y limpia los escombros reales")
	_verificar(not is_instance_valid(efecto) and not jugador.input_locked, "Retira el efecto y devuelve los controles")
	oficina.queue_free()
	await _cuadros(3)
	print("[TIERRA] %d comprobaciones, %d errores" % [comprobaciones, errores])
	quit(0 if errores == 0 else 1)

func _cuadros(cantidad: int) -> void:
	for i in cantidad:
		await process_frame

func _verificar(condicion: bool, texto: String) -> void:
	comprobaciones += 1
	if not condicion:
		errores += 1
		push_error(texto)
	else:
		print("OK: ", texto)
