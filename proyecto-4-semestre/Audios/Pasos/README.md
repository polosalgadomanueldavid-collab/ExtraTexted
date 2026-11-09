# Pasos seleccionados: opción 3, Suela de goma

Los seis archivos de `SuelaGoma/` son copias exactas de
`muestras_audio/pasos/golpes/03_suela_de_goma/` en la raíz del repositorio.
Audio original generado por `herramientas/generar_propuestas_pasos.py`:
WAV mono, PCM de 16 bits, 48 kHz, 0.28 s, sin bucle ni muestras externas.

`SonidosPasos`, hijo de las dos escenas del policía, reproduce una variación
por pisada, evitando repetir el mismo archivo consecutivamente. La separación
es de 0.45 s al caminar y 0.30 s al correr, equivalente a dos pisadas por ciclo
de las animaciones actuales. La cadencia, las pistas, el tono y su variación se
pueden ajustar en el Inspector; el volumen inicial es −9 dB.

El controlador informa del movimiento horizontal real después de las
colisiones. Solo hay pisadas en el suelo y con los controles habilitados.
Quedarse quieto, empujar contra una pared, saltar, abrir una interacción o
reiniciar detiene el sonido. La pausa congela el audio y la cadencia juntos.
La voz Gomosa sigue reproduciéndose en su propio reproductor.

Prueba de integración:

```text
Godot --headless --path <proyecto-4-semestre> --script res://Pruebas/PersonajePolicia/prueba_pasos_personaje.gd
```
