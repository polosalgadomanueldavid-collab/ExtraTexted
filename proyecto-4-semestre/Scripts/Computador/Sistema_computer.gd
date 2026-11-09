extends Node
class_name SistemaComputador

# ------------------ SEÑALES DEL SISTEMA ------------------
signal cambio_de_texto(nuevo_texto: String)
signal requerir_objetos_mapa(lista_objetos: Array[String])
signal reproducir_video_derrota(ruta_video: String)
signal mostrar_resultado_final(mensaje: String)
# ---------------------------------------------------------

var pc_static: PCStatic
var nodo_actual: NodoProblematica

func evaluar_nodo() -> void:
	if not nodo_actual:
		finalizar_caso()
		return
		
	# ------------------ PROTECCIÓN CONTRA EL ERROR ------------------
	if not ("tipo_nodo" in nodo_actual):
		push_error("El recurso asignado no tiene la propiedad 'tipo_nodo'. Revisa NodoProblematica.gd.")
		finalizar_caso()
		return
	# ------------------------------------------------------------------
		
	var texto_a_mostrar: String = nodo_actual.texto_pantalla if "texto_pantalla" in nodo_actual and nodo_actual.texto_pantalla != "" else nodo_actual.texto_caso

	match nodo_actual.tipo_nodo:
		NodoProblematica.TipoNodo.DECISION:
			cambio_de_texto.emit(texto_a_mostrar)
			
		NodoProblematica.TipoNodo.REQUERIR_OBJETOS:
			cambio_de_texto.emit(texto_a_mostrar)
			if "objetos_requeridos" in nodo_actual:
				requerir_objetos_mapa.emit(nodo_actual.objetos_requeridos)

		NodoProblematica.TipoNodo.EXITO:
			mostrar_resultado_final.emit(texto_a_mostrar)
			cambio_de_texto.emit(texto_a_mostrar)
			print("--- ÉXITO: Mostrando mensaje por 3 segundos ---")
			
			await get_tree().create_timer(3.0).timeout
			finalizar_caso()

		NodoProblematica.TipoNodo.DERROTA_VIDEO:
			print("--- DERROTA: Disparando señal de video ---")
			if "ruta_video_derrota" in nodo_actual and nodo_actual.ruta_video_derrota != "":
				reproducir_video_derrota.emit(nodo_actual.ruta_video_derrota)
			elif "ruta_video" in nodo_actual:
				reproducir_video_derrota.emit(nodo_actual.ruta_video)
			else:
				reproducir_video_derrota.emit("")
				
			finalizar_caso()

		NodoProblematica.TipoNodo.CASO_IRRELEVANTE:
			cambio_de_texto.emit(texto_a_mostrar)
			await get_tree().create_timer(3.0).timeout
			finalizar_caso()


func responder_si() -> void:
	if not nodo_actual:
		return
		
	var siguiente: NodoProblematica = nodo_actual.rama_si if "rama_si" in nodo_actual and nodo_actual.rama_si else nodo_actual.nodo_si
	if siguiente:
		nodo_actual = siguiente
		evaluar_nodo()
	else:
		finalizar_caso()


func responder_no() -> void:
	if not nodo_actual:
		return
		
	var siguiente: NodoProblematica = nodo_actual.rama_no if "rama_no" in nodo_actual and nodo_actual.rama_no else nodo_actual.nodo_no
	if siguiente:
		nodo_actual = siguiente
		evaluar_nodo()
	else:
		finalizar_caso()


func finalizar_caso() -> void:
	if pc_static:
		pc_static.finalizar_caso_actual()
