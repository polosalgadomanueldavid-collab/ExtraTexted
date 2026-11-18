extends SceneTree

var fallos := 0

func _initialize() -> void:
	probar.call_deferred()

func verificar(condicion: bool, texto: String) -> void:
	if not condicion:
		fallos += 1
		push_error(texto)

func probar() -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)
	current_scene = mundo
	var lan = load("res://Scripts/Red/partida_lan.gd").new()
	var a: CharacterBody3D = load("res://Personajes/PoliciaAzul/Policia.tscn").instantiate()
	var b: CharacterBody3D = load("res://Personajes/PoliciaRelevo/PoliciaRelevo.tscn").instantiate()
	for j: CharacterBody3D in [a, b]:
		j.remoto_red = true
		mundo.add_child(j)
		j.set_physics_process(false)
		lan._preparar_colision(j)
	a.position.x = -0.225
	b.position.x = 0.225
	a.visual.rotation.y = PI * 0.5
	b.visual.rotation.y = -PI * 0.5
	await physics_frame
	verificar(not a.choque.registrar(b, Vector3.ZERO), "Quietos no producen un choque")
	verificar(not a.choque.registrar(b, Vector3(0, 0, 3)), "Un roce tangencial no dispara la reacción")
	b.input_locked = true
	verificar(not a.choque.registrar(b, Vector3(3, 0, 0)), "Respeta los paneles de tareas")
	b.input_locked = false
	var posicion_a := a.position
	var posicion_b := b.position
	verificar(a.choque.registrar(b, Vector3(3, 0, 0)), "Activa el choque frontal")
	verificar(a.choque.tiempo == 0.0 and b.choque.tiempo == 0.0, "Reaccionan los dos personajes")
	verificar(a.position == posicion_a and b.position == posicion_b and a.velocity == Vector3.ZERO and b.velocity == Vector3.ZERO, "La animación no altera la física")
	verificar(not b.choque.registrar(a, Vector3(-3, 0, 0)), "El mismo contacto no se duplica")
	await create_timer(0.7).timeout
	verificar(a.choque.tiempo == a.choque.DURACION, "Termina en 420 ms")
	verificar(not a.choque.registrar(b, Vector3(3, 0, 0)), "No vibra al permanecer pegados")
	var esqueleto: Skeleton3D = a.gestos.get_skeleton()
	verificar(esqueleto.get_bone_pose_scale(esqueleto.find_bone("root")).is_equal_approx(Vector3.ONE), "Recupera la escala original sin acumulación")
	b.position.x = 1.4
	await process_frame
	await process_frame
	verificar(a.choque.contactos.is_empty() and b.choque.contactos.is_empty(), "Separarse rearma el siguiente choque")
	# Usa el mismo barrido de interpolación que el jugador remoto en LAN.
	a.position.x = -0.8
	b.position.x = 0.0
	a.velocity = Vector3(3, 0, 0)
	await physics_frame
	await physics_frame # Jolt incorpora las posiciones teletransportadas en el paso anterior.
	lan._mover_cuerpo_remoto(a, Vector3(0.4, 0, 0))
	verificar(a.choque.tiempo < a.choque.DURACION and b.choque.tiempo < b.choque.DURACION, "El barrido remoto activa ambas reacciones")
	verificar(a.position.x < b.position.x, "Los cuerpos no se atraviesan")
	# Ejercita también move_and_slide del controlador local, con su entrada real.
	a.choque.reiniciar()
	b.choque.reiniciar()
	a.position = Vector3(-0.46, 0, 0)
	b.position = Vector3.ZERO
	a.velocity = Vector3(2.8, 0, 0)
	b.velocity = Vector3.ZERO
	a.remoto_red = false
	await physics_frame
	await physics_frame
	Input.action_press(a.RIGHT)
	a._physics_process(1.0 / 60.0)
	Input.action_release(a.RIGHT)
	verificar(a.choque.tiempo < a.choque.DURACION and b.choque.tiempo < b.choque.DURACION, "El controlador local activa ambas reacciones")
	a.remoto_red = true
	lan.free()
	print("PRUEBA_CHOQUE: ", "OK" if fallos == 0 else str(fallos) + " fallos")
	quit(0 if fallos == 0 else 1)
