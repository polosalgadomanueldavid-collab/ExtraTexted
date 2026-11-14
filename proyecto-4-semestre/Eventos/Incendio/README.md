# Incendio

El selector compartido elige apagón, terremoto o incendio tras 40–65 segundos de descanso entre eventos. No se solapan. El anuncio de INCENDIO usa el mismo panel de cómic que los demás eventos.

Las 17 mesas del grupo `mesas_incendiables` incluyen las cinco estaciones, el computador y las mesas vacías del perímetro. Solo estas cuentan para el porcentaje y se pueden apagar. Al completar el apagado de una mesa, las vecinas comienzan una contracción suave de sus llamas durante **1,1 segundos**, desde su intensidad actual. Se recuperan al terminar esa transición y el evento espera a que se extinga la última llama. La pausa congela la animación. No hay reacción en cadena ni se saltan vecinas ya apagadas para alcanzar mesas más lejanas. **Abajo, cada tramo es independiente: el efecto no cruza el hueco central ni gira hacia las mesas laterales**, en ninguno de los dos sentidos. Las esquinas superiores sí conservan su vecindad. El PC no imprime y Seguridad pausa su desencriptado mientras arden.

El extintor aparece señalado en la zona de descanso. **E** lo recoge con el gesto del personaje. Se transporta a la espalda y se usa **manteniendo E**, mirando una mesa cercana: tres segundos acumulados por mesa. Soltar E, alejarse, perder el foco de la ventana o pausar detiene la espuma y el sonido. La pausa requiere una pulsación nueva al volver. El avance parcial se conserva. La hoja se guarda a la espalda durante el chorro sin perder la denuncia.

La interfaz usa la **barra B** aprobada: cápsula crema compacta, llama coral, porcentaje y conteo de mesas debajo. El **marcador C del extintor** muestra el icono libre con halo abierto, etiqueta, puntero y distancia. La tecla E aparece solo cuando el jugador puede recogerlo. Si el objeto sale del encuadre, el marcador se mantiene en el borde de la zona de juego con una flecha hacia él; desaparece al equiparlo y vuelve en el siguiente incendio. El indicador de luz conserva su diseño existente.

El progreso de la mesa cercana usa el diseño **Arco abierto**: un arco fino de 270° en el centro inferior, sin panel de fondo, con una mesa procedural al centro y el porcentaje en la abertura inferior. Se llena según el apagado real de esa mesa y conserva su avance al soltar E. La pista cambia de «Mantén para apagar» a «Apagando…» mientras sale espuma. Se muestra únicamente al apuntar a una mesa en llamas con el extintor equipado.

Los cajones dejan de cambiar de lugar desde el inicio. A los **10 segundos de juego** comienza una animación de **1,1 segundos**: se oscurecen, tiemblan y se hunden mientras aparecen restos y polvo. Mantienen su colisión y sus casillas bloqueadas durante todo el incendio. La pausa congela también esta animación.

Al apagar la última mesa, se retiran las cenizas y se genera una distribución nueva de cajones normales. Su reloj vuelve a empezar desde diez segundos. Los mismos treinta objetos se reutilizan: se restauran mallas, transformaciones y materiales sin conservar hollín ni animaciones pendientes. La distribución protege al jugador, la hoja suelta y los accesos a las mesas y al extintor.

`fuego_3d.gd` adapta el video de referencia recibido (`WhatsApp Video 2026-11-12 at 1.49.48 AM.mp4`): siluetas redondas con cuello, puntas curvas, movimiento de estiramiento y pequeñas lenguas que se desprenden hacia arriba. El fuego tiene volumen 3D; el shader pinta sobre la malla el exterior naranja, el centro amarillo y el núcleo crema, visibles desde las distintas cámaras. Los ciclos de las llamas son independientes y respetan la pausa. El extintor, su manguera articulada y la espuma también se construyen en Godot; no necesitan Blender ni texturas externas.

La voz usa la expresión **estrés** existente. Los bucles originales de fuego y chorro se regeneran con `herramientas/generar_sonidos_incendio.py` desde la raíz del repositorio.

El incendio da **24 segundos de gracia** antes de desgastar la cordura en toda la oficina. Después resta **1 punto por segundo**, aumenta a **2 puntos/s tras 60 segundos** y a **3 puntos/s tras 90 segundos**, hasta apagar todas las mesas. Se conservan las fracciones entre cuadros, la pausa congela el desgaste y cada incendio reinicia la gracia. El HUD indica la cuenta regresiva y luego la pérdida por segundo. Llegar a cero termina la partida con la causa «Incendio sin apagar».

## Probar

- Abrir `res://Pruebas/Incendio/PruebaIncendio.tscn` y pulsar **F6**. El incendio comienza a los cinco segundos de juego, después de cerrar la ayuda.
- En la oficina, **F3** abre depuración y **I** solicita el incendio cuando no hay otro evento activo.
- Prueba automática: `Godot --headless --fixed-fps 60 --path proyecto-4-semestre --script res://Pruebas/Incendio/prueba_incendio.gd`.
- Para capturas, ejecutar la prueba sin `--headless` y añadir `-- --capturas`. Se guardan en `.godot/incendio_qa`.
