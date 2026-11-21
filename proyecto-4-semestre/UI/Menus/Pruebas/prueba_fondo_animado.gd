extends SceneTree
## --headless --path proyecto-4-semestre --script res://UI/Menus/Pruebas/prueba_fondo_animado.gd
var errores := 0

func _initialize() -> void:
	probar.call_deferred()

func comprobar(valor: bool, mensaje: String) -> void:
	if not valor:
		errores += 1
		push_error(mensaje)

func probar() -> void:
	var calidad = root.get_node("CalidadVisual")
	var nivel: int = calidad.nivel
	var ventana := root.size
	var modo := root.mode
	var menu = load("res://UI/Menus/MainMenu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var fondo = menu.get_node("FondoOficina")
	var escena = fondo.escenario
	comprobar(root.size == ventana and root.mode == modo,"El fondo no debe modificar la ventana")
	comprobar(calidad.nivel == nivel,"El fondo no debe cambiar la calidad elegida")
	comprobar(fondo.vista.own_world_3d,"El decorado necesita un mundo independiente del juego")
	comprobar(escena.hojas.size() == 28,"Se conservan los 28 papeles aprobados")
	escena.set_process(false)
	var muebles := [Rect2(0.5,0.78,3.2,1.3),Rect2(-4.0,-1.85,1.8,1.1),Rect2(-3.539,-4.569,1.278,1.338),Rect2(-4.839,-4.569,1.278,1.338),Rect2(1.929,-4.202,1.743,0.804),Rect2(4.45,-2.95,1.1,1.1)]
	var invasiones := 0
	for cuadro in 1481:
		escena._actualizar(fposmod(cuadro*0.05,74.0))
		for actor in escena.actores:
			var p := Vector2(actor.position.x,actor.position.z)
			for mueble in muebles:
				var cerca := Vector2(clampf(p.x,mueble.position.x,mueble.end.x),clampf(p.y,mueble.position.y,mueble.end.y))
				if p.distance_to(cerca) < 0.46:
					invasiones += 1
		comprobar(escena.actores[0].position.distance_to(escena.actores[1].position)>1.0,"Los compañeros no deben atravesarse")
	comprobar(invasiones == 0,"Los dos recorridos deben respetar el espacio de los muebles")
	for frontera in [10.0,37.0,47.0,74.0]:
		escena._actualizar(fposmod(frontera-0.0001,74.0))
		var antes := [escena.actores[0].transform,escena.actores[1].transform]
		escena._actualizar(fposmod(frontera,74.0))
		for i in 2:
			comprobar(antes[i].origin.distance_to(escena.actores[i].position)<0.001,"El relevo no debe saltar entre fases")
			comprobar(antes[i].basis.is_equal_approx(escena.actores[i].basis),"La orientación debe continuar entre fases")
	escena.reloj = 73.999
	escena.reloj_papeles = 5.0
	escena._actualizar(escena.reloj)
	var hoja: Vector3 = escena.hojas[0].position
	escena._process(0.002)
	comprobar(hoja.distance_to(escena.hojas[0].position)<0.01,"El viento no debe saltar al reiniciar el relevo")
	menu.iniciar_discusion()
	fondo.gesticular(1)
	comprobar(escena.gestos[1]>0.0,"Los diálogos conservan la respuesta de los personajes")
	menu.cancelar_discusion()
	fondo.hide()
	comprobar(escena.process_mode == Node.PROCESS_MODE_DISABLED,"El fondo oculto debe detenerse")
	fondo.show()
	comprobar(escena.process_mode == Node.PROCESS_MODE_INHERIT,"El fondo visible debe continuar")
	menu.queue_free()
	await process_frame
	print("PRUEBA FONDO ANIMADO: %d errores" % errores)
	quit(0 if errores == 0 else 1)
