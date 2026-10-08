# Sistema de despacho AVL - Patrulla Digital

## 1. Propósito

El sistema de despacho administra las denuncias digitales que llegan durante la partida. Su objetivo es decidir cuál debe atender el equipo primero, conservar las denuncias pendientes ordenadas en el panel lateral y controlar el tiempo y la calma operativa.

El computador de la oficina funciona como punto de despacho: al interactuar con él, los jugadores aceptan la denuncia más prioritaria. La solución del caso ocurre después en las estaciones físicas del escenario, no en el computador.

## 2. Por qué se usa un árbol AVL

Un árbol binario de búsqueda normal puede quedar inclinado si las denuncias llegan en un orden desfavorable. En ese caso, insertar, buscar o eliminar puede tardar `O(n)`.

El AVL mantiene el árbol balanceado. Cada nodo almacena su altura y, después de insertar o eliminar, se calcula el factor de balance:

```text
factor = altura(hijo izquierdo) - altura(hijo derecho)
```

Si el factor está entre `-1` y `1`, el nodo está balanceado. Si sale de ese rango, el árbol aplica una rotación LL, RR, LR o RL. Esto conserva el orden de prioridad y mantiene inserción, búsqueda y eliminación en `O(log n)`.

## 3. Datos almacenados

### Denuncia

Cada denuncia es un recurso `Denuncia` y contiene:

| Campo | Uso |
|---|---|
| `id` | Identificador único y último desempate. |
| `titulo` y `descripcion_despacho` | Información visible para el jugador. |
| `nivel_riesgo` | Valor entre 1 y 5; determina la urgencia principal. |
| `hora_reporte` | Desempata denuncias del mismo riesgo. |
| `tiempo_limite_segundos` | Tiempo disponible antes de vencer. |
| `penalidad_calma` | Calma operativa perdida si vence. |
| `puntaje_recompensa` | Recompensa prevista al resolverla. |
| `protocolo_estaciones` | Secuencia de estaciones que debe completar el equipo. |
| `estado` | Pendiente, en proceso, resuelta o vencida. |
| `indice_estacion_actual` | Paso actual dentro del protocolo. |

### Nodo AVL

Un `NodoAVL` no guarda solamente un número: guarda una denuncia completa, referencias al hijo izquierdo y derecho, y su altura.

```text
NodoAVL
├── denuncia
├── izquierda: caso que debe atenderse antes
├── derecha: caso que debe atenderse después
└── altura
```

## 4. Regla de orden

No se suman prioridad, hora e ID. Se comparan por niveles, en este orden:

1. **Mayor nivel de riesgo**: se atiende antes.
2. **Menor hora de reporte**: si el riesgo es igual, se atiende primero quien reportó antes.
3. **Menor ID**: resuelve un empate exacto y vuelve la comparación determinista.

La función `Denuncia.va_antes_que(otra)` implementa esta comparación. Por convención del proyecto:

```text
Hijo izquierdo = denuncia más prioritaria
Hijo derecho   = denuncia menos prioritaria
```

Por tanto, la denuncia prioritaria es el nodo más a la izquierda. El recorrido **in-order** devuelve todas las denuncias desde la más urgente hasta la menos urgente y alimenta el panel lateral.

Ejemplo:

```text
             Nivel 4
            /       \
      Nivel 5       Nivel 3
```

Aunque el nivel 4 sea la raíz tras una rotación, el nivel 5 sigue siendo el prioritario porque está más a la izquierda.

## 5. Flujo de una denuncia

```text
Generador aleatorio crea una denuncia
        ↓
SistemaDespacho la inserta en el AVL
        ↓
Panel lateral recibe el recorrido in-order
        ↓
Jugador interactúa con el computador
        ↓
Se activa la denuncia más prioritaria
        ↓
Equipo cumple su protocolo en estaciones físicas
        ↓
Se resuelve o vence: se elimina del AVL y se actualiza la calma
```

El generador crea copias independientes de las plantillas `.tres`, asigna un ID único y registra la hora de llegada. Esto permite que un mismo tipo de denuncia pueda aparecer varias veces sin colisiones en el árbol.

## 6. Tiempo y calma operativa

Cada denuncia inicia su temporizador al entrar al despacho. El temporizador sigue bajando aunque el caso esté en proceso.

| Riesgo | Tiempo inicial | Penalidad si vence |
|---:|---:|---:|
| 5 - Crítica | 40 s | -30 calma |
| 4 - Alta | 55 s | -20 calma |
| 3 - Media | 70 s | -14 calma |
| 2 - Prevención | 90 s | -8 calma |
| 1 - Bienestar | 110 s | -4 calma |

- Resolver una denuncia recupera 5 puntos de calma, sin superar 100.
- Cuando la calma llega a 0, se emite la señal de fin de partida.
- Resolver o vencer una denuncia la elimina del AVL y refresca el panel.

## 7. Protocolo de estaciones

Los casos no se resuelven contestando preguntas. Cada denuncia tiene una secuencia de identificadores de estación, por ejemplo:

```text
evidencias → verificacion → privacidad → reporte
```

`SistemaDespacho.interactuar_estacion(estacion_id)` compara la estación usada con el paso esperado. Si coincide, avanza `indice_estacion_actual`; si era el último paso, resuelve el caso. Si no coincide, emite una señal de estación incorrecta.

La lógica de validación ya está implementada. La siguiente integración pendiente es crear y ubicar en el escenario los objetos físicos que representen `evidencias`, `verificacion`, `privacidad`, `reporte` y `bienestar`.

## 8. Archivos principales

| Archivo | Responsabilidad |
|---|---|
| `Scripts/Estructuras/denuncia.gd` | Modelo de una denuncia y comparación de prioridad. |
| `Scripts/Estructuras/nodo_avl.gd` | Nodo interno del árbol. |
| `Scripts/Estructuras/arbol_denuncias_avl.gd` | Inserción, búsqueda, recorrido, eliminación y rotaciones AVL. |
| `Scripts/SistemaDespacho.gd` | Temporizadores, calma, denuncia activa y validación de estaciones. |
| `Scripts/gestor_partida.gd` | Generación dinámica y conexión entre escena, computador, panel y despacho. |
| `UI/panel_despacho.gd` | Actualización visual del panel lateral. |
| `Pruebas/prueba_avl.gd` | Pruebas de orden, eliminación y las cuatro rotaciones. |

## 9. Pruebas realizadas

- Inserción de seis denuncias con diferentes niveles de riesgo.
- Validación del orden prioritario: nivel 5, 4, 3, 2, 2 y 1.
- Desempate entre denuncias de nivel 2 por hora de reporte.
- Eliminación de una denuncia y actualización de la nueva prioritaria.
- Pruebas de rotaciones LL, RR, LR y RL; la raíz resultante conserva altura 2 en los casos de tres elementos.
- Vencimiento de denuncia, aplicación de penalidad y actualización de calma.
- Resolución de denuncia y recuperación de calma.
- Panel lateral conectado al recorrido in-order, con temporizadores en tiempo real.
- Integración del computador: al abrirlo, se marca la denuncia prioritaria como `EN_PROCESO`.

## 10. Guion breve para la sustentación

> Cada nodo del AVL almacena una denuncia completa, no solo un número. La comparación prioriza primero la severidad, después la hora de reporte y, por último, el ID. Las denuncias más urgentes quedan a la izquierda; por eso el recorrido in-order alimenta el panel de mayor a menor prioridad y el nodo más a la izquierda representa el caso prioritario. El AVL realiza rotaciones para evitar que el árbol se degrade, manteniendo operaciones de inserción, búsqueda y eliminación en `O(log n)`. Cuando un caso se resuelve o vence, se elimina del árbol y el sistema actualiza tanto el panel como la calma operativa.
