extends SkeletonModifier3D
## Poses posteriores a los clips importados; nunca acumula rotaciones entre frames.
## Los anclajes se actualizan con la pose final, incluidos los gestos y el tambaleo.

signal contacto
signal terminada
signal reposo_terminado

const DURACIONES := {&"recoger": 1.15, &"recibir": 0.75, &"interactuar": 0.7, &"reparar": 2.4, &"lanzar": 0.95, &"beber": 1.8, &"kamehameha": 3.6, &"genkidama": 5.0, &"rasengan": 3.8, &"explosion_final": 6.8}
const CONTACTOS := {&"recoger": 0.48, &"recibir": 0.38, &"interactuar": 0.48, &"reparar": 0.85, &"lanzar": 0.46, &"beber": 0.56, &"kamehameha": 0.55, &"genkidama": 0.72, &"rasengan": 0.5, &"explosion_final": 0.72}
const REPOSOS := {&"idle_despistado": 3.4, &"idle_tambaleo": 3.1}
const ESCALA_GENKIDAMA := 3.0
const RADIO_GENKIDAMA := 2.38
const DURACION_CARGA_EXPLOSION_FINAL := 4.8
const RECORRIDO_GENKIDAMA := 12.0
const RECORRIDO_RASENGAN := 10.0
const ALTURA_MODELO_POLICIA := 2.66
const DURACION_TRANSFORMACION_AURA := 7.0
const ESCALA_INICIAL_AURA_TRANSFORMACION := 5.4
const ESCALA_FINAL_AURA_TRANSFORMACION := 1.08
const LONGITUD_KAMEHAMEHA := 16.0
const ESCALA_GROSOR_KAMEHAMEHA := 4.0
const ESCALA_ORBE_INICIO_KAMEHAMEHA := 1.3
const ESCALA_AURA_PERSONAJE := Vector3(0.92, 0.92, 0.92)
const COLOR_EXPLOSION_FINAL_PRIMARIO := Color(1.0, 0.91, 0.36)
const COLOR_EXPLOSION_FINAL_SECUNDARIO := Color(1.0, 0.46, 0.035)
const COLOR_EXPLOSION_FINAL_TERCIARIO := Color(0.46, 0.085, 0.0)
const COLOR_EXPLOSION_FINAL_LUZ := Color(1.0, 0.62, 0.12)
const ESCENA_CARGA_AZUL := preload("res://assets/BinbunVFX_Vol2/BattleFX/effects/charge/vfx_blank_charge.tscn")
const ESCENA_AURA_AZUL := preload("res://assets/BinbunVFX_Vol2/BattleFX/effects/shield/vfx_blank_shield_01.tscn")
const ESCENA_IMPACTO_AZUL := preload("res://assets/BinbunVFX_Vol2/ExplosionFX/effects/air/vfx_air_explosion_01.tscn")
const ESCENA_AURA_STATUS := preload("res://assets/BinbunVFX_Vol2/StatusFX/effects/status/vfx_status_shatter.tscn")
const MATERIAL_OVERLAY_AURA := preload("res://assets/BinbunVFX_Vol2/StatusFX/effects/overlay/shatter_overlay.tres")
var jugador: CharacterBody3D
var gesto: StringName = &""
var tiempo: float = 0.0
var duracion: float = 1.0
var tambaleo: float = 1.0
var mano_izquierda: Node3D
var mano_derecha: Node3D
var anclaje_taza: Node3D
var objetivo: Node3D
var _reloj: float = 0.0
var _contacto_emitido: bool = false
var _peso_papel: float = 0.0
var _huesos: Dictionary = {}
var _reposo: Dictionary = {}
var _llave: Node3D
var _energia: Node3D
var _aura_persistente: Node3D
var _luz_aura_persistente: OmniLight3D
var _material_overlay_aura: ShaderMaterial
var _overlays_originales_aura: Array[Dictionary] = []
var _material_particulas_aura: ShaderMaterial
var _material_trazos_aura: ShaderMaterial
var aura_persistente_activada: bool = false
var aura_transformacion_en_curso: bool = false
var aura_transformacion_progreso: float = 0.0
var _tiempo_transformacion_aura: float = 0.0
var _tween_aura_persistente: Tween
var _materiales_aura_status: Array[ShaderMaterial] = []
var _colores_originales_poderes: Array[Dictionary] = []
var _esfera_energia: Node3D
var _aura: MeshInstance3D
var _orbita_aura: MeshInstance3D
var _material_aura: ShaderMaterial
var _material_orbita_aura: ShaderMaterial
var _luz_aura: OmniLight3D
var _aura_dorada: MeshInstance3D
var _orbita_dorada: MeshInstance3D
var _material_aura_dorada: ShaderMaterial
var _material_orbita_dorada: ShaderMaterial
var _luz_dorada: OmniLight3D
var _rayo_vfx: Node3D
var _rayos_malla: Array[MeshInstance3D] = []
var _orbe_inicio_rayo: Node3D
var _orbe_final_rayo: Node3D
var _esfera_genkidama: Node3D
var _genkidama_vfx: Node3D
var _luz_genkidama: OmniLight3D
var _capa_aura_genkidama: MeshInstance3D
var _orbita_genkidama: MeshInstance3D
var _material_aura_genkidama: ShaderMaterial
var _material_orbita_genkidama: ShaderMaterial
var _impacto_disparado: bool = false
var _impacto_activo: Node3D
var _explosion_final_activa: Node3D
var _rasengan: Node3D
var _rasengan_espinas: Node3D
var _rasengan_espinas_inversas: Node3D
var _capa_aura_rasengan: MeshInstance3D
var _orbita_rasengan: MeshInstance3D
var _material_aura_rasengan: ShaderMaterial
var _material_orbita_rasengan: ShaderMaterial
var _rasengan_lanzado: bool = false
var _origen_lanzamiento_rasengan := Vector3.ZERO
var reposo_especial: StringName = &""
var tiempo_reposo: float = 0.0
var _peso_reposo: float = 0.0
var _saliendo_reposo: bool = false
var sentado: bool = false
var lleva_taza: bool = false
var rociando_extintor := false
var _peso_extintor := 0.0
var _peso_sentado: float = 0.0
var _peso_taza: float = 0.0


func _ready() -> void:
	var esqueleto := get_skeleton()
	for i: int in range(esqueleto.get_bone_count()):
		var nombre := esqueleto.get_bone_name(i)
		_huesos[nombre] = i
		_reposo[nombre] = esqueleto.get_bone_rest(i).basis.get_rotation_quaternion()
	mano_izquierda = Node3D.new()
	mano_izquierda.name = "AnclajeManoIzquierda"
	esqueleto.add_child(mano_izquierda)
	mano_derecha = Node3D.new()
	mano_derecha.name = "AnclajeManoDerecha"
	esqueleto.add_child(mano_derecha)
	anclaje_taza = Node3D.new()
	anclaje_taza.name = "AnclajeTaza"
	esqueleto.add_child(anclaje_taza)
	_crear_llave()
	_crear_energia(esqueleto)
	_crear_aura_persistente(esqueleto)


func iniciar(tipo: StringName, destino: Node3D = null, segundos: float = 0.0) -> bool:
	if gesto != &"" or not DURACIONES.has(tipo):
		return false
	gesto = tipo
	tiempo = 0.0
	duracion = segundos if segundos > 0.0 else float(DURACIONES[tipo])
	_contacto_emitido = false
	if tipo == &"rasengan":
		_rasengan_lanzado = false
		_impacto_disparado = false
	if tipo == &"genkidama":
		_genkidama_vfx.set("one_shot", false)
		var animacion_esfera := _genkidama_vfx.get_node("AnimationPlayer") as AnimationPlayer
		if not animacion_esfera.is_playing():
			_genkidama_vfx.call("play")
		_impacto_disparado = false
	if tipo == &"kamehameha":
		_impacto_disparado = false
	if tipo == &"explosion_final":
		_impacto_disparado = false
	objetivo = destino
	cancelar_reposo()
	return true


func alternar_aura_persistente() -> void:
	if not is_instance_valid(_aura_persistente):
		return
	aura_persistente_activada = not aura_persistente_activada
	if is_instance_valid(_tween_aura_persistente):
		_tween_aura_persistente.kill()
	var emisor := _aura_persistente
	if aura_persistente_activada:
		_aplicar_color_explosion_final_aura()
		_aplicar_overlay_aura_al_personaje()
		emisor.visible = true
		aura_transformacion_en_curso = true
		aura_transformacion_progreso = 0.0
		_tiempo_transformacion_aura = 0.0
		emisor.scale = Vector3.ONE * ESCALA_INICIAL_AURA_TRANSFORMACION
		emisor.set("emitting", true)
	else:
		aura_transformacion_en_curso = false
		aura_transformacion_progreso = 0.0
		_material_overlay_aura.set_shader_parameter("effect_amount", 0.0)
		_restaurar_overlays_personaje()
		emisor.set("emitting", false)
		_tween_aura_persistente = create_tween()
		_tween_aura_persistente.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_tween_aura_persistente.tween_property(emisor, "scale", Vector3.ONE * 0.05, 0.42)
		_tween_aura_persistente.tween_callback(func() -> void:
			if is_instance_valid(emisor) and not aura_persistente_activada:
				emisor.visible = false
		)
	_actualizar_colores_poderes()


func _registrar_colores_poder(nodo: Node) -> void:
	if nodo is Light3D:
		_colores_originales_poderes.append({"objeto": nodo, "propiedad": &"light_color", "color": nodo.light_color, "shader": false})
	if nodo is GeometryInstance3D:
		var material: Material = nodo.material_override
		if material is ShaderMaterial:
			for nombre: StringName in [&"primary_color", &"secondary_color", &"tertiary_color", &"beam_color", &"highlight_color"]:
				var valor: Variant = material.get_shader_parameter(nombre)
				if valor is Color:
					_colores_originales_poderes.append({"objeto": material, "propiedad": nombre, "color": valor, "shader": true})
		elif material is BaseMaterial3D:
			for propiedad: StringName in [&"albedo_color", &"emission"]:
				_colores_originales_poderes.append({"objeto": material, "propiedad": propiedad, "color": material.get(propiedad), "shader": false})
	for hijo: Node in nodo.get_children():
		_registrar_colores_poder(hijo)


func _color_poder_con_aura(original: Color, propiedad: StringName) -> Color:
	var color: Color
	match propiedad:
		&"primary_color": color = COLOR_EXPLOSION_FINAL_PRIMARIO
		&"secondary_color": color = COLOR_EXPLOSION_FINAL_SECUNDARIO
		&"tertiary_color": color = COLOR_EXPLOSION_FINAL_TERCIARIO
		&"light_color": color = COLOR_EXPLOSION_FINAL_LUZ
		_:
			# Conserva el contraste entre núcleo claro y bordes intensos, y su opacidad.
			color = Color.from_hsv(COLOR_EXPLOSION_FINAL_PRIMARIO.h, original.s, original.v)
	color.a = original.a
	return color


func _actualizar_colores_poderes() -> void:
	# Solo se actualiza al alternar el aura; no recorre los materiales cada frame.
	for registro: Dictionary in _colores_originales_poderes:
		var original: Color = registro["color"]
		var propiedad: StringName = registro["propiedad"]
		var color := _color_poder_con_aura(original, propiedad) if aura_persistente_activada else original
		if registro["shader"]:
			(registro["objeto"] as ShaderMaterial).set_shader_parameter(propiedad, color)
		else:
			(registro["objeto"] as Object).set(propiedad, color)


func _aislar_materiales_vfx(efecto: Node3D) -> void:
	# Los prefabs comparten recursos; cada jugador/impacto necesita su propia paleta.
	var materiales: Array[ShaderMaterial] = []
	for hijo: Node in efecto.get_children():
		if hijo is GeometryInstance3D and hijo.material_override is ShaderMaterial:
			hijo.material_override = hijo.material_override.duplicate() as ShaderMaterial
			materiales.append(hijo.material_override)
	efecto.set("materials", materiales)


func _crear_aura_persistente(esqueleto: Skeleton3D) -> void:
	_aura_persistente = ESCENA_AURA_STATUS.instantiate() as Node3D
	_aura_persistente.name = "AuraPersistenteStatusFX"
	_aura_persistente.position = Vector3(0.0, ALTURA_MODELO_POLICIA * 0.5, 0.0)
	_aura_persistente.scale = Vector3.ONE * 0.05
	_aura_persistente.visible = false
	_aura_persistente.set("particles_amount", 180)
	_aura_persistente.set("lifetime", 1.35)
	_aura_persistente.set("emission_shape", Vector3(0.55, 1.0, 0.55))
	_aura_persistente.set("waviness", 0.52)
	_aura_persistente.set("particles_radial", 0.08)
	_aura_persistente.set("particles_vertical", 0.12)
	_material_overlay_aura = MATERIAL_OVERLAY_AURA.duplicate() as ShaderMaterial
	_material_overlay_aura.set_shader_parameter("effect_amount", 0.0)
	for nombre_nodo: String in ["MeshInstance3D", "Aura"]:
		var efecto := _aura_persistente.get_node(nombre_nodo) as GeometryInstance3D
		if efecto == null:
			continue
		var material_base := efecto.material_override as ShaderMaterial
		var material_copia := material_base.duplicate() as ShaderMaterial
		efecto.material_override = material_copia
		if nombre_nodo == "Aura":
			material_copia.set_shader_parameter("use_secondary", true)
			_material_particulas_aura = material_copia
			(_aura_persistente.get_node("Aura") as GPUParticles3D).local_coords = true
			var procesador := (_aura_persistente.get_node("Aura") as GPUParticles3D).process_material.duplicate() as ParticleProcessMaterial
			procesador.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			procesador.emission_box_extents = Vector3(1.0, 1.42, 1.0)
			procesador.direction = Vector3(0.0, 1.0, 0.0)
			# Columnas de fuego más definidas: suben con dirección clara y se
			# abren ligeramente alrededor del cuerpo en vez de parecer humo.
			procesador.initial_velocity_min = 1.0
			procesador.initial_velocity_max = 2.25
			procesador.spread = 22.0
			procesador.radial_velocity_min = 0.08
			procesador.radial_velocity_max = 0.24
			(_aura_persistente.get_node("Aura") as GPUParticles3D).process_material = procesador
			material_copia.set_shader_parameter("noise_scale", Vector2(1.3, 0.85))
			material_copia.set_shader_parameter("shape_curve", 1.45)
			material_copia.set_shader_parameter("edge_hardness", 0.22)
			material_copia.set_shader_parameter("noise_scroll", Vector2(0.07, -0.42))
		else:
			_material_trazos_aura = material_copia
			material_copia.set_shader_parameter("streaks1_count", 18.0)
			material_copia.set_shader_parameter("streaks2_count", 25.0)
			material_copia.set_shader_parameter("streaks_fade", 0.72)
			material_copia.set_shader_parameter("streaks_thickness", 1.15)
			material_copia.set_shader_parameter("center_radius", 0.12)
			material_copia.set_shader_parameter("fade_radius", 0.82)
		_materiales_aura_status.append(material_copia)
	var malla_trazos := _aura_persistente.get_node("MeshInstance3D") as MeshInstance3D
	# El destello del paquete es un QuadMesh billboard; junto a este personaje
	# forma un panel rectangular visible. Las llamas y el overlay del cuerpo bastan.
	malla_trazos.visible = false
	esqueleto.add_child(_aura_persistente)
	_aura_persistente.set("emitting", false)
	_material_overlay_aura.set_shader_parameter("noise_scale", Vector2(1.2, 1.2))
	_material_overlay_aura.set_shader_parameter("noise_scroll", Vector2(0.025, 0.24))
	_material_overlay_aura.set_shader_parameter("offset", 0.028)
	_luz_aura_persistente = OmniLight3D.new()
	_luz_aura_persistente.name = "LuzAuraDoradaPersistente"
	_luz_aura_persistente.light_color = COLOR_EXPLOSION_FINAL_LUZ
	_luz_aura_persistente.light_energy = 0.0
	_luz_aura_persistente.omni_range = 5.0
	_luz_aura_persistente.shadow_enabled = false
	_luz_aura_persistente.position = Vector3(0.0, ALTURA_MODELO_POLICIA * 0.5, 0.0)
	esqueleto.add_child(_luz_aura_persistente)


func _aplicar_color_explosion_final_aura() -> void:
	for material: ShaderMaterial in _materiales_aura_status:
		material.set_shader_parameter("primary_color", COLOR_EXPLOSION_FINAL_PRIMARIO)
		material.set_shader_parameter("secondary_color", COLOR_EXPLOSION_FINAL_SECUNDARIO)
		material.set_shader_parameter("emission", 4.4)
	_material_particulas_aura.set_shader_parameter("tertiary_color", COLOR_EXPLOSION_FINAL_TERCIARIO)
	_material_particulas_aura.set_shader_parameter("color_curve", 1.05)
	_material_particulas_aura.set_shader_parameter("hue_variation", 0.025)
	_material_trazos_aura.set_shader_parameter("primary_color", COLOR_EXPLOSION_FINAL_PRIMARIO)
	_material_trazos_aura.set_shader_parameter("secondary_color", COLOR_EXPLOSION_FINAL_SECUNDARIO)
	_material_trazos_aura.set_shader_parameter("emission", 5.2)
	_material_overlay_aura.set_shader_parameter("primary_color", COLOR_EXPLOSION_FINAL_PRIMARIO)
	_material_overlay_aura.set_shader_parameter("secondary_color", COLOR_EXPLOSION_FINAL_SECUNDARIO)
	_material_overlay_aura.set_shader_parameter("emission", 4.8)
	_material_overlay_aura.set_shader_parameter("color_curve", 0.75)
	_material_overlay_aura.set_shader_parameter("effect_amount", 0.14)


func _aplicar_overlay_aura_al_personaje() -> void:
	_restaurar_overlays_personaje()
	if not is_instance_valid(jugador):
		return
	var modelo := jugador.get_node_or_null("Visual/Modelo")
	if modelo == null:
		return
	for nodo: Node in modelo.find_children("*", "MeshInstance3D", true, false):
		if _energia.is_ancestor_of(nodo) or _aura_persistente.is_ancestor_of(nodo):
			continue
		var malla := nodo as MeshInstance3D
		if malla == null or malla.mesh == null:
			continue
		_overlays_originales_aura.append({"malla": malla, "material": malla.material_overlay})
		malla.material_overlay = _material_overlay_aura


func _restaurar_overlays_personaje() -> void:
	for registro: Dictionary in _overlays_originales_aura:
		var malla := registro.get("malla") as MeshInstance3D
		if is_instance_valid(malla):
			malla.material_overlay = registro.get("material") as Material
	_overlays_originales_aura.clear()


func iniciar_reposo(tipo: StringName) -> bool:
	if gesto != &"" or reposo_especial != &"" or not REPOSOS.has(tipo):
		return false
	reposo_especial = tipo
	tiempo_reposo = 0.0
	_peso_reposo = 0.0
	_saliendo_reposo = false
	return true


func cancelar_reposo() -> void:
	if reposo_especial != &"":
		_saliendo_reposo = true


func establecer_sentado(activo: bool, inmediato: bool = false) -> void:
	sentado = activo
	if activo:
		reposo_especial = &""
		_peso_reposo = 0.0
		_saliendo_reposo = false
	if inmediato:
		_peso_sentado = float(activo)


func cancelar() -> void:
	if is_instance_valid(_explosion_final_activa):
		_separar_humo_final(_explosion_final_activa)
	if gesto == &"genkidama" and is_instance_valid(_genkidama_vfx):
		# Deja terminar el ciclo actual de la esfera y evita que se repita fuera del gesto.
		_genkidama_vfx.set("one_shot", true)
	if is_instance_valid(_impacto_activo):
		_impacto_activo.queue_free()
		_impacto_activo = null
	gesto = &""
	objetivo = null
	_llave.visible = false


func _process(delta: float) -> void:
	tambaleo = jugador.intensidad_tambaleo
	_reloj += delta
	_peso_sentado = move_toward(_peso_sentado, float(sentado), delta * 5.0)
	_peso_taza = move_toward(_peso_taza, float(lleva_taza), delta * 7.0)
	_peso_extintor = move_toward(_peso_extintor, float(rociando_extintor), delta * 8.0)
	var lleva: bool = is_instance_valid(jugador.papel_en_mano)
	_peso_papel = move_toward(_peso_papel, 1.0 if lleva else 0.0, delta * 7.0)
	if reposo_especial != &"":
		if _saliendo_reposo:
			_peso_reposo = move_toward(_peso_reposo, 0.0, delta * 7.0)
			if is_zero_approx(_peso_reposo):
				reposo_especial = &""
				_saliendo_reposo = false
		else:
			_peso_reposo = move_toward(_peso_reposo, 1.0, delta * 5.0)
			tiempo_reposo += delta
			if tiempo_reposo >= float(REPOSOS[reposo_especial]):
				_saliendo_reposo = true
				reposo_terminado.emit()
	_actualizar_transformacion_aura(delta)
	if gesto == &"":
		return
	tiempo = minf(tiempo + delta, duracion)
	if not _contacto_emitido and tiempo >= duracion * float(CONTACTOS[gesto]):
		_contacto_emitido = true
		contacto.emit()
		# El efecto puede cancelar el gesto (por ejemplo, al reiniciar la prueba).
		if gesto == &"":
			return
	if tiempo >= duracion:
		cancelar()
		terminada.emit()


func _actualizar_transformacion_aura(delta: float) -> void:
	if not aura_persistente_activada:
		if is_instance_valid(_luz_aura_persistente):
			_luz_aura_persistente.light_energy = 0.0
		return
	if aura_transformacion_en_curso:
		_tiempo_transformacion_aura = minf(_tiempo_transformacion_aura + delta, DURACION_TRANSFORMACION_AURA)
		aura_transformacion_progreso = _tiempo_transformacion_aura / DURACION_TRANSFORMACION_AURA
	var progreso_suave := smoothstep(0.0, 1.0, aura_transformacion_progreso)
	if aura_transformacion_en_curso:
		var escala_actual := lerpf(ESCALA_INICIAL_AURA_TRANSFORMACION, ESCALA_FINAL_AURA_TRANSFORMACION, progreso_suave)
		_aura_persistente.scale = Vector3.ONE * escala_actual
	if is_instance_valid(_material_overlay_aura):
		var pulso := 0.94 + 0.06 * sin(_reloj * 8.5)
		_material_overlay_aura.set_shader_parameter("effect_amount", lerpf(0.14, 1.0, progreso_suave) * pulso)
	if is_instance_valid(_luz_aura_persistente):
		var tremolo := 0.88 + 0.12 * sin(_reloj * 7.2)
		_luz_aura_persistente.light_energy = lerpf(0.62, 1.25, progreso_suave) * tremolo
	if aura_transformacion_en_curso and aura_transformacion_progreso >= 1.0:
		aura_transformacion_en_curso = false


func _process_modification() -> void:
	if not is_instance_valid(jugador) or _huesos.is_empty():
		return
	var locomocion: StringName = jugador.current_animation
	var ritmo := 2.5
	var amplitud := 0.035
	if locomocion == &"walk":
		ritmo = 7.3
		amplitud = 0.11
	elif locomocion == &"run":
		ritmo = 10.8
		amplitud = 0.16
	elif locomocion in [&"jump", &"fall", &"wave"]:
		ritmo = 5.0
		amplitud = 0.095
	var peso_balanceo := 1.0 - _peso_sentado * 0.85
	var balanceo := sin(_reloj * ritmo) * amplitud * tambaleo * peso_balanceo
	_sumar("spine", Vector3(0.015 * sin(_reloj * ritmo * 2.0) * tambaleo, 0.0, balanceo))
	_sumar("chest", Vector3(0.025 * sin(_reloj * ritmo - 0.6) * tambaleo, balanceo * 0.35, -balanceo * 0.3))
	_sumar("head", Vector3(0.035 * sin(_reloj * ritmo - 0.9) * tambaleo, 0.0, -sin(_reloj * ritmo - 0.7) * amplitud * 1.4 * tambaleo))
	if _peso_sentado > 0.0:
		_aplicar_sentado(_peso_sentado)
	_sostener(_peso_papel)
	_sostener_taza(_peso_taza)
	if reposo_especial != &"":
		_aplicar_reposo(_peso_reposo)
	_llave.visible = gesto == &"reparar"
	if gesto != &"":
		_aplicar_gesto(tiempo / duracion)
	if _peso_extintor > 0.0:
		_aplicar_extintor(_peso_extintor)
	_actualizar_energia()
	var esqueleto := get_skeleton()
	mano_izquierda.transform = esqueleto.get_bone_global_pose(_huesos["hand.L"])
	mano_derecha.transform = esqueleto.get_bone_global_pose(_huesos["hand.R"])
	var inclinacion := 0.0
	if gesto == &"beber":
		var t := tiempo / duracion
		inclinacion = -0.55 * smoothstep(0.22, 0.42, t) * (1.0 - smoothstep(0.66, 0.90, t))
	anclaje_taza.transform = Transform3D(Basis.from_euler(Vector3(inclinacion, 0.0, 0.0)), mano_derecha.position + Vector3(0.13, -0.15, 0.05))


func _aplicar_sentado(peso: float) -> void:
	for lado: String in ["L", "R"]:
		_pose("thigh." + lado, Vector3(-1.48, 0.0, -0.06 if lado == "L" else 0.06), peso)
		_pose("shin." + lado, Vector3(1.52, 0.0, 0.0), peso)
		_pose("foot." + lado, Vector3(-0.04, 0.0, 0.0), peso)
		_pose("upper_arm." + lado, Vector3(-0.30, 0.0, 0.06 if lado == "R" else -0.06), peso)
		_pose("forearm." + lado, Vector3(-0.58, 0.0, 0.0), peso)
	_sumar("spine", Vector3(-0.045 * peso, 0.0, 0.0))
	_sumar("chest", Vector3(0.025 * sin(_reloj * 1.6) * peso, 0.0, 0.0))
	_sumar("head", Vector3(0.025 * sin(_reloj * 1.2 - 0.3) * peso, 0.0, 0.0))


func _aplicar_reposo(peso: float) -> void:
	var t := tiempo_reposo
	var entrar := smoothstep(0.0, 0.35, t)
	var salir := 1.0 - smoothstep(float(REPOSOS[reposo_especial]) - 0.55, float(REPOSOS[reposo_especial]), t)
	var suave := peso * entrar * salir
	if reposo_especial == &"idle_despistado":
		var mirar := sin(t * 2.4) * 0.32 * suave
		var rascar := smoothstep(0.75, 1.2, t) * (1.0 - smoothstep(2.3, 2.8, t)) * peso
		_sumar("spine", Vector3(0.0, mirar * 0.35, sin(t * 3.0) * 0.065 * suave * tambaleo))
		_sumar("head", Vector3(0.08 * suave, mirar, sin(t * 4.0) * 0.11 * suave * tambaleo))
		_pose("upper_arm.R", Vector3(-0.28, 0.0, 2.30), rascar)
		_pose("forearm.R", Vector3(-0.35, 0.0, 0.20 * sin(t * 13.0)), rascar)
		_pose("hand.R", Vector3(0.0, 0.0, 0.20 * sin(t * 13.0)), rascar)
		_sumar("chest", Vector3(0.0, -mirar * 0.3, 0.0))
	else:
		var perder := smoothstep(0.15, 0.55, t) * (1.0 - smoothstep(1.85, 2.3, t)) * peso
		var vaiven := (sin(t * 5.5) * 0.26 + 0.18) * perder * tambaleo
		_sumar("spine", Vector3(0.10 * perder, 0.0, vaiven))
		_sumar("chest", Vector3(-0.08 * perder, 0.0, -vaiven * 0.4))
		_sumar("head", Vector3(-0.13 * perder, 0.0, -vaiven * 1.5))
		_pose("upper_arm.R", Vector3(-0.30, 0.0, 0.85 + 0.20 * sin(t * 8.0)), perder)
		_sumar("upper_arm.L", Vector3(-0.12 * perder, 0.0, -0.18 * perder))
		_pose("thigh.R", Vector3(-0.34, 0.0, 0.0), perder)
		_pose("shin.R", Vector3(0.48, 0.0, 0.0), perder)
		var esqueleto := get_skeleton()
		var raiz: int = _huesos["root"]
		esqueleto.set_bone_pose_position(raiz, esqueleto.get_bone_pose_position(raiz) + Vector3(0.0, -0.07 * perder, 0.0))
		if t > 2.15:
			_sumar("head", Vector3(0.11 * sin((t - 2.15) * 9.0) * suave, 0.0, 0.0))


func _aplicar_gesto(t: float) -> void:
	var entrada := smoothstep(0.0, 0.18, t)
	var salida := 1.0 - smoothstep(0.78, 1.0, t)
	var peso := entrada * salida
	var meneo := sin(t * TAU * 2.0) * 0.10 * tambaleo * peso
	_sumar("spine", Vector3(0.0, 0.0, meneo))
	_sumar("head", Vector3(0.04 * sin(t * TAU * 3.0), -meneo * 0.6, -meneo * 1.3))
	match gesto:
		&"recoger", &"recibir":
			var alcanzar := smoothstep(0.0, 0.32, t) * (1.0 - smoothstep(0.49, 0.85, t))
			var suelo := gesto == &"recoger"
			_sumar("spine", Vector3(0.65 if suelo else 0.10, 0.0, 0.0) * alcanzar)
			_sumar("head", Vector3(0.18, 0.0, 0.0) * alcanzar)
			if suelo:
				var esqueleto := get_skeleton()
				var raiz: int = _huesos["root"]
				esqueleto.set_bone_pose_position(raiz, esqueleto.get_bone_pose_position(raiz) + Vector3(0.0, -0.30 * alcanzar, 0.0))
				for lado: String in ["L", "R"]:
					_pose("thigh." + lado, Vector3(-0.5, 0.0, 0.0), alcanzar)
					_pose("shin." + lado, Vector3(0.9, 0.0, 0.0), alcanzar)
			_pose("upper_arm.L", Vector3(-0.85, 0.0, -0.1), alcanzar)
			_pose("forearm.L", Vector3(-0.12 if suelo else -0.7, 0.0, 0.0), alcanzar)
			# La mano busca la hoja real, también si quedó a un lado de los pies.
			if is_instance_valid(objetivo) and not _contacto_emitido:
				_apuntar_mano(objetivo.global_position, alcanzar)
		&"reparar":
			var ciclo := sin((t - 0.18) * TAU * 4.0)
			_sumar("spine", Vector3(0.19 * peso, 0.0, ciclo * 0.045 * peso * tambaleo))
			_pose("upper_arm.R", Vector3(-0.72, 0.0, 0.12), peso)
			_pose("forearm.R", Vector3(-0.87 + ciclo * 0.24, 0.0, 0.06 * ciclo), peso)
			_pose("hand.R", Vector3(0.0, ciclo * 0.4, ciclo * 0.12), peso)
			if t > 0.83:
				_sumar("head", Vector3(sin((t - 0.83) * TAU * 5.8) * 0.16, 0.0, 0.0))
		&"interactuar":
			_pose("upper_arm.R", Vector3(-0.83, 0.0, 0.06), peso)
			_pose("forearm.R", Vector3(-0.60 + sin(t * TAU * 2.0) * 0.09, 0.0, 0.0), peso)
			_sumar("spine", Vector3(0.10 * peso, 0.05 * peso, 0.0))
		&"lanzar":
			var impulso := smoothstep(0.28, 0.46, t)
			var preparar := smoothstep(0.0, 0.25, t) * (1.0 - impulso)
			_pose("upper_arm.L", Vector3(-0.42 + 0.95 * preparar - impulso, 0.0, -0.14), salida)
			_pose("forearm.L", Vector3(-1.38 + 0.65 * preparar + 1.10 * impulso, 0.0, 0.0), salida)
			_sumar("chest", Vector3(0.0, (-0.17 * preparar + 0.14 * impulso) * salida, 0.0))
		&"beber":
			var sorbo := smoothstep(0.0, 0.30, t) * (1.0 - smoothstep(0.68, 0.96, t))
			_pose("upper_arm.R", Vector3(-0.90, 0.0, 0.08), sorbo)
			_pose("forearm.R", Vector3(-1.65, 0.0, 0.0), sorbo)
			_pose("hand.R", Vector3(0.35, 0.0, -0.05), sorbo)
			_sumar("head", Vector3(-0.07 * sorbo, 0.0, 0.0))
			var esqueleto := get_skeleton()
			var boca := esqueleto.get_bone_global_pose(_huesos["head"]).origin + Vector3(0.0, 0.12, 0.48)
			_apuntar_mano(esqueleto.to_global(boca), sorbo, "R")
		&"kamehameha":
			# Carga de lado: palmas enfrentadas a distintas alturas. Luego gira
			# al frente y proyecta las manos juntas, una arriba de la otra, dejando
			# el hueco central de la "C" para el poder.
			var carga := smoothstep(0.04, 0.22, t) * (1.0 - smoothstep(0.43, 0.58, t))
			var lanzamiento := smoothstep(0.43, 0.62, t) * (1.0 - smoothstep(0.78, 0.94, t))
			var volver := smoothstep(0.82, 1.0, t)
			var temblor := sin(_reloj * 22.0) * carga * 0.025
			_pose("thigh.L", Vector3(-0.27 * carga, 0.0, 0.0), 1.0)
			_pose("thigh.R", Vector3(-0.27 * carga, 0.0, 0.0), 1.0)
			_pose("shin.L", Vector3(0.38 * carga, 0.0, 0.0), 1.0)
			_pose("shin.R", Vector3(0.38 * carga, 0.0, 0.0), 1.0)
			# En Godot, Y negativo gira el frente (+Z) hacia el costado -X,
			# el mismo lado donde se reúnen las manos durante la carga.
			var giro_lateral := -0.72 * carga * (1.0 - lanzamiento)
			_sumar("spine", Vector3(0.12 * carga - 0.05 * lanzamiento, giro_lateral, temblor))
			_sumar("chest", Vector3(-0.08 * carga + 0.10 * lanzamiento, giro_lateral * 0.72, -temblor))
			_sumar("head", Vector3(-0.04 * carga + 0.02 * lanzamiento, -giro_lateral * 0.55, 0.0))
			var esqueleto := get_skeleton()
			# X y Z iguales: las manos quedan apiladas en una sola línea vertical.
			var carga_superior := Vector3(-0.58, 1.49, 0.62)
			var carga_inferior := Vector3(-0.58, 1.23, 0.62)
			var mano_superior := Vector3(-0.13, 1.52, 0.78)
			var mano_inferior := Vector3(0.13, 1.27, 0.78)
			var peso_carga := carga * (1.0 - volver)
			var peso_lanzamiento := maxf(lanzamiento, volver)
			var peso_brazos := maxf(peso_carga, peso_lanzamiento)
			var objetivo_L := carga_superior.lerp(mano_superior, smoothstep(0.36, 0.64, t))
			var objetivo_R := carga_inferior.lerp(mano_inferior, smoothstep(0.36, 0.64, t))
			if peso_brazos > 0.01:
				_apuntar_mano(esqueleto.to_global(objetivo_L), peso_brazos, "L")
				_apuntar_mano(esqueleto.to_global(objetivo_R), peso_brazos, "R")
			_pose("hand.L", Vector3(0.10, 0.0, -0.22), peso_brazos)
			_pose("hand.R", Vector3(-0.08, 0.0, 0.22), peso_brazos)
		&"genkidama":
			var levantar := smoothstep(0.02, 0.24, t) * (1.0 - smoothstep(0.56, 0.69, t))
			var empujar := smoothstep(0.57, 0.72, t) * (1.0 - smoothstep(0.82, 0.96, t))
			var recuperar := smoothstep(0.84, 1.0, t)
			var temblor_esfera := sin(_reloj * 12.0) * levantar * 0.025
			_sumar("spine", Vector3(-0.04 * levantar + 0.12 * empujar, 0.0, temblor_esfera))
			_sumar("chest", Vector3(0.04 * levantar + 0.16 * empujar, 0.0, -temblor_esfera))
			_sumar("head", Vector3(-0.12 * levantar + 0.02 * empujar, 0.0, 0.0))
			var esqueleto := get_skeleton()
			# Manos sobre los hombros y un poco fuera del alcance para estirar los codos.
			var manos_arriba_L := Vector3(0.42, ALTURA_MODELO_POLICIA - 0.10, 0.20)
			var manos_arriba_R := Vector3(-0.42, ALTURA_MODELO_POLICIA - 0.10, 0.20)
			var manos_frente_L := Vector3(0.46, 1.68, 1.02)
			var manos_frente_R := Vector3(-0.46, 1.52, 1.02)
			var transicion_lanzamiento := smoothstep(0.56, 0.73, t)
			var peso_brazos := maxf(levantar, empujar) * (1.0 - recuperar)
			var objetivo_L := manos_arriba_L.lerp(manos_frente_L, transicion_lanzamiento)
			var objetivo_R := manos_arriba_R.lerp(manos_frente_R, transicion_lanzamiento)
			if peso_brazos > 0.01:
				_apuntar_mano(esqueleto.to_global(objetivo_L), peso_brazos, "L")
				_apuntar_mano(esqueleto.to_global(objetivo_R), peso_brazos, "R")
			_pose("hand.L", Vector3(-0.12, 0.0, -0.08), peso_brazos)
			_pose("hand.R", Vector3(0.12, 0.0, 0.08), peso_brazos)
		&"explosion_final":
			# Primero concentra el puño delante del torso; luego abre ambos brazos
			# hacia los lados y atrás para que cada mano permanezca fuera del cuerpo.
			var fase_explosion := tiempo / DURACION_CARGA_EXPLOSION_FINAL
			var preparar := smoothstep(0.02, 0.22, fase_explosion) * (1.0 - smoothstep(0.32, 0.44, fase_explosion))
			var liberar := smoothstep(0.32, 0.58, fase_explosion) * (1.0 - smoothstep(1.32, 1.42, fase_explosion))
			var peso_brazos := maxf(preparar, liberar)
			var esqueleto := get_skeleton()
			_sumar("spine", Vector3(-0.10 * preparar + 0.16 * liberar, 0.0, sin(_reloj * 24.0) * 0.018 * liberar))
			_sumar("chest", Vector3(0.12 * preparar - 0.08 * liberar, 0.0, 0.0))
			var puño_derecho := Vector3(-0.62, 1.52, 0.94)
			var puño_izquierdo := Vector3(0.66, 1.32, 0.20)
			var mano_abierta_L := Vector3(1.28, 1.58, -0.18)
			var mano_abierta_R := Vector3(-1.28, 1.58, -0.18)
			var objetivo_L := puño_izquierdo.lerp(mano_abierta_L, liberar)
			var objetivo_R := puño_derecho.lerp(mano_abierta_R, liberar)
			if peso_brazos > 0.01:
				_apuntar_mano(esqueleto.to_global(objetivo_L), peso_brazos, "L")
				_apuntar_mano(esqueleto.to_global(objetivo_R), peso_brazos, "R")
			_pose("hand.R", Vector3(-0.10, 0.0, 0.0), preparar * (1.0 - liberar))
			_pose("hand.L", Vector3.ZERO, liberar)
		&"rasengan":
			var agacharse := smoothstep(0.0, 0.20, t) * (1.0 - smoothstep(0.78, 0.96, t))
			var extender := smoothstep(0.10, 0.40, t) * (1.0 - smoothstep(0.86, 0.99, t))
			var impulso := smoothstep(0.62, 0.72, t)
			var vibracion := sin(_reloj * 13.0) * agacharse * 0.018
			_pose("thigh.L", Vector3(-0.16 * agacharse, 0.0, 0.0), 1.0)
			_pose("thigh.R", Vector3(-0.16 * agacharse, 0.0, 0.0), 1.0)
			_pose("shin.L", Vector3(0.20 * agacharse, 0.0, 0.0), 1.0)
			_pose("shin.R", Vector3(0.20 * agacharse, 0.0, 0.0), 1.0)
			_sumar("spine", Vector3(0.14 * agacharse, 0.0, vibracion))
			_sumar("chest", Vector3(0.08 * agacharse + 0.12 * impulso, 0.0, -vibracion))
			_sumar("head", Vector3(-0.06 * agacharse, 0.0, 0.0))
			var esqueleto := get_skeleton()
			# El blanco queda más allá del alcance cómodo para que el brazo se estire.
			var mano_objetivo := Vector3(-0.58, 1.50, 1.18)
			if extender > 0.01:
				_apuntar_mano(esqueleto.to_global(mano_objetivo), extender, "R")
			_pose("hand.R", Vector3(0.0, 0.0, 0.08), extender)


func _aplicar_extintor(peso: float) -> void:
	# Izquierda en el asa; derecha dirige la boquilla con un barrido corto.
	var barrido := sin(_reloj * 3.8) * 0.10
	_pose("upper_arm.L", Vector3(-0.48, 0.0, -0.16), peso)
	_pose("forearm.L", Vector3(-1.12, 0.0, 0.0), peso)
	_pose("hand.L", Vector3.ZERO, peso)
	_pose("upper_arm.R", Vector3(-1.0, barrido, 0.12), peso)
	_pose("forearm.R", Vector3(-0.48, 0.0, 0.0), peso)
	_pose("hand.R", Vector3(0.0, barrido, 0.0), peso)
	_pose("thigh.L", Vector3(-0.14, 0.0, -0.05), peso)
	_pose("shin.L", Vector3(0.22, 0.0, 0.0), peso)
	_pose("thigh.R", Vector3(0.10, 0.0, 0.05), peso)
	_sumar("spine", Vector3(-0.09 + sin(_reloj * 19.0) * 0.012, barrido * 0.3, 0.0) * peso)
	_sumar("head", Vector3(0.10, -barrido * 0.3, 0.0) * peso)


func _sostener(peso: float) -> void:
	_pose("upper_arm.L", Vector3(-0.42, 0.0, -0.12), peso)
	_pose("forearm.L", Vector3(-1.38, 0.0, 0.0), peso)
	_pose("hand.L", Vector3.ZERO, peso)


func _sostener_taza(peso: float) -> void:
	_pose("upper_arm.R", Vector3(-0.32, 0.0, 0.06), peso)
	_pose("forearm.R", Vector3(-1.40, 0.0, 0.0), peso)
	_pose("hand.R", Vector3.ZERO, peso)


func _pose(nombre: String, giro: Vector3, peso: float) -> void:
	var esqueleto := get_skeleton()
	var i: int = _huesos[nombre]
	var destino: Quaternion = _reposo[nombre] * Quaternion.from_euler(giro)
	esqueleto.set_bone_pose_rotation(i, esqueleto.get_bone_pose_rotation(i).slerp(destino, peso))


func _sumar(nombre: String, giro: Vector3) -> void:
	var esqueleto := get_skeleton()
	var i: int = _huesos[nombre]
	esqueleto.set_bone_pose_rotation(i, esqueleto.get_bone_pose_rotation(i) * Quaternion.from_euler(giro))


func _apuntar_mano(destino_global: Vector3, peso: float, lado: String = "L") -> void:
	var esqueleto := get_skeleton()
	var destino := esqueleto.to_local(destino_global)
	# CCD breve: rota hombro y codo, sin mover el cuerpo físico ni estirar huesos.
	for repeticion: int in range(3):
		for nombre: String in ["forearm." + lado, "upper_arm." + lado]:
			var i: int = _huesos[nombre]
			var pose := esqueleto.get_bone_global_pose(i)
			var mano := esqueleto.get_bone_global_pose(_huesos["hand." + lado]).origin
			var desde := (mano - pose.origin).normalized()
			var hacia := (destino - pose.origin).normalized()
			if desde.is_zero_approx() or hacia.is_zero_approx():
				continue
			var ajuste := Quaternion(desde, hacia)
			var padre := esqueleto.get_bone_global_pose(esqueleto.get_bone_parent(i)).basis.get_rotation_quaternion()
			var local := padre.inverse() * ajuste * padre * esqueleto.get_bone_pose_rotation(i)
			esqueleto.set_bone_pose_rotation(i, esqueleto.get_bone_pose_rotation(i).slerp(local, peso * 0.65))


func _crear_energia(esqueleto: Skeleton3D) -> void:
	_energia = Node3D.new()
	_energia.name = "EfectosKamehameha"
	esqueleto.add_child(_energia)
	_esfera_energia = Node3D.new()
	_esfera_energia.name = "EsferaDeEnergia"
	_energia.add_child(_esfera_energia)
	var material_exterior := StandardMaterial3D.new()
	material_exterior.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_exterior.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_exterior.albedo_color = Color(0.12, 0.72, 1.0, 0.34)
	material_exterior.emission_enabled = true
	material_exterior.emission = Color(0.04, 0.52, 1.0)
	material_exterior.emission_energy_multiplier = 2.4
	var exterior := MeshInstance3D.new()
	var malla_exterior := SphereMesh.new()
	malla_exterior.radius = 0.19
	malla_exterior.height = 0.38
	exterior.mesh = malla_exterior
	exterior.material_override = material_exterior
	_esfera_energia.add_child(exterior)
	var material_nucleo := StandardMaterial3D.new()
	material_nucleo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_nucleo.albedo_color = Color(0.72, 0.96, 1.0)
	material_nucleo.emission_enabled = true
	material_nucleo.emission = Color(0.30, 0.82, 1.0)
	material_nucleo.emission_energy_multiplier = 4.0
	var nucleo := MeshInstance3D.new()
	var malla_nucleo := SphereMesh.new()
	malla_nucleo.radius = 0.105
	malla_nucleo.height = 0.21
	nucleo.mesh = malla_nucleo
	nucleo.material_override = material_nucleo
	_esfera_energia.add_child(nucleo)
	var luz := OmniLight3D.new()
	luz.light_color = Color(0.16, 0.68, 1.0)
	luz.light_energy = 1.8
	luz.omni_range = 2.4
	_esfera_energia.add_child(luz)
	var escena_aura := ESCENA_AURA_AZUL.instantiate() as Node3D
	escena_aura.name = "AuraAzulBattleFX"
	_energia.add_child(escena_aura)
	_aura = escena_aura.get_node("Surface") as MeshInstance3D
	_aura.position = Vector3(0.0, ESCALA_AURA_PERSONAJE.y * 2.0, 0.0)
	_aura.scale = ESCALA_AURA_PERSONAJE
	_material_aura = (_aura.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	_aura.material_override = _material_aura
	_material_aura.set_shader_parameter("primary_color", Color(0.34, 0.86, 1.0))
	_material_aura.set_shader_parameter("secondary_color", Color(0.025, 0.26, 0.90))
	_material_aura.set_shader_parameter("tertiary_color", Color(0.005, 0.035, 0.28))
	_material_aura.set_shader_parameter("emission", 1.6)
	_material_aura.set_shader_parameter("effect_decay", 1.0)
	# Usamos la superficie esférica del escudo como una envoltura ajustada al cuerpo.
	escena_aura.get_node("Aura").visible = false
	_orbita_aura = escena_aura.get_node("Orbit") as MeshInstance3D
	_orbita_aura.position = _aura.position
	_orbita_aura.scale = Vector3.ONE * 0.52
	_material_orbita_aura = (_orbita_aura.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	_orbita_aura.material_override = _material_orbita_aura
	_material_orbita_aura.set_shader_parameter("primary_color", Color(0.46, 0.89, 1.0))
	_material_orbita_aura.set_shader_parameter("secondary_color", Color(0.045, 0.32, 1.0))
	_material_orbita_aura.set_shader_parameter("tertiary_color", Color(0.005, 0.035, 0.30))
	_material_orbita_aura.set_shader_parameter("emission", 1.9)
	_material_orbita_aura.set_shader_parameter("effect_decay", 1.0)
	_material_orbita_aura.set_shader_parameter("rotation_frequency", 0.65)
	_material_orbita_aura.set_shader_parameter("rotation_amount", 0.24)
	escena_aura.get_node("Shards").visible = false
	_luz_aura = OmniLight3D.new()
	_luz_aura.name = "LuzAuraAzul"
	_luz_aura.light_color = Color(0.035, 0.22, 1.0)
	_luz_aura.light_energy = 1.2
	_luz_aura.omni_range = 3.8
	_luz_aura.position = Vector3(0.0, 1.35, 0.0)
	_energia.add_child(_luz_aura)
	var escena_aura_dorada := ESCENA_AURA_AZUL.instantiate() as Node3D
	escena_aura_dorada.name = "AuraDoradaExplosionFinal"
	_energia.add_child(escena_aura_dorada)
	_aura_dorada = escena_aura_dorada.get_node("Surface") as MeshInstance3D
	_aura_dorada.position = Vector3(0.0, ESCALA_AURA_PERSONAJE.y * 2.0, 0.0)
	_aura_dorada.scale = ESCALA_AURA_PERSONAJE
	_material_aura_dorada = (_aura_dorada.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	_aura_dorada.material_override = _material_aura_dorada
	_material_aura_dorada.set_shader_parameter("primary_color", COLOR_EXPLOSION_FINAL_PRIMARIO)
	_material_aura_dorada.set_shader_parameter("secondary_color", COLOR_EXPLOSION_FINAL_SECUNDARIO)
	_material_aura_dorada.set_shader_parameter("tertiary_color", COLOR_EXPLOSION_FINAL_TERCIARIO)
	_material_aura_dorada.set_shader_parameter("emission", 2.2)
	_material_aura_dorada.set_shader_parameter("effect_decay", 1.0)
	escena_aura_dorada.get_node("Aura").visible = false
	_orbita_dorada = escena_aura_dorada.get_node("Orbit") as MeshInstance3D
	_orbita_dorada.position = _aura_dorada.position
	_orbita_dorada.scale = Vector3.ONE * 0.52
	_material_orbita_dorada = (_orbita_dorada.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	_orbita_dorada.material_override = _material_orbita_dorada
	_material_orbita_dorada.set_shader_parameter("primary_color", Color(1.0, 0.96, 0.55))
	_material_orbita_dorada.set_shader_parameter("secondary_color", Color(1.0, 0.55, 0.05))
	_material_orbita_dorada.set_shader_parameter("tertiary_color", Color(0.45, 0.10, 0.0))
	_material_orbita_dorada.set_shader_parameter("emission", 2.5)
	_material_orbita_dorada.set_shader_parameter("effect_decay", 1.0)
	_material_orbita_dorada.set_shader_parameter("rotation_frequency", 0.8)
	_material_orbita_dorada.set_shader_parameter("rotation_amount", 0.28)
	escena_aura_dorada.get_node("Shards").visible = false
	_luz_dorada = OmniLight3D.new()
	_luz_dorada.name = "LuzAuraDorada"
	_luz_dorada.light_color = Color(1.0, 0.62, 0.12)
	_luz_dorada.light_energy = 0.0
	_luz_dorada.omni_range = 5.2
	_luz_dorada.position = Vector3(0.0, 1.35, 0.0)
	_energia.add_child(_luz_dorada)
	_crear_genkidama()
	_crear_rasengan()
	_rayo_vfx = Node3D.new()
	_rayo_vfx.name = "RayoKamehamehaAzul"
	_rayo_vfx.position = Vector3(0.0, 1.36, 1.55)
	_rayo_vfx.rotation.x = PI * 0.5 # El eje largo local Y del tubo apunta hacia delante (+Z).
	_energia.add_child(_rayo_vfx)
	_orbe_inicio_rayo = Node3D.new()
	_orbe_inicio_rayo.name = "EsferaInicialKamehameha"
	_rayo_vfx.add_child(_orbe_inicio_rayo)
	_orbe_inicio_rayo.add_child(_crear_orbe_kamehameha(1.10 * ESCALA_GROSOR_KAMEHAMEHA * ESCALA_ORBE_INICIO_KAMEHAMEHA, 0.68 * ESCALA_GROSOR_KAMEHAMEHA * ESCALA_ORBE_INICIO_KAMEHAMEHA))
	_orbe_final_rayo = Node3D.new()
	_orbe_final_rayo.name = "EsferaFinalKamehameha"
	_rayo_vfx.add_child(_orbe_final_rayo)
	_orbe_final_rayo.add_child(_crear_orbe_kamehameha(0.98 * ESCALA_GROSOR_KAMEHAMEHA, 0.60 * ESCALA_GROSOR_KAMEHAMEHA))
	_rayos_malla.clear()
	_rayos_malla.append(_crear_tubo_kamehameha("AureolaDeEnergia", 1.12 * ESCALA_GROSOR_KAMEHAMEHA, 1.0 * ESCALA_GROSOR_KAMEHAMEHA, Color(0.008, 0.12, 1.0), 0.16))
	_rayos_malla.append(_crear_tubo_kamehameha("DescargaAzul", 0.94 * ESCALA_GROSOR_KAMEHAMEHA, 0.84 * ESCALA_GROSOR_KAMEHAMEHA, Color(0.025, 0.40, 1.0), 0.54))
	_rayos_malla.append(_crear_tubo_kamehameha("CentroBlancoAzulado", 0.60 * ESCALA_GROSOR_KAMEHAMEHA, 0.54 * ESCALA_GROSOR_KAMEHAMEHA, Color(0.68, 0.94, 1.0), 0.96))
	_rayo_vfx.visible = false
	_energia.visible = false
	for efecto: Node in [_esfera_energia, _aura, _orbita_aura, _luz_aura, _rayo_vfx, _esfera_genkidama, _rasengan]:
		_registrar_colores_poder(efecto)


func _crear_orbe_kamehameha(radio_exterior: float, radio_nucleo: float) -> Node3D:
	var orbe := Node3D.new()
	var exterior := _crear_esfera_rayo(radio_exterior, Color(0.02, 0.34, 1.0, 0.48), 3.0)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
uniform vec3 secondary_color : source_color = vec3(0.012, 0.12, 0.76);
uniform vec3 primary_color : source_color = vec3(0.34, 0.86, 1.0);

void fragment() {
	float giro = UV.x * TAU * 5.0 + UV.y * 18.0 - TIME * 5.0
		+ sin(UV.y * 11.0 - TIME * 2.2) * 1.1;
	float corriente = smoothstep(-0.28, 0.82, sin(giro));
	float borde = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.25);
	vec3 azul = mix(secondary_color, primary_color, corriente);
	ALBEDO = azul;
	EMISSION = azul * (0.9 + corriente * 1.25 + borde * 0.55);
	ALPHA = clamp(0.56 + corriente * 0.28 + borde * 0.14, 0.56, 0.96);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("secondary_color", Color(0.012, 0.12, 0.76))
	material.set_shader_parameter("primary_color", Color(0.34, 0.86, 1.0))
	exterior.material_override = material
	orbe.add_child(exterior)
	orbe.add_child(_crear_esfera_rayo(radio_nucleo, Color(0.73, 0.95, 1.0), 4.2))
	return orbe


func _crear_tubo_kamehameha(nombre: String, radio_inicio: float, radio_final: float, color: Color, opacidad: float) -> MeshInstance3D:
	var anillos: int = 96
	var segmentos: int = 128
	var vertices := PackedVector3Array()
	var normales := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for anillo: int in range(anillos + 1):
		var avance := float(anillo) / float(anillos)
		var comienzo_punta_redonda := 1.0 - radio_final / LONGITUD_KAMEHAMEHA
		var radio: float
		if avance < comienzo_punta_redonda:
			radio = lerpf(radio_inicio, radio_final, smoothstep(0.0, 0.76, avance))
		else:
			var progreso_punta := (avance - comienzo_punta_redonda) / (1.0 - comienzo_punta_redonda)
			radio = radio_final * sqrt(maxf(1.0 - progreso_punta * progreso_punta, 0.0))
		for segmento: int in range(segmentos + 1):
			var vuelta := float(segmento) / float(segmentos)
			var angulo := vuelta * TAU
			var radial := Vector2(cos(angulo), sin(angulo))
			vertices.append(Vector3(radial.x * radio, avance - 0.5, radial.y * radio))
			normales.append(Vector3(radial.x, 0.0, radial.y))
			uv.append(Vector2(vuelta, avance))
	for anillo: int in range(anillos):
		for segmento: int in range(segmentos):
			var actual := anillo * (segmentos + 1) + segmento
			var siguiente := actual + segmentos + 1
			indices.append(actual)
			indices.append(siguiente)
			indices.append(actual + 1)
			indices.append(actual + 1)
			indices.append(siguiente)
			indices.append(siguiente + 1)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normales
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var haz := ArrayMesh.new()
	haz.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var tubo := MeshInstance3D.new()
	tubo.name = nombre
	tubo.mesh = haz
	tubo.scale.y = 0.0
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec3 beam_color : source_color;
uniform vec3 highlight_color : source_color = vec3(0.84, 0.98, 1.0);
uniform float beam_alpha = 0.5;

void vertex() {
	float phase = UV.y * 18.0 - TIME * 3.8 + sin(UV.x * TAU * 5.0 - TIME * 2.4) * 0.55;
	float wave = sin(phase) * 0.035 * smoothstep(0.0, 0.8, UV.y);
	vec2 radial = normalize(VERTEX.xz + vec2(0.0001));
	VERTEX.xz += radial * wave;
	VERTEX.x += sin(UV.y * 5.0 - TIME * 1.4) * 0.08 * UV.y;
	VERTEX.z += cos(UV.y * 4.0 - TIME * 1.2) * 0.035 * UV.y;
}

void fragment() {
	float drift = UV.x * TAU * 7.0 + UV.y * 18.0 - TIME * 6.5;
	float wave = sin(drift + sin(UV.y * 7.0 + TIME * 1.7) * 1.3);
	float filament = smoothstep(-0.28, 0.86, wave);
	float bands = 0.73 + 0.18 * sin(UV.x * TAU * 3.0 - UV.y * 8.0 - TIME * 3.0);
	vec3 color = mix(beam_color, highlight_color, filament * 0.42);
	ALBEDO = color;
	EMISSION = color * (0.95 + filament * 1.1);
	ALPHA = beam_alpha * clamp(bands + filament * 0.18, 0.22, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("beam_color", color)
	material.set_shader_parameter("highlight_color", Color(0.84, 0.98, 1.0))
	material.set_shader_parameter("beam_alpha", opacidad)
	tubo.material_override = material
	_rayo_vfx.add_child(tubo)
	return tubo

func _crear_genkidama() -> void:
	_esfera_genkidama = Node3D.new()
	_esfera_genkidama.name = "Genkidama"
	_esfera_genkidama.position = Vector3(0.0, ALTURA_MODELO_POLICIA + RADIO_GENKIDAMA * ESCALA_GENKIDAMA, 0.25)
	_energia.add_child(_esfera_genkidama)
	var esfera_energia := _crear_esfera_rayo(RADIO_GENKIDAMA, Color(0.035, 0.34, 1.0), 2.0)
	var shader_esfera := Shader.new()
	shader_esfera.code = """
shader_type spatial;
render_mode unshaded;
uniform vec3 tertiary_color : source_color = vec3(0.012, 0.075, 0.48);
uniform vec3 secondary_color : source_color = vec3(0.015, 0.31, 0.95);
uniform vec3 primary_color : source_color = vec3(0.30, 0.82, 1.0);
void fragment() {
	float giro = UV.x * 6.28318 * 9.0 + UV.y * 24.0 - TIME * 3.4;
	float corrientes = sin(giro + sin(UV.y * 31.0 - TIME * 2.1) * 1.6);
	float vetas = smoothstep(-0.20, 0.78, corrientes);
	float nubes = 0.5 + 0.5 * sin(UV.x * 42.0 + sin(UV.y * 28.0 - TIME) * 2.0 + TIME * 1.5);
	vec3 profundo = tertiary_color;
	vec3 azul = secondary_color;
	vec3 brillo = primary_color;
	vec3 color = mix(profundo, azul, 0.42 + vetas * 0.42);
	color = mix(color, brillo, smoothstep(0.78, 0.97, nubes) * (0.20 + vetas * 0.45));
	ALBEDO = color;
	EMISSION = color * (1.4 + vetas * 1.8 + smoothstep(0.78, 0.97, nubes) * 1.2);
}
"""
	var material_esfera := ShaderMaterial.new()
	material_esfera.shader = shader_esfera
	material_esfera.set_shader_parameter("tertiary_color", Color(0.012, 0.075, 0.48))
	material_esfera.set_shader_parameter("secondary_color", Color(0.015, 0.31, 0.95))
	material_esfera.set_shader_parameter("primary_color", Color(0.30, 0.82, 1.0))
	esfera_energia.material_override = material_esfera
	_esfera_genkidama.add_child(esfera_energia)
	_esfera_genkidama.add_child(_crear_esfera_rayo(1.48, Color(0.64, 0.92, 1.0), 4.2))
	_capa_aura_genkidama = _crear_malla_aura_esferica("MantoDeAuraGenkidama", RADIO_GENKIDAMA * 1.015, _material_aura)
	_esfera_genkidama.add_child(_capa_aura_genkidama)
	_material_aura_genkidama = _capa_aura_genkidama.material_override as ShaderMaterial
	_material_aura_genkidama.set_shader_parameter("primary_color", Color(0.54, 0.91, 1.0))
	_material_aura_genkidama.set_shader_parameter("secondary_color", Color(0.025, 0.30, 0.98))
	_material_aura_genkidama.set_shader_parameter("tertiary_color", Color(0.005, 0.045, 0.38))
	_material_aura_genkidama.set_shader_parameter("effect_decay", 0.42)
	_material_aura_genkidama.set_shader_parameter("emission", 2.1)
	_orbita_genkidama = _crear_malla_aura_esferica("CorrientesDeAuraGenkidama", RADIO_GENKIDAMA * 1.065, _material_orbita_aura)
	_esfera_genkidama.add_child(_orbita_genkidama)
	_material_orbita_genkidama = _orbita_genkidama.material_override as ShaderMaterial
	_material_orbita_genkidama.set_shader_parameter("primary_color", Color(0.72, 0.97, 1.0))
	_material_orbita_genkidama.set_shader_parameter("secondary_color", Color(0.06, 0.42, 1.0))
	_material_orbita_genkidama.set_shader_parameter("tertiary_color", Color(0.005, 0.06, 0.42))
	_material_orbita_genkidama.set_shader_parameter("effect_decay", 0.58)
	_material_orbita_genkidama.set_shader_parameter("emission", 1.9)
	_genkidama_vfx = ESCENA_CARGA_AZUL.instantiate() as Node3D
	_aislar_materiales_vfx(_genkidama_vfx)
	_genkidama_vfx.name = "EsferaBattleFX"
	_genkidama_vfx.scale = Vector3.ONE * 1.25
	_genkidama_vfx.set("primary_color", Color(0.50, 0.91, 1.0))
	_genkidama_vfx.set("secondary_color", Color(0.02, 0.38, 1.0))
	_genkidama_vfx.set("tertiary_color", Color(0.005, 0.045, 0.35))
	_genkidama_vfx.set("emission", 3.0)
	_genkidama_vfx.set("particle_amount", 48)
	_genkidama_vfx.set("particle_local_coords", true)
	_genkidama_vfx.set("speed_scale", 0.78)
	_esfera_genkidama.add_child(_genkidama_vfx)
	_luz_genkidama = OmniLight3D.new()
	_luz_genkidama.name = "LuzGenkidama"
	_luz_genkidama.light_color = Color(0.12, 0.52, 1.0)
	_luz_genkidama.light_energy = 3.0
	_luz_genkidama.omni_range = 5.0
	_esfera_genkidama.add_child(_luz_genkidama)
	_esfera_genkidama.visible = false


func _crear_impacto_azul(posicion_global: Vector3, escala: float, duracion_humo: float = 0.0, velocidad: float = 1.6, persistir: bool = false) -> void:
	var impacto := ESCENA_IMPACTO_AZUL.instantiate() as Node3D
	_aislar_materiales_vfx(impacto)
	impacto.name = "ImpactoAzulTemporal"
	# El prefab se marca con autoplay; desactivarlo antes de entrar al árbol evita que repita el estallido.
	impacto.set("autoplay", false)
	impacto.set("one_shot", true)
	impacto.set("primary_color", Color(0.36, 0.82, 1.0))
	impacto.set("secondary_color", Color(0.025, 0.24, 0.88))
	impacto.set("tertiary_color", Color(0.005, 0.035, 0.30))
	impacto.set("emission", 2.3)
	impacto.set("light_color", Color(0.08, 0.42, 1.0))
	if aura_persistente_activada:
		impacto.set("primary_color", COLOR_EXPLOSION_FINAL_PRIMARIO)
		impacto.set("secondary_color", COLOR_EXPLOSION_FINAL_SECUNDARIO)
		impacto.set("tertiary_color", COLOR_EXPLOSION_FINAL_TERCIARIO)
		impacto.set("light_color", COLOR_EXPLOSION_FINAL_LUZ)
	impacto.set("speed_scale", velocidad)
	if duracion_humo > 0.0:
		var humo := impacto.get_node_or_null("Smoke") as GPUParticles3D
		if is_instance_valid(humo):
			humo.lifetime = duracion_humo
	get_skeleton().add_child(impacto)
	if not persistir:
		_impacto_activo = impacto
	impacto.global_position = posicion_global
	impacto.scale = Vector3.ONE * escala
	(impacto.get_node("AnimationPlayer") as AnimationPlayer).play("main")
	_liberar_impacto_azul(impacto, duracion_humo if duracion_humo > 0.0 else 0.82, persistir)


func _crear_explosion_final_amarilla(posicion_global: Vector3) -> void:
	var impacto := ESCENA_IMPACTO_AZUL.instantiate() as Node3D
	_aislar_materiales_vfx(impacto)
	impacto.name = "ExplosionFinalVegeta"
	impacto.set("autoplay", false)
	impacto.set("one_shot", true)
	impacto.set("primary_color", COLOR_EXPLOSION_FINAL_PRIMARIO)
	impacto.set("secondary_color", COLOR_EXPLOSION_FINAL_SECUNDARIO)
	impacto.set("tertiary_color", COLOR_EXPLOSION_FINAL_TERCIARIO)
	impacto.set("emission", 2.8)
	impacto.set("light_color", COLOR_EXPLOSION_FINAL_LUZ)
	impacto.set("speed_scale", 0.9)
	var humo := impacto.get_node_or_null("Smoke") as GPUParticles3D
	if is_instance_valid(humo):
		humo.lifetime = 5.0
	var malla_centro := SphereMesh.new()
	malla_centro.radius = RADIO_GENKIDAMA
	malla_centro.height = RADIO_GENKIDAMA * 2.0
	malla_centro.radial_segments = 64
	malla_centro.rings = 40
	var centro_dorado := MeshInstance3D.new()
	centro_dorado.name = "CentroSolidoExplosion"
	centro_dorado.mesh = malla_centro
	var material_centro := StandardMaterial3D.new()
	material_centro.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_centro.albedo_color = COLOR_EXPLOSION_FINAL_SECUNDARIO
	material_centro.emission_enabled = true
	material_centro.emission = COLOR_EXPLOSION_FINAL_SECUNDARIO
	material_centro.emission_energy_multiplier = 1.3
	centro_dorado.material_override = material_centro
	impacto.add_child(centro_dorado)
	var borde := _crear_malla_aura_esferica("BordeEsfericoDorado", RADIO_GENKIDAMA * 1.035, _material_aura_dorada)
	impacto.add_child(borde)
	var material_borde := borde.material_override as ShaderMaterial
	material_borde.set_shader_parameter("primary_color", COLOR_EXPLOSION_FINAL_PRIMARIO)
	material_borde.set_shader_parameter("secondary_color", COLOR_EXPLOSION_FINAL_SECUNDARIO)
	material_borde.set_shader_parameter("tertiary_color", COLOR_EXPLOSION_FINAL_TERCIARIO)
	material_borde.set_shader_parameter("effect_decay", 0.56)
	material_borde.set_shader_parameter("emission", 2.7)
	var corrientes := _crear_malla_aura_esferica("CorrientesEsfericasDoradas", RADIO_GENKIDAMA * 1.085, _material_orbita_dorada)
	impacto.add_child(corrientes)
	var material_corrientes := corrientes.material_override as ShaderMaterial
	material_corrientes.set_shader_parameter("primary_color", Color(1.0, 0.96, 0.58))
	material_corrientes.set_shader_parameter("secondary_color", Color(1.0, 0.60, 0.08))
	material_corrientes.set_shader_parameter("tertiary_color", Color(0.48, 0.11, 0.005))
	material_corrientes.set_shader_parameter("effect_decay", 0.64)
	material_corrientes.set_shader_parameter("emission", 2.3)
	get_skeleton().add_child(impacto)
	impacto.global_position = posicion_global
	impacto.scale = Vector3.ONE * ESCALA_GENKIDAMA * 1.65
	(impacto.get_node("AnimationPlayer") as AnimationPlayer).play("main")
	_explosion_final_activa = impacto
	_apagar_explosion_y_dejar_humo(impacto, humo, maxf(0.0, duracion - tiempo))


func _apagar_explosion_y_dejar_humo(impacto: Node3D, humo: GPUParticles3D, segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout
	if not is_instance_valid(impacto):
		return
	_separar_humo_final(impacto, humo)


func _separar_humo_final(impacto: Node3D, humo: GPUParticles3D = null) -> void:
	if not is_instance_valid(impacto):
		_explosion_final_activa = null
		return
	var humo_residual := humo if is_instance_valid(humo) else impacto.get_node_or_null("Smoke") as GPUParticles3D
	if is_instance_valid(humo_residual) and humo_residual.get_parent() == impacto:
		var transformacion_humo := humo_residual.global_transform
		humo_residual.emitting = false
		impacto.remove_child(humo_residual)
		get_skeleton().add_child(humo_residual)
		humo_residual.name = "HumoResidualExplosionFinal"
		humo_residual.global_transform = transformacion_humo
		_liberar_humo_residual(humo_residual, humo_residual.lifetime)
	impacto.queue_free()
	_explosion_final_activa = null


func _liberar_humo_residual(humo: GPUParticles3D, segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout
	if is_instance_valid(humo):
		humo.queue_free()


func _liberar_impacto_azul(impacto: Node3D, segundos: float, persistir: bool) -> void:
	# El efecto se recorta antes de que las partículas largas de humo queden flotando en el mapa.
	await get_tree().create_timer(segundos).timeout
	if not is_instance_valid(impacto):
		return
	impacto.queue_free()
	if not persistir and _impacto_activo == impacto:
		_impacto_activo = null


func _crear_rasengan() -> void:
	_rasengan = Node3D.new()
	_rasengan.name = "RasenganEnMano"
	_rasengan.add_child(_crear_esfera_rayo(0.50, Color(0.025, 0.42, 1.0), 3.8))
	_rasengan.add_child(_crear_esfera_rayo(0.31, Color(0.76, 0.98, 1.0), 5.6))
	_energia.add_child(_rasengan)
	_rasengan_espinas = Node3D.new()
	_rasengan_espinas.name = "EspinasAzules"
	_rasengan.add_child(_rasengan_espinas)
	_crear_espinas_rasengan(_rasengan_espinas, 10, 0.45, 0.11, 0.36, Color(0.12, 0.62, 1.0), 4.5)
	_rasengan_espinas_inversas = Node3D.new()
	_rasengan_espinas_inversas.name = "EspinasClaras"
	_rasengan.add_child(_rasengan_espinas_inversas)
	_crear_espinas_rasengan(_rasengan_espinas_inversas, 8, 0.35, 0.08, 0.27, Color(0.62, 0.92, 1.0), 5.0, PI / 8.0)
	_capa_aura_rasengan = _crear_malla_aura_esferica("CapaAuraRasengan", 0.53, _material_aura)
	_rasengan.add_child(_capa_aura_rasengan)
	_material_aura_rasengan = _capa_aura_rasengan.material_override as ShaderMaterial
	_material_aura_rasengan.set_shader_parameter("primary_color", Color(0.65, 0.96, 1.0))
	_material_aura_rasengan.set_shader_parameter("secondary_color", Color(0.03, 0.38, 1.0))
	_material_aura_rasengan.set_shader_parameter("tertiary_color", Color(0.005, 0.04, 0.32))
	_material_aura_rasengan.set_shader_parameter("effect_decay", 0.48)
	_material_aura_rasengan.set_shader_parameter("emission", 2.7)
	_orbita_rasengan = _crear_malla_aura_esferica("EspiralAuraRasengan", 0.56, _material_orbita_aura)
	_rasengan.add_child(_orbita_rasengan)
	_material_orbita_rasengan = _orbita_rasengan.material_override as ShaderMaterial
	_material_orbita_rasengan.set_shader_parameter("primary_color", Color(0.75, 0.98, 1.0))
	_material_orbita_rasengan.set_shader_parameter("secondary_color", Color(0.05, 0.44, 1.0))
	_material_orbita_rasengan.set_shader_parameter("tertiary_color", Color(0.005, 0.05, 0.36))
	_material_orbita_rasengan.set_shader_parameter("effect_decay", 0.62)
	_material_orbita_rasengan.set_shader_parameter("emission", 2.3)
	var luz := OmniLight3D.new()
	luz.name = "LuzRasengan"
	luz.light_color = Color(0.05, 0.48, 1.0)
	luz.light_energy = 1.8
	luz.omni_range = 3.4
	_rasengan.add_child(luz)
	_rasengan.visible = false


func _crear_espinas_rasengan(grupo: Node3D, cantidad: int, radio: float, radio_base: float, alto: float, color: Color, brillo: float, desfase: float = 0.0) -> void:
	for indice: int in range(cantidad):
		var angulo := TAU * float(indice) / float(cantidad) + desfase
		var direccion := Vector3(cos(angulo), sin(angulo), 0.0)
		var punta := MeshInstance3D.new()
		var cono := CylinderMesh.new()
		cono.top_radius = 0.0
		cono.bottom_radius = radio_base
		cono.height = alto
		cono.radial_segments = 20
		punta.mesh = cono
		punta.position = direccion * radio
		punta.quaternion = Quaternion(Vector3.UP, direccion)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b)
		material.emission_energy_multiplier = brillo
		punta.material_override = material
		grupo.add_child(punta)


func _crear_esfera_rayo(radio: float, color: Color, brillo: float) -> MeshInstance3D:
	var esfera := MeshInstance3D.new()
	var malla := SphereMesh.new()
	malla.radius = radio
	malla.height = radio * 2.0
	malla.radial_segments = 64
	malla.rings = 40
	esfera.mesh = malla
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = brillo
	esfera.material_override = material
	return esfera


func _crear_malla_aura_esferica(nombre: String, radio: float, material_base: ShaderMaterial) -> MeshInstance3D:
	var malla_aura := SphereMesh.new()
	malla_aura.radius = radio
	malla_aura.height = radio * 2.0
	malla_aura.radial_segments = 64
	malla_aura.rings = 40
	var capa := MeshInstance3D.new()
	capa.name = nombre
	capa.mesh = malla_aura
	capa.material_override = material_base.duplicate() as ShaderMaterial
	return capa


func _actualizar_energia() -> void:
	if not is_instance_valid(_energia):
		return
	var es_kamehameha := gesto == &"kamehameha"
	var es_genkidama := gesto == &"genkidama"
	var es_rasengan := gesto == &"rasengan"
	var es_explosion_final := gesto == &"explosion_final"
	if not es_kamehameha and not es_genkidama and not es_rasengan and not es_explosion_final:
		_energia.visible = false
		return
	_energia.visible = true
	var t := tiempo / duracion
	var fuerza_aura := 0.0 if es_rasengan else smoothstep(0.02, 0.18, t) * (1.0 - smoothstep(0.84, 0.99, t))
	_aura.visible = fuerza_aura > 0.01 and not es_explosion_final
	_orbita_aura.visible = fuerza_aura > 0.01 and not es_explosion_final
	var fase_aura_dorada := tiempo / DURACION_CARGA_EXPLOSION_FINAL
	var fuerza_aura_dorada := smoothstep(0.02, 0.20, fase_aura_dorada) * (1.0 - smoothstep(1.32, 1.42, fase_aura_dorada)) if es_explosion_final else 0.0
	_aura_dorada.visible = fuerza_aura_dorada > 0.01
	_orbita_dorada.visible = fuerza_aura_dorada > 0.01
	_aura_dorada.scale = ESCALA_AURA_PERSONAJE * (1.0 + sin(_reloj * 10.0) * 0.025 * fuerza_aura_dorada)
	_material_aura_dorada.set_shader_parameter("effect_decay", 1.0 - fuerza_aura_dorada * 0.64)
	_material_aura_dorada.set_shader_parameter("emission", 2.0 + fuerza_aura_dorada * 1.7)
	_material_orbita_dorada.set_shader_parameter("effect_decay", 1.0 - fuerza_aura_dorada * 0.58)
	_material_orbita_dorada.set_shader_parameter("emission", 1.8 + fuerza_aura_dorada * 1.8)
	_orbita_dorada.rotation.y = _reloj * 0.82
	_luz_dorada.light_energy = fuerza_aura_dorada * 3.8
	_aura.scale = ESCALA_AURA_PERSONAJE * (1.0 + sin(_reloj * 8.0) * 0.018 * fuerza_aura)
	_material_aura.set_shader_parameter("effect_decay", 1.0 - fuerza_aura * 0.55)
	_material_aura.set_shader_parameter("emission", 1.6 + fuerza_aura * 1.1)
	_material_orbita_aura.set_shader_parameter("effect_decay", 1.0 - fuerza_aura * 0.50)
	_material_orbita_aura.set_shader_parameter("emission", 1.3 + fuerza_aura * 1.0)
	_orbita_aura.rotation.y = _reloj * 0.34
	_luz_aura.light_energy = 0.0 if es_explosion_final else 1.0 + fuerza_aura * 2.6
	if es_explosion_final:
		_rayo_vfx.visible = false
		_esfera_genkidama.visible = false
		_esfera_energia.visible = false
		_rasengan.visible = false
		if tiempo >= DURACION_CARGA_EXPLOSION_FINAL * 0.72 and not _impacto_disparado:
			_impacto_disparado = true
			_crear_explosion_final_amarilla(_energia.to_global(Vector3(0.0, 1.30, 0.0)))
		return
	if es_rasengan:
		_rayo_vfx.visible = false
		_esfera_genkidama.visible = false
		_esfera_energia.visible = false
		var aparicion := smoothstep(0.30, 0.48, t) * (1.0 - smoothstep(0.97, 1.0, t))
		var mano := get_skeleton().get_bone_global_pose(_huesos["hand.R"]).origin
		var posicion_en_mano := mano + Vector3(-0.28, 0.02, 1.15)
		if t >= 0.68 and not _rasengan_lanzado:
			_origen_lanzamiento_rasengan = posicion_en_mano
			_rasengan_lanzado = true
		if _rasengan_lanzado:
			var recorrido := smoothstep(0.68, 0.96, t)
			_rasengan.position = _origen_lanzamiento_rasengan.lerp(_origen_lanzamiento_rasengan + Vector3(0.0, 0.0, RECORRIDO_RASENGAN), recorrido)
		else:
			_rasengan.position = posicion_en_mano
		_rasengan.visible = aparicion > 0.01
		_rasengan.scale = Vector3.ONE * 2.1 * aparicion * (1.0 + sin(_reloj * 9.0) * 0.035)
		_rasengan_espinas.rotation.z = _reloj * 8.0
		_rasengan_espinas_inversas.rotation.z = -_reloj * 10.5
		_orbita_rasengan.rotation.y = _reloj * 1.3
		_orbita_rasengan.rotation.x = _reloj * 0.45
		if t >= 0.96 and not _impacto_disparado:
			_impacto_disparado = true
			_crear_impacto_azul(_energia.to_global(_rasengan.position), 2.2, 5.0, 1.1, true)
		return
	_rasengan.visible = false
	if es_genkidama:
		_rayo_vfx.visible = false
		_esfera_energia.visible = false
		_esfera_genkidama.visible = t > 0.14 and t < 0.995
		var crecimiento := smoothstep(0.14, 0.34, t)
		var vuelo := smoothstep(0.66, 0.97, t)
		var pulso_genki := 1.0 + sin(_reloj * 7.0) * 0.035
		var altura_genkidama := ALTURA_MODELO_POLICIA + RADIO_GENKIDAMA * ESCALA_GENKIDAMA
		_esfera_genkidama.position = Vector3(0.0, altura_genkidama, 0.25).lerp(Vector3(0.0, altura_genkidama, RECORRIDO_GENKIDAMA), vuelo)
		_esfera_genkidama.scale = Vector3.ONE * ESCALA_GENKIDAMA * crecimiento * pulso_genki
		_capa_aura_genkidama.rotation.y = _reloj * 0.46
		_orbita_genkidama.rotation.y = -_reloj * 0.72
		_orbita_genkidama.rotation.x = sin(_reloj * 0.55) * 0.22
		_luz_genkidama.light_energy = 1.5 + crecimiento * (1.5 + 1.0 * (1.0 - vuelo))
		if t >= 0.95 and not _impacto_disparado:
			_impacto_disparado = true
			_crear_impacto_azul(_energia.to_global(_esfera_genkidama.position), 3.4, 5.0, 0.9, true)
		return
	_esfera_genkidama.visible = false
	var carga := smoothstep(0.08, 0.20, t) * (1.0 - smoothstep(0.48, 0.60, t))
	var avance := smoothstep(0.59, 0.90, t)
	var desvanecer_rayo := 1.0 - smoothstep(0.93, 0.995, t)
	var apertura_rayo := smoothstep(0.59, 0.90, t) * desvanecer_rayo
	var desvanecer_carga := 1.0 - smoothstep(0.52, 0.60, t)
	_esfera_energia.visible = t > 0.08 and t < 0.60
	# La esfera sigue el punto medio real de las palmas mientras las manos se juntan para cargar.
	var esqueleto := get_skeleton()
	var palma_izquierda := esqueleto.get_bone_global_pose(_huesos["hand.L"]).origin
	var palma_derecha := esqueleto.get_bone_global_pose(_huesos["hand.R"]).origin
	var centro_manos := (palma_izquierda + palma_derecha) * 0.5
	_esfera_energia.position = centro_manos
	var adelanto_orbe := 0.42 + 1.10 * (ESCALA_GROSOR_KAMEHAMEHA - 1.0) + 1.10 * ESCALA_GROSOR_KAMEHAMEHA * (ESCALA_ORBE_INICIO_KAMEHAMEHA - 1.0)
	_rayo_vfx.position = centro_manos + Vector3(0.0, 0.0, adelanto_orbe)
	var pulso := 1.0 + sin(_reloj * 10.0) * (0.08 + carga * 0.14)
	_esfera_energia.scale = Vector3.ONE * pulso * desvanecer_carga
	_luz_aura.light_energy = 0.8 + fuerza_aura * (1.0 + carga * 1.2)
	_rayo_vfx.visible = apertura_rayo > 0.001
	var largo_rayo := LONGITUD_KAMEHAMEHA * apertura_rayo
	_orbe_inicio_rayo.visible = apertura_rayo > 0.001
	_orbe_inicio_rayo.scale = Vector3.ONE * (0.96 + 0.04 * sin(_reloj * 11.0))
	_orbe_final_rayo.visible = apertura_rayo > 0.08
	_orbe_final_rayo.position.y = largo_rayo
	_orbe_final_rayo.scale = Vector3.ONE * smoothstep(0.08, 0.24, apertura_rayo) * (0.96 + 0.04 * sin(_reloj * 13.0))
	for tubo: MeshInstance3D in _rayos_malla:
		tubo.visible = apertura_rayo > 0.001
		tubo.scale.y = largo_rayo
		tubo.position.y = largo_rayo * 0.5
	if t >= 0.89 and not _impacto_disparado:
		_impacto_disparado = true
		var punto_impacto := _energia.to_global(centro_manos + Vector3(0.0, 0.0, adelanto_orbe + LONGITUD_KAMEHAMEHA * avance))
		_crear_impacto_azul(punto_impacto, 4.0, 5.0, 0.9, true)


func _crear_llave() -> void:
	_llave = Node3D.new()
	_llave.name = "LlaveReparacion"
	mano_derecha.add_child(_llave)
	_llave.position.y = 0.10
	_llave.rotation.x = -1.25
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("9fb8ca")
	metal.metallic = 0.55
	metal.roughness = 0.35
	for datos: Array in [
		[Vector3(0.0, 0.20, 0.0), Vector3(0.065, 0.32, 0.065)],
		[Vector3(0.0, 0.38, 0.0), Vector3(0.16, 0.07, 0.065)],
		[Vector3(-0.06, 0.45, 0.0), Vector3(0.04, 0.10, 0.065)],
		[Vector3(0.06, 0.45, 0.0), Vector3(0.04, 0.10, 0.065)]]:
		var pieza := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = datos[1]
		pieza.mesh = caja
		pieza.position = datos[0]
		pieza.material_override = metal
		_llave.add_child(pieza)
	_llave.visible = false
