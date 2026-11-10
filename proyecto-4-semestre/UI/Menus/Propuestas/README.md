# Propuestas animadas para el menú principal

Abre `res://UI/Menus/PropuestasMenu.tscn` en Godot y ejecuta la escena con **F6**.
La galería conserva el menú principal del juego y permite comparar cuatro disposiciones:

1. **Escolta:** un policía a cada lado del menú centrado.
2. **Compañeros:** menú a la izquierda y ambos policías a la derecha.
3. **Expediente:** menú a la derecha y ambos policías a la izquierda.
4. **Primer plano:** menú compacto a la izquierda, un policía al fondo y otro grande a la derecha.

Usa los botones superiores o las teclas **1–4** para cambiar. **F12** guarda una captura de la propuesta visible en esta carpeta. Las imágenes `captura_01.png` a `captura_04.png` muestran las cuatro opciones.

El escenario recrea una oficina con escritorios, monitores, ventanas y tablero de expedientes. Tiene un desplazamiento lento de cámara y pequeñas variaciones de luz; los monitores cambian su iluminación. Los policías usan el modelo y las animaciones 3D existentes: reposo y saludo. Los cinco botones del menú siguen funcionando.

Esta escena conserva las cuatro composiciones iniciales para consultar la evolución del diseño.

## Segunda ronda: oficina real

Abre `res://UI/Menus/PropuestasOficinaReal.tscn` y ejecuta con **F6**. Esta escena
mantiene la disposición elegida de **Compañeros** y usa los muebles y la geometría
de `Mundo/Oficina.tscn`. Se desactivan los sistemas de partida y se retiran el
jugador y la interfaz de juego de esta vista. Los dos policías del menú siguen
animados delante del escenario.

- **01 Sin fondo:** se retira el panel azul detrás del logo y los botones.
- **02 Con degradado:** el mismo encuadre, con un velo oscuro que se desvanece
  desde el lado izquierdo hacia el centro.

Usa **1–2** o las pestañas superiores. **F12** guarda la vista actual. Las capturas
`oficina_real_01.png` y `oficina_real_02.png` comparan ambas versiones.

La versión **con degradado** fue elegida para `MainMenu.tscn`. El menú de inicio
usa una cámara con perspectiva dentro de la oficina; las paredes y mesas forman
un punto de fuga y la pared frontal queda fuera de la vista. La captura
`menu_final.png` muestra el menú de inicio sin los controles del comparador.
