extends SceneTree
## Hornea las dos tazas huecas; no genera geometría durante la partida.
## --headless --script res://Objetos/ZonaDescanso/Editor/generar_tazas.gd
const SEGMENTOS := 64
const DESTINO := "res://Objetos/ZonaDescanso/Mallas/"


func _initialize() -> void:
	for amarilla: bool in [false, true]:
		var nombre := "TazaAmarilla" if amarilla else "TazaBlanca"
		var malla := _crear_taza(amarilla)
		malla.resource_name = nombre
		var resultado := ResourceSaver.save(malla, DESTINO + nombre + ".res", ResourceSaver.FLAG_COMPRESS)
		if resultado != OK:
			push_error("No se pudo hornear %s: %s" % [nombre, error_string(resultado)])
			quit(1)
			return
		print("TAZA: %s, %s" % [nombre, malla.get_aabb()])
	quit()


func _crear_taza(amarilla: bool) -> ArrayMesh:
	var altura := 0.09 if amarilla else 0.0825
	var centro_x := 0.020339 if amarilla else 0.021208
	var base := 0.033 if amarilla else 0.028
	var radio_interior := 0.0315 if amarilla else 0.0275
	# Perfil continuo: base, pared exterior, labio redondeado, interior y fondo.
	# La pared interior es lineal de (radio_interior, .015) a (.0375, altura-.004).
	# contenido_cafe.gd puede cortar esa pared con el plano horizontal del líquido.
	var perfil: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(base - 0.0035, 0.0),
		Vector2(base - 0.001, 0.001), Vector2(base + 0.001, 0.0035),
		Vector2(base + 0.0025, 0.008), Vector2(base + 0.003, 0.015),
		Vector2(0.0415, altura - 0.004),
		Vector2(0.04135, altura - 0.0023),
		Vector2(0.04075, altura - 0.0008), Vector2(0.0395, altura),
		Vector2(0.03825, altura - 0.0008), Vector2(0.03765, altura - 0.0023),
		Vector2(0.0375, altura - 0.004), Vector2(radio_interior, 0.015),
		Vector2(radio_interior - 0.001, 0.011),
		Vector2(radio_interior - 0.003, 0.0085), Vector2(radio_interior - 0.006, 0.008),
		Vector2(0.0, 0.008),
	]
	var superficie := SurfaceTool.new()
	superficie.begin(Mesh.PRIMITIVE_TRIANGLES)
	for fila in perfil.size() - 1:
		for segmento in SEGMENTOS:
			var a := _punto_perfil(perfil, fila, segmento, centro_x)
			var b := _punto_perfil(perfil, fila + 1, segmento, centro_x)
			var c := _punto_perfil(perfil, fila + 1, segmento + 1, centro_x)
			var d := _punto_perfil(perfil, fila, segmento + 1, centro_x)
			if perfil[fila + 1].x > 0.0:
				_triangulo(superficie, a, b, c)
			if perfil[fila].x > 0.0:
				_triangulo(superficie, a, c, d)
	_crear_asa(superficie, centro_x, altura)
	var ceramica := StandardMaterial3D.new()
	ceramica.resource_name = "EsmalteMostaza" if amarilla else "EsmalteMarfil"
	ceramica.albedo_color = Color("d99b38") if amarilla else Color("ece9df")
	ceramica.roughness = 0.24
	ceramica.metallic_specular = 0.45
	superficie.set_material(ceramica)
	superficie.index()
	return superficie.commit()


func _punto_perfil(perfil: Array[Vector2], fila: int, segmento: int, centro_x: float) -> Array[Vector3]:
	var angulo := TAU * segmento / SEGMENTOS
	var p := perfil[fila]
	var anterior := perfil[maxi(0, fila - 1)]
	var siguiente := perfil[mini(perfil.size() - 1, fila + 1)]
	# Normales suavizadas del perfil; los centros del fondo quedan planos.
	var tangente := (siguiente - anterior).normalized()
	var normal := Vector3(tangente.y * cos(angulo), -tangente.x, tangente.y * sin(angulo))
	if fila == 0:
		normal = Vector3.DOWN
	elif fila == perfil.size() - 1:
		normal = Vector3.UP
	return [Vector3(centro_x + p.x * cos(angulo), p.y, p.x * sin(angulo)), normal]


func _crear_asa(superficie: SurfaceTool, centro_x: float, altura: float) -> void:
	# Asa elíptica cerrada, con ambos extremos embebidos en la pared cerámica.
	const PASOS := 36
	const LADOS := 16
	for tramo in PASOS:
		for lado in LADOS:
			var a := _punto_asa(tramo, lado, centro_x, altura)
			var b := _punto_asa(tramo + 1, lado, centro_x, altura)
			var c := _punto_asa(tramo + 1, lado + 1, centro_x, altura)
			var d := _punto_asa(tramo, lado + 1, centro_x, altura)
			_triangulo(superficie, a, b, c)
			_triangulo(superficie, a, c, d)
	# Las tapas quedan dentro del cuerpo, pero cierran por completo la malla.
	for tramo in [0, PASOS]:
		var punto := _punto_asa(tramo, 0, centro_x, altura)
		var centro := punto[0] - punto[1] * 0.0045
		var normal := Vector3.RIGHT
		for lado in LADOS:
			_triangulo(superficie, [centro, normal], _punto_asa(tramo, lado, centro_x, altura), _punto_asa(tramo, lado + 1, centro_x, altura))


func _punto_asa(tramo: int, lado: int, centro_x: float, altura: float) -> Array[Vector3]:
	var angulo := PI * 0.5 + PI * tramo / 36.0
	var vuelta := TAU * lado / 16.0
	var amarilla := altura > 0.085
	var radio_asa := 0.0255 if amarilla else 0.028
	var radio_medio_base := 0.03375 if amarilla else 0.02925
	var pendiente := (0.0395 - radio_medio_base) / (altura - 0.019)
	var y := altura * 0.54 + altura * 0.285 * sin(angulo)
	# Los extremos siguen el centro del espesor de la pared: no atraviesan
	# la cavidad, incluso en la taza blanca cuyo cuerpo se estrecha abajo.
	var radio_pared := radio_medio_base + pendiente * (y - 0.015)
	var centro := Vector3(centro_x - radio_pared + radio_asa * cos(angulo), y, 0)
	var dy := altura * 0.285 * cos(angulo)
	var tangente := Vector3(-pendiente * dy - radio_asa * sin(angulo), dy, 0).normalized()
	var exterior := Vector3(tangente.y, -tangente.x, 0)
	var normal := exterior * cos(vuelta) + Vector3.BACK * sin(vuelta)
	return [centro + normal * 0.0045, normal]


func _triangulo(superficie: SurfaceTool, a: Array[Vector3], b: Array[Vector3], c: Array[Vector3]) -> void:
	# Godot presenta caras con orden horario. Mantener el índice coherente
	# con la normal también en el interior y en la parte curva del asa.
	var puntos := [a, b, c]
	if (b[0] - a[0]).cross(c[0] - a[0]).dot(a[1] + b[1] + c[1]) > 0:
		puntos = [a, c, b]
	for punto: Array in puntos:
		superficie.set_normal(punto[1])
		superficie.add_vertex(punto[0])
