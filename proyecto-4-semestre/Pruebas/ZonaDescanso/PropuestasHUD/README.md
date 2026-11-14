# Propuestas de preview del bolsillo

Bocetos de diseño aislados de la partida. No cambian el HUD ni añaden controles.

Reutilizan la hoja aprobada, los modelos de producto de `panel_expendedora.gd`, las fuentes Luckiest Guy/Nunito y la paleta crema, coral y azul petróleo. Las tres propuestas se sitúan junto a la hoja, en el borde inferior izquierdo, en una referencia de 1280 × 720.

- **A — Medallones:** cuatro objetos con marcos independientes, cantidad y atajos Z/X/V/N. La opción más cercana al indicador actual de la hoja. En producción, solo aparecen objetos disponibles o con efecto activo.
- **B — Destacado y reservas:** el último objeto recogido o activado ocupa el medallón grande; tres reservas conservan sus atajos. El nombre y el efecto tienen espacio propio. No requiere añadir una tecla de selección.
- **C — Bandeja de bolsillo:** agrupa cuatro casillas en una tarjeta crema. Ofrece una silueta más compacta, a cambio de cubrir una superficie continua del escenario.

Estados ilustrados: cuatro objetos disponibles; chocolate consumido con 17 s de efecto restante. El estado activo usa menta y tiempo restante en vez de la instrucción de uso. Avatar mostraría «LISTO» con carga y «SIN EVENTO» cuando todavía no puede activarse; los objetos consumidos desaparecerían tras terminar su efecto. Los bocetos no simulan esas reglas.

Ejecutar Godot con `--path <proyecto> --script res://Pruebas/ZonaDescanso/PropuestasHUD/renderizar_propuestas.gd` sin `--headless`. Produce seis capturas y cuatro iconos de los modelos en `.godot/propuestas_hud_objetos`. El script congela la oficina de demostración para comparar las propuestas sobre el mismo fondo.

La integración responsive, las transiciones y la conexión al inventario quedan para la alternativa elegida.
