extends Node
## Continúa la emergencia durante la pausa del despacho y aplica sus reglas
## a ambos actores. Los relojes de casos y de nuevos eventos siguen detenidos.

const Capsula := preload("res://Eventos/Hielo/capsula_hielo.gd")
const Fuego := preload("res://Eventos/Incendio/fuego_3d.gd")
var oficina: Node3D
var puerta: Node3D
var temblor := 0.0
var reloj_temblor := 0.0
var _procesos: Dictionary = {}
var _companero: Player
var _llamas: Array[Node3D] = []
var _ondas := 0.0


func configurar(escenario: Node3D, relevo: Player, vista: Camera3D) -> void:
	oficina = escenario
	puerta = oficina.get_node("PuertaRelevo")
	_companero = relevo
	for evento: Node in [oficina.evento_apagon, oficina.evento_terremoto, oficina.evento_incendio,
			oficina.evento_inundacion, oficina.evento_lava, oficina.evento_hielo]:
		_continuar(evento)
		# Los reproductores declaran PAUSABLE explícitamente: cambiar solo el
		# padre no basta para conservar retumbo, agua y ambiente de emergencia.
		for sonido: Node in evento.find_children("*", "AudioStreamPlayer", true, false):
			_continuar(sonido)
		for sonido: Node in evento.find_children("*", "AudioStreamPlayer3D", true, false):
			_continuar(sonido)
	# Algunas llamas pertenecen al mueble/cajón, fuera del nodo del evento.
	for nodo: Node in oficina.find_children("*", "Node3D", true, false):
		if nodo.get_script() == Fuego:
			_continuar(nodo)
	oficina.evento_apagon.preparar_relevo(vista, relevo)
	oficina.evento_terremoto.temblor_actualizado.connect(_al_temblar)
	oficina.evento_incendio.panel.hide()
	oficina.evento_incendio.indicador_extintor.hide()
	oficina.evento_lava.panel.hide()
	oficina.evento_hielo.aviso.hide()
	oficina.evento_hielo.indicador.hide()
	oficina.evento_inundacion._aviso.hide()
	oficina.evento_inundacion.indicador.hide()
	if oficina.evento_hielo.activo:
		var cristal := Capsula.new()
		cristal.jugador = relevo
		add_child(cristal)
	if oficina.evento_lava.activo:
		for lado in 2:
			var llama := Fuego.new()
			llama.ancho = 0.18
			llama.profundo = 0.12
			add_child(llama)
			llama.scale = Vector3.ONE * 0.3
			_llamas.append(llama)
	relevo.brazada_agua.connect(_brazada_companero)


func _continuar(nodo: Node) -> void:
	if _procesos.has(nodo):
		return
	_procesos[nodo] = nodo.process_mode
	nodo.process_mode = Node.PROCESS_MODE_ALWAYS


func _al_temblar(tiempo: float, intensidad: float) -> void:
	temblor = intensidad
	reloj_temblor = tiempo


func aplicar(actor: Player) -> void:
	var en_oficina := puerta.to_local(actor.global_position).z > 0.05 and actor.visible
	var agua: Node = oficina.evento_inundacion
	actor.establecer_nivel_agua(agua.nivel if agua.activo and en_oficina else -INF)
	var hielo: Node = oficina.evento_hielo
	actor.hielo_activo = hielo.activo and en_oficina
	actor.congelado = actor.hielo_activo and not hielo.descongelando and hielo.tiempo >= hielo.INTERVALO and fposmod(hielo.tiempo, hielo.INTERVALO) < hielo.CONGELACION
	actor.lava_activa = oficina.evento_lava.activo and en_oficina
	actor.quemandose_pies = actor.lava_activa and actor.global_position.y < oficina.evento_lava.PISO + 0.10 and oficina.evento_lava._tiempo >= oficina.evento_lava.DURACION_ENTRADA


func factor_velocidad(actor: Player) -> float:
	if actor.nadando:
		return actor.FACTOR_NADO
	if actor.hielo_activo:
		return 0.8
	if actor.lava_activa:
		return 1.25 # Pasos apresurados, alternando los pies calientes.
	if oficina.evento_incendio.activo:
		return 0.85
	return lerpf(1.0, 0.72, temblor)


func _process(delta: float) -> void:
	for i in _llamas.size():
		_llamas[i].global_position = _companero.gestos.posicion_pie("L" if i == 0 else "R")
		_llamas[i].establecer_intensidad(float(_companero.quemandose_pies))
	_ondas -= delta
	if _companero.nadando and _ondas <= 0.0:
		_ondas = 0.35
		oficina.evento_inundacion.salpicar(_companero.global_position, 0.28, true)


func _brazada_companero(lado: String) -> void:
	var mano: Node3D = _companero.gestos.mano_izquierda if lado == "L" else _companero.gestos.mano_derecha
	oficina.evento_inundacion.salpicar(mano.global_position, 0.24)


func finalizar() -> void:
	for nodo in _procesos:
		if is_instance_valid(nodo):
			nodo.process_mode = _procesos[nodo]
	_procesos.clear()
	process_mode = Node.PROCESS_MODE_PAUSABLE
