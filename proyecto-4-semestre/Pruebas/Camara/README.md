# Cámara de la oficina

- **C:** alterna entre la cámara actual, una vista más frontal y la vista God desde arriba.
- **1 / 2 / 3:** elige directamente cada vista.
- **Opciones → Accesibilidad:** activa o desactiva el balanceo ambiental. Empieza activado y se guarda entre partidas.

Las transiciones de posición y ángulo son suaves. El balanceo dibuja un infinito
en el plano de la pantalla cada 10 segundos, con amplitudes de 12 cm y 6 cm.
Se pueden ajustar vistas, velocidades y amplitud del balanceo en el Inspector de
`Oficina/Gameplay/Camera3D`. El estado del balanceo se controla desde Accesibilidad.
La vista original conserva el ángulo de la escena.
Los atajos se suspenden durante la pausa, las interacciones que bloquean al
personaje y mientras otra cámara esté activa.

El techo usa la capa visual 20, «Oclusores de cámara», que la cámara de juego
no dibuja. La pared posterior vuelve a la capa normal y se ve desde arriba.

La zona segura limita la posición real de la cámara dentro de las paredes,
incluidos el balanceo y los cuadros intermedios al cambiar de vista. Cuando
la cámara queda por encima de los muros, proyecta las cuatro esquinas del
encuadre sobre su coronación y reserva el espacio necesario a cada lado.
También ajusta la altura en ventanas especialmente anchas. Al detenerse cerca
del fondo, la vista se inclina para conservar al personaje en pantalla.
`recinto_visible`, `margen_pared` y `altura_pared` se ajustan en el Inspector
si cambia la geometría de la oficina; `zona_segura_activa` permite desactivarla.

Prueba de integración con la oficina real:

```text
Godot --headless --path <proyecto-4-semestre> --script res://Pruebas/Camara/prueba_camara.gd
```

Comprueba los atajos, las transiciones, los límites, la pausa, el movimiento en
vista cenital, la amplitud del balanceo sin deriva y la visión durante el apagón.
Recorre además las cuatro esquinas en 16:9, 4:3, 21:9 y 32:9 y comprueba con
rayos físicos que los bordes del encuadre no muestran el exterior durante las
transiciones, y que el personaje permanece en pantalla.
Para guardar capturas de las vistas, ejecuta sin `--headless` y añade
`-- --capturas`. Las imágenes quedan
en `.godot/camara_qa/`.
