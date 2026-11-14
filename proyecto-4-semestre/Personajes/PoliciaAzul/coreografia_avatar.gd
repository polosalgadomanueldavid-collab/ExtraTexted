extends RefCounted
## Coreografías originales inspiradas en Toph, Korra, Aang y Zuko.
## Curvas en fase normalizada: la resolución del evento ocurre en 0,72.
## La raíz solo mueve la silueta; nunca desplaza el cuerpo ni sus colisiones.
const TIPOS := [&"control_tierra", &"control_agua", &"control_aire", &"control_fuego"]
const PISADAS_TIERRA := [0.29, 0.51]

static func es_elemental(tipo: StringName) -> bool:
	return tipo in TIPOS

static func curva(t: float, claves: Array) -> float:
	for i in range(1, claves.size()):
		var a: Vector2 = claves[i - 1]
		var b: Vector2 = claves[i]
		if t <= b.x:
			return lerpf(a.y, b.y, smoothstep(a.x, b.x, t))
	return claves.back().y

static func pulso(t: float, inicio: float, cima: float, fin: float) -> float:
	return smoothstep(inicio, cima, t) * (1.0 - smoothstep(cima, fin, t))

static func muestrear(tipo: StringName, t: float) -> Dictionary:
	var pose := {
		"root": Vector3.ZERO, "desplazamiento": Vector3.ZERO,
		"pelvis": Vector3.ZERO, "spine": Vector3.ZERO, "chest": Vector3.ZERO,
		"head": Vector3.ZERO,
	}
	for lado: String in ["L", "R"]:
		for hueso: String in ["upper_arm", "forearm", "hand", "thigh", "shin", "foot"]:
			pose[hueso + "." + lado] = Vector3.ZERO
	match tipo:
		&"control_tierra": _tierra(pose, t)
		&"control_agua": _agua(pose, t)
		&"control_aire": _aire(pose, t)
		&"control_fuego": _fuego(pose, t)
	return pose

static func _tierra(p: Dictionary, t: float) -> void:
	# Escuchar el suelo, abrir la base, levantar una rodilla y descargar el talón.
	# Dos ataques cortos separados por una pausa de apoyo, no un trote cíclico.
	var izquierda := curva(t, [Vector2(0, 0), Vector2(.16, 0), Vector2(.24, 1), Vector2(.29, 0), Vector2(1, 0)])
	var derecha := curva(t, [Vector2(0, 0), Vector2(.37, 0), Vector2(.46, 1), Vector2(.51, 0), Vector2(1, 0)])
	var impacto := pulso(t, .285, .30, .35) + pulso(t, .505, .52, .57)
	var alzar := smoothstep(.54, .65, t)
	var empujar := smoothstep(.66, .72, t)
	var peso := sin(t * PI * 2.0) * .10 + (derecha - izquierda) * .14
	p.desplazamiento = Vector3(peso, 0, empujar * .10)
	p.pelvis = Vector3(.05, 0, (izquierda - derecha) * .10)
	p.spine = Vector3(.12 + impacto * .12 - empujar * .16, 0, -peso * .35)
	p.chest = Vector3(-.06, (izquierda - derecha) * .14, 0)
	p.head = Vector3(.12 * (1.0 - alzar), 0, peso * .15)
	for lado: String in ["L", "R"]:
		var s := 1.0 if lado == "L" else -1.0
		var levantar := izquierda if lado == "L" else derecha
		p["thigh." + lado] = Vector3(-.32 - levantar * 1.15 - impacto * .12, -s * .13, -s * .24)
		p["shin." + lado] = Vector3(.52 + levantar * 1.1 + impacto * .18, 0, 0)
		p["foot." + lado] = Vector3(-.20 - levantar * .35, -s * .14, s * .08)
		# Codos recogidos al pecho; palmas elevan la roca y golpean al frente.
		p["upper_arm." + lado] = Vector3(-.28 - alzar * .65 - empujar * .55, s * .12, -s * (.48 - empujar * .27))
		p["forearm." + lado] = Vector3(-1.25 + alzar * .3 + empujar * .83, 0, 0)
		p["hand." + lado] = Vector3(-.35 + empujar * .85, s * .08, 0)

static func _agua(p: Dictionary, t: float) -> void:
	# Korra: recoger desde la cadera, rodear con ambos brazos y conducir la ola
	# sobre el hombro; la pierna de apoyo cambia antes del empuje final.
	var giro := curva(t, [Vector2(0, 0), Vector2(.16, -.55), Vector2(.34, .6), Vector2(.52, -.42), Vector2(.65, -.2), Vector2(.72, .18), Vector2(1, 0)])
	var paso := curva(t, [Vector2(0, 0), Vector2(.20, -.18), Vector2(.40, .22), Vector2(.58, -.1), Vector2(.72, .18), Vector2(1, 0)])
	var recoger := smoothstep(.05, .20, t)
	var arco := sin(clampf((t - .19) / .43, 0, 1) * PI)
	var descargar := smoothstep(.63, .72, t)
	p.desplazamiento = Vector3(paso, 0, descargar * .12)
	p.root = Vector3(0, giro * .38, 0)
	p.pelvis = Vector3(.02, giro * .12, paso * -.18)
	p.spine = Vector3(.08 - arco * .12 + descargar * .12, giro * .52, paso * .25)
	p.chest = Vector3(-.06, giro * .30, -paso * .22)
	p.head = Vector3(-arco * .10, -giro * .48, 0)
	for lado: String in ["L", "R"]:
		var s := 1.0 if lado == "L" else -1.0
		var apoyar := clampf(.5 + paso * s * 2.0, 0, 1)
		var fase := clampf((t - (.12 if lado == "L" else .21)) / .43, 0, 1) * PI
		var barrido := sin(fase)
		p["thigh." + lado] = Vector3(-.14 - apoyar * .35, -s * .10 + giro * .10, -s * .14)
		p["shin." + lado] = Vector3(.20 + apoyar * .45, 0, 0)
		p["foot." + lado] = Vector3(-.12 - apoyar * .16, giro * .15, 0)
		p["upper_arm." + lado] = Vector3(-.35 - recoger * .25 - barrido * 1.9, s * (.45 * cos(fase)) - giro * .3, -s * (.25 + barrido * .65))
		p["forearm." + lado] = Vector3(-.65 + barrido * .46, s * .10, 0)
		p["hand." + lado] = Vector3(.25 * cos(fase), s * .35 * sin(fase), -s * .20)
		p["upper_arm." + lado] = p["upper_arm." + lado].lerp(Vector3(-1.40, s * .10, -s * .25), descargar)
		p["forearm." + lado] = p["forearm." + lado].lerp(Vector3(-.12, 0, 0), descargar)
		p["hand." + lado] = p["hand." + lado].lerp(Vector3(.40, 0, -s * .12), descargar)

# Pistas de rotación en grados: XYZ y fase W. Las manos pueden retrasarse
# respecto a la cadera sin obligar a todo el cuerpo a detenerse en cada pose.
static func trazo(t: float, claves: Array) -> Vector3:
	for i in range(1, claves.size()):
		var a: Vector4 = claves[i - 1]
		var b: Vector4 = claves[i]
		if t <= b.w:
			var v := Vector3(a.x, a.y, a.z).lerp(Vector3(b.x, b.y, b.z), smoothstep(a.w, b.w, t))
			return v * (PI / 180.0)
	var ultimo: Vector4 = claves.back()
	return Vector3(ultimo.x, ultimo.y, ultimo.z) * (PI / 180.0)

static func _aire(p: Dictionary, t: float) -> void:
	# Palma circular de entrada -> esquiva baja -> paso cruzado y giro ->
	# barrido alto/bajo -> recoger el aire al pecho -> doble palma en zancada.
	# El torso conduce; las manos llegan después y dibujan dos arcos distintos.
	var giro := curva(t, [Vector2(0, 0), Vector2(.14, -.38), Vector2(.24, .12), Vector2(.46, PI), Vector2(.61, TAU), Vector2(1, TAU)])
	var esquiva := pulso(t, .08, .22, .36)
	var giro_pie := pulso(t, .27, .45, .61)
	var recoger := pulso(t, .56, .65, .715)
	var soltar := smoothstep(.665, .72, t)
	p.root = Vector3(0, giro, 0)
	p.desplazamiento = Vector3(-.48 * esquiva + sin(giro) * .32, 0, -.20 * recoger + .40 * soltar)
	p.pelvis = trazo(t, [Vector4(0, 0, 0, 0), Vector4(9, -16, 12, .22), Vector4(-4, 12, -8, .43), Vector4(6, -12, 6, .60), Vector4(12, 0, 0, .72)])
	p.spine = trazo(t, [Vector4(0, 0, 0, 0), Vector4(22, -18, 18, .22), Vector4(-12, 15, -14, .43), Vector4(5, -20, 8, .61), Vector4(12, 0, 0, .72)])
	p.chest = trazo(t, [Vector4(0, 0, 0, 0), Vector4(-10, -18, -8, .16), Vector4(-8, 15, -8, .34), Vector4(-12, 20, 12, .49), Vector4(-8, -8, 0, .65), Vector4(-6, 0, 0, .72)])
	p.head = Vector3(-.12, -.25 * sin(giro), -.10 * esquiva)
	p["upper_arm.L"] = trazo(t, [Vector4(-25, 0, -15, 0), Vector4(-120, 30, -20, .14), Vector4(-10, -25, -55, .28), Vector4(-150, -20, -45, .45), Vector4(-20, 25, -65, .56), Vector4(-35, 25, -20, .65), Vector4(-92, -8, -23, .72)])
	p["upper_arm.R"] = trazo(t, [Vector4(-25, 0, 15, 0), Vector4(-10, -20, 45, .17), Vector4(-145, 15, 35, .32), Vector4(-15, 20, 55, .47), Vector4(-140, -15, 45, .57), Vector4(-35, -25, 20, .65), Vector4(-92, 8, 23, .72)])
	p["forearm.L"] = trazo(t, [Vector4(-70, 0, 0, 0), Vector4(-15, 0, -15, .14), Vector4(-30, 0, 0, .28), Vector4(-15, 0, 0, .45), Vector4(-105, 0, 0, .65), Vector4(-6, 0, 0, .72)])
	p["forearm.R"] = trazo(t, [Vector4(-70, 0, 0, 0), Vector4(-20, 0, 0, .17), Vector4(-15, 0, 15, .32), Vector4(-30, 0, 0, .47), Vector4(-105, 0, 0, .65), Vector4(-6, 0, 0, .72)])
	p["thigh.L"] = Vector3(-.23 - esquiva * .72 - soltar * .42, -.18, -.23)
	p["shin.L"] = Vector3(.35 + esquiva * .95 + soltar * .42, 0, 0)
	p["foot.L"] = Vector3(-.15 - esquiva * .25, -.12, 0)
	p["thigh.R"] = Vector3(-.12 - giro_pie * 1.6 + soltar * .22, -.5 * giro_pie, .22 + giro_pie * .4)
	p["shin.R"] = Vector3(.22 + giro_pie * 1.75, 0, 0)
	p["foot.R"] = Vector3(-.08 - giro_pie * .3, .18, .2 * giro_pie)
	for lado: String in ["L", "R"]:
		var s := 1.0 if lado == "L" else -1.0
		p["hand." + lado] = Vector3(.35 + soltar * .25, s * (.45 * sin(giro + .6)), -s * .24)

static func _fuego(p: Dictionary, t: float) -> void:
	# Guardia cruzada, golpe recto desde la cadera, revés ascendente,
	# patada circular y doble descarga. Preparaciones lentas, ataques breves,
	# suspensión del golpe y retroceso: cada acción tiene peso y respiración.
	var golpe_r := pulso(t, .18, .24, .32)
	var golpe_l := pulso(t, .32, .38, .46)
	var patada := pulso(t, .48, .56, .64)
	var carga := pulso(t, .59, .665, .72)
	var final := smoothstep(.675, .72, t)
	var giro := curva(t, [Vector2(0, 0), Vector2(.14, -.58), Vector2(.24, .12), Vector2(.31, .55), Vector2(.38, -.30), Vector2(.46, -.80), Vector2(.56, .72), Vector2(.64, -.24), Vector2(.72, 0)])
	p.root = Vector3(0, giro, 0)
	p.desplazamiento = Vector3(.14 * sin(giro), 0, -.18 * carga + .22 * (golpe_r + golpe_l) + final * .48)
	p.pelvis = Vector3(.07 - patada * .15, giro * .25, patada * -.18)
	p.spine = Vector3(-.10 - patada * .32 - carga * .18 + final * .32, giro * .30, patada * -.18)
	p.chest = Vector3(-.08 + (golpe_r + golpe_l) * .16 - carga * .16, giro * .30, patada * .12)
	p.head = Vector3(.04, -giro * .65, patada * .14)
	p["upper_arm.R"] = trazo(t, [Vector4(-25, 0, 10, 0), Vector4(-65, -35, 30, .12), Vector4(15, -15, 15, .18), Vector4(-94, 0, 8, .24), Vector4(10, -15, 20, .32), Vector4(-40, -10, 15, .40), Vector4(-90, -25, 70, .51), Vector4(-40, -15, 35, .59), Vector4(20, -15, 35, .665), Vector4(-96, 0, 16, .72)])
	p["upper_arm.L"] = trazo(t, [Vector4(-25, 0, -10, 0), Vector4(-95, 30, -18, .12), Vector4(-55, 15, -22, .24), Vector4(10, 20, -28, .32), Vector4(-135, -10, -32, .38), Vector4(-55, 10, -25, .46), Vector4(-25, 10, -100, .56), Vector4(20, 15, -35, .665), Vector4(-96, 0, -16, .72)])
	p["forearm.R"] = trazo(t, [Vector4(-85, 0, 0, 0), Vector4(-95, 0, 0, .12), Vector4(-105, 0, 0, .18), Vector4(-5, 0, 0, .24), Vector4(-110, 0, 0, .32), Vector4(-80, 0, 0, .46), Vector4(-40, 0, 0, .56), Vector4(-110, 0, 0, .665), Vector4(-5, 0, 0, .72)])
	p["forearm.L"] = trazo(t, [Vector4(-85, 0, 0, 0), Vector4(-65, 0, 0, .12), Vector4(-110, 0, 0, .32), Vector4(-20, 0, 0, .38), Vector4(-100, 0, 0, .46), Vector4(-25, 0, 0, .56), Vector4(-110, 0, 0, .665), Vector4(-5, 0, 0, .72)])
	p["thigh.L"] = Vector3(-.48 + patada * .24 - final * .40, -.18, -.28)
	p["shin.L"] = Vector3(.72 - patada * .35 + final * .40, 0, 0)
	p["foot.L"] = Vector3(-.25, -.16 + patada * .4, 0)
	p["thigh.R"] = trazo(t, [Vector4(8, 15, 18, 0), Vector4(8, 15, 18, .43), Vector4(-95, -25, 25, .49), Vector4(-100, -45, 48, .56), Vector4(-75, 15, 20, .60), Vector4(14, 15, 20, .665)])
	p["shin.R"] = trazo(t, [Vector4(20, 0, 0, 0), Vector4(20, 0, 0, .43), Vector4(125, 0, 0, .49), Vector4(8, 0, 0, .56), Vector4(110, 0, 0, .60), Vector4(18, 0, 0, .665)])
	p["foot.R"] = Vector3(-.12 + patada * .48, .18, patada * -.15)
	for lado: String in ["L", "R"]:
		var s := 1.0 if lado == "L" else -1.0
		p["hand." + lado] = Vector3(-.16 + final * .65, s * .10, s * .10)
