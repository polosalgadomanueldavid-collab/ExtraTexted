extends Node
## Da a los focos principales fallos breves y aleatorios sin cambiar su visibilidad.

@export var luces_parpadeantes: Array[SpotLight3D] = []

var _azar := RandomNumberGenerator.new()
var _focos: Array[Dictionary] = []


func _ready() -> void:
	_azar.randomize()
	for luz: SpotLight3D in luces_parpadeantes:
		if not is_instance_valid(luz):
			continue
		_focos.append({
			"luz": luz,
			"energia_base": luz.light_energy,
			"espera": _azar.randf_range(1.5, 5.0),
			"fase": "espera",
			"restante": 0.0,
			"pulsos": 0,
		})


func _process(delta: float) -> void:
	for foco: Dictionary in _focos:
		var luz := foco["luz"] as SpotLight3D
		# El apagón suspende el parpadeo hasta que el foco vuelva a verse.
		if not is_instance_valid(luz) or not luz.is_visible_in_tree():
			continue
		if foco["fase"] == "espera":
			foco["espera"] = float(foco["espera"]) - delta
			if float(foco["espera"]) > 0.0:
				continue
			if _azar.randf() < 0.72:
				foco["fase"] = "corte"
				foco["restante"] = _azar.randf_range(0.14, 0.30)
				foco["pulsos"] = _azar.randi_range(1, 2)
				luz.light_energy = float(foco["energia_base"]) * 0.02
			else:
				foco["espera"] = _azar.randf_range(1.5, 4.5)
			continue

		foco["restante"] = float(foco["restante"]) - delta
		if float(foco["restante"]) > 0.0:
			continue
		match String(foco["fase"]):
			"corte":
				foco["fase"] = "recupera"
				foco["restante"] = _azar.randf_range(0.10, 0.20)
				luz.light_energy = float(foco["energia_base"]) * _azar.randf_range(0.55, 0.78)
			"recupera":
				foco["pulsos"] = int(foco["pulsos"]) - 1
				if int(foco["pulsos"]) > 0:
					foco["fase"] = "pausa"
					foco["restante"] = _azar.randf_range(0.09, 0.19)
					luz.light_energy = float(foco["energia_base"]) * 0.9
				else:
					foco["fase"] = "espera"
					foco["espera"] = _azar.randf_range(2.5, 7.0)
					luz.light_energy = float(foco["energia_base"])
			"pausa":
				foco["fase"] = "corte"
				foco["restante"] = _azar.randf_range(0.14, 0.28)
				luz.light_energy = float(foco["energia_base"]) * 0.02
