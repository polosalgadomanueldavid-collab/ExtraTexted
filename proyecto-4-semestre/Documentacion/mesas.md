mesa 23 der : Mesa de evidencias
mesa 21 izq: mesa de verificacion
mesa 25 down: mesa de privacidad
mesa 27 down: mesa de reporte
mesa 17 izq: mesa de bienestar


## Progresión de mesas y plazos

Las estaciones del perímetro conservan su posición. Las mesas/cajones de los pasillos
comienzan en **5**, suman **1 cada 25 segundos** de turno sin emergencias y llegan
como máximo a **30**. La cantidad se aplica en el siguiente reparto procedural.
Práctica, pausa, Papa Tiempo y emergencias no avanzan esta progresión. Se conservan
las protecciones de rutas, jugadores y hojas: si no caben todas, se coloca la cantidad segura.

El debugger (**F3 y después F4**) permite escribir cuántas mesas añadir y muestra
cantidad activa y objetivo. Durante incendio o terremoto el aumento queda pendiente
para el próximo reparto. En LAN solo el anfitrión aplica cambios; los clientes reciben
su distribución y progresión.

Las llegadas pasan de 12–20 a **15–23 s**, solo tres segundos adicionales.
Plazos base: uso excesivo 120 s; enlace sospechoso y phishing 150 s; suplantación
(cuatro estaciones) 180 s; acoso 140 s; amenaza creíble 130 s. Al llegar se añaden
15 s por caso existente (hasta 60 s) y 1,5 s por mesa adicional a las cinco iniciales.
Mientras esperan asignación, los relojes avanzan al 50 %. Apagón e incendio multiplican
el ritmo por 0,25; terremoto, inundación, lava e hielo, por 0,5. Cola y emergencia
combinan sus factores. Al finalizar el evento se recupera el ritmo normal sin rellenar
plazos ni modificar la cadencia. Papa Tiempo y práctica conservan la pausa total.

Pruebas: `Pruebas/Partida/prueba_balance_progresion.gd`,
`Pruebas/Bloqueos/prueba_generacion_bloqueos.gd` y
`Pruebas/ZonaDescanso/prueba_depurador_recursos.gd`.
