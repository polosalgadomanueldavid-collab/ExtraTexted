# Revisión del multijugador — 14 de noviembre de 2026

## Dictamen

La base permite empezar la implementación del cooperativo LAN de dos jugadores. Todavía no permite convertir la partida actual en una sesión compartida simplemente añadiendo conexión y sincronización de posiciones. Conviene preparar primero las acciones y el estado de partida, conservando el modo individual como prueba de regresión.

La revisión corresponde al árbol de trabajo actual, incluidos los cambios locales de descanso y bolsillo. No se implementó red ni se probó una sesión entre dos equipos.

## Base que se puede reutilizar

- Denuncias identificadas por ID, progreso por estaciones, rechazo de estaciones repetidas y cierre automático en `Scripts/Estructuras/denuncia.gd` y `Scripts/Despacho/SistemaDespacho.gd`.
- AVL de prioridad, puntuación y calma separados en componentes; señales para actualizar la interfaz.
- Hoja física con ID del caso y portador en `Scripts/Despacho/papel_denuncia.gd`.
- Grafo de navegación y protección de accesos al distribuir bloqueos.
- Eventos con métodos de inicio, resolución y limpieza, más escenas y pruebas de integración existentes.

## Adaptaciones necesarias

| Área | Evidencia actual | Cambio necesario |
| --- | --- | --- |
| Sesión | No aparecen RPC, ENet, MultiplayerSpawner ni MultiplayerSynchronizer en los scripts y escenas revisados. Los autoloads son accesibilidad y menú. | Gestor persistente de sesión, sala, carga coordinada, altas/bajas de personajes y errores de conexión. |
| Jugadores | `gestor_partida.gd` toma un solo personaje desde `$Gameplay/Node3D`; `policia_azul.gd` lee `Input` directamente. | Registro por ID de jugador; entrada, cámara, audio e interfaz locales; movimiento y animaciones remotas. |
| Casos | `SistemaDespacho.denuncia_activa_id` es único; `interactuar_estacion(estacion_id)` no recibe caso ni jugador; el gestor conserva un `papel_actual`. | Registro de casos en proceso, hojas por caso y solicitudes con jugador, caso y estación explícitos. |
| Autoridad | Temporizadores, generación aleatoria, puntuación y resolución se ejecutan localmente. | El anfitrión confirma cambios; los clientes solicitan acciones. Validar alcance, portador, disponibilidad, coste y duplicados antes de modificar el estado. |
| Objetos y estaciones | La hoja es un RigidBody3D con referencia local al portador; los minijuegos y tareas pendientes viven en el gestor único. | IDs estables, recogida y entrega exclusivas, ocupación de estaciones y liberación al desconectarse. Replicar el resultado confirmado de cada tarea. |
| Pausa y tutorial | `menu_global.gd` detiene todo el árbol al abrir pausa y guías. | Menús personales sin congelar el mundo compartido, o una política explícita de pausa coordinada. |
| Eventos y poderes | La inundación guarda `_jugador` y rechaza a otro jugador; los poderes de descanso desactivan procesamiento local para detener el tiempo. | Estado común del evento, efectos por personaje y reparación con usuario identificado. Definir y sincronizar el alcance de los poderes. |
| Navegación | `_cambiar_bloqueo_temporal()` protege la huella y las rutas de un personaje y una hoja. | Proteger a todos los jugadores y objetos necesarios antes de confirmar la distribución. |

## Orden recomendado

1. Permitir dos casos independientes y centralizar las solicitudes de interacción. Mantener la partida individual funcionando con ese mismo flujo.
2. Incorporar sala LAN para dos jugadores, control local y movimiento remoto. Usar ENet y la API multijugador de alto nivel de Godot.
3. Compartir una partida básica: tomar hojas, completar estaciones, vencer casos y actualizar una sola puntuación y calma.
4. Adaptar eventos, poderes, pausas, tutoriales, navegación y desconexiones. Añadirlos de forma gradual a la partida básica ya sincronizada.
5. Verificar ejecutables en dos equipos reales: acciones simultáneas, doble recogida, cierre de caso una sola vez, salida durante una reparación y nueva sesión limpia.

El plan existente en `PLAN_MULTIJUGADOR.md` sigue siendo útil; su inventario de eventos debe ampliarse para cubrir incendio, inundación, lava, hielo, terremoto y poderes actuales. Dos casos simultáneos son parte del cooperativo propuesto, aunque no sean un requisito técnico para una primera prueba de conexión.

Referencia técnica consultada: [multijugador de alto nivel de Godot](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html), que documenta ENet, identificación de participantes, autoridad y RPC. La elección del orden de migración es una recomendación basada en este código.

## Verificación realizada

- `Pruebas/Despacho/prueba_protocolo_libre.gd`: 50 órdenes, 1.300 comprobaciones, cero errores.
- `Pruebas/prueba_integracion_eventos.gd`: cero errores.
- `Pruebas/Inundacion/prueba_inundacion.gd`, con renderizado y capturas: un fallo tanto antes como después del cambio visual. La comprobación que falla es «Saludo, menú y poderes muestran el mensaje solicitado». El resto de las comprobaciones, incluida reparación, drenaje y restauración, pasa.
- Causa observada del fallo: `policia_azul.gd::_input()` atiende la apertura de la ruleta de emotes y retorna antes de alcanzar el rechazo por natación. Debe corregirse o aclararse el comportamiento esperado antes de declarar verde la suite.
- Se revisó visualmente el nuevo anuncio de inundación a 1280 × 720. Dice «REPARA LA TUBERÍA», con el estilo de cómic existente, fondo turquesa e indicación de la válvula en descanso.
- El motor también emite advertencias de UIDs de recursos externos y efectos no compatibles con el renderizador Compatibility. No impidieron estas ejecuciones; esta revisión no certifica rendimiento ni cubre toda la suite.
