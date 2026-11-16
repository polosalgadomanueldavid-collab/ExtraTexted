# Plan de optimización y auditoría de cargas

Fecha: 15 de noviembre de 2026. Estado: revisión terminada; optimizaciones propuestas, todavía sin implementar. Se actualizó únicamente la prueba de carga para recorrer el menú actual y registrar tiempos.

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
