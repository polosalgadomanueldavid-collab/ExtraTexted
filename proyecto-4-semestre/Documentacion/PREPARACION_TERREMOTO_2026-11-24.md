# Preparación incremental del terremoto

Estado posterior: la [revisión de cierre](CIERRE_TERREMOTO_Y_RADIO_2026-11-24.md) verifica de nuevo los fallos físicos y las ocho distribuciones LAN con sus accesos reales, y sustituye los booleanos durante la partida por un piso preparado. Las limitaciones descritas abajo corresponden a esta revisión anterior.

Implementa la primera prioridad de `VERIFICACION_RENDIMIENTO_2026-11-23.md`. La apertura CSG, sus contornos, paredes, losas y colisiones no se modifican.

## Flujo

`evento_terremoto.iniciar()` acepta una solicitud y regresa sin buscar distribuciones ni construir escombros. `preparando` reserva el evento; otros eventos y cambios de cajones esperan. Su reloj conserva el tiempo restante desde la solicitud; un rechazo restaura su estado de pausa anterior. `preparacion_terminada(correcta)` comunica el resultado. Una solicitud aceptada todavía puede terminar rechazada.

`planificador_terremoto.gd` trabaja con una copia de la ocupación y adyacencia del grafo, posiciones capturadas, un RNG y un AStar propios. `forma_grieta.gd` contiene los contornos y las consultas geométricas, sin nodos ni recursos gráficos. Se conserva el algoritmo de hasta 32 distribuciones, sus mínimos, accesos protegidos, separación entre bordes y anchos de salto.

`presupuesto_preparacion.gd` cede a `process_frame` al alcanzar 3000 microsegundos. Los puntos de cesión están dentro de las búsquedas de candidatas y caminos, en la selección de escombros y entre las piezas del montaje visual. Se reserva margen antes de la validación final, que comprueba todos los accesos mediante un recorrido del grafo. Las piezas parciales permanecen ocultas y su eliminación se difiere para respetar los callbacks del árbol. El presupuesto es cooperativo: una operación individual del motor y las interrupciones del sistema pueden superar el límite; no es una garantía de tiempo total de cuadro. Los materiales de roca y metal de los escombros se comparten. Las mutaciones del árbol y los recursos gráficos permanecen en el hilo principal.

Antes del montaje y de la autorización se comprueban las posiciones actuales, las hojas, las huellas de derrumbe, la ocupación del grafo y las rutas a los accesos que estaban conectados. La gigante conserva la excepción de abrirse bajo los pies después del aviso. Si cambia el contexto durante el montaje, se descarta y se intenta planificar de nuevo hasta tres veces. El rechazo o la cancelación retiran lo preparado y permiten reintentar.

El aviso, el sonido y el reloj empiezan al autorizar el montaje completo. Se conservan aviso de ocho segundos, ruptura en el segundo ocho, recuperación desde el dieciséis, cierre en el veinticuatro y las mismas oleadas de derrumbes. La preparación respeta la pausa.

## LAN

El protocolo pasa a `extratexted-lan-6`; ambos equipos deben actualizarse. El anfitrión publica los bytes del plan validado con un identificador y una huella. Los clientes importan esos datos y usan el estado de RNG visual recibido; no sortean otra distribución. Cada cliente confirma el montaje de ese plan. El anfitrión espera todos los acuses, vuelve a validar las posiciones actuales y autoriza el inicio mediante un mensaje separado. Los acuses de otro plan no liberan la barrera. Una cancelación se difunde y la espera tiene un límite de treinta segundos sin pausa.

## Verificación

`Pruebas/Terremoto/prueba_preparacion_terremoto.gd` cubre cesión entre cuadros, pausa, rechazo de solicitudes simultáneas, validación de posiciones y hojas nuevas, cambios del grafo, montaje importado idéntico, autorización, cancelación inmediata y durante el montaje, y salida de escena durante la preparación.

`Pruebas/Multijugador/prueba_lan.gd -- --host --solo-terremoto` y su proceso `--client --solo-terremoto` comprueban la barrera con dos instancias ENet, acuses incorrectos o antiguos, cancelación por movimiento y autorización después de una pausa. La prueba específica de barrera pasa 27 comprobaciones. Su fixture reubica las herramientas de reporte y sus accesos junto a los extintores: la disposición LAN original no produjo una distribución válida para las ocho semillas ensayadas, por sus accesos adicionales. El juego conserva esa disposición y su validación. Ejecutar los dos procesos con acceso a UDP localhost. Ambos procesos de la pasada final terminaron con código 0, sin errores de scripts ni del motor; quedaron advertencias de 77 y 74 instancias ObjectDB al salir. En pasadas anteriores también hubo errores de carga al volver al menú, ajenos a las aserciones de la barrera.

Las regresiones existentes esperan ahora el resultado de preparación antes de consultar grietas o escombros. Los instrumentos `perfil_rendimiento.gd` y `comparar_tirones.gd` incluyen los cuadros de preparación en sus muestras, registran su duración aparte y distinguen aceptación de solicitud de activación real.

La prueba final de preparación devuelve cero errores. En esa ejecución funcional headless, la solicitud tardó 41 µs y se repartió el trabajo en 215 lotes: media de 3,04 ms, dos lotes por encima de 4 ms y máximo de 5,42 ms. La validación final independiente tardó 3,20 ms. Son observaciones diagnósticas de esa ejecución, con otras aplicaciones abiertas; no garantizan un límite estricto ni una mejora gráfica.

La comprobación headless completa de terremoto conserva trece fallos que también se reproducen en la revisión original `2c56b7a`: diez consultas sobre los huecos CSG, dos comprobaciones de hoja lanzada y el segundo inicio mediante F3/T, además de avisos de una acción InputMap ausente. La regresión de escombros conserva el rechazo de la semilla 45 con hoja protegida, también presente en esa revisión. No se modifican estas condiciones en esta tarea. Los registros locales están en `.godot/qa_preparacion/`.

La prueba funcional headless no certifica una mejora de FPS ni reemplaza una medición gráfica o una sesión LAN entre dos equipos físicos.
