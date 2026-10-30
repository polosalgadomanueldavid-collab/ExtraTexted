class_name IndicadorProximaEstacion
extends Node3D
## Objeto 3D flotante que identifica la próxima estación del protocolo.
## La orientación sigue a la cámara sin mover el anclaje de la mesa.

const MODELOS := preload("res://MarcadoresEstaciones/modelos_marcador.gd")
const RESALTADO := preload("res://MarcadoresEstaciones/resaltado_interaccion.gdshader")
const AMPLITUD_FLOTACION: float = 0.045
const VELOCIDAD_FLOTACION: float = 2.2
const GIRO_BASE := Vector3(0.0, -0.24, -0.045)
const ALTURA_VISUAL: float = 0.88

## Evita que la perspectiva agrande el objeto sobre el personaje al acercarse.
@export_range(0.08, 0.5, 0.01) var alto_maximo_pantalla: float = 0.18

var estacion_id: String = ""
var interactuable: bool = false
var _orientacion: Node3D
var _modelo: Node3D
var _tiempo: float = 0.0
var _activo: bool = false
var _intensidad_interaccion: float = 0.0
var _tiempo_interaccion: float = 0.0
var _piezas_resaltadas: Array[MeshInstance3D] = []
var _materiales_resaltados: Array[StandardMaterial3D] = []
var _emisiones_base: Array[float] = []
var _contorno: ShaderMaterial


func _init() -> void:
	visible = false
	set_process(false)


func _ready() -> void:
	visibility_changed.connect(_actualizar_procesamiento)
	_actualizar_orientacion()
	_actualizar_procesamiento()


func configurar(nueva_estacion_id: String, nombre_estacion: String) -> void:
	_restablecer_resaltado()
	_piezas_resaltadas.clear()
	_materiales_resaltados.clear()
	_emisiones_base.clear()
	estacion_id = nueva_estacion_id
	name = "Indicador_" + estacion_id
	set_meta("nombre_estacion", nombre_estacion)
	if is_instance_valid(_orientacion):
		_orientacion.free()
	_orientacion = Node3D.new()
	_orientacion.name = "OrientacionCamara"
	add_child(_orientacion)
	_modelo = MODELOS.crear(estacion_id)
	_modelo.position.y = 0.16
	_modelo.rotation = GIRO_BASE
	_orientacion.add_child(_modelo)
	var puntero := MODELOS.crear_puntero()
	puntero.position.y = -0.30
	_orientacion.add_child(puntero)
	_preparar_resaltado()
	_tiempo = 0.0
	_actualizar_orientacion()


func establecer_activo(activo: bool) -> void:
	if _activo == activo and visible == activo:
		return
	_activo = activo
	visible = activo
	if not activo:
		_restablecer_resaltado()
	if activo:
		_tiempo = 0.0
		if is_instance_valid(_orientacion):
			_orientacion.position = Vector3.ZERO
			_modelo.rotation = GIRO_BASE
		_actualizar_orientacion()
	_actualizar_procesamiento()


func establecer_interactuable(disponible: bool) -> void:
	var nuevo_estado := disponible and _activo
	if interactuable == nuevo_estado:
		return
	interactuable = nuevo_estado
	if interactuable:
		_tiempo_interaccion = 0.0


func _process(delta: float) -> void:
	_tiempo += delta
	_orientacion.position.y = sin(_tiempo * VELOCIDAD_FLOTACION) * AMPLITUD_FLOTACION
	# Balanceo limitado: conserva la silueta en lugar de girar el icono de espaldas.
	_modelo.rotation.y = GIRO_BASE.y + sin(_tiempo * 1.3) * 0.07
	_modelo.rotation.z = GIRO_BASE.z + sin(_tiempo * 1.1) * 0.025
	_actualizar_resaltado(delta)
	_actualizar_orientacion()


func _preparar_resaltado() -> void:
	_contorno = ShaderMaterial.new()
	_contorno.shader = RESALTADO
	for nodo: Node in _orientacion.find_children("*", "MeshInstance3D", true, false):
		var pieza := nodo as MeshInstance3D
		var original := pieza.material_override as StandardMaterial3D
		if original == null:
			continue
		# Los materiales de la fábrica se comparten. El brillo solo afecta a este icono.
		var material := original.duplicate() as StandardMaterial3D
		pieza.material_override = material
		_piezas_resaltadas.append(pieza)
		_materiales_resaltados.append(material)
		_emisiones_base.append(material.emission_energy_multiplier)


func _actualizar_resaltado(delta: float) -> void:
	_intensidad_interaccion = move_toward(_intensidad_interaccion, 1.0 if interactuable else 0.0, delta * 7.0)
	_tiempo_interaccion += delta
	var pulso := 0.5 + 0.5 * sin(_tiempo_interaccion * 4.5)
	_contorno.set_shader_parameter("grosor", _intensidad_interaccion * lerpf(0.012, 0.019, pulso))
	for indice: int in range(_materiales_resaltados.size()):
		_materiales_resaltados[indice].emission_energy_multiplier = lerpf(_emisiones_base[indice], 0.35 + pulso * 0.25, _intensidad_interaccion)
		_piezas_resaltadas[indice].material_overlay = _contorno if _intensidad_interaccion > 0.001 else null


func _restablecer_resaltado() -> void:
	interactuable = false
	_intensidad_interaccion = 0.0
	_tiempo_interaccion = 0.0
	for indice: int in range(_materiales_resaltados.size()):
		_materiales_resaltados[indice].emission_energy_multiplier = _emisiones_base[indice]
		_piezas_resaltadas[indice].material_overlay = null


func _actualizar_orientacion() -> void:
	if not is_inside_tree() or not is_instance_valid(_orientacion):
		return
	var camara := get_viewport().get_camera_3d()
	if is_instance_valid(camara):
		var factor := 1.0
		if not camara.is_position_behind(global_position):
			var centro := camara.unproject_position(global_position)
			var arriba := camara.unproject_position(global_position + camara.global_basis.y)
			var pixeles_por_unidad := centro.distance_to(arriba)
			var alto_permitido := get_viewport().get_visible_rect().size.y * alto_maximo_pantalla
			if pixeles_por_unidad > 0.001:
				factor = minf(1.0, alto_permitido / (pixeles_por_unidad * ALTURA_VISUAL))
		# Las mallas tienen frente +Z; esta base mantiene su cara hacia el jugador.
		_orientacion.global_basis = camara.global_basis.orthonormalized().scaled(Vector3.ONE * factor)


func _actualizar_procesamiento() -> void:
	set_process(_activo and is_inside_tree() and is_visible_in_tree())
