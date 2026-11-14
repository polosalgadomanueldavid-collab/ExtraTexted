# Hielo

Una fuga de nitrógeno en descanso congela la oficina. Entra en el sorteo compartido de seis eventos, sin solaparse con los demás. Permanece hasta reparar la fuga.

- Entrada de 3 s: el hielo cristaliza desde la tubería, cae nieve y la iluminación se vuelve azul. La nieve se acumula en montículos de altura irregular sobre las caras superiores de mesas y cajones, con bordes suaves y zonas del mueble visibles entre ellos. Crece y se retira con el evento; sigue al mueble sin añadir colisiones. El piso tiene placas deformadas, vetas suaves, manchas de escarcha y orillas blanquecinas; no sube ni ondula como el agua.
- Aceleración de 2,4 m/s² y frenado de 0,38 m/s². Cada 4 s desde el inicio se congela durante 1,25 s. No se aplica fuerza horizontal durante ese intervalo: conserva velocidad, gravedad y colisiones. La cápsula facetada crece y se retira alrededor del personaje sin añadir colisiones.
- Las tareas, papeles, computador, café y sofá siguen disponibles. Sus gestos y paneles mantienen el frenado normal; congelarse no bloquea la tecla E ni pausa los casos.
- Aviso de inicio azul, copo de nieve centrado arriba y marcador hacia **NITRÓGENO**. El copo sustituye al recuadro: sin texto ni números, seis cristales se vacían hasta la próxima congelación y vuelven a llenarse para contar sus 1,25 s. La primera espera dura 4 s y las siguientes 2,75 s. Congelado, el copo brilla en blanco; al sellar la fuga desaparece. La tubería está en la pared derecha de descanso, separada de las tuberías de agua. Su acceso está protegido al distribuir cajones.
- **E frente a la tubería** abre el puzzle: aprieta cuatro tuercas siguiendo el orden cruzado indicado, durante tres pasadas. Clic o WASD/flechas para elegir, E/Espacio/Enter para apretar. Un error no borra el progreso; Esc permite salir y continuar después. La pausa global detiene todo.
- El puzzle conserva el gabinete, la tubería, la ficha de orden y el arte de Barandica, con las animaciones de tuercas de issa: giro suave de 60° por apriete, rebote y elevación al pasar el cursor. Las arandelas permanecen fijas y los números no giran.
- Al sellar la fuga, el frío desaparece durante 2,5 s y se restauran materiales, luces y movimiento. El final de partida también limpia el evento y cierra el puzzle.

Prueba manual: abre `res://Pruebas/Hielo/PruebaHielo.tscn` y pulsa **F6**. También **Ñ** con el depurador de grafo visible.

Prueba automática: `Godot --headless --fixed-fps 60 --path proyecto-4-semestre --script res://Pruebas/Hielo/prueba_hielo.gd`.
