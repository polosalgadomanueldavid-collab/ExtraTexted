extends Control

@onready var panel_despacho: PanelDespacho = $PanelDespacho

var sistema_despacho: SistemaDespacho


func _ready() -> void:
	sistema_despacho = SistemaDespacho.new()
	add_child(sistema_despacho)

	panel_despacho.configurar_sistema(sistema_despacho)

	var denuncias: Array[Denuncia] = [
		preload("res://Casos/Despacho/denuncia_uso_excesivo.tres") as Denuncia,
		preload("res://Casos/Despacho/denuncia_enlace_sospechoso.tres") as Denuncia,
		preload("res://Casos/Despacho/denuncia_suplantacion.tres") as Denuncia,
		preload("res://Casos/Despacho/denuncia_acoso_persistente.tres") as Denuncia,
		preload("res://Casos/Despacho/denuncia_amenaza_critica.tres") as Denuncia,
		preload("res://Casos/Despacho/denuncia_phishing_repetido.tres") as Denuncia
	]

	for denuncia: Denuncia in denuncias:
		sistema_despacho.recibir_denuncia(denuncia)
