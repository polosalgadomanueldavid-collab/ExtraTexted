# Plan de desarrollo del multijugador de ExtraTexted

Fecha: 7 de noviembre de 2026.
Estado: diseño guardado para implementar después de las correcciones de bugs.

## Objetivo y decisiones de diseño

Crear un cooperativo inspirado en Overcooked: un equipo comparte oficina, estaciones, denuncias con tiempo límite, puntuación y calma. La coordinación surge de repartir tareas, desplazarse y decidir qué atender primero.

- **Estaciones en cualquier orden.** Cada denuncia define las estaciones que necesita; el jugador elige el recorrido. Todas deben completarse una vez.
- **Cierre automático.** La última estación pendiente resuelve el caso. No se exige volver al computador para entregarlo.
- **Un computador compartido dentro del escenario.** Cualquier jugador puede tomar una denuncia mediante una interacción breve. Nadie tiene un rol fijo de despachador.
- **Cooperación con libertad de reparto.** Los jugadores pueden atender casos distintos y ayudar en el mismo caso. El progreso pertenece a la denuncia y es compartido.
- **Conexión local cliente-servidor.** Un participante aloja la partida y también juega; los demás se conectan por LAN.
- **Base inicial propuesta:** dos jugadores, una oficina y hasta dos denuncias en proceso simultáneamente. Ampliar a cuatro jugadores después de comprobar el funcionamiento y el balance.

El computador del escenario es un objeto del juego. Para demostrar el multijugador de la rúbrica se usarán dos computadores reales conectados a la misma red.

Ejemplo: un caso necesita evidencias, verificación y reporte. Un jugador puede completar verificación primero y otro evidencias después. El caso se resuelve cuando también se completa reporte. Visitar una estación ya completada no vuelve a sumar progreso ni puntos. Si reporte puede hacerse primero, su texto debe describir la preparación del informe; el cierre se produce al terminar el conjunto.

## Relación con el laboratorio y la rúbrica

Fuente revisada en esta conversación: `C:/Users/HP/Downloads/Laboratorio.pdf`.

| Requisito | Aplicación en el plan |
| --- | --- |
| Multijugador local cliente-servidor; preferiblemente sockets | Partida LAN con anfitrión y clientes mediante ENet sobre UDP. Documentar conexión, mensajes y autoridad. |
| Árboles integrados al juego | El AVL mantiene la prioridad de las denuncias por riesgo, hora e ID; su resultado se ve en el panel y en la toma de casos. |
| Grafos integrados al juego | Calcular rutas hacia estaciones pendientes y recalcular cuando cambien los bloqueos. |
| Aleatoriedad y habilidad | Denuncias y obstáculos variables; planificación de recorridos, reparto de trabajo y coordinación. |
| Uso saludable de redes sociales, sin preguntas tipo concurso | Resolver situaciones mediante acciones y estaciones con significado educativo. |
| Inclusión, ayuda e indicaciones gráficas | Mantener accesibilidad, tutorial y avisos; distinguir jugadores y estados con texto/iconos además del color. |
| Confiabilidad y respuesta ante entradas erradas | Validar interacciones, duplicados, conexiones y desconexiones; mostrar errores comprensibles. |
| Sustentación y trabajo del equipo | Registrar contribuciones en Git y preparar una explicación que los cuatro integrantes puedan defender. |

La entrega final del documento está prevista para la semana del 16 al 20 de noviembre de 2026; la Feria Gamer, para el 26 de noviembre. Godot/GDScript requiere la justificación y demostración técnica previstas en el laboratorio para un motor/lenguaje distinto de Java o Python.

## Punto de partida del código

- `Scripts/Estructuras/denuncia.gd`: almacena `protocolo_estaciones` y `indice_estacion_actual`; actualmente representa una secuencia.
- `Scripts/SistemaDespacho.gd`: mantiene una sola `denuncia_activa_id`, actualiza tiempos y valida únicamente la próxima estación.
- `Scripts/gestor_partida.gd`: referencia un jugador, genera denuncias y bloqueos, conecta el computador y calcula la ruta a una estación.
- `Scripts/estacion.gd`: comunica la estación usada, sin identificar una denuncia concreta para varios casos simultáneos.
- `Scripts/computer.gd`: obtiene el primer jugador del grupo y controla su entrada y cámara al abrir la PC.
- `UI/panel_despacho.gd` y los indicadores: muestran una denuncia activa y el avance secuencial.
- `UI/Menus/menu_global.gd`: usa la pausa del árbol de escenas; debe adaptarse para que un menú individual no detenga o desincronice la sesión.
- `Eventos/Apagon/evento_apagon.gd`: el apagón y su reparación también necesitarán un estado compartido, con controles y efectos visuales locales por jugador.

Revisar estos puntos al comenzar: las correcciones de bugs pueden modificar el código antes de implementar el plan.

## Modelo de partida propuesto

### Denuncias y estaciones

- Cada denuncia conserva su ID, tipo, prioridad, estado, tiempo y conjunto de estaciones requeridas.
- Sustituir el índice secuencial por un conjunto de estaciones completadas. Puede representarse mediante un diccionario de IDs para evitar duplicados.
- Las estaciones pendientes se obtienen restando las completadas a las requeridas.
- Mantener los recursos de casos como plantillas y crear estado independiente para cada denuncia de la partida.
- Validar las plantillas: IDs de estación existentes, sin repeticiones y con al menos una estación requerida.
- Permitir varios casos en proceso. La toma de casos debe seleccionar una denuncia pendiente del AVL, sin volver a entregar una ya iniciada.
- Cada interacción identifica al jugador, la denuncia y la estación. El servidor comprueba que el caso sigue activo, que la estación corresponde, que el jugador está en alcance y que la tarea sigue pendiente.
- Dos jugadores pueden solicitar la misma tarea simultáneamente: solo la primera solicitud válida produce el cambio. Resolver o vencer un caso debe tener efecto una sola vez.

### Red y autoridad

- Crear un gestor de sesión persistente para alojar, conectarse, listar participantes, iniciar y abandonar la partida.
- El anfitrión decide denuncias, vencimientos, estaciones completadas, puntuación, calma, bloqueos y eventos como el apagón.
- Los clientes envían solicitudes de acción; reciben el resultado confirmado y actualizan su interfaz.
- Replicar la creación y salida de personajes con IDs estables. Cada equipo procesa entrada y cámara únicamente para su jugador local.
- Sincronizar los datos necesarios para movimiento y animación con una frecuencia medida; suavizar el movimiento remoto.
- Enviar cambios de denuncias y eventos cuando ocurran. Sincronizar el reloj de referencia para mostrar cuentas regresivas locales; el anfitrión decide el vencimiento.
- Transmitir IDs y datos simples. No enviar recursos `Denuncia`, nodos ni referencias del árbol AVL como objetos de red.
- Empezar cuando todos hayan cargado la escena y estén listos. Para la primera versión, permitir incorporarse en la sala previa y cerrar nuevas incorporaciones al iniciar.
- Si sale un cliente, retirar su personaje y liberar cualquier estación reservada. Si sale el anfitrión, mostrar el motivo y volver al menú de forma controlada.

### Interfaz, rutas e interacción

- Panel común con cola priorizada, casos en proceso, tiempo y lista de estaciones pendientes/completadas.
- Identificar claramente sobre qué caso actuará cada jugador. Una pulsación nunca debe completar una estación para todos los casos por accidente.
- Mostrar todas las estaciones pendientes del caso elegido. El grafo puede recomendar la más cercana por distancia de camino transitable; esa recomendación no obliga al jugador.
- Calcular la orientación desde cada jugador. Al generar bloqueos, proteger las posiciones ocupadas y comprobar accesibilidad a los objetivos necesarios para que nadie quede atrapado.
- La interacción con la PC debe ser breve. El menú, la cámara de PC o la reparación del circuito afectan solo a quien los usa; los demás continúan jugando.
- Mantener una sola fuente de verdad para el resultado del caso y la recompensa mostrada en ambos equipos.

## Orden de implementación

### Fase 1. Estaciones en cualquier orden

- [ ] Cambiar el estado de progreso de `Denuncia` y la validación en `SistemaDespacho`.
- [ ] Adaptar panel, protocolo visual, indicadores y rutas a varias estaciones pendientes.
- [ ] Conservar cierre automático, tiempo límite, calma y puntuación.
- [ ] Actualizar las pruebas que todavía esperan un índice secuencial.

Criterio de salida: un mismo caso puede completarse en órdenes distintos; repetir una estación o usar otra ajena al caso no produce progreso extra.

### Fase 2. Varios casos y acciones identificadas

- [ ] Sustituir la única denuncia activa global por el registro de casos en proceso.
- [ ] Añadir selección visible del caso sobre el que actúa cada jugador.
- [ ] Permitir tomar hasta dos casos desde la PC compartida y reflejarlo en el panel.
- [ ] Centralizar solicitudes de toma de casos e interacción para usar el mismo flujo en solitario y en red.

Criterio de salida: dos casos avanzan de forma independiente y pueden recibir ayuda del equipo sin mezclar estaciones ni premios.

### Fase 3. Sala LAN y jugadores

- [ ] Añadir Crear partida / Unirse por IP, nombre o identificación del jugador y estado de conexión.
- [ ] Crear la sala previa, confirmar carga y dar inicio desde el anfitrión.
- [ ] Instanciar los personajes; asignar control, cámara y UI local.
- [ ] Sincronizar movimiento y mostrar fallos de conexión comprensibles.

Criterio de salida: dos equipos reales se conectan, ven ambos personajes y cada persona controla únicamente el suyo.

### Fase 4. Partida compartida

- [ ] Ejecutar las reglas de partida y los generadores aleatorios solo en el anfitrión.
- [ ] Replicar denuncias, estaciones completadas, tiempo, puntuación, calma y resultado.
- [ ] Replicar bloqueos, apagones y reparación; adaptar las rutas a todos los jugadores.
- [ ] Adaptar PC, menús y tutorial para no congelar la sesión al abrir una interfaz individual.
- [ ] Gestionar salida de clientes, desconexión del anfitrión y regreso al menú.

Criterio de salida: una partida completa puede terminar por resolución o por pérdida de calma sin divergencias entre equipos.

### Fase 5. Balance y entrega

- [ ] Probar reparto de tareas y circulación con dos casos y dos jugadores.
- [ ] Ajustar tiempos y frecuencia de denuncias según las pruebas; evitar que el segundo jugador solo espere.
- [ ] Revisar accesibilidad, avisos, ayuda y retroalimentación visual/sonora.
- [ ] Documentar el papel del AVL, del grafo y del esquema cliente-servidor con una demostración reproducible.
- [ ] Probar el ejecutable exportado en dos computadores de la misma red.

## Pruebas de aceptación esenciales

1. Resolver todas las estaciones en varios órdenes cierra el caso una sola vez.
2. Repetir una estación, interactuar fuera de alcance o usar una estación ajena al caso no altera su progreso.
3. Dos solicitudes simultáneas para la última estación conceden una sola recompensa.
4. Una interacción tardía sobre un caso vencido no lo revive ni evita su penalización.
5. Dos jugadores que toman casos a la vez reciben resultados coherentes sin duplicar la misma toma.
6. Los dos equipos ven las mismas denuncias, estaciones completadas, puntos, calma y eventos del mapa.
7. Abrir opciones o usar la PC no bloquea a otro jugador ni detiene los temporizadores compartidos.
8. Un bloqueo conserva rutas transitables para los jugadores y sus objetivos.
9. La reparación del apagón se refleja en ambos equipos y no se completa dos veces.
10. Desconectarse y crear una nueva partida no conserva jugadores, reservas o denuncias de la sesión anterior.

## Detalles por concretar antes de desarrollar su mecánica

- **Expediente transportable:** se propuso tomarlo, dejarlo y transferirlo físicamente. Falta definir cómo encaja con dos jugadores trabajando a la vez sobre un mismo caso. Un único expediente obligatorio para cada interacción limitaría ese paralelismo. Decidir si el expediente es inicialmente una referencia compartida o si cada tarea produce objetos transportables.
- **Selección de caso:** concretar cómo el jugador elige el caso en foco y cómo otro compañero se suma; debe ser visible y rápido.
- **Duración de las estaciones:** comenzar con la interacción existente y decidir en pruebas si convienen tareas breves con progreso y ocupación exclusiva.
- **Cuatro jugadores, mandos y segundo computador dentro del mapa:** mejoras posteriores, condicionadas a las pruebas y al tiempo disponible.

## Referencias técnicas consultadas

- [Multijugador de alto nivel de Godot 4.7](https://docs.godotengine.org/en/4.7/tutorials/networking/high_level_multiplayer.html).
- [MultiplayerSpawner](https://docs.godotengine.org/en/4.7/classes/class_multiplayerspawner.html).
- [MultiplayerSynchronizer y límites de sincronización de recursos](https://docs.godotengine.org/en/4.7/classes/class_multiplayersynchronizer.html).
