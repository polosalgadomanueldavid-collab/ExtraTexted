"""Sintetiza cinco voces de personaje con cuatro expresiones no verbales.

Fuente glotal, formantes moviles, aire y pequenas irregularidades de afinacion.
Biblioteca estandar; sin grabaciones externas ni voces de otros juegos.
"""

from array import array
import json
import math
from pathlib import Path
import random
import sys
import wave


RAIZ = Path(__file__).resolve().parents[1]
DESTINO = RAIZ / "muestras_audio" / "expresiones"
FRECUENCIA = 48000
TAU = math.tau

VOCALES = {
    "u": (330, 780, 2220),
    "o": (460, 900, 2400),
    "a": (760, 1220, 2550),
    "i": (310, 2100, 2950),
    "e": (510, 1780, 2520),
    "uh": (550, 1290, 2470),
}

VOCES = [
    dict(id="01_redondita", nombre="Redondita", tono=255, formante=1.10,
         ancho=1.0, aire=0.025, vibrato=0.013, rebote=0.012, nasal=0.14,
         cierre=0.19, filtro=0.48, irregularidad=0.005),
    dict(id="02_traviesa", nombre="Traviesa", tono=355, formante=1.25,
         ancho=0.90, aire=0.018, vibrato=0.020, rebote=0.025, nasal=0.08,
         cierre=0.14, filtro=0.63, irregularidad=0.008),
    dict(id="03_bonachona", nombre="Bonachona", tono=183, formante=0.88,
         ancho=1.18, aire=0.045, vibrato=0.012, rebote=0.016, nasal=0.11,
         cierre=0.18, filtro=0.38, irregularidad=0.016),
    dict(id="04_gomosa", nombre="Gomosa", tono=290, formante=1.08,
         ancho=0.95, aire=0.020, vibrato=0.030, rebote=0.075, nasal=0.22,
         cierre=0.20, filtro=0.48, irregularidad=0.009),
    dict(id="05_peluche", nombre="Peluche", tono=280, formante=1.02,
         ancho=1.40, aire=0.115, vibrato=0.009, rebote=0.008, nasal=0.05,
         cierre=0.29, filtro=0.24, irregularidad=0.004),
]

# inicio, duracion, curva de tono, transiciones de vocal, fuerza
EXPRESIONES = [
    ("saludo", 1.05, [
        (0.035, 0.29, [(0, 0.90), (0.65, 1.12), (1, 1.08)],
         [(0, "u"), (0.80, "o"), (1, "u")], 0.80),
        (0.385, 0.44, [(0, 1.12), (0.36, 1.36), (1, 0.98)],
         [(0, "u"), (0.65, "o"), (1, "u")], 0.90),
    ]),
    ("esfuerzo", 0.58, [
        (0.025, 0.285, [(0, 1.10), (0.18, 1.17), (0.62, 0.88), (1, 0.78)],
         [(0, "uh"), (0.45, "a"), (1, "u")], 0.88),
    ]),
    ("sorpresa", 0.90, [
        (0.045, 0.61, [(0, 0.92), (0.20, 1.09), (0.74, 1.65), (1, 1.46)],
         [(0, "u"), (0.30, "a"), (0.75, "o"), (1, "o")], 0.94),
    ]),
    ("alegria", 1.35, [
        (0.035, 0.34, [(0, 1.14), (0.55, 1.62), (1, 1.46)],
         [(0, "i"), (0.45, "u"), (1, "u")], 1.0),
        (0.465, 0.25, [(0, 1.43), (0.35, 1.59), (1, 1.24)],
         [(0, "u"), (0.4, "a"), (1, "u")], 0.88),
        (0.80, 0.30, [(0, 1.24), (0.35, 1.40), (1, 1.01)],
         [(0, "u"), (0.45, "o"), (1, "u")], 0.76),
    ]),
]

INICIOS_DEMO = [0.25, 1.80, 2.85, 4.30]
DURACION_DEMO = 6.10


def interpolar(puntos: list[tuple], u: float) -> float:
    for (t0, v0), (t1, v1) in zip(puntos, puntos[1:]):
        if u <= t1:
            f = min(1.0, max(0.0, (u - t0) / (t1 - t0)))
            f = f * f * (3 - 2 * f)
            return v0 + (v1 - v0) * f
    return puntos[-1][1]


def formantes(puntos: list[tuple], u: float) -> tuple[float, ...]:
    return tuple(interpolar([(t, VOCALES[v][i]) for t, v in puntos], u) for i in range(3))


def silaba(voz: dict, duracion: float, curva: list[tuple], vocales: list[tuple],
           fuerza: float, semilla: int) -> list[float]:
    azar = random.Random(semilla)
    fase = azar.uniform(0, 1)
    tono_base = voz["tono"] * azar.uniform(0.985, 1.015)
    fase_vibrato = azar.uniform(0, TAU)
    estados = [[0.0, 0.0] for _ in range(4)]
    coeficientes = []
    fuente_suave = aire_suave = temblor = 0.0
    muestras = []
    for indice in range(round(FRECUENCIA * duracion)):
        t = indice / FRECUENCIA
        u = t / duracion
        blanco = azar.uniform(-1, 1)
        temblor += 0.008 * (blanco - temblor)
        vibrato = voz["vibrato"] * math.sin(TAU * 6.3 * t + fase_vibrato)
        rebote = voz["rebote"] * math.sin(TAU * 13.8 * t) * math.exp(-t * 3.2)
        frecuencia = tono_base * interpolar(curva, u)
        frecuencia *= 1 + vibrato + rebote + voz["irregularidad"] * temblor * 7
        fase = (fase + frecuencia / FRECUENCIA) % 1.0

        # Derivada de flujo glotal: apertura suave, cierre mas corto y reposo.
        # Las dos areas se compensan para no introducir continua.
        apertura = 0.43
        cierre = voz["cierre"]
        if fase < apertura:
            fuente = 0.5 * math.sin(math.pi * fase / apertura)
        elif fase < apertura + cierre:
            fuente = -0.5 * apertura / cierre * math.sin(math.pi * (fase - apertura) / cierre)
        else:
            fuente = 0.0
        fuente_suave += voz["filtro"] * (fuente - fuente_suave)
        aire_suave += 0.52 * (blanco - aire_suave)
        # Aire concentrado en los ataques y entre silabas; no es habla inteligible.
        aire = voz["aire"] * (0.45 + 0.85 * math.exp(-t * 24))
        entrada = fuente_suave + aire_suave * aire

        if indice % 96 == 0:
            frecuencias = list(formantes(vocales, u)) + [1030]
            anchos = [100, 145, 210, 115]
            coeficientes = []
            for f, ancho in zip(frecuencias, anchos):
                # Ligera abertura del tracto vocal durante el enfasis.
                f *= voz["formante"] * (0.98 + 0.04 * math.sin(math.pi * u))
                radio = math.exp(-math.pi * ancho * voz["ancho"] / FRECUENCIA)
                coeficientes.append((2 * radio * math.cos(TAU * f / FRECUENCIA),
                                     -radio * radio, 1 - radio))

        valor = fuente_suave * 0.013
        pesos = [1.0, 0.60, 0.30, voz["nasal"]]
        for estado, (a, b, ganancia), peso in zip(estados, coeficientes, pesos):
            salida = entrada * ganancia + a * estado[0] + b * estado[1]
            estado[1], estado[0] = estado[0], salida
            valor += salida * peso
        ataque = min(1.0, t / 0.018)
        final = min(1.0, max(0.0, (duracion - t) / 0.047))
        envolvente = ataque * final * (0.80 + 0.20 * math.sin(math.pi * u))
        # Una ligera pulsacion hace que el timbre grave tenga una textura mas ronquita.
        ronquera = 1 + voz["irregularidad"] * 2 * math.sin(TAU * 43 * t)
        muestras.append(valor * envolvente * fuerza * ronquera)
    return muestras


def crear_expresion(voz: dict, expresion: tuple, semilla: int) -> list[float]:
    nombre, duracion, silabas = expresion
    muestras = [0.0] * round(FRECUENCIA * duracion)
    for i, (inicio, largo, curva, vocales, fuerza) in enumerate(silabas):
        parte = silaba(voz, largo, curva, vocales, fuerza, semilla + i * 97)
        offset = round(inicio * FRECUENCIA)
        for j, valor in enumerate(parte):
            muestras[offset + j] += valor
    if nombre == "esfuerzo":
        # Cierre de labios acolchado al terminar el pequeno gruñido.
        azar = random.Random(semilla + 811)
        ruido_suave = 0.0
        for i in range(round(FRECUENCIA * 0.035)):
            t = i / FRECUENCIA
            ruido_suave += 0.12 * (azar.uniform(-1, 1) - ruido_suave)
            valor = ruido_suave * 0.025 * math.sin(math.pi * t / 0.035) ** 2
            muestras[round(FRECUENCIA * 0.32) + i] += valor
    # Suprime continua sin rellenar de ruido los huecos silenciosos.
    activos = [i for i, x in enumerate(muestras) if abs(x) > 1e-9]
    if activos:
        media = sum(muestras) / len(activos)
        for i in activos:
            muestras[i] -= media * min(1.0, abs(muestras[i]) / 0.0005)
    return muestras


def guardar(ruta: Path, muestras: list[float]) -> dict:
    ruta.parent.mkdir(parents=True, exist_ok=True)
    datos = array("h")
    for valor in muestras:
        if not math.isfinite(valor) or abs(valor) >= 1:
            raise ValueError(f"Nivel de audio no valido en {ruta.name}: {valor}")
        datos.append(round(valor * 32767))
    if sys.byteorder != "little":
        datos.byteswap()
    with wave.open(str(ruta), "wb") as archivo:
        archivo.setnchannels(1)
        archivo.setsampwidth(2)
        archivo.setframerate(FRECUENCIA)
        archivo.writeframes(datos.tobytes())
    pico = max(abs(x) for x in muestras)
    rms = math.sqrt(sum(x * x for x in muestras) / len(muestras))
    return dict(archivo=ruta.relative_to(DESTINO).as_posix(),
                duracion_s=round(len(muestras) / FRECUENCIA, 3),
                pico_dbfs=round(20 * math.log10(max(pico, 1e-9)), 2),
                rms_dbfs=round(20 * math.log10(max(rms, 1e-9)), 2))


def colocar(destino: list[float], sonido: list[float], inicio: float) -> None:
    offset = round(inicio * FRECUENCIA)
    for i, valor in enumerate(sonido):
        destino[offset + i] += valor


def generar() -> None:
    DESTINO.mkdir(parents=True, exist_ok=True)
    informe = dict(frecuencia_hz=FRECUENCIA, formato="PCM 16 bits mono", voces=[])
    comparativa = [0.0] * round(FRECUENCIA * 12.5)
    for numero, voz in enumerate(VOCES):
        clips = [crear_expresion(voz, expresion, 52917 + numero * 1009 + i * 31)
                 for i, expresion in enumerate(EXPRESIONES)]
        # Energia equivalente en tramos vocalizados; conserva el enfasis emocional.
        energia = sum(sum(x * x for x in clip) for clip in clips)
        tiempo_activo = sum(sum(s[1] for s in expresion[2]) for expresion in EXPRESIONES)
        rms = math.sqrt(energia / (tiempo_activo * FRECUENCIA))
        pico = max(abs(x) for clip in clips for x in clip)
        ganancia = min(0.125 / rms, 0.66 / pico)
        clips = [[x * ganancia for x in clip] for clip in clips]
        pistas = []
        demo = [0.0] * round(FRECUENCIA * DURACION_DEMO)
        for expresion, clip, inicio in zip(EXPRESIONES, clips, INICIOS_DEMO):
            pistas.append(guardar(DESTINO / "clips" / voz["id"] / f"{expresion[0]}.wav", clip))
            colocar(demo, clip, inicio)
        pistas.append(guardar(DESTINO / f"{voz['id']}.wav", demo))
        colocar(comparativa, clips[0], numero * 2.5 + 0.20)
        colocar(comparativa, clips[1], numero * 2.5 + 1.35)
        informe["voces"].append(dict(id=voz["id"], nombre=voz["nombre"], pistas=pistas))
        print(f"{voz['nombre']}: saludo, esfuerzo, sorpresa y alegria; muestra de {DURACION_DEMO:.1f} s", flush=True)
    informe["comparativa"] = guardar(DESTINO / "00_comparativa.wav", comparativa)
    (DESTINO / "niveles.json").write_text(json.dumps(informe, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    generar()
