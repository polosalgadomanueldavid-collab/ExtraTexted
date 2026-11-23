extends Node3D
## Pintura permanente sobre el ladrillo: no es un marcador flotante ni tiene texto.
const TEXTURAS := {
	"evidencias": preload("res://MarcadoresEstaciones/Grafitis/evidencias.svg"),
	"verificacion": preload("res://MarcadoresEstaciones/Grafitis/verificacion.svg"),
	"privacidad": preload("res://MarcadoresEstaciones/Grafitis/privacidad.svg"),
	"reporte": preload("res://MarcadoresEstaciones/Grafitis/reporte.svg"),
	"bienestar": preload("res://MarcadoresEstaciones/Grafitis/bienestar.svg")
}
const IZQUIERDA := ["bienestar", "verificacion", "privacidad"]
# Zonas libres de los tableros centrales, en coordenadas de cada mesa.
# La altura queda 3 mm por encima de la madera para evitar parpadeos.
const MARCAS_MESA := {
	"privacidad": Vector3(-.45, .5323, -.22),
	"reporte": Vector3(.50, .5171, -.22)
}
var pinturas: Dictionary = {}
var marcas_mesa: Dictionary = {}

func _ready() -> void:
	var oficina := get_parent()
	for estacion: Node in oficina.find_children("*", "Estacion", true, false):
		var id := str(estacion.estacion_id)
		if not TEXTURAS.has(id): continue
		var izquierda := IZQUIERDA.has(id)
		var pared := oficina.get_node("Pared, suelo, techo/Pared2" if izquierda else "Pared, suelo, techo/Pared3") as CSGBox3D
		var normal := Vector3.RIGHT if izquierda else Vector3.LEFT
		var semiespesor := pared.size.z * pared.global_basis.z.length() * .5
		var centro := pared.global_position + normal * (semiespesor + .006)
		centro.y = 1.8
		centro.z = estacion.global_position.z
		var pintura := MeshInstance3D.new()
		pintura.name = "Grafiti_" + id
		pintura.set_meta("estacion_id", id)
		pintura.set_meta("pared", pared.get_path())
		var plano := QuadMesh.new()
		plano.size = Vector2.ONE * 1.35
		pintura.mesh = plano
		pintura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.albedo_texture = TEXTURAS[id]
		material.albedo_color = Color(1, 1, 1, .88)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 1.0
		material.metallic_specular = 0.0
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		pintura.material_override = material
		add_child(pintura)
		pintura.global_position = centro
		pintura.global_rotation = Vector3(0, PI*.5 if izquierda else -PI*.5, 0)
		pinturas[id] = pintura
		if MARCAS_MESA.has(id):
			var marca := MeshInstance3D.new()
			marca.name = "Pintura_" + id
			var sello := QuadMesh.new()
			sello.size = Vector2.ONE * .20
			marca.mesh = sello
			marca.material_override = material
			marca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Hija de la mesa: acompaña al mueble sin modificar su modelo ni colisión.
			estacion.get_parent().add_child(marca)
			marca.position = MARCAS_MESA[id]
			marca.rotation = Vector3(-PI * .5, 0, PI)
			marcas_mesa[id] = marca
