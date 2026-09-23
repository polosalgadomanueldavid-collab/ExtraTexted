class_name NodoProblematica
extends Resource

# Identificador para diferenciar si el nodo es una pregunta o una consecuencia (hoja)
enum TipoNodo {
	DECISION,          # 0: Pregunta en pantalla que espera respuesta (SÍ / NO)
	REQUERIR_OBJETOS,  # 1: El jugador aceptó un caso real y debe buscar objetos en el mapa
	DERROTA_VIDEO,    # 2: El jugador rechazó algo grave -> Dispara video de perdiste
	CASO_IRRELEVANTE, # 3: El caso no era importante (muestra mensaje de desestimado)
	EXITO             # 4: Caso resuelto con éxito
}

@export var id: String = ""
@export_multiline var texto_pantalla: String = "" # El texto que se mostrará en el Label de la PC

# ------------------ CAMBIO REALIZADO AQUÍ ------------------
# Cambiado 'tipo' por 'tipo_nodo' para que SistemaComputador pueda leerlo
@export var tipo_nodo: TipoNodo = TipoNodo.DECISION
# ------------------------------------------------------------

# --- BIFURCACIÓN DEL ÁRBOL BINARIO (Punteros a los nodos hijos) ---
@export var rama_si: NodoProblematica # Hijo Izquierdo (Puntero al presionar SÍ)
@export var rama_no: NodoProblematica # Hijo Derecho (Puntero al presionar NO)

# Propiedades alias para mantener compatibilidad total con SistemaComputador
var nodo_si: NodoProblematica:
	get: return rama_si
	set(value): rama_si = value

var nodo_no: NodoProblematica:
	get: return rama_no
	set(value): rama_no = value

var texto_caso: String:
	get: return texto_pantalla
	set(value): texto_pantalla = value

var ruta_video: String:
	get: return ruta_video_derrota
	set(value): ruta_video_derrota = value

# --- DATOS EXTRA SEGÚN EL TIPO DE NODO (Hojas del árbol) ---
@export var objetos_requeridos: Array[String] = [] # Nombres de items (ej: ["Placa", "Radio"])
@export var ruta_video_derrota: String = ""        # Ruta del archivo (ej: "res://videos/bomba.ogv")
@export_multiline var mensaje_resultado: String = "" # Mensaje de cierre de caso
