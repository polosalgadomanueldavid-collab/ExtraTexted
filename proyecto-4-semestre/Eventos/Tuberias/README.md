# Tuberías de descanso

Agua usa la compuerta abierta de `Furniture Pack/Compuertas/CompuertaAzulTuberias.glb`.
Nitrógeno usa `Furniture Pack/Compuertas/TuberiaNitrogeno.glb`, copiado del archivo
proporcionado por el usuario. Los GLB originales se conservan completos.

`hornear_tuberias.gd` separa las superficies móviles conservando las texturas,
normales y UV. Excluye la compuerta cerrada adicional del archivo de agua y guarda
`Agua.scn` y `Nitrogeno.scn`. La separación se hace en autoría, sin recorrer
triángulos durante la carga de la partida. Ejecutar con Godot 4.7:

```
--headless --path <proyecto> --script res://Eventos/Tuberias/hornear_tuberias.gd
```

Ambas instalaciones miden aproximadamente 0,65 m de alto, frente a los 0,54 m
del taco de luz. Usan escala 0,52 respecto a la primera versión y comparten
centro a 1,12 m. Están junto al taco (Z=8,66), en Z=9,34 (agua) y Z=10,08
(nitrógeno), con accesos despejados y visibles desde la cámara de juego.
El respaldo se sitúa en X=2,368, encastrado unos 2 mm en la cara interior de la
pared (X=2,3656), sin separación visible. No llevan rótulos flotantes permanentes;
se conservan los indicadores que aparecen durante cada evento.

Cada gabinete tiene un cuerpo sólido ajustado a los límites de sus mallas.
La tapa del agua tiene una colisión propia que gira con la bisagra. El cuerpo
fijo permanece activo durante la rotura y la reparación, y registra su huella
en el grafo de navegación. La interacción reconoce el choque con la propia
caja o su puerta, sin permitir atravesar otros obstáculos para repararla.

La puerta del agua está separada del gabinete, ajustada al marco y articulada
sobre una bisagra. Empieza cerrada; E abre la tapa en 0,35 s al entrar al puzzle,
y salir del panel o completar la reparación la cierra. Su giro de 105 grados
usa la misma duración y curva que el taco. La pausa y la detención temporal
congelan también esta animación. Cerrada, el agua escapa por la junta; abierta,
el chorro nace en el tramo roto. El nitrógeno mantiene su emisor en la boca.

`tuberia_rompible.gd` realiza una secuencia de presión, separación de la junta,
descarga inicial y fuga continua. El agua combina un chorro parabólico con gotas
y rocío; el nitrógeno combina un chorro de vapor con niebla que se expande.
La reparación corta la emisión y encaja la pieza progresivamente. Cancelar el
evento restaura inmediatamente las transformaciones y oculta las partículas.
Las animaciones heredan la pausa y la detención temporal. La reparación LAN
utiliza la misma animación. Se mantienen las reglas de inundación y congelación.

El marcador `Salida` de cada modelo ancla todos sus emisores. El frente de hielo
recibe la posición global de ese marcador al iniciar cada evento: no conserva
el antiguo origen fijo `(2.12, 8.95)`.

## Verificación

- `Pruebas/Tuberias/prueba_tuberias.gd`: temporización, pausa, desplazamiento del
  emisor, reparación, cancelación, repetición, recepción de reparación LAN y
  origen del shader en la oficina. También verifica apertura/cierre gradual,
  pausa de la puerta y su conexión con la interacción real del puzzle.
  Comprueba además el encastre en la pared, el choque frontal y lateral del
  personaje real, la colisión de la puerta abierta y el acceso a ambos puzzles.
- `Pruebas/Inundacion/prueba_inundacion.gd` y `Pruebas/Hielo/prueba_hielo.gd`:
  interacción con E, navegación, puzzles, estados del personaje y fin del evento.
- Ejecutar las pruebas con `--headless --fixed-fps 60 --path <proyecto> --script <ruta>`.

## Capturas de los tutoriales

Se revisaron las 20 fotografías usadas por el tutorial general y las guías de
eventos. Se volvieron a sustituir estas seis tras ajustar las cajas a la pared y
retirar los rótulos permanentes,
renderizadas desde la oficina actual:

| Captura | Motivo |
| --- | --- |
| `Eventos/agua_tuberia.webp` | Caja pequeña junto al taco, puerta cerrada y fuga por la junta. |
| `Eventos/agua_red.webp` | Puerta abierta e instalaciones visibles detrás del minijuego. |
| `Eventos/hielo_tuberia.webp` | Nuevo nitrógeno, junta abierta y niebla. |
| `Eventos/hielo_tuercas.webp` | Instalaciones visibles detrás del minijuego. |
| `Eventos/sismo_aviso.webp` | Las tres cajas se ven juntas al borde de descanso. |
| `apagon_taco.webp` | La caja de agua aparece ahora junto al tablero. |

Las demás fotografías no muestran las tuberías. Los textos de agua y hielo
identifican las nuevas compuertas. Para reproducir la revisión visual, ejecutar
`Pruebas/Tuberias/capturar_tutoriales.gd` con renderizado y `--fixed-fps 60`,
seguido de `-- tuberias`, `-- inundacion`, `-- hielo`, `-- terremoto` o
`-- apagon`. El modo `tuberias` captura las instalaciones sanas, rotas y reparadas.
La salida está en `.godot/tuberias_qa`; revisar antes de copiar las fotografías
correspondientes a `UI/Menus/ArtePiloto`.
