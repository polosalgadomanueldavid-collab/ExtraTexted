extends Node
## Ajustes locales: solo presentación; no modifican daño, física ni relojes.
const ARCHIVO := "user://calidad_visual.cfg"
const ESCALAS := [0.65, 0.85, 1.0]
const PARTICULAS := [0.5, 0.75, 1.0]
const ESCALAS_MOVIL := [0.55, 0.7, 0.85]
const PARTICULAS_MOVIL := [0.3, 0.5, 0.7]
var nivel := 1 if OS.has_feature("android") else 2

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	if config.load(ARCHIVO) == OK:
		var valor: Variant = config.get_value("visual", "nivel", nivel)
		if valor is int:
			nivel = clampi(valor, 0, 2)
	get_tree().node_added.connect(_nuevo_nodo)
	get_tree().root.scaling_3d_scale = _escala_3d()

func establecer(valor: int) -> void:
	nivel = clampi(valor, 0, 2)
	get_tree().root.scaling_3d_scale = _escala_3d()
	_recorrer(get_tree().root)
	var config := ConfigFile.new()
	config.set_value("visual", "nivel", nivel)
	config.save(ARCHIVO)

func _nuevo_nodo(nodo: Node) -> void:
	if nodo is Light3D or nodo is CPUParticles3D or nodo is GPUParticles3D:
		_aplicar.call_deferred(nodo)

func _recorrer(nodo: Node) -> void:
	_aplicar(nodo)
	for hijo in nodo.get_children():
		_recorrer(hijo)

func _aplicar(nodo: Node) -> void:
	if not is_instance_valid(nodo):
		return
	if nodo is Light3D:
		if not nodo.has_meta("sombra_original"):
			nodo.set_meta("sombra_original", nodo.shadow_enabled)
		nodo.shadow_enabled = nodo.get_meta("sombra_original") and (nivel == 2 or (nivel == 1 and nodo is DirectionalLight3D))
	elif nodo is CPUParticles3D:
		if not nodo.has_meta("cantidad_original"):
			nodo.set_meta("cantidad_original", nodo.amount)
		var cantidad := maxi(1, roundi(int(nodo.get_meta("cantidad_original")) * _proporcion_particulas()))
		if nodo.amount != cantidad:
			nodo.amount = cantidad
	elif nodo is GPUParticles3D:
		if not nodo.has_meta("proporcion_original"):
			nodo.set_meta("proporcion_original", nodo.amount_ratio)
		nodo.amount_ratio = float(nodo.get_meta("proporcion_original")) * _proporcion_particulas()
		if RenderingServer.get_current_rendering_method() == "gl_compatibility":
			nodo.trail_enabled = false
			if nodo.process_material is ParticleProcessMaterial and nodo.process_material.sub_emitter_mode != ParticleProcessMaterial.SUB_EMITTER_DISABLED:
				nodo.process_material = nodo.process_material.duplicate()
				nodo.process_material.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_DISABLED


func _escala_3d() -> float:
	return ESCALAS_MOVIL[nivel] if OS.has_feature("android") else ESCALAS[nivel]


func _proporcion_particulas() -> float:
	return PARTICULAS_MOVIL[nivel] if OS.has_feature("android") else PARTICULAS[nivel]
