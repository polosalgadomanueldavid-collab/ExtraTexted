extends Node
## Ajustes locales: solo presentación; no modifican daño, física ni relojes.
const ARCHIVO := "user://calidad_visual.cfg"
signal nivel_cambiado(nuevo_nivel: int)
signal graficos_cambiados
const ULTRA := 3
const NOMBRES := ["Baja", "Media", "Alta", "Ultra"]
# Ultra cambia la dirección artística, sin supersampling ni más partículas.
const ESCALAS := [0.65, 0.85, 1.0, 1.0]
const PARTICULAS := [0.5, 0.75, 1.0, 1.0]
var nivel := 2
var vsync := true
var escala_3d := 1
var detalle_particulas := 1
var sombras_ultra := 1
var limite_fps := 0
var suavizado_bordes := 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Perfil inicial más ligero para móviles; el jugador puede cambiarlo en Gráficos.
	if OS.has_feature("mobile"):
		nivel = 1
		limite_fps = 1
	var config := ConfigFile.new()
	if config.load(ARCHIVO) == OK:
		var valor: Variant = config.get_value("visual", "nivel", nivel)
		if valor is int:
			nivel = clampi(valor, 0, ULTRA)
		vsync = bool(config.get_value("visual", "vsync", true))
		escala_3d = clampi(int(config.get_value("visual", "escala_3d", 1)), 0, 2)
		detalle_particulas = clampi(int(config.get_value("visual", "particulas", 1)), 0, 2)
		sombras_ultra = clampi(int(config.get_value("visual", "sombras_ultra", 1)), 0, 2)
		limite_fps = clampi(int(config.get_value("visual", "limite_fps", 0)), 0, 2)
		var suavizado_guardado: Variant = config.get_value("visual", "suavizado_bordes", 1)
		suavizado_bordes = int(suavizado_guardado) if suavizado_guardado is bool else clampi(int(suavizado_guardado), 0, 2)
	get_tree().node_added.connect(_nuevo_nodo)
	_aplicar_pantalla()

func establecer(valor: int, guardar_preferencia := true) -> void:
	nivel = clampi(valor, 0, ULTRA)
	_aplicar_pantalla()
	_recorrer(get_tree().root)
	nivel_cambiado.emit(nivel)
	if not guardar_preferencia:
		return
	_guardar()

func configurar_graficos(clave: String, valor: int) -> void:
	match clave:
		"vsync": vsync = valor != 0
		"escala_3d": escala_3d = clampi(valor, 0, 2)
		"particulas": detalle_particulas = clampi(valor, 0, 2)
		"sombras_ultra": sombras_ultra = clampi(valor, 0, 2)
		"limite_fps": limite_fps = clampi(valor, 0, 2)
		"suavizado_bordes": suavizado_bordes = clampi(valor, 0, 2)
		_: return
	_aplicar_pantalla()
	if clave == "particulas":
		_recorrer_particulas(get_tree().root)
	graficos_cambiados.emit()
	_guardar()

func _aplicar_pantalla() -> void:
	var factor: float = [0.75, 1.0, 1.15][escala_3d]
	var factor_suavizado := 1.12 if suavizado_bordes == 2 and not OS.has_feature("mobile") else 1.0
	get_tree().root.scaling_3d_scale = minf(1.3, ESCALAS[nivel] * factor * factor_suavizado)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = [0, 60, 120][limite_fps]
	var compatible := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	get_tree().root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if not compatible and suavizado_bordes > 0 else Viewport.SCREEN_SPACE_AA_DISABLED
	get_tree().root.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][suavizado_bordes] if compatible else (Viewport.MSAA_4X if suavizado_bordes == 2 else Viewport.MSAA_DISABLED)

func _guardar() -> void:
	var config := ConfigFile.new()
	config.set_value("visual", "nivel", nivel)
	config.set_value("visual", "vsync", vsync)
	config.set_value("visual", "escala_3d", escala_3d)
	config.set_value("visual", "particulas", detalle_particulas)
	config.set_value("visual", "sombras_ultra", sombras_ultra)
	config.set_value("visual", "limite_fps", limite_fps)
	config.set_value("visual", "suavizado_bordes", suavizado_bordes)
	config.save(ARCHIVO)

func _nuevo_nodo(nodo: Node) -> void:
	if nodo is CPUParticles3D or nodo is GPUParticles3D:
		# El nodo nuevo aún no se ha dibujado: aplicar su densidad antes del primer cuadro.
		_aplicar(nodo, true)
	elif nodo is Light3D:
		_aplicar.call_deferred(nodo)

func _recorrer(nodo: Node) -> void:
	_aplicar(nodo)
	for hijo in nodo.get_children():
		_recorrer(hijo)

func _recorrer_particulas(nodo: Node) -> void:
	if nodo is CPUParticles3D or nodo is GPUParticles3D:
		_aplicar(nodo)
	for hijo in nodo.get_children():
		_recorrer_particulas(hijo)

func _aplicar(nodo: Node, nuevo := false) -> void:
	if not is_instance_valid(nodo):
		return
	if nodo is Light3D:
		if not nodo.has_meta("sombra_original"):
			nodo.set_meta("sombra_original", nodo.shadow_enabled)
		nodo.shadow_enabled = nodo.get_meta("sombra_original") and (nivel >= 2 or (nivel == 1 and nodo is DirectionalLight3D))
	elif nodo is CPUParticles3D:
		# En GL Compatibility, redimensionar el buffer de un emisor activo
		# puede dejar triángulos estirados hasta el siguiente reinicio.
		if nodo.emitting and not nuevo:
			return
		if not nodo.has_meta("cantidad_original"):
			nodo.set_meta("cantidad_original", nodo.amount)
		var cantidad := maxi(1, roundi(int(nodo.get_meta("cantidad_original")) * PARTICULAS[nivel] * [0.6, 1.0, 1.25][detalle_particulas]))
		if nodo.amount != cantidad:
			nodo.amount = cantidad
	elif nodo is GPUParticles3D:
		# Los trails y subemisores activos no se reconstruyen durante un evento.
		if nodo.emitting and not nuevo:
			return
		if not nodo.has_meta("proporcion_original"):
			nodo.set_meta("proporcion_original", nodo.amount_ratio)
		nodo.amount_ratio = minf(1.0, float(nodo.get_meta("proporcion_original")) * PARTICULAS[nivel] * [0.6, 1.0, 1.25][detalle_particulas])
		if RenderingServer.get_current_rendering_method() == "gl_compatibility":
			if nodo.trail_enabled:
				nodo.trail_enabled = false
			if nodo.process_material is ParticleProcessMaterial and nodo.process_material.sub_emitter_mode != ParticleProcessMaterial.SUB_EMITTER_DISABLED:
				nodo.process_material = nodo.process_material.duplicate()
				nodo.process_material.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_DISABLED
