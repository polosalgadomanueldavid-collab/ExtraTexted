# Iluminación de la oficina

La oficina combina estaciones cálidas con una entrada azul desde las ventanas y
un relleno frío en descanso. Usa el renderer Compatibility existente, sin nuevos
efectos de pantalla completa, texturas, luz horneada ni iluminación global.

## Presupuesto y aspecto

- Ocho focos de oficina y dos luces de la puerta: **10 luces fijas**, antes 13.
- El foco lateral izquierdo cubre bienestar y verificación. Se retiran los tres
  focos redundantes de la pared trasera; el foco general cubre descanso.
- Ambiente azul con energía 0,36, ACES y exposición 1,1. Las paredes conservan su
  textura con un tinte ligeramente frío; el piso tiene un brillo ancho y tenue.
- **Ninguna sombra dinámica en las luces fijas.** Se probaron dos focos con
  sombras y una variante limitada a siluetas, pero su coste de dibujo aumentaba
  en Iris Xe. La versión entregada conserva el contraste por dirección y color.
  Las luces de eventos y los ajustes generales de calidad mantienen su lógica.
- Los diez nodos están incluidos explícitamente en `EventoApagon.luces`.
  El apagón oculta también los focos que antes no figuraban en esa lista;
  la reparación restaura su visibilidad y energía.
- El shader existente del piso conserva la máscara de agujeros del terremoto.
  Solo cambian rugosidad y especular. No se añaden muestreos ni pasadas.

La selección de colores y energías es estática. No hay búsquedas de luces por
fotograma, generación de recursos durante la partida ni cambios automáticos de
calidad. Los ocho focos fijos dejan de superar por sí solos el límite por malla
predeterminado de Compatibility; las luces adicionales de eventos deben seguir
respetando su alcance y sus máscaras.

## Preparación de la primera imagen

`UI/Menus/calentamiento_visual.gd` dibuja trabajo y descanso con la cámara real
durante la carga, con la partida pausada y el overlay opaco. Restaura posición,
orientación y FOV antes de preparar la visión del apagón. Si se cancela la carga y
se libera la escena durante la espera, no vuelve a acceder a la cámara liberada.

Esto anticipa combinaciones de focos y materiales que no están visibles en el
encuadre de arranque. Puede aumentar la carga inicial cuando el controlador debe
compilar variantes. No garantiza eliminar todos los tirones de los eventos.

## Verificación reproducible

Desde la raíz del repositorio, con `$Godot` apuntando al ejecutable:

```powershell
& $Godot --path proyecto-4-semestre --audio-driver Dummy --script res://Pruebas/Iluminacion/prueba_iluminacion.gd -- --etiqueta=entrega --calidad=2 --segundos=10
& $Godot --headless --path proyecto-4-semestre --script res://Pruebas/Apagon/prueba_apagon_oficina.gd
& $Godot --path proyecto-4-semestre --audio-driver Dummy --script res://Pruebas/Menus/prueba_carga.gd
```

La prueba de iluminación guarda capturas y `mediciones.json` en
`.godot/qa_iluminacion/<etiqueta>/`. Comprueba presupuesto, conexión de todas las
luces al apagón, apagado/restauración, lava, inundación, los tres niveles de
calidad y la restauración de cámara/luces tras el calentamiento. No guarda
preferencias de calidad. `--referencia` omite las comprobaciones del nuevo
presupuesto al medir una revisión anterior; no restaura automáticamente esa
revisión.

Las muestras de tiempos corresponden a vistas quietas y eventos ya activados.
No incluyen el coste síncrono de iniciar cada evento ni sustituyen una sesión
de juego prolongada, una exportación o una prueba con caché de shaders fría.
Headless permite comprobar lógica, pero no sirve para comparar FPS/GPU.

## Resultado local del 23 de noviembre de 2026

Godot 4.7 stable `5b4e0cb0f`, Compatibility, Intel Iris Xe, 1280 × 720,
calidad alta y VSync desactivado en el medidor. La versión final supera **77
comprobaciones sin fallos**. Se revisaron las capturas de trabajo, descanso,
frontal, apagón, restauración, lava e inundación.

| Vista | Llamadas de dibujo antes | Después |
| --- | ---: | ---: |
| Trabajo | 195 | 181 |
| Descanso | 257 | 206 |
| Frontal | 153 | 153 |

Son medianas de vistas quietas, con la misma cámara y resolución. Las muestras
originales duran tres segundos por vista y las finales diez. Permanecían abiertos
el editor y otra partida del usuario: **no es una medición aislada de fluidez**.
Aunque baja el trabajo de dibujo, el p95 de cuadro no mejoró en estas muestras
(trabajo: 11,09 → 16,67 ms; descanso: 14,61 → 19,46 ms). No se atribuye esa
diferencia exclusivamente a la iluminación ni se presenta como garantía de FPS
estables. Queda pendiente comparar ejecuciones aisladas de igual duración,
incluyendo movimiento, eventos y caché fría.

El arranque final completó la carga en 14,82 s, con 0,70 s en la fase de dibujo y
calentamiento. Un intento anterior agotó el plazo cargando recursos; tras la
importación del proyecto, las ejecuciones siguientes completaron la carga.
También persiste el aviso previo de instancias ObjectDB al cerrar las pruebas.
No se consideran resueltos por este cambio de iluminación.

La integración del apagón supera **241 comprobaciones sin errores**. Su prueba
antigua intentaba activar eventos dentro de la práctica inicial, que los bloquea;
ese fallo también se reprodujo con la oficina anterior. La prueba ahora omite
esa práctica para ejercitar los circuitos, sin cambiar las reglas del juego.

La prueba de carga gráfica termina sin fallos y verifica 100 %, cajones preparados,
restauración del calentamiento y la práctica inicial interactiva. Se actualizó la
expectativa del tutorial antiguo y se alineó su espera funcional con el límite de
60 s del cargador (65 s en el test). La entrada medida desde el formulario fue de
**19,17 s**: el cambio de plazo no representa una optimización ni un cumplimiento
del límite anterior de 15 s. Se conserva la auditoría de tiempos.
