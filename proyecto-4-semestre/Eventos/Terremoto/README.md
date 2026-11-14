# Terremoto

El evento dura **24 segundos**: ocho de aviso, ocho de rotura y ocho de recuperación. Al romperse el suelo aparecen **entre diez y doce grietas**, incluida una gigante de unos **4 × 2,3 metros en descanso**, que hay que rodear. Su contorno dorado se dibuja durante el aviso y puede abrirse debajo del jugador si permanece allí; descanso también tiembla y deja de ser refugio durante el terremoto. Las estrechas se pueden saltar con **Espacio**.

La alfombra central permanece en su sitio durante el aviso y cae hacia la grieta gigante al romperse el suelo, con el mismo vuelco de los bloqueos. Se oculta tras hundirse y recupera su posición, giro y escala al terminar o interrumpirse el evento; la animación respeta la pausa.

Después de abrirse las grietas caen **entre catorce y veinte montones de escombros del techo en la parte superior**, más **un máximo de tres en descanso**, en tres oleadas separadas por 2,6 segundos. Se reservan los huecos de los derrumbes superiores antes de completar las grietas restantes. Se priorizan los recorridos rectos abiertos y los cruces entre grietas, conservando rutas a las estaciones; en distribuciones densas se acortan algunas grietas pequeñas para dejar sitio a los escombros, sin estrechar los saltos ni reducir la gigante. Algunos aplastan cajones al impactar y conservan ocupada su casilla; los cajones vuelven al pool al terminar el evento. Una marca rectangular rayada señala la huella del montón, con una exclamación central y un borde que se consume y cambia de amarillo a rojo hasta el impacto. El aviso dura 0,85 segundos y la caída 0,72 segundos; sobre los cajones, la marca aparece a la altura de su tapa. Varios montones ocupan dos casillas y cierran pasos más anchos. Las placas de hormigón y yeso tienen cantos rotos, áridos, fisuras y varillas dobladas; las piezas giran por separado durante la caída y se asientan con un pequeño rebote. Al impactar levantan polvo, suenan y bloquean físicamente los pasos entre grietas. Hay que rodearlos hasta que termine el evento.

La distribución conserva rutas a las estaciones y sus accesos, protege la hoja suelta y reserva accesos a descanso, sus servicios y las estaciones. La grieta gigante puede ocupar la posición inicial del jugador después de los ocho segundos de aviso; las grietas pequeñas y los derrumbes evitan esa posición al planificarse. Las rutas se recalculan con cada impacto. Si el jugador entra en el punto de caída en el último instante, se aparta a suelo conectado para evitar quedar dentro del obstáculo. Al finalizar o interrumpirse el evento se retiran las grietas y los escombros, incluidas sus colisiones.

Para probarlo en la oficina, activa la depuración con **F3** y pulsa **T**, también desde descanso. Pruebas automatizadas desde la carpeta del proyecto:

```text
godot --headless --fixed-fps 60 --script res://Pruebas/Terremoto/prueba_terremoto.gd
godot --headless --fixed-fps 60 --script res://Pruebas/Terremoto/prueba_escombros.gd
godot --headless --fixed-fps 60 --script res://Pruebas/Terremoto/prueba_bordes_grietas.gd
```

La prueba de escombros admite `-- --capturas` al ejecutar con renderizado y guarda las imágenes en `.godot/terremoto_qa/`.
