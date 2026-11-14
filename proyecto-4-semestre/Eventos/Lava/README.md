# El piso es lava

Evento aleatorio de **60 segundos de juego**, exclusivo con apagón, terremoto, incendio e inundación. Durante los primeros **3 segundos**, las grietas se encienden desde el jugador y se extienden por el piso antes de aflorar la costra de magma; este aviso no quita cordura. Los seis charcos combinan **cruce fundido y costra hundida**: tres placas vecinas se funden en un núcleo con pequeñas islas de roca, y tres ramales se afinan siguiendo las grietas del suelo. Las corrientes y el calor se animan dentro de esa geometría estable. La luz cálida y las chispas aparecen progresivamente; cada nueva caída de un cajón salpica chispas en lugar de polvo.

- **Espacio** permite saltar la altura física del bloqueo **más un 10 %**: actualmente `0,91 × 1,10 = 1,001` unidades. Se mide la colisión del bloqueo y se compensa el paso físico del salto para respetar esa cima. Solo durante lava; al terminar se conserva el salto original configurado en el personaje.
- Sobre el suelo se pierde **0,70 de cordura por segundo**. Los charcos añaden **0,45/s** (total **1,15/s**). Se usa la calma operativa del HUD. Las fracciones se acumulan entre contactos, sin borrar el daño pendiente al saltar.
- El núcleo y los ramales comparten la misma máscara para dibujarse y aplicar daño adicional. Las pequeñas islas son costra caliente, no plataformas de refugio. El patrón de placas se prepara al cargar la oficina y la máscara se genera al iniciar el evento; solo el color y las corrientes se actualizan durante la partida.
- En el aire o sobre los bloqueos temporales no hay daño por lava. El personaje da un sobresalto, levanta las rodillas, rebota y agita los brazos mientras se quema. Las llamas siguen los huesos de ambos pies. La pose entra y sale suavemente; su rebote visual no añade altura al salto ni interrumpe el daño.
- Las mesas y demás muebles fijos no se pueden trepar. Durante el evento se prolonga su huella física en una capa exclusiva del personaje; las consultas de interacción y las hojas conservan sus colisiones habituales.
- Los bloqueos se redistribuyen cada **4 segundos**. Su retirada hace caer al jugador si estaba encima. Se conservan las protecciones de colocación del grafo, del personaje y del papel.
- El aviso inicial explica el salto. Arriba, centrado, queda únicamente un cronómetro circular con la cuenta `01:00 → 00:00`: números compactos en Luckiest Guy, naranja y contorno oscuro. La carcasa y los números pasan a rojo durante los últimos diez segundos. Se eliminan el cuadro rectangular, los textos de estado y la barra de redistribución.
- La pausa detiene reloj, daño, animaciones y cambios de bloqueos. Al terminar se retiran magma, charcos, chispas y barreras, se restaura el intervalo anterior (normalmente 10 s) y se programa el siguiente evento. Agotar la cordura finaliza la partida con una causa propia de lava.

## Probar

Abre `res://Pruebas/Lava/PruebaLava.tscn` y pulsa **F6**. La oficina inicia lava después de cinco segundos y conserva el flujo normal de casos. En la oficina habitual también se puede forzar con **L** mientras está visible el depurador del grafo.

Prueba automatizada con Godot 4.7:

```text
godot --headless --path proyecto-4-semestre --fixed-fps 60 --script res://Pruebas/Lava/prueba_lava.gd
```

Verifica la entrada gradual sin daño, las transiciones de la quemadura, la altura exacta del salto y el aterrizaje con física real, refugio y caída al reciclar el apoyo, daño en el núcleo, ramales e islas y ausencia de daño extra en la roca contigua, barreras sobre los muebles, pausa, minuto completo, cambios reales a los 4 segundos, restauración, repetición y final de partida por calor. El anuncio de suelo enfriado no incluye subtítulo de salto ni de intervalos.
