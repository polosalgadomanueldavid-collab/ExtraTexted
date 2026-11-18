extends Node3D
## F6: demostración en bucle. Espacio repite; Escape cierra.
## --fixed-fps 30 -- --capturar-choque guarda un ciclo real de Godot en output/choque.

const LAN := preload("res://Scripts/Red/partida_lan.gd")
var jugadores: Array[Player] = []
var reloj := 0.0
var fase: Label
var _impacto := false
var _fotograma := 0
var _capturando := false

func _ready() -> void:
	get_window().title = "ExtraTexted · Choque de compañeros"
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(960, 640)
	get_window().content_scale_size = Vector2i(960, 640)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_capturando = "--capturar-choque" in OS.get_cmdline_user_args()
	if _capturando:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://output/choque/fotogramas"))
	var entorno := WorldEnvironment.new()
	entorno.environment = Environment.new()
	entorno.environment.background_mode = Environment.BG_COLOR
	entorno.environment.background_color = Color("172b3b")
	entorno.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.environment.ambient_light_color = Color("d6e6ef")
	entorno.environment.ambient_light_energy = 0.65
	add_child(entorno)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-50, -25, 0)
	luz.light_energy = 1.5
	add_child(luz)
	var camara := Camera3D.new()
	add_child(camara)
	camara.position = Vector3(1.25, 1.65, 4.1)
	camara.look_at(Vector3(0, 0.4, 0))
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.size = 3.7
	camara.current = true
	var suelo := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 1.8
	disco.bottom_radius = 1.8
	disco.height = 0.08
	disco.radial_segments = 96
	suelo.mesh = disco
	suelo.position.y = -0.055
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("718e99")
	material.roughness = 0.9
	suelo.material_override = material
	add_child(suelo)
	var lan := LAN.new()
	for ruta: String in ["res://Personajes/PoliciaAzul/Policia.tscn", "res://Personajes/PoliciaRelevo/PoliciaRelevo.tscn"]:
		var jugador := load(ruta).instantiate() as Player
		jugador.remoto_red = true
		add_child(jugador)
		lan._preparar_colision(jugador)
		jugador.set_physics_process(false)
		jugador.intensidad_tambaleo = 0.35
		jugadores.append(jugador)
		var sombra := MeshInstance3D.new()
		var plano := CylinderMesh.new()
		plano.top_radius = 0.23
		plano.bottom_radius = 0.23
		plano.height = 0.003
		sombra.mesh = plano
		var tinta := StandardMaterial3D.new()
		tinta.albedo_color = Color("526e7b")
		tinta.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sombra.material_override = tinta
		jugador.add_child(sombra)
	lan.free()
	_interfaz()
	_reiniciar()

func _interfaz() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)
	_etiqueta(capa, "EXTRATEXTED  /  MULTIJUGADOR", Vector2(44, 28), 15, Color("83d2db"))
	_etiqueta(capa, "Un choque un poco tonto.", Vector2(42, 57), 34, Color("f4f1e9"))
	_etiqueta(capa, "Un pequeño rebote y seguimos trabajando.", Vector2(44, 105), 18, Color("b5c6cf"))
	fase = _etiqueta(capa, "", Vector2(44, 530), 23, Color("ffdc88"))
	_etiqueta(capa, "0,42 s  ·  Sin sacudida de cámara  ·  Conserva el control", Vector2(44, 570), 17, Color("d0dce2"))
	_etiqueta(capa, "ESPACIO  Repetir                          ESC  Cerrar", Vector2(44, 609), 13, Color("8ba8b9"))

func _etiqueta(capa: Node, texto: String, posicion: Vector2, tamano: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.position = posicion
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	capa.add_child(etiqueta)
	return etiqueta

func _reiniciar() -> void:
	reloj = 0.0
	_impacto = false
	for i in 2:
		var j := jugadores[i]
		j.choque.reiniciar()
		j.position = Vector3(-1.08 if i == 0 else 1.08, 0, 0)
		j.visual.rotation.y = PI * 0.5 if i == 0 else -PI * 0.5
		j._play_animation(&"run")

func _process(delta: float) -> void:
	if jugadores.size() != 2:
		return
	reloj += delta
	if reloj < 0.45:
		fase.text = "01 / Van con demasiada prisa…"
	elif not _impacto:
		for i in 2:
			var j := jugadores[i]
			j.velocity = Vector3(2.8 if i == 0 else -2.8, 0, 0)
			var contacto := j.move_and_collide(j.velocity * delta)
			if contacto != null and j.choque.registrar(contacto.get_collider(), j.velocity):
				_impacto = true
				reloj = 0.76
				for p in jugadores:
					p._play_animation(&"idle")
					p.velocity = Vector3.ZERO
				break
	else:
		fase.text = "02 / ¡Poc!" if reloj < 1.18 else "03 / Aquí no ha pasado nada."
		if reloj > 1.55:
			for i in 2:
				var j := jugadores[i]
				j.visual.rotation.y = lerp_angle(j.visual.rotation.y, 0.0, 1.0 - exp(-delta * 7.0))
		if reloj > 2.8 and not _capturando:
			_reiniciar()
	if _capturando:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://output/choque/fotogramas/%03d.png" % _fotograma)
		_fotograma += 1
		if _fotograma >= 90:
			_capturando = false
			set_process(false)
			print("CAPTURA_CHOQUE_OK")
			get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_reiniciar()
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()
