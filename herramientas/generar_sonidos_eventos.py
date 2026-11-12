"""Efectos originales de terremoto y apagón, sin muestras de terceros.

Genera WAV estéreo PCM de 48 kHz. Los ambientes usan un fundido circular
para poder repetirse sin chasquidos; los impactos tienen entrada/salida suave.
"""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 48000
DESTINO = Path(__file__).resolve().parents[1] / "proyecto-4-semestre/Audios/Eventos"


def golpe(t, inicio, duracion, frecuencia, ruido):
    u = t - inicio
    if not 0 < u < duracion:
        return 0.0
    return (math.sin(math.tau * frecuencia * u) * 0.6 + ruido * 0.4) * (
        1 - math.exp(-u * 800)
    ) * math.exp(-u * 6 / duracion)


def forma(tipo, t, ruido, grave):
    if tipo == "terremoto_retumbo":
        oleaje = 0.65 + 0.19 * math.sin(math.tau * 0.5 * t) + 0.13 * math.sin(math.tau * 0.83 * t)
        return oleaje * (grave * 4.8 + 0.18 * math.sin(math.tau * 41 * t)
                         + 0.11 * math.sin(math.tau * 67 * t + 0.8 * math.sin(t * 4)))
    if tipo == "terremoto_crujidos":
        valor = grave * 0.12
        for i, inicio in enumerate([0.13, 0.57, 1.11, 1.44, 2.21, 2.88, 3.34, 4.17, 4.62]):
            valor += golpe(t, inicio, 0.14 + i % 3 * 0.13, 120 + i * 37, ruido)
        return valor
    if tipo == "terremoto_ruptura":
        return (golpe(t, 0.015, 1.6, 46, grave * 5)
                + golpe(t, 0.06, 0.7, 125, ruido)
                + sum(golpe(t, i * 0.09, 0.3, 280 + i * 43, ruido) * 0.3 for i in range(2, 9)))
    if tipo == "terremoto_cierre":
        return grave * 3 * math.sin(math.pi * t / 0.55) ** 2 + golpe(t, 0.36, 0.18, 84, ruido) * 0.5
    if tipo == "apagon_corte":
        caida = max(0, 1 - t / 0.9)
        motor = math.sin(math.tau * (180 * t - 80 * t * t)) * 0.26 * caida ** 2
        rele = golpe(t, 0.012, 0.16, 95, ruido) + golpe(t, 0.07, 0.13, 730, ruido) * 0.42
        chispa = ruido * math.exp(-t * 32) * (0.5 + 0.5 * math.sin(t * 880))
        return motor + rele + chispa
    # Zumbido tenue de emergencia y aviso distante, espaciado cada cuatro segundos.
    fase = t % 4
    aviso = math.sin(math.tau * 660 * t) * math.sin(math.pi * fase / 0.24) ** 2 if fase < 0.24 else 0
    return (0.12 * math.sin(math.tau * 60 * t) + grave * 0.9
            + 0.025 * math.sin(math.tau * 180 * t)) * (0.8 + 0.2 * math.sin(math.tau * 0.25 * t)) + aviso * 0.09


def generar(nombre, duracion, pico, bucle, semilla):
    canales = []
    for canal in range(2):
        azar = random.Random(semilla + canal)
        grave = 0.0
        muestras = []
        for i in range(round(RATE * duracion)):
            t = i / RATE
            ruido = azar.uniform(-1, 1)
            grave += 0.013 * (ruido - grave)
            muestra = forma(nombre, t, ruido, grave)
            if not bucle:
                muestra *= min(1.0, t / 0.005, (duracion - t) / 0.025)
            muestras.append(muestra)
        if bucle:
            solape = round(RATE * 0.08)
            for i in range(solape):
                peso = i / solape
                muestras[i] = muestras[-solape + i] * (1 - peso) + muestras[i] * peso
            muestras = muestras[:-solape]
        canales.append(muestras)
    ganancia = pico / max(abs(x) for canal in canales for x in canal)
    datos = bytearray()
    for par in zip(*canales):
        datos.extend(struct.pack("<hh", *(round(x * ganancia * 32767) for x in par)))
    with wave.open(str(DESTINO / f"{nombre}.wav"), "wb") as archivo:
        archivo.setnchannels(2)
        archivo.setsampwidth(2)
        archivo.setframerate(RATE)
        archivo.writeframes(datos)
    print(f"{nombre}: {len(canales[0]) / RATE:.2f} s")


if __name__ == "__main__":
    DESTINO.mkdir(parents=True, exist_ok=True)
    for i, parametros in enumerate([
        ("terremoto_retumbo", 6.08, 0.8, True),
        ("terremoto_crujidos", 5.08, 0.7, True),
        ("terremoto_ruptura", 1.8, 0.85, False),
        ("terremoto_cierre", 0.55, 0.65, False),
        ("apagon_corte", 1.2, 0.8, False),
        ("apagon_ambiente", 8.08, 0.5, True),
    ]):
        generar(*parametros, 7310 + i * 13)
