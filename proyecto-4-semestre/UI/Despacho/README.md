# Barra lateral de denuncias

HUD exclusivo de `res://UI/PanelDespacho.tscn`: fondo general transparente,
tarjetas crema compactas, acentos laterales por riesgo y fuente Luckiest Guy
reutilizada del menú. No modifica el despacho, el AVL, las estaciones ni los menús.

- La tarjeta **PUNTOS** permanece visible aunque no haya casos. Muestra el saldo
  de la partida, separadores de miles y un aviso `+N PTS` durante tres segundos
  después de obtener una recompensa; el aviso se congela con la pausa.
- La tarjeta del caso activo muestra su recompensa prevista **AL RESOLVER**.
  Por defecto corresponde a 100 puntos por nivel de riesgo (100 a 500); un valor
  positivo en `Denuncia.puntaje_recompensa` permite ajustar un caso concreto.
- El saldo se consulta en `SistemaDespacho.puntuacion.puntos` y se actualiza
  mediante su señal `puntos_actualizados`. Cada nueva oficina crea su propio
  sistema, con saldo inicial cero. El HUD también admite cambiar de sistema
  sin conservar conexiones o avisos de la partida anterior.
- El reloj activo vacía la arena según `tiempo_restante / tiempo_limite_segundos`.
  El flujo de granos se anima mientras el caso está activo y se congela con la pausa.
- Los iconos de los casos en espera son estáticos; sus números siguen mostrando
  el tiempo real. Al aceptar el siguiente caso se usa su tiempo restante actual.
- El protocolo muestra las estaciones como tareas independientes, con marca de
  completada por ID y contador `N/T COMPLETADAS`. Todas las pendientes
  tienen la misma importancia visual; no hay una etapa obligatoria siguiente.
- Repetir una estación muestra un aviso y conserva el progreso. Al completar todas,
  el caso se cierra automáticamente y el panel retira la tarjeta activa.
- En la oficina, E en el computador entrega una hoja física vinculada al caso.
  Las estaciones solo aceptan la interacción si el personaje lleva esa hoja.
  E sobre un espacio libre la lanza; E cerca de la hoja la recoge.
- El medallón de `indicador_papel.gd` aparece abajo a la izquierda mientras el
  jugador lleva la hoja, con la leyenda «E - soltar». Se oculta al soltarla,
  terminar/vencer el caso y durante las interfaces del computador o reparación.
  Su referencia es 140×158 píxeles a 1280×720, con margen de 24 píxeles;
  escala proporcionalmente y desplaza los avisos de apagón hacia arriba solo mientras
  está visible. No captura entradas. El círculo y la leyenda son controles
  nativos; `Arte/papel_medallon.png` conserva el documento 3D aprobado sin
  renderizar una escena adicional cada cuadro. Se regenera desde el modelo real
  ejecutando Godot con `--path proyecto-4-semestre --script ../herramientas/renderizar_papel_hud.gd`.
- La mesa física de seguridad (`privacidad`) inicia un desencriptado de seis
  segundos al pulsar E con la hoja. La barra coral se llena sobre la estación y
  otra línea se llena debajo de «DESENCRIPTANDO», en el centro inferior. Ambas
  pistas y sus rellenos tienen extremos redondeados. La tarea
  sigue mientras el jugador se mueve y se detiene al pausar. Tras seis segundos
  queda lista: el jugador debe regresar a la mesa y pulsar E para completar la
  estación. Volver a pulsar E antes no reinicia el tiempo. Si el caso vence o se
  resuelve por otra vía, la tarea y sus avisos se cancelan.
- En reportes la impresora tiene un 35 % de probabilidad de atascarse al primer
  uso de cada caso. La herramienta aparece en la zona de descanso: recogerla con
  E y regresar a la mesa con la hoja repara la impresora y completa la tarea.
  El atasco y la herramienta desaparecen si vence el caso.
- Evidencias abre un planillero de cartón con pinza metálica. La hoja de
  referencia a la izquierda muestra el archivo solicitado; tres papeles de
  colores aparecen a la derecha en orden aleatorio. A/D o flechas elige la
  hoja, E la toma y Esc sale conservando el avance. Las hojas correctas
  desaparecen del planillero; tres elecciones correctas completan la estación.
  Una equivocada no da progreso. El planillero sube desde el borde inferior al
  abrirse y las instrucciones se presentan como teclas individuales.
- Verificación muestra de cerca el cristal de un escáner con un documento físico.
  El aparato sube desde abajo al abrirse, como el planillero de Evidencias, y
  las indicaciones E y Esc usan las mismas teclas dibujadas. La luz coral recorre
  verticalmente el documento y E la detiene dentro de una franja verde cuya
  posición cambia por caso. Durante la entrada no se puede detener la luz.
  Acertar completa la estación; fallar reinicia el barrido tras un aviso breve.
  Esc permite salir y regresar; pausa y vencimiento detienen o cancelan el
  escáner junto con la partida.
- El aviso «Luz restaurada» solo se muestra durante una ejecución de depuración
  con la capa F3 visible. En juego normal desaparece. La tecla B de prueba del
  apagón solo está disponible en ejecuciones de depuración.
- El HUD escala desde 1920×1080 sin alterar el mundo; la cola permite desplazamiento
  cuando no cabe y no captura el foco del teclado.

La puntuación se acumula al resolver el caso completo; avanzar estaciones o
dejar vencer un caso no concede puntos. El canje y los efectos sobre el mapa
se incorporarán en una etapa posterior.

## Comprobación

Ejecutar con F6 `UI/Despacho/Pruebas/PruebaBarraLateral.tscn`.
Por CLI, añadir `--headless` para pruebas funcionales o `-- --capturas` para
capturas renderizadas en `.godot/barra_lateral_qa/`.
Comprueba transición de caso, arena sincronizada, espera inmóvil, pausa real de
la oficina, vencimiento, actividad, protocolos largos y cinco resoluciones.

Las pruebas de puntuación se ejecutan con F6 en
`Pruebas/Puntuacion/PruebaPuntuacion.tscn` (lógica, pausa y nueva partida real)
y `Pruebas/Puntuacion/PruebaInterfazPuntuacion.tscn` (HUD, conexiones y cinco
resoluciones de pantalla). También admiten CLI:

```text
Godot --headless --path proyecto-4-semestre res://Pruebas/Puntuacion/PruebaPuntuacion.tscn
Godot --headless --path proyecto-4-semestre res://Pruebas/Puntuacion/PruebaInterfazPuntuacion.tscn
```

La escena de interfaz admite `-- --capturas` al ejecutarse sin `--headless`,
para guardar imágenes en `.godot/puntuacion_qa/`.
