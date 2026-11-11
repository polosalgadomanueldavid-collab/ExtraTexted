extends Node3D
## La boca, la sustracción física y las losas comparten los mismos vértices X/Z.

const EFECTO := preload("res://Eventos/Terremoto/EfectoFractura.tscn")
const TRAMOS := 8
var centro: Vector2
var contorno := PackedVector2Array()
var limites: Rect2
var _izquierda := PackedVector2Array()
var _derecha := PackedVector2Array()
var _corte: CSGPolygon3D
var _losas: Array[MeshInstance3D] = []
var _origenes: Array[Vector3] = []
var _piedra: StandardMaterial3D


func trazar(origen: Vector2, largo: float, ancho: float, angulo: float, azar: RandomNumberGenerator) -> void:
	centro = origen
	limites = Rect2(centro, Vector2.ZERO)
	for i in range(TRAMOS + 1):
		var t := float(i) / TRAMOS
		var eje := Vector2(azar.randf_range(-0.14, 0.14), (t - 0.5) * largo)
		# Las puntas terminan en cuña y el tramo central conserva su anchura.
		var radio := ancho * 0.5 * minf(1.0, minf(t, 1.0 - t) * 4.3)
		var izq := centro + (eje - Vector2.RIGHT * radio * azar.randf_range(0.86, 1.08)).rotated(angulo)
		var der := centro + (eje + Vector2.RIGHT * radio * azar.randf_range(0.86, 1.08)).rotated(angulo)
		_izquierda.append(izq)
		_derecha.append(der)
		limites = limites.expand(izq).expand(der)
	contorno.append_array(_izquierda)
	for i in range(TRAMOS - 1, 0, -1):
		contorno.append(_derecha[i])


func contiene(punto: Vector2) -> bool:
	return limites.has_point(punto) and Geometry2D.is_point_in_polygon(punto, contorno)


func toca_cuadro(punto: Vector2, radio: float) -> bool:
	var caja := Rect2(punto - Vector2.ONE * radio, Vector2.ONE * radio * 2.0)
	if not limites.intersects(caja):
		return false
	var cuadro := PackedVector2Array([caja.position, Vector2(caja.end.x, caja.position.y),
		caja.end, Vector2(caja.position.x, caja.end.y)])
	return not Geometry2D.intersect_polygons(contorno, cuadro).is_empty()


func abrir(suelo: CSGBox3D) -> void:
	global_position.y = suelo.to_global(Vector3.UP * suelo.size.y * 0.5).y
	_corte = CSGPolygon3D.new()
	_corte.operation = CSGShape3D.OPERATION_SUBTRACTION
	var subsuelo := StandardMaterial3D.new()
	subsuelo.albedo_color = Color("322933")
	_corte.material = subsuelo
	_corte.polygon = contorno
	_corte.depth = suelo.size.y + 0.4
	suelo.add_child(_corte)
	_corte.global_transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0),
		Vector3(0, global_position.y - suelo.size.y - 0.2, 0))
	_piedra = StandardMaterial3D.new()
	_piedra.vertex_color_use_as_albedo = true
	_piedra.cull_mode = BaseMaterial3D.CULL_DISABLED
	_modelar_paredes()
	var superficie := (suelo.material as StandardMaterial3D).albedo_color
	for i in range(TRAMOS):
		var mitad_a := _izquierda[i].lerp(_derecha[i], 0.46 + 0.09 * sin(i * 3.0))
		var mitad_b := _izquierda[i + 1].lerp(_derecha[i + 1], 0.46 + 0.09 * sin((i + 1) * 3.0))
		_crear_losa([_izquierda[i], mitad_a, mitad_b, _izquierda[i + 1]], i, -1.0, superficie)
		_crear_losa([mitad_a, _derecha[i], _derecha[i + 1], mitad_b], i, 1.0, superficie)
		if i % 3 == 1:
			var efecto := EFECTO.instantiate() as Node3D
			add_child(efecto)
			efecto.position = _punto(_izquierda[i] if i % 2 else _derecha[i], 0.03)
			for emisor: CPUParticles3D in efecto.get_children():
				create_tween().tween_callback(emisor.restart).set_delay(i * 0.041)


func _modelar_paredes() -> void:
	var malla := SurfaceTool.new()
	malla.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(contorno.size()):
		var j := (i + 1) % contorno.size()
		var a := contorno[i]
		var b := contorno[j]
		# Labio levantado, veta de subsuelo y talud en sombra.
		var labio_a := _punto(a + centro.direction_to(a) * 0.033, 0.008)
		var labio_b := _punto(b + centro.direction_to(b) * 0.033, 0.008)
		var borde_a := _punto(a, 0.018 + 0.009 * sin(i * 2.7))
		var borde_b := _punto(b, 0.018 + 0.009 * sin(j * 2.7))
		var veta_a := _punto(a.lerp(centro, 0.06), -0.12 + 0.036 * sin(i * 3.6))
		var veta_b := _punto(b.lerp(centro, 0.06), -0.12 + 0.036 * sin(j * 3.6))
		var fondo_a := _punto(a.lerp(centro, 0.29), -0.94)
		var fondo_b := _punto(b.lerp(centro, 0.29), -0.94)
		_cara(malla, labio_a, labio_b, borde_b, borde_a, Color("bb8961"))
		_cara(malla, borde_a, borde_b, veta_b, veta_a, Color("94694e").darkened(0.12 * (i % 3)))
		_cara(malla, veta_a, veta_b, fondo_b, fondo_a, Color("42383d").darkened(0.13 * (i % 4)))
		_triangulo(malla, fondo_a, fondo_b, _punto(centro, -1.18), Color("211d29"))
		if i % 3 != 1:
			_modelar_fisura_lateral(malla, a, b, i)
	_instanciar_malla(malla)


func _modelar_fisura_lateral(malla: SurfaceTool, a: Vector2, b: Vector2, indice: int) -> void:
	var tangente := a.direction_to(b)
	var exterior := Vector2(-tangente.y, tangente.x)
	var base := a.lerp(b, 0.38)
	var codo := base + exterior * (0.09 + 0.025 * (indice % 3)) + tangente * 0.07
	var punta := codo + exterior * 0.09 - tangente * 0.06
	var ancho := tangente * 0.018
	var sombra := Color("352324")
	_cara(malla, _punto(base - ancho, 0.004), _punto(base + ancho, 0.004),
		_punto(codo + ancho * 0.46, 0.004), _punto(codo - ancho * 0.46, 0.004), sombra)
	_triangulo(malla, _punto(codo - ancho * 0.46, 0.004), _punto(codo + ancho * 0.46, 0.004),
		_punto(punta, 0.004), sombra)
	# Una astilla de corteza con una cara clara y otra en sombra junto a la fisura.
	var pie := base + exterior * 0.05 - tangente * 0.07
	var v1 := _punto(pie - tangente * 0.046, 0.005)
	var v2 := _punto(pie + tangente * 0.062, 0.005)
	var v3 := _punto(pie + exterior * 0.042, 0.005)
	var cima := _punto(pie + exterior * 0.014, 0.034)
	_triangulo(malla, v1, v2, cima, Color("a77554"))
	_triangulo(malla, v2, v3, cima, Color("805b48"))
	_triangulo(malla, v3, v1, cima, Color("b18462"))


func _crear_losa(puntos: PackedVector2Array, tramo: int, lado: float, color: Color) -> void:
	var origen := _punto((puntos[0] + puntos[1] + puntos[2] + puntos[3]) * 0.25, 0.0)
	var vertices := PackedVector3Array()
	for p in puntos:
		vertices.append(_punto(p, 0) - origen)
	var malla := SurfaceTool.new()
	malla.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cara(malla, vertices[0], vertices[1], vertices[2], vertices[3], color)
	for i in range(4):
		var a := vertices[i]
		var b := vertices[(i + 1) % 4]
		_cara(malla, a, b, b + Vector3.DOWN * 0.13, a + Vector3.DOWN * 0.13, Color("806049"))
	var losa := _instanciar_malla(malla)
	losa.position = origen
	_losas.append(losa)
	_origenes.append(origen)
	var caida := create_tween()
	caida.tween_interval(tramo * 0.041)
	caida.tween_property(losa, "rotation", Vector3(lado * 0.11, 0.0, lado * 0.16), 0.09)
	caida.tween_property(losa, "position:y", -1.52, 0.49).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	caida.parallel().tween_property(losa, "rotation", Vector3(0.63, lado * 0.3, lado * 0.89), 0.49)
	caida.tween_callback(losa.hide)


func animar_cierre() -> void:
	for i in range(_losas.size()):
		var losa := _losas[i]
		losa.show()
		var cierre := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		cierre.tween_interval(0.014 * (_losas.size() - i))
		cierre.tween_property(losa, "position", _origenes[i], 0.34)
		cierre.parallel().tween_property(losa, "rotation", Vector3.ZERO, 0.34)


func cerrar() -> void:
	_corte.get_parent().remove_child(_corte)
	_corte.queue_free()
	queue_free()


func _punto(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


func _triangulo(malla: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (c - a).cross(b - a).normalized()
	if normal.is_zero_approx():
		return
	malla.set_normal(normal)
	malla.set_color(color)
	malla.add_vertex(a)
	malla.add_vertex(b)
	malla.add_vertex(c)


func _cara(malla: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_triangulo(malla, a, b, c, color)
	_triangulo(malla, a, c, d, color)


func _instanciar_malla(datos: SurfaceTool) -> MeshInstance3D:
	var pieza := MeshInstance3D.new()
	pieza.mesh = datos.commit()
	pieza.material_override = _piedra
	add_child(pieza)
	return pieza
