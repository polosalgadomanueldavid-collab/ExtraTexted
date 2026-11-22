extends Node3D
## Planilla apoyada sobre el tablero. Mismo pictograma que el expediente, sin texto.

const ICONO := preload("res://UI/Despacho/icono_despacho.gd")
const CREMA := Color("fff1d8")
const TINTA := Color("173b50")
const VERDE := Color("507b65")

var estacion_id := ""
var caso_id := ""
var pendiente := false
var completada := false
var cercana := false
var _caso: Denuncia
var _firma := ""
var _tween: Tween
var _receptor: Node3D
var _hoja: MeshInstance3D
var _simbolo: Node3D
var _sello: Node3D
var _piloto: StandardMaterial3D
var _base: StandardMaterial3D


func configurar(id: String) -> void:
	estacion_id = id
	name = "RespuestaFisica_" + id
	# Reservar una zona del tablero sin tocar los modelos importados.
	var altura_tablero := {"bienestar": .53, "verificacion": .52, "evidencias": .52, "privacidad": .53, "reporte": .51}
	position = Vector3(-0.43, float(altura_tablero.get(id, .52)) + .003, -0.16)
	# Estas tres mesas ya tienen objetos en las esquinas: reservar el frente libre.
	if id in ["bienestar", "verificacion", "evidencias"]:
		position.x = .06 if id == "bienestar" else 0.0
		position.z = .12
	_receptor = Node3D.new()
	if id in ["bienestar", "verificacion", "evidencias"]:
		_receptor.rotation.y = PI
	add_child(_receptor)
	var tabla := _caja(_receptor, "Planilla", Vector3(.30, .006, .20), Vector3.ZERO, Color("bba071"))
	_base = tabla.material_override as StandardMaterial3D
	_hoja = _caja(_receptor, "DocumentoTramitado", Vector3(.27, .002, .17), Vector3(0, .004, 0), CREMA)
	_hoja.visible = false
	_simbolo = _crear_simbolo(id)
	_simbolo.name = "SimboloEnReceptor"
	_simbolo.position.y = .0065
	_receptor.add_child(_simbolo)
	_sello = Node3D.new()
	_sello.name = "SelloCompletado"
	_sello.position = Vector3(.075, .008, -.035)
	_receptor.add_child(_sello)
	var trazo := _caja(_sello, "CheckCorto", Vector3(.040, .003, .012), Vector3(-.018, 0, -.008), VERDE)
	trazo.rotation.y = -.7
	trazo = _caja(_sello, "CheckLargo", Vector3(.075, .003, .012), Vector3(.017, 0, .006), VERDE)
	trazo.rotation.y = .75
	_sello.hide()
	var piloto := _caja(_receptor, "EstadoPlanilla", Vector3(.020, .003, .014), Vector3(.130, .005, -.087), Color("6b7263"))
	_piloto = piloto.material_override as StandardMaterial3D
	_piloto.emission_enabled = true
	_piloto.emission = Color("d5eca8")
	_piloto.emission_energy_multiplier = 0.0
	_caja(_receptor, "PinzaPlanilla", Vector3(.07, .006, .021), Vector3(0, .007, .087), Color("a8b3ab"))


func actualizar(caso: Denuncia, habilitada: bool, cerca: bool) -> void:
	# El papel terminado queda sobre la mesa hasta recibir otro expediente.
	if caso == null and _caso != null and _caso.estado == Denuncia.Estado.RESUELTA:
		caso = _caso
	var nuevo_id := caso.id if caso != null else ""
	var cambio_caso := nuevo_id != caso_id
	var antes_completada := completada
	_caso = caso
	caso_id = nuevo_id
	completada = caso != null and caso.estaciones_completadas.has(estacion_id)
	pendiente = caso != null and caso.estado == Denuncia.Estado.EN_PROCESO and caso.obtener_estaciones_pendientes().has(estacion_id)
	cercana = cerca and pendiente and habilitada
	var firma := "%s|%s|%s|%s|%s" % [caso_id, pendiente, completada, cercana, habilitada]
	if firma == _firma:
		return
	_firma = firma
	if _tween != null:
		_tween.kill()
	_piloto.albedo_color = Color("d5eca8") if pendiente and habilitada else Color("6b7263")
	_piloto.emission_energy_multiplier = .20 if cercana else 0.0
	_base.albedo_color = Color("dcb581") if cercana else Color("bba071")
	_hoja.visible = pendiente or completada
	(_hoja.material_override as StandardMaterial3D).albedo_color = Color("e3eccf") if completada else CREMA
	_sello.visible = completada
	_simbolo.visible = pendiente or completada
	_sello.scale = Vector3.ONE
	if is_inside_tree() and not cambio_caso and completada and not antes_completada:
		_sello.scale = Vector3(.65, 1.0, .65)
		_tween = create_tween()
		_tween.tween_property(_sello, "scale", Vector3.ONE, .18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _caja(padre: Node3D, nombre: String, tamano: Vector3, lugar: Vector3, color: Color) -> MeshInstance3D:
	var pieza := MeshInstance3D.new()
	pieza.name = nombre
	var caja := BoxMesh.new()
	caja.size = tamano
	pieza.mesh = caja
	pieza.position = lugar
	pieza.material_override = _material(color)
	padre.add_child(pieza)
	return pieza


func _crear_simbolo(id: String) -> MeshInstance3D:
	# El mismo dibujo del expediente, impreso sobre el receptor. Se renderiza una vez.
	var vista := SubViewport.new()
	vista.size = Vector2i(128, 128)
	vista.transparent_bg = true
	vista.disable_3d = true
	vista.render_target_update_mode = SubViewport.UPDATE_ONCE
	var icono := ICONO.new()
	icono.tipo = ICONO.tipo_estacion(id)
	icono.tinta = TINTA
	icono.size = Vector2(128, 128)
	vista.add_child(icono)
	add_child(vista)
	var impresion := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(.135, .135)
	impresion.mesh = plano
	var material := _material(Color.WHITE)
	material.albedo_texture = vista.get_texture()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	impresion.material_override = material
	return impresion


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .88
	return material
