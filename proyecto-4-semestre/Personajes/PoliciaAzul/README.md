# Policía azul

Modelo 3D ajustado a las proporciones de las cuatro vistas de referencia. Las cotas del generador traducen los 650 píxeles de altura de la vista frontal a 2,66 unidades de malla.

## Usarlo en Godot

Abre `res://Pruebas/PersonajePolicia/PruebaPoliciaAzul.tscn` y pulsa **F6**. La plataforma de pruebas y `res://Policia.tscn` usan el mismo GLB. En el juego, `character_scale = 0.3` da una altura de aproximadamente 0,8 unidades.

`PoliciaAzul.tscn` es el personaje reutilizable con `CharacterBody3D`, colisión, controlador y modelo. Puede instanciarse en otra escena con suelo de colisión en la capa 1. El modelo mide aproximadamente 2,7 m, tiene los pies en el origen y mira hacia **+Z**. La velocidad, aceleración, salto y cámara se ajustan en el Inspector.

`policia_azul.glb` contiene 30 piezas de malla vinculadas a un `Skeleton3D` de 17 huesos. Incluye `idle`, `walk`, `run`, `jump`, `fall` y `wave`. El script de importación `preparar_animaciones.gd` mantiene en bucle reposo, caminar, correr y caída. Salto y saludo tienen final. El controlador de Godot se encarga del desplazamiento horizontal.

Los controles de prueba usan acciones con prefijo `policia_prueba_`, registradas al ejecutar el personaje. No requieren modificar el mapa de entradas del juego. El controlador expone `input_locked`, `play_wave()`, `reset_to_spawn()` y la señal `animation_state_changed`.

## Editar el modelo

Fuera de la carpeta del proyecto Godot, en la raíz del repositorio:

- `arte-fuente/PoliciaAzul/policia_azul.blend`: fuente editable con mallas, materiales, armature, pesos y acciones.
- `herramientas/generar_policia_azul.py`: generador reproducible para Blender 4.5.

Ejecuta `blender --background --python herramientas/generar_policia_azul.py` desde la raíz para regenerar el GLB, la fuente y la vista previa. Después permite que Godot reimporte el GLB. **Blender no es necesario para abrir ni ejecutar la escena de Godot.**

El generador reemplaza la fuente y el GLB generados; si editas a mano el `.blend`, exporta desde esa fuente o actualiza el generador antes de volver a ejecutarlo.
