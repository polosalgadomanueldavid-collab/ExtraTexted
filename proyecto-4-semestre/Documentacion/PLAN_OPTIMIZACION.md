# Plan de optimización y auditoría de cargas

## Revisión de errores del 24 de noviembre de 2026

Verificación local con Godot **4.7.stable.official.5b4e0cb0f**, Windows y ejecución headless. Esta revisión no sustituye las mediciones gráficas históricas que aparecen debajo.

- Retiradas las impresiones de diagnóstico de la partida, las estaciones, el grafo y el cargador. Se conservan los errores y advertencias del depurador, así como los resultados de herramientas y pruebas.
- Corregidas la comprobación del método de interacción de estaciones, la acción de soltar papel ausente fuera del modo móvil y las notificaciones de cordura sin cambios.
- El terremoto reserva espacio para los derrumbes antes de agotar el suelo disponible, conserva los mínimos de grietas y escombros y admite los accesos de las dos herramientas LAN en sus posiciones normales. La prueba de barrera ya no reubica las herramientas para conseguir un plan válido.
- Las grietas ahora perforan la losa física. El personaje conserva su colisión al saltar; se retira la caída forzada que interrumpía el salto. La rotura también tolera cajones retirados durante el relevo.
- Actualizadas las pruebas que suponían preparación síncrona, cantidades fijas de cajones o valores de cordura anteriores. El cierre compartido detiene el audio y concede tiempo real al mezclador incluso con `--fixed-fps`.

La carga de los **270 scripts** termina sin errores. Pasan las comprobaciones de las **28 pruebas de regresión** de menús, despacho, eventos, personaje, descanso y partida. Se repiten las pruebas de terremoto tras ajustar la posición alternativa LAN. La suite LAN completa pasa **161 comprobaciones del anfitrión**, más cliente, sala y rechazo de conexiones; la barrera específica del terremoto pasa **27 comprobaciones** con las herramientas en su posición real. Se actualiza también la comprobación de accesorios de los personajes al acabado actual. Los registros están en `.godot/qa_general` y `.godot/qa_lan` (locales, no versionados). Estas cifras describen validación funcional headless, no una aceptación visual ni de rendimiento en dos equipos físicos.

**Aviso pendiente del cargador del motor:** `aislar_carga_threaded.gd -- --threaded` reproduce instancias `RefCounted` con contador cero al salir, sin instanciar la oficina; la misma prueba con `-- --sincrona` no deja ese aviso. Esperar al mezclador soluciona los errores de audio, pero no estas instancias. Se mantiene la carga asíncrona para evitar bloquear la interfaz. La reproducción está aislada; no se considera corregido este aviso ni se oculta la salida del motor.

## Registro previo

Actualización: 16 de noviembre de 2026, base `e57e652`. Estado: implementación parcial, ramas integradas y verificación adicional en Iris Xe. El diagnóstico original se conserva debajo como referencia histórica; sus descripciones de carga directa y barra al 90 % ya no describen el código actual. Detalles y limitaciones: [continuación del día 16](VERIFICACION_OPTIMIZACION_2026-11-16.md).

## Estado comprobado tras integrar las ramas

La optimización inicial está en `f6079ea` de `issa`. El merge `3cc52eb` incorpora `da5bc4d` (tutoriales LAN y skins por participante) y `5d29121` (nombre del proyecto) de `Barandica`. Se resolvieron los conflictos de `gestor_partida.gd` y `menu_global.gd` conservando la señal de disponibilidad, el cargador común, los modelos correctos y las confirmaciones compartidas de tutoriales.

| Prioridad | Implementado y comprobado por código | Pendiente de aceptación |
| --- | --- | --- |
| 0. Medidas | Tiempos por fase; perfil de CPU/física/GPU, cuadros, draw calls, memoria y nodos; cinco rondas; primera/segunda activación registrada; bytes reales ENet. | Exportación, caché fría de disco/shaders y sesión continua de 30 minutos. La ejecución larga tuvo una interrupción tras unos 28 minutos. |
| 1. Cargas | Decorado independiente; coordinador común; pool de 30 cajones; preparación progresiva; calentamiento visual; 100 % al terminar; barrera LAN posterior al primer cuadro. | Aún hay picos superiores a 100 ms. Las muestras de shaders no cubren todas sus variantes. |
| 2. Red/HUD | AVL incremental; caché de estaciones; HUD por cambios; snapshots diferenciales con recuperación completa; finales pendientes hasta acuse; canales separados. | Medición sostenida de tráfico, pérdida/reordenación, jitter y latencia en dos PCs/Hamachi. |
| 3. Render/recursos | Calidad visual, SubViewport visible, preparación de magma y nieve, partículas de Compatibility, tangentes de MarcoFoto, calentamiento de visión/luces reales del apagón. | Reducir los picos de generación y dibujo; resolver los avisos de RefCounted y el bloqueo de carga directa reproducido en headless. |
| 4. Aceptación | Pruebas de carga, recuperación, Hielo y LAN local; perfil gráfico en Iris Xe. | Dos ejecutables iguales en dos equipos; cumplir los umbrales de rendimiento y completar la resistencia sin interrupciones. |

Continuación de este lote:

- Carga idempotente, liberación de solicitudes abandonadas una vez completadas y retirada de oficinas parcialmente preparadas al cancelar o desconectar.
- Validación de ronda en inicio y movimiento remoto; rechazo de cambios de escena diferidos obsoletos; plazo de conexión monotónico. Protocolo `extratexted-lan-4`: ambos equipos deben actualizarse.
- Una sola barra durante la discusión. Se conserva el diálogo y la presentación del menú.
- Lectura de triángulos de nieve por presupuesto de 3 ms, con cursor dentro de cada superficie. Se excluyen modelos de SubViewports de interfaz. No se modifican física, daño, tiempos ni geometría de la nieve del mundo.
- La prueba de menú LAN detiene el MP3 antes de salir, igual que las otras pruebas, evitando un error de recurso todavía en uso por el mezclador.

### Evidencia de la continuación

Equipo real de esta revisión: AMD Ryzen 5 5600G con Radeon integrada, Godot **4.7.2**, Windows, Compatibility a 1280 × 720. Es un equipo diferente del Intel/Iris Xe de la auditoría original; las cifras no constituyen una comparación entre esos equipos.

- Antes de continuar, la prueba individual ya pasaba **22 comprobaciones**, alcanzaba 100 % y registró 2.425 ms desde confirmar hasta oficina y un intervalo máximo de 142 ms en headless. La optimización inicial sí estaba implementada.
- La suite LAN tras el merge pasó inicialmente **137 comprobaciones del anfitrión**. La suite final ampliada pasa **144 comprobaciones del anfitrión y 17 de reglas, sin errores**, además de verificaciones del cliente, menú, sala de dos procesos y rechazo de conexiones incompatibles/ocupadas. Incluye equipos lentos, rondas obsoletas y desconexión durante preparación.
- Recuperación: **49 comprobaciones, 0 errores**, cancelando en recursos, pool, entrada, preparación, render y listo; ruta inexistente, recurso que no es escena, plazo agotado, solicitudes repetidas, tres reentradas y retorno al menú.
- Hielo: prueba funcional sin errores, incluyendo nieve de cajones reciclados, rutas, reparación, pausa, restauración y segundo evento.
- Comparación de nieve con el generador de `f6079ea`: **65 mallas con geometría idéntica byte a byte, 0 diferencias**. Máximo de la llamada anterior: 54,3 ms; máximo de lectura por lote: 5,1 ms en 130 lotes. CPU total de la comparación: 262,6 ms antes / 259,5 ms después. El presupuesto es cooperativo; no es un límite duro. Se reparte el trabajo, sin prometer una reducción del tiempo total de entrada.

Los resultados finales reproducibles se registran en `Documentacion/RESULTADOS_OPTIMIZACION.md`. Los registros detallados permanecen en `.godot/qa_optimizacion`, `.godot/qa_lan`, `.godot/hielo_optimizacion.log` y `.godot/comparar_nieve.log` (locales, no versionados).

Para repetir el lote, desde la raíz, con `$Godot` apuntando a Godot 4.7.2:

```powershell
& proyecto-4-semestre/Pruebas/Menus/ejecutar_auditoria.ps1 -Godot $Godot
& proyecto-4-semestre/Pruebas/Multijugador/ejecutar_pruebas.ps1 -Godot $Godot
& $Godot --headless --path proyecto-4-semestre --script res://Pruebas/Hielo/prueba_hielo.gd --fixed-fps 60
```

`-SinRender` limita la primera orden a headless. Cada repetición de carga usa un proceso nuevo; no vacía cachés del SO ni de shaders. El perfil conserva cinco rondas, calidad alta y tres segundos por escenario, suficiente como diagnóstico breve, no como aceptación de una sesión larga.

## Objetivo

Reducir los bloqueos de entrada y los tirones durante eventos y sesiones largas, conservando estética, controles, dificultad, física, herramientas dobles, saldo compartido y sincronización. Priorizar Windows con gráfica integrada y Compatibility. No cambiar de renderizador ni reducir la frecuencia de la física sin mediciones comparables.

## ¿Las pantallas de carga cumplen su función?

**Parcialmente.** La individual prepara recursos y cajones, pero no garantiza una transición fluida ni representa toda la preparación. La LAN coordina a ambos equipos, pero no utiliza el flujo visual y progresivo de la individual.

| Recorrido | Comprobación | Veredicto |
| --- | --- | --- |
| Arranque → menú | `carga_inicial.gd` espera 0,35 s y ejecuta `load(MainMenu)` en el hilo principal. Solo muestra un fondo negro. | Oculta la transición; no mantiene una carga animada ni informa del trabajo. |
| Fondo del menú | `fondo_menu_oficina.gd` precarga e instancia `Oficina.tscn` completa; después elimina nodos y scripts para usarla de decoración. Mantiene un SubViewport actualizado continuamente y luces con sombras. | Dependencia pesada antes de la barra. El coste incluye recursos que el menú no necesita como lógica de juego. |
| Individual → oficina | `menu_global.gd` usa carga en segundo plano, comprueba su finalización antes de obtener el recurso, instancia en el hilo principal y prepara 30 cajones en lotes de tres. | Hay trabajo real, aunque buena parte de los recursos ya llega a la caché por el fondo del menú. Instanciar y ejecutar `_ready` todavía puede bloquear. |
| Barra individual | `MainMenu.gd` transforma el progreso del recurso al rango 0–90 y fija 90 al terminarlo. No representa lotes, inicialización, renderizado ni llegada a 100. | Información incompleta. No es una medida del tiempo restante. |
| Espera mínima | La discusión permanece al menos 2,5 s después de confirmar el nombre. | Decisión de presentación, independiente de cuánto tarde la carga; no debe confundirse con trabajo pendiente. |
| Crear/unirse LAN → oficina | `sesion_lan.gd::_cambiar_a_oficina()` usa `change_scene_to_file`, sin el cargador individual. La barrera espera las confirmaciones de ambos puentes. | Coordinación real; falta una pantalla persistente con progreso local y estado del compañero. |
| Preparación LAN | El gestor programa el pool de cajones con `call_deferred` y confirma el puente sin esperar explícitamente a terminar ese pool. | La confirmación no acredita toda la preparación. Debe depender de una señal de disponibilidad completa. |
| Reiniciar / volver al menú | Reinicio individual usa `reload_current_scene`; LAN vuelve al cambio directo y el regreso al menú usa carga directa. | Unificar también estos recorridos. |

`_ready` del gestor contiene una espera a física y luego crea eventos, interfaces y temporizadores. Entrar en el árbol o cambiar de escena no debe ser el único criterio de «listo». La carga tampoco incluye un calentamiento visual explícito de todos los efectos.

## Evidencia ejecutada

Equipo de referencia: Intel i5-1135G7, Iris Xe, aproximadamente 16 GB RAM; Godot 4.7 estable, Compatibility. Son dos ejecuciones diagnósticas en este equipo, con otros programas abiertos y recursos importados. No son un benchmark de ejecutable exportado, ni una prueba de caché de disco/GPU vacía.

| Medida | Sin renderizado | Con renderizado Windows, 1280 × 720 |
| --- | ---: | ---: |
| Mayor intervalo entre cuadros en arranque | 5.632 ms | 7.336 ms |
| Confirmar nombre → oficina | 3.372 ms | 3.332 ms |
| Mayor intervalo durante entrada individual | 866 ms | 821 ms |
| Máximo observado en la barra | 90 % | 90 % |
| Comprobaciones funcionales | 20 correctas, 0 fallos | 20 correctas, 0 fallos |

Los intervalos se miden con reloj monotónico entre señales `process_frame`; incluyen bloqueos y planificación del sistema, no son tiempos exclusivos de CPU/GPU ni FPS de juego. El arranque medido comienza después de inicializar los autoloads. El recorrido incluye abrir, cancelar y reabrir Individual antes de confirmar; no representa una primera entrada directa sin precarga previa.

La prueba anterior dio 9 fallos porque asumía que Jugar abría directamente el formulario. Ahora recorre Jugar → Individual, sin retirar sus aserciones de alias, cancelación, tutorial y cajones preparados. Los fallos antiguos de esta prueba no demostraban que el cargador estuviera roto.

Registros locales: `.godot/auditoria_prueba_carga.log` (prueba desactualizada), `auditoria_carga_actual.log`, `auditoria_carga_render.log` y `auditoria_carga_render.error.log`. Hay avisos de partículas no compatibles y tangentes ausentes en MarcoFoto durante el renderizado. No se atribuye una magnitud de coste a estos avisos sin perfilar.

La barrera LAN se revisó por código y cuenta con las pruebas previas de dos procesos (111 comprobaciones). No se volvió a medir una carga entre dos computadores ni por Hamachi en esta auditoría.

## Implementación por prioridades

### 0. Establecer medidas reproducibles

- Registrar arranque hasta primera imagen, menú interactivo, carga de recursos, instanciación, preparación, primer cuadro de oficina y habilitación de controles por separado.
- Medir tiempos de cuadro p50/p95/p99 y máximos, CPU/física/GPU, draw calls, nodos, partículas, memoria y bytes de red por segundo. Medir apertura de cada evento y poderes por primera y segunda vez.
- Repetir tres veces en procesos nuevos y tres entradas repetidas. Probar individual, anfitrión y cliente por separado; distinguir caché del motor, disco y shaders.
- Escenarios: menú, oficina tranquila, 30 cajones, cada uno de los seis eventos, ambos extintores, poderes, colisión y sesión LAN de 30 minutos con reinicios. Registrar resolución, calidad, versión, hardware y si es editor o exportación.
- Mantener identificados los fallos previos de interacción/terremoto; no cambiar aserciones para declarar una mejora.

Salida: tabla base por escenario y perfiles que permitan elegir entre coste CPU, GPU, carga y red. Objetivo provisional: 60 FPS a 720p en el equipo de referencia; p95 ≤ 16,7 ms y p99 ≤ 33,3 ms en juego. Ajustar el objetivo para el equipo más lento real tras medirlo, sin prometerlo como resultado actual.

### 1. Hacer que todas las cargas preparen de verdad

Archivos principales: `carga_inicial.gd`, `fondo_menu_oficina.gd`, `menu_global.gd`, `sesion_lan.gd`, `gestor_partida.gd`.

1. Separar una escena de decoración del menú con solo geometría visible y los dos policías; compartir recursos visuales con el juego sin depender de su gestor completo. Evitar instanciar la oficina entera para luego recortarla.
2. Crear un coordinador de carga común para Individual, LAN, reinicio y regreso al menú, con overlay persistente, presentación ligera y señales de fase/progreso/error. Evitar dos solicitudes concurrentes para la misma oficina.
3. Fases explícitas: recursos → instanciación → preparación de estaciones/eventos/interfaces → pool completo → primer render → listo. La instanciación y las mutaciones del árbol se mantienen en el hilo principal; repartir construcción procedural por presupuesto de 2–4 ms por cuadro, no solo por cantidad fija.
4. Mostrar progreso de trabajo medible por fase; usar indicador indeterminado donde no exista una medida real. La barra solo llega a 100 al completar la preparación. Conservar las frases; quitar la espera mínima obligatoria o permitir omitirla cuando esté listo.
5. Emitir `oficina_preparada` al terminar todo. En LAN cada equipo confirma su ronda después de esa señal; el anfitrión empieza tras ambas confirmaciones. Mostrar «Tu oficina está lista; esperando al compañero» sin fingir avance remoto.
6. Mantener ENet activo durante la preparación; usar plazos de reloj monotónico y cancelación asociada a la ronda, con limpieza de tareas/instancias y regreso controlado al menú. Un tiempo agotado no puede impedirse por una carga síncrona larga.
7. Preparar muestras visibles de materiales y efectos en una vista de calentamiento detrás del overlay, verificar su renderizado y retirarlas. Para Compatibility no asumir que cargar un shader o mantener una malla oculta elimina la primera compilación.

Salida: overlay dibujado antes del trabajo pesado; controles y relojes bloqueados hasta la disponibilidad completa; barra coherente y sin regresiones; ninguna fase de preparación provoca pausas de >100 ms en la máquina de referencia tras desacoplar recursos. Medir el arranque total: trasladar el coste a otra pantalla no cuenta como optimización.

### 2. Reducir trabajo continuo y tráfico LAN

Evidencias en `partida_lan.gd`: actualización de contexto/HUD cada cuadro; estado completo a 10 Hz; retransmisión acumulada de casos resueltos/vencidos; el cliente recrea AVL y denuncias en cada snapshot. `fila_calma_jugador.gd` solicita redibujado incluso cuando no cambia el valor.

- Conservar el AVL; actualizarlo incrementalmente por altas, cambios y bajas. Cachear estaciones por ID en vez de recorrer nodos en cada búsqueda.
- Actualizar cordura, alias, saldo, disponibilidad y textos por cambios; conservar animaciones activas con su frecuencia visual. Evitar restablecer colisiones/visibilidad idénticas cada cuadro.
- Enviar eventos discretos fiables una vez, con identificación, ronda y confirmación; snapshots completos solo al sincronizar y como recuperación periódica. Acotar el historial de deduplicación mediante acuses seguros.
- Separar movimiento y estado frecuente de acciones fiables para evitar que un historial creciente retrase compras o reparaciones. Mantener inicialmente los 20 Hz de movimiento; medir antes de cambiar frecuencias.
- Preservar autoridad del anfitrión, recompensas únicas, reservas y recuperación ante pérdida/reordenación. Ajustar suavizado solo después de medir latencia y jitter en Hamachi.

Salida: tamaño del estado periódico no crece con el historial de 30 minutos; menos asignaciones y tiempo CPU del cliente; pasan concurrencia, economía, pausas, eliminación y reconexión a una sesión nueva. Comparar bytes y latencia antes/después, no solo FPS.

### 3. Optimizar renderizado, eventos y recursos

- Perfilar primero el SubViewport del menú, sombras y resolución. Reducir su resolución o ritmo cuando no sea visible, conservando animaciones en primer plano.
- Revisar mallas/materiales repetidos y partículas de incendio. Ya existe malla compartida de llama: conservarla; evaluar materiales compartidos/MultiMesh para elementos compatibles sin fusionar objetos con colisión/interacción individual.
- Revisar actualización por llama y parámetros shader, overlays de nieve, agua, lava y efectos del Avatar. Separar simulación de presentación para que reducir partículas no altere daño, tiempos o reparaciones.
- Preparar/poolizar los efectos cuyo primer uso muestre picos. No reservar todos los efectos indiscriminadamente: comparar la memoria estable y el pico de entrada.
- Auditar recursos realmente referenciados, triángulos, superficies y texturas embebidas. Candidatos por tamaño fuente: expendedora 21,63 MiB; TacoLuz separado 13,93 MiB; Taco_Luz 11,54 MiB; cafetera 8,09 MiB. El tamaño de un GLB no mide por sí solo coste GPU ni demuestra que ambos tacos se carguen.
- Corregir tangentes requeridas y parámetros de partículas incompatibles. Definir ajustes visuales Bajo/Medio/Alto para sombras, partículas y resolución 3D; HUD legible a resolución nativa. No quitar eventos ni alterar la estética sin comparar capturas.

Salida: mejora medida del escenario que limitaba CPU/GPU y sin degradación visual no acordada. Cero crecimiento persistente de nodos/recursos entre cinco rondas equivalentes después del calentamiento.

### 4. Aceptación y entrega

- Carga: primer arranque, entrada repetida, cancelación, error de recurso, salir durante preparación, reinicio y retorno al menú. Inyectar fallo en una ruta de prueba sin romper recursos de producción.
- LAN: cliente lento, anfitrión lento, desconexión durante carga, rondas sucesivas y confirmaciones atrasadas. Ningún caso/reloj/control empieza antes de ambos listos.
- Jugabilidad: minijuegos, dos herramientas, colisiones, seis eventos, poderes, audio único, saldo, muerte, descanso y clasificación.
- Ejecutables iguales en dos PCs mediante LAN/Hamachi; comparar exportación con editor. Registrar latencia y rendimiento de cada equipo, no inferirlo de dos procesos locales.
- Entregar perfiles, tiempos antes/después, capturas comparativas y lista explícita de limitaciones. Implementar por lotes pequeños: primero carga y menú, después red/HUD, luego los efectos que el perfil señale.

## Cómo repetir la comprobación actual

Desde la raíz del repositorio, con `$Godot` apuntando al ejecutable de Godot 4.7:

```powershell
& $Godot --headless --path proyecto-4-semestre --script res://Pruebas/Menus/prueba_carga.gd
& $Godot --path proyecto-4-semestre --script res://Pruebas/Menus/prueba_carga.gd --rendering-method gl_compatibility -- --capturas
```

El segundo comando guarda `.godot/carga_discusion_qa.png`. Estas pruebas comprueban el comportamiento actual, no certifican todavía los criterios futuros de fluidez, recuperación ni carga LAN lenta.

## Referencias técnicas

- [Carga en segundo plano de Godot](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html): `load` bloquea; obtener un recurso threaded antes de terminar también puede bloquear.
- [API y seguridad entre hilos](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html): respetar las restricciones al manipular escenas y recursos compartidos.
- [Compilación de shaders y pipelines](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html): distinguir las posibilidades del renderizador Compatibility de las de Mobile/Forward+.
