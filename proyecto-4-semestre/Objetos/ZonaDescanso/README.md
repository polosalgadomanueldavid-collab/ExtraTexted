# Zona de descanso

La oficina instancia `ZonaDescanso.tscn` junto a la pared lateral y `MaquinaExpendedora.tscn` en la parte inferior del mapa, conservando el mobiliario del Furniture Pack.

- **E frente a la cafetera:** abre la máquina 3D sobre el escenario traslúcido. El pulsador SERVIR prepara una taza en 1,8 segundos; se recoge haciendo clic en la taza o en la pantalla RETIRA. Cobra 50 puntos al entregarla; **Esc** permite cancelar antes sin cobro. Requiere luz, calma menor a 100 y no llevar un papel u otro café.
- **F llevando café:** toma el café, recupera hasta 15 de calma y devuelve la taza vacía al mueble. Puede beberse de pie o sentado.
- **E frente al sofá:** se sienta en el tramo más cercano. Recupera 1 de calma cada 2 segundos. **E o Esc** permiten levantarse hacia un punto libre.

Los casos continúan durante la preparación y el descanso. La pausa global congela estas acciones. Reiniciar o salir limpia gestos, taza y colisiones; no reembolsa cafés ya entregados ni recupera calma después de terminar la partida.

`zona_descanso.gd` expone el precio, la recuperación y los tiempos para ajustar el equilibrio desde el inspector. El saldo gastable está separado del puntaje ganado para la clasificación. Las tazas blanca y amarilla se alternan y usan el anclaje de la mano derecha del personaje. La animación comparte la malla y los materiales de la taza seleccionada; al recogerla, esa taza sale físicamente de la mesa. Con el café en la mano solo se muestra el medallón del bolsillo, sin un aviso azul duplicado. El líquido se ajusta al interior de la taza y usa un material independiente para cada preparación y jugador. La cafetera usa crema y azul petróleo del modelo del escenario, sin título ni rótulo de salida. En LAN, el servidor confirma el índice de la taza al comprar y lo replica para que ambos jugadores vean el mismo color; las compras siguen usando el saldo compartido.

Los sonidos de `Audios/Descanso` son síntesis originales PCM mono: preparación de 1,8 s y sorbo de 0,7 s. Se pausan con la partida.

Las tazas tienen paredes interiores, fondo y borde redondeado, con asas curvas integradas. `Editor/generar_tazas.gd` hornea ambas mallas conservando sus medidas y colores. `contenido_cafe.gd` y `superficie_cafe.gdshader` cubren todo el interior con un plano horizontal ajustado al centro y al perfil de cada recipiente; el nivel baja al beber sin atravesar el borde ni el fondo. La taza pivota desde el agarre, se endereza y vuelve vacía al mueble después de bajar el brazo. Las copias de la cafetera y de otros jugadores tienen materiales de café independientes.

Validación: ejecutar Godot con `--headless --fixed-fps 60 --script` y una de estas rutas:

- `res://Pruebas/ZonaDescanso/prueba_panel_cafetera.gd` (añadir `-- --capturas`, sin `--headless`, para las vistas de ambas tazas)
- `res://Pruebas/ZonaDescanso/prueba_interacciones_descanso.gd`
- `res://Pruebas/ZonaDescanso/prueba_taza_cafe.gd` (añadir `-- --capturas`, sin `--headless`, para sostener, sorbo y descenso de pie y sentado)
- `res://Pruebas/ZonaDescanso/prueba_taza_remota.gd` (presentación remota con datos locales, sin abrir una conexión)
- `res://Pruebas/ZonaDescanso/prueba_economia_descanso.gd`
- `res://Pruebas/ZonaDescanso/prueba_zona_descanso.gd`

La herramienta `Editor/hornear_sofa_l.gd` genera las dos mallas recortadas del sofá. Se usa fuera de la partida; el juego carga únicamente las mallas horneadas y tres colisiones de caja.

## Máquina expendedora

### Preview de objetos y café

El bolsillo usa los **medallones de la propuesta A**, con crema, coral, azul petróleo y la misma fuente que la hoja. `UI/Descanso/indicador_bolsillo.gd` observa el inventario y la taza real: chocolate **Z**, dona **X**, papa tiempo **V**, Avatar **N** y café **F · BEBER**. No intercepta entradas ni cambia el flujo de compra o consumo.

Solo aparecen objetos disponibles o con un efecto en curso. Mientras se consumen muestran **USANDO/BEBIENDO**; los efectos temporales mantienen el medallón con aro menta y segundos restantes. Una nueva unidad comprada durante un efecto conserva su contador. Avatar muestra **SIN EVENTO** y su atajo hasta que haya un evento. El café desaparece al contacto del sorbo, cuando se aplica la recuperación de calma.

La fila se coloca junto a la hoja cuando está en la mano; sin hoja utiliza el margen izquierdo. Escala con la referencia 1280 × 720. Los avisos de descanso se sitúan encima. El HUD se oculta al abrir tiendas, computador, tareas, clasificación, pausa o ayuda y al terminar la partida. Durante ZA WARUDO sigue mostrando el reloj real.

Los cinco iconos son PNG transparentes prerenderizados desde los modelos del proyecto, sin viewports 3D permanentes. Se regeneran con `res://Objetos/ZonaDescanso/Editor/hornear_iconos_bolsillo.gd` (sin `--headless`). `res://Pruebas/ZonaDescanso/prueba_indicador_bolsillo.gd` verifica el HUD con compras y consumo de café reales; `-- --capturas` guarda las vistas en `.godot/bolsillo_qa`.

**E** frente a la máquina abre la tienda. Clic o **1–4** compran; **E/Esc** cierra. El mundo continúa mientras compras. Guarda una unidad de cada producto y actívala fuera de la tienda:

| Objeto | Usar | Precio inicial | Efecto |
| --- | --- | --- | --- |
| Chocolate | Z | 50 | Velocidad de caminar/correr ×1,65 durante 25 s. |
| Dona | X | 75 | Silueta ancha y salto de 1,65 m durante 10 s; permite subir a las mesas, también en lava. |
| Papa tiempo | V | 150 | Pose ZA WARUDO, burbuja expansiva gris, sonidos de parada/reanudación y tic-tac; congela el mundo 12 s. |
| El Avatar | N | 250 | Un uso para resolver el evento activo con una animación elemental. Sin evento conserva la carga. |

Los precios se ajustan en `maquina_expendedora.gd` desde el inspector. Comprar descuenta saldo, sin alterar el puntaje ganado de clasificación. Los objetos se consumen al contacto del gesto; cancelar antes conserva el objeto. No se acumulan duraciones, y el bolsillo se conserva al reaparecer. El final de la partida lo vacía.

Agua control resuelve inundación y lava; fuego control, incendio y apagón; tierra control, terremoto; aire control, la fuga de nitrógeno del evento hielo (la fuga de gas existente). Cada evento expone `resolver_con_avatar()`, que restaura también navegación, mobiliario, colisiones, luces y estados del jugador. Las poses son procedurales sobre el esqueleto, con cintas de agua/aire, llamas y rocas originales.

La papa congela procesos del mundo, sus temporizadores, animaciones, partículas, audio y cuerpos físicos, preservando sus colisiones. No usa `SceneTree.paused`: jugador, cámara, interfaces y acciones de las denuncias siguen disponibles; sus plazos, la llegada de casos y el reloj de partida no avanzan. Los shaders de los eventos ya usan relojes explícitos y permanecen inmóviles. El tic-tac es síntesis PCM original. La pausa normal suspende también la cuenta de 12 s. Reinicio, final y salida restauran los estados guardados, incluso si una denuncia eliminó su papel durante la detención.

Los dos MP3 elegidos para la parada y la reanudación están en `Audios/Expendedora`, junto con sus enlaces de origen. La parada suena al comenzar la burbuja; el tic-tac entra después de ese clip. La reanudación suena una vez al terminar los 12 s. Reiniciar o salir silencia los audios sin simular una reanudación. Ambos usan el bus `Interacciones` a −9 dB y respetan la pausa del juego.

### Coreografías del Avatar

`Personajes/PoliciaAzul/coreografia_avatar.gd` contiene cuatro secuencias originales de 3,6 s inspiradas en los personajes de la serie y adaptadas a las proporciones del policía:

- **Tierra / Toph:** base baja, cambios de peso, elevación de rodilla y dos golpes de talón separados. Cada pisada emite una onda y levanta fragmentos; después, las palmas elevan y empujan la tierra.
- **Agua / Korra:** barridos amplios y alternados por encima del hombro, rotación de cintura, cambios de apoyo y una descarga final con ambas palmas. Las estelas siguen las manos.
- **Aire / Aang:** entrada de palma circular, esquiva baja con cambio de peso, paso cruzado y giro completo. Los brazos alternan barridos altos y bajos con retraso respecto a la cintura; recogen el aire al pecho y descargan ambas palmas en zancada. Tres espirales abiertas e inclinadas convergen entre las manos y salen hacia delante.
- **Fuego / Zuko:** guardia cruzada, preparación del puño junto a la cadera, golpe recto, golpe ascendente y patada circular que recoge la rodilla antes y después de extender la pierna. La cintura anticipa los golpes, los puños sostienen brevemente la extensión y la patada continúa el giro antes de recuperar el apoyo. Una inhalación abre el pecho antes de la doble descarga final en zancada. Los ataques tienen preparación, aceleración, suspensión y retroceso; los chorros siguen la dirección real de los antebrazos y el pie, sin aros decorativos alrededor del cuerpo.

El evento se resuelve al 72 % del gesto; la postura se recupera al final. El esqueleto conserva la altura del pie de apoyo, sin mover las colisiones del jugador. Se mantiene el comportamiento de nado cuando el personaje está dentro de la inundación.

Los flujos de agua y fuego tienen geometría y materiales propios, compatibles con GL Compatibility:

- `flujo_agua.gd` mantiene las corrientes ligadas a las manos y suma `torbellino_agua.gd`: el agua se acumula en los pies, sube en una columna de hasta 1,6 unidades con tres espirales que envuelven al personaje y sale como una ola de más de 2 unidades de ancho. `manto_agua.gdshader` aporta espuma, transparencia y reflejos animados; 120 gotas adicionales acompañan el remolino y la descarga. Las superficies reutilizan los puntos vecinos para calcular normales. Todo sigue el reloj del gesto y conserva el contacto resolutivo al 72 %.
- `flujo_fuego.gd` crea llamaradas de tres capas y 48 brasas por emisor: los puñetazos alcanzan unas 2,9 unidades y la patada 3,35, frente a las 0,8 de altura del policía. `barrido_fuego.gd` conserva durante 0,58 s las trayectorias reales de manos y pie, proyectándolas hacia fuera como cortinas de fuego que persisten al recoger el golpe. La descarga de ambas palmas alimenta cinco lenguas adicionales en abanico, con más de 5 unidades de alcance y más de 3 de separación entre extremos. El frente conserva el rumbo al bajar los brazos. Los shaders aportan núcleo amarillo, lóbulos anaranjados y puntas que se deshacen; los materiales del incendio siguen siendo independientes. La malla de los chorros se comparte, cada estela usa un solo envío de geometría y un máximo de 38 muestras; las envolventes de visibilidad incluyen la deformación del shader.
- Ambos usan `ruido_flujo.tres`, ruido procedural compartido de FastNoiseLite, y el reloj del gesto: pausar congela ondas, turbulencia y gotas. No necesitan texturas externas, SSR ni nuevas extensiones. La captura y las pruebas de coreografía también ejercitan estos flujos.

Referencias de movimiento: [Toph enseña tierra control a Aang](https://www.youtube.com/watch?v=8nF4DQj_-Vc), [evolución del aire control de Aang](https://www.youtube.com/watch?v=DoxI_3RhVUg), [evolución del fuego control de Zuko](https://www.youtube.com/watch?v=CwlTFQqdI3I). Las animaciones se generan con el esqueleto del juego; no se incluyen clips de la serie.

Pruebas: `res://Pruebas/ZonaDescanso/prueba_expendedora.gd` y `res://Pruebas/ZonaDescanso/prueba_coreografias_avatar.gd` con `--headless --fixed-fps 60 --script`. Cubren compras, sonidos, detención, resolución de los seis eventos, contactos únicos, pausa, apoyos, dirección de las llamas y cancelación de las coreografías. Para revisar las poses y efectos, `res://Pruebas/ZonaDescanso/capturar_expendedora.gd` sin `--headless`; guarda siete fases por elemento en `.godot/expendedora_qa`. Añadir `-- --aire-fuego` produce doce poses de estos dos elementos en primer plano; con `--secuencia` guarda 60 cuadros por gesto para revisar la continuidad del movimiento.

Para revisar el fuego a escala completa, ejecutar `capturar_expendedora.gd` con `-- --fuego-amplio`: guarda doce fases en `.godot/fuego_avatar_qa`. Añadir `--secuencia` genera 60 cuadros; `--lateral` usa una cámara lateral y oculta únicamente en esa captura la pared que la tapa, guardando el resultado en `.godot/fuego_avatar_lateral_qa`. La secuencia toma como referencia visual los dos videos de Avatar proporcionados, sin incorporar sus clips al juego.
