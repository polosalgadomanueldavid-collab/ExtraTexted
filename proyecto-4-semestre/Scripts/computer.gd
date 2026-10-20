extends StaticBody3D
class_name PCStatic
signal computador_despacho_abierto

var player: Player
var is_using: bool = false

@onready var camera_3d: Camera3D = $Camera3D
@onready var sub_viewport: SubViewport = $SubViewport

var ui_pantalla: UIPantalla

# --- SISTEMA DE PROBLEMAS Y TEMPORIZADOR ---
@export var lista_problemas: Array[NodoProblematica] = [] # Arrastra tus archivos .tres aquí
var problema_actual: NodoProblematica = null
var sistema_computador: SistemaComputador

var timer_nuevo_problema: Timer

func _ready() -> void:
	camera_3d.current = false
	player = get_tree().get_first_node_in_group("player")
	
	# Instanciar el gestor del árbol y conectar señales
	sistema_computador = SistemaComputador.new()
	add_child(sistema_computador)
	
	# Asignar referencia y conectar la señal del texto
	sistema_computador.pc_static = self
	sistema_computador.cambio_de_texto.connect(_on_texto_caso_cambiado)
	
	# Configurar el temporizador aleatorio (20 a 40 segundos)
	timer_nuevo_problema = Timer.new()
	timer_nuevo_problema.one_shot = true
	timer_nuevo_problema.timeout.connect(_on_tiempo_nuevo_problema_agotado)
	add_child(timer_nuevo_problema)
	
	await get_tree().process_frame
	if sub_viewport.get_child_count() > 0:
		ui_pantalla = sub_viewport.get_child(0) as UIPantalla
		
	if ui_pantalla:
		ui_pantalla.pc_reference = self
		
	# Arrancar la cuenta regresiva del primer caso al iniciar la partida
	iniciar_temporizador_aleatorio()

func iniciar_temporizador_aleatorio() -> void:
	var tiempo_espera: float = randf_range(1, 5)
	timer_nuevo_problema.start(tiempo_espera)
	print("Siguiente problema llegará en: ", tiempo_espera, " segundos.")

func _on_tiempo_nuevo_problema_agotado() -> void:
	if lista_problemas.size() > 0 and problema_actual == null:
		problema_actual = lista_problemas.pick_random()
		print("¡HA LLEGADO UN NUEVO PROBLEMA!")
		
		# Si el jugador está sentado frente a la PC cuando entra el caso, actualiza la UI
		if is_using:
			actualizar_interfaz_segun_estado()

func toggle_use() -> void:
	is_using = !is_using
	camera_3d.current = is_using
	
	if player:
		# Congela o libera el movimiento del jugador según use la PC o no
		player.set_process_input(!is_using)
		player.set_physics_process(!is_using)

	if is_using:
		encender_pc()
		if ui_pantalla and ui_pantalla.vista_problema and ui_pantalla.vista_problema.visible:
			if ui_pantalla.boton_si:
				ui_pantalla.boton_si.grab_focus()
	else:
		apagar_pc()

func encender_pc() -> void:
	actualizar_interfaz_segun_estado()
	if ui_pantalla:
		ui_pantalla.encender()
	computador_despacho_abierto.emit()

func apagar_pc() -> void:
	if ui_pantalla:
		ui_pantalla.apagar()

func actualizar_interfaz_segun_estado() -> void:
	if not ui_pantalla:
		return
		
	if problema_actual == null:
		# Muestra el fondo por defecto de "Sin Problemas"
		ui_pantalla.mostrar_vista_sin_problema()
	else:
		# Carga la raíz del árbol en el sistema y evalúa la vista
		sistema_computador.nodo_actual = problema_actual
		sistema_computador.evaluar_nodo()

func _on_texto_caso_cambiado(nuevo_texto: String) -> void:
	if ui_pantalla:
		ui_pantalla.mostrar_vista_problema(nuevo_texto)

func finalizar_caso_actual() -> void:
	problema_actual = null
	
	# Asegura que la pantalla vuelva a "Sin Problemas"
	if is_using:
		actualizar_interfaz_segun_estado()
	else:
		if ui_pantalla:
			ui_pantalla.mostrar_vista_sin_problema()
			
	iniciar_temporizador_aleatorio()

func salir_de_uso() -> void:
	if not is_using:
		return
	toggle_use()
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if player:
		player.input_locked = false


func _input(event: InputEvent) -> void:
	if !is_using:
		return
		
	if event is InputEventKey and event.pressed and not event.echo:
		# La pausa conserva el uso de la PC; las escenas aisladas mantienen su salida.
		if event.is_action_pressed("Cancel"):
			if MenuGlobal.es_escena_de_juego():
				MenuGlobal.abrir_pausa()
			else:
				salir_de_uso()
			get_viewport().set_input_as_handled()
			return

		# 2. Navegación entre Botón SÍ / NO con A, D, Izquierda o Derecha
		if event.keycode in [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT] or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			if ui_pantalla:
				ui_pantalla.mover_foco()
				get_viewport().set_input_as_handled()

		# 3. Confirmar respuesta con Enter, Espacio o Tecla E
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E] or event.is_action_pressed("ui_accept"):
			if ui_pantalla:
				ui_pantalla.confirmar_seleccion()
				get_viewport().set_input_as_handled()
