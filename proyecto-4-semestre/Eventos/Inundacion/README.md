# Inundación

Cuarto evento del coordinador aleatorio: no coincide con apagón, terremoto o incendio. La oficina tarda cuatro segundos en llenarse y el evento permanece hasta reparar las tuberías de la pared derecha, al fondo de la zona de descanso.

- El agua llega a `1.10` unidades. Su acabado turquesa translúcido combina manchas de luz, cáusticas deformadas y espuma de contacto siguiendo la referencia visual. Tiene oleaje, volumen, fuga visible y sonidos originales de agua y salpicaduras.
- Mesas, sillas, sofá, mueble de café, computadora y cajones flotan con cabeceo suave. Sus posiciones horizontales y colisiones de navegación permanecen estables.
- Los cajones conservan el cambio periódico y las protecciones existentes para personaje, hoja y rutas. Al caer al agua producen una corona, un chorro de rebote, gotas balísticas y anillos de espuma que se disipan. Los impactos también deforman la superficie.
- La natación usa brazadas con entrada, tracción, empuje y recuperación, patadas alternas y remadas de reposo. La fase es continua: la velocidad real mezcla las poses al arrancar y frenar, sin reiniciar el ciclo. El cuerpo gira alrededor del pecho, manteniendo la cabeza fuera del agua; entrar y salir funde la animación durante 0.65 segundos.
- Cada mano libre salpica al completar la brazada y el desplazamiento deja una estela. La velocidad queda en el 55 % de la velocidad de caminar; correr y saltar no evitan la penalización. No suenan pasos terrestres.
- Los casos y estaciones siguen funcionando. La hoja puede transportarse, lanzarse y recogerse; flota si se suelta.
- Saludos, menú de emotes y poderes quedan bloqueados con «No se pueden usar emotes en este momento». Se reactivan al bajar el agua.
- La cafetera y el sofá esperan a que se repare la inundación.

## Reparación

Acércate al indicador **TUBERÍAS**, mira hacia la pared y pulsa **E**. Gira las piezas del tablero de 5 × 4 para conectar la entrada con el desagüe. El flujo azul permite ver la parte conectada.

**Clic** gira una pieza. **WASD / flechas** eligen una pieza y **E / Espacio / Enter** la giran. **Esc** o el botón Salir cierran el panel conservando los giros. El reloj de los casos continúa; la pausa global congela el evento. Tras conectar el circuito, el agua baja durante cuatro segundos y se restauran las poses originales y la velocidad.

## Pruebas

Abre `res://Pruebas/Inundacion/PruebaInundacion.tscn` y pulsa **F6**. Tras empezar el turno y recibir el primer caso, se activa la inundación. En la oficina normal también puedes usar **U** con el depurador del grafo visible.

```text
Godot --headless --path proyecto-4-semestre --fixed-fps 60 --script res://Pruebas/Inundacion/prueba_inundacion.gd
```

Para las capturas, ejecuta sin `--headless` y añade `-- --capturas`. Se guardan en `.godot/inundacion_qa/`. La prueba recorre 500 semillas del puzzle y comprueba natación, emotes, papel, estaciones, cajones, rutas, reparación, pausa, restauración, repetición y final de partida.

La prueba de continuidad mide las rotaciones finales del esqueleto durante arranque y frenado, las brazadas, la pausa, el vaciado y la limpieza de los efectos:

```text
Godot --headless --path proyecto-4-semestre --fixed-fps 60 --script res://Pruebas/Inundacion/prueba_transiciones_nado.gd
```

Sin `--headless`, `-- --capturas` exporta un PNG cada dos cuadros a `.godot/nado_secuencia/`. Añade `--detalle` para seguir al personaje de cerca en `.godot/nado_secuencia_detalle/`. El reloj del evento controla todos los shaders; al pausar se congelan tanto el agua como las animaciones y los efectos.
