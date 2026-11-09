# Policía azul

Modelo 3D ajustado a las proporciones de las cuatro vistas de referencia. Las cotas del generador traducen los 650 píxeles de altura de la vista frontal a 2,66 unidades de malla.

## Usarlo en Godot

Abre `res://Pruebas/PersonajePolicia/PruebaPoliciaAzul.tscn` y pulsa **F6**. La plataforma de pruebas y `res://Personajes/PoliciaAzul/Policia.tscn` usan el mismo GLB. En el juego, `character_scale = 0.3` da una altura de aproximadamente 0,8 unidades.

`PoliciaAzul.tscn` es el personaje reutilizable con `CharacterBody3D`, colisión, controlador y modelo. Puede instanciarse en otra escena con suelo de colisión en la capa 1. El modelo mide aproximadamente 2,7 m, tiene los pies en el origen y mira hacia **+Z**. La velocidad, aceleración, salto y cámara se ajustan en el Inspector.

`policia_azul.glb` contiene 30 piezas de malla vinculadas a un `Skeleton3D` de 17 huesos. Incluye `idle`, `walk`, `run`, `jump`, `fall` y `wave`. El script de importación `preparar_animaciones.gd` mantiene en bucle reposo, caminar, correr y caída. Salto y saludo tienen final. El controlador de Godot se encarga del desplazamiento horizontal.

Los controles de prueba usan acciones con prefijo `policia_prueba_`, registradas al ejecutar el personaje. No requieren modificar el mapa de entradas del juego. El controlador expone `input_locked`, `play_wave()`, `reset_to_spawn()` y la señal `animation_state_changed`.

La voz provisional es **Gomosa (opción 4)**. Saluda con `play_wave()` y hace un esfuerzo al saltar. En la oficina también expresa sorpresa al iniciar un apagón y alegría al completar una estación. Las pistas, el tono, la variación y el volumen se ajustan en el hijo `VozPersonaje` del personaje. Detalles en `Audios/VozPersonaje/README.md`.

Los pasos usan **Suela de goma (opción 3)**, con seis variaciones y dos cadencias para caminar y correr. Solo suenan con desplazamiento real sobre el suelo. Los ajustes están en el hijo `SonidosPasos`; detalles en `Audios/Pasos/README.md`.

## Gestos e interacción

`animaciones_interaccion.gd` añade poses sobre el esqueleto después de los clips importados. El papel sigue la mano izquierda; la derecha pulsa equipos y mueve una llave durante la reparación de la impresora. La tecla E conserva sus acciones habituales: recibir/recoger, usar estaciones y lanzar en un espacio libre. Las acciones breves bloquean movimiento y nuevas interacciones; la pausa conserva su progreso y reiniciar cancela su efecto pendiente.

La entrega, la recogida y el lanzamiento ocurren al llegar al contacto del gesto. Reparar dura 2,4 segundos y resuelve el atasco al terminar el trabajo de la herramienta. Se vuelve a comprobar el caso al aplicar el efecto para evitar completar una denuncia que venció durante el gesto.

`intensidad_tambaleo` en el controlador ajusta el balanceo caricaturesco (0–2; predeterminado 1). Afecta al torso y a la cabeza tanto en locomoción como en las acciones. Los anclajes reciben la pose final, por lo que la hoja acompaña el movimiento sin deslizarse. Las dos variantes adicionales de reposo quedan pendientes.

Validación: `Godot --headless --fixed-fps 60 --path proyecto-4-semestre --script res://Pruebas/PersonajePolicia/prueba_gestos_policia.gd`. El paso fijo permite comprobar los momentos de contacto de forma reproducible. Comprueba entrega, sujeción, pausa, bloqueo de duplicados, reparación, lanzamiento, recogida, reinicio y retirada de una denuncia durante el gesto. Sin `--headless`, añadir `-- --capturas` guarda poses en `.godot/gestos_qa`.

## Editar el modelo

Fuera de la carpeta del proyecto Godot, en la raíz del repositorio:

- `arte-fuente/PoliciaAzul/policia_azul.blend`: fuente editable con mallas, materiales, armature, pesos y acciones.
- `herramientas/generar_policia_azul.py`: generador reproducible para Blender 4.5.

Ejecuta `blender --background --python herramientas/generar_policia_azul.py` desde la raíz para regenerar el GLB, la fuente y la vista previa. Después permite que Godot reimporte el GLB. **Blender no es necesario para abrir ni ejecutar la escena de Godot.**

El generador reemplaza la fuente y el GLB generados; si editas a mano el `.blend`, exporta desde esa fuente o actualiza el generador antes de volver a ejecutarlo.
