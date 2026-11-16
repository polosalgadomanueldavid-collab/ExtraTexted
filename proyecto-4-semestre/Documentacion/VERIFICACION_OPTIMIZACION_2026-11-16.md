# Continuación de la optimización — 16 de noviembre de 2026

Base: `e57e652`, rama `issa`, incluyendo la actualización de `Barandica` (`d5c494a`). No se sustituyeron los cambios de skins, tutorial compartido ni reglas LAN. Equipo de esta ejecución: Intel i5-1135G7, Iris Xe, Windows, Godot 4.7 stable `5b4e0cb0f`, Compatibility, 1280 × 720, calidad alta. El usuario detuvo su partida; el editor permaneció abierto.

## Cambios entregados

- MarcoFoto usa una malla con tangentes. El generador conserva posiciones, índices, materiales y LOD; no recalcula normales por cara. La comparación con ambos modelos intercambiando posiciones conserva el aspecto. Se regeneró el decorado del menú para usar el mismo recurso. Las pruebas con renderizado ya no emiten el aviso de tangentes ausentes.
- El calentamiento de la carga ahora dibuja también el shader de visión del apagón como `canvas_item` y la oficina con sus luces de emergencia reales detrás del overlay. Restaura luces y máscara antes de jugar, sin activar el evento ni su audio. Antes solo dibujaba muestras de shaders espaciales. No garantiza todas las combinaciones de luces, geometría y materiales.
- El perfil repite eventos y poderes y registra si realmente se activaron. Una distribución de terremoto rechazada no debe interpretarse como una segunda activación fluida. El perfil abandona con error si una carga no termina, en vez de quedarse esperando una señal indefinidamente.
- Se añadió una prueba de resistencia con dos procesos ENet, casos repetidos, reinicios, bytes reales del transporte, historial pendiente, nodos, objetos y memoria; incluye un ejecutor reproducible.
- Se añadió un diagnóstico mínimo de carga síncrona/frente a carga en segundo plano sin instanciar la oficina, para investigar los avisos de recursos al salir.

## Carga y recuperación

Pasaron 23 comprobaciones de carga individual tanto en headless como con renderizado; también pasaron 49 de recuperación en cada modo. Se verifican 100 %, oficina preparada antes de habilitar controles, cancelación por fase, errores, plazo, solicitudes duplicadas, reentradas, retirada de oficinas canceladas y restauración de la visión tras el calentamiento.

La regresión LAN completa volvió a pasar: **144 comprobaciones de partida y 17 de reglas**, además de menú, sala con dos procesos, versión incompatible, sala llena y desconexiones durante preparación. No hubo errores de scripts en ese lote.

La pantalla de carga sí prepara recursos, cajones, estaciones, nieve y primera imagen. En LAN mantiene la barrera de ambos equipos. **Eso no elimina el trabajo que algunos eventos todavía generan al activarse.**

En dos perfiles headless que entraban directamente desde el menú, la carga de la oficina se quedó al 5,625 % hasta vencer el plazo. El recorrido del formulario y las pruebas de recuperación sí terminaron; el perfil con renderizado completó cinco entradas. No se oculta esta incidencia ni se cambia la prueba para hacerla pasar. Los errores de dependencias mostrados al cerrar el proceso bloqueado no prueban por sí solos que esos archivos estén dañados.

## Recursos al salir

La carga en segundo plano de la oficina sin instanciarla reprodujo 57–58 avisos de `RefCounted` al salir. La carga síncrona del mismo recurso no los reprodujo. En pruebas completas se observaron 60–61. Esto acota la investigación al proceso de carga/compilación y sus referencias; no demuestra una fuga creciente por ronda ni identifica por sí solo un fallo concreto del motor.

No se cambió toda la carga a síncrona: la alternativa ensayada eliminaba los avisos, pero introducía compilaciones de scripts de más de 500 ms en el hilo principal. El diagnóstico queda reproducible:

```powershell
& $Godot --headless --path proyecto-4-semestre --script res://Pruebas/Menus/aislar_carga_threaded.gd -- --sincrona
& $Godot --headless --path proyecto-4-semestre --script res://Pruebas/Menus/aislar_carga_threaded.gd -- --threaded
```

## Perfil final con renderizado

Medición final sin procesos LAN concurrentes, tres segundos por escenario y al menos 4,5 segundos por poder. Ventana de 1280 × 720, calidad alta, editor abierto y cachés sin limpiar. Son intervalos entre cuadros; una muestra corta no certifica todos los recorridos ni separa por sí sola CPU y GPU. Las comparaciones visuales no sustituyen una medida con caché fría.

| Escenario | p95 (ms) | Máximo (ms) |
| --- | ---: | ---: |
| Menú | 17,27 | 17,91 |
| Oficina inicial | 17,29 | 17,66 |
| Apagón, primera activación | 17,41 | 156,21 |
| Apagón, segunda activación | 17,26 | 17,60 |
| Terremoto, primera activación | 17,24 | 480,85 |
| Incendio | 17,78 | 29,69 |
| Inundación | 19,69 | 30,06 |
| Lava | 17,58 | 130,60 |
| Hielo | 18,07 | 30,50 |
| Chocolate | 17,30 | 17,95 |
| Dona | 17,38 | 17,92 |
| Papa tiempo | 17,22 | 25,04 |
| Avatar de agua | 17,26 | 17,79 |
| Quinta oficina | 17,17 | 17,56 |

Los cuatro poderes se activaron en ambas pasadas. El segundo intento de terremoto **no encontró una distribución válida** y consumió unos 598 ms; el JSON lo marca con `terremoto_segunda_activado: false`. No se presenta como una segunda ejecución válida del evento. Avatar se midió con agua; faltan perfiles gráficos de sus otros elementos y de la rotura completa del suelo del terremoto, que ocurre después de esta ventana corta.

Las cinco oficinas tuvieron 2.026 nodos. Primera carga de oficina: 5.428 ms; reentradas: 2.397–3.777 ms. La barra llega al 100 % tras la preparación, pero los picos posteriores de apagón, terremoto y lava siguen superando 100 ms. No se declara cumplido el objetivo provisional de p95 ≤ 16,7 ms.

Datos completos: [perfil_rendimiento.json](Mediciones/2026-11-16/perfil_rendimiento.json). Las capturas locales `.godot/perfil_oficina_4.png` y la comparación de marcos fueron inspeccionadas.

## Resistencia y tráfico LAN

La ejecución larga llegó a 1.684 segundos (unos 28 minutos) con seis rondas, y después registró un salto hasta 4.133 segundos. La conexión terminó tras esa interrupción. Se conserva como evidencia incompleta en [resistencia_interrumpida.json](Mediciones/2026-11-16/resistencia_interrumpida.json), **no como aprobación de 30 minutos continuos**.

En el tramo activo hubo 2.256 nodos en ambos procesos. Tras el calentamiento, el anfitrión mantuvo 7.624 objetos y el cliente 7.599. El historial de finales pendientes se mantuvo en 1 en el anfitrión y 0 en el cliente; no creció con el número de casos. El tráfico estable fue aproximadamente 17,3 kB/s de salida del anfitrión y 6,7 kB/s de entrada, incluidos ENet y movimiento. No hay una línea base equivalente para afirmar una reducción porcentual.

Se corrigió el propio instrumento: conserva el lado del proceso aunque se cierre la sesión, detecta intervalos de muestreo mayores de 30 segundos y exige el acuse final del cliente. La repetición de **120 segundos, seis rondas y 207 casos** terminó con cero errores en ambos procesos y saldo/secuencia final coincidentes. Datos: [anfitrión](Mediciones/2026-11-16/resistencia_120s_host.json), [cliente](Mediciones/2026-11-16/resistencia_120s_client.json).

## Criterios aún abiertos

No se certifica fluidez constante ni p95 de 16,7 ms. Persisten costes de generación de terremoto/lava y picos de dibujo de eventos. Dos alternativas ensayadas para las rutas/contactos del terremoto conservaron la geometría, pero no mejoraron los tiempos de manera consistente y se retiraron.

La sesión local no sustituye una prueba en dos computadores por Hamachi, una exportación idéntica, ni una prueba con pérdida/reordenación de paquetes inducida. No había plantillas de exportación instaladas. Tampoco se atribuyen mejoras al calentamiento comparando procesos con distintas cachés de shaders.

## Repetición

Cerrar otras partidas antes de medir gráficos; no ejecutar la suite LAN normal simultáneamente con la prueba de resistencia, porque ambas usan UDP 7000.

```powershell
& proyecto-4-semestre/Pruebas/Multijugador/ejecutar_resistencia.ps1 -Godot $Godot -Segundos 1800
& $Godot --path proyecto-4-semestre --script res://Pruebas/Menus/perfil_rendimiento.gd -- --segundos=10 --rondas=5 --calidad=2
```

Los JSON se escriben en `.godot/perfil_rendimiento.json` y `.godot/resistencia_host.json` / `resistencia_client.json`. Los registros guardados para esta entrega están en [Mediciones/2026-11-16](Mediciones/2026-11-16).
