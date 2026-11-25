# Multijugador LAN de ExtraTexted: dos jugadores

Para la verificación más reciente del terremoto, la radio y las pruebas LAN, consultar [CIERRE_TERREMOTO_Y_RADIO_2026-11-24.md](CIERRE_TERREMOTO_Y_RADIO_2026-11-24.md). Los resultados históricos de esta página se conservan como referencia.

Actualizado: 15 de noviembre de 2026. Sustituye el plan preliminar del 7 de noviembre.

Para la arquitectura y las reglas vigentes, consulta [DOCUMENTACION_MULTIJUGADOR.md](DOCUMENTACION_MULTIJUGADOR.md). Las comprobaciones más recientes están en [VERIFICACION_OPTIMIZACION_2026-11-16.md](VERIFICACION_OPTIMIZACION_2026-11-16.md).

## Reglas acordadas e implementadas

| Aspecto | Comportamiento |
| --- | --- |
| Sesión | Dos computadores en LAN. El anfitrión también juega. UDP 7000, ENet, conexión por IP. |
| Individual | Usa el mismo sistema de reglas con un jugador y un caso en proceso. |
| Denuncias | AVL de prioridad; hasta dos casos en proceso, una hoja por caso y una por jugador. Se transfieren lanzándolas y recogiéndolas. |
| Participación | Se añade al confirmar una estación válida. Transportar la hoja no basta. |
| Cordura | Individual. Resolver recupera 5 a cada participante; vencer aplica la penalización completa a cada participante. Sin progreso responde el último portador; si nadie recogió, responden ambos. |
| Puntuación | Los casos resueltos cuentan para ambos. Comprar no reduce la puntuación ganada para la clasificación. |
| Saldo compartido | Cada recompensa entra una sola vez. Todas las compras descuentan del mismo fondo en el anfitrión. La primera compra válida gana cuando no alcanza para ambas. |
| Inventario | Bolsillo y café personales; solo recibe el producto quien compra. El cobro ocurre al recoger el producto. Cancelar antes no cobra. |
| Descanso | Café y sofá recuperan solo al usuario. Los dos asientos del sofá se reservan por separado. |
| Herramientas | Dos extintores en incendio y dos llaves en el atasco de impresora, con portadores independientes y máximo uno de cada tipo por jugador. Al eliminarse el portador, su unidad vuelve al punto de recogida. Individual mantiene una unidad. |
| Contacto | Los personajes activos chocan y pueden bloquearse el paso; el movimiento remoto también respeta el contacto. |
| Eliminación | Cordura cero elimina hasta la próxima ronda, libera interacciones y deja la hoja recuperable. La cámara sigue al compañero; el personaje no bloquea pasos. |
| Derrota | Solo cuando ambos están eliminados. El anfitrión continúa sirviendo aunque esté eliminado. |
| Pausa y guías | Pausan el mundo para ambos; se reanuda cuando ninguno conserva una pantalla que pausa. El transporte continúa funcionando. |
| Poderes | Chocolate y dona personales. Papa tiempo detiene el mundo 12 segundos y permite actuar a ambos. Avatar resuelve el evento compartido. Un segundo uso rechazado conserva su carga. |
| Dificultad | Se conservan tiempos, precios, frecuencias y penalizaciones, incluso con un superviviente. |
| Desconexión | Termina la sesión y vuelve al menú con aviso. Sin reconexión, cambio de anfitrión ni ingreso a una ronda empezada. |
| Clasificación | Se guarda el puntaje ganado en el equipo de cada jugador, con su alias y el formato existente. |

## Implementación

1. **Reglas y casos** — `Scripts/Despacho/SistemaDespacho.gd` mantiene jugadores identificados, casos, participantes, último portador, cordura y eliminación. `SistemaPuntuacion` conserva un saldo de equipo y un total ganado independiente. El AVL continúa priorizando las denuncias.
2. **Sesión y personajes** — `Scripts/Red/sesion_lan.gd`, autoload persistente, administra sala, alias, versión de protocolo, preparación, carga coordinada, pausas, desconexión y reinicio. `UI/Menus/panel_lan.gd` agrega Individual, Crear partida y Unirse por IP. Solo el personaje local procesa controles y cámara.
3. **Autoridad de juego** — `Scripts/Red/partida_lan.gd` conecta la oficina existente con las reglas compartidas. El anfitrión valida identidad, estado, alcance, hoja, caso, reservas y saldo; ejecuta acciones y publica confirmaciones. Los minijuegos existentes se abren exclusivamente para quien reserva la estación.
4. **Eventos y poderes** — Se integraron apagón, terremoto, incendio, inundación, lava e hielo. El anfitrión publica las celdas de obstáculos, el trazado exacto del terremoto y los charcos de lava. Las reparaciones y cada unidad de herramienta se reservan por separado; Avatar no consume una carga si otra resolución ya ganó. Se protegen ambos personajes, accesos a herramientas y las hojas al generar obstáculos y peligros. La llave recogible y el gesto de reparación usan el mismo modelo procedural.
5. **Final y nueva ronda** — Se cancelan tareas del eliminado, se liberan reservas y se conserva la capacidad de continuar con el superviviente. El anfitrión coordina el final y la recarga. La nueva ronda limpia saldo, casos, objetos, pausas y poderes.

### Mensajes y concurrencia

- Movimiento a 20 Hz por canal no fiable ordenado: posición, velocidad, orientación, animación y estados visuales. Entrada local inmediata; suavizado remoto de 100 ms y validación de desplazamiento en el anfitrión.
- Acciones y confirmaciones por canal fiable. La identidad viene del emisor RPC. Cada petición incluye número secuencial y ronda; se conservan respuestas recientes para no ejecutar duplicados y se rechazan secuencias antiguas.
- Estado de reglas, hojas y mundo a 10 Hz, además de las actualizaciones al confirmar acciones. Las revisiones antiguas se descartan. Se transmiten datos serializables, nunca referencias a nodos o recursos.
- Reserva de Seguridad por caso hasta recoger el resultado o vencer. Evidencias y Verificación confirman su resultado **antes** de liberar la estación. Reporte conserva el atasco y la herramienta hasta completarse o limpiarse el caso.
- Cafetera y expendedora tienen reservas independientes, pero compiten por el mismo saldo. Comprobación, descuento y entrega lógica ocurren juntos en el anfitrión.

## Verificación local

Motor utilizado: Godot 4.7 estable para Windows. Los registros quedan en `.godot/` y no se versionan.

| Prueba | Resultado de la integración |
| --- | --- |
| Protocolo individual | 1.300 comprobaciones, 0 errores. |
| Reglas LAN | 17 comprobaciones, 0 errores. |
| Dos procesos ENet | 111 comprobaciones, 0 errores y cierre limpio de ambos procesos. Incluye minijuegos reales, saldo, compras concurrentes, transferencia, herramientas dobles, exclusión de doble portador, colisiones en ambos equipos, seis eventos, reparaciones, poderes sin audio duplicado, eliminación, reinicio y desconexión. |
| Puntuación y clasificación individual | 88 comprobaciones, 0 errores. La prueba se adaptó a la selección Individual/LAN y a la espera real de la presentación. |
| Descanso y expendedora individual | 75 y 99 comprobaciones, 0 errores. |
| Final individual e integración de eventos | Pasaron. |
| Incendio, inundación, lava e hielo individuales | Pasaron. |
| Conexión | Pasaron el rechazo de versión incompatible y de una tercera conexión mientras la sala está ocupada. |
| Presentación LAN | Oficina de ambos jugadores inspeccionada con renderizado real: saldo compartido, dos corduras, caso local y alias/número legibles. |
| Menú LAN | Verificados IP inválida, creación, inicio bloqueado sin compañero, cierre y sesión nueva. Sala inspeccionada con renderizado real. |
| Terremoto individual | **13 fallos preexistentes reproducidos también en HEAD sin la implementación LAN**, en el mismo Godot 4.7: colisión de huecos, hoja lanzada y segundo inicio desde descanso. No se declara esta prueba aprobada. La prueba LAN comprueba igualdad del trazado, inicio y limpieza, pero no sustituye estos casos físicos. |
| Interacción de marcadores individual (15/11) | 118 comprobaciones, 23 fallos de alcance/interacción. Se reprodujeron los mismos 23 en una copia limpia de HEAD anterior a las herramientas dobles; no hay fallos adicionales en esta modificación. Registros: `qa_llaves_individual_fijo.log` y `qa_llaves_baseline.log`. |
| Modelo y gestos (15/11) | Llave inspeccionada con renderizado real. Gestos del policía e incendio individual: 0 errores de comprobación. |

La prueba automatizada opera dos procesos en un solo equipo. No representa latencia real entre equipos ni acredita una demostración con dos ejecutables exportados.

## Pendientes de aceptación de entrega

- Reproducir e investigar los fallos físicos preexistentes del terremoto; no ocultarlos cambiando sus aserciones.
- Instalar las plantillas de exportación correspondientes a Godot 4.7 y exportar Windows. No se encontraron plantillas instaladas en el equipo de implementación.
- Ejecutar la demostración en dos computadores de la misma LAN y registrar versión, IP, tiempos de respuesta y resultado. No se dispone de un segundo computador controlable en esta sesión.
- Recorrer manualmente todos los controles de reparación y poderes en ambos equipos, con pausas y eliminación durante cada interacción; las pruebas de RPC no sustituyen esa revisión visual completa.

Las instrucciones reproducibles y el guion de demostración están en [DEMOSTRACION_LAN.md](DEMOSTRACION_LAN.md).
