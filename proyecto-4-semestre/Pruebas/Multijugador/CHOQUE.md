# Choque de compañeros

Abre `VistaChoque.tscn` y pulsa **F6** para ver los dos personajes reales chocando en bucle. **Espacio** repite y **Escape** cierra.

La reacción dura **0,42 s**: compresión suave, cabeza y torso hacia atrás, brazos sorprendidos y un único rebote amortiguado. Cinco trazos dorados marcan el contacto durante 0,22 s. No altera el cuerpo físico, la velocidad, el control ni la cámara. Conserva los agarres cuando hay objetos en las manos.

Se activa desde las colisiones locales y el barrido del remoto en LAN; es presentación local, sin nuevos mensajes de red. Ignora roces tangenciales, contactos lentos, personajes sentados, congelados, nadando o en tareas. El contacto se rearma al separarse más de 0,82 m, con una espera mínima de 0,6 s.

Validación automática:

```powershell
Godot --headless --path proyecto-4-semestre --script res://Pruebas/Multijugador/prueba_choque.gd
```

Para capturar un ciclo a 30 FPS, ejecuta la escena con `--fixed-fps 30 -- --capturar-choque`. Los fotogramas se guardan en `output/choque/fotogramas`, fuera del control de versiones.
