extends "res://Pruebas/ZonaDescanso/prueba_interacciones_descanso.gd"
## --headless --fixed-fps 60 --script res://Pruebas/ZonaDescanso/prueba_taza_cafe.gd
## Sin --headless y con -- --capturas guarda los contactos reales de ambas tazas.

func _probar() -> void:
	root.size = Vector2i(1280, 900)
	await _cargar()
	_oficina.temporizador_eventos.stop()
	_oficina.anuncios.detener()
	_postura_cafe = _buscar_postura(_cafe)
	_postura_sofa = _buscar_postura(_sofa)
	for indice in 2:
		_saldo_y_calma(200, 60)
		await _colocar(_postura_cafe)
		await _pedir_cafe()
		await _recibir_cafe()
		var taza: MeshInstance3D = _zona.taza_en_mano
		var contenido := taza.get_node("ContenidoCafe") as MeshInstance3D
		var material := contenido.material_override as ShaderMaterial
		_verificar(material != _zona.panel_cafetera._cafe.material_override, "El llenado de la cafetera no modifica el café de la mano")
		_verificar(is_equal_approx(material.get_shader_parameter("llenado"), 1.0), "Cada taza se recibe llena")
		if indice == 1:
			await _colocar(_postura_sofa)
			await _tecla(KEY_E)
			await _esperar_estado("sentado", true, 2.0)
			await _segundos(0.4)
		else:
			await _colocar({"posicion": Vector3(-2.5, _altura, 9.2), "giro": 0.0})
		await _foto("%d_sostener" % indice)
		await _tecla(KEY_F)
		await _hasta_fase(0.46)
		_verificar(contenido.visible and float(material.get_shader_parameter("llenado")) < 0.9, "El café baja gradualmente durante el sorbo")
		await _foto("%d_sorbo" % indice)
		await _hasta_fase(0.61)
		_verificar(_zona.taza_en_mano == taza and taza.get_parent() == _jugador.anclaje_taza(), "La taza sigue en la mano después de consumir")
		_verificar(not contenido.visible and not _zona.tiene_cafe() and _despacho.calma_operativa >= 75, "Solo el café desaparece al consumirse y deja de estar disponible")
		var calma: int = _despacho.calma_operativa
		_zona._consumir_cafe()
		_verificar(_despacho.calma_operativa == calma, "El descenso no permite consumir dos veces")
		var pose := taza.global_transform
		paused = true
		await _cuadros(10)
		_verificar(taza.global_transform.is_equal_approx(pose) and _zona.taza_en_mano == taza, "La pausa conserva la taza vacía en la mano")
		paused = false
		await _hasta_fase(0.83)
		_verificar(taza.global_basis.y.normalized().dot(Vector3.UP) > 0.99, "La taza se endereza antes de terminar el descenso")
		await _foto("%d_descenso" % indice)
		await _esperar_estado("bebiendo", false, 3.0)
		_verificar(taza.get_parent() == _zona.get_node("RinconCafe") and not contenido.visible, "La taza vuelve vacía al mueble al acabar el gesto")
		if indice == 1:
			await _tecla(KEY_E)
			await _esperar_estado("sentado", false, 2.0)
	# Interrumpir la animación tras el consumo debe retirar también la taza vacía.
	_saldo_y_calma(200, 60)
	await _colocar(_postura_cafe)
	await _pedir_cafe()
	await _recibir_cafe()
	var ultima: MeshInstance3D = _zona.taza_en_mano
	await _tecla(KEY_F)
	await _hasta_fase(0.62)
	_jugador.reset_to_spawn()
	await _cuadros(3)
	_verificar(not _zona.tiene_cafe() and ultima.get_parent() == _zona.get_node("RinconCafe"), "Reiniciar durante el descenso devuelve la taza sin dejar objetos en la mano")
	await _finalizar()

func _hasta_fase(fase: float) -> void:
	for cuadro in 150:
		if not _jugador.realizando_gesto() or _jugador.gestos.tiempo / _jugador.gestos.duracion >= fase:
			return
		await process_frame
	_verificar(false, "El sorbo alcanza la fase %s" % fase)

func _foto(nombre: String) -> void:
	if not "--capturas" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	var camara := _oficina.get_node("Gameplay/Camera3D") as Camera3D
	var esqueleto: Skeleton3D = _jugador.gestos.get_skeleton()
	var cabeza := esqueleto.to_global(esqueleto.get_bone_global_pose(esqueleto.find_bone("head")).origin)
	var orientacion: Basis = esqueleto.global_basis.orthonormalized()
	camara.global_position = cabeza + orientacion * Vector3(0.55, 0.32, 1.0)
	camara.look_at(cabeza + Vector3(0, -0.035, 0))
	camara.fov = 40
	if not camara.has_node("LuzDetalle"):
		var luz := OmniLight3D.new()
		luz.name = "LuzDetalle"
		luz.omni_range = 3.0
		luz.light_energy = 2.0
		camara.add_child(luz)
	await RenderingServer.frame_post_draw
	var carpeta := "res://.godot/tazas_qa"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta))
	root.get_texture().get_image().save_png(carpeta.path_join(nombre + ".png"))
