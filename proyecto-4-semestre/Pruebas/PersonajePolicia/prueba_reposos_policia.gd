extends SceneTree
## Godot --headless --fixed-fps 60 --path <proyecto> --script res://Pruebas/PersonajePolicia/prueba_reposos_policia.gd
## Sin --headless, añadir -- --capturas para guardar poses en .godot/reposos_qa.

var errores: int = 0
var laboratorio: Node3D
var jugador
var esqueleto: Skeleton3D
var muestras: Dictionary = {}


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	laboratorio = (load("res://Pruebas/PersonajePolicia/PruebaPoliciaAzul.tscn") as PackedScene).instantiate() as Node3D
	jugador = laboratorio.get_node("PoliciaAzul")
	jugador.character_scale = 1.0
	root.add_child(laboratorio)
	current_scene = laboratorio
	await _cuadros(40)
	jugador.voz.habilitada = false
	esqueleto = jugador.find_child("Skeleton3D", true, false) as Skeleton3D
	jugador.gestos.modification_processed.connect(_guardar_pose)
	_verificar(jugador.is_on_floor() and esqueleto != null, "El personaje y su esqueleto están listos")
	var boton_despistado = laboratorio.get_node("HUD/Interfaz/Vistas/Contenido/Reposos/Despistado") as Button
	var boton_tambaleo = laboratorio.get_node("HUD/Interfaz/Vistas/Contenido/Reposos/Tambaleo") as Button
	_verificar(boton_despistado != null and boton_tambaleo != null, "La prueba permite ver ambos reposos")
	boton_despistado.emit_signal("pressed")
	_verificar(jugador.gestos.reposo_especial == &"idle_despistado", "El botón inicia el reposo despistado")
	await _cuadros(85)
	var brazo: Quaternion = muestras.get("brazo", Quaternion.IDENTITY)
	_verificar(brazo.angle_to(esqueleto.get_bone_rest(esqueleto.find_bone("upper_arm.R")).basis.get_rotation_quaternion()) > 0.1, "El brazo derecho alcanza la gorra")
	await _capturar("01_despistado")
	var tiempo = jugador.gestos.tiempo_reposo
	paused = true
	await create_timer(0.12).timeout
	_verificar(is_equal_approx(jugador.gestos.tiempo_reposo, tiempo), "La pausa congela el reposo")
	paused = false
	Input.action_press(&"policia_prueba_adelante")
	await _cuadros(18)
	_verificar(jugador.current_animation == &"walk" and jugador.gestos.reposo_especial == &"", "Caminar interrumpe el reposo")
	Input.action_release(&"policia_prueba_adelante")
	await _cuadros(30)
	boton_tambaleo.emit_signal("pressed")
	_verificar(jugador.gestos.reposo_especial == &"idle_tambaleo", "El botón inicia el tambaleo")
	await _cuadros(90)
	var inclinacion: Quaternion = muestras.get("spine", Quaternion.IDENTITY)
	_verificar(inclinacion.angle_to(esqueleto.get_bone_rest(esqueleto.find_bone("spine")).basis.get_rotation_quaternion()) > 0.08, "El cuerpo pierde el equilibrio")
	await _capturar("02_tambaleo")
	jugador.play_wave()
	await _cuadros(18)
	_verificar(jugador.current_animation == &"wave" and jugador.gestos.reposo_especial == &"", "Saludar interrumpe el tambaleo")
	await _cuadros(125)
	var hoja = load("res://Scripts/Despacho/papel_denuncia.gd").new()
	laboratorio.add_child(hoja)
	hoja.tomar(jugador)
	await _cuadros(15)
	var local = hoja.transform
	var mundo = hoja.global_position
	_verificar(jugador.play_idle_variant(&"idle_despistado"), "El reposo funciona llevando papel")
	await _cuadros(95)
	_verificar(hoja.get_parent() == jugador.anclaje_papel() and hoja.transform.is_equal_approx(local), "La hoja no se desliza de la mano")
	_verificar(hoja.global_position.distance_to(mundo) > 0.001, "La hoja acompaña el balanceo")
	await _cuadros(125)
	await _cuadros(12)
	jugador._reloj_reposo = 0.0
	await _cuadros(2)
	_verificar(jugador.gestos.reposo_especial == &"idle_tambaleo", "El siguiente reposo automático alterna la variante")
	jugador.reset_to_spawn()
	await _cuadros(18)
	_verificar(jugador.gestos.reposo_especial == &"" and jugador.current_animation == &"idle", "Reiniciar limpia el reposo especial")
	print("REPOSOS_POLICIA: %d errores" % errores)
	jugador.papel_en_mano = null
	hoja.queue_free()
	await _cuadros(3)
	laboratorio.queue_free()
	await _cuadros(10)
	quit(0 if errores == 0 else 1)


func _cuadros(cantidad: int) -> void:
	for i: int in range(cantidad):
		await physics_frame
		await process_frame


func _guardar_pose() -> void:
	muestras["brazo"] = esqueleto.get_bone_pose_rotation(esqueleto.find_bone("upper_arm.R"))
	muestras["spine"] = esqueleto.get_bone_pose_rotation(esqueleto.find_bone("spine"))


func _verificar(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("OK: " + mensaje)
	else:
		errores += 1
		push_error(mensaje)


func _capturar(nombre: String) -> void:
	if not OS.get_cmdline_user_args().has("--capturas"):
		return
	var camara = Camera3D.new()
	laboratorio.add_child(camara)
	camara.fov = 32.0
	camara.global_position = jugador.global_position + jugador.visual.global_basis.orthonormalized() * Vector3(-4.2, 2.9, 5.8)
	camara.look_at(jugador.global_position + Vector3.UP * 1.3)
	camara.current = true
	await RenderingServer.frame_post_draw
	var directorio = "res://.godot/reposos_qa"
	DirAccess.make_dir_recursive_absolute(directorio)
	root.get_texture().get_image().save_png(directorio + "/" + nombre + ".png")
	camara.queue_free()
