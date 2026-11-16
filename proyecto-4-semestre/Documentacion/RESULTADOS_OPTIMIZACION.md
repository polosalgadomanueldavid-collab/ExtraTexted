# Verificación de optimización e integración

15 de noviembre de 2026. Rama `issa`, merge `3cc52eb` con los commits `da5bc4d` y `5d29121` de `Barandica`. Las mediciones corresponden al árbol de trabajo posterior a ese merge.

## Resultado funcional

- Carga individual: 22 comprobaciones correctas en cada una de seis ejecuciones (tres headless y tres con renderizado).
- Recuperación: 49 comprobaciones correctas en headless y 49 con renderizado. Incluye cancelación durante seis fases, recursos inválidos, plazo vencido, solicitudes duplicadas, tres reentradas y retorno al menú.
- Hielo: 41 comprobaciones correctas. La geometría del nuevo generador coincide byte a byte con la anterior en las 65 mallas del mundo comparadas.
- LAN: **144 comprobaciones del anfitrión y 17 de reglas, sin errores**; también pasan cliente, menú, sala real con dos procesos, versión incompatible y sala llena. Conserva tutoriales con confirmación de ambos, skins por participante, herramientas dobles, economía compartida, colisiones, poderes, eventos y reinicios. Comprueba cliente lento, anfitrión lento, mensajes de rondas anteriores y recuperación de ambos menús tras desconectar durante preparación.

El protocolo pasa a `extratexted-lan-4`; ambos equipos deben ejecutar la misma versión. Las pruebas usan dos procesos locales, no dos computadores ni Hamachi.

## Entorno y alcance de las medidas

AMD Ryzen 5 5600G, Radeon integrada, Windows, Godot 4.7.2, Compatibility/OpenGL 3.3, 1280 × 720, calidad alta. Procesos del motor con scripts, sin exportar. Ventanas de prueba lanzadas mediante `Start-Process -WindowStyle Hidden`; no se controla el refresco/compositor de Windows ni la actividad de otros programas. El perfil observado ronda 30 cuadros/s; no se atribuye ese límite exclusivamente a CPU o GPU.

Los procesos de rendimiento se ejecutaron secuencialmente, separados de la suite LAN. Los recursos estaban importados. Un proceso nuevo limpia la caché del motor, pero no la de disco o shaders. No se compara directamente con el equipo Intel/Iris Xe del plan original.

## Carga: tres procesos nuevos por modo

Intervalos entre señales `process_frame`, en milisegundos. «Entrada» abarca confirmar nombre, preparación completa, calentamiento y disponibilidad; el recorrido abre, cancela y reabre el formulario antes de confirmar.

| Modo / ejecución | Confirmar → oficina | Mayor intervalo de arranque | Mayor intervalo de entrada | Barra final |
| --- | ---: | ---: | ---: | ---: |
| Headless 1 | 3508,936 | 51,438 | 160,224 | 100 % |
| Headless 2 | 2185,835 | 23,285 | 114,282 | 100 % |
| Headless 3 | 2249,718 | 22,860 | 108,644 | 100 % |
| Render 1 | 5628,825 | 138,640 | 197,042 | 100 % |
| Render 2 | 5542,868 | 115,863 | 194,806 | 100 % |
| Render 3 | 5751,743 | 114,780 | 195,113 | 100 % |

Datos: [cargas.json](Mediciones/2026-11-15/cargas.json). Cada registro de consola contiene además los tiempos por fase. La medición inicial aislada antes de este lote fue 2424,686 ms / 141,750 ms en headless; no es una línea base de tres repeticiones comparables. **No se afirma una reducción global del tiempo de carga.**

## Preparación de nieve

Comparación con el script original de `f6079ea` sobre las mismas mallas y transformaciones, en el mismo proceso:

| Medida | Anterior | Continuación |
| --- | ---: | ---: |
| CPU acumulada para preparar las mallas comparadas | 262,585 ms | 259,513 ms |
| Mayor llamada anterior / mayor lote de lectura actual | 54,335 ms | 5,089 ms |
| Geometrías diferentes | — | 0 de 65 |

La segunda fila compara distintas unidades de trabajo: una llamada completa anterior y un lote de lectura actual. No mide toda la preparación de un mueble ni el tiempo total de un cuadro. Hubo 130 lotes; el presupuesto de 3 ms es cooperativo, no un límite duro. Los modelos auxiliares de SubViewports ya no reciben nieve. Repartir trabajo puede aumentar la duración total de la pantalla de carga, especialmente con pocos cuadros por segundo.

## Perfil de cuadros y cinco rondas

Tres segundos de muestreo por escenario; todos los tiempos están en ms. Las aperturas de eventos pueden aparecer en el máximo. Los percentiles de una muestra tan breve son diagnósticos.

| Escenario | p50 | p95 | p99 | Máximo |
| --- | ---: | ---: | ---: | ---: |
| Menú | 31,14 | 31,75 | 32,01 | 32,20 |
| Oficina inicial | 33,85 | 35,15 | 35,83 | 35,97 |
| Apagón | 32,27 | 33,79 | 160,25 | 173,01 |
| Terremoto | 32,19 | 33,37 | 33,97 | 348,98 |
| Incendio | 33,53 | 34,90 | 54,87 | 116,89 |
| Inundación | 33,76 | 35,25 | 51,54 | 117,02 |
| Lava | 32,25 | 32,99 | 33,76 | 143,08 |
| Hielo | 36,83 | 38,84 | 39,36 | 147,82 |
| Oficina, quinta ronda | 34,31 | 35,84 | 36,31 | 36,52 |

Las cinco oficinas estabilizaron **2025 nodos**. Tras la primera pasada de eventos, las rondas 2–5 conservaron aproximadamente **420,71 MiB de VRAM**; la memoria estática pasó de **184,98 a 185,01 MiB**. Esto no certifica ausencia de fugas en una sesión de 30 minutos. Persisten avisos de 59–60 instancias `RefCounted` al salir y de tangentes ausentes en MarcoFoto, ya presentes antes de este lote.

Datos completos de fases, memoria, GPU, física y draw calls: [perfil_rendimiento.json](Mediciones/2026-11-15/perfil_rendimiento.json). Capturas locales inspeccionadas: `.godot/carga_discusion_qa.png` y `.godot/perfil_hielo.png`.

## Siguiente lote necesario

1. Perfilar las operaciones restantes de inicialización y apertura de eventos: aún hay cuadros superiores a 100 ms y no se alcanza el objetivo provisional de 60 FPS en esta ejecución.
2. Corregir las tangentes de MarcoFoto sin perder su material; localizar el origen de los avisos de RefCounted y repetir pruebas de recursos tras calentamiento.
3. Medir bytes ENet, acciones fiables y recuperación bajo pérdida/reordenación durante 30 minutos; medir la primera y segunda apertura de efectos/poderes.
4. Validar una exportación idéntica en dos equipos reales y en el equipo Iris Xe de referencia.

Reproducción y estado completo: [PLAN_OPTIMIZACION.md](PLAN_OPTIMIZACION.md).
