extends Control
## Check dibujado, círculo irregular y subrayado de la opción «Check con garabato».

const DURACION := 1.4
const FUENTE := preload("res://UI/Menus/ArtePiloto/LuckiestGuy-Regular.ttf")
const FUENTE_DETALLE := preload("res://UI/Menus/ArtePiloto/Nunito.ttf")
const SONIDO := preload("res://Audios/tarea_completada.wav")
const TINTA := Color("173b50")
const CREMA := Color("fff1d8")
const CORAL := Color("ff785f")
const VERDE := Color("a8dcad")

var tiempo: float = 0.0
var estacion: String = ""
var caso_id: String = ""
var sonido: AudioStreamPlayer
var _circulo := PackedVector2Array()
var _check := PackedVector2Array([Vector2(-24, -12), Vector2(-12, 5), Vector2(-7, 8), Vector2(25, -31)])
var _subrayado := PackedVector2Array([Vector2(-47, 84), Vector2(-11, 81), Vector2(43, 83), Vector2(32, 87), Vector2(-23, 89)])


func _ready() -> void:
	name = "EfectoTareaCompletada"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 20
	for indice: int in range(66):
		var angulo := -0.7 + indice / 65.0 * TAU * 1.065
		_circulo.append(Vector2(cos(angulo) * (48.0 + sin(indice * 0.53) * 1.1), sin(angulo) * 43.0 - 8.0))
	sonido = AudioStreamPlayer.new()
	sonido.name = "SonidoLapiz"
	sonido.stream = SONIDO
	sonido.volume_db = -6.5
	add_child(sonido)
	resized.connect(queue_redraw)
	detener()


func reproducir(nombre_estacion: String, id_denuncia: String) -> void:
	estacion = nombre_estacion
	caso_id = id_denuncia
	tiempo = 0.0
	modulate.a = 1.0
	show()
	set_process(true)
	# Una instancia reutilizable evita acumular voces al completar tareas seguidas.
	sonido.stop()
	sonido.play()
	queue_redraw()


func detener() -> void:
	hide()
	set_process(false)
	tiempo = 0.0
	estacion = ""
	caso_id = ""
	if is_instance_valid(sonido):
		sonido.stop()


func _process(delta: float) -> void:
	tiempo += delta
	if tiempo >= DURACION:
		detener()
		return
	modulate.a = clampf((DURACION - tiempo) / 0.28, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var avance := clampf(tiempo / DURACION, 0.0, 1.0)
	var factor := maxf(0.1, minf(size.x / 1280.0, size.y / 720.0))
	var centro := Vector2(size.x * 0.5, size.y * 0.35)
	draw_set_transform(centro, 0.0, Vector2.ONE * factor)
	_trazo(_circulo, CREMA, 2.5, (avance - 0.18) * 3.0)
	_trazo(_check, VERDE, 7.0, avance * 4.0)
	var aparicion := clampf((avance - 0.25) * 6.0, 0.0, 1.0)
	_texto("¡HECHO!", FUENTE, 29, 70.0, aparicion)
	_trazo(_subrayado, CORAL, 2.5, (avance - 0.4) * 5.0)
	_texto(estacion.to_upper(), FUENTE_DETALLE, 16, 114.0, aparicion)
	for indice: int in range(3):
		var angulo := -0.9 + indice * 0.8
		var inicio := Vector2(cos(angulo) * 67.0, sin(angulo) * 55.0 - 8.0)
		var fin := Vector2(cos(angulo) * 80.0, sin(angulo) * 70.0 - 8.0)
		_trazo(PackedVector2Array([inicio, fin]), CORAL, 3.0, (avance - 0.35) * 6.0)
	draw_set_transform(Vector2.ZERO)


func _texto(texto: String, fuente: Font, tamano: int, y: float, opacidad: float) -> void:
	if opacidad <= 0.0:
		return
	var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
	var posicion := Vector2(-ancho * 0.5, y)
	draw_string_outline(fuente, posicion, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, 6, Color(TINTA, opacidad))
	draw_string(fuente, posicion, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, Color(CREMA, opacidad))


func _trazo(puntos: PackedVector2Array, color: Color, ancho: float, avance: float) -> void:
	if avance <= 0.0 or puntos.size() < 2:
		return
	var longitud := 0.0
	for indice: int in range(1, puntos.size()):
		longitud += puntos[indice - 1].distance_to(puntos[indice])
	var restante := longitud * clampf(avance, 0.0, 1.0)
	var parcial := PackedVector2Array([puntos[0]])
	for indice: int in range(1, puntos.size()):
		var segmento := puntos[indice - 1].distance_to(puntos[indice])
		if restante < segmento:
			parcial.append(puntos[indice - 1].lerp(puntos[indice], restante / segmento))
			break
		parcial.append(puntos[indice])
		restante -= segmento
	draw_polyline(parcial, TINTA, ancho + 3.0, true)
	draw_polyline(parcial, color, ancho, true)
	draw_circle(parcial[0], ancho * 0.5, color, true, -1.0, true)
	draw_circle(parcial[-1], ancho * 0.5, color, true, -1.0, true)
