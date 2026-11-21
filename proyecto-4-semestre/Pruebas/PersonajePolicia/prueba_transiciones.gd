extends SceneTree
## Comprueba continuidad de los pasos y del balanceo en ambos modelos reales.
var errores := 0

func _initialize() -> void:
	probar.call_deferred()

func verificar(condicion: bool, mensaje: String) -> void:
	if not condicion:
		errores += 1
		push_error(mensaje)

func probar() -> void:
	for ruta: String in ["res://Personajes/PoliciaAzul/Policia.tscn", "res://Personajes/PoliciaRelevo/PoliciaRelevo.tscn", "res://Personajes/PoliciaRelevo/PoliciaVioleta.tscn"]:
		var jugador: CharacterBody3D = load(ruta).instantiate()
		jugador.remoto_red = true
		root.add_child(jugador)
		jugador.set_physics_process(false)
		var animador: AnimationPlayer = jugador.animation_player
		var gestos: SkeletonModifier3D = jugador.gestos
		for fase: float in [0.12, 0.45, 0.78]:
			jugador._play_animation(&"walk")
			animador.advance(0.0)
			animador.seek(fase * animador.current_animation_length, true)
			jugador._play_animation(&"run")
			verificar(is_equal_approx(animador.current_animation_position / animador.current_animation_length, fase), "Caminar a correr conserva el apoyo: " + ruta)
			animador.advance(0.0)
			jugador._play_animation(&"walk")
			verificar(is_equal_approx(animador.current_animation_position / animador.current_animation_length, fase), "Correr a caminar conserva el apoyo: " + ruta)
		gestos._fase_balanceo = 2.0
		gestos._ritmo_balanceo = 7.3
		gestos._amplitud_balanceo = 0.11
		jugador._play_animation(&"run")
		gestos._actualizar_locomocion_visual(1.0 / 60.0)
		verificar(gestos._fase_balanceo > 2.0 and gestos._fase_balanceo < 2.18, "La fase avanza sin saltar al cambiar de ritmo")
		verificar(gestos._amplitud_balanceo > 0.11 and gestos._amplitud_balanceo < 0.16, "La amplitud se mezcla gradualmente")
		jugador._play_animation(&"fall")
		gestos._actualizar_locomocion_visual(0.016)
		jugador._play_animation(&"idle")
		gestos._actualizar_locomocion_visual(0.016)
		verificar(gestos._aterrizaje > 0.0, "La caída termina con absorción de rodillas")
		for i in 30:
			gestos._actualizar_locomocion_visual(0.016)
		verificar(is_zero_approx(gestos._aterrizaje), "El aterrizaje recupera la pose base")
		jugador.queue_free()
		await process_frame
	print("TRANSICIONES: ", errores, " errores")
	quit(0 if errores == 0 else 1)
