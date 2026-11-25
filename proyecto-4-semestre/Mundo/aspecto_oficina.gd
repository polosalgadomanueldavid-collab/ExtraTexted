extends Node
## Perfiles de iluminación sobre los mismos nodos/materiales. Solo se actualiza
## al entrar o cambiar calidad, sin luces nuevas ni trabajo por fotograma.
signal perfil_aplicado

const LUCES_ULTRA := {
	"FocoFilaFrontal": [Color("ffc37c"), 3.5],
	"FocoFilaFrontal3": [Color("ffe0b1"), 3.1],
	"LuzVentanaEntrada": [Color("84caff"), 4.4],
	"LuzRellenoDescanso": [Color("77baff"), 3.6],
	"FocoFilaTrasera": [Color("ffe0b1"), 3.0],
	"LuzEstacionEvidencias": [Color("ffc37c"), 3.3],
	"LuzEstacionPrivacidad": [Color("ffe0b1"), 2.7],
	"LuzEstacionReporte": [Color("ffe0b1"), 2.7],
}
const FOCOS_CON_SOMBRA := ["FocoFilaFrontal3", "FocoFilaTrasera", "LuzEstacionPrivacidad", "LuzEstacionReporte"]
const FOCOS_EN_BOMBILLO := {
	"FocoFilaFrontal": ["LamparaVerificacion", Vector3(-2.2, 0.7, 3.87)],
	"FocoFilaFrontal3": ["LamparaComputador", Vector3(-0.95, 0.7, 1.4)],
	"LuzEstacionEvidencias": ["LamparaEvidencias", Vector3(0.25, 0.7, 3.87)],
	"LuzEstacionPrivacidad": ["LamparaPrivacidad", Vector3(-2.38, 0.6, 6.15)],
	"LuzEstacionReporte": ["LamparaReporte", Vector3(0.33, 0.6, 6.15)],
}
const PROPIEDADES_AMBIENTE := ["ambient_light_color", "ambient_light_energy", "tonemap_exposure", "adjustment_contrast", "adjustment_saturation", "ssao_enabled", "ssao_radius", "ssao_intensity", "ssao_detail", "ssil_enabled", "ssil_radius", "ssil_intensity", "glow_enabled", "glow_intensity", "glow_bloom"]

var _luces: Array[Light3D] = []
var _base_luces: Array[Dictionary] = []
var _ambiente: Environment
var _base_ambiente := {}
var _piso: ShaderMaterial
var _base_piso := {}
var _apagon: Node
var _ultra_aplicado := false
var _atlas_sombras_base := 0
var _luminarias: Node3D
var _rebotes_pared: Array[OmniLight3D] = []


func _ready() -> void:
	var oficina := get_parent()
	var camara := oficina.get_node("Gameplay/Camera3D") as Camera3D
	_atlas_sombras_base = oficina.get_viewport().positional_shadow_atlas_size
	_luminarias = oficina.get_node("Pared, suelo, techo/Luminarias") as Node3D
	# Cada oficina tiene su entorno, también al salir y volver a entrar.
	_ambiente = camara.environment.duplicate() as Environment
	camara.environment = _ambiente
	for propiedad: String in PROPIEDADES_AMBIENTE:
		_base_ambiente[propiedad] = _ambiente.get(propiedad)
	for nombre: String in LUCES_ULTRA:
		var luz := oficina.get_node("Pared, suelo, techo/" + nombre) as Light3D
		_luces.append(luz)
		_base_luces.append({"color": luz.light_color, "energia": luz.light_energy, "sombra": luz.shadow_enabled, "sesgo": luz.shadow_bias, "sesgo_normal": luz.shadow_normal_bias, "atenuacion": (luz as SpotLight3D).spot_attenuation, "angulo": (luz as SpotLight3D).spot_angle, "borde": (luz as SpotLight3D).spot_angle_attenuation, "transform": luz.transform})
	# Terremoto ya creó una copia local en su _ready. Conservar esa instancia
	# permite cambiar el acabado sin perder su máscara de grietas.
	_piso = oficina.get_node("Pared, suelo, techo/PisoTerremoto/Suelo").material as ShaderMaterial
	for parametro in ["rugosidad", "especular"]:
		_base_piso[parametro] = _piso.get_shader_parameter(parametro)
	_apagon = oficina.get_node("EventoApagon")
	for nombre in ["LamparaBienestar", "LamparaVerificacion", "LamparaEvidencias"]:
		var bombillo := _luminarias.get_node(nombre + "/Bombillo") as Node3D
		var rebote := OmniLight3D.new()
		rebote.name = "RebotePared" + nombre
		rebote.light_color = Color("ffc88f")
		rebote.light_energy = 0.24
		rebote.omni_range = 2.0
		rebote.omni_attenuation = 2.0
		rebote.shadow_enabled = false
		rebote.visible = false
		bombillo.add_child(rebote)
		_rebotes_pared.append(rebote)
	_apagon.estado_cambiado.connect(_al_cambiar_apagon)
	CalidadVisual.nivel_cambiado.connect(_aplicar_nivel)
	_aplicar_nivel(CalidadVisual.nivel)


func _aplicar_nivel(nivel: int) -> void:
	# La reparación anima y restaura energías propias. Esperar a que termine
	# evita encender focos ocultos o sobrescribir su transición elemental.
	if _apagon.estado != _apagon.Estado.RESTAURADO:
		return
	var ultra := nivel == CalidadVisual.ULTRA
	if ultra == _ultra_aplicado:
		return
	_ultra_aplicado = ultra
	for rebote in _rebotes_pared:
		rebote.visible = ultra
	# Más definición para las sombras de los muebles en escritorio. En Android
	# se conserva el atlas actual para no aumentar el uso de memoria.
	if not OS.has_feature("mobile"):
		get_viewport().positional_shadow_atlas_size = 4096 if ultra else _atlas_sombras_base
	for i in _luces.size():
		var luz := _luces[i]
		var perfil: Array = LUCES_ULTRA[String(luz.name)]
		luz.light_color = perfil[0] if ultra else _base_luces[i].color
		luz.light_energy = perfil[1] if ultra else _base_luces[i].energia
		# Cuatro focos principales proyectan sombras; el resto ilumina sin
		# multiplicar los mapas de sombras de toda la oficina.
		luz.shadow_enabled = (String(luz.name) in FOCOS_CON_SOMBRA) if ultra else bool(_base_luces[i].sombra)
		# Un sesgo demasiado pequeño causaba las rayas diagonales de la captura.
		luz.shadow_bias = 0.12 if ultra else _base_luces[i].sesgo
		luz.shadow_normal_bias = 1.2 if ultra else _base_luces[i].sesgo_normal
		(luz as SpotLight3D).spot_attenuation = 1.4 if ultra else _base_luces[i].atenuacion
		(luz as SpotLight3D).spot_angle_attenuation = 1.7 if ultra else _base_luces[i].borde
		if ultra and FOCOS_EN_BOMBILLO.has(String(luz.name)):
			var datos: Array = FOCOS_EN_BOMBILLO[String(luz.name)]
			var bombillo := _luminarias.get_node(str(datos[0]) + "/Bombillo") as Node3D
			luz.global_position = bombillo.global_position + Vector3.DOWN * 0.06
			var hacia_abajo := String(luz.name) in ["LuzEstacionPrivacidad", "LuzEstacionReporte"]
			luz.look_at(datos[1], Vector3.FORWARD if hacia_abajo else Vector3.UP)
			(luz as SpotLight3D).spot_angle = 38.0 if String(luz.name) in ["FocoFilaFrontal", "FocoFilaFrontal3", "LuzEstacionEvidencias"] else 34.0
		elif not ultra:
			luz.transform = _base_luces[i].transform
			(luz as SpotLight3D).spot_angle = _base_luces[i].angulo
	# Mantener las mismas características del shader en ambos perfiles: el
	# cambio en Opciones modifica valores, sin compilar variantes de efectos.
	# Luz indirecta suave: revela ladrillos y rótulos sin aplanar las sombras.
	_ambiente.ambient_light_color = Color("8f9092") if ultra else _base_ambiente.ambient_light_color
	_ambiente.ambient_light_energy = 0.20 if ultra else _base_ambiente.ambient_light_energy
	_ambiente.tonemap_exposure = 0.96 if ultra else _base_ambiente.tonemap_exposure
	_ambiente.adjustment_contrast = 1.12 if ultra else _base_ambiente.adjustment_contrast
	_ambiente.adjustment_saturation = 1.04 if ultra else _base_ambiente.adjustment_saturation
	var avanzado := RenderingServer.get_current_rendering_method() == "forward_plus"
	_ambiente.ssao_enabled = avanzado if ultra else _base_ambiente.ssao_enabled
	_ambiente.ssao_radius = 1.15 if ultra else _base_ambiente.ssao_radius
	_ambiente.ssao_intensity = 1.25 if ultra else _base_ambiente.ssao_intensity
	_ambiente.ssao_detail = 0.65 if ultra else _base_ambiente.ssao_detail
	_ambiente.ssil_enabled = avanzado if ultra else _base_ambiente.ssil_enabled
	_ambiente.ssil_radius = 2.0 if ultra else _base_ambiente.ssil_radius
	_ambiente.ssil_intensity = 0.35 if ultra else _base_ambiente.ssil_intensity
	_ambiente.glow_enabled = RenderingServer.get_current_rendering_method() != "gl_compatibility" if ultra else _base_ambiente.glow_enabled
	_ambiente.glow_intensity = 0.18 if ultra else _base_ambiente.glow_intensity
	_ambiente.glow_bloom = 0.015 if ultra else _base_ambiente.glow_bloom
	_piso.set_shader_parameter("rugosidad", 0.6 if ultra else _base_piso.rugosidad)
	_piso.set_shader_parameter("especular", 0.3 if ultra else _base_piso.especular)

	perfil_aplicado.emit()


func colores_de_focos() -> Array[Dictionary]:
	var colores: Array[Dictionary] = []
	for i in _luces.size():
		var luz := _luces[i]
		var color: Color = LUCES_ULTRA[String(luz.name)][0] if _ultra_aplicado else _base_luces[i].color
		colores.append({"nodo": luz, "color": color})
	return colores


func _al_cambiar_apagon(_estado: int) -> void:
	for rebote in _rebotes_pared:
		rebote.visible = _apagon.estado == _apagon.Estado.RESTAURADO and _ultra_aplicado
	_aplicar_nivel(CalidadVisual.nivel)


func _exit_tree() -> void:
	if _atlas_sombras_base > 0 and not OS.has_feature("mobile"):
		get_viewport().positional_shadow_atlas_size = _atlas_sombras_base
