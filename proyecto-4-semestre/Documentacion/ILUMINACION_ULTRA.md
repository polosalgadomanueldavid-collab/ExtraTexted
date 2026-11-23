# Calidad Ultra

Ultra se elige en **Opciones → Calidad visual → Ultra**. Alta sigue siendo el
valor predeterminado; Baja, Media y Alta conservan el aspecto base aprobado.
La preferencia se guarda con los ajustes locales de cada equipo, sin afectar
reglas, física ni sincronización LAN.

## Tratamiento visual

El perfil toma del menú los cálidos `ffe0b1` y `ffc37c`, los azules `84caff` y
`77baff` y su ambiente azul `819cba` con energía 0,26. Acentúa las luces cálidas
de trabajo y la luz azul de ventanas y descanso. El piso recibe un reflejo más
definido (rugosidad 0,60, especular 0,30) frente al acabado base (0,74 / 0,22).

Se mantienen las diez luces fijas, sus posiciones, alcances y conos. No se
añaden sombras dinámicas, niebla, SSAO, glow, iluminación global, texturas ni
pasadas de pantalla completa. Ultra conserva la resolución interna nativa y la
cantidad de partículas de Alta; no es un modo de supersampling. En el menú
también conserva los ajustes de Alta, sin reducir su antialiasing o sus sombras.

El objetivo es acercar el contraste y la paleta al menú dentro del presupuesto
de render existente. No reproduce sus sombras ni su composición de cámara.

## Aplicación y restauración

`Mundo/aspecto_oficina.gd` conserva los valores originales de la escena y cambia
el perfil al recibir `CalidadVisual.nivel_cambiado`. No ejecuta un bucle por
fotograma ni crea luces/materiales al cambiar de calidad. El entorno se duplica
una vez por oficina; el piso reutiliza el material local que prepara Terremoto.
Sus grietas, textura y máscara permanecen intactas.

Si se cambia de calidad durante el apagón o su reparación elemental, el perfil
de la oficina espera a que se restaure la luz. Así la transición conserva sus
energías y no enciende focos antes de tiempo. El ajuste elegido sigue guardado y
se aplica automáticamente al terminar. Cambiar a un nivel inferior restaura los
valores base; reiniciar una partida con Ultra no modifica los recursos originales.

Ambos perfiles usan las mismas características de shader. Solo cambian colores,
energías y valores uniformes, evitando introducir variantes de efectos al abrir
Opciones. El calentamiento existente continúa recorriendo trabajo y descanso.

## Verificación

```powershell
& $Godot --headless --path proyecto-4-semestre --script res://Pruebas/Iluminacion/prueba_ultra.gd
& $Godot --path proyecto-4-semestre --audio-driver Dummy --script res://Pruebas/Iluminacion/prueba_ultra.gd -- --medir
& $Godot --path proyecto-4-semestre --audio-driver Dummy --script res://Pruebas/Iluminacion/prueba_iluminacion.gd -- --etiqueta=ultra --calidad=3
```

La prueba específica comprueba la opción del menú, cambios en pausa, vuelta a
los valores base, reutilización de recursos, máscara del terremoto, apagón,
restauración elemental, reinicio con Ultra y que no se escriban preferencias.
Con `--medir` compara Alta/Ultra/Ultra/Alta dentro del mismo proceso, en trabajo
y descanso, con idéntica cámara, resolución y duración. Guarda capturas y
`resultado.json` en `.godot/qa_ultra`. Los tiempos no incluyen la lectura de
capturas, el calentamiento o el inicio de eventos; no certifican todas las
situaciones de una partida ni ausencia absoluta de tirones.

## Resultado local del 23 de noviembre de 2026

Godot 4.7 stable, Compatibility, Intel Iris Xe, 1280 × 720. La prueba con
renderizado pasó **118 comprobaciones, sin fallos**, incluidos el reinicio con
Ultra y la vuelta al aspecto base. Se revisaron las capturas de ambas zonas.
La prueba de iluminación arrancando directamente en Ultra pasó otras **75
comprobaciones** en headless, incluidos lava e inundación. El fondo animado del
menú también pasó su prueba con el nivel 3, sin errores funcionales.

| Vista | Llamadas de dibujo Alta (mediana) | Ultra (mediana) |
| --- | ---: | ---: |
| Trabajo | 181 | 181 |
| Descanso | 206 | 206 |

En las dos pasadas Ultra, el p95 de cuadro fue 14,45 / 13,14 ms en trabajo y
17,16 / 12,70 ms en descanso. Las pasadas Alta fueron 23,11 / 13,76 ms y
24,27 / 14,83 ms, respectivamente. No se interpreta como una aceleración de
Ultra: había otra medición gráfica ejecutándose en el equipo y las muestras
duran cuatro segundos. La evidencia más estable es que el perfil mantiene el
trabajo de dibujo y no añade efectos, píxeles ni luces. Queda pendiente una
medición aislada y prolongada para certificar tiempos en todas las situaciones.

Capturas de esta ejecución en `output/iluminacion_ultra/` (salida local ignorada
por Git). Persiste el aviso previo de instancias ObjectDB al cerrar la oficina;
la ejecución headless también informa de un recurso todavía en uso al cerrar.
No se atribuye su resolución a este cambio.
