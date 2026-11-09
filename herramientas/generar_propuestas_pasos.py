"""Crea cinco propuestas originales de pasos y sus muestras de escucha.

Solo usa la biblioteca estandar. No descarga ni reutiliza audio de otros juegos.
Ejecutar desde cualquier carpeta: python herramientas/generar_propuestas_pasos.py
"""

from array import array
import json
import math
from pathlib import Path
import random
import sys
import wave


RAIZ = Path(__file__).resolve().parents[1]
DESTINO = RAIZ / "muestras_audio" / "pasos"
FRECUENCIA = 48000
DURACION_GOLPE = 0.28
DURACION_DEMO = 7.0
TAU = math.tau

PROPUESTAS = [
    {
        "id": "01_gomita_ligera",
        "nombre": "Gomita ligera",
        "descripcion": "Pasitos blanditos, cortos y elasticos, con un pequeno pop de goma.",
        "cuerpo": (172, 107, 0.032, 0.049, 0.64),
        "modos": [(335, 0.027, 0.12), (584, 0.018, 0.055), (935, 0.010, 0.025)],
        "ruido": (0.34, 0.052, 0.018, 0.027),
        "detalles": [(0.012, 570, 305, 0.014, 0.023, 0.09)],
    },
    {
        "id": "02_peluche",
        "nombre": "Peluche",
        "descripcion": "Pisada mullida y discreta: mas pompon y tela, con muy poco tono.",
        "cuerpo": (127, 83, 0.018, 0.035, 0.34),
        "modos": [(217, 0.016, 0.055), (408, 0.009, 0.018)],
        "ruido": (1.55, 0.17, 0.010, 0.031),
        "detalles": [],
    },
    {
        "id": "03_suela_de_goma",
        "nombre": "Suela de goma",
        "descripcion": "Tac suave y definido, con roce de zapatilla y un toque gomoso.",
        "cuerpo": (193, 118, 0.011, 0.022, 0.38),
        "modos": [(490, 0.014, 0.13), (1125, 0.008, 0.05), (1970, 0.004, 0.018)],
        "ruido": (0.52, 0.25, 0.035, 0.015),
        "detalles": [(0.023, 1180, 870, 0.012, 0.011, 0.018)],
    },
    {
        "id": "04_gelatina",
        "nombre": "Gelatina",
        "descripcion": "Plop redondito y burbujeante, con una pequena compresion humeda.",
        "cuerpo": (155, 83, 0.037, 0.055, 0.43),
        "modos": [(289, 0.041, 0.10), (426, 0.022, 0.065)],
        "ruido": (0.20, 0.055, 0.016, 0.028),
        "detalles": [(0.008, 610, 245, 0.025, 0.041, 0.17),
                     (0.051, 755, 365, 0.010, 0.015, 0.047)],
    },
    {
        "id": "05_rebote",
        "nombre": "Rebote caricaturesco",
        "descripcion": "Pum-boing jugueton: mas elasticidad y una colita de rebote.",
        "cuerpo": (205, 98, 0.060, 0.061, 0.60),
        "modos": [(322, 0.037, 0.050), (687, 0.019, 0.028)],
        "ruido": (0.28, 0.045, 0.013, 0.020),
        "detalles": [(0.040, 300, 166, 0.030, 0.035, 0.16)],
    },
]


def envolvente(t: float, caida: float, ataque: float = 0.002) -> float:
    if t <= 0:
        return 0.0
    return (1 - math.exp(-t / ataque)) * math.exp(-t / caida)


def barrido(t: float, inicio: float, final: float, curva: float,
            caida: float, amplitud: float, tono: float) -> float:
    if t <= 0:
        return 0.0
    # Integral del barrido exponencial: el impacto baja de tono sin saltos de fase.
    fase = tono * (final * t + (inicio - final) * curva * (1 - math.exp(-t / curva)))
    return amplitud * math.sin(TAU * fase) * envolvente(t, caida)


def sintetizar(config: dict, variante: int) -> list[float]:
    azar = random.Random(71083 + int(config["id"][:2]) * 100 + variante)
    tono = (0.975 if variante % 2 == 0 else 1.025) * azar.uniform(0.98, 1.02)
    fuerza = azar.uniform(0.94, 1.06)
    tiempo = azar.uniform(0.96, 1.04)
    filtro_grave = filtro_medio = filtro_alto = 0.0
    coeficientes = [1 - math.exp(-TAU * hz / FRECUENCIA) for hz in (340, 1600, 6500)]
    grave, medio, aire, caida = config["ruido"]
    fases = [azar.uniform(-0.2, 0.2) for _ in config["modos"]]
    muestras = []
    for i in range(round(FRECUENCIA * DURACION_GOLPE)):
        t = i / FRECUENCIA
        u = t / tiempo
        blanco = azar.uniform(-1, 1)
        filtro_grave += coeficientes[0] * (blanco - filtro_grave)
        filtro_medio += coeficientes[1] * (blanco - filtro_medio)
        filtro_alto += coeficientes[2] * (blanco - filtro_alto)
        textura = (grave * filtro_grave + medio * (filtro_medio - filtro_grave)
                   + aire * (filtro_alto - filtro_medio))
        valor = textura * envolvente(u, caida, 0.0014)
        valor += barrido(u, *config["cuerpo"], tono)
        for (hz, cola, amplitud), fase in zip(config["modos"], fases):
            valor += amplitud * math.sin(TAU * hz * tono * u + fase) * envolvente(u, cola)
        for inicio, f0, f1, curva, cola, amplitud in config["detalles"]:
            valor += barrido(u - inicio, f0, f1, curva, cola, amplitud, tono)
        # Una cola corta permite parar al jugador sin dejar una nota sonando.
        valor *= min(1.0, max(0.0, (DURACION_GOLPE - t) / 0.045))
        muestras.append(math.tanh(valor * fuerza * 1.15) / 1.15)
    # Elimina cualquier componente continua; conserva silencio en ambos extremos.
    media = sum(muestras) / len(muestras)
    for i, valor in enumerate(muestras):
        borde = min(1.0, i / 48, (len(muestras) - 1 - i) / 480)
        muestras[i] = (valor - media) * max(0.0, borde)
    return muestras


def guardar_wav(ruta: Path, canales: list[list[float]]) -> dict:
    ruta.parent.mkdir(parents=True, exist_ok=True)
    datos = array("h")
    pico = 0.0
    energia = 0.0
    for frame in zip(*canales):
        for valor in frame:
            if not math.isfinite(valor) or abs(valor) >= 1.0:
                raise ValueError(f"Muestra no valida o saturada en {ruta.name}: {valor}")
            pico = max(pico, abs(valor))
            energia += valor * valor
            datos.append(round(valor * 32767))
    if sys.byteorder != "little":
        datos.byteswap()
    with wave.open(str(ruta), "wb") as archivo:
        archivo.setnchannels(len(canales))
        archivo.setsampwidth(2)
        archivo.setframerate(FRECUENCIA)
        archivo.writeframes(datos.tobytes())
    return {
        "archivo": ruta.relative_to(DESTINO).as_posix(),
        "duracion_s": round(len(canales[0]) / FRECUENCIA, 3),
        "canales": len(canales),
        "pico_dbfs": round(20 * math.log10(max(pico, 1e-9)), 2),
        "rms_dbfs": round(10 * math.log10(max(energia / len(datos), 1e-12)), 2),
    }


def mezclar(destino: list[list[float]], golpe: list[float], inicio: float,
            fuerza: float, paneo: float) -> None:
    primero = round(inicio * FRECUENCIA)
    for canal, ganancia in zip(destino, (1 - paneo, 1 + paneo)):
        for i, valor in enumerate(golpe):
            if primero + i < len(canal):
                canal[primero + i] += valor * fuerza * ganancia


def demo(golpes: list[list[float]]) -> list[list[float]]:
    canales = [[0.0] * round(FRECUENCIA * DURACION_DEMO) for _ in range(2)]
    # La misma frase en las cinco opciones: caminar, pausa, trotar.
    for i in range(8):
        mezclar(canales, golpes[i % len(golpes)], 0.30 + i * 0.39,
                [0.95, 0.89, 1.0, 0.92][i % 4], -0.055 if i % 2 == 0 else 0.055)
    for i in range(10):
        mezclar(canales, golpes[(i + 2) % len(golpes)], 4.05 + i * 0.245,
                [1.0, 0.93, 1.04, 0.96][i % 4], -0.055 if i % 2 == 0 else 0.055)
    return canales


def generar() -> None:
    DESTINO.mkdir(parents=True, exist_ok=True)
    informe = {"frecuencia_hz": FRECUENCIA, "formato": "PCM 16 bits", "propuestas": []}
    resumen = [[0.0] * round(FRECUENCIA * 18.5) for _ in range(2)]
    for numero, config in enumerate(PROPUESTAS):
        golpes = [sintetizar(config, variante) for variante in range(6)]
        # Iguala energia de pisada entre familias; mantiene la variacion entre golpes.
        ventana = round(FRECUENCIA * 0.16)
        rms = math.sqrt(sum(sum(x * x for x in g[:ventana]) for g in golpes)
                        / (len(golpes) * ventana))
        pico = max(abs(x) for g in golpes for x in g)
        ganancia = min(0.105 / rms, 0.60 / pico)
        golpes = [[x * ganancia for x in golpe] for golpe in golpes]
        pistas = []
        for i, golpe in enumerate(golpes):
            pistas.append(guardar_wav(DESTINO / "golpes" / config["id"] / f"paso_{i + 1:02}.wav", [golpe]))
        pistas.append(guardar_wav(DESTINO / f"{config['id']}.wav", demo(golpes)))
        for i in range(7):
            mezclar(resumen, golpes[i % 6], numero * 3.7 + 0.20 + i * 0.39,
                    0.95, -0.055 if i % 2 == 0 else 0.055)
        informe["propuestas"].append({"id": config["id"], "nombre": config["nombre"], "pistas": pistas})
        print(f"{config['nombre']}: 6 golpes y una muestra de {DURACION_DEMO:.0f} s")
    informe["comparativa"] = guardar_wav(DESTINO / "00_comparativa.wav", resumen)
    (DESTINO / "niveles.json").write_text(json.dumps(informe, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    generar()
