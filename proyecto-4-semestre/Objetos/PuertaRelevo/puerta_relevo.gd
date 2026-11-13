@tool
extends Node3D
## +Z da a la oficina. Las cotas están en unidades del mundo, con los pies en Y = 0.

const FUENTE := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
const VIDRIO := preload("res://Objetos/PuertaRelevo/vidrio_estriado.gdshader")
const PASO := Vector2(0.96, 1.28)
const ANCHO_JAMBA := 0.052
const HOLGURA := 0.008
const ESPESOR_HOJA := 0.048
const APERTURA := deg_to_rad(98.0)

var pivote: Node3D
var _colision_hoja: CollisionShape3D
var _movimiento: Tween


func _ready() -> void:
	if is_instance_valid(pivote):
		return
	var madera := _material("aa7953")
	var batiente := _material("5c4237")
	var laton := _material("d8b577", 0.36, 0.32)
	_construir_pasillo(madera)
	_construir_marco(madera, batiente)
	_construir_hoja(batiente, laton)


func abrir() -> Tween:
	_colision_hoja.set_deferred("disabled", true)
	return _girar(APERTURA)


func cerrar() -> Tween:
	var cierre := _girar(0.0)
	cierre.tween_callback(_colision_hoja.set_deferred.bind("disabled", false))
	return cierre


func _girar(angulo: float) -> Tween:
	if is_instance_valid(_movimiento):
		_movimiento.kill()
	_movimiento = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_movimiento.tween_property(pivote, "rotation:y", angulo, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return _movimiento


func _construir_marco(madera: Material, batiente: Material) -> void:
	# El forro ocupa todo el espesor del muro. La tapeta biselada solapa el
	# canto del hueco; los tres lados comparten los ingletes de las esquinas.
	var vano := Rect2(-PASO.x * 0.5, 0.0, PASO.x, PASO.y)
	var forro := vano.grow_individual(ANCHO_JAMBA, 0, ANCHO_JAMBA, ANCHO_JAMBA)
	var tapeta := forro.grow_individual(0.025, 0, 0.025, 0.025)
	_moldura(self, "Cerco", forro, vano, -0.087, -0.078, madera, false)
	_moldura(self, "Tapajuntas", tapeta, vano, 0.078, 0.108, madera, false)
	# Cada jamba tiene una sola cara interior continua desde el pasillo a la hoja.
	for lado: int in [-1, 1]:
		var x := lado * (PASO.x + ANCHO_JAMBA) * 0.5
		var medidas := Vector3(ANCHO_JAMBA, PASO.y, 0.164)
		var centro := Vector3(x, PASO.y * 0.5, 0)
		_caja(self, "Jamba", medidas, centro, madera, true)
		_caja(self, "Tope", Vector3(0.025, PASO.y, 0.026), Vector3(lado * (PASO.x * 0.5 - 0.0125), PASO.y * 0.5, 0.060), batiente)
	_caja(self, "Dintel", Vector3(forro.size.x, ANCHO_JAMBA, 0.164), Vector3(0, PASO.y + ANCHO_JAMBA * 0.5, 0), madera, true)
	_caja(self, "TopeSuperior", Vector3(PASO.x - 0.05, 0.025, 0.026), Vector3(0, PASO.y - 0.0125, 0.060), batiente)
	_caja(self, "Umbral", Vector3(PASO.x, 0.012, 0.18), Vector3(0, 0.006, 0), _material("908373", 0.22))


func _construir_hoja(batiente: Material, laton: Material) -> void:
	var ancho := PASO.x - 2 * HOLGURA
	var pie := 0.015
	var alto := PASO.y - HOLGURA - pie
	var frente := ESPESOR_HOJA * 0.5
	pivote = Node3D.new()
	pivote.name = "Pivote"
	pivote.position = Vector3(-ancho * 0.5, 0, 0.019)
	add_child(pivote)
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "ColisionHoja"
	pivote.add_child(cuerpo)
	_colision_hoja = _colision(cuerpo, Vector3(ancho, alto, ESPESOR_HOJA), Vector3(ancho * 0.5, pie + alto * 0.5, 0))

	var esmalte := _material("367270", 0.06, 0.55)
	var relieve := _material("50938a", 0.08, 0.46)
	var junquillo := _material("50706f", 0.26, 0.34)
	# Los largueros y travesaños forman dos huecos reales. Vidrio y cuarterón
	# quedan embutidos entre ellos, también vistos desde el lado del pasillo.
	var lateral := 0.085
	var luz := ancho - 2 * lateral
	var inferior := Rect2(lateral, 0.105, luz, 0.43)
	var superior := Rect2(lateral, 0.68, luz, 0.515)
	for x: float in [lateral * 0.5, ancho - lateral * 0.5]:
		_caja(pivote, "Larguero", Vector3(lateral, alto, ESPESOR_HOJA), Vector3(x, pie + alto * 0.5, 0), esmalte)
	for tramo: Vector2 in [Vector2(pie, inferior.position.y), Vector2(inferior.end.y, superior.position.y), Vector2(superior.end.y, pie + alto)]:
		_caja(pivote, "Travesano", Vector3(luz, tramo.y - tramo.x, ESPESOR_HOJA), Vector3(ancho * 0.5, (tramo.x + tramo.y) * 0.5, 0), esmalte)

	var cristal := ShaderMaterial.new()
	cristal.shader = VIDRIO
	_caja(pivote, "VidrioEstriado", Vector3(luz, superior.size.y, 0.014), Vector3(ancho * 0.5, superior.get_center().y, 0), cristal)
	_caja(pivote, "Cuarteron", Vector3(luz, inferior.size.y, 0.016), Vector3(ancho * 0.5, inferior.get_center().y, 0), esmalte)
	for cara: float in [-1.0, 1.0]:
		_moldura(pivote, "JunquilloVidrio", superior, superior.grow(-0.021), frente * cara, 0.007 * cara, junquillo)
		_moldura(pivote, "BiselCuarteron", inferior, inferior.grow(-0.034), frente * cara, 0.008 * cara, relieve)
		_manilla(ancho - 0.062, inferior.end.y + 0.067, cara, laton)
	_colocar_placa(ancho * 0.5, (inferior.end.y + superior.position.y) * 0.5, laton)
	for y: float in [0.21, alto - 0.19]:
		_cilindro(pivote, "Bisagra", 0.016, 0.093, Vector3(0, y, -frente), Vector3.ZERO, batiente)


func _manilla(x: float, y: float, cara: float, laton: Material) -> void:
	# La palanca vuelve hacia el centro de la hoja y deja hueco para la mano.
	_cilindro(pivote, "Roseta", 0.039, 0.016, Vector3(x, y, 0.029 * cara), Vector3.RIGHT * PI / 2, laton)
	_cilindro(pivote, "Cuello", 0.014, 0.046, Vector3(x, y, 0.055 * cara), Vector3.RIGHT * PI / 2, laton)
	_cilindro(pivote, "Palanca", 0.016, 0.105, Vector3(x - 0.04, y, 0.077 * cara), Vector3.FORWARD * PI / 2, laton)


func _colocar_placa(x: float, y: float, laton: Material) -> void:
	_caja(pivote, "PlacaPersonal", Vector3(0.42, 0.088, 0.010), Vector3(x, y, 0.029), laton)
	var fuente := FontVariation.new()
	fuente.base_font = FUENTE
	fuente.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800.0}
	var rotulo := Label3D.new()
	rotulo.name = "RotuloPersonal"
	rotulo.font = fuente
	rotulo.text = "PERSONAL"
	rotulo.font_size = 64
	rotulo.pixel_size = 0.00113
	rotulo.outline_size = 0
	rotulo.modulate = Color("203737")
	rotulo.position = Vector3(x, y, 0.035)
	pivote.add_child(rotulo)


## Anillo rectangular de sección inclinada. exterior/interior están en el plano
## XY. Si no hay umbral, los lados terminan en el suelo sin un cuarto listón.
func _moldura(padre: Node3D, nombre: String, exterior: Rect2, interior: Rect2, z_fuera: float, z_dentro: float, material: Material, con_base: bool = true) -> void:
	var fuera := _esquinas(exterior, z_fuera)
	var dentro := _esquinas(interior, z_dentro)
	var superficie := SurfaceTool.new()
	superficie.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(4):
		if i == 0 and not con_base:
			continue
		var j := (i + 1) % 4
		# Godot considera frontal el giro horario. Crea igualmente el bisel
		# posterior orientado al pasillo cuando se especifica una Z negativa.
		var a := fuera[i]
		var c := dentro[j]
		var b := dentro[i] if z_fuera >= 0 else fuera[j]
		var d := fuera[j] if z_fuera >= 0 else dentro[i]
		var normal := (c - a).cross(b - a).normalized()
		for vertice: Vector3 in [a, b, c, a, c, d]:
			superficie.set_normal(normal)
			superficie.add_vertex(vertice)
	var malla := MeshInstance3D.new()
	malla.name = nombre
	malla.mesh = superficie.commit()
	malla.material_override = material
	padre.add_child(malla)


func _esquinas(rect: Rect2, z: float) -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(rect.position.x, rect.position.y, z), Vector3(rect.end.x, rect.position.y, z),
		Vector3(rect.end.x, rect.end.y, z), Vector3(rect.position.x, rect.end.y, z)
	])


func _construir_pasillo(madera: Material) -> void:
	# El pasillo conserva su profundidad para recibir al jugador completo.
	var pared := _material("bba986")
	var suelo := _material("70645b")
	_caja(self, "SueloPasillo", Vector3(1.62, 0.08, 1.68), Vector3(0, -0.044, -0.82), suelo, true)
	_caja(self, "FondoPasillo", Vector3(1.62, 1.54, 0.08), Vector3(0, 0.77, -1.64), pared, true)
	for lado: int in [-1, 1]:
		_caja(self, "LateralPasillo", Vector3(0.08, 1.54, 1.6), Vector3(lado * 0.77, 0.77, -0.84), pared, true)
	_caja(self, "TechoPasillo", Vector3(1.62, 0.06, 1.68), Vector3(0, 1.55, -0.82), pared)
	_caja(self, "ZocaloFondo", Vector3(1.46, 0.08, 0.022), Vector3(0, 0.04, -1.589), madera)


func _material(color: String, metal: float = 0.0, rugosidad: float = 0.71) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.metallic = metal
	material.roughness = rugosidad
	return material


func _caja(padre: Node3D, nombre: String, medidas: Vector3, centro: Vector3, material: Material, con_colision: bool = false) -> void:
	var malla := MeshInstance3D.new()
	malla.name = nombre
	var caja := BoxMesh.new()
	caja.size = medidas
	malla.mesh = caja
	malla.material_override = material
	malla.position = centro
	padre.add_child(malla)
	if con_colision:
		var cuerpo := StaticBody3D.new()
		malla.add_child(cuerpo)
		_colision(cuerpo, medidas, Vector3.ZERO)


func _colision(cuerpo: StaticBody3D, medidas: Vector3, centro: Vector3) -> CollisionShape3D:
	var colision := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = medidas
	colision.shape = caja
	colision.position = centro
	cuerpo.add_child(colision)
	return colision


func _cilindro(padre: Node3D, nombre: String, radio: float, largo: float, centro: Vector3, giro: Vector3, material: Material) -> void:
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = radio
	cilindro.bottom_radius = radio
	cilindro.height = largo
	cilindro.radial_segments = 12
	cilindro.rings = 1
	var pieza := MeshInstance3D.new()
	pieza.name = nombre
	pieza.mesh = cilindro
	pieza.material_override = material
	pieza.position = centro
	pieza.rotation = giro
	padre.add_child(pieza)
