# QA de marcadores de estaciones

Ejecuta `res://Pruebas/PruebaIndicadoresEstaciones.tscn` con F6 o por CLI:

```text
Godot --headless --path proyecto-4-semestre res://Pruebas/PruebaIndicadoresEstaciones.tscn
```

La prueba usa la oficina real y comprueba los cinco modelos distintos, ausencia
de colisiones/texto/aro/cono provisional, reconfiguración sin duplicados,
documento de reserva para IDs desconocidos y todas las transiciones de los seis
protocolos. También cubre estaciones incorrectas, cierre y vencimiento directos,
vencimiento de un caso pendiente, un único objetivo activo y pausa/reanudación.
Con la cámara original, proyecta los ocho vértices del AABB de cada malla para
comprobar que modelo y puntero completos caben en el 18% de alto de pantalla
(más 5 píxeles de tolerancia), quedan dentro de la vista y no invaden el HUD.
Termina con código 0 si pasa o 1 si registra errores.

Para guardar vistas de los cinco marcadores sobre sus estaciones, ejecuta sin
`--headless` y añade `-- --capturas`. Las imágenes quedan en
`proyecto-4-semestre/.godot/marcadores_estaciones_qa/`: `<id>.png` es una vista
de detalle y `<id>_jugando.png` usa la orientación original de la cámara de juego
con el jugador en la celda de aproximación de esa estación. Posiciones,
velocidad y procesamiento físico del jugador/cámara se restauran al terminar
cada captura; no se modifica la escena del juego.

`VistaMarcadores3D.tscn` es una galería independiente de las cinco mallas reales.
F6 permite verlas animadas sin abrir una partida. Por CLI, `-- --capturas`
guarda `.godot/marcadores_qa/00_galeria_3d.png` y termina; la captura se realiza
con el renderizador de Godot.

Añadir `--interactuables` activa el pulso y el contorno de los cinco objetos
en la galería. Con `-- --capturas --interactuables` guarda
`.godot/marcadores_qa/01_galeria_interactuable.png` para comparar su brillo
con la vista normal sin modificar una partida.

## Disponibilidad real de interacción

Ejecuta `PruebaInteraccionMarcadores.tscn` con F6 o por CLI:

```text
Godot --headless --path proyecto-4-semestre res://Pruebas/MarcadoresEstaciones/PruebaInteraccionMarcadores.tscn
```

Esta prueba instancia la oficina y deja aterrizar al policía sobre su suelo
real. Luego mueve y orienta al personaje para consultar el `ShapeCast3D` que
ya usa la tecla E: no sustituye sus colisiones por una distancia calculada.
Comprueba entrada, salida, reentrada, mirar en sentido opuesto estando en el
mismo lugar, estación incorrecta, bloqueo de entrada, uso del computador y
pausa. También pulsa E para resolver protocolos en mesas distintas, comprueba el
apagado al vencer y al reconfigurar, y verifica que el pulso no modifique los
materiales de otros marcadores ni añada colisiones o sombras.

Ejecutar sin `--headless` y añadir `-- --capturas` guarda tres imágenes
(`01_fuera_de_alcance.png`, `02_dentro_de_alcance.png`, `03_al_salir.png`) en
`.godot/interaccion_marcadores_qa/`, usando la cámara original de la oficina.
