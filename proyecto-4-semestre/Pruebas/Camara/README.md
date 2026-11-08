# Cámara de la oficina

- **C:** alterna entre la cámara actual, una vista más frontal y la vista God desde arriba.
- **1 / 2 / 3:** elige directamente cada vista.
- **M:** activa o desactiva el balanceo ambiental. Empieza activado.

Las transiciones de posición y ángulo son suaves. El balanceo dibuja un infinito
en el plano de la pantalla cada 12 segundos, con amplitudes de 2,5 cm y 1,2 cm.
Se pueden ajustar vistas, velocidades y balanceo en el Inspector de
`Oficina/Gameplay/Camera3D`. La vista original conserva el ángulo de la escena.
Los atajos se suspenden durante la pausa, las interacciones que bloquean al
personaje y mientras otra cámara esté activa.

El techo y la pared posterior usan la capa visual 20, «Oclusores de cámara», que
la cámara de juego no dibuja para permitir la vista desde arriba y acercarse al
fondo con la vista frontal sin obstrucciones. Las colisiones se conservan.

Prueba de integración con la oficina real:

```text
Godot --headless --path <proyecto-4-semestre> --script res://Pruebas/Camara/prueba_camara.gd
```

Comprueba los atajos, las transiciones, los límites, la pausa, el movimiento en
vista cenital, la amplitud del balanceo sin deriva y la visión durante el apagón.
Para guardar capturas de las vistas, ejecuta sin `--headless` y añade
`-- --capturas`. Las imágenes quedan
en `.godot/camara_qa/`.
