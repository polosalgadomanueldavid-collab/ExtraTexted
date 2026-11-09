# Propuestas de pasos del personaje

Cinco diseños originales de pasos cortos, blandos y juguetones, inspirados en el
carácter caricaturesco solicitado. Audio sintetizado desde cero, sin muestras de
Fall Guys ni de otros juegos.

| Opción | Muestra | Carácter |
| --- | --- | --- |
| 1 | `01_gomita_ligera.wav` | Gomita ligera: golpe blando y pequeño pop elástico. |
| 2 | `02_peluche.wav` | Peluche: mullido, discreto y con textura de tela. |
| 3 | `03_suela_de_goma.wav` | Suela de goma: contacto más claro y roce breve. |
| 4 | `04_gelatina.wav` | Gelatina: plop redondo y burbujeante. |
| 5 | `05_rebote.wav` | Rebote caricaturesco: pum-boing más expresivo. |

Cada muestra dura 7 segundos: ocho pasos al caminar, una pausa y diez pasos al
trotar. Se utiliza la misma cadencia y una energía de pisada equivalente para
facilitar la comparación. Hay pequeñas diferencias de tono y fuerza, con una
alternancia estéreo muy sutil para los pies.

`00_comparativa.wav` reúne las opciones 1 a 5, en ese orden: cada opción empieza
en 0, 3.7, 7.4, 11.1 y 14.8 segundos. Todas tienen la misma frase de siete pasos.

En `golpes/` hay seis variaciones mono por opción, de 0.28 segundos cada una,
listas para integrar al decidir el diseño. Las propuestas se conservan fuera
de la carpeta de Godot. La opción 3, Suela de goma, fue seleccionada y sus seis
golpes se copiaron a `proyecto-4-semestre/Audios/Pasos/SuelaGoma/` para el juego.

Formato: WAV PCM de 16 bits a 48 kHz. Las muestras de escucha son estéreo; los
golpes individuales son mono. Sin música ni reverberación añadida. Los niveles
medidos de todos los archivos están en `niveles.json`.

Para reproducir los archivos basta un reproductor de audio. Para regenerarlos:

```powershell
python herramientas/generar_propuestas_pasos.py
```
