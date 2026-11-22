# Barra lateral de denuncias

## Recompensa del turno y SHOP

Se conserva una sola confirmación central: **¡HECHO!**, con su animación y sonido de lápiz. Las ganancias aparecen en el HUD, cuyo saldo anima durante 0,8 s sin retrasar el valor real usado para compras. Un gasto cancela el conteo anterior. No hay un sello adicional de caso resuelto ni una segunda nota de sueldo. La señal de SHOP espera a que finalice ¡HECHO!.

## Primer turno por radio

Cada partida individual nueva comienza con una práctica jugable, tanto desde el menú como al ejecutar Oficina directamente en el editor. La marca guardada de una práctica vista no la oculta; F2 permite omitirla. Un reintento explícito después del final puede pasar directamente al turno. `Scripts/Partida/practica_radio.gd` crea una denuncia real con una estación (Evidencias), una referencia fija (IDENTIDAD) y saldo equivalente al precio actual del chocolate. Usa la hoja física, los gestos, el archivador, la compra, la entrega y el consumo habituales; los cambios de paso dependen de esas acciones. La radio no bloquea movimiento ni ofrece un botón para completar tareas.

`radio_practica.gd` dibuja una radio y papel ilustrados con Luckiest Guy, Nunito y la paleta crema, petróleo y coral. Las indicaciones se adaptan al teclado/mando y siguen el objetivo o la hoja suelta. Incluye una breve señal sonora original en el bus Interacciones, respeta la pausa y la preferencia de movimiento de cámara. Se reduce a una línea durante el archivador y se oculta en la tienda, los menús y la confirmación ¡HECHO!. Los objetivos muestran destino y acción: recoger en el computador, archivar IDENTIDAD o comprar y recoger el chocolate.

Mientras dura, el despacho protege calma y plazos; se detienen denuncias nuevas, bloqueos y emergencias. El caso concede saldo gastable pero no suma al récord, la duración ni las estadísticas del turno. Al terminar o pulsar F2/Vista para omitir, se retira la guía, se guarda `user://practica_radio.cfg` y empieza el turno normal. Ayuda incluye **PRÁCTICA POR RADIO · TURNO NUEVO** para repetirla en otra oficina. La introducción compartida de LAN conserva sus guías actuales.

Validación: `Godot --headless --path proyecto-4-semestre --fixed-fps 60 --script res://Pruebas/Partida/prueba_practica_radio.gd`. Sin `--headless`, añadir `-- --capturas` para guardar las fases y Ayuda en `.godot/practica_radio_qa`. La prueba usa un perfil temporal independiente del usuario.

HUD exclusivo de `res://UI/Despacho/PanelDespacho.tscn`: fondo general transparente,
tarjetas crema compactas, acentos laterales por riesgo y fuente Luckiest Guy
reutilizada del menú. No modifica el despacho, el AVL, las estaciones ni los menús.

- La calma operativa aparece en la esquina superior izquierda, con el policía
  centrado en un retrato circular y una barra segmentada a su lado. Cada jugador
  tiene su propia fila; las filas nuevas se apilan debajo sin mover el panel de
  denuncias de la derecha.
- La fila de calma muestra el nombre elegido al iniciar la partida. Los nombres
  largos reducen su tamaño y se recortan con puntos suspensivos dentro del mismo
  hueco, sin desplazar el retrato, la cifra ni los segmentos. Para el futuro
  compañero, `PanelCalmaJugadores.actualizar_jugador(2, calma, nombre)` permite
  asignar su identidad; las actualizaciones de calma conservan el nombre.
- Mantener Tab abre una hoja de la libreta de turnos. El título lleva una pasada
  de rotulador coral y un círculo a lápiz identifica el puesto del jugador. Se reserva el espacio de dos filas de calma más
  una separación de 24 unidades de diseño, incluso con un único jugador.
  Conserva los cinco mejores récords y el resumen del puntaje de la partida.
  La clasificación del menú usa una carpeta de expedientes con una ficha para el
  puesto, alias y mejor marca local. Su lista completa permite desplazamiento.
  Ambas tablas usan marcos ilustrados y controles nativos para sus datos.
- Al terminar el relevo, **Ir al cuaderno** abre una libreta 3D: cubierta naranja,
  cantos de papel, espiral metálico, hojas cuadriculadas con curvatura y giro con
  anverso y reverso. Conserva los titulares, descripciones y resultados del turno.
  Las pestañas de Balance, Casos y Estadísticas pasan al lado izquierdo conforme
  se avanza. Las estaciones y denuncias llevan viñetas. El fondo se desenfoca.
  **A/D, flechas o RePág/AvPág** cambian de sección; **clic derecho** acerca la
  zona apuntada y vuelve al encuadre completo; **Z** acerca el centro y **Esc**
  sale del acercamiento. La rueda desplaza cada lista. Cambiar de sección también
  devuelve el encuadre completo. El balanceo sigue el ajuste de accesibilidad.
  Reintentar y Menú conservan su comportamiento, incluida la restricción del
  anfitrión LAN. El renderizado adicional solo funciona con la libreta visible.
  Las pestañas de colores son la única numeración; no hay encabezado de marca
  repetido ni números al pie. El espiral queda dentro de las hojas, sin varilla.
  En LAN, la primera apertura añade **MVP del equipo** sobre el caso final:
  **Más misiones** reconoce las denuncias resueltas en las que el jugador completó
  alguna estación, y **Mayor aporte** cuenta sus tareas completadas, incluso en
  casos que luego vencen o siguen abiertos. Una misión compartida reconoce a
  ambos; repetir una estación o llevar la hoja no suma. Los empates muestran
  ambos nombres y una ronda sin actividad deja los premios sin asignar.
  El anfitrión acumula y sincroniza los totales; reiniciar los pone a cero.
  Las demás páginas conservan su contenido.
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
- El caso activo y la cola muestran los símbolos de carpeta, lupa, candado,
  documento y corazón en una sola fila compacta. Coinciden con los flotantes de
  las estaciones y conservan contraste petróleo/crema. Una tarea completada
  queda verde con un check; no cambia a otro símbolo ni se convierte en una
  miniatura. No hay nombres de estaciones, números de orden ni flechas.
- Las cinco mesas conservan completos los diseños 3D originales, su decoración,
  escala, ubicación, texturas y colisiones. Una luz cálida ilumina la superficie
  de las pendientes y aumenta al poder interactuar, sin superponer materiales
  a las mallas ni blanquearlas. Los flotantes están activos; E/X aparece al poder
  actuar con la hoja correcta. `respuestas_visuales_mesas = false` desactiva
  solo la luz de trabajo adicional. El orden y los minijuegos siguen siendo reales.

  Prueba integrada: `Godot --headless --path proyecto-4-semestre --fixed-fps 60
  --script res://Pruebas/Despacho/prueba_orientacion_contextual.gd`. Sin
  `--headless`, añadir `-- --capturas` guarda los dos protocolos reales y el
  sellado parcial en `.godot/denuncias_visuales_qa/`.
- Repetir una estación o usar una ajena resalta brevemente las casillas pendientes,
  sin añadir otro aviso de texto ni alterar el progreso. Completar todas cierra
  el caso automáticamente; la ficha permanece 0,85 s para recibir la última pieza.
- En la oficina cada estación completada envía su símbolo desde la herramienta
  a la casilla correspondiente durante 0,62 s. No aparece otro check central ni texto
  «¡HECHO!». Conserva el sonido original estéreo de lápiz y dos notas suaves,
  `Audios/tarea_completada.wav` (1,1 segundos), sincronizado con el dibujo.
  El vuelo, la carpeta y el audio se congelan con la pausa; repetir una tarea o usar una
  estación incorrecta no los vuelve a activar. La última tarea conserva el efecto
  aunque su caso se cierre. Cambiar de sistema o vencer el mismo caso lo cancela.
  El audio sigue el volumen del bus Master, con una atenuación adicional de 6,5 dB.
  Se regenera con `python herramientas/generar_sonido_tarea.py` desde la raíz del
  repositorio; la síntesis es determinista y no usa muestras ni servicios externos.
- En la oficina, E en el computador entrega una hoja física vinculada al caso.
  Las estaciones solo aceptan la interacción si el personaje lleva esa hoja.
  E sobre un espacio libre la lanza; E cerca de la hoja la recoge.
- El medallón de `indicador_papel.gd` aparece abajo a la izquierda mientras el
  jugador lleva la hoja, con la leyenda «E - soltar». Se oculta al soltarla,
  terminar/vencer el caso y durante las interfaces del computador o reparación.
  Su referencia es 140×158 píxeles a 1280×720, con margen de 24 píxeles;
  escala proporcionalmente y desplaza los avisos de apagón hacia arriba solo mientras
  está visible. No captura entradas. El círculo y la leyenda son controles
  nativos; el medallón muestra ahora la carpeta que lleva el personaje. La hoja
  física mantiene su tamaño, colisión y manejo, con cubierta ocre y piezas claras
  que se incorporan según el progreso de ese expediente.
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
- Las cinco mesas tienen audio de interacción: Evidencias alterna tres sonidos
  de pasar página al cambiar realmente de hoja y un golpe de papel al archivar;
  Verificación mantiene un motor en bucle sincronizado con una ida y vuelta de la
  luz, con un aviso corto al fallar; Seguridad tiene teclas durante el desencriptado
  y dos pitidos cuando está listo; Reportes distingue rodillos, atasco y reparación;
  Bienestar añade un toque suave al completar su tarea. Los bucles se interrumpen
  al cancelar o vencer el caso, y todo el audio se pausa con el juego. El motor del
  escáner espera a que termine la entrada del panel y se detiene también al salir,
  fallar o acertar. Son complementarios al sonido de «Check con garabato».
  `Audios/Mesas/README.md` documenta los archivos, sus fuentes y las licencias.
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
  apagón solo está disponible después de activar el modo debug con F3 en una
  ejecución de desarrollo.
- El HUD escala desde 1920×1080 sin alterar el mundo; la cola permite desplazamiento
  cuando no cabe y no captura el foco del teclado.

La puntuación se acumula al resolver el caso completo; avanzar estaciones o
dejar vencer un caso no concede puntos. El canje y los efectos sobre el mapa
se incorporarán en una etapa posterior.

## Comprobación

`Pruebas/Partida/PruebaCuaderno3D.tscn` ofrece una vista interactiva con F6.
Por CLI, `-- --verificar` comprueba clics proyectados, giro en ambos sentidos,
entradas repetidas, foco/Enter, desplazamiento normal y ampliado, cinco tamaños
de ventana y las señales de salida. `-- --verificar --capturas` guarda las
vistas de balance, casos, estadísticas, giro y zoom en `.godot/cuaderno_3d_qa/`.
También verifica MVP individual/LAN, ganadores diferentes, empates y ausencia
de actividad; `08_mvp.png` y `09_mvp_sin_actividad.png` muestran estos estados.
La prueba admite `--headless`. `Pruebas/Partida/prueba_final_partida.gd` comprueba
además el relevo real, la pausa, el reinicio de la oficina y la vuelta al menú.

`Godot --headless --path proyecto-4-semestre --script res://Pruebas/Puntuacion/prueba_diseno_clasificacion.gd`
comprueba los nombres, la reserva para dos barras, cuatro resoluciones, estados
vacíos, errores y listas largas. Con renderizado, `-- --capturas` guarda ambos
diseños en `.godot/clasificacion_qa/`. La prueba de puntuación existente verifica
además Tab, actualización de récords y navegación entre menú y partida; para
ejecutarla sin ventana usar `--max-fps 30`, pues su espera de 120 cuadros debe
abarcar la duración mínima de la pantalla de carga.

`UI/Despacho/Pruebas/PruebaSonidosMesas.tscn` prueba las acciones de las cinco
mesas dentro de la oficina real: entrada del panel, cambio de hojas, variantes,
archivo correcto e incorrecto, pausas, reintento y salida del escáner, duración
del bucle, desencriptado completo, atasco, reparación, impresión normal, Bienestar
y cancelación de bucles al vencer el caso. Admite ejecución con `--headless`.

`UI/Despacho/Pruebas/PruebaEfectoTarea.tscn` comprueba las estaciones correctas,
repetidas e incorrectas, pausa y reanudación audiovisual, cierre de caso,
vencimiento, cambio de sistema y escalado del efecto. Admite `--headless` y,
en ejecución renderizada, `-- --capturas` guarda imágenes en
`.godot/efecto_tarea_qa/`.

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

La entrada directa y las partidas nuevas con un perfil ya utilizado se comprueban con `Pruebas/Partida/prueba_inicio_practica.gd`.
