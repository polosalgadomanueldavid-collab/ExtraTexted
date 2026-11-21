extends Node3D
## Cintas y fragmentos originales sincronizados con los cuatro gestos del esqueleto.
var tipo: StringName = &"control_agua"
var jugador: Player
var tiempo := 0.0
const DURACION := 3.8
const FUEGO := preload("res://Objetos/ZonaDescanso/flujo_fuego.gd")
const AGUA := preload("res://Objetos/ZonaDescanso/flujo_agua.gd")
const COREOGRAFIA := preload("res://Personajes/PoliciaAzul/coreografia_avatar.gd")
var _cintas: Array[MeshInstance3D] = []
var _fragmentos: Array[MeshInstance3D] = []
var _luz: OmniLight3D
var _material: StandardMaterial3D
var _material_cinta: ShaderMaterial
var _llamas: Array[Node3D] = []
var _estelas: Array[MeshInstance3D] = []
var _recorridos: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array()]
var _ondas_pisada: Array[MeshInstance3D] = []
var _fase_anterior := 0.0
var _pisada: AudioStreamPlayer3D
var _agua: Node3D
var _barrido_fuego: Node3D
var _frente_fuego := Vector3.BACK
var _centro_fuego := Vector3.ZERO
var _descarga_fijada := false

func _ready() -> void:
	var color := Color("43caff")
	match tipo:
		&"control_fuego": color = Color("ff862e")
		&"control_tierra": color = Color("c79759")
		&"control_aire": color = Color("e2fff4")
	_material = StandardMaterial3D.new()
	_material.albedo_color = color
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.emission_enabled = true
	_material.emission = color
	_material.emission_energy_multiplier = 1.4
	if tipo == &"control_tierra":
		_material.albedo_color = Color("78634c")
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_material.emission_enabled = false
		_material.roughness = 0.95
	_material_cinta = ShaderMaterial.new()
	_material_cinta.shader = preload("res://Objetos/ZonaDescanso/cinta_elemental.gdshader")
	_material_cinta.set_shader_parameter("tinte", color)
	_material_cinta.set_shader_parameter("aire", tipo == &"control_aire")
	for i in (3 if tipo == &"control_aire" else (2 if tipo == &"control_tierra" else 0)):
		var cinta := MeshInstance3D.new()
		cinta.mesh = ImmediateMesh.new()
		cinta.material_override = _material_cinta
		cinta.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cinta)
		_cintas.append(cinta)
	if tipo == &"control_agua":
		_agua = AGUA.new()
		_agua.jugador = jugador
		add_child(_agua)
	if tipo == &"control_tierra":
		_pisada = AudioStreamPlayer3D.new()
		_pisada.stream = preload("res://Audios/Pasos/SuelaGoma/paso_03.wav")
		_pisada.bus = "Interacciones"
		_pisada.pitch_scale = 0.7
		_pisada.volume_db = -5.0
		add_child(_pisada)
		for i in 2:
			var onda := MeshInstance3D.new()
			var aro := TorusMesh.new()
			aro.inner_radius = .88
			aro.outer_radius = 1.0
			aro.rings = 32
			aro.ring_segments = 6
			onda.mesh = aro
			onda.material_override = _material.duplicate()
			onda.hide()
			add_child(onda)
			_ondas_pisada.append(onda)
		for i in 10:
			var pieza := MeshInstance3D.new()
			var malla := CylinderMesh.new()
			malla.top_radius = 0.13
			malla.bottom_radius = 0.24
			malla.height = 0.48
			malla.radial_segments = 5
			pieza.mesh = malla
			pieza.material_override = _material
			add_child(pieza)
			_fragmentos.append(pieza)
	if tipo == &"control_fuego":
		_barrido_fuego = preload("res://Objetos/ZonaDescanso/barrido_fuego.gd").new()
		add_child(_barrido_fuego)
		for i in 8:
			var llama := FUEGO.new()
			llama.ancho = 0.24
			llama.profundo = 0.16
			llama.semilla = i * .37
			add_child(llama)
			_llamas.append(llama)
	if tipo == &"control_aire":
		for i in 2:
			var estela := MeshInstance3D.new()
			estela.mesh = ImmediateMesh.new()
			estela.material_override = _material_cinta
			estela.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(estela)
			_estelas.append(estela)
	_luz = OmniLight3D.new()
	_luz.position.y = 0.9
	_luz.light_color = color
	_luz.omni_range = 4.0
	add_child(_luz)

func _process(delta: float) -> void:
	if not is_instance_valid(jugador) or (tiempo < 2.5 and not jugador.realizando_gesto()):
		queue_free()
		return
	tiempo += delta
	if jugador.realizando_gesto() and jugador.gestos.gesto == tipo:
		tiempo = jugador.gestos.tiempo
	var t := tiempo / DURACION
	var fase := clampf(tiempo / 3.6, 0, 1)
	if t >= 1.0:
		queue_free()
		return
	var presencia := smoothstep(0.02, 0.18, t) * (1.0 - smoothstep(0.75, 1.0, t))
	_material.albedo_color.a = presencia * (0.65 if tipo == &"control_aire" else 0.88)
	_material_cinta.set_shader_parameter("tiempo", tiempo)
	_material_cinta.set_shader_parameter("presencia", presencia)
	_luz.light_energy = presencia * (1.2 if tipo == &"control_fuego" else .30)
	if tipo == &"control_fuego":
		_actualizar_fuego(fase, presencia)
	if is_instance_valid(_agua):
		_agua.actualizar(tiempo, presencia)
	var expansion := smoothstep(0.56, 0.95, t)
	var coreografia := COREOGRAFIA.muestrear(tipo, fase)
	var giro: float = coreografia.root.y
	_actualizar_estelas(presencia)
	for i in _ondas_pisada.size():
		var impacto: float = COREOGRAFIA.PISADAS_TIERRA[i]
		var onda := _ondas_pisada[i]
		if _fase_anterior < impacto and fase >= impacto:
			onda.global_position = jugador.gestos.posicion_pie("L" if i == 0 else "R")
			onda.global_position.y = global_position.y + .025
			_pisada.global_position = onda.global_position
			_pisada.play()
		var avance := (fase - impacto) / .18
		onda.visible = avance >= 0.0 and avance <= 1.0
		if onda.visible:
			onda.scale = Vector3(1, .035, 1) * lerpf(.12, 1.45, avance)
			(onda.material_override as StandardMaterial3D).albedo_color.a = (1.0 - avance) * .6
	_fase_anterior = fase
	for i in _cintas.size():
		if tipo == &"control_aire":
			_cinta_aire(_cintas[i].mesh as ImmediateMesh, i, fase, giro, presencia)
			continue
		var radio := 0.6 + i * 0.19 + expansion * 5.5
		var altura := 0.18 + i * 0.24
		var ancho := 0.045
		if tipo == &"control_agua":
			altura = lerpf(_mano_local("L" if i == 0 else "R").y, .15, expansion)
			ancho = 0.08
		elif tipo == &"control_fuego":
			altura = 0.35 + i * 0.3
			ancho = 0.07
		elif tipo == &"control_tierra":
			altura = 0.035
			radio = 0.5 + expansion * 6.0 + i * 0.1
			ancho = 0.025
			_cintas[i].visible = fase >= COREOGRAFIA.PISADAS_TIERRA[i]
		elif tipo == &"control_aire":
			_cintas[i].rotation.y = giro
		_cinta(_cintas[i].mesh as ImmediateMesh, radio, altura, ancho * presencia, i, t)
	for i in _fragmentos.size():
		var angulo := TAU * float(i) / _fragmentos.size()
		var pieza := _fragmentos[i]
		var pisada: float = COREOGRAFIA.PISADAS_TIERRA[i % 2]
		var elevar := smoothstep(pisada, pisada + .07, fase) * (1.0 - smoothstep(.75, 1.0, fase))
		pieza.position = Vector3(cos(angulo), 0.0, sin(angulo)) * (0.9 + expansion * 1.5)
		# Fragmentos bajos delante para que la silueta y las pisadas se lean.
		# Las columnas laterales suben después del segundo golpe de talón.
		var lateral := absf(cos(angulo))
		var columna := smoothstep(.54, .65, fase) * lateral * .25
		pieza.position.y = -.18 + elevar * (.28 + (i % 3) * .035 + columna)
		pieza.rotation = Vector3(0.15 * elevar, angulo, 0.25 * elevar)
		pieza.scale = Vector3.ONE * presencia * (.55 + lateral * .15)

func _actualizar_fuego(fase: float, presencia: float) -> void:
	var golpe_l := COREOGRAFIA.pulso(fase, .335, .38, .475)
	var golpe_r := COREOGRAFIA.pulso(fase, .205, .24, .335)
	var patada := COREOGRAFIA.pulso(fase, .50, .56, .65)
	var carga := COREOGRAFIA.pulso(fase, .61, .665, .71) * .32
	var descarga := smoothstep(.685, .735, fase)
	var origenes: Array[Vector3] = [_mano_local("L"), _mano_local("R"), to_local(jugador.gestos.posicion_pie("R"))]
	var direcciones: Array[Vector3] = []
	for lado: String in ["L", "R"]:
		direcciones.append((global_basis.inverse() * jugador.gestos.direcciones_antebrazos[lado]).normalized())
	direcciones.append((origenes[2] - Vector3(0, .32, 0)).normalized())
	var fuerzas: Array[float] = [golpe_l, golpe_r, patada]
	for j in 3:
		var llama: Node3D = _llamas[[0, 1, 6][j]]
		var fuerza := fuerzas[j]
		var remate := descarga * (1.0 - smoothstep(.80, .90, fase)) if j < 2 else 0.0
		llama.position = origenes[j]
		llama.quaternion = Quaternion(Vector3.UP, direcciones[j])
		llama.reloj = tiempo
		llama.largo = .25 + fuerza * (3.1 if j == 2 else 2.65) + remate * 4.8
		llama.ancho = .16 + fuerza * (1.2 if j == 2 else .95) + remate * 1.4
		llama.profundo = llama.ancho * .85
		llama.establecer_intensidad(maxf(fuerza, maxf(remate, carga if j < 2 else 0.0)) * presencia)
	_barrido_fuego.actualizar(tiempo, origenes, direcciones, fuerzas, presencia)
	# Las dos palmas alimentan un frente ancho. Las lenguas secundarias abren
	# el abanico a distancia del cuerpo para conservar el origen del impulso.
	var centro := (origenes[0] + origenes[1]) * .5
	var frente := (direcciones[0] + direcciones[1]).normalized()
	if frente.is_zero_approx():
		frente = Vector3.BACK
	if not _descarga_fijada:
		_centro_fuego = centro
		_frente_fuego = frente
		_descarga_fijada = fase >= .735
	# La masa lanzada conserva su rumbo al bajar los brazos en la recuperación.
	if _descarga_fijada:
		centro = _centro_fuego
		frente = _frente_fuego
	var apertura := smoothstep(.715, .85, fase)
	for j in 5:
		var llama: Node3D = _llamas[[2, 3, 4, 5, 7][j]]
		var abanico := (j - 2) * .24 * apertura
		var direccion := frente.rotated(Vector3.UP, abanico)
		direccion = (direccion + Vector3.UP * (.03 + (j % 2) * .09)).normalized()
		llama.position = centro + frente * (.55 + apertura * .35)
		llama.quaternion = Quaternion(Vector3.UP, direccion)
		llama.reloj = tiempo
		llama.largo = (3.8 + apertura * 1.5) * (1.0 - absf(j - 2) * .085)
		llama.ancho = 1.1 + apertura * .75
		llama.profundo = llama.ancho * .82
		llama.establecer_intensidad(smoothstep(.715, .765, fase) * presencia * .84)
	var energia := maxf(maxf(golpe_l, golpe_r), maxf(patada, descarga))
	_luz.position = centro + frente * descarga * 1.2
	_luz.omni_range = 4.0 + energia * 3.0
	_luz.light_energy = presencia * (.35 + energia * 2.3)

func _mano_local(lado: String) -> Vector3:
	var anclaje: Node3D = jugador.gestos.mano_izquierda if lado == "L" else jugador.gestos.mano_derecha
	return to_local(anclaje.global_position)

func _cinta_aire(malla: ImmediateMesh, indice: int, fase: float, giro: float, presencia: float) -> void:
	# Espirales abiertas e inclinadas: rodean el gesto y convergen entre las
	# palmas antes de salir como una ráfaga frontal. No son aros planos apilados.
	var recoger := COREOGRAFIA.pulso(fase, .55, .655, .72)
	var salida := smoothstep(.70, .94, fase)
	var radio := (.46 + indice * .15) * (1.0 - recoger * .55) + salida * (1.4 + indice * .3)
	var centro := Vector3(0, .32, 0).lerp((_mano_local("L") + _mano_local("R")) * .5, recoger)
	centro.z += salida * 2.8
	var inclinacion := lerpf(.35 + indice * .42, PI * .5, smoothstep(.66, .76, fase))
	var plano := Basis(Vector3.UP, giro + indice * .8) * Basis(Vector3.RIGHT, inclinacion)
	plano = plano.slerp(Basis(Vector3.RIGHT, PI * .5), smoothstep(.66, .76, fase))
	malla.clear_surfaces()
	malla.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for j in 65:
		var u := float(j) / 64.0
		var angulo := u * TAU * .82 + tiempo * 4.8 + indice * 2.1
		var grosor := sin(u * PI) * (.022 + indice * .008) * presencia
		for lado: float in [-1.0, 1.0]:
			var r := radio + lado * grosor
			var punto := Vector3(cos(angulo) * r, sin(u * PI) * .08, sin(angulo) * r)
			malla.surface_set_uv(Vector2(u, (lado + 1.0) * .5))
			malla.surface_add_vertex(centro + plano * punto)
	malla.surface_end()

func _actualizar_estelas(presencia: float) -> void:
	for i in _estelas.size():
		var camino := _recorridos[i]
		camino.append(_mano_local("L" if i == 0 else "R"))
		if camino.size() > 22:
			camino.remove_at(0)
		_recorridos[i] = camino
		var malla := _estelas[i].mesh as ImmediateMesh
		malla.clear_surfaces()
		if camino.size() < 2:
			continue
		malla.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for j in camino.size():
			var u := float(j) / (camino.size() - 1)
			var tangente := camino[mini(j + 1, camino.size() - 1)] - camino[maxi(0, j - 1)]
			var normal := tangente.cross(Vector3.UP).normalized()
			if normal.is_zero_approx():
				normal = Vector3.RIGHT
			for lado: float in [-1.0, 1.0]:
				malla.surface_set_uv(Vector2(u, (lado + 1.0) * .5))
				malla.surface_add_vertex(camino[j] + normal * lado * .065 * u * presencia)
		malla.surface_end()

func _cinta(malla: ImmediateMesh, radio: float, altura: float, ancho: float, indice: int, t: float) -> void:
	malla.clear_surfaces()
	malla.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for paso in 81:
		var u := float(paso) / 80.0
		var angulo := u * TAU + tiempo * (2.8 if indice % 2 == 0 else -2.8) + indice * PI
		var elevacion := sin(angulo * 2.0 + tiempo * 2.0) * 0.13 * (1.0 - smoothstep(0.55, 0.85, t))
		if tipo == &"control_aire":
			elevacion += u * 0.3
		if tipo == &"control_tierra":
			elevacion = 0.0
		for lado: float in [-1.0, 1.0]:
			var r := radio + ancho * lado
			malla.surface_set_uv(Vector2(u, (lado + 1.0) * 0.5))
			malla.surface_add_vertex(Vector3(cos(angulo) * r, altura + elevacion + ancho * lado * 0.4, sin(angulo) * r))
	malla.surface_end()
