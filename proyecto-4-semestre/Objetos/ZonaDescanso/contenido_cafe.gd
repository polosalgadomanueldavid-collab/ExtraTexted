extends RefCounted
## Disco continuo ajustado al perfil interior de Editor/generar_tazas.gd.
const SUPERFICIE := preload("res://Objetos/ZonaDescanso/superficie_cafe.gdshader")
const SEGMENTOS := 64

static func crear(amarilla: bool) -> MeshInstance3D:
	var contenido := MeshInstance3D.new()
	contenido.name = "ContenidoCafe"
	var superficie := SurfaceTool.new()
	superficie.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SEGMENTOS:
		var a := Vector2.from_angle(TAU * i / SEGMENTOS)
		var b := Vector2.from_angle(TAU * (i + 1) / SEGMENTOS)
		for punto: Vector2 in [Vector2.ZERO, a * 0.96, b * 0.96, a * 0.96, a, b, a * 0.96, b, b * 0.96]:
			superficie.set_normal(Vector3.UP)
			superficie.set_uv(punto * 0.5 + Vector2.ONE * 0.5)
			superficie.add_vertex(Vector3(punto.x * 0.04, 0.07, punto.y * 0.04))
	contenido.mesh = superficie.commit()
	# El shader desplaza vértices al centro real y cambia el nivel al beber.
	contenido.custom_aabb = AABB(Vector3(-0.025, 0, -0.045), Vector3(0.09, 0.10, 0.09))
	contenido.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = SUPERFICIE
	material.set_shader_parameter("centro_x", 0.020339 if amarilla else 0.021208)
	material.set_shader_parameter("altura_taza", 0.09 if amarilla else 0.0825)
	material.set_shader_parameter("radio_fondo", 0.0315 if amarilla else 0.0275)
	material.set_shader_parameter("llenado", 1.0)
	contenido.material_override = material
	return contenido

static func establecer_llenado(contenido: MeshInstance3D, cantidad: float) -> void:
	(contenido.material_override as ShaderMaterial).set_shader_parameter("llenado", clampf(cantidad, 0.0, 1.0))

static func actualizar_sorbo(contenido: MeshInstance3D, fase: float) -> void:
	establecer_llenado(contenido, 1.0 - smoothstep(0.36, 0.56, fase))
