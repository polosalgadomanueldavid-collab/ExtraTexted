extends Node3D
## Modelo procedural: depósito rojo, banda, manómetro, asa, manguera y boquilla.

var evento: Node
var recogido := false
var deposito: Node3D
var boquilla: Node3D
var espuma: CPUParticles3D
var _manguera: Array[MeshInstance3D] = []


func _ready() -> void:
	deposito = Node3D.new()
	add_child(deposito)
	_cilindro(deposito, Vector3(0, 0.22, 0), 0.105, 0.36, Color("dc4238"))
	_cilindro(deposito, Vector3(0, 0.055, 0), 0.11, 0.04, Color("273944"))
	_cilindro(deposito, Vector3(0, 0.22, 0), 0.107, 0.12, Color("fff1d8"))
	_cilindro(deposito, Vector3(0, 0.42, 0), 0.035, 0.07, Color("8d9b9b"))
	_caja(deposito, Vector3(0, 0.47, 0), Vector3(0.17, 0.035, 0.07), Color("253b45"))
	_caja(deposito, Vector3(0, 0.50, 0), Vector3(0.15, 0.025, 0.045), Color("e75642"))
	var reloj := _cilindro(deposito, Vector3(0, 0.405, 0.048), 0.033, 0.02, Color("e9eacb"))
	reloj.rotation.x = PI * 0.5
	_caja(deposito, Vector3(0, 0.22, 0.109), Vector3(0.035, 0.075, 0.008), Color("d94331"))
	boquilla = Node3D.new()
	add_child(boquilla)
	var tubo := _cilindro(boquilla, Vector3(0, 0, -0.06), 0.035, 0.14, Color("263944"))
	tubo.rotation.x = PI * 0.5
	for i in 9:
		_manguera.append(_cilindro(self, Vector3.ZERO, 0.014, 1.0, Color("27323d")))
	espuma = CPUParticles3D.new()
	espuma.amount = 90
	espuma.lifetime = 0.45
	espuma.local_coords = false
	espuma.direction = Vector3(0, 0, -1)
	espuma.spread = 14.0
	espuma.initial_velocity_min = 2.5
	espuma.initial_velocity_max = 3.2
	espuma.gravity = Vector3(0, -0.3, 0)
	espuma.scale_amount_min = 0.5
	espuma.scale_amount_max = 1.5
	var bola := SphereMesh.new()
	bola.radius = 0.025
	bola.height = 0.05
	bola.radial_segments = 6
	bola.rings = 3
	var material := _material(Color("eaf7f1"))
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bola.material = material
	espuma.mesh = bola
	var gradiente := Gradient.new()
	gradiente.set_color(0, Color("f4fff8"))
	gradiente.set_color(1, Color(0.85, 0.95, 0.91, 0.0))
	espuma.color_ramp = gradiente
	espuma.emitting = false
	boquilla.add_child(espuma)
	hide()


func interactuar(jugador: Player) -> void:
	if not recogido:
		evento.recoger_extintor(jugador)


func actualizar(jugador: Player, rociando: bool, destino: Vector3) -> void:
	if recogido:
		deposito.global_basis = jugador.visual.global_basis.orthonormalized()
		if rociando and is_instance_valid(jugador.gestos):
			deposito.global_position = jugador.gestos.mano_izquierda.global_position - Vector3.UP * 0.47
			boquilla.global_position = jugador.gestos.mano_derecha.global_position
			boquilla.look_at(destino)
		else:
			deposito.global_position = jugador.global_position + Vector3.UP * 0.27 - jugador.visual.global_basis.z.normalized() * 0.20
			boquilla.global_transform = deposito.global_transform.translated_local(Vector3(0.16, 0.31, 0))
	else:
		boquilla.transform = deposito.transform.translated_local(Vector3(0.16, 0.31, 0))
	espuma.emitting = rociando
	var inicio := deposito.to_global(Vector3(0.03, 0.43, 0))
	var fin := boquilla.global_position
	var anterior := inicio
	for i in _manguera.size():
		var t := float(i + 1) / _manguera.size()
		var punto := inicio.lerp(fin, t) + Vector3.DOWN * sin(t * PI) * 0.16
		var tramo := _manguera[i]
		tramo.global_position = (punto + anterior) * 0.5
		var direccion := punto - anterior
		tramo.global_basis = Basis(Quaternion(Vector3.UP, direccion.normalized()))
		tramo.scale.y = maxf(0.001, direccion.length())
		anterior = punto


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	return material


func _cilindro(padre: Node3D, posicion: Vector3, radio: float, altura: float, color: Color) -> MeshInstance3D:
	var malla := CylinderMesh.new()
	malla.top_radius = radio
	malla.bottom_radius = radio
	malla.height = altura
	malla.radial_segments = 12
	var pieza := MeshInstance3D.new()
	pieza.mesh = malla
	pieza.material_override = _material(color)
	pieza.position = posicion
	padre.add_child(pieza)
	return pieza


func _caja(padre: Node3D, posicion: Vector3, tamano: Vector3, color: Color) -> void:
	var pieza := MeshInstance3D.new()
	var malla := BoxMesh.new()
	malla.size = tamano
	pieza.mesh = malla
	pieza.material_override = _material(color)
	pieza.position = posicion
	padre.add_child(pieza)
