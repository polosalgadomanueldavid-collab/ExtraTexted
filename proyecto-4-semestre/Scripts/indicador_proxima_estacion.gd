class_name IndicadorProximaEstacion
extends Node3D

## Señal visual no interactuable para orientar al jugador hacia una estación.
## Se construye por código para no alterar las colisiones ni los recursos de mesa.

const COLOR_AZUL: Color = Color("35c4d8")
const COLOR_CREMA: Color = Color("fff1d8")
const COLOR_CORAL: Color = Color("ff7b68")

var estacion_id: String = ""
var _aro: MeshInstance3D
var _flecha: MeshInstance3D
var _etiqueta: Label3D
var _tiempo: float = 0.0


func configurar(nueva_estacion_id: String, nombre_estacion: String) -> void:
	estacion_id = nueva_estacion_id
	name = "Indicador_" + estacion_id
	_construir_visual(nombre_estacion)


func _process(delta: float) -> void:
	_tiempo += delta
	var pulso: float = 1.0 + sin(_tiempo * 3.2) * 0.10
	if is_instance_valid(_aro):
		_aro.scale = Vector3(pulso, 1.0, pulso)
		_aro.rotation.y += delta * 0.75
	if is_instance_valid(_flecha):
		_flecha.position.y = 0.34 + sin(_tiempo * 3.2) * 0.07


func _construir_visual(nombre_estacion: String) -> void:
	_aro = MeshInstance3D.new()
	_aro.name = "AroOrientacion"
	var aro_malla := TorusMesh.new()
	aro_malla.inner_radius = 0.22
	aro_malla.outer_radius = 0.31
	aro_malla.rings = 16
	aro_malla.ring_segments = 8
	_aro.mesh = aro_malla
	_aro.material_override = _material_emisivo(COLOR_AZUL)
	add_child(_aro)

	_flecha = MeshInstance3D.new()
	_flecha.name = "FlechaOrientacion"
	var flecha_malla := CylinderMesh.new()
	flecha_malla.top_radius = 0.0
	flecha_malla.bottom_radius = 0.15
	flecha_malla.height = 0.30
	_flecha.mesh = flecha_malla
	_flecha.material_override = _material_emisivo(COLOR_CORAL)
	_flecha.position.y = 0.34
	add_child(_flecha)

	_etiqueta = Label3D.new()
	_etiqueta.name = "RotuloSiguiente"
	_etiqueta.text = "SIGUIENTE\n" + nombre_estacion.to_upper()
	_etiqueta.font_size = 38
	_etiqueta.outline_size = 7
	_etiqueta.modulate = COLOR_CREMA
	_etiqueta.outline_modulate = Color("07313d")
	_etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_etiqueta.position = Vector3(0.0, 0.78, 0.0)
	_etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_etiqueta)


func _material_emisivo(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.8
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.render_priority = 126
	return material
