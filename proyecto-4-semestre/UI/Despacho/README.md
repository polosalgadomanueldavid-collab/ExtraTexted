# Barra lateral de denuncias

HUD exclusivo de `res://UI/PanelDespacho.tscn`: fondo general transparente,
tarjetas crema compactas, acentos laterales por riesgo y fuente Luckiest Guy
reutilizada del menú. No modifica el despacho, el AVL, las estaciones ni los menús.

- El reloj activo vacía la arena según `tiempo_restante / tiempo_limite_segundos`.
  El flujo de granos se anima mientras el caso está activo y se congela con la pausa.
- Los iconos de los casos en espera son estáticos; sus números siguen mostrando
  el tiempo real. Al aceptar el siguiente caso se usa su tiempo restante actual.
- El protocolo admite la cantidad real de estaciones y cambia el icono de actividad
  (carpeta, lupa, candado, documento o corazón) según la estación actual.
- El HUD escala desde 1920×1080 sin alterar el mundo; la cola permite desplazamiento
  cuando no cabe y no captura el foco del teclado.

## Comprobación

Ejecutar con F6 `UI/Despacho/Pruebas/PruebaBarraLateral.tscn`.
Por CLI, añadir `--headless` para pruebas funcionales o `-- --capturas` para
capturas renderizadas en `.godot/barra_lateral_qa/`.
Comprueba transición de caso, arena sincronizada, espera inmóvil, pausa real de
la oficina, vencimiento, actividad, protocolos largos y cinco resoluciones.
