extends SceneTree

var fallos := 0
var comprobaciones := 0

func _initialize() -> void:
	probar.call_deferred()

func verificar(condicion: bool, texto: String) -> void:
	comprobaciones += 1
	if not condicion:
		fallos += 1
		push_error(texto)

func nuevo() -> SistemaDespacho:
	var sistema := SistemaDespacho.new()
	root.add_child(sistema)
	sistema.set_process(false)
	sistema.configurar_jugadores([1, 2], 1)
	sistema.perder_calma(40, &"prueba", 1)
	sistema.perder_calma(40, &"prueba", 2)
	return sistema

func caso(sistema: SistemaDespacho, id: String) -> Denuncia:
	var denuncia := Denuncia.new()
	denuncia.id = id
	denuncia.protocolo_estaciones.assign(["evidencias", "reporte"])
	denuncia.penalidad_calma = 12
	sistema.recibir_denuncia(denuncia)
	return denuncia

func probar() -> void:
	var s := nuevo()
	caso(s, "uno")
	caso(s, "dos")
	caso(s, "tres")
	var a := s.iniciar_denuncia_prioritaria(1)
	var b := s.iniciar_denuncia_prioritaria(2)
	verificar(a != null and b != null and a.id != b.id, "Dos jugadores reciben casos distintos")
	s.establecer_portador(a.id, 0)
	verificar(s.iniciar_denuncia_prioritaria(1) == null, "No se imprime un tercer caso al soltar una hoja")
	s.establecer_portador(a.id, 1)
	verificar(s.interactuar_estacion("evidencias", a.id, 1), "Primer participante completa una estación")
	s.establecer_portador(a.id, 2)
	verificar(s.interactuar_estacion("reporte", a.id, 2), "El compañero puede terminar el mismo caso")
	verificar(s.obtener_cordura(1) == 65 and s.obtener_cordura(2) == 65, "Ambos participantes recuperan 5")
	verificar(s.puntuacion.puntos == 100, "Una única recompensa en el saldo compartido")
	verificar(not s.interactuar_estacion("reporte", a.id, 2) and not s.resolver_denuncia(a.id), "La resolución repetida no duplica premios")
	verificar(s.puntuacion.gastar_puntos(75) and not s.puntuacion.gastar_puntos(50), "Las compras compiten por el mismo saldo")
	verificar(s.puntuacion.puntos == 25 and s.puntuacion.puntos_ganados == 100, "Gastar no reduce puntuación ganada")
	s.free()
	s = nuevo()
	var c := caso(s, "solo")
	s.iniciar_denuncia_prioritaria(1)
	s.interactuar_estacion("evidencias", c.id, 1)
	s.establecer_portador(c.id, 2)
	s.vencer_denuncia(c.id)
	verificar(s.obtener_cordura(1) == 48 and s.obtener_cordura(2) == 60, "Llevar la hoja no cuenta como completar una estación")
	c = caso(s, "ultimo")
	s.iniciar_denuncia_prioritaria(1)
	s.establecer_portador(c.id, 2)
	s.establecer_portador(c.id, 0)
	s.vencer_denuncia(c.id)
	verificar(s.obtener_cordura(2) == 48, "Sin progreso responde el último portador aunque suelte la hoja")
	c = caso(s, "sin_recoger")
	s.vencer_denuncia(c.id)
	verificar(s.obtener_cordura(1) == 36 and s.obtener_cordura(2) == 36, "Sin recoger penaliza a ambos")
	s.recuperar_calma(15, 2)
	verificar(s.obtener_cordura(1) == 36 and s.obtener_cordura(2) == 51, "Recuperación individual")
	s.perder_calma(100, &"prueba", 1)
	verificar(not s.terminada and not s.esta_activo(1) and s.esta_activo(2), "El primer eliminado no termina la partida")
	verificar(s.recuperar_calma(100, 1) == 0, "Un eliminado no revive")
	c = caso(s, "superviviente")
	s.iniciar_denuncia_prioritaria(2)
	s.interactuar_estacion("evidencias", c.id, 2)
	s.interactuar_estacion("reporte", c.id, 2)
	verificar(s.obtener_cordura(1) == 0 and s.puntuacion.puntos == 100, "El superviviente sigue resolviendo y ganando saldo")
	s.perder_calma(100, &"prueba", 2)
	verificar(s.terminada, "La derrota requiere ambos eliminados")
	s.free()
	print("[REGLAS LAN] %d comprobaciones, %d errores" % [comprobaciones, fallos])
	quit(1 if fallos else 0)
