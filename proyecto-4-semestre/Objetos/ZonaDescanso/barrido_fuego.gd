extends Node3D
## Conserva el recorrido real de los golpes; el fuego avanza tras el retroceso.
## La patada dibuja una cortina abierta, nunca un aro prefabricado.
const VIDA := .58
const INTERVALO := 1.0 / 60.0
const MAX_MUESTRAS := 38
var _recorridos: Array = [[], [], []]
var _mallas: Array[MeshInstance3D] = []
var _material: ShaderMaterial
var _reloj := 0.0
var _ultima_muestra := -1.0

func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = preload("res://Objetos/ZonaDescanso/barrido_fuego.gdshader")
	_material.set_shader_parameter("ruido", preload("res://Objetos/ZonaDescanso/ruido_flujo.tres"))
	for i in 3:
		var pieza := MeshInstance3D.new()
		pieza.mesh = ImmediateMesh.new()
		pieza.material_override = _material
		pieza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pieza.extra_cull_margin = .3
		add_child(pieza)
		_mallas.append(pieza)

func actualizar(reloj: float, origenes: Array[Vector3], direcciones: Array[Vector3], fuerzas: Array[float], presencia: float) -> void:
	_reloj = reloj
	_material.set_shader_parameter("reloj", reloj)
	_material.set_shader_parameter("presencia", presencia)
	var muestrear := reloj - _ultima_muestra >= INTERVALO - .0001
	for i in 3:
		var camino: Array = _recorridos[i]
		while not camino.is_empty() and reloj - float(camino[0].tiempo) > VIDA:
			camino.pop_front()
		if muestrear and fuerzas[i] > .06:
			camino.append({"origen": origenes[i], "direccion": direcciones[i], "tiempo": reloj, "fuerza": fuerzas[i]})
			if camino.size() > MAX_MUESTRAS:
				camino.pop_front()
		_dibujar(i, camino)
	if muestrear:
		_ultima_muestra = reloj

func _dibujar(indice: int, camino: Array) -> void:
	var malla := _mallas[indice].mesh as ImmediateMesh
	malla.clear_surfaces()
	_mallas[indice].visible = camino.size() >= 2
	if camino.size() < 2:
		return
	# Dos superficies cruzadas dan espesor desde el lateral y desde arriba.
	# Un solo envío por emisor; vértices degenerados separan los tramos.
	malla.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for plano in 2:
		for j in range(camino.size() - 1):
			for k in 13:
				var v := float(k) / 12.0
				for n in [j, j + 1]:
					var dato: Dictionary = camino[n]
					var edad: float = _reloj - dato.tiempo
					var direccion: Vector3 = dato.direccion
					var normal := direccion.cross(Vector3.RIGHT).normalized()
					if normal.is_zero_approx():
						normal = Vector3.UP
					if plano == 1:
						normal = direccion.cross(normal).normalized()
					var u := float(n) / (camino.size() - 1)
					var espesor := sin(v * PI) * (.12 + edad * .65) * sin(u * PI)
					var punto: Vector3 = dato.origen + direccion * (.05 + edad * 2.7 + v * (1.35 + dato.fuerza * 1.35))
					punto += normal * espesor + Vector3.UP * edad * edad * .65
					malla.surface_set_normal(normal)
					malla.surface_set_color(Color(1, 1, 1, (1.0 - smoothstep(.12, VIDA, edad)) * dato.fuerza))
					malla.surface_set_uv(Vector2(u, v))
					malla.surface_add_vertex(punto)
					if (k == 0 and n == j) or (k == 12 and n == j + 1):
						malla.surface_add_vertex(punto)
	malla.surface_end()
