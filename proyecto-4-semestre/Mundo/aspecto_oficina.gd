extends Node
## Perfiles de iluminación sobre los mismos nodos/materiales. Solo se actualiza
## al entrar o cambiar calidad, sin luces nuevas ni trabajo por fotograma.
const LUCES_ULTRA := {
	"FocoFilaFrontal": [Color("ffc37c"), 4.2],
	"FocoFilaFrontal3": [Color("ffe0b1"), 4.0],
	"LuzVentanaEntrada": [Color("84caff"), 6.0],
	"LuzRellenoDescanso": [Color("77baff"), 4.5],
	"FocoFilaTrasera": [Color("ffe0b1"), 4.0],
	"LuzEstacionEvidencias": [Color("ffc37c"), 3.4],
	"LuzEstacionPrivacidad": [Color("ffe0b1"), 3.5],
	"LuzEstacionReporte": [Color("ffe0b1"), 3.5],
}
const PROPIEDADES_AMBIENTE := ["ambient_light_color", "ambient_light_energy", "tonemap_exposure", "adjustment_contrast", "adjustment_saturation"]

var _luces: Array[Light3D] = []
var _base_luces: Array[Dictionary] = []
var _ambiente: Environment
var _base_ambiente := {}
var _piso: ShaderMaterial
var _base_piso := {}
var _apagon: Node
var _ultra_aplicado := false


func _ready() -> void:
	var oficina := get_parent()
	var camara := oficina.get_node("Gameplay/Camera3D") as Camera3D
	# Cada oficina tiene su entorno, también al salir y volver a entrar.
	_ambiente = camara.environment.duplicate() as Environment
	camara.environment = _ambiente
	for propiedad: String in PROPIEDADES_AMBIENTE:
		_base_ambiente[propiedad] = _ambiente.get(propiedad)
	for nombre: String in LUCES_ULTRA:
		var luz := oficina.get_node("Pared, suelo, techo/" + nombre) as Light3D
		_luces.append(luz)
		_base_luces.append({"color": luz.light_color, "energia": luz.light_energy})
	# Terremoto ya creó una copia local en su _ready. Conservar esa instancia
	# permite cambiar el acabado sin perder su máscara de grietas.
	_piso = oficina.get_node("Pared, suelo, techo/PisoTerremoto/Suelo").material as ShaderMaterial
	for parametro in ["rugosidad", "especular"]:
		_base_piso[parametro] = _piso.get_shader_parameter(parametro)
	_apagon = oficina.get_node("EventoApagon")
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
	for i in _luces.size():
		var luz := _luces[i]
		var perfil: Array = LUCES_ULTRA[String(luz.name)]
		luz.light_color = perfil[0] if ultra else _base_luces[i].color
		luz.light_energy = perfil[1] if ultra else _base_luces[i].energia
	# Mantener las mismas características del shader en ambos perfiles: el
	# cambio en Opciones modifica valores, sin compilar variantes de efectos.
	_ambiente.ambient_light_color = Color("819cba") if ultra else _base_ambiente.ambient_light_color
	_ambiente.ambient_light_energy = 0.26 if ultra else _base_ambiente.ambient_light_energy
	_ambiente.tonemap_exposure = 1.1 if ultra else _base_ambiente.tonemap_exposure
	_ambiente.adjustment_contrast = 1.08 if ultra else _base_ambiente.adjustment_contrast
	_ambiente.adjustment_saturation = 1.04 if ultra else _base_ambiente.adjustment_saturation
	_piso.set_shader_parameter("rugosidad", 0.6 if ultra else _base_piso.rugosidad)
	_piso.set_shader_parameter("especular", 0.3 if ultra else _base_piso.especular)


func _al_cambiar_apagon(_estado: int) -> void:
	_aplicar_nivel(CalidadVisual.nivel)
