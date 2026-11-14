"""Crepitar y extintor originales, PCM mono 48 kHz; sin muestras externas."""
import math
import random
import struct
import wave
from pathlib import Path

DESTINO = Path(__file__).resolve().parents[1] / 'proyecto-4-semestre/Audios/Eventos'
RATE = 48000


def generar(nombre, semilla):
    azar = random.Random(semilla)
    lento = 0.0
    chispa = 0.0
    muestras = []
    for i in range(RATE * 4 + 3840):
        t = i / RATE
        ruido = azar.uniform(-1, 1)
        lento += (ruido - lento) * 0.045
        if nombre == 'incendio_fuego':
            if azar.random() < 0.00032:
                chispa = azar.uniform(0.3, 0.9)
            chispa *= 0.994
            valor = lento * (1.5 + 0.4 * math.sin(math.tau * 0.75 * t)) + ruido * chispa
        else:
            valor = (ruido * 0.28 + lento * 1.3) * (0.85 + 0.05 * math.sin(math.tau * 3 * t))
        muestras.append(valor)
    # Empalme circular para que el bucle no haga clic.
    for i in range(3840):
        peso = i / 3840
        muestras[i] = muestras[-3840 + i] * (1 - peso) + muestras[i] * peso
    muestras = muestras[:-3840]
    ganancia = 0.7 / max(abs(x) for x in muestras)
    with wave.open(str(DESTINO / (nombre + '.wav')), 'wb') as archivo:
        archivo.setnchannels(1)
        archivo.setsampwidth(2)
        archivo.setframerate(RATE)
        archivo.writeframes(b''.join(struct.pack('<h', round(x * ganancia * 32767)) for x in muestras))


if __name__ == '__main__':
    DESTINO.mkdir(parents=True, exist_ok=True)
    generar('incendio_fuego', 7351)
    generar('incendio_extintor', 7352)
