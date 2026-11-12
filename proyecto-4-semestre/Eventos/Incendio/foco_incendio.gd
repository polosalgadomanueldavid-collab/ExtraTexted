extends Node3D

const Fuego := preload("res://Eventos/Incendio/fuego_3d.gd")
var evento: Node
var mesa: Node3D
var cuerpo: StaticBody3D
var nombre_visible := "Mesa del perímetro"
var estacion_id := ""
var apagado := 0.0
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
	apagado = 0.0
	mesa.set_meta("en_llamas", true)
	fuego.establecer_intensidad(1.0)


func rociar(delta: float, duracion: float) -> bool:
	apagado = minf(1.0, apagado + delta / duracion)
	if apagado >= 0.99999:
		apagado = 1.0
	mesa.set_meta("en_llamas", apagado < 1.0)
	fuego.establecer_intensidad(1.0 - apagado)
	return apagado >= 1.0


func interactuar(jugador: Player) -> void:
	evento.solicitar_apagado(self, jugador)
