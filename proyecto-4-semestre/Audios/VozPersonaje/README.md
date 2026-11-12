# Voz del personaje: opción 4, Gomosa

Saludo, esfuerzo, sorpresa y alegría son copias exactas de
`muestras_audio/expresiones/clips/04_gomosa/`, creados con
`herramientas/generar_propuestas_expresiones.py` en la raíz del repositorio.
La expresión de estrés usa el mismo sintetizador y la voz Gomosa, con dos
jadeos cortos y una exhalación temblorosa. Las cinco pistas son mono a
48 kHz, en PCM de 16 bits y sin bucle.

| Expresión | Cuándo suena |
| --- | --- |
| Saludo | Al ejecutar `play_wave()`, incluido el botón del laboratorio. |
| Esfuerzo | Al iniciar un salto válido desde el suelo. |
| Sorpresa | Una vez al empezar un apagón; cerrar su panel no la repite. |
| Alegría | Al completar una estación válida del protocolo de denuncia. |
| Estrés | Al comenzar el aviso de terremoto o el evento de incendio. |

Las escenas `Personajes/PoliciaAzul/Policia.tscn` y `Personajes/PoliciaAzul/PoliciaAzul.tscn` incorporan
un hijo `VozPersonaje`. Selecciónalo en el Inspector para cambiar las cinco
pistas, `tono_base`, `variacion_tono`, `pausa_minima`, `habilitada` y el
`volume_db` del reproductor. Valores iniciales: tono 1.0, variación 2 %, pausa
0.15 s y volumen −5 dB. La voz utiliza el bus Master y se pausa con el juego.

Solo hay una expresión a la vez. Estrés, alegría y sorpresa pueden interrumpir una
expresión de prioridad menor; pulsar repetidamente no reinicia la misma voz.
No se habla automáticamente al aparecer, caminar, correr o volver al centro.
El reinicio detiene la expresión que estuviera sonando.

El controlador expone `reproducir_expresion(&"saludo")` (o `esfuerzo`, `sorpresa`,
`alegria`, `estres`) para otras acciones futuras. Los pasos usan la opción 3, Suela de
goma, en su reproductor independiente; ver `Audios/Pasos/README.md`.

Prueba de integración:

```text
Godot --headless --path <proyecto-4-semestre> --script res://Pruebas/PersonajePolicia/prueba_voz_personaje.gd
```
