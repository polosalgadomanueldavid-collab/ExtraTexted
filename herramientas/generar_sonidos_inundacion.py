"""Agua y salpicaduras originales sintetizadas, sin muestras externas."""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 24000
DESTINO = Path(__file__).resolve().parents[1] / "proyecto-4-semestre/Audios/Eventos"


def generar(nombre, duracion, bucle, semilla):
    azar = random.Random(semilla)
    muestras = []
    suave = 0.0
    burbujas = [(azar.uniform(0, duracion), azar.uniform(280, 760)) for _ in range(35 if bucle else 7)]
    for i in range(round(duracion * RATE)):
        t = i / RATE
        ruido = azar.uniform(-1, 1)
        suave += 0.12 * (ruido - suave)
        envolvente = 0.65 + 0.2 * math.sin(math.tau * t / 2) if bucle else (1 - math.exp(-t * 90)) * math.exp(-t * 7)
        valor = suave * envolvente
        for inicio, frecuencia in burbujas:
            u = t - inicio
            if 0 < u < 0.12:
                valor += 0.07 * math.sin(math.tau * (frecuencia * u - 250 * u * u)) * math.sin(math.pi * u / 0.12) ** 2
        if not bucle:
            valor *= min(1, (duracion - t) / 0.08)
        muestras.append(valor)
    if bucle:
        solape = int(RATE * 0.12)
        for i in range(solape):
            peso = i / solape
            muestras[i] = muestras[-solape + i] * (1 - peso) + muestras[i] * peso
        muestras = muestras[:-solape]
    ganancia = 0.7 / max(abs(x) for x in muestras)
    with wave.open(str(DESTINO / f"{nombre}.wav"), "wb") as salida:
        salida.setnchannels(1)
        salida.setsampwidth(2)
        salida.setframerate(RATE)
        salida.writeframes(b"".join(struct.pack("<h", round(x * ganancia * 32767)) for x in muestras))


if __name__ == "__main__":
    DESTINO.mkdir(parents=True, exist_ok=True)
    generar("inundacion_agua", 6.12, True, 4417)
    generar("inundacion_salpicadura", 0.8, False, 4421)
