extends SkeletonModifier3D
var sentado := 0.0
var reloj := 0.0
var actividad := 0.0
var marcha := 0.0
var inclinacion := 0.0
var gesto := 0.0
var personaje: Node3D
var paso_distancia := 0.0
var paso_peso := 0.0
var paso_giro := false
var carpeta: Node3D

func _process_modification() -> void:
	var s := get_skeleton()
	if marcha > 0.0:
		for lado in ["L", "R"]:
			for hueso in ["thigh.","shin.","foot.","upper_arm.","forearm."]:
				pose(hueso+lado,Vector3.ZERO,marcha)
	for lado in ["L", "R"]:
		pose("thigh." + lado, Vector3(-1.48, 0, -0.06 if lado == "L" else 0.06), sentado)
		pose("shin." + lado, Vector3(1.52, 0, 0), sentado)
		pose("foot." + lado, Vector3(-0.04, 0, 0), sentado)
		pose("upper_arm." + lado, Vector3(-0.60, 0, -0.09 if lado == "L" else 0.09), sentado)
		pose("forearm." + lado, Vector3(-0.95, 0, 0), sentado)
	pose("head", Vector3(0.34 + sin(reloj * 1.1) * 0.025, sin(reloj * 0.6) * 0.05, 0), sentado)
	pose("spine", Vector3(0.08, 0, 0), sentado)
	if inclinacion > 0.0:
		pose("spine",Vector3(inclinacion,0,0),1.0)
	if actividad > 0.0 and is_instance_valid(carpeta):
		pose("head", Vector3(0.22, sin(reloj * 1.1) * 0.07, 0), actividad)
		pose("spine", Vector3(0.08, 0, 0), actividad)
		for lado in ["L", "R"]:
			pose("upper_arm." + lado, Vector3(-0.65, 0, -0.12 if lado == "L" else 0.12), actividad)
			pose("forearm." + lado, Vector3(-0.8, 0, 0), actividad)
			var agarre := Vector3(0.25 if lado == "L" else -0.25, 0.015, 0.05)
			apuntar_mano(carpeta.global_transform * agarre, actividad, lado)
	if gesto > 0.0:
		var cabeza := s.find_bone("head")
		s.set_bone_pose_rotation(cabeza,s.get_bone_pose_rotation(cabeza)*Quaternion(Vector3.RIGHT,gesto))
	var i := s.find_bone("root")
	s.set_bone_pose_position(i, s.get_bone_pose_position(i) + Vector3(0, -0.30 * sentado, 0))
	if paso_peso > 0.0:
		for lado in ["L","R"]:
			var fase := fposmod(paso_distancia/0.60+(0.0 if lado == "L" else 0.5),1.0)
			var adelante := 0.18 if not paso_giro else 0.025
			var z := lerpf(adelante,-adelante,minf(fase/0.6,1.0))
			var altura := 0.0
			if fase > 0.6:
				var vuelo := (fase-0.6)/0.4
				z = lerpf(-adelante,adelante,smoothstep(0.0,1.0,vuelo))
				altura = sin(PI*vuelo)*(0.085 if not paso_giro else 0.045)
			var pie := Vector3(0.292 if lado == "L" else -0.292,0.129+altura,-0.021+z)
			apoyar_pie(lado,personaje.global_transform*pie,paso_peso)

func orientar_hueso(i: int, hijo: int, destino: Vector3) -> void:
	var s := get_skeleton()
	var origen := s.get_bone_global_pose(i).origin
	var desde := (s.get_bone_global_pose(hijo).origin-origen).normalized()
	var hacia := (destino-origen).normalized()
	var padre := s.get_bone_global_pose(s.get_bone_parent(i)).basis.get_rotation_quaternion()
	s.set_bone_pose_rotation(i,padre.inverse()*Quaternion(desde,hacia)*padre*s.get_bone_pose_rotation(i))

func apoyar_pie(lado: String, destino_global: Vector3, peso: float) -> void:
	var s := get_skeleton()
	var muslo := s.find_bone("thigh."+lado)
	var pierna := s.find_bone("shin."+lado)
	var pie := s.find_bone("foot."+lado)
	var anteriores := [s.get_bone_pose_rotation(muslo),s.get_bone_pose_rotation(pierna),s.get_bone_pose_rotation(pie)]
	var cadera := s.get_bone_global_pose(muslo).origin
	var rodilla := s.get_bone_global_pose(pierna).origin
	var tobillo := s.get_bone_global_pose(pie).origin
	var destino := s.to_local(destino_global)
	var largo_a := cadera.distance_to(rodilla)
	var largo_b := rodilla.distance_to(tobillo)
	var direccion := (destino-cadera).normalized()
	var distancia := clampf(cadera.distance_to(destino),0.01,largo_a+largo_b-0.001)
	var avance := (largo_a*largo_a-largo_b*largo_b+distancia*distancia)/(2.0*distancia)
	var frente := (s.global_basis.inverse()*personaje.global_basis*Vector3.BACK).normalized()
	var flexion := (frente-direccion*frente.dot(direccion)).normalized()
	var objetivo_rodilla := cadera+direccion*avance+flexion*sqrt(maxf(0.0,largo_a*largo_a-avance*avance))
	orientar_hueso(muslo,pierna,objetivo_rodilla)
	orientar_hueso(pierna,pie,cadera+direccion*distancia)
	var padre := s.get_bone_global_pose(pierna).basis.get_rotation_quaternion()
	s.set_bone_pose_rotation(pie,padre.inverse()*s.get_bone_global_rest(pie).basis.get_rotation_quaternion())
	var cadena := [muslo,pierna,pie]
	for n in 3:
		s.set_bone_pose_rotation(cadena[n],anteriores[n].slerp(s.get_bone_pose_rotation(cadena[n]),peso))

func pose(nombre: String, giro: Vector3, peso: float) -> void:
	var s := get_skeleton()
	var i := s.find_bone(nombre)
	if i >= 0:
		var objetivo := s.get_bone_rest(i).basis.get_rotation_quaternion() * Quaternion.from_euler(giro)
		s.set_bone_pose_rotation(i, s.get_bone_pose_rotation(i).slerp(objetivo, peso))

func apuntar_mano(destino_global: Vector3, peso: float, lado: String) -> void:
	var s := get_skeleton()
	var destino := s.to_local(destino_global)
	for repeticion in 4:
		for nombre in ["forearm." + lado, "upper_arm." + lado]:
			var i := s.find_bone(nombre)
			var origen := s.get_bone_global_pose(i).origin
			var mano := s.get_bone_global_pose(s.find_bone("hand." + lado)).origin
			var desde := (mano - origen).normalized()
			var hacia := (destino - origen).normalized()
			if desde.is_zero_approx() or hacia.is_zero_approx():
				continue
			var padre := s.get_bone_global_pose(s.get_bone_parent(i)).basis.get_rotation_quaternion()
			var ajuste := padre.inverse() * Quaternion(desde, hacia) * padre * s.get_bone_pose_rotation(i)
			s.set_bone_pose_rotation(i, s.get_bone_pose_rotation(i).slerp(ajuste, peso * 0.8))
