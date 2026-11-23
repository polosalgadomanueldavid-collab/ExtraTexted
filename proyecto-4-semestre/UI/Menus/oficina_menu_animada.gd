extends Node3D
## Escenario decorativo del menú: no modifica la ventana ni las preferencias del juego.
const Pose := preload("res://UI/Menus/pose_oficina_menu.gd")
const DURACION := 74.0
var actores: Array[Node3D] = []
var poses: Array[SkeletonModifier3D] = []
var animadores: Array[AnimationPlayer] = []
var hojas: Array[Node3D] = []
var documento: Node3D
var carpeta: Node3D
var reloj := 0.0
var reloj_papeles := 0.0
var ambiente: Environment
var gestos := [0.0, 0.0]
var camara: Camera3D
var silla_mueble: Node3D
var ruta_salida: Curve3D
var ruta_entrada: Curve3D
const SILLA := Vector3(2.1, 0, 0.0)
const FONDO := Vector3(-3.3, 0, -2.5)
const GIRO_FONDO := 0.0
const PILA_A := Vector3(-3.50, 1.24, -1.65)
const PILA_B := Vector3(-2.96, 1.24, -1.65)
const CARPETA_LECTURA := Vector3(-3.30, 1.60, -1.95)

func mat(color: String, rough := 0.65) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = rough
	return m

func caja(pos: Vector3, tam: Vector3, material: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = tam
	n.mesh = mesh
	n.material_override = material
	n.position = pos
	add_child(n)
	return n

func cilindro(pos: Vector3, radio: float, alto: float, material: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radio
	mesh.bottom_radius = radio
	mesh.height = alto
	mesh.radial_segments = 32
	n.mesh = mesh
	n.material_override = material
	n.position = pos
	add_child(n)
	return n

func foco(pos: Vector3, destino: Vector3, color: String, energia: float, angulo: float, alcance: float) -> void:
	var l := SpotLight3D.new()
	l.position = pos
	l.light_color = Color(color)
	l.light_energy = energia
	l.spot_range = alcance
	l.spot_angle = angulo
	l.spot_attenuation = 0.7
	l.shadow_enabled = true
	l.shadow_bias = 0.16 if RenderingServer.get_current_rendering_method() == "gl_compatibility" else 0.04
	l.shadow_normal_bias = 0.8 if RenderingServer.get_current_rendering_method() == "gl_compatibility" else 0.4
	l.light_size = 0.18
	add_child(l)
	l.look_at(destino)

func objeto(ruta: String, pos: Vector3, alto: float, giro := 0.0) -> Node3D:
	var n: Node3D = load(ruta).instantiate()
	add_child(n)
	var limites := AABB()
	var primero := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (n.global_transform.affine_inverse() * m.global_transform) * m.get_aabb()
		limites = b if primero else limites.merge(b)
		primero = false
	var factor := alto / maxf(limites.size.y, 0.001)
	var soporte := Node3D.new()
	add_child(soporte)
	n.reparent(soporte)
	n.scale *= factor
	n.position = -Vector3(limites.get_center().x, limites.position.y, limites.get_center().z) * factor
	soporte.position = pos
	soporte.rotation.y = giro
	return soporte

func _ready() -> void:
	_crear_ambiente()
	_crear_oficina()
	_crear_actores()
	ruta_salida = crear_ruta([SILLA, Vector3(-1.0,0,0), Vector3(-1.0,0,-2.5), FONDO])
	ruta_entrada = crear_ruta([FONDO, Vector3(0,0,-2.5), Vector3(3.7,0,-2.5), Vector3(3.7,0,0), SILLA])
	for i in 28:
		hojas.append(papel(Vector3.ZERO, 0.42 + (i % 3) * 0.07))
	# Hoja plana, delante del torso y apoyada sobre la superficie (y = 1.23).
	documento = papel(Vector3(2.0, 1.24, 1.43), 0.58)
	documento.rotation.y = -0.12
	carpeta = caja(PILA_A, Vector3(0.56, 0.035, 0.65), mat("bc8d54", 0.85))
	var hoja_carpeta := papel(Vector3.ZERO, 0.47)
	hoja_carpeta.reparent(carpeta)
	hoja_carpeta.position = Vector3(0, 0.024, 0)
	for pose in poses:
		pose.carpeta = carpeta
	_actualizar(0)

func _crear_ambiente() -> void:
	var e := WorldEnvironment.new()
	ambiente = Environment.new()
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = Color("101c2b")
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color("819cba")
	ambiente.ambient_light_energy = 0.26
	ambiente.tonemap_mode = Environment.TONE_MAPPER_ACES
	ambiente.tonemap_exposure = 1.1
	ambiente.ssao_enabled = RenderingServer.get_current_rendering_method() == "forward_plus"
	ambiente.ssao_radius = 1.3
	ambiente.ssao_intensity = 1.5
	ambiente.ssao_detail = 0.5
	ambiente.glow_enabled = RenderingServer.get_current_rendering_method() != "gl_compatibility"
	ambiente.glow_intensity = 0.35
	ambiente.glow_bloom = 0.03
	ambiente.fog_enabled = true
	ambiente.fog_light_color = Color("33566c")
	ambiente.fog_density = 0.004
	e.environment = ambiente
	add_child(e)
	camara = Camera3D.new()
	add_child(camara)
	camara.position = Vector3(7.0, 4.1, 10.0)
	camara.look_at(Vector3(0.8, 1.5, -0.7))
	camara.fov = 39
	# Deja a ambos compañeros visibles a la derecha de los botones originales.
	camara.h_offset = -1.6
	camara.current = true
	foco(Vector3(1.5, 5.5, 3), Vector3(1.6, 0.3, 0.2), "ffe0b1", 4.0, 42, 13)
	foco(Vector3(-3, 4, -4.3), Vector3(1.4, 0, 2), "84caff", 5.0, 45, 13)
	foco(Vector3(2.5, 4, -4.3), Vector3(2.8, 0, 2), "77baff", 4.5, 36, 12)
	foco(Vector3(-3.5, 3.5, -0.5), Vector3(-1, 1, -2.7), "ffc37c", 2.8, 50, 10)
	var relleno := OmniLight3D.new()
	relleno.position=Vector3(3,2.3,4)
	relleno.light_color=Color("ffe0bd")
	relleno.light_energy=0.65
	relleno.omni_range=9.0
	add_child(relleno)

func _crear_oficina() -> void:
	var pared := mat("b19178", 0.88)
	pared.albedo_texture = load("res://Arte/Texturas/pared_ladrillo_psx.png")
	pared.uv1_triplanar = true
	pared.uv1_scale = Vector3.ONE * 0.5
	caja(Vector3(0, 6, -5), Vector3(40, 12, 0.25), pared)
	caja(Vector3(-7, 6, 0), Vector3(0.25, 12, 30), pared)
	var madera := mat("be986e", 0.43)
	madera.albedo_texture = load("res://Arte/Texturas/36bf31df51379c823db97b294d26704f.jpg")
	madera.uv1_triplanar = true
	madera.uv1_scale = Vector3.ONE * 0.45
	var oscuro := mat("172632", 0.5)
	caja(Vector3(0, -0.12, 0), Vector3(30, 0.2, 30), mat("101822"))
	# Dos lotes para todo el suelo, en vez de dibujar cada baldosa por separado.
	for paridad in 2:
		var posiciones: Array[Transform3D] = []
		for x in range(-8,9):
			for z in range(-6,8):
				if posmod(x+z,2) == paridad:
					posiciones.append(Transform3D(Basis.IDENTITY,Vector3(x*0.9,0,z*0.9)))
		var baldosa := BoxMesh.new()
		baldosa.size = Vector3(0.87,0.025,0.87)
		baldosa.material = mat("343536" if paridad else "26292d",0.68)
		var lote := MultiMesh.new()
		lote.transform_format = MultiMesh.TRANSFORM_3D
		lote.mesh = baldosa
		lote.instance_count = posiciones.size()
		for i in posiciones.size():
			lote.set_instance_transform(i,posiciones[i])
		var suelo := MultiMeshInstance3D.new()
		suelo.multimesh = lote
		add_child(suelo)
	for x in [-3.4, 1.6]:
		var cristal := mat("67b7e2")
		cristal.emission_enabled = true
		cristal.emission = Color("559dd0")
		cristal.emission_energy_multiplier = 1.3
		caja(Vector3(x, 3.5, -4.79), Vector3(1.65, 2.7, 0.04), cristal)
		for dx in [-0.9, 0, 0.9]:
			caja(Vector3(x+dx, 3.5, -4.68), Vector3(0.13, 3.0, 0.18), mat("5b6870"))
		for y in [2.05, 3.5, 4.95]:
			caja(Vector3(x, y, -4.68), Vector3(1.9, 0.13, 0.18), mat("5b6870"))
		caja(Vector3(x, 1.95, -4.55), Vector3(2.1, 0.15, 0.48), mat("56636b"))
	# Mesa principal y archivadores, conservando espacio para las rodillas.
	var inicio_mesa := get_child_count()
	caja(Vector3(2.1, 1.15, 1.08), Vector3(3.2, 0.16, 1.3), madera)
	for x in [0.7, 3.5]:
		caja(Vector3(x, 0.55, 1.1), Vector3(0.14, 1.1, 1.1), oscuro)
	for i in 3:
		caja(Vector3(0.98, 1.28+i*0.075, 1.15), Vector3(0.65, 0.065, 0.80), mat(["b86b4c", "ddc69b", "4c797e"][i]))
	# Silla tapizada frente a la mesa: asiento, respaldo y patas.
	silla_mueble = Node3D.new()
	add_child(silla_mueble)
	caja(Vector3(2.1, 0.84, -0.05), Vector3(0.95, 0.15, 0.9), mat("1c4352",0.8)).reparent(silla_mueble)
	caja(Vector3(2.1, 1.34, -0.45), Vector3(0.98, 0.94, 0.14), mat("204b5a",0.8)).reparent(silla_mueble)
	for x in [1.72, 2.48]:
		for z in [-0.37, 0.25]:
			caja(Vector3(x, 0.4, z), Vector3(0.08,0.8,0.08), oscuro).reparent(silla_mueble)
	# La mesa principal queda despejada para ver la lectura; el PC está al fondo.
	# Lámpara de escritorio con luz localizada.
	cilindro(Vector3(0.85,1.29,0.82),0.19,0.06,mat("30414b",0.35))
	cilindro(Vector3(0.85,1.75,0.82),0.025,0.9,mat("b7955b",0.3))
	var pantalla := MeshInstance3D.new()
	var cono := CylinderMesh.new()
	cono.top_radius=0.12
	cono.bottom_radius=0.32
	cono.height=0.24
	pantalla.mesh=cono
	pantalla.material_override=mat("d9bd7c",0.45)
	pantalla.position=Vector3(0.85,2.22,0.82)
	add_child(pantalla)
	foco(Vector3(0.85,2.07,0.82), Vector3(1.8,1.1,1.05), "ffc178", 2.8, 55, 4.5)
	cilindro(Vector3(2.55,1.40,1.46),0.12,0.3,mat("e3d4b3",0.3))
	# Holgura real entre la silla retirada y el borde de la mesa.
	for n in get_children().slice(inicio_mesa):
		if n is Node3D and n != silla_mueble:
			n.position.z += 0.35
	# Mobiliario real del juego en segundo plano.
	objeto("res://Furniture Pack/Cajon/Cajon.glb", Vector3(-2.9,0,-3.9),1.2)
	objeto("res://Furniture Pack/Cajon/Cajon.glb", Vector3(-4.2,0,-3.9),1.2)
	objeto("res://Furniture Pack/Mesas_estaciones/Estacion_reportes.glb",Vector3(2.8,0,-3.8),1.25)
	objeto("res://Furniture Pack/Planta/Planta.glb",Vector3(5,0,-2.4),2.0)
	# Puesto lateral de clasificación: se ven las manos y la carpeta desde cámara.
	caja(Vector3(-3.1, 1.15, -1.3), Vector3(1.8, 0.16, 1.1), madera)
	for x in [-3.85,-2.35]:
		caja(Vector3(x,0.55,-1.3),Vector3(0.09,1.1,0.85),oscuro)
	# Tablón y carpetas de pared.
	caja(Vector3(4.7,3.3,-4.75),Vector3(2.3,1.6,0.10),madera)
	caja(Vector3(4.7,3.3,-4.65),Vector3(2.1,1.4,0.03),mat("6d5947"))
	for i in 5:
		var nota := caja(Vector3(4.1+(i%3)*0.53,3.0+(i/3)*0.55,-4.61),Vector3(0.35,0.45,0.01),mat("dfcba2"))
		nota.rotation.z = sin(i)*0.1

func monitor(pos: Vector3) -> void:
	var marco := caja(pos,Vector3(0.85,0.62,0.09),mat("172934",0.4))
	marco.rotation.y=-0.3
	var pantalla := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size=Vector2(0.72,0.49)
	pantalla.mesh=mesh
	var m:=mat("335e6d")
	m.emission_enabled=true
	m.emission=Color("3d7684")
	m.emission_energy_multiplier=0.6
	pantalla.material_override=m
	pantalla.position.z=0.05
	marco.add_child(pantalla)

func papel(pos: Vector3, tam: float) -> Node3D:
	var p := caja(pos,Vector3(tam,0.009,tam*1.35),mat("e9dcc5",0.95))
	for i in 4:
		var linea:=MeshInstance3D.new()
		var mesh:=BoxMesh.new()
		mesh.size=Vector3(tam*0.67,0.002,0.012)
		linea.mesh=mesh
		linea.material_override=mat("62747a")
		linea.position=Vector3(0,0.006,-tam*0.30+i*tam*0.17)
		p.add_child(linea)
	return p

func _crear_actores() -> void:
	for ruta: String in ["res://Personajes/PoliciaAzul/ModeloAzul.tscn", "res://Personajes/PoliciaRelevo/ModeloRelevo.tscn"]:
		var p: Node3D=load(ruta).instantiate()
		add_child(p)
		actores.append(p)
		var a:=p.find_child("AnimationPlayer",true,false) as AnimationPlayer
		a.play("idle")
		animadores.append(a)
		var s:=p.find_child("Skeleton3D",true,false) as Skeleton3D
		var pose:=Pose.new()
		pose.personaje = p
		s.add_child(pose)
		poses.append(pose)

func _actualizar(t: float) -> void:
	var segunda := t >= 37.0
	var local := t - (37.0 if segunda else 0.0)
	var saliente := 1 if segunda else 0
	var entrante := 1-saliente
	for pose in poses:
		pose.actividad = 0.0
		pose.inclinacion = 0.0
		pose.marcha = 0.0
		pose.paso_peso = 0.0
		pose.paso_giro = false
	if local < 10.0:
		actores[saliente].position=SILLA
		actores[saliente].rotation.y=0.0
		poses[saliente].sentado=1.0
		actores[entrante].position=FONDO
		actores[entrante].rotation.y=GIRO_FONDO
		poses[entrante].sentado=0.0
		animar(saliente,"idle")
		animar(entrante,"idle")
		ordenar_carpetas(entrante, local * 0.8)
		silla_mueble.position.z = 0.0
	else:
		var u := local-10.0
		var retirar := smoothstep(0.0,2.0,u)
		var levantarse := smoothstep(2.0,4.0,u)
		var sentarse := smoothstep(23.0,25.0,u)
		var acercar := smoothstep(25.0,27.0,u)
		# El cuerpo avanza solo lo que cambia la proyección de las piernas (0.30 m).
		# La silla rueda más atrás al liberar el peso y vuelve al recibir la sentada.
		silla_mueble.position.z = (-0.30*retirar-0.65*levantarse+0.65*sentarse)*(1.0-acercar)
		poses[saliente].sentado = 1.0-levantarse
		poses[entrante].sentado = sentarse
		poses[saliente].inclinacion = sin(PI*levantarse)*0.22
		poses[entrante].inclinacion = sin(PI*sentarse)*0.22
		# El saliente se levanta antes de girar; el entrante utiliza el otro pasillo.
		seguir_ruta(saliente,ruta_salida,u,6.0,22.0,4.0,24.0,0.0,GIRO_FONDO)
		seguir_ruta(entrante,ruta_entrada,u,2.0,21.0,0.0,23.0,GIRO_FONDO,0.0)
		if u < 4.0:
			actores[saliente].position = SILLA + Vector3(0,sin(PI*levantarse)*0.055,-0.30*retirar*(1.0-levantarse))
		if u >= 23.0:
			actores[entrante].position = SILLA + Vector3(0,sin(PI*sentarse)*0.055,-0.30*sentarse*(1.0-acercar))
		carpeta.position = PILA_A
		carpeta.rotation = Vector3.ZERO
	for p in poses:
		p.reloj=t*0.7
	for i in hojas.size():
		var nivel := floorf(i / 7.0)
		var f := TAU*reloj_papeles/17.0 + (i % 7)*TAU/7.0 + nivel*0.63
		var radio := 2.3+nivel*0.65
		# Cuatro corrientes a distintas alturas, siempre libres de los sombreros.
		hojas[i].position=Vector3(0.7+sin(f)*radio,3.35+nivel*0.38+sin(f*2+i)*0.18,-1.2+cos(f)*(1.3+nivel*0.25))
		hojas[i].rotation=Vector3(0.2+sin(f*2+i)*0.55,f*(1.0+(i%2))+i*0.3,cos(f+i)*0.5)

func crear_ruta(puntos: Array[Vector3]) -> Curve3D:
	var curva := Curve3D.new()
	curva.bake_interval = 0.025
	for n in puntos.size():
		if n == 0 or n == puntos.size()-1:
			curva.add_point(puntos[n])
			continue
		var llegada := (puntos[n]-puntos[n-1]).normalized()
		var salida := (puntos[n+1]-puntos[n]).normalized()
		if llegada.dot(salida) > 0.999:
			continue
		var radio := minf(0.8,minf(puntos[n].distance_to(puntos[n-1]),puntos[n].distance_to(puntos[n+1]))*0.45)
		# Redondear dentro del pasillo evita sobrepasar la esquina de un mueble.
		curva.add_point(puntos[n]-llegada*radio,Vector3.ZERO,llegada*radio*0.552285)
		curva.add_point(puntos[n]+salida*radio,-salida*radio*0.552285,Vector3.ZERO)
	return curva

func distancia_ruta(t: float, duracion: float, longitud: float) -> float:
	# Velocidad uniforme salvo una aceleración y frenada de un segundo.
	var u := clampf(t,0.0,duracion)
	var area := u*u*0.5 if u < 1.0 else u-0.5
	if u > duracion-1.0:
		area = duracion-1.0-pow(duracion-u,2)*0.5
	return longitud*area/(duracion-1.0)

func rumbo(curva: Curve3D, distancia: float) -> float:
	var longitud := curva.get_baked_length()
	var direccion := curva.sample_baked(minf(longitud,distancia+0.10),true)-curva.sample_baked(maxf(0.0,distancia-0.10),true)
	return atan2(direccion.x,direccion.z)

func seguir_ruta(i: int, curva: Curve3D, u: float, inicio: float, fin: float, inicio_giro: float, fin_giro: float, giro_inicial: float, giro_final: float) -> void:
	var longitud := curva.get_baked_length()
	var distancia := distancia_ruta(u-inicio,fin-inicio,longitud)
	actores[i].position = curva.sample_baked(distancia,true)
	var orientacion := rumbo(curva,distancia)
	if u < inicio:
		orientacion = lerp_angle(giro_inicial,rumbo(curva,0.0),smoothstep(inicio_giro,inicio,u))
	elif u > fin:
		orientacion = lerp_angle(rumbo(curva,longitud),giro_final,smoothstep(fin,fin_giro,u))
	actores[i].rotation.y = orientacion
	if u > inicio and u < fin:
		var velocidad := (distancia_ruta(u-inicio+0.01,fin-inicio,longitud)-distancia_ruta(u-inicio-0.01,fin-inicio,longitud))/0.02
		animar(i,"walk",velocidad)
		poses[i].paso_distancia = distancia
		poses[i].paso_peso = smoothstep(inicio,inicio+0.6,u)*(1.0-smoothstep(fin-0.6,fin,u))
	elif (u > inicio_giro and u < inicio) or (u > fin and u < fin_giro):
		# Pasitos cortos al girar, en lugar de pivotar rígido sobre ambos pies.
		animar(i,"walk",0.16)
		poses[i].marcha = 0.8
		poses[i].paso_distancia = u*0.30
		poses[i].paso_giro = true
		var avance := inverse_lerp(inicio_giro,inicio,u) if u < inicio else inverse_lerp(fin,fin_giro,u)
		poses[i].paso_peso = sin(PI*avance)
	else:
		animar(i,"idle")

func ordenar_carpetas(i: int,t: float) -> void:
	var segundo_pase := t >= 4.0
	var ciclo := fposmod(t,4.0)
	var origen := PILA_B if segundo_pase else PILA_A
	var destino := PILA_A if segundo_pase else PILA_B
	var recoger := smoothstep(0.25,1.0,ciclo)
	var dejar := smoothstep(2.5,3.25,ciclo)
	carpeta.position = origen.lerp(CARPETA_LECTURA,recoger).lerp(destino,dejar)
	var leyendo := recoger*(1.0-dejar)
	carpeta.rotation = Vector3(-0.45*leyendo,0.0,0.0)
	poses[i].actividad = smoothstep(0.0,0.25,ciclo)*(1.0-smoothstep(3.25,3.75,ciclo))

func animar(i: int, clip: String, velocidad := 0.0) -> void:
	# El apoyo de cada pie acompaña 0.60 m por ciclo; los brazos siguen esa cadencia.
	animadores[i].speed_scale = clampf(velocidad*0.9/0.60,0.12,1.1) if clip == "walk" else 0.65
	poses[i].marcha = 0.35 if clip == "walk" else 0.0
	if animadores[i].current_animation != clip:
		animadores[i].play(clip,0.45)

func _process(delta: float) -> void:
	reloj = fposmod(reloj+delta,DURACION)
	# El viento conserva su fase al reiniciar el relevo de 74 segundos.
	reloj_papeles = fposmod(reloj_papeles+delta,17.0)
	for i in gestos.size():
		gestos[i] = maxf(0.0,gestos[i]-delta)
		poses[i].gesto = sin(PI*gestos[i]/0.8)*0.06
	_actualizar(reloj)

func gesticular(indice: int) -> void:
	if indice >= 0 and indice < gestos.size():
		gestos[indice] = 0.8

func configurar_calidad(nivel: int) -> void:
	var avanzado := RenderingServer.get_current_rendering_method() == "forward_plus"
	ambiente.ssao_enabled = avanzado and nivel >= 2
	ambiente.glow_enabled = RenderingServer.get_current_rendering_method() != "gl_compatibility" and nivel > 0
