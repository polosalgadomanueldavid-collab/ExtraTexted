mesa 23 der : Mesa de evidencias
mesa 21 izq: mesa de verificacion
mesa 25 down: mesa de privacidad
mesa 27 down: mesa de reporte
mesa 17 izq: mesa de bienestar


## Progresión de mesas y plazos

Las estaciones del perímetro conservan su posición. Las mesas/cajones de los pasillos
comienzan en **10 ya colocadas al entrar**, suman **1 cada 15 segundos** de turno sin emergencias y llegan
como máximo a **30**. La cantidad se aplica en el siguiente reparto procedural.
Práctica, pausa, Papa Tiempo y emergencias no avanzan esta progresión. Se conservan
las protecciones de rutas, jugadores y hojas: si no caben todas, se coloca la cantidad segura.

El debugger (**F3 y después F4**) permite escribir cuántas mesas añadir y muestra
cantidad activa y objetivo. Durante incendio o terremoto el aumento queda pendiente
para el próximo reparto. En LAN solo el anfitrión aplica cambios; los clientes reciben
su distribución y progresión.

La cantidad de mesas realmente colocadas determina la cadencia de nuevas misiones.
Cada mesa por encima de cinco (la referencia del balance) añade **0,6 s** a los extremos del
intervalo de llegada. Se aplica al programar la próxima denuncia, sin reiniciar
continuamente la espera que ya estaba en curso. En individual se han restado
**7 segundos** a ambos extremos de cada intervalo; en dúo se han restado **8 segundos**.

| Mesas activas | Llegadas individual | Llegadas dúo | Niveles nuevos |
| --- | --- | --- | --- |
| 10 (inicio) | 11–19 s | 7–15 s | 1–5 |
| 15 | 14–22 s | 10–18 s | 1–5 |
| 24 | 19,4–27,4 s | 15,4–23,4 s | 1–5 |
| 25 | 20–28 s | 16–24 s | 3–5 |
| 30 | 23–31 s | 19–27 s | 3–5 |

A partir de **25 mesas**, el sorteo solo admite denuncias de **nivel 3 o superior**.
Los casos que ya estaban en la cola se conservan. La regla también cuenta mesas
agregadas desde el debugger; un aumento pendiente durante un evento se cuenta al
colocarse realmente. Si el catálogo no contiene niveles admisibles, se espera al
siguiente intento sin generar un caso de nivel inferior.

El plazo de resolución individual sigue siendo el original más **30 segundos**;
en dúo es el original más **15 segundos**. Pueden tramitar dos casos a la vez,
pero siguen compartiendo estaciones.

| Denuncia | Individual | Dúo |
| --- | --- | --- |
| Uso excesivo | 140 s | 125 s |
| Enlace sospechoso / phishing | 120 s | 105 s |
| Suplantación | 100 s | 85 s |
| Acoso | 85 s | 70 s |
| Amenaza creíble | 70 s | 55 s |

El anfitrión aplica el balance al crear cada denuncia y replica el plazo real.
Si un policía queda eliminado, las siguientes denuncias y la siguiente programación
de llegadas usan el balance individual; los relojes existentes no se reinician.
No se añade tiempo de resolución por cola ni por mesas. La progresión de mesas y los eventos
mantienen las mismas reglas en ambos modos.
Los relojes avanzan a velocidad normal también en espera y durante los eventos.
Papa Tiempo y práctica conservan la pausa total.

Pruebas: `Pruebas/Partida/prueba_balance_progresion.gd`,
`Pruebas/Bloqueos/prueba_generacion_bloqueos.gd` y
`Pruebas/ZonaDescanso/prueba_depurador_recursos.gd`.
