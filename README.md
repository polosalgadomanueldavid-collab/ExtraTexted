# ExtraTexted

Proyecto de Godot 4.7. Abre [project.godot](proyecto-4-semestre/project.godot) para editar o ejecutar el juego. `UI/Menus/CargaInicial.tscn` muestra una pantalla negra mientras se prepara el menú, que aparece con un fundido. `UI/Menus/MainMenu.tscn` presenta la oficina real con perspectiva y dos policías animados; al pulsar Jugar, los policías discuten mientras aparecen frases y consejos a la izquierda y se prepara la partida. La oficina jugable está en `Mundo/Oficina.tscn`. Sus 30 cajones temporales se preparan de forma gradual y se reutilizan en las siguientes distribuciones.

## Organización

| Carpeta | Contenido |
| --- | --- |
| `proyecto-4-semestre/Mundo` | Escena principal de la oficina. |
| `proyecto-4-semestre/UI` | Menú, computador, despacho y sus interfaces. |
| `proyecto-4-semestre/Objetos` | Objetos interactivos del mundo, incluido el computador activo. |
| `proyecto-4-semestre/Personajes` | Escenas, scripts y modelos de personajes. |
| `proyecto-4-semestre/Eventos` | Apagón y bloqueos temporales. |
| `proyecto-4-semestre/Scripts` | Lógica agrupada por computador, despacho, estructuras, mundo y partida. |
| `proyecto-4-semestre/Casos` | Datos de las denuncias y los casos. |
| `proyecto-4-semestre/MarcadoresEstaciones` | Marcadores visuales de las estaciones. |
| `proyecto-4-semestre/Arte`, `Audios`, `Furniture Pack` | Texturas, sonidos y modelos usados por Godot. `Furniture Pack/Computador/Computador.tscn` es el modelo independiente; `Objetos/Computador/computer.tscn` es el objeto interactivo del juego. |
| `proyecto-4-semestre/Pruebas` | Pruebas y escenas de verificación agrupadas por función. |
| `proyecto-4-semestre/Documentacion` | Diseño técnico y notas del proyecto. |
| `arte-fuente`, `muestras_audio`, `herramientas` | Archivos editables, muestras y herramientas fuera del proyecto de Godot. |

Las rutas `res://` empiezan en `proyecto-4-semestre`. Al mover un recurso, actualiza sus referencias y conserva su archivo `.uid` o `.import` cuando exista.
