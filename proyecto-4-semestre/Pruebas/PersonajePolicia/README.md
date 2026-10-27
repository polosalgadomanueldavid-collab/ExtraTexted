# Prueba del policía azul

Abre `PruebaPoliciaAzul.tscn` en Godot y ejecuta **F6** (escena actual). El juego principal conserva su escena y personaje.

- **WASD o flechas:** caminar según la cámara.
- **Shift:** correr.
- **Espacio:** saltar.
- **E:** saludar.
- **R / Volver al centro:** restablecer personaje y cámara.
- **Botón derecho + arrastrar:** orbitar la cámara; **rueda:** acercar/alejar.
- Los botones **Frente / Perfil / Espalda** muestran el modelo desde su orientación actual.

El borde de la plataforma permite probar caídas. Al caer al vacío, el personaje regresa al centro automáticamente. La escena instancia el recurso reutilizable `res://Personajes/PoliciaAzul/PoliciaAzul.tscn`.

Para comprobar el rig, las seis animaciones, el movimiento, el salto y las colisiones sin abrir una ventana:

```text
Godot --headless --path <proyecto-4-semestre> --script res://Pruebas/PersonajePolicia/prueba_policia_smoke.gd
```

Para guardar vistas y poses reales del motor, ejecuta `capturar_policia.gd` sin `--headless`, pasando una carpeta de salida después de `--`. La captura usa una ventana de 1280×720.

La iluminación de este laboratorio usa una sombra de contacto suave: las sombras direccionales y de foco produjeron bandas de color en el renderizador Compatibility del equipo de prueba. El ajuste está limitado a esta escena.
