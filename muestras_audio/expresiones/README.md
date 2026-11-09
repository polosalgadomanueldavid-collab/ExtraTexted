# Expresiones del personaje: cinco propuestas de voz

Vocalizaciones originales de estilo caricaturesco, redonditas y juguetonas,
siguiendo la inspiración solicitada de Fall Guys. Son balbuceos sin palabras:
se generan mediante una fuente glotal con formantes móviles, aire y variaciones
de tono. No contienen grabaciones ni voces extraídas de otros juegos.

| Opción | Archivo | Personalidad del diseño |
| --- | --- | --- |
| 1 | `01_redondita.wav` | Voz media, redonda y nasal; alegre y equilibrada. |
| 2 | `02_traviesa.wav` | Más aguda, brillante y energética. |
| 3 | `03_bonachona.wav` | Más grave y corpulenta, con un toque ronquito. |
| 4 | `04_gomosa.wav` | Tono más ondulante y elástico. |
| 5 | `05_peluche.wav` | Más suave y aireada, con ataques menos marcados. |

Todas las muestras duran 6.1 segundos y usan las mismas cuatro expresiones,
en este orden:

1. **Saludo**: dos balbuceos ascendentes, desde 0.25 s.
2. **Esfuerzo**: pequeño impulso vocal y cierre de labios, desde 1.80 s.
3. **Sorpresa**: vocalización que sube de tono, desde 2.85 s.
4. **Alegría**: tres sílabas juguetonas, desde 4.30 s.

`00_comparativa.wav` presenta saludo y esfuerzo de cada opción, de la 1 a la 5.
Los bloques empiezan en 0, 2.5, 5, 7.5 y 10 segundos.

En `clips/` están las cuatro expresiones separadas para cada voz. Las propuestas
se conservan fuera del proyecto de Godot. La opción 4, Gomosa, fue seleccionada
y sus expresiones se copiaron a `proyecto-4-semestre/Audios/VozPersonaje/Gomosa/`.

Formato: WAV mono PCM de 16 bits a 48 kHz, sin música ni reverberación añadida.
Los niveles medidos quedan registrados en `niveles.json`.

Para regenerar:

```powershell
python herramientas/generar_propuestas_expresiones.py
```
