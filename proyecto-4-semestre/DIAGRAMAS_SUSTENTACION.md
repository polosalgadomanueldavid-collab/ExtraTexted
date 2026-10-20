# Diagramas para diapositivas: AVL y grafo

Estos diagramas son ejemplos didácticos: muestran la lógica de las estructuras sin intentar dibujar todas las celdas del mapa ni todas las denuncias reales.

## Diapositiva: Árbol AVL de denuncias

**Idea que debe comunicar:** el árbol mantiene las denuncias ordenadas por prioridad y se rebalancea para no degradar el rendimiento.

```mermaid
flowchart TB
    R["Riesgo 4\nCaso B · altura 3"]
    I["Riesgo 5\nCaso A · más prioritario"]
    D["Riesgo 3\nCaso C · menos prioritario"]
    I1["Riesgo 5\nCaso D"]
    I2["Riesgo 4\nCaso E"]

    R -->|izquierda: atender antes| I
    R -->|derecha: atender después| D
    I --> I1
    I --> I2

    classDef prioridad fill:#ef4444,color:#fff,stroke:#991b1b;
    classDef normal fill:#2563eb,color:#fff,stroke:#1e3a8a;
    classDef menor fill:#64748b,color:#fff,stroke:#334155;
    class I,I1 prioridad;
    class R,I2 normal;
    class D menor;
```

### Texto breve para decir

> Cada nodo guarda una denuncia completa y su altura. A la izquierda van los casos que deben atenderse antes; a la derecha, los menos urgentes. Por eso, la denuncia prioritaria se obtiene recorriendo hasta el nodo más a la izquierda. Tras insertar o eliminar, el AVL revisa el factor de balance y rota cuando es necesario, manteniendo las operaciones principales en `O(log n)`.

### Rótulos sugeridos al presentar

- **Rojo:** mayor prioridad.
- **Azul:** nodo de comparación intermedio.
- **Gris:** menor prioridad.
- **Factor de balance:** `altura(izquierda) − altura(derecha)`; debe quedar entre `-1` y `1`.

## Diapositiva: Rotación AVL

**Idea que debe comunicar:** una rotación cambia la forma, no el orden de prioridades.

```mermaid
flowchart LR
    subgraph Antes[Antes: desequilibrio izquierda-izquierda]
        A5["Riesgo 3"] --> A4["Riesgo 4"]
        A4 --> A3["Riesgo 5"]
    end

    Giro["Rotación a la derecha"]

    subgraph Despues[Después: árbol balanceado]
        D4["Riesgo 4"] --> D3["Riesgo 5"]
        D4 --> D5["Riesgo 3"]
    end

    Antes --> Giro --> Despues
```

> Aunque la raíz cambia durante una rotación, el orden sigue siendo correcto: el caso de riesgo 5 permanece a la izquierda y continúa siendo el prioritario.

## Diapositiva: Grafo del piso y ruta mínima

**Idea que debe comunicar:** el mapa se transforma en nodos y conexiones; Dijkstra encuentra el camino más corto evitando obstáculos.

```mermaid
flowchart LR
    J([Jugador\nOrigen]) --- A((Celda A))
    A --- B((Celda B))
    B --- C((Celda C))
    C --- E([Estación\nDestino])
    A --- D((Celda D))
    D --- F((Celda F))
    F --- E
    B -.- X["Bloqueo temporal\nno transitable"]

    classDef ruta fill:#16a34a,color:#fff,stroke:#166534;
    classDef nodo fill:#2563eb,color:#fff,stroke:#1e3a8a;
    classDef bloqueo fill:#dc2626,color:#fff,stroke:#991b1b;
    class J,A,B,C,E ruta;
    class D,F nodo;
    class X bloqueo;
```

### Texto breve para decir

> Cada celda transitable del piso es un vértice y cada movimiento horizontal o vertical es una arista de costo uno. Los muros y bloqueos no se incluyen en la adyacencia. Dijkstra compara las distancias acumuladas y devuelve la secuencia de celdas más corta desde el jugador hasta la estación que exige el protocolo. Cuando aparece un bloqueo temporal, se reconstruye el grafo y se recalcula la ruta.

### Leyenda sugerida

- **Verde:** ruta seleccionada por Dijkstra.
- **Azul:** celdas transitables disponibles como alternativas.
- **Rojo punteado:** bloqueo que no puede ser recorrido.

## Diapositiva final: Conexión entre ambas estructuras

```mermaid
flowchart LR
    A["AVL\nSelecciona la denuncia prioritaria"] --> B["Protocolo\nIndica la siguiente estación"]
    B --> C["Grafo + Dijkstra\nCalcula la ruta más corta"]
    C --> D["Jugador\nSe desplaza por el escenario"]
```

> El AVL decide **qué caso atender primero**; el grafo decide **cómo llegar a la estación necesaria para resolverlo**.
