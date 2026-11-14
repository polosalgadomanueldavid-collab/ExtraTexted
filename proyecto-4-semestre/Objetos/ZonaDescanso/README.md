# Zona de descanso

La oficina instancia `ZonaDescanso.tscn` junto a la pared lateral y `MaquinaExpendedora.tscn` en la parte inferior del mapa, conservando los modelos del Furniture Pack.

- **E frente a la cafetera:** prepara una taza en 1,8 segundos. Cobra 50 puntos al entregarla; **Esc** permite cancelar antes sin cobro. Requiere luz, calma menor a 100 y no llevar un papel u otro café.
- **F llevando café:** toma el café, recupera hasta 15 de calma y devuelve la taza vacía al mueble. Puede beberse de pie o sentado.
- **E frente al sofá:** se sienta en el tramo más cercano. Recupera 1 de calma cada 2 segundos. **E o Esc** permiten levantarse hacia un punto libre.

Los casos continúan durante la preparación y el descanso. La pausa global congela estas acciones. Reiniciar o salir limpia gestos, taza y colisiones; no reembolsa cafés ya entregados ni recupera calma después de terminar la partida.

`zona_descanso.gd` expone el precio, la recuperación y los tiempos para ajustar el equilibrio desde el inspector. El saldo gastable está separado del puntaje ganado para la clasificación. Las tazas blanca y amarilla se alternan y usan el anclaje de la mano derecha del personaje.

Los sonidos de `Audios/Descanso` son síntesis originales PCM mono: preparación de 1,8 s y sorbo de 0,7 s. Se pausan con la partida.

Validación: ejecutar Godot con `--headless --fixed-fps 60 --script` y una de estas rutas:

- `res://Pruebas/ZonaDescanso/prueba_interacciones_descanso.gd`
- `res://Pruebas/ZonaDescanso/prueba_economia_descanso.gd`
- `res://Pruebas/ZonaDescanso/prueba_zona_descanso.gd`

La herramienta `Editor/hornear_sofa_l.gd` genera las dos mallas recortadas del sofá. Se usa fuera de la partida; el juego carga únicamente las mallas horneadas y tres colisiones de caja.

## Máquina expendedora

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
- **Fuego / Zuko:** guardia cruzada, preparación del puño junto a la cadera, golpe recto, golpe ascendente y patada circular que recoge la rodilla antes y después de extender la pierna. Una inhalación abre el pecho antes de la doble descarga final. Los ataques tienen preparación, aceleración, suspensión y retroceso; los chorros siguen la dirección real de los antebrazos y el pie, sin aros decorativos alrededor del cuerpo.

El evento se resuelve al 72 % del gesto; la postura se recupera al final. El esqueleto conserva la altura del pie de apoyo, sin mover las colisiones del jugador. Se mantiene el comportamiento de nado cuando el personaje está dentro de la inundación.

Referencias de movimiento: [Toph enseña tierra control a Aang](https://www.youtube.com/watch?v=8nF4DQj_-Vc), [evolución del aire control de Aang](https://www.youtube.com/watch?v=DoxI_3RhVUg), [evolución del fuego control de Zuko](https://www.youtube.com/watch?v=CwlTFQqdI3I). Las animaciones se generan con el esqueleto del juego; no se incluyen clips de la serie.

Pruebas: `res://Pruebas/ZonaDescanso/prueba_expendedora.gd` y `res://Pruebas/ZonaDescanso/prueba_coreografias_avatar.gd` con `--headless --fixed-fps 60 --script`. Cubren compras, sonidos, detención, resolución de los seis eventos, contactos únicos, pausa, apoyos, dirección de las llamas y cancelación de las coreografías. Para revisar las poses y efectos, `res://Pruebas/ZonaDescanso/capturar_expendedora.gd` sin `--headless`; guarda siete fases por elemento en `.godot/expendedora_qa`. Añadir `-- --aire-fuego` produce doce poses de estos dos elementos en primer plano; con `--secuencia` guarda 60 cuadros por gesto para revisar la continuidad del movimiento.
