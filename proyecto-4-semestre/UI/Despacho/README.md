# Barra lateral de denuncias

HUD exclusivo de `res://UI/PanelDespacho.tscn`: fondo general transparente,
tarjetas crema compactas, acentos laterales por riesgo y fuente Luckiest Guy
reutilizada del menú. No modifica el despacho, el AVL, las estaciones ni los menús.

- La tarjeta **PUNTOS** permanece visible aunque no haya casos. Muestra el saldo
  de la partida, separadores de miles y un aviso `+N PTS` durante tres segundos
  después de obtener una recompensa; el aviso se congela con la pausa.
- La tarjeta del caso activo muestra su recompensa prevista **AL RESOLVER**.
  Por defecto corresponde a 100 puntos por nivel de riesgo (100 a 500); un valor
  positivo en `Denuncia.puntaje_recompensa` permite ajustar un caso concreto.
- El saldo se consulta en `SistemaDespacho.puntuacion.puntos` y se actualiza
  mediante su señal `puntos_actualizados`. Cada nueva oficina crea su propio
  sistema, con saldo inicial cero. El HUD también admite cambiar de sistema
  sin conservar conexiones o avisos de la partida anterior.
- El reloj activo vacía la arena según `tiempo_restante / tiempo_limite_segundos`.
  El flujo de granos se anima mientras el caso está activo y se congela con la pausa.
- Los iconos de los casos en espera son estáticos; sus números siguen mostrando
  el tiempo real. Al aceptar el siguiente caso se usa su tiempo restante actual.
- El protocolo admite la cantidad real de estaciones y cambia el icono de actividad
  (carpeta, lupa, candado, documento o corazón) según la estación actual.
- El HUD escala desde 1920×1080 sin alterar el mundo; la cola permite desplazamiento
  cuando no cabe y no captura el foco del teclado.

La puntuación se acumula al resolver el caso completo; avanzar estaciones o
dejar vencer un caso no concede puntos. El canje y los efectos sobre el mapa
se incorporarán en una etapa posterior.

## Comprobación

Ejecutar con F6 `UI/Despacho/Pruebas/PruebaBarraLateral.tscn`.
Por CLI, añadir `--headless` para pruebas funcionales o `-- --capturas` para
capturas renderizadas en `.godot/barra_lateral_qa/`.
Comprueba transición de caso, arena sincronizada, espera inmóvil, pausa real de
la oficina, vencimiento, actividad, protocolos largos y cinco resoluciones.

Las pruebas de puntuación se ejecutan con F6 en
`Pruebas/Puntuacion/PruebaPuntuacion.tscn` (lógica, pausa y nueva partida real)
y `Pruebas/Puntuacion/PruebaInterfazPuntuacion.tscn` (HUD, conexiones y cinco
resoluciones de pantalla). También admiten CLI:

```text
Godot --headless --path proyecto-4-semestre res://Pruebas/Puntuacion/PruebaPuntuacion.tscn
Godot --headless --path proyecto-4-semestre res://Pruebas/Puntuacion/PruebaInterfazPuntuacion.tscn
```

La escena de interfaz admite `-- --capturas` al ejecutarse sin `--headless`,
para guardar imágenes en `.godot/puntuacion_qa/`.
