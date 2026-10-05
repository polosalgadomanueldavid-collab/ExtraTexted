extends Node3D

@onready var panel_despacho: PanelDespacho = $CanvasLayer/PanelDespacho

const TIEMPO_MINIMO_ENTRE_DENUNCIAS: float = 12.0
const TIEMPO_MAXIMO_ENTRE_DENUNCIAS: float = 20.0
const MAX_DENUNCIAS_PENDIENTES: int = 5

var sistema_despacho: SistemaDespacho
var temporizador_denuncias: Timer
var generador_aleatorio: RandomNumberGenerator = RandomNumberGenerator.new()
var contador_denuncias: int = 0

var catalogo_denuncias: Array[Denuncia] = [
	preload("res://Casos/Despacho/denuncia_uso_excesivo.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_enlace_sospechoso.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_suplantacion.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_acoso_persistente.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_amenaza_critica.tres") as Denuncia,
	preload("res://Casos/Despacho/denuncia_phishing_repetido.tres") as Denuncia
]


func _ready() -> void:
	generador_aleatorio.randomize()

	sistema_despacho = SistemaDespacho.new()
	add_child(sistema_despacho)

	panel_despacho.configurar_sistema(sistema_despacho)

	temporizador_denuncias = Timer.new()
	temporizador_denuncias.one_shot = true
	temporizador_denuncias.timeout.connect(_recibir_denuncia_aleatoria)
	add_child(temporizador_denuncias)

	# La primera llega pronto para confirmar visualmente la integración.
	temporizador_denuncias.start(3.0)


func _recibir_denuncia_aleatoria() -> void:
	if sistema_despacho.obtener_denuncias_ordenadas().size() < MAX_DENUNCIAS_PENDIENTES:
		var plantilla: Denuncia = catalogo_denuncias[
			generador_aleatorio.randi_range(0, catalogo_denuncias.size() - 1)
		]

		# Copia independiente: evita modificar el recurso base .tres.
		var nueva_denuncia: Denuncia = plantilla.duplicate(true) as Denuncia

		contador_denuncias += 1
		nueva_denuncia.id = "%s-%03d" % [plantilla.id, contador_denuncias]
		nueva_denuncia.hora_reporte = Time.get_ticks_msec()

		sistema_despacho.recibir_denuncia(nueva_denuncia)

		print(
			"Nueva denuncia: ",
			nueva_denuncia.id,
			" | Nivel ",
			nueva_denuncia.nivel_riesgo,
			" | ",
			nueva_denuncia.titulo
		)

	_programar_siguiente_denuncia()


func _programar_siguiente_denuncia() -> void:
	var espera: float = generador_aleatorio.randf_range(
		TIEMPO_MINIMO_ENTRE_DENUNCIAS,
		TIEMPO_MAXIMO_ENTRE_DENUNCIAS
	)

	temporizador_denuncias.start(espera)
