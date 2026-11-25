# Multijugador LAN: arquitectura y reglas

Esta página describe la implementación actual del cooperativo para **dos jugadores**. Para iniciar una partida y ejecutar una demostración, consulta [DEMOSTRACION_LAN.md](DEMOSTRACION_LAN.md). El historial de decisiones y las verificaciones anteriores están en [PLAN_MULTIJUGADOR.md](PLAN_MULTIJUGADOR.md).

## Sesión y ciclo de vida

El juego usa **Godot 4.7**, ENet y el puerto **UDP 7000**. El anfitrión juega y es la autoridad; el segundo jugador se une por la IP del anfitrión. `SesionLAN`, cargado como autoload, mantiene participantes, alias, estado de la sala, ronda, pausas y transporte. La versión de protocolo actual es `extratexted-lan-7`; una versión distinta o una tercera conexión se rechaza.

```text
Jugar → Crear partida LAN / Unirse por IP
  → ambos marcan Estoy listo
  → el anfitrión inicia la ronda
  → cada equipo carga Oficina.tscn
  → barrera de carga: empiezan cuando ambos están listos
  → partida compartida → final → voto de reintento de ambos
```

La conexión tiene un plazo de `10 s` y la carga coordinada uno de `60 s`. Al desconectarse un participante durante la carga o la partida, la sesión termina y ambos vuelven al menú con aviso. No hay reconexión, migración de anfitrión ni ingreso a una ronda ya iniciada. Una ronda nueva limpia solicitudes pendientes, pausas, tutoriales, votos y estado anterior. El modo **Individual** usa las mismas reglas de despacho con un solo jugador y un máximo de un caso en proceso.

Las pausas se registran por participante: el mundo sigue detenido mientras alguno mantenga abierta una pantalla que lo pausa. Las guías iniciales y de eventos esperan confirmación de ambos antes de continuar. En el final, cada jugador vota **Reintentar**; el anfitrión carga la siguiente ronda al recibir los dos votos.

## Autoridad, mensajes y sincronización

`Scripts/Red/partida_lan.gd` adapta la oficina existente a la sesión. Crea y registra los dos personajes, conserva el control y la cámara locales, y representa al compañero como personaje remoto. `SistemaDespacho` y los temporizadores de casos avanzan en el anfitrión. El cliente presenta la copia recibida y envía peticiones; no decide resultados de casos, compras ni generación aleatoria del mundo.

| Flujo | Transporte | Contenido y tratamiento |
| --- | --- | --- |
| Movimiento | Canal `1`, `unreliable_ordered`, cada `0,05 s` | Posición, velocidad, giro, animación y estados visuales. El anfitrión comprueba orden de `tick`, valores finitos, límites de oficina, desplazamiento plausible y estado activo antes de retransmitir. El personaje remoto se suaviza en unos `0,1 s` y su cuerpo respeta el contacto con jugadores. |
| Acciones y respuestas | Canal `0`, `reliable` | El cliente envía ronda, número secuencial, tipo y datos. La identidad se toma del emisor RPC. El anfitrión valida el contexto, ejecuta una vez y devuelve el resultado. Conserva respuestas recientes para duplicados y rechaza números antiguos. |
| Estado de reglas y mundo | Canal `2`, `reliable`, cada `0,1 s` y tras acciones | Casos, tiempos, cordura, hojas, reservas, inventarios, saldo, aportes y eventos. Cada paquete tiene revisión creciente. Se envía un estado completo al inicio y cada 20 revisiones; los demás llevan campos cambiados. Si falta la base de un delta, el cliente solicita un estado completo. |
| Eventos confirmados | Canal `0`, `reliable` | Inicio, reparación, poderes, gestos y tareas. Las listas de celdas y los trazados especiales provienen del anfitrión. |

Los paquetes contienen valores serializables, no referencias a nodos. El número de ronda impide aplicar mensajes de una partida anterior. Los cierres de caso llevan número propio, se confirman desde el cliente y permanecen pendientes hasta el acuse; así no se pierden cuando el estado se actualiza entre dos cierres.

La validación del movimiento cubre límites y velocidad, y las acciones validan el estado que corresponde. No debe interpretarse como un sistema antitrampas general.

## Denuncias, hojas y aportes

El AVL mantiene la prioridad de las denuncias. En LAN pueden existir hasta **dos casos en proceso**, uno asignado a cada portador. Cada caso tiene una hoja física identificada por su ID. Tomarla, recogerla o lanzarla pasa por el anfitrión. La hoja lanzada puede ser recogida por el compañero para continuar el mismo caso.

Una estación valida **jugador, caso, hoja, alcance, tarea pendiente y reserva**. Evidencias y Verificación reservan el minijuego para un jugador y confirman la finalización antes de liberar la estación. Privacidad conserva la espera de desencriptado. Reporte conserva el atasco y sus llaves hasta completar o limpiar el caso. Una estación ocupada por otro caso rechaza la interacción.

Completar una estación registra al jugador como participante del caso y le suma una tarea. Transportar la hoja por sí solo no cuenta como participación. Resolver el caso suma una misión a cada participante, recupera `5` de cordura a cada responsable y agrega **una sola recompensa** al saldo compartido. Si vence, cada responsable recibe la penalización completa. Si nadie completó una estación, responde el último portador; si no hubo portador, responden ambos. Los aportes se conservan hasta el fin de la ronda aunque la denuncia venza o el jugador quede eliminado.

## Recursos, eventos y fin de partida

El saldo del equipo es único y el anfitrión decide cada gasto en orden de llegada. Si solo alcanza para una compra, la primera válida obtiene el producto. El total de puntos **ganados** se conserva aparte para la clasificación. Bolsillo, café, cordura, chocolate y dona son personales; el cobro ocurre al recoger el producto. Los dos asientos del sofá se reservan por separado y recuperan solo al usuario.

El anfitrión decide los cajones y publica sus celdas. El cliente reconstruye el mismo grafo sin volver a sortearlos. La generación protege a ambos personajes activos y las hojas sueltas. Apagón, terremoto, incendio, inundación, lava e hielo comparten inicio y estado; para terremoto se transmite el trazado exacto y para lava los charcos. El terremoto prepara datos y montaje en lotes de 3 ms. El anfitrión valida las posiciones actuales antes de publicar el plan; cada cliente confirma el identificador y la huella del plan ya montado. Solo después de todos los acuses y otra validación del anfitrión se autoriza el aviso de ocho segundos. Una cancelación retira el montaje en ambos equipos, y los acuses antiguos no liberan la barrera. Véase [DOCUMENTACION_GRAFOS.md](DOCUMENTACION_GRAFOS.md) para la navegación y las protecciones de acceso.

En incendio hay dos extintores y en el atasco de impresora dos llaves, con portadores independientes; un jugador no puede acaparar dos unidades del mismo tipo. Al eliminarse un portador, su unidad vuelve a estar disponible. Papa tiempo detiene los plazos del mundo durante `12 s` y permite actuar a ambos. Avatar resuelve el evento compartido; una resolución anterior impide gastar una segunda carga.

La cordura cero elimina al personaje hasta la siguiente ronda: libera sus interacciones y su hoja queda recuperable. El personaje deja de bloquear el paso y su cámara observa al compañero. El anfitrión sigue sirviendo la sesión aunque esté eliminado. La partida termina cuando **ambos** están eliminados. Al cerrar la ronda, cada equipo guarda su alias y puntaje ganado en su clasificación local; el resumen de aportes muestra misiones y tareas de ambos.

## Código y verificación

La radio cooperativa se abre con **R** o **B** en mando durante la partida LAN. Permite marcar estaciones, pedir ayuda, señalar una hoja cercana o anunciar una reparación, con marcador y sonido en ambos equipos. No pausa el mundo; los avisos duran seis segundos y el anfitrión limita su frecuencia a uno cada dos segundos por jugador. La [verificación del 24 de noviembre](CIERRE_TERREMOTO_Y_RADIO_2026-11-24.md) incluye la radio, las ocho distribuciones reales del terremoto y el piso preparado para evitar reconstrucciones CSG durante la partida.

| Archivo | Responsabilidad |
| --- | --- |
| `Scripts/Red/sesion_lan.gd` | Sala, transporte ENet, RPC, barrera de carga, pausas, tutoriales y reintento. |
| `Scripts/Red/partida_lan.gd` | Adaptador de oficina, validación de acciones, personajes, reservas y sincronización de estado. |
| `Scripts/Despacho/SistemaDespacho.gd` | Casos, participantes, cordura, aportes y condición de derrota. |
| `Scripts/Estructuras/arbol_denuncias_avl.gd` | Priorización de denuncias. |
| `Scripts/Partida/gestor_partida.gd` | Oficina, estaciones, eventos y grafo. |
| `UI/Menus/panel_lan.gd` | Crear sala, unirse por IP y estado de jugadores. |

Desde la raíz del repositorio, con un ejecutable de Godot 4.7:

```powershell
& .\proyecto-4-semestre\Pruebas\Multijugador\ejecutar_pruebas.ps1 -Godot $Godot
```

La suite ejecuta reglas, menú, sala, dos procesos ENet con la oficina y rechazos de conexión; deja registros en `proyecto-4-semestre/.godot/qa_lan/`. La [verificación de optimización del 16 de noviembre de 2026](VERIFICACION_OPTIMIZACION_2026-11-16.md) registró **144 comprobaciones de partida y 17 de reglas** sin errores de scripts, además de las pruebas de sala y conexión. Una prueba de resistencia de `120 s`, seis rondas y 207 casos terminó sin errores en ambos procesos. Esas pruebas se hicieron en un solo computador con dos procesos; la exportación Windows y la demostración en dos equipos reales siguen pendientes.
