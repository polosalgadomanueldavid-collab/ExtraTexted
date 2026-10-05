class_name NodoAVL
extends RefCounted

var denuncia: Denuncia
var izquierda: NodoAVL = null
var derecha: NodoAVL = null
var altura: int = 1


func _init(nueva_denuncia: Denuncia) -> void:
	denuncia = nueva_denuncia
