extends SceneTree
## --headless --script res://Pruebas/ZonaDescanso/prueba_economia_descanso.gd

var _errores: Array[String] = []
var _comprobaciones: int = 0


func _initialize() -> void:
	_probar.call_deferred()


func _probar() -> void:
	_probar_gastos()
	_probar_calma()
	_probar_despacho_y_tiempos()
	print("[ECONOMIA DESCANSO] %d comprobaciones, %d errores." % [_comprobaciones, _errores.size()])
	quit(0 if _errores.is_empty() else 1)


func _probar_gastos() -> void:
	var puntuacion := SistemaPuntuacion.new()
	var saldos: Array[int] = []
	puntuacion.puntos_actualizados.connect(func(total: int) -> void: saldos.append(total))
	for cantidad: int in [50, 0, -50]:
		_verificar(not puntuacion.gastar_puntos(cantidad), "Un saldo vacío rechaza el gasto %d" % cantidad)
	_verificar(puntuacion.puntos == 0 and saldos.is_empty(), "Los gastos rechazados no modifican el saldo ni notifican ganancias")
	_verificar(puntuacion.puntos_ganados == 0, "Una partida nueva no tiene puntuación acumulada")
	var caso := _crear_caso("CAFE-SALDO", 1)
	caso.estado = Denuncia.Estado.RESUELTA
	_verificar(puntuacion.registrar_resolucion(caso) == 100, "Una denuncia resuelta permite pagar dos cafés de 50 puntos")
	_verificar(puntuacion.gastar_puntos(50) and puntuacion.puntos == 50, "El primer café descuenta exactamente 50 puntos")
	_verificar(puntuacion.puntos_ganados == 100, "Comprar café conserva los 100 puntos ganados para la clasificación")
	_verificar(puntuacion.gastar_puntos(50) and puntuacion.puntos == 0, "El segundo café puede consumir el saldo exacto")
	_verificar(not puntuacion.gastar_puntos(50) and puntuacion.puntos == 0, "El tercer café se rechaza sin dejar saldo negativo")
	_verificar(saldos == [100, 50, 0], "El HUD recibe una actualización por cada recompensa y gasto válido")
	_verificar(puntuacion.registrar_resolucion(caso) == 0, "Consumir el saldo conserva la deduplicación de las denuncias")
	_verificar(puntuacion.puntos_ganados == 100, "Repetir una denuncia consumida tampoco duplica la puntuación histórica")
	var siguiente := _crear_caso("CAFE-OTRA-RECOMPENSA", 2)
	siguiente.estado = Denuncia.Estado.RESUELTA
	puntuacion.registrar_resolucion(siguiente)
	_verificar(puntuacion.puntos == 200 and puntuacion.puntos_ganados == 300, "Una recompensa posterior suma a la puntuación histórica además del saldo disponible")
	var anteriores := saldos.duplicate()
	for cantidad: int in [201, 0, -1, -50]:
		_verificar(not puntuacion.gastar_puntos(cantidad), "Un saldo positivo rechaza el gasto inválido %d" % cantidad)
	_verificar(puntuacion.puntos == 200 and saldos == anteriores, "Los gastos inválidos no emiten cambios ni convierten valores negativos en premios")
	var otra := SistemaPuntuacion.new()
	_verificar(otra.puntos == 0 and not otra.gastar_puntos(1), "Cada partida mantiene un saldo independiente")
	_verificar(otra.puntos_ganados == 0, "La puntuación histórica también empieza de nuevo en otra partida")


func _probar_calma() -> void:
	var despacho := SistemaDespacho.new()
	var calmas: Array[int] = []
	despacho.calma_actualizada.connect(func(valor: int) -> void: calmas.append(valor))
	despacho.calma_operativa = 40
	_verificar(despacho.recuperar_calma(15) == 15 and despacho.calma_operativa == 55, "Beber un café recupera 15 puntos de calma")
	_verificar(despacho.recuperar_calma(1) == 1 and despacho.calma_operativa == 56, "Un pulso de descanso recupera un punto de calma")
	_verificar(calmas == [55, 56], "El HUD observa la calma ya actualizada después de cada recuperación")
	for cantidad: int in [0, -1, -15]:
		_verificar(despacho.recuperar_calma(cantidad) == 0 and despacho.calma_operativa == 56, "Recuperar %d no descuenta calma ni crea notificaciones" % cantidad)
	_verificar(calmas == [55, 56], "Los valores no positivos no actualizan el HUD")
	despacho.calma_operativa = 95
	_verificar(despacho.recuperar_calma(15) == 5 and despacho.calma_operativa == 100, "El café aplica solo la cantidad que cabe hasta 100")
	var cantidad_senales := calmas.size()
	_verificar(despacho.recuperar_calma(1) == 0 and despacho.recuperar_calma(15) == 0, "La calma completa no genera recuperaciones adicionales")
	_verificar(calmas.size() == cantidad_senales, "La calma completa no emite recuperaciones repetidas")
	despacho.calma_operativa = 1
	_verificar(despacho.recuperar_calma(1000000) == 99 and despacho.calma_operativa == 100, "Una recuperación grande se limita al máximo permitido")
	for valor: int in [0, -1]:
		despacho.calma_operativa = valor
		cantidad_senales = calmas.size()
		_verificar(despacho.recuperar_calma(15) == 0 and despacho.calma_operativa == valor, "Recuperar calma no revive una partida con calma %d" % valor)
		_verificar(calmas.size() == cantidad_senales, "Una partida terminada no anuncia una recuperación")
	despacho.free()


func _probar_despacho_y_tiempos() -> void:
	var despacho := SistemaDespacho.new()
	var finales: Array[bool] = []
	var cambios_denuncias: Array[bool] = []
	despacho.partida_terminada.connect(func() -> void: finales.append(true))
	despacho.denuncias_actualizadas.connect(func(_casos: Array[Denuncia]) -> void: cambios_denuncias.append(true))
	var resuelto := _crear_caso("CAFE-RECOMPENSA-REAL", 1)
	despacho.recibir_denuncia(resuelto)
	despacho.resolver_denuncia(resuelto.id)
	despacho.calma_operativa = 40
	var pendiente := _crear_caso("DESCANSO-CASO-ACTIVO", 1)
	pendiente.tiempo_limite_segundos = 10.0
	despacho.recibir_denuncia(pendiente)
	despacho.iniciar_denuncia_prioritaria()
	var cambios_antes := cambios_denuncias.size()
	_verificar(despacho.puntuacion.gastar_puntos(50), "El saldo real del despacho puede pagar un café")
	_verificar(despacho.calma_operativa == 40, "Pagar el café todavía no recupera calma: se recupera al beber")
	despacho.recuperar_calma(15)
	_verificar(despacho.puntuacion.puntos == 50 and despacho.calma_operativa == 55, "Beber aplica calma sin cobrar una segunda vez")
	_verificar(despacho.puntuacion.puntos_ganados == 100, "La compra real conserva el puntaje de las denuncias para el récord")
	_verificar(cambios_denuncias.size() == cambios_antes, "Los servicios de descanso no modifican ni reordenan denuncias")
	despacho.actualizar_tiempos(2.0)
	despacho.recuperar_calma(1)
	_verificar(is_equal_approx(despacho.obtener_tiempo_restante(pendiente.id), 8.0), "Las denuncias consumen su tiempo mientras se descansa")
	_verificar(despacho.obtener_denuncia_activa() == pendiente and pendiente.estaciones_completadas.is_empty(), "Descansar conserva el papel y el protocolo pendientes")
	despacho.calma_operativa = 1
	despacho.actualizar_tiempos(20.0)
	_verificar(despacho.calma_operativa == 0 and finales == [true], "Una denuncia puede terminar la partida mientras el jugador descansa")
	_verificar(despacho.recuperar_calma(15) == 0 and despacho.calma_operativa == 0, "El café o el sofá no revierten la partida terminada")
	_verificar(despacho.puntuacion.puntos == 50, "El vencimiento conserva el saldo restante sin devolver el café consumido")
	despacho.free()


func _crear_caso(id: String, nivel: int) -> Denuncia:
	var caso := Denuncia.new()
	caso.id = id
	caso.nivel_riesgo = nivel
	return caso


func _verificar(condicion: bool, descripcion: String) -> void:
	_comprobaciones += 1
	if not condicion:
		_errores.append(descripcion)
		push_error("[ECONOMIA DESCANSO] " + descripcion)
