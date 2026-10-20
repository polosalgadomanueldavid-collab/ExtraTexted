# Sistema de grafos para navegación del escenario

## 1. Propósito

El proyecto usa un **grafo no dirigido y no ponderado** para representar las zonas transitables del piso de la comisaría. Su función es calcular una ruta válida desde la posición actual del jugador hasta la estación requerida por la denuncia activa.

La ruta se actualiza cuando se inicia una denuncia, se completa una estación del protocolo o cambia un bloqueo temporal. Así, la navegación respeta tanto los obstáculos permanentes del mapa como los obstáculos dinámicos de la partida.

## 2. Modelado del grafo

La clase `GrafoPiso` convierte una cuadrícula de `14` columnas por `25` filas en un grafo:

| Elemento del mapa | Representación en el grafo |
|---|---|
| Celda transitable | Vértice `Vector2i(columna, fila)` |
| Paso a norte, sur, este u oeste | Arista entre dos vértices vecinos |
| Muro u obstáculo fijo | No se crea el vértice |
| Bloqueo temporal | El vértice se elimina temporalmente de la adyacencia |
| Estación del escenario | Vértice destino identificado por nombre |

No existen conexiones diagonales. Por esto, cada vértice puede tener como máximo cuatro vecinos: arriba, abajo, izquierda y derecha.

```text
Cuadrícula física                         Grafo lógico

  (2,1) ─ (3,1) ─ (4,1)                 (2,1) ─── (3,1) ─── (4,1)
    │       │       │                      │         │         │
  (2,2) ─ (3,2) ─ (4,2)       =>        (2,2) ─── (3,2) ─── (4,2)
    │       X       │                      │                   │
  (2,3) ─ (3,3) ─ (4,3)                 (2,3) ──────────── (4,3)

X = celda bloqueada: no es vértice ni puede formar aristas.
```

## 3. Estaciones registradas

Las estaciones están definidas en `GrafoPiso.DESTINOS`. Cada una se asocia a la celda donde se encuentra su objeto físico.

| Identificador | Coordenada | Uso dentro del protocolo |
|---|---:|---|
| `computador` | `(7, 0)` | Punto de despacho. |
| `evidencias` | `(13, 7)` | Recolección o análisis de evidencias. |
| `verificacion` | `(1, 7)` | Verificación de información. |
| `privacidad` | `(4, 12)` | Gestión de datos y privacidad. |
| `reporte` | `(9, 12)` | Registro o reporte del caso. |
| `bienestar` | `(1, 3)` | Atención asociada al bienestar. |

## 4. Construcción de la lista de adyacencia

`construir_adyacencia()` recorre toda la cuadrícula. Si una celda es transitable, crea una entrada en el diccionario `adyacencia` y añade únicamente sus vecinos transitables en las cuatro direcciones permitidas.

```text
Para cada celda del piso:
    si es transitable:
        crear lista de vecinos
        revisar derecha, izquierda, abajo y arriba
        agregar solo vecinos transitables
        guardar la lista en adyacencia[celda]
```

Una celda es transitable si está dentro de los límites y no figura ni en `bloqueos_fijos` ni en `bloqueos_temporales`.

## 5. Cálculo de la ruta mínima

El método `calcular_ruta(origen, destino)` implementa **Dijkstra**. Todas las aristas tienen costo `1`, porque desplazarse entre dos celdas vecinas representa un paso equivalente.

1. Asigna distancia infinita a cada vértice y `0` al origen.
2. Selecciona el vértice no visitado con menor distancia.
3. Revisa sus vecinos y mejora su distancia cuando encuentra un camino más corto.
4. Guarda en `anterior` el vértice desde el que se llegó a cada celda.
5. Al llegar al destino, reconstruye el camino retrocediendo desde destino hasta origen y luego invierte el resultado.

Si el origen o el destino no son transitables, o si no existe conexión entre ellos, retorna un arreglo vacío. Esto evita mostrar rutas que atraviesen obstáculos.

### Complejidad

La implementación actual busca linealmente el siguiente vértice de menor distancia dentro de `sin_visitar`; por eso su complejidad es `O(V² + E)`. Es adecuada para el mapa actual, cuyo máximo teórico es de `14 × 25 = 350` celdas. Una versión para mapas mucho más grandes podría reemplazar esa búsqueda por una cola de prioridad y lograr `O((V + E) log V)`.

## 6. Bloqueos dinámicos

Cada 10 segundos, `gestor_partida.gd` intenta ubicar un bloqueo temporal en una celda libre. Antes de aceptarlo, reconstruye la adyacencia y comprueba que siga existiendo una ruta hacia la estación activa.

```text
Elegir candidata libre
        ↓
Agregarla a bloqueos_temporales
        ↓
Reconstruir adyacencia
        ↓
¿Hay ruta al destino activo?
   ├── Sí: conservar bloqueo y recalcular ruta
   └── No: retirar candidata y probar otra
```

Con esta validación, un bloqueo puede obligar al jugador a tomar un desvío, pero no puede dejar imposible el protocolo que está realizando.

## 7. Integración con el flujo de juego

```text
Denuncia prioritaria activada
        ↓
Se lee la siguiente estación del protocolo
        ↓
Posición 3D del jugador → celda de origen
Estación solicitada      → celda de destino
        ↓
GrafoPiso.calcular_ruta(origen, destino)
        ↓
ruta_actual: secuencia ordenada de celdas
```

La conversión se realiza con `posicion_a_celda()` y `celda_a_posicion()`, usando el origen espacial del piso y un tamaño de celda de `0.5` unidades. Esto conecta el modelo lógico en 2D con las posiciones reales de la escena 3D.

## 8. Archivos principales

| Archivo | Responsabilidad |
|---|---|
| `Scripts/Estructuras/grafo_piso.gd` | Modelo de cuadrícula, adyacencia, Dijkstra y conversiones de coordenadas. |
| `Scripts/gestor_partida.gd` | Solicita rutas, administra bloqueos temporales y los visualiza en la escena. |
| `Pruebas/prueba_grafo.gd` | Prueba el cálculo de una ruta entre origen y destino. |

## 9. Guion breve para la sustentación

> Modelamos el piso como un grafo: cada celda transitable es un vértice y cada paso horizontal o vertical es una arista de costo uno. Cuando una denuncia exige ir a una estación, convertimos la posición del jugador y la estación a coordenadas de cuadrícula y aplicamos Dijkstra para obtener la ruta más corta. Los obstáculos fijos y temporales no forman parte de la adyacencia. Además, antes de fijar un bloqueo temporal verificamos que aún exista un camino válido, de modo que el reto cambia la ruta sin bloquear el progreso del jugador.
