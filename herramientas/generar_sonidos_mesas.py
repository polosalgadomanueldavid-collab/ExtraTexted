"""Sintetiza mecanismos de oficina originales; el papel usa Foley de Kenney CC0."""

import math
import random
import struct
import wave
from pathlib import Path


FRECUENCIA = 48000
DESTINO = Path(__file__).resolve().parents[1] / "proyecto-4-semestre/Audios/Mesas"


def pulso(t: float, inicio: float, duracion: float) -> float:
    u = (t - inicio) / duracion
    return math.sin(math.pi * u) ** 2 if 0 < u < 1 else 0.0


def sintetizar(nombre: str, duracion: float, pico: float, forma, semilla: int) -> None:
    azar = random.Random(semilla)
    grave = 0.0
    agudo = 0.0
    muestras = []
    for indice in range(round(FRECUENCIA * duracion)):
        t = indice / FRECUENCIA
        ruido = azar.uniform(-1, 1)
        grave += 0.04 * (ruido - grave)
        agudo += 0.65 * (ruido - agudo)
        muestra = forma(t, agudo - grave, grave)
        # Suaviza los extremos del archivo y la unión de los bucles.
        muestra *= min(1.0, t / 0.008, (duracion - t) / 0.012)
        muestras.append(muestra)
    ganancia = pico / max(max(abs(muestra) for muestra in muestras), 1e-9)
    datos = b"".join(struct.pack("<h", round(muestra * ganancia * 32767)) for muestra in muestras)
    with wave.open(str(DESTINO / nombre), "wb") as archivo:
        archivo.setnchannels(1)
        archivo.setsampwidth(2)
        archivo.setframerate(FRECUENCIA)
        archivo.writeframes(datos)
    print(f"{nombre}: {len(muestras) / FRECUENCIA:.3f} s")


def escaner(t: float, ruido: float, grave: float) -> float:
    fase = (t * 0.55) % 1.0
    carga = 0.4 + 0.6 * math.sin(math.pi * fase) ** 0.6
    motor = math.sin(math.tau * 110 * t) * 0.24 + math.sin(math.tau * 220 * t) * 0.10
    dientes = math.sin(math.tau * 1430 * t + 2.8 * math.sin(math.tau * 110 * t)) * 0.055
    retorno = math.exp(-fase * 80) * (grave * 0.55 + math.sin(math.tau * 340 * t) * 0.025)
    return (motor + dientes + ruido * 0.045) * carga + retorno


def impresora(t: float, ruido: float, grave: float) -> float:
    rodillo = math.sin(math.tau * (150 * t + 80 * t * t)) * 0.11
    engranaje = math.sin(math.tau * 1770 * t + 3 * math.sin(math.tau * 94 * t)) * 0.045
    papel = ruido * (0.04 + pulso(t, 0.40, 0.28) * 0.2)
    return (rodillo + engranaje + papel) * pulso(t, 0.015, 0.69) ** 0.35 + grave * pulso(t, 0.62, 0.08) * 1.2


def atasco(t: float, ruido: float, grave: float) -> float:
    frenada = math.sin(math.tau * (220 * t - 140 * t * t)) * 0.15 * pulso(t, 0, 0.34)
    traqueteo = sum(pulso(t, inicio, 0.035) for inicio in [0.21, 0.27, 0.33, 0.39])
    return frenada + (ruido * 0.13 + grave * 0.9) * traqueteo


def reparar(t: float, ruido: float, grave: float) -> float:
    clics = sum(pulso(t, inicio, 0.04) for inicio in [0.018, 0.11])
    return (ruido * 0.18 + grave) * clics + impresora(t - 0.14, ruido, grave) * 0.5


def teclas(t: float, ruido: float, grave: float) -> float:
    valor = 0.0
    for indice, inicio in enumerate([0.03, 0.14, 0.23, 0.39, 0.46, 0.66, 0.79, 0.88, 1.05]):
        envolvente = pulso(t, inicio, 0.045)
        valor += (grave * 1.2 + ruido * 0.12 + math.sin(math.tau * (470 + indice * 29) * (t - inicio)) * 0.045) * envolvente
    return valor


def aviso(t: float, ruido: float, grave: float) -> float:
    return math.sin(math.tau * 1046.5 * t) * (pulso(t, 0.01, 0.075) + pulso(t, 0.13, 0.075)) * 0.2


def rechazo(t: float, ruido: float, grave: float) -> float:
    return (math.sin(math.tau * 330 * t) * 0.17 + math.sin(math.tau * 440 * t) * 0.055) * pulso(t, 0.008, 0.16)


def bienestar(t: float, ruido: float, grave: float) -> float:
    return (math.sin(math.tau * 175 * t) * math.exp(-t * 24) * 0.21 + grave * 0.28 + ruido * 0.012) * pulso(t, 0, 0.24) ** 0.4


def generar() -> None:
    DESTINO.mkdir(parents=True, exist_ok=True)
    for indice, (nombre, duracion, pico, forma) in enumerate([
        ("escaner_barrido.wav", 2 / 0.55, 0.45, escaner),
        ("impresora.wav", 0.76, 0.55, impresora),
        ("impresora_atasco.wav", 0.46, 0.52, atasco),
        ("reparar_impresora.wav", 0.90, 0.52, reparar),
        ("desencriptado.wav", 1.20, 0.42, teclas),
        ("archivo_listo.wav", 0.25, 0.38, aviso),
        ("rechazo.wav", 0.19, 0.35, rechazo),
        ("bienestar.wav", 0.25, 0.45, bienestar),
    ]):
        sintetizar(nombre, duracion, pico, forma, 9317 + indice)


if __name__ == "__main__":
    generar()
