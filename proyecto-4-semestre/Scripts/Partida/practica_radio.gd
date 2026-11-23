extends Node
## Práctica individual basada en las mismas interacciones y recursos del turno.
enum Paso { RECOGER, EVIDENCIAS, PREMIO, TIENDA, USAR, FINAL }
const CASO := "PRACTICA-001"
const Radio := preload("res://UI/Despacho/radio_practica.gd")
var activa := true
var paso := Paso.RECOGER
var oficina
var radio: Control
var maquina
var caso: Denuncia
var _espera := 0.0
var _sin_avance := 0.0
var _precio := 50
var _mesa_evidencias: Node3D
var _llevaba_hoja := false
var _mando := -2

func iniciar(mundo: Node3D) -> void:
	oficina = mundo
	if not oficina.oficina_preparada:
		await oficina.preparacion_terminada
	if not is_inside_tree():
		return
	maquina = oficina.get_node("MaquinaExpendedora")
	_precio = maxi(1, maquina.precios[0])
	for estacion in oficina.find_children("*", "Estacion", true, false):
		if estacion.estacion_id == "evidencias":
			_mesa_evidencias = estacion
			break
	for reloj in [oficina.temporizador_denuncias, oficina.temporizador_bloqueos, oficina.temporizador_eventos]:
		reloj.stop()
	oficina.anuncios.detener()
	oficina._turno_anunciado = true
	oficina.sistema_despacho.en_practica = true
	caso = Denuncia.new()
	caso.id = CASO
	caso.titulo = "Práctica: un archivo extraviado"
	caso.descripcion_despacho = "Lleva la hoja a Evidencias y archiva el carnet. Después visita SHOP."
	caso.protocolo_estaciones.assign(["evidencias"])
	caso.puntaje_recompensa = _precio
	caso.es_practica = true
	oficina.sistema_despacho.recibir_denuncia(caso)
	oficina.sistema_despacho.denuncia_resuelta.connect(_caso_resuelto)
	radio = Radio.new()
	radio.barra_despacho = oficina.panel_despacho.contenido
	oficina.get_node("CanvasLayer").add_child(radio)
	radio.omitir.connect(omitir)
	_actualizar_mensaje()

func _process(delta: float) -> void:
	if not is_instance_valid(radio) or not activa:
		return
	if not is_instance_valid(maquina) or not is_instance_valid(maquina.panel):
		omitir()
		return
	var ocultar: bool = MenuGlobal.capa.visible or oficina.clasificacion_partida.visible or oficina.partida_finalizada
	var tarea: bool = oficina.clasificador_evidencias.visible or oficina.escaner_verificacion.visible or maquina.panel.visible
	radio.visible = not ocultar and not maquina.panel.visible and paso != Paso.PREMIO and not oficina.panel_despacho.efecto_tarea.visible
	radio.compacta = oficina.clasificador_evidencias.visible or oficina.escaner_verificacion.visible
	if ocultar:
		return
	_sin_avance += delta
	if _sin_avance > 22.0 and not tarea:
		_actualizar_mensaje(true)
		_sin_avance = 0.0
	var papel = oficina.papel_actual
	var llevando: bool = is_instance_valid(papel) and papel.portador == oficina.jugador
	if (paso == Paso.EVIDENCIAS and llevando != _llevaba_hoja) or _mando != ControladorInterfaz.dispositivo_mando:
		_actualizar_mensaje()
	_llevaba_hoja = llevando
	_mando = ControladorInterfaz.dispositivo_mando
	if paso == Paso.RECOGER and is_instance_valid(papel) and papel.portador == oficina.jugador:
		_cambiar(Paso.EVIDENCIAS)
	elif paso == Paso.PREMIO:
		_espera -= delta
		if _espera <= 0.0:
			_cambiar(Paso.TIENDA)
	elif paso == Paso.TIENDA and maquina.inventario[0] > 0:
		_cambiar(Paso.USAR)
	elif paso in [Paso.TIENDA, Paso.USAR] and oficina.jugador.chocolate_restante > 0.0:
		# También reconoce USAR desde la tienda, y espera al contacto del gesto real.
		_cambiar(Paso.FINAL)
		_espera = 3.2
	elif paso == Paso.FINAL:
		_espera -= delta
		if _espera <= 0.0 and not oficina.jugador.realizando_gesto():
			_terminar()
	if not tarea:
		_actualizar_objetivo()

func _caso_resuelto(denuncia: Denuncia) -> void:
	if activa and denuncia.id == CASO and paso <= Paso.EVIDENCIAS:
		_cambiar(Paso.PREMIO)
		_espera = 3.4

func _cambiar(nuevo: Paso) -> void:
	paso = nuevo
	_sin_avance = 0.0
	_actualizar_mensaje()

func _actualizar_mensaje(pista := false) -> void:
	if paso == Paso.PREMIO:
		radio.hide()
		return
	var tecla := "X" if ControladorInterfaz.dispositivo_mando >= 0 else "E"
	var usar := "LB" if ControladorInterfaz.dispositivo_mando >= 0 else "Z"
	var titulos := ["Tu primera denuncia", "Un archivo extraviado", "Archivo completado", "Visita la tienda", "Un impulso en el bolsillo", "Agente en servicio"]
	var mensajes := [
		"Bienvenido, agente. Ve al computador del fondo y pulsa %s para recoger tu primer expediente." % tecla,
		"Lleva la hoja a Evidencias. Compara la referencia de la izquierda y archiva el carnet. Puedes reintentar.",
		"Buen trabajo. Ganaste %d puntos de saldo. Vamos a probar la tienda." % _precio,
		"Busca el cartel SHOP. Abre la máquina con %s, compra el chocolate y recoge el producto de la bandeja." % tecla,
		"Ya lo llevas contigo. Sal de la tienda y pulsa %s para usarlo. También puedes pulsar USAR en la máquina." % usar,
		"Cambio y fuera, agente. Ya sabes recoger, resolver y comprar. Ahora empieza el turno."
	]
	if pista and paso <= Paso.EVIDENCIAS and is_instance_valid(oficina.papel_actual) and oficina.papel_actual.portador == null:
		mensajes[paso] = "Tu hoja sigue en la oficina. Acércate a su marcador y pulsa %s para recuperarla." % tecla
	if paso == Paso.EVIDENCIAS and is_instance_valid(oficina.papel_actual) and oficina.papel_actual.portador == null:
		mensajes[paso] = "Se te cayó la hoja. Recógela con %s y llévala a Evidencias." % tecla
	radio.presentar(titulos[paso], mensajes[paso], paso, _precio)

func _actualizar_objetivo() -> void:
	var objetivo: Node3D
	var etiqueta := ""
	var detalle := ""
	var tecla := "X" if ControladorInterfaz.dispositivo_mando >= 0 else "E"
	if paso <= Paso.EVIDENCIAS:
		if is_instance_valid(oficina.papel_actual) and oficina.papel_actual.portador == null:
			objetivo = oficina.papel_actual
			etiqueta = "RECUPERAR HOJA"
			detalle = "%s · Recoge tu expediente del suelo" % tecla
		elif paso == Paso.RECOGER:
			objetivo = oficina.computador
			etiqueta = "COMPUTADOR · DENUNCIAS"
			detalle = "%s · Recoge tu primer caso" % tecla
		else:
			objetivo = _mesa_evidencias
			etiqueta = "EVIDENCIAS"
			detalle = "%s · Lleva la hoja y archiva el carnet" % tecla
	elif paso == Paso.TIENDA:
		objetivo = maquina
		etiqueta = "SHOP · TIENDA"
		detalle = "%s · Compra y recoge el chocolate" % tecla
	radio.objetivo = objetivo
	radio.objeto_objetivo = "tienda" if paso == Paso.TIENDA else ("pc" if objetivo == oficina.computador else "evidencias")
	radio.etiqueta_objetivo = etiqueta
	radio.detalle_objetivo = detalle

func omitir() -> void:
	if not activa:
		return
	# Retirar solo el caso de práctica sin simular un vencimiento ni perder calma.
	if oficina.sistema_despacho.arbol.buscar_por_id(CASO) != null:
		oficina.clasificador_evidencias.cancelar()
		oficina.sistema_despacho.arbol.eliminar_por_id(CASO)
		oficina.sistema_despacho.tiempos_restantes.erase(CASO)
		oficina.sistema_despacho._limpiar_caso(CASO)
		if is_instance_valid(oficina.papel_actual):
			oficina.jugador.cancelar_gesto()
			oficina.jugador.papel_en_mano = null
			oficina.papel_actual.queue_free()
			oficina.papel_actual = null
		oficina.sistema_despacho._notificar_cambios()
	if is_instance_valid(maquina) and is_instance_valid(maquina.panel):
		maquina.cerrar()
	_terminar()

func _terminar() -> void:
	if not activa:
		return
	activa = false
	oficina.sistema_despacho.en_practica = false
	MenuGlobal.guardar_practica_vista()
	radio.queue_free()
	oficina.temporizador_denuncias.start(3.0)
	oficina.anuncios.mostrar_inicio()
	queue_free()

func _exit_tree() -> void:
	if is_instance_valid(radio):
		radio.queue_free()
