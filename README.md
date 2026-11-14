# ExtraTexted

Proyecto de Godot 4.7. Abre [project.godot](proyecto-4-semestre/project.godot) para editar o ejecutar el juego. `UI/Menus/CargaInicial.tscn` muestra una pantalla negra mientras se prepara el menú, que aparece con un fundido. `UI/Menus/MainMenu.tscn` presenta la oficina real con perspectiva y dos policías animados; al pulsar Jugar, los policías discuten mientras aparecen frases y consejos a la izquierda y se prepara la partida. La oficina jugable está en `Mundo/Oficina.tscn`. Sus 30 cajones temporales se preparan de forma gradual y se reutilizan en las siguientes distribuciones.

## Organización

| Carpeta | Contenido |
| --- | --- |
| `proyecto-4-semestre/Mundo` | Escena principal de la oficina. |
| `proyecto-4-semestre/UI` | Menú, computador, despacho y sus interfaces. |
| `proyecto-4-semestre/Objetos` | Objetos interactivos del mundo, incluido el computador activo. |
| `proyecto-4-semestre/Personajes` | Escenas, scripts y modelos de personajes. |
| `proyecto-4-semestre/Eventos` | Apagón, terremoto, incendio, inundación, lava, hielo y bloqueos temporales. |
| `proyecto-4-semestre/Scripts` | Lógica agrupada por computador, despacho, estructuras, mundo y partida. |
| `proyecto-4-semestre/Casos` | Datos de las denuncias y los casos. |
| `proyecto-4-semestre/MarcadoresEstaciones` | Marcadores visuales de las estaciones. |
| `proyecto-4-semestre/Arte`, `Audios`, `Furniture Pack` | Texturas, sonidos y modelos usados por Godot. `Furniture Pack/Computador/Computador.tscn` es el modelo independiente; `Objetos/Computador/computer.tscn` es el objeto interactivo del juego. |
| `proyecto-4-semestre/Pruebas` | Pruebas y escenas de verificación agrupadas por función. |
| `proyecto-4-semestre/Documentacion` | Diseño técnico y notas del proyecto. |
| `arte-fuente`, `muestras_audio`, `herramientas` | Archivos editables, muestras y herramientas fuera del proyecto de Godot. |

Las rutas `res://` empiezan en `proyecto-4-semestre`. Al mover un recurso, actualiza sus referencias y conserva su archivo `.uid` o `.import` cuando exista.

El evento [TERREMOTO](proyecto-4-semestre/Eventos/Terremoto/README.md) abre **entre diez y doce grietas**, incluida una gigante en descanso, y deja caer **entre catorce y veinte montones de escombros en la parte superior**, más un máximo de tres en descanso, en tres oleadas desde el techo. Los derrumbes priorizan los pasillos rectos abiertos y los pasos entre grietas. Aléjate de las marcas rayadas, cuyo borde se consume y se vuelve rojo antes del impacto, y rodea los derrumbes; las grietas estrechas se saltan con **Espacio**. Los montones anchos cierran pasos de dos casillas. Las estaciones conservan acceso, pero descanso también se fractura: sal del contorno dorado de la grieta gigante antes de que se abra. Todo se retira al terminar los **24 segundos** del evento.

El evento [INCENDIO](proyecto-4-semestre/Eventos/Incendio/README.md) inutiliza las estaciones y las mesas del perímetro hasta apagarlas. Recoge el extintor con **E** en descanso y mantén **E** mirando cada fuego: apagar una mesa extingue gradualmente sus vecinas durante **1,1 s**. Abajo, el efecto se limita al mismo tramo, sin cruzar el hueco ni girar hacia los laterales. Tras **24 segundos** empieza la pérdida de cordura a **1 punto/s**, que aumenta a **2 tras 60 s** y **3 tras 90 s** hasta resolver el evento. A los diez segundos, los cajones se carbonizan con una animación y quedan como bloqueos de ceniza durante el evento. Al apagar la última mesa, se retiran las cenizas y vuelven los cajones normales y sus cambios periódicos. Para probarlo directamente, abre `Pruebas/Incendio/PruebaIncendio.tscn` y pulsa **F6**.

El evento [INUNDACIÓN](proyecto-4-semestre/Eventos/Inundacion/README.md) llena la oficina de agua, hace flotar el mobiliario y ralentiza al policía con animaciones de natación. Los casos siguen disponibles y los nuevos cajones salpican sin perder sus protecciones de colocación. Repara las tuberías de descanso con **E**, girando los tramos para conectar el flujo. Los emotes se bloquean durante la natación. Para probarlo, abre `Pruebas/Inundacion/PruebaInundacion.tscn` y pulsa **F6**.

El evento [LAVA](proyecto-4-semestre/Eventos/Lava/README.md) convierte el piso en magma durante **60 segundos**. El contacto reduce la cordura y los seis charcos brillantes hacen daño adicional. **Espacio** permite saltar hasta los bloqueos temporales para protegerse; las mesas laterales siguen sin poder treparse. Los bloqueos cambian cada **4 segundos**, con chispas al caer. El personaje sacude los pies quemados y un reloj muestra el tiempo restante. Para probarlo, abre `Pruebas/Lava/PruebaLava.tscn` y pulsa **F6**.

El evento [HIELO](proyecto-4-semestre/Eventos/Hielo/README.md) cubre la oficina de hielo azul y nieve. El policía resbala y se congela **1,25 s cada 4 s**, conservando la inercia. Las tareas siguen disponibles. Repara la fuga de **nitrógeno en descanso con E**, apretando las tuercas en cruz durante tres pasadas. Para probarlo, abre `Pruebas/Hielo/PruebaHielo.tscn` y pulsa **F6**.
