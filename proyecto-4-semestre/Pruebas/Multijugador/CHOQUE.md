# Choque de compañeros

Abre `VistaChoque.tscn` y pulsa **F6** para ver los dos personajes reales chocando en bucle. **Espacio** repite y **Escape** cierra.

La reacción dura **0,54 s**: compresión marcada, estiramiento y pequeño salto visual hacia atrás, brazos abiertos y cabeza que sigue al torso con retraso. Una segunda compresión suave devuelve el cuerpo a su pose base. Cinco trazos dorados marcan el contacto durante 0,22 s. No altera el cuerpo físico, la velocidad, el control ni la cámara. Conserva los agarres cuando hay objetos en las manos.

Las transiciones generales conservan la fase de apoyo al pasar de caminar a correr. El balanceo integra su fase y mezcla ritmo y amplitud gradualmente. El reposo y el saludo tienen fundidos más largos, el salto responde rápido y el aterrizaje absorbe el movimiento con las rodillas. La locomoción local usa desplazamiento real e histéresis para evitar alternar poses con velocidades pequeñas o caminar contra una pared.

Se activa desde las colisiones locales y el barrido del remoto en LAN; es presentación local, sin nuevos mensajes de red. Ignora roces tangenciales, contactos lentos, personajes sentados, congelados, nadando o en tareas. El contacto se rearma al separarse más de 0,82 m, con una espera mínima de 0,6 s.

Validación automática:

```powershell
Godot --headless --path proyecto-4-semestre --script res://Pruebas/Multijugador/prueba_choque.gd
Godot --headless --path proyecto-4-semestre --script res://Pruebas/PersonajePolicia/prueba_transiciones.gd
```

Para capturar un ciclo a 30 FPS, ejecuta la escena con `--fixed-fps 30 -- --capturar-choque`. Los fotogramas se guardan en `output/choque/fotogramas_v2`, fuera del control de versiones. Añade `--transiciones` para mostrar los cambios de locomoción sobre el mismo escenario; esta muestra de poses se guarda en `output/choque/transiciones`.
