# Sistema de grafos para la navegación de la oficina

## Propósito

`GrafoPiso` representa las casillas transitables de la oficina y calcula una ruta sugerida desde el jugador hasta la estación pendiente alcanzable con menos pasos. Las estaciones de una denuncia se pueden completar en cualquier orden. El grafo también permite comprobar que los cajones y los peligros del terremoto conserven los accesos necesarios.

La sugerencia se recalcula al cambiar la denuncia o sus estaciones pendientes, al entrar el jugador en otra celda y al cambiar los obstáculos. Los marcadores de **todas** las estaciones pendientes permanecen visibles; la guía destaca una sola sugerencia.

## Modelo y coordenadas

La cuadrícula tiene `14` columnas por `25` filas, con celdas de `0,5` unidades. Su referencia espacial usa `ORIGEN_X = -4,5` y `ORIGEN_Z = -0,1`. `posicion_a_celda()` convierte la posición 3D en `Vector2i(columna, fila)`; `celda_a_posicion()` devuelve el centro de la celda en el piso.

Cada celda transitable es un vértice. Las aristas unen vecinos horizontales o verticales y cuestan un paso; no hay diagonales. `construir_adyacencia()` recorre las 350 posiciones posibles y guarda en `adyacencia` solo los vértices transitables con sus vecinos. Una celda fuera del mapa o incluida en cualquiera de estas colecciones no es transitable:

| Colección | Procedencia |
| --- | --- |
| `bloqueos_fijos` | Casillas definidas en `CELDAS_BLOQUEADAS_FIJAS`. |
| `bloqueos_mesas` | Huellas de mesas y muebles obtenidas de la escena por `GrafoDebugVisual`. |
| `bloqueos_temporales` | Cajones que cambian durante la partida. |
| `grietas`, `escombros` | Obstáculos del terremoto mientras dura el evento. |

`celda_de_acceso()` usa la propia celda si es transitable. Si una mesa ocupa lógicamente la celda donde está el personaje, busca el centro de la celda transitable más cercana y lo usa como origen. No abre la celda de la mesa. Si no existe ninguna, devuelve `(-1, -1)` y la búsqueda de ruta no produce resultado.

`DESTINOS` contiene **casillas de aproximación**, no el centro de la mesa física:

| Estación | Celda de acceso |
| --- | ---: |
| `computador` | `(7, 2)` |
| `evidencias` | `(11, 7)` |
| `verificacion` | `(2, 7)` |
| `privacidad` | `(4, 10)` |
| `reporte` | `(9, 10)` |
| `bienestar` | `(2, 3)` |

## Ruta mínima

`calcular_ruta_a_mas_cercana(origen, destinos)` hace una **búsqueda en anchura (BFS)** sobre `adyacencia`. Como todas las aristas cuestan uno, la primera capa que contiene un destino tiene la distancia mínima. Si varios destinos están en esa capa, elige el de menor fila y luego menor columna. `calcular_ruta(origen, destino)` delega en el mismo método con un solo destino.

La búsqueda guarda cada celda visitada en una cola y registra su predecesora. Después reconstruye la ruta desde el destino elegido hasta el origen y la invierte. La ruta incluye ambos extremos: `[origen]` significa que el jugador ya está en la casilla de acceso. Devuelve `[]` si no hay destinos, el origen no está en la adyacencia o ningún destino es alcanzable. Un destino bloqueado tampoco puede aparecer en la ruta.

El recorrido cuesta `O(V + E)` en tiempo y `O(V)` en memoria, donde `V` son las celdas transitables y `E` sus conexiones. Para este mapa, `V ≤ 350` y `E ≤ 661`. La implementación anterior basada en Dijkstra ya no es la que ejecuta `GrafoPiso`.

`celdas_alcanzables(origen)` recorre las cuatro direcciones leyendo `es_transitable()` directamente, incluso antes de reconstruir la adyacencia. Devuelve un diccionario de celdas visitadas o `{}` cuando el origen está bloqueado. Se usa para evaluar una ocupación provisional.

## Cajones y conservación de accesos

Cada `10` segundos, `gestor_partida.gd` retira la distribución anterior e intenta colocar hasta `30` cajones. Primero calcula las celdas alcanzables desde el acceso del jugador y prepara un `AStarGrid2D` sin diagonales para ensayar candidatos. Se excluyen las estaciones, la zona segura, el acceso del jugador y las celdas que invadirían su cuerpo o una hoja suelta, incluido su trayecto inmediato.

Para cada candidato, el gestor lo marca provisionalmente como sólido. `_conserva_accesos()` comprueba que el jugador conserve una salida y los destinos que eran alcanzables al inicio: estaciones y nodos del grupo `accesos_navegacion`. Solo vuelve a buscar una ruta si el candidato corta una ruta protegida conocida. En LAN, `PartidaLAN.proteger_celda()` añade la protección de **ambos** jugadores activos, sus accesos a estaciones y las hojas sueltas. Si el candidato falla, se retira del ensayo y se prueba otro. Puede quedar una distribución parcial o ninguna.

Después se reconstruye la adyacencia, se actualiza el depurador y se recalcula la ruta sugerida. En LAN solo el anfitrión sortea los cajones; publica la lista concreta de celdas y el cliente la aplica a su grafo, sin repetir el sorteo.

El terremoto registra grietas y escombros en el grafo y reconstruye la adyacencia al cambiar el suelo. Para planificar su trazado usa su propio `AStarGrid2D`; el anfitrión transmite el trazado exacto al cliente. Al terminar, se limpian estas ocupaciones y se vuelve a reconstruir el mapa. Véase [la documentación del terremoto](../Eventos/Terremoto/README.md).

## Integración y diagnóstico

```text
Caso activo del jugador → estaciones pendientes → DESTINOS
Posición del jugador → celda_de_acceso()
                ↓
calcular_ruta_a_mas_cercana() → ruta_actual y estacion_sugerida
                ↓
Guía de estación y capa de diagnóstico
```

`GrafoDebugVisual` compara el mapa lógico con las mesas de la escena. En una compilación de desarrollo, **F3** muestra la cuadrícula: verde libre, azul zona segura, cian ruta, amarillo destino, rojo obstáculo fijo o mesa, naranja cajón y blanco jugador; también distingue grietas, escombros y bloqueos lógicos sin mesa. Al caminar cambia el material de las casillas de la ruta sin recrear las mallas; al cambiar el mapa reconstruye la vista. Esta capa no altera las colisiones.

| Archivo | Papel |
| --- | --- |
| `Scripts/Estructuras/grafo_piso.gd` | Cuadrícula, ocupación, BFS, alcanzabilidad y conversiones. |
| `Scripts/Mundo/grafo_debug_visual.gd` | Sincronización de huellas de muebles y vista F3. |
| `Scripts/Partida/gestor_partida.gd` | Ruta sugerida y distribución de cajones. |
| `Scripts/Red/partida_lan.gd` | Protección adicional y sincronización de celdas en LAN. |
| `Pruebas/Despacho/prueba_protocolo_libre.gd` | Ruta al destino más cercano, destino bloqueado y casos límite. |
| `Pruebas/Bloqueos/prueba_generacion_bloqueos.gd` | Accesos conservados, bordes del jugador y distribuciones parciales. |

Para ejecutar la prueba de bloqueos con Godot desde la raíz del repositorio:

```powershell
& $Godot --headless --path .\proyecto-4-semestre --script res://Pruebas/Bloqueos/prueba_generacion_bloqueos.gd
```

`$Godot` debe ser la ruta del ejecutable. La prueba de ruta también forma parte de `prueba_protocolo_libre.gd`. `Pruebas/Estructuras/prueba_grafo.gd` solo imprime un recorrido de ejemplo con coordenadas antiguas; no verifica las casillas de aproximación actuales.
