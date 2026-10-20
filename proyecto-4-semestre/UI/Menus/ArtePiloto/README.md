# Menú piloto

Implementado en `res://MainMenu.tscn` y en los paneles de `UI/Menus/MenuGlobal.tscn`.
Paleta: petróleo `#173B50`, crema
`#FFF1D8` y coral `#FF785F`. El fondo del menú principal queda liso.

El logo es una imagen RGBA independiente. Los botones son controles `Button`
de Godot: textos, iconos, áreas de interacción y estados permanecen separados.
Las superficies SVG son editables y tienen variantes normal, hover y pressed.
El foco tiene un contorno adicional; el botón se amplía un 2,5 % al seleccionarlo
y se comprime al pulsarlo. El menú escala de manera uniforme desde 1920×1080
sin modificar las coordenadas del juego.

`UI/Menus/tema_piloto.tres` comparte el panel y la fuente entre el menú principal,
la pausa, las opciones y la confirmación de regreso al menú. La pausa conserva el escenario
oscurecido detrás, presenta Reanudar en coral y muestra Salir del computador
solo cuando corresponde. Los textos largos reducen su fuente automáticamente
para respetar el espacio del icono y mantener el centrado.

La pausa y su confirmación ya no muestran el logotipo y se presentan a una
escala adicional de 0,8 (20 % menos en ambos ejes, incluidos sus controles).
Las opciones tienen su propia presentación centrada, sin logotipo, con
selector crema, selección coral y deslizadores con indicadores de foco y
estado inactivo. Brillo, filtros, intensidad y guardado mantienen la lógica
compartida entre la pantalla inicial y la pausa.

Los botones se redujeron un 15 % en ambos ejes y luego otro 15 % respecto al
tamaño resultante: de 712×132 a 605,2×112,2 y finalmente a 514,42×95,37
unidades. Fuente, iconos, márgenes y superficies acompañan estas reducciones.
El texto se centra respecto al botón completo y se corrige la línea base de la
fuente; los iconos quedan a la izquierda, centrados en la cara del botón.
Se retiró el subtítulo «Menú principal».

## Fuentes y procedencia

- `LuckiestGuy-Regular.ttf`: fuente de botones, alternativa instalada localmente
  para aproximar el lettering irregular del boceto. No es la fuente oficial de
  Gang Beasts. Fuente: https://github.com/google/fonts/tree/main/apache/luckiestguy
  Licencia Apache 2.0 adjunta en `LuckiestGuy-LICENSE.txt`.
- `Nunito.ttf`: fuente de lectura de etiquetas, valores, lista de filtros y aviso de confirmación.
  Fuente: https://github.com/google/fonts/tree/main/ofl/nunito
  Licencia OFL adjunta en `Nunito-OFL.txt`.
- `extra_texted_logo.png`: derivado del boceto aprobado mediante la herramienta
  integrada imagegen, con transparencia real. Sin servicios externos en ejecución.
- Botones e iconos: SVG nativos creados para esta prueba.

## Prompt final del logo (imagegen integrado)

Referencia: último boceto aprobado, `exec-411ccfe8-0711-42e8-9c29-29db19972a35.png`.
Parámetro `transparent_background: true`.

> Use case: background-extraction. Extract ONLY the EXTRA TEXTED title logo from the supplied game main-menu reference as a clean high-resolution RGBA TRANSPARENT PNG game asset. Keep logo intact, the exact existing angular irregular chunky hand-cut block typography inspired by Gang Beasts, word EXTRA in cream, TEXTED in coral, dark petrol outlines and subtle thick dark extruded shadows, coral accent strokes at left and right, and speech bubble in the final D with three cream dots. Preserve original lettering shapes, spelling, color, relative arrangement, proportions and shading with no redesign. Remove EVERYTHING ELSE including background, panel, subtitle "Menú principal", all buttons and all icons. Result must contain ONLY this original two-line logo with its own outline and shadow and accent strokes, isolated on true alpha transparency, no dark rectangular patch, no baked checkerboard. Crop composition tightly around the title with a small transparent safe margin about 4% to prevent clipping edges. Horizontal logo composition around 1.9:1. Do not add any text or symbols. This will be placed above working native UI buttons in Godot, so clean smooth alpha edges essential.

## Probar

Abrir el proyecto `proyecto-4-semestre/project.godot` y ejecutar con F6
`MainMenu.tscn`, o F5 para iniciar el proyecto completo.
Ratón, flechas arriba/abajo, Tab/Shift+Tab y Enter/Espacio usan la navegación
nativa. Jugar abre la oficina; Opciones abre el panel existente; Salir guarda
los ajustes y termina la aplicación.

Escenas de comprobación:

- `UI/Menus/Pruebas/PruebaMenuPiloto.tscn`: foco, navegación, clic real,
  retorno de opciones y visibilidad en varias resoluciones. Añadir
  `-- --capturas` a la ejecución por CLI para guardar capturas renderizadas
  en `.godot/piloto_qa/`.
- `UI/Menus/Pruebas/PruebaMenus.tscn`: integración existente con la oficina,
  pausa, accesibilidad, regreso al menú y salida.

El piloto se aplica a la pantalla principal, la pausa, las opciones y la
confirmación de regreso al menú.
