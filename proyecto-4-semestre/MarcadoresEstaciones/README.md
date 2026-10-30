# Modelos de los marcadores de estación

`modelos_marcador.gd` construye cinco objetos 3D con geometría nativa de Godot.
No necesita Blender, imágenes, fuentes, colisiones ni un proceso por modelo.

```gdscript
const ModelosMarcador = preload("res://MarcadoresEstaciones/modelos_marcador.gd")
var modelo: Node3D = ModelosMarcador.crear("evidencias")
var puntero: MeshInstance3D = ModelosMarcador.crear_puntero()
```

La raíz se llama `ModeloEstacion`. Su centro queda cerca del origen, su frente
mira hacia **+Z** y su silueta se dibuja en el plano XY. Las dimensiones aproximadas
son 0,5–0,65 unidades en ancho y alto y 0,15 en profundidad. El indicador coloca,
orienta y anima el objeto; el puntero se devuelve separado, con nombre `Puntero`,
ancho 0,20, alto 0,14 y profundidad 0,065 antes de redondear las esquinas.

| Estación | Objeto |
| --- | --- |
| `evidencias` | Carpeta con frente crema, trasera petróleo y pestaña coral |
| `verificacion` | Lupa con aro crema, canto y mango petróleo y banda coral |
| `privacidad` | Candado petróleo con arco crema y cerradura coral |
| `reporte` | Documento crema, esquina doblada y tres líneas en relieve |
| `bienestar` | Corazón coral con canto volumétrico petróleo |

Una estación desconocida devuelve el documento y añade metadata `fallback = true`.
Todas las raíces guardan también `estacion_id` en metadata.

Las siluetas se extruyen con varios anillos de bisel y normales suavizadas.
La lupa tiene un hueco real, sin vidrio ni transparencia. El arco del candado
es un tubo cerrado con sección circular; el mango de la lupa es una cápsula.

Se comparten tres materiales `StandardMaterial3D`: crema `#fff1d8`, petróleo
`#173b50` y coral `#ff785f`. Son opacos, iluminados, con rugosidad 0,4 y emisión
leve de 0,2. Mantienen la prueba de profundidad y no proyectan sombras sobre
el mobiliario.

## Integración

`Scripts/indicador_proxima_estacion.gd` coloca el modelo y el puntero bajo
`OrientacionCamara`. Los orienta a la cámara activa y aplica una flotación y
un balanceo limitados, sin girar la cara del icono de espaldas. Solo el objetivo
activo procesa animación; la pausa congela su fase y los marcadores ocultos
no procesan cuadros.

El gestor ancla cada marcador 1,90 unidades sobre su estación. La altura se
ajusta en `ALTURA_INDICADOR_ESTACION` de `Scripts/gestor_partida.gd`; el balanceo
y la separación del puntero se ajustan en el script del indicador. Su propiedad
`alto_maximo_pantalla` limita el tamaño al 18 % del alto del viewport al acercarse,
sin agrandar los objetos lejanos. Así se mantiene visible el personaje al usar
las mesas inferiores. La API `establecer_activo(bool)` controla visibilidad y
animación juntas.

Los cambios de protocolo, la resolución y el vencimiento sincronizan el
marcador inmediatamente con el despacho. No se añaden colisiones ni rótulos
al mundo; el HUD conserva el nombre y los pasos del caso.

## Disponibilidad de interacción

El marcador activo se ilumina y pulsa cuando es el objetivo real de la tecla
de interacción. El gestor consulta `Player.obtener_objetivo_interaccion()`,
que comparte el `ShapeCast3D`, su orientación y su orden de selección con la
acción del jugador. No se introduce otro radio: alejarse, mirar hacia otro lado,
bloquear la entrada o usar el computador retira el resaltado.

`establecer_interactuable(bool)` activa una transición breve de emisión y un
contorno cálido de `resaltado_interaccion.gdshader`. El efecto funciona en
Compatibility sin depender del bloom del escenario. Cada marcador duplica
sus materiales antes de animarlos para no iluminar las otras estaciones.
Desactivar o reconfigurar el marcador restablece inmediatamente su aspecto;
al salir del alcance, el brillo desaparece suavemente en unos 0,14 segundos.
