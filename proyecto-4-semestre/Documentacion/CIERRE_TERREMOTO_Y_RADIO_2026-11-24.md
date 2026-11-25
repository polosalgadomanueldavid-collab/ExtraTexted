# Terremoto y radio cooperativa

Revisión del 24 de noviembre de 2026. Godot 4.7 estable, GL Compatibility.

## Distribución real y fallos históricos

La revisión inicial de esta tarea ejecutó la prueba completa del terremoto antes de modificar producción: **0 errores**. También pasó la barrera LAN existente: **27 comprobaciones, 0 fallos**, sin reubicar las herramientas. Por tanto, los trece fallos y la limitación de las ocho semillas registrados en `PREPARACION_TERREMOTO_2026-11-24.md` no se reprodujeron en el árbol actual. Esta revisión actualiza su estado; no atribuye su desaparición a cambios posteriores.

La prueba LAN se amplió con las ocho semillas originales: 8762, 14, 927, 951, 1307, 2026, 13 y 114. Utiliza los jugadores, los cajones, las herramientas y todos los accesos de la oficina real. Comprueba preparación válida, al menos diez grietas y catorce escombros, validación final de rutas y posiciones, y que herramientas y accesos no se hayan movido. Después prueba la barrera, los acuses incorrectos, la cancelación y la pausa. Resultado: **70 comprobaciones, 0 fallos** con dos procesos ENet.

## Piso preparado y restauración

`Eventos/Terremoto/piso_preparado.gd` conserva la malla CSG intacta como decoración y prepara su colisión de caja al cargar la oficina. Durante la preparación del plan construye la superficie fracturada y su colisión triangular usando los contornos exteriores exactos de las grietas. El barrido por las coordenadas Z de cada vértice produce trapecios de suelo firme; las caras del dibujo y la colisión son las mismas. El montaje respeta el presupuesto cooperativo y la cancelación.

Abrir el suelo intercambia visibilidad y capas físicas. La oficina no añade ni retira operandos CSG durante el terremoto. Se conservan las paredes, biseles, losas, efectos, anchos de salto, avisos, duración y protección de accesos. La función aislada `grieta.abrir()` mantiene su variante CSG para la prueba de bordes; la oficina solicita explícitamente la variante preparada.

Cada grieta prepara también una tapa con el mismo contorno y material del piso. Al llegar el frente del Avatar al 82 %, se activa su dibujo y colisión y se ocultan las losas ya reunidas, evitando superficies coplanares. Las otras bocas siguen abiertas. Al finalizar, se activa la caja intacta y se retiran las piezas preparadas. No se reconstruyen booleanos ni máscaras por cada grieta sellada y no se cambia de material opaco a transparente durante el cierre.

`prueba_restauracion_suelo.gd` comprueba conservación del área del piso, ausencia de colisiones invisibles, apoyo real sobre una tapa, normal hacia arriba, otra boca aún abierta, sellado único, pausa y limpieza. Pasó con cero errores tanto en headless como con renderizado: 23 y 24 comprobaciones en las ejecuciones registradas, según la cantidad de grietas del plan. También se volvieron a ejecutar las pruebas completas de terremoto, escombros y preparación, con cero errores.

## Medición gráfica

Comparación secuencial en Intel Iris Xe, calidad alta, calentamiento visual y el mismo perfil de Tierra, a 1280 × 720. Cada ejecución arranca una oficina nueva y confirma diez grietas abiertas y restauración completa. Son observaciones locales de una pasada por condición, no una garantía de FPS o de rendimiento en otro equipo.

| Restauración del terremoto | Antes | Piso preparado |
| --- | ---: | ---: |
| Cuadro máximo | 459,449 ms | 41,820 ms |
| Cuadros por encima de 100 ms | 1 | 0 |
| Cuadros por encima de 50 ms | 1 | 0 |
| Cuadro p95 | 7,795 ms | 10,621 ms |
| FPS medios del escenario | 148,6 | 127,9 |
| Llamadas de dibujo máximas | 409 | 368 |

La mejora observada corresponde al pico de restauración. El promedio y el p95 no mejoraron en esta comparación; no se declara una mejora general de FPS. Una primera pasada del piso preparado registró 45,545 ms de máximo y la comprobación final 41,820 ms, ambas sin cuadros superiores a 50 ms durante la restauración. Los registros locales son `.godot/qa_cierre_tierra_base.json`, `.godot/qa_cierre_tierra_final.json`, `.godot/qa_cierre_tierra_final_repetida.json` y sus archivos `.log`.

## Radio LAN

El protocolo es ahora **extratexted-lan-7**; ambos equipos deben usar la misma versión.

- Abrir/cerrar con **R**, con **B** en mando durante el juego LAN, o con el botón **RADIO** en pantalla. **Start** conserva la pausa. Dentro de los paneles, B conserva la función de volver.
- Elegir con clic, foco y confirmación del mando o las teclas numéricas. Escape cierra sin pausar. El selector de estaciones ofrece Computador, Evidencias, Verificación, Seguridad, Reporte y Bienestar.
- Las cuatro señales son **marcar estación**, **necesito ayuda**, **recoge esta hoja** y **voy a reparar**. Una hoja requiere estar suelta y a 2,5 m como máximo del emisor. Reparar señala el objeto de la emergencia actual; en incendio señala el foco encendido más cercano.
- El anfitrión valida al emisor, la ronda, la pausa, las opciones y un intervalo de dos segundos por jugador. Los clientes no eligen coordenadas ni textos arbitrarios.
- Ambos jugadores reciben un marcador con alias, símbolo, texto, dirección y sonido breve en el bus Interacciones. Cada jugador conserva como máximo una señal; dura seis segundos y su reloj respeta la pausa. Ayuda sigue al emisor y Hoja sigue al expediente mientras continúe suelto.
- La radio no pausa el mundo. Mientras se elige una opción, el personaje conserva su física y se suspende su entrada de movimiento y acciones. Cerrar, pausar, finalizar o salir de escena retira el selector y libera ese estado.

Las pruebas de radio usan dos procesos y cubren envío en ambos sentidos, posición autoritativa, enfriamientos independientes, opciones inválidas, hoja cercana, mensajes de otra ronda, entrada R/Escape y B, confirmación sin salto accidental, pausa, reparación, caducidad y eliminación. Resultado final con anfitrión gráfico y cliente headless: **38 comprobaciones, 0 fallos**. La revisión visual incluye el selector y el marcador dentro de la oficina real. Las entradas de mando se sintetizan; no certifican un mando físico conectado.

La regresión LAN completa pasó **161 comprobaciones con cero errores**, incluyendo los seis eventos, reparación y Avatar, herramientas, eliminación, final, reinicio y desconexión durante carga. También pasaron Lava, Hielo, Inundación y el manual de controles en cuatro tamaños de pantalla. El conductor espera ahora el final real del fundido gráfico antes de comprobar la barrera de carga.

## Reproducir

Desde la raíz del proyecto Godot:

```text
--headless --fixed-fps 60 --script res://Pruebas/Terremoto/prueba_terremoto.gd
--headless --fixed-fps 60 --script res://Pruebas/Terremoto/prueba_escombros.gd
--headless --fixed-fps 60 --script res://Pruebas/Terremoto/prueba_preparacion_terremoto.gd
--headless --fixed-fps 60 --script res://Pruebas/Terremoto/prueba_restauracion_suelo.gd
--script res://Pruebas/ZonaDescanso/perfil_tierra.gd -- --calidad=2 --calentamiento --reporte=res://.godot/qa_cierre_tierra_final.json
```

Para LAN, abrir un proceso con `--script res://Pruebas/Multijugador/prueba_lan.gd -- --host --solo-terremoto` y otro con `--client --solo-terremoto`. Sustituir `--solo-terremoto` por `--solo-senales` para la radio. Omitir `--headless` y añadir `--capturas` al anfitrión para guardar imágenes. El test de restauración también admite `--capturas`.

La verificación LAN usa dos procesos en el mismo computador. No sustituye una sesión con dos equipos físicos ni una prueba de exportación. Persisten advertencias ObjectDB al salir de algunas pruebas LAN, también presentes en la referencia anterior; no se consideran un cierre limpio certificado del motor.
