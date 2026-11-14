extends Node3D

const Fuego := preload("res://Eventos/Incendio/fuego_3d.gd")
var evento: Node
var mesa: Node3D
var cuerpo: StaticBody3D
var nombre_visible := "Mesa del perímetro"
var estacion_id := ""
var apagado := 0.0
var apagando_adyacente := false
var _apagado_inicial := 0.0
var _tiempo_apagado := 0.0
var limites: AABB
var fuego: Fuego
var acceso: Marker3D


func _ready() -> void:
	fuego = Fuego.new()
	fuego.ancho = maxf(limites.size.x, limites.size.z) * 0.9
	fuego.profundo = minf(limites.size.x, limites.size.z)
	add_child(fuego)
	if limites.size.z > limites.size.x:
		fuego.rotation.y = PI * 0.5
	fuego.establecer_intensidad(0.0)


func encender() -> void:
	cancelar_apagado_adyacente()
	apagado = 0.0
	mesa.set_meta("en_llamas", true)
	fuego.establecer_intensidad(1.0)


func rociar(delta: float, duracion: float) -> bool:
	_establecer_apagado(apagado + delta / duracion)
	return apagado >= 1.0


func iniciar_apagado_adyacente() -> void:
	if apagado >= 1.0 or apagando_adyacente:
		return
	apagando_adyacente = true
	_apagado_inicial = apagado
	_tiempo_apagado = 0.0


func avanzar_apagado_adyacente(delta: float, duracion: float) -> bool:
	if not apagando_adyacente:
		return false
	_tiempo_apagado += delta
	# La llama se contrae suavemente desde su intensidad actual, sin saltos.
	var avance := smoothstep(0.0, duracion, _tiempo_apagado)
	_establecer_apagado(lerpf(_apagado_inicial, 1.0, avance))
	if apagado < 1.0:
		return false
	cancelar_apagado_adyacente()
	return true


func cancelar_apagado_adyacente() -> void:
	apagando_adyacente = false
	_tiempo_apagado = 0.0


func _establecer_apagado(valor: float) -> void:
	apagado = clampf(valor, 0.0, 1.0)
	if apagado >= 0.99999:
		apagado = 1.0
	mesa.set_meta("en_llamas", apagado < 1.0)
	fuego.establecer_intensidad(1.0 - apagado)


func interactuar(jugador: Player) -> void:
	evento.solicitar_apagado(self, jugador)
