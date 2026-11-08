# Sonidos de las mesas

## Papel: Kenney, CC0

Grabaciones del paquete **RPG Audio** de Kenney, sin modificar:

| Archivo del juego | Archivo original |
| --- | --- |
| pasar_hoja_1.ogg | OGG/bookFlip1.ogg |
| pasar_hoja_2.ogg | OGG/bookFlip2.ogg |
| pasar_hoja_3.ogg | OGG/bookFlip3.ogg |
| archivar_hoja.ogg | OGG/bookPlace1.ogg |

Autor: Kenney (www.kenney.nl).
Licencia: Creative Commons Zero / dominio público, incluida en `Kenney-LICENSE.txt`.
Fuente del autor: https://kenney.nl/assets/rpg-audio
Publicación del autor: https://opengameart.org/content/50-rpg-sound-effects
Archivo descargado: https://opengameart.org/sites/default/files/RPGsounds_Kenney.zip

## Mecanismos: síntesis original

Los ocho archivos WAV se generan de forma determinista con
`python herramientas/generar_sonidos_mesas.py`, sin muestras externas.
Son mono PCM de 16 bits a 48 kHz. Los bucles del escáner y del desencriptado
se configuran en `UI/Despacho/sonidos_mesas.gd`.

El ciclo del escáner dura `2 / 0.55` segundos: una ida y una vuelta de la luz.
El motor se detiene durante la entrada del panel, un fallo y al cerrarlo.
Las pistas siguen el bus Master y se pausan con el juego. Ninguna se reproduce
de forma automática al cargar la oficina.
