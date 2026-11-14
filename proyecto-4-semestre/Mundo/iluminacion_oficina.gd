extends Node
## Da fallos breves y aleatorios a unos pocos focos.
## Usa temporizadores para no actualizar luces en cada fotograma.

@export var luces_parpadeantes: Array[SpotLight3D] = []

var _azar := RandomNumberGenerator.new()
var _focos: Array[Dictionary] = []


func _ready() -> void:
	_azar.randomize()
	for luz: SpotLight3D in luces_parpadeantes:
		if not is_instance_valid(luz):
			continue
		var indice := _focos.size()
		var temporizador := Timer.new()
		temporizador.one_shot = true
		temporizador.timeout.connect(_avanzar_parpadeo.bind(indice))
		add_child(temporizador)
		_focos.append({
			"luz": luz,
			"energia_base": luz.light_energy,
			"fase": "espera",
			"pulsos": 0,
			"temporizador": temporizador,
		})
		temporizador.start(_azar.randf_range(2.0, 6.0))


func _avanzar_parpadeo(indice: int) -> void:
	if indice < 0 or indice >= _focos.size():
		return
	var foco: Dictionary = _focos[indice]
	var luz := foco["luz"] as SpotLight3D
	var temporizador := foco["temporizador"] as Timer
	if not is_instance_valid(luz) or not is_instance_valid(temporizador):
		return

	# Si el apagón ocultó el foco, queda preparado para volver estable.
	if not luz.is_visible_in_tree():
		foco["fase"] = "espera"
		luz.light_energy = float(foco["energia_base"])
		temporizador.start(_azar.randf_range(0.8, 1.4))
		return

	match String(foco["fase"]):
		"espera":
			if _azar.randf() >= 0.72:
				temporizador.start(_azar.randf_range(1.5, 4.5))
				return
			foco["fase"] = "corte"
			foco["pulsos"] = _azar.randi_range(1, 2)
			luz.light_energy = float(foco["energia_base"]) * 0.02
			temporizador.start(_azar.randf_range(0.14, 0.28))
		"corte":
			foco["fase"] = "recupera"
			luz.light_energy = float(foco["energia_base"]) * _azar.randf_range(0.58, 0.78)
			temporizador.start(_azar.randf_range(0.10, 0.18))
		"recupera":
			foco["pulsos"] = int(foco["pulsos"]) - 1
			if int(foco["pulsos"]) > 0:
				foco["fase"] = "pausa"
				luz.light_energy = float(foco["energia_base"]) * 0.9
				temporizador.start(_azar.randf_range(0.09, 0.17))
			else:
				foco["fase"] = "espera"
				luz.light_energy = float(foco["energia_base"])
				temporizador.start(_azar.randf_range(2.5, 7.0))
		"pausa":
			foco["fase"] = "corte"
			luz.light_energy = float(foco["energia_base"]) * 0.02
			temporizador.start(_azar.randf_range(0.14, 0.26))
