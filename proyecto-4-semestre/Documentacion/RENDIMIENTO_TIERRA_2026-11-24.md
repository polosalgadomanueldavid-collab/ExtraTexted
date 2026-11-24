# Tierra control: implementación y verificación

Fecha: 24 de noviembre de 2026. Godot 4.7 estable, GL Compatibility, Intel Iris Xe, ventana de 1280 × 720, VSync desactivado.

## Cambio implementado

La coreografía conserva 3,6 segundos, pisadas al 29 % y 51 %, y contacto resolutivo al 72 %. Añade apertura de palmas, elevación de macizos, reunión mediante giro de cintura y descarga. No desplaza las colisiones del jugador.

El efecto utiliza tres lotes MultiMesh opacos con geometría facetada compartida: 184 rocas en alta/ultra, 120 en media y 64 en baja. Los 32 macizos principales se conservan en todos los niveles. Solo estos proyectan sombras en alta/ultra. No añade cuerpos físicos, navegación, luz propia ni partículas transparentes nuevas.

Los datos de las instancias y las mallas se preparan al configurar la oficina y se reutilizan. El shader calcula las trayectorias desde el reloj del gesto, con influencia de las manos reales y parámetros independientes para cada efecto. Las manos se fijan al soltar la descarga. No se reconstruyen mallas ni se actualizan las 184 transformaciones desde GDScript por cuadro.

El calentamiento visual dibuja los lotes tanto en su muestra aislada como con las luces reales de la oficina mientras la carga está cubierta. La envolvente de visibilidad contiene la trayectoria completa. Los lotes permanecen registrados desde el inicio; el shader mantiene escala cero antes de emerger.

## Pruebas funcionales

- `Pruebas/ZonaDescanso/prueba_coreografias_avatar.gd`: 76 comprobaciones, 0 errores. Incluye apoyo de pies, cuerpo sin desplazamiento, contacto único, pausa, cancelación y recuperación de controles para los cuatro elementos.
- `Pruebas/ZonaDescanso/prueba_tierra.gd`: 24 comprobaciones, 0 errores. Incluye niveles de calidad, reutilización de lotes, dos materiales/relojes independientes, descarga que no sigue el retorno de brazos, pausa del shader y consumo/restauración real del terremoto.
- Captura gráfica de 60 fotogramas con el personaje y oficina reales. La vista frontal usa el entorno y las capas de la cámara del juego. El modo lateral de diagnóstico oculta una pared solo en la captura.
- `git diff --check` sin errores de espacios.

## Medición comparativa final

El perfil compara una copia del efecto anterior obtenido del HEAD con el nuevo efecto, manteniendo la misma coreografía actual, escena y cámara. Es una comparación del coste del VFX, no de dos ejecutables completos de revisiones distintas. Cada proceso arranca una oficina nueva. El cuerpo se fija durante la medición para que una caída no cancele el gesto; el esqueleto sigue actualizándose. Las pruebas funcionales sí usan la física normal.

Para la restauración, el perfil espera la preparación válida y el reloj físico del terremoto hasta 8,4167 s; ambas versiones tenían 10 grietas al iniciar el gesto y terminaron con la restauración completa. Las mediciones previas que esperaban un temporizador de pared, sin verificar el éxito de la preparación, se descartaron para comparar restauraciones.

Calidad alta, comparación final con calentamiento visual y cachés del controlador ya utilizadas:

| Escenario | Versión | FPS medios | Cuadro p95 (ms) | Cuadro máximo (ms) | Llamadas de dibujo máximas de la escena |
|---|---|---:|---:|---:|---:|
| Primera activación del proceso | Anterior | 95,4 | 12,444 | 133,317 | 209 |
| Primera activación del proceso | Nueva | 106,6 | 11,365 | 74,841 | 200 |
| Activación repetida | Anterior | 101,5 | 12,323 | 59,519 | 209 |
| Activación repetida | Nueva | 109,0 | 11,958 | 58,290 | 200 |
| Gesto y restauración del suelo roto | Anterior | 81,8 | 16,300 | 63,950 | 415 |
| Gesto y restauración del suelo roto | Nueva | 87,9 | 14,778 | 57,993 | 406 |

En baja, la versión nueva obtuvo 110,6 FPS medios durante la activación repetida (p95 11,185 ms) y 89,7 durante la restauración (p95 14,855 ms). Las cantidades son de toda la escena: tres grupos de rocas no equivalen necesariamente a tres llamadas totales por las pasadas de sombras y luces.

Estos resultados no muestran una regresión sostenida en los escenarios medidos, pero una pasada por condición no establece una mejora estadística ni garantiza resultados idénticos en otros equipos.

## Picos y límites de la validación

La primera prueba directa que omitía el calentamiento encontró un pico de unos 770 ms al aparecer las rocas. Se añadió preparación de la variante instanciada en el mundo real; la medición final registra 74,841 ms como máximo de la primera activación del proceso. Parte del inicio incluye también la infraestructura existente del gesto y del Avatar.

En una primera restauración con el suelo realmente roto se registró un pico de 828,481 ms. En la comparación posterior con cachés utilizadas, la restauración antigua alcanzó 63,950 ms y la nueva 57,993 ms. No se afirma que ese pico inicial esté eliminado, ni se atribuye exclusivamente al VFX sin un perfil más profundo de la reconstrucción del terremoto. Tampoco se promete ausencia total de tirones: las activaciones repetidas todavía tienen picos cercanos a 58–60 ms.

Los registros gráficos también contienen el aviso preexistente de InputMap `movil_soltar_papel`, observado tanto con el efecto antiguo como con el nuevo. No se modificó ese sistema ni los cambios de terremoto/LAN que ya estaban presentes en el árbol de trabajo.

La independencia de dos efectos se comprobó localmente; no se ejecutó una sesión LAN entre dos equipos.

## Reproducir

Ejecutar desde la raíz del proyecto con Godot:

```text
--headless --fixed-fps 60 --script res://Pruebas/ZonaDescanso/prueba_coreografias_avatar.gd
--headless --fixed-fps 60 --script res://Pruebas/ZonaDescanso/prueba_tierra.gd
--script res://Pruebas/ZonaDescanso/perfil_tierra.gd -- --calidad=2 --calentamiento --reporte=res://.godot/tierra_medicion.json
--script res://Pruebas/ZonaDescanso/perfil_tierra.gd -- --calidad=0 --calentamiento --reporte=res://.godot/tierra_medicion_baja.json
--fixed-fps 60 --script res://Pruebas/ZonaDescanso/capturar_expendedora.gd -- --tierra-amplia --secuencia
```

Para comparar un efecto previo, añadir `--efecto-anterior=res://ruta/a/la/copia.gd` al perfil. No se reemplazan archivos de producción para esa comparación. Los reportes locales de esta revisión son `.godot/tierra_referencia_2.json`, `.godot/tierra_verificada_2.json` y `.godot/tierra_final_0.json`; contienen tiempos de CPU/GPU, nodos, memoria, picos y condiciones del terremoto.
