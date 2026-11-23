extends Node3D
## Luz de trabajo sobre el diseño original, sin superponer materiales a sus mallas.

const REGIONES := {
	"evidencias": AABB(Vector3(-.60,.54,-.04), Vector3(.48,.28,.33)),
	"verificacion": AABB(Vector3(.0,.56,-.22), Vector3(.58,.42,.36)),
	"privacidad": AABB(Vector3(-.61,.54,-.20), Vector3(.38,.22,.38)),
	"reporte": AABB(Vector3(-.60,.52,-.20), Vector3(.46,.07,.47)),
	"bienestar": AABB(Vector3(.20,.54,-.24), Vector3(.34,.35,.36))
}
var estacion_id := ""
var caso_id := ""
var pendiente := false
var completada := false
var cercana := false
var _caso: Denuncia
var modelo_original: Node3D
var piezas_originales: Array[MeshInstance3D] = []
var _capas_originales: Array[int] = []
var luz_trabajo: SpotLight3D
var _firma := ""
var intensidad := 0.0:
	set(valor):
		intensidad = valor
		if is_instance_valid(luz_trabajo): luz_trabajo.light_energy = valor
var _transicion: Tween

func configurar(id: String) -> void:
	estacion_id = id
	name = "RespuestaModelo_" + id
	var mesa := get_parent().get_parent() as MeshInstance3D
	for hijo: Node in mesa.get_children():
		if str(hijo.name).begins_with("Diseno_") and hijo is Node3D:
			modelo_original = hijo as Node3D
			break
	if modelo_original == null: return
	for pieza: MeshInstance3D in modelo_original.find_children("*", "MeshInstance3D", true, false):
		piezas_originales.append(pieza)
		_capas_originales.append(pieza.layers)
		pieza.set_layer_mask_value(19, true)
	# No se toca material_override/material_overlay: la textura y la iluminación
	# del GLB permanecen intactas, también durante la compilación de shaders.
	luz_trabajo = SpotLight3D.new()
	luz_trabajo.name = "LuzDeTrabajo"
	luz_trabajo.position = Vector3(0, 1.55, 0)
	luz_trabajo.rotation.x = -PI / 2.0
	luz_trabajo.light_color = Color("fff1d8")
	luz_trabajo.light_specular = 0.0
	luz_trabajo.light_energy = 0.0
	luz_trabajo.spot_range = 1.55
	luz_trabajo.spot_angle = 50.0
	luz_trabajo.spot_attenuation = 0.6
	luz_trabajo.shadow_enabled = false
	# La luz adicional alcanza solo el mobiliario, nunca los flotantes o el jugador.
	luz_trabajo.light_cull_mask = 1 << 18
	add_child(luz_trabajo)

func _exit_tree() -> void:
	for i in piezas_originales.size():
		if is_instance_valid(piezas_originales[i]):
			piezas_originales[i].layers = _capas_originales[i]

func actualizar(caso: Denuncia, habilitada: bool, cerca: bool) -> void:
	if caso == null and _caso != null and _caso.estado == Denuncia.Estado.RESUELTA:
		caso = _caso
	_caso = caso
	caso_id = caso.id if caso != null else ""
	completada = caso != null and caso.estaciones_completadas.has(estacion_id)
	pendiente = caso != null and caso.estado == Denuncia.Estado.EN_PROCESO and caso.obtener_estaciones_pendientes().has(estacion_id)
	cercana = cerca and pendiente and habilitada
	var firma := "%s|%s|%s|%s|%s" % [caso_id, completada, pendiente, cercana, habilitada]
	if firma == _firma: return
	_firma = firma
	var objetivo := (.85 if cercana else .45) if pendiente else (.12 if completada else 0.0)
	if not habilitada: objetivo = 0.0
	if _transicion != null: _transicion.kill()
	_transicion = create_tween()
	_transicion.tween_property(self, "intensidad", objetivo, .18)

func origen_resultado() -> Vector3:
	var region: AABB = REGIONES[estacion_id]
	return get_parent().to_global(region.get_center())
