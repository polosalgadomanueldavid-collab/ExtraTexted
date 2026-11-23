# Rendimiento y tirones del juego

23 de noviembre de 2026. **Siguen existiendo tirones**, especialmente al generar el terremoto y la lava. La oficina tranquila ronda 60 FPS a 1280 × 720 en este equipo, pero ese promedio no representa las pausas al iniciar eventos. La reducción de sombras del menú sí produjo una mejora clara en el experimento gráfico.

## Entorno y alcance

Intel i5-1135G7, Iris Xe, Windows, Godot 4.7 stable `5b4e0cb0f`, Compatibility/OpenGL, ventana de 1280 × 720. Editor abierto; ejecuciones con scripts del motor, sin exportar. Procesos iniciados con `Start-Process -WindowStyle Hidden`. Los intervalos corresponden a señales `process_frame`, no a una captura de presentación del monitor.

Base del repositorio: `57ac234`, con cambios locales de iluminación en curso. El perfil general usa las fuentes de trabajo; para la comparación posterior se copiaron las fuentes a `.godot/qa_rendimiento_2026_11_23/snapshot`, compartiendo únicamente los recursos importados. Las huellas de los archivos principales de esa copia están en [entorno.json](Mediciones/2026-11-23/entorno.json).

El usuario detuvo su partida antes de empezar. Después se ejecutó otra prueba gráfica de Ultra durante parte de la comparación; el usuario indicó que debía continuar. Por eso los resultados son diagnósticos y **no permiten atribuir porcentajes de mejora de los eventos a la calidad gráfica**. Tampoco constituyen una comparación aislada frente al día 16. Las cachés del sistema y del controlador no se vaciaron. Ultra no se evaluó como perfil de calidad en esta revisión.

## Perfil general

Diez segundos por escenario, dos pasadas de eventos y poderes, cinco oficinas. FPS calculados a partir del número de intervalos y su duración acumulada; incluyen el intervalo de activación. Todos los tiempos de cuadro son milisegundos.

| Escenario | FPS medios | p95 | Mayor intervalo |
| --- | ---: | ---: | ---: |
| Menú | 38,01 | 33,01 | 52,55 |
| Oficina inicial | 59,96 | 17,41 | 19,45 |
| Apagón | 59,96 | 17,23 | 28,11 |
| Terremoto, primera activación válida | 52,73 | 17,40 | **1252,43** |
| Incendio | 59,96 | 17,37 | 34,66 |
| Inundación | 60,06 | 17,21 | 18,46 |
| Lava | 59,15 | 17,28 | **162,17** |
| Hielo | 60,04 | 17,72 | 21,29 |
| Chocolate | 59,96 | 17,28 | 39,59 |
| Dona | 60,06 | 17,26 | 17,78 |
| Papa tiempo | 60,06 | 17,48 | 27,87 |
| Avatar de agua | 47,61 | 41,35 | **85,57** |
| Quinta oficina | 60,06 | 17,30 | 26,32 |

Datos exactos: [perfil_alta.json](Mediciones/2026-11-23/perfil_alta.json). Las cifras redondeadas de esta tabla son orientativas; los JSON conservan la precisión del instrumento.

La llamada de inicio del primer terremoto consumió **1210,53 ms**. El segundo intento fue rechazado, consumió **265,76 ms** y produjo un intervalo de 271,96 ms. El JSON registra `terremoto_segunda_activado: false`: no fue una segunda ejecución válida del evento. Un intento rechazado también puede causar una pausa.

La lava se activó en ambas pasadas: llamadas de inicio de **140,26 y 114,02 ms**, con intervalos máximos de **162,17 y 122,25 ms**. Todos los otros eventos y los cuatro poderes registraron activaciones válidas en ambas pasadas. El avatar de agua repitió con 53,70 FPS y p95 de 27,50 ms; requiere una revisión específica del efecto completo para separar dibujo y lógica.

Las cinco oficinas conservaron **2191 nodos**. Tras la pasada inicial de eventos, la memoria estática del motor pasó de **188,99 a 189,02 MiB** entre las oficinas 2 y 5, y la VRAM informada se mantuvo alrededor de **559,15 MiB**. No se observó crecimiento de nodos entre esas entradas; no certifica ausencia de fugas en sesiones largas. La memoria estática de Godot no es la RAM total del proceso Windows.

## Comparación de alternativas

Ocho segundos por escenario; cada terremoto válido se siguió durante 26 segundos para incluir aviso, rotura a los ocho segundos, derrumbes y cierre. Ambas activaciones del terremoto fueron válidas. La semilla usada fue 8762; la simulación y el estado del personaje evolucionan entre escenarios, por lo que no se garantiza identidad de toda la distribución entre calidades.

| Escenario | FPS medios | p95 | Mayor intervalo | Cuadros >100 ms |
| --- | ---: | ---: | ---: | ---: |
| Menú en Alta | 43,70 | 32,04 | 34,86 | 0 |
| Menú en Baja | **60,03** | 17,58 | 25,54 | 0 |
| Menú en Alta, sombras desactivadas | **60,07** | 18,15 | 20,34 | 0 |
| Menú en Alta, sombras restauradas | 43,00 | 31,89 | 36,47 | 0 |
| Oficina en Alta | 60,06 | 17,86 | 18,88 | 0 |
| Oficina en Baja | 59,94 | 17,37 | 37,55 | 0 |
| Generar y mantener 30 cajones, Alta | 59,32 | 18,12 | 60,67 | 0 |
| Generar y mantener 30 cajones, Baja | 60,06 | 17,37 | 20,16 | 0 |
| Terremoto completo en Alta | 57,02 | 17,79 | **992,35** | 3 |
| Terremoto completo en Baja | 59,03 | 17,37 | **421,11** | 1 |
| Lava en Alta | 58,68 | 17,43 | **183,38** | 1 |
| Lava en Baja | 58,44 | 17,48 | **225,91** | 1 |

Datos: [comparacion.json](Mediciones/2026-11-23/comparacion.json).

En el menú, desactivar las sombras redujo la mediana de llamadas de dibujo de **2289 a 310**, conservando la escala 3D y el antialiasing de Alta. Al restaurarlas volvió el rendimiento de unos 43 FPS. Esto respalda limitar las sombras del decorado como alternativa concreta; la configuración actual de Baja también ayuda. El experimento no eligió todavía qué focos conservar para mantener la composición artística.

El perfil anterior consultaba solo la GPU del viewport raíz. Eso no incluía adecuadamente el decorado dentro del SubViewport: en la comparación, su GPU p95 fue de **13,75 ms** en Alta, frente a **0,53 ms** informados por el viewport raíz. Se añadieron mediciones separadas de SubViewports. Su suma no equivale al tiempo total del cuadro ni elimina los costes de CPU/controlador. La documentación de [optimización de GPU de Godot](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html) explica el coste de llamadas de dibujo y cambios de estado en OpenGL.

La calidad Baja **no elimina los tirones de los eventos**. Las llamadas de inicio de lava fueron de 165,09 ms en Alta y 209,48 ms en Baja; las del terremoto, 917,76 y 405,12 ms. No se interpreta esta diferencia como aceleración causada por bajar calidad. Sí demuestra que ambas configuraciones conservan trabajo síncrono superior al presupuesto de un cuadro.

En el terremoto completo de Alta hubo un intervalo de **219,65 ms** alrededor de la apertura del suelo, además del de inicio. El código incorpora en ese momento cortes CSG, mallas y efectos. Esto los señala como candidatos de investigación; no separa cuánto corresponde a cada operación o al controlador.

## Soluciones propuestas y orden

1. **Terremoto: repartir la planificación y preparar la geometría antes de abrir el suelo.** `Eventos/Terremoto/evento_terremoto.gd::iniciar` intenta hasta 32 distribuciones en una llamada, con consultas de caminos y geometría. Separar planificación de datos y montaje visual, con lotes de aproximadamente 2–4 ms por cuadro; validar las posiciones actuales antes de aplicar el plan. Reutilizar escombros y materiales donde sea posible. La barrera LAN debe esperar el mismo plan autorizado por el anfitrión. El resultado debe conservar accesos, anchos de salto, avisos y tiempos.
2. **Terremoto: sustituir o preparar anticipadamente los booleanos CSG del piso.** `grieta.gd::abrir` añade una sustracción CSG por grieta y crea paredes/losas durante la ruptura. Evaluar piso triangulado y colisión preparada a partir de los mismos contornos, o distribuciones precalculadas y validadas. Es un cambio de mayor alcance que debe pasar las pruebas de grietas, caídas, rutas y LAN. Godot advierte del coste de CSG y describe el horneado a malla/colisión en [su documentación de CSG](https://docs.godotengine.org/en/stable/tutorials/3d/csg_tools.html).
3. **Lava: preparar la máscara fuera de la llamada de inicio.** `evento_lava.gd::_crear_visuales` elige seis charcos y llama a `patron_magma.gd::agregar_charco`; sus rutinas pintan polígonos y ramales píxel por píxel sobre una máscara de 512 × 932. Separar selección, generación de datos de la máscara y carga de textura; repartir el trabajo o preparar datos independientes en segundo plano. Mantener idéntica la máscara compartida por shader y daño. Bajar su resolución sin verificar ese contrato puede cambiar los bordes peligrosos.
4. **Menú: limitar las sombras del decorado.** Es la alternativa gráfica con una mejora observada más clara. Probar conservar solo las sombras que aportan a los personajes y los muebles principales, comparar capturas y repetir el perfil. Reducir resolución o MSAA puede complementar esta medida si continúa la limitación gráfica.
5. **Avatar de agua y cargas: medir sus fases específicas.** Separar transformación, torbellino y resolución del evento. Registrar creación de partículas, geometría y primer dibujo. Reutilizar los recursos cuyo primer uso resulte costoso. La carga ya prepara recursos, pool y calentamiento; eso no cubre la geometría aleatoria que se genera al activar terremoto/lava.

Si se utilizan hilos, deben recibir datos independientes. Las mutaciones del árbol activo y la creación/subida de recursos gráficos deben coordinarse con el hilo principal; tampoco se debe compartir un mismo AStar entre hilos. Son restricciones documentadas en [Thread-safe APIs](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html). Las alternativas anteriores son propuestas; esta revisión entrega mediciones e instrumentos, no una optimización de la jugabilidad.

## Cargas y verificaciones pendientes

La ruta directa del perfil menú → oficina tardó **18,72 s** la primera vez y **2,27–2,89 s** en las cuatro reentradas; su mayor intervalo inicial fue de **4,07 s**. En la copia de comparación, la primera oficina tardó **17,96 s**. Son rutas del instrumento que no recorren el formulario y su precarga anticipada, con compilación/cachés e interferencia externa sin controlar. No representan un tiempo certificado de entrada desde el botón Individual ni una exportación.

Ambas ejecuciones gráficas finalizaron y el comparador devolvió código 0. No hubo errores de scripts en sus registros; sí advertencias de **91 y 92 instancias ObjectDB sin liberar al salir**. Los registros se conservan junto a los JSON. Antes de afirmar que se resolvió el rendimiento faltan: exportación a 720p y 1080p sin otras pruebas concurrentes, sesión continua de al menos 30 minutos, recorrido real del formulario de carga y LAN en dos equipos. No se midió jitter de red en esta revisión.

## Instrumentos y reproducción

`Pruebas/Menus/perfil_rendimiento.gd` ahora registra número de cuadros, duración, FPS calculados, cantidades de intervalos >33,33/>50/>100 ms, los primeros 64 picos con su momento, máximos durante cargas y GPU de SubViewports. Admite salida independiente y omitir capturas. Los monitores `TIME_PROCESS` y física no son tiempos exclusivos por función; los intervalos monotónicos son la evidencia principal de las pausas.

`Pruebas/Menus/comparar_tirones.gd` reproduce la comparación de sombras/calidad, cajones, terremoto completo y lava. Ninguno de los dos guarda preferencias de calidad. Ambos scripts pasaron la comprobación sintáctica de Godot sobre las fuentes finales.

Desde la raíz del repositorio, usando el ejecutable de Godot 4.7 instalado:

```powershell
& $Godot --path proyecto-4-semestre --script res://Pruebas/Menus/perfil_rendimiento.gd --rendering-method gl_compatibility -- --segundos=10 --rondas=5 --calidad=2 --sin-capturas --reporte=res://.godot/perfil_alta.json
& $Godot --path proyecto-4-semestre --script res://Pruebas/Menus/comparar_tirones.gd --rendering-method gl_compatibility
```

Ejecutar secuencialmente. El segundo guarda `.godot/comparar_tirones.json`. Para comparar cifras con esta revisión, registrar también los cambios locales y las aplicaciones concurrentes.
