class_name PanelDespacho
extends Control

const IconoDespacho := preload("res://UI/Despacho/icono_despacho.gd")
const ANCHO_DISENO := 408.0
const TAMANO_DISENO := Vector2(1920, 1080)
const MARGEN := 28.0
const PETROLEO := Color("173b50")
const CREMA := Color("fff1d8")
const CORAL := Color("ff785f")
const ICONOS_ESTACION := {
	"evidencias": IconoDespacho.Tipo.EVIDENCIAS,
	"verificacion": IconoDespacho.Tipo.VERIFICACION,
	"privacidad": IconoDespacho.Tipo.PRIVACIDAD,
	"reporte": IconoDespacho.Tipo.REPORTE,
	"bienestar": IconoDespacho.Tipo.BIENESTAR
}

@onready var contenido: VBoxContainer = $Contenido
@onready var calma_texto: Label = $Contenido/Calma/Cabecera/Titulo
@onready var calma_valor: Label = %ValorCalma
@onready var calma_barra: ProgressBar = %CalmaBar
@onready var denuncia_activa_detalle: PanelContainer = %TarjetaActiva
@onready var denuncia_activa_titulo: Label = %TituloCaso
@onready var denuncia_activa_tiempo: Label = %TiempoActivo
@onready var reloj_activo: Control = %RelojActivo
@onready var protocolo: Control = %Protocolo
@onready var icono_actividad: Control = %IconoActividad
@onready var mensaje_estacion: Label = %MensajeEstacion
@onready var lista_denuncias: VBoxContainer = %ListaDenuncias

var sistema_despacho: SistemaDespacho = null
var tarjetas: Dictionary = {}
var denuncias_visibles: Dictionary = {}
var segundos_mensaje: float = 0.0
var _id_activo: String = ""
var _indice_activo: int = -1


func _ready() -> void:
	resized.connect(_ajustar_presentacion)
	for etiqueta: Label in [calma_texto, calma_valor, %TituloActiva, $Contenido/CabeceraEspera/Titulo, %SinCasoActivo, %SinPendientes, mensaje_estacion]:
		_estilo_sobre_escenario(etiqueta)
	%CantidadEspera.add_theme_stylebox_override("normal", _pastilla(CORAL))
	%CantidadEspera.add_theme_color_override("font_color", CREMA)
	_ajustar_presentacion()
	actualizar_calma(100)
	actualizar_denuncias([])


func _process(delta: float) -> void:
	if not is_instance_valid(sistema_despacho):
		return
	for id: String in tarjetas:
		_actualizar_tarjeta(denuncias_visibles[id])
	_actualizar_denuncia_activa()
	_actualizar_mensaje(delta)


func _ajustar_presentacion() -> void:
	# Escala únicamente el HUD, sin cambiar el viewport ni las coordenadas del juego.
	var factor := maxf(0.1, minf(size.x / TAMANO_DISENO.x, size.y / TAMANO_DISENO.y))
	contenido.scale = Vector2.ONE * factor
	contenido.position = Vector2(size.x - (ANCHO_DISENO + MARGEN) * factor, MARGEN * factor)
	contenido.size = Vector2(ANCHO_DISENO, maxf(0.0, size.y / factor - MARGEN * 2.0))


func configurar_sistema(nuevo_sistema: SistemaDespacho) -> void:
	if sistema_despacho == nuevo_sistema:
		return
	if is_instance_valid(sistema_despacho):
		_cambiar_conexiones(false)
	sistema_despacho = nuevo_sistema
	if not is_instance_valid(sistema_despacho):
		actualizar_denuncias([])
		return
	_cambiar_conexiones(true)
	actualizar_calma(sistema_despacho.calma_operativa)
	actualizar_denuncias(sistema_despacho.obtener_denuncias_ordenadas())


func _cambiar_conexiones(conectar: bool) -> void:
	var conexiones := [
		[sistema_despacho.denuncias_actualizadas, actualizar_denuncias],
		[sistema_despacho.calma_actualizada, actualizar_calma],
		[sistema_despacho.estacion_completada, _on_estacion_completada],
		[sistema_despacho.estacion_incorrecta, _on_estacion_incorrecta],
		[sistema_despacho.denuncia_resuelta, _on_denuncia_resuelta],
		[sistema_despacho.denuncia_vencida, _on_denuncia_vencida]
	]
	for conexion: Array in conexiones:
		var senal: Signal = conexion[0]
		var destino: Callable = conexion[1]
		if conectar and not senal.is_connected(destino):
			senal.connect(destino)
		elif not conectar and senal.is_connected(destino):
			senal.disconnect(destino)


func actualizar_calma(nueva_calma: int) -> void:
	calma_barra.value = nueva_calma
	calma_valor.text = "%d / 100" % nueva_calma
	var color := CREMA if nueva_calma >= 30 else CORAL
	calma_valor.add_theme_color_override("font_color", color)
	calma_barra.modulate = Color.WHITE if nueva_calma >= 30 else CORAL


func actualizar_denuncias(denuncias: Array[Denuncia]) -> void:
	for hijo: Node in lista_denuncias.get_children():
		lista_denuncias.remove_child(hijo)
		hijo.queue_free()
	tarjetas.clear()
	denuncias_visibles.clear()
	for denuncia: Denuncia in denuncias:
		if denuncia.estado != Denuncia.Estado.PENDIENTE:
			continue
		var tarjeta := _crear_tarjeta(denuncia, tarjetas.is_empty())
		lista_denuncias.add_child(tarjeta)
		tarjetas[denuncia.id] = tarjeta
		denuncias_visibles[denuncia.id] = denuncia
		_actualizar_tarjeta(denuncia)
	%CantidadEspera.text = str(tarjetas.size())
	%SinPendientes.visible = tarjetas.is_empty()
	_actualizar_denuncia_activa()


func _crear_tarjeta(denuncia: Denuncia, siguiente: bool) -> PanelContainer:
	var color := _color_riesgo(denuncia.nivel_riesgo)
	var tarjeta := PanelContainer.new()
	tarjeta.name = denuncia.id
	tarjeta.custom_minimum_size.y = 82
	tarjeta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(CREMA, 0.94)
	estilo.set_corner_radius_all(14)
	estilo.border_width_left = 7
	estilo.border_color = color
	estilo.content_margin_left = 18
	estilo.content_margin_right = 14
	estilo.content_margin_top = 8
	estilo.content_margin_bottom = 8
	tarjeta.add_theme_stylebox_override("panel", estilo)
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_theme_constant_override("separation", 10)
	tarjeta.add_child(fila)
	var alerta := IconoDespacho.new()
	alerta.tipo = IconoDespacho.Tipo.ALERTA
	alerta.acento = color
	alerta.informativo = denuncia.nivel_riesgo <= 2
	alerta.custom_minimum_size = Vector2(30, 40)
	fila.add_child(alerta)
	var texto := VBoxContainer.new()
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texto.add_theme_constant_override("separation", 4)
	fila.add_child(texto)
	var riesgo := _etiqueta("%s · N%d" % [_etiqueta_riesgo(denuncia.nivel_riesgo), denuncia.nivel_riesgo], 15)
	riesgo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	riesgo.add_theme_stylebox_override("normal", _pastilla(color))
	riesgo.add_theme_color_override("font_color", CREMA)
	texto.add_child(riesgo)
	var titulo := _etiqueta(denuncia.titulo, 20)
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.add_child(titulo)
	var derecha := VBoxContainer.new()
	derecha.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	derecha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	derecha.add_theme_constant_override("separation", 4)
	fila.add_child(derecha)
	if siguiente:
		var rotulo := _etiqueta("SIGUIENTE", 12)
		rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rotulo.add_theme_color_override("font_color", CORAL)
		derecha.add_child(rotulo)
	var tiempo := HBoxContainer.new()
	tiempo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tiempo.add_theme_constant_override("separation", 6)
	derecha.add_child(tiempo)
	var arena := IconoDespacho.new()
	arena.custom_minimum_size = Vector2(18, 26)
	tiempo.add_child(arena)
	# En espera el icono conserva su dibujo y no ejecuta _process.
	var valor := _etiqueta("00:00", 23)
	valor.custom_minimum_size.x = 65
	tiempo.add_child(valor)
	tarjeta.set_meta("tiempo", valor)
	tarjeta.set_meta("reloj", arena)
	return tarjeta


func _actualizar_tarjeta(denuncia: Denuncia) -> void:
	var tarjeta: PanelContainer = tarjetas.get(denuncia.id)
	if tarjeta == null:
		return
	var tiempo := denuncia.tiempo_limite_segundos
	if is_instance_valid(sistema_despacho):
		tiempo = sistema_despacho.obtener_tiempo_restante(denuncia.id)
	var etiqueta: Label = tarjeta.get_meta("tiempo")
	etiqueta.text = _formatear_tiempo(tiempo)


func _actualizar_denuncia_activa() -> void:
	var denuncia: Denuncia = null
	if is_instance_valid(sistema_despacho):
		denuncia = sistema_despacho.obtener_denuncia_activa()
	denuncia_activa_detalle.visible = denuncia != null
	%SinCasoActivo.visible = denuncia == null
	if denuncia == null:
		reloj_activo.sincronizar_tiempo(0.0, 1.0, false)
		_id_activo = ""
		_indice_activo = -1
		return
	if _id_activo != denuncia.id:
		_id_activo = denuncia.id
		_indice_activo = -1
		denuncia_activa_titulo.text = denuncia.titulo
		var color := _color_riesgo(denuncia.nivel_riesgo)
		var estilo := denuncia_activa_detalle.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		estilo.border_color = color
		denuncia_activa_detalle.add_theme_stylebox_override("panel", estilo)
		%EtiquetaRiesgo.text = "%s · NIVEL %d" % [_etiqueta_riesgo(denuncia.nivel_riesgo), denuncia.nivel_riesgo]
		%EtiquetaRiesgo.add_theme_stylebox_override("normal", _pastilla(color))
		%EtiquetaRiesgo.add_theme_color_override("font_color", CREMA)
		%IconoRiesgo.acento = color.darkened(0.32)
		%IconoRiesgo.queue_redraw()
	var tiempo := sistema_despacho.obtener_tiempo_restante(denuncia.id)
	denuncia_activa_tiempo.text = _formatear_tiempo(tiempo)
	reloj_activo.sincronizar_tiempo(tiempo, denuncia.tiempo_limite_segundos, true)
	if _indice_activo != denuncia.indice_estacion_actual:
		_indice_activo = denuncia.indice_estacion_actual
		protocolo.configurar(denuncia.protocolo_estaciones, _indice_activo)
		var tiene_estacion := _indice_activo < denuncia.protocolo_estaciones.size()
		icono_actividad.visible = tiene_estacion
		if tiene_estacion:
			icono_actividad.tipo = ICONOS_ESTACION.get(denuncia.protocolo_estaciones[_indice_activo], IconoDespacho.Tipo.REPORTE)
			icono_actividad.queue_redraw()


func _formatear_tiempo(tiempo: float) -> String:
	var segundos := maxi(0, ceili(tiempo))
	return "%02d:%02d" % [floori(segundos / 60.0), segundos % 60]


func _etiqueta(texto: String, tamano: int) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_size_override("font_size", tamano)
	return etiqueta


func _pastilla(color: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.set_corner_radius_all(14)
	estilo.content_margin_left = 9
	estilo.content_margin_right = 9
	estilo.content_margin_top = 3
	estilo.content_margin_bottom = 3
	return estilo


func _estilo_sobre_escenario(etiqueta: Label) -> void:
	etiqueta.add_theme_color_override("font_color", CREMA)
	etiqueta.add_theme_color_override("font_shadow_color", Color("031923b3"))
	etiqueta.add_theme_constant_override("shadow_offset_x", 1)
	etiqueta.add_theme_constant_override("shadow_offset_y", 2)
	etiqueta.add_theme_constant_override("shadow_outline_size", 3)


func _on_estacion_completada(_denuncia: Denuncia, estacion_id: String) -> void:
	_mostrar_mensaje("Correcto: %s completada." % _nombre_estacion(estacion_id), Color("86efac"))


func _on_estacion_incorrecta(_denuncia: Denuncia, estacion_esperada: String) -> void:
	_mostrar_mensaje("Estación incorrecta. Ve a %s." % _nombre_estacion(estacion_esperada), CORAL)


func _on_denuncia_resuelta(_denuncia: Denuncia) -> void:
	_mostrar_mensaje("Denuncia resuelta: +5 de calma.", Color("86efac"))


func _on_denuncia_vencida(denuncia: Denuncia) -> void:
	_mostrar_mensaje("La denuncia '%s' venció." % denuncia.titulo, CORAL)


func _nombre_estacion(id: String) -> String:
	return "Verificación" if id == "verificacion" else id.capitalize()


func _mostrar_mensaje(texto: String, color: Color) -> void:
	mensaje_estacion.text = texto
	mensaje_estacion.add_theme_color_override("font_color", color)
	mensaje_estacion.show()
	segundos_mensaje = 3.0


func _actualizar_mensaje(delta: float) -> void:
	if segundos_mensaje <= 0.0:
		return
	segundos_mensaje -= delta
	if segundos_mensaje <= 0.0:
		mensaje_estacion.hide()


func _etiqueta_riesgo(nivel: int) -> String:
	match nivel:
		5: return "CRÍTICA"
		4: return "ALTA"
		3: return "MEDIA"
		2: return "PREVENCIÓN"
		_: return "BIENESTAR"


func _color_riesgo(nivel: int) -> Color:
	match nivel:
		5: return CORAL
		4: return CORAL
		3: return Color("f4a400")
		2: return Color("10b5b5")
		_: return Color("75a6a8")
