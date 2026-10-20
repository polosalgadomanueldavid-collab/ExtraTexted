extends StaticBody3D

@export_range(0.5, 5.0, 0.1) var altura_caida: float = 2.5
@export_range(0.1, 2.0, 0.05) var duracion_caida: float = 0.55
@export_range(0.0, 0.3, 0.01) var altura_rebote: float = 0.08

@onready var diseño_cajon: Node3D = $Diseño_Cajon


func _ready() -> void:
	var altura_final: float = diseño_cajon.position.y
	diseño_cajon.position.y = altura_final + altura_caida

	var animacion := create_tween()
	animacion.tween_property(
		diseño_cajon,
		"position:y",
		altura_final,
		duracion_caida
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	animacion.tween_property(
		diseño_cajon,
		"position:y",
		altura_final + altura_rebote,
		0.08
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	animacion.tween_property(
		diseño_cajon,
		"position:y",
		altura_final,
		0.312
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
