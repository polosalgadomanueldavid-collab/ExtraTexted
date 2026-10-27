# Policía azul — primera versión jugable

Modelo 3D original construido a partir de las referencias proporcionadas: cuerpo redondeado sin rostro, uniforme azul, gorra de plato, dos placas, tres botones y cinturón con cartucheras. Esta es una base editable para seguir afinando la silueta y las animaciones.

## Usarlo en Godot

Abre `res://Pruebas/PersonajePolicia/PruebaPoliciaAzul.tscn` y pulsa **F6**. El juego principal conserva su escena y personaje actuales.

`PoliciaAzul.tscn` es el personaje reutilizable con `CharacterBody3D`, colisión, controlador y modelo. Puede instanciarse en otra escena con suelo de colisión en la capa 1. El modelo mide aproximadamente 2,7 m, tiene los pies en el origen y mira hacia **+Z**. La velocidad, aceleración, salto y cámara se ajustan en el Inspector.

`policia_azul.glb` contiene 33 piezas de malla vinculadas a un `Skeleton3D` de 17 huesos y seis clips: `idle`, `walk`, `run`, `jump`, `fall` y `wave`. El script de importación `preparar_animaciones.gd` mantiene en bucle reposo, caminar, correr y caída; salto y saludo tienen final. El movimiento físico lo controla Godot, sin desplazamiento horizontal de la raíz en los clips.

Los controles de prueba usan acciones con prefijo `policia_prueba_`, registradas al ejecutar el personaje. No requieren modificar el mapa de entradas del juego. El controlador expone `input_locked`, `play_wave()`, `reset_to_spawn()` y la señal `animation_state_changed`.

## Editar el modelo

Fuera de la carpeta del proyecto Godot, en la raíz del repositorio:

- `arte-fuente/PoliciaAzul/policia_azul.blend`: fuente editable con mallas, materiales, armature, pesos y acciones.
- `herramientas/generar_policia_azul.py`: generador reproducible para Blender 4.5.

Ejecuta `blender --background --python herramientas/generar_policia_azul.py` desde la raíz para regenerar el GLB, la fuente y la vista previa. Después permite que Godot reimporte el GLB. **Blender no es necesario para abrir ni ejecutar la escena de Godot.**

El generador reemplaza la fuente y el GLB generados; si editas a mano el `.blend`, exporta desde esa fuente o actualiza el generador antes de volver a ejecutarlo.
