# Zona de descanso

La oficina instancia `ZonaDescanso.tscn` junto a la pared lateral. Conserva los modelos del Furniture Pack y deja libre el hueco de la futura expendedora.

- **E frente a la cafetera:** prepara una taza en 1,8 segundos. Cobra 50 puntos al entregarla; **Esc** permite cancelar antes sin cobro. Requiere luz, calma menor a 100 y no llevar un papel u otro café.
- **F llevando café:** toma el café, recupera hasta 15 de calma y devuelve la taza vacía al mueble. Puede beberse de pie o sentado.
- **E frente al sofá:** se sienta en el tramo más cercano. Recupera 1 de calma cada 2 segundos. **E o Esc** permiten levantarse hacia un punto libre.

Los casos continúan durante la preparación y el descanso. La pausa global congela estas acciones. Reiniciar o salir limpia gestos, taza y colisiones; no reembolsa cafés ya entregados ni recupera calma después de terminar la partida.

`zona_descanso.gd` expone el precio, la recuperación y los tiempos para ajustar el equilibrio desde el inspector. El saldo gastable está separado del puntaje ganado para la clasificación. Las tazas blanca y amarilla se alternan y usan el anclaje de la mano derecha del personaje.

Los sonidos de `Audios/Descanso` son síntesis originales PCM mono: preparación de 1,8 s y sorbo de 0,7 s. Se pausan con la partida.

Validación: ejecutar Godot con `--headless --fixed-fps 60 --script` y una de estas rutas:

- `res://Pruebas/ZonaDescanso/prueba_interacciones_descanso.gd`
- `res://Pruebas/ZonaDescanso/prueba_economia_descanso.gd`
- `res://Pruebas/ZonaDescanso/prueba_zona_descanso.gd`

La herramienta `Editor/hornear_sofa_l.gd` genera las dos mallas recortadas del sofá. Se usa fuera de la partida; el juego carga únicamente las mallas horneadas y tres colisiones de caja.
