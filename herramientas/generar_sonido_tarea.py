"""Crea el efecto original de lápiz y confirmación, sin muestras externas."""

import math
import random
import struct
import wave
from pathlib import Path


FRECUENCIA = 48000
DURACION = 1.1
DESTINO = Path(__file__).resolve().parents[1] / "proyecto-4-semestre/Audios/tarea_completada.wav"


def generar() -> None:
    azar = random.Random(7419)
    canales = [[], []]
    ruido_grave = 0.0
    ruido_agudo = 0.0
    for indice in range(round(FRECUENCIA * DURACION)):
        t = indice / FRECUENCIA
        ruido = azar.uniform(-1.0, 1.0)
        ruido_grave += 0.075 * (ruido - ruido_grave)
        ruido_agudo += 0.72 * (ruido - ruido_agudo)
        lapiz = ruido_agudo - ruido_grave
        muestra = 0.0
        for inicio, duracion, volumen in [(0.015, 0.10, 0.19), (0.13, 0.20, 0.24), (0.28, 0.39, 0.12)]:
            u = (t - inicio) / duracion
            if 0.0 < u < 1.0:
                envolvente = math.sin(math.pi * u) ** 1.3
                textura = 0.65 + 0.35 * math.sin(math.tau * (83 * t + 18 * t * t)) ** 2
                muestra += lapiz * envolvente * textura * volumen
        # Dos notas ascendentes suaves cuando termina la marca de verificación.
        for inicio, frecuencia, volumen in [(0.35, 659.25, 0.20), (0.49, 987.77, 0.17)]:
            u = t - inicio
            if u > 0.0:
                ataque = min(1.0, u / 0.008)
                cuerpo = math.sin(math.tau * frecuencia * u) * math.exp(-u * 9)
                brillo = 0.23 * math.sin(math.tau * frecuencia * 2 * u) * math.exp(-u * 17)
                muestra += (cuerpo + brillo) * ataque * volumen
        # Pequeño toque de papel al apoyar el lápiz, sin golpe grave invasivo.
        toque = t - 0.325
        if 0 < toque < 0.045:
            muestra += (lapiz * 0.09 + math.sin(math.tau * 235 * toque) * 0.04) * math.exp(-toque * 100)
        muestra *= min(1.0, t / 0.006, (DURACION - t) / 0.04)
        paneo = 0.12 * math.sin(math.tau * (t - 0.13))
        canales[0].append(muestra * (1.0 - paneo))
        canales[1].append(muestra * (1.0 + paneo))

    pico = max(max(abs(muestra) for muestra in canal) for canal in canales)
    ganancia = 0.68 / pico
    datos = bytearray()
    for izquierda, derecha in zip(*canales):
        datos.extend(struct.pack("<hh", round(izquierda * ganancia * 32767), round(derecha * ganancia * 32767)))
    DESTINO.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(DESTINO), "wb") as archivo:
        archivo.setnchannels(2)
        archivo.setsampwidth(2)
        archivo.setframerate(FRECUENCIA)
        archivo.writeframes(datos)
    print(f"Sonido original: {DESTINO} ({DURACION:.1f} s, estéreo, {FRECUENCIA} Hz)")


if __name__ == "__main__":
    generar()
