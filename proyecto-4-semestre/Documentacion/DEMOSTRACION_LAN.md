# Demostración LAN para dos jugadores

## Preparación

1. Usar la misma revisión del proyecto y Godot 4.7 en ambos computadores Windows. Para una entrega autónoma, instalar las plantillas de exportación **de esa misma versión** desde el administrador de plantillas de Godot y exportar Windows Desktop x86_64. Copiar el ejecutable y su archivo `.pck`, si se exporta por separado, a ambos equipos.
2. Conectar ambos equipos a la misma red. El anfitrión necesita recibir UDP 7000. Si Windows muestra su aviso de firewall, permitir el juego en la red privada usada para la demostración. No hace falta abrir puertos del router para una LAN.
3. Abrir el juego y elegir **Jugar → Crear partida LAN**, indicando alias. La sala muestra la IP local; usar la dirección de la conexión que comparte con el compañero.
4. En el segundo equipo: **Jugar → Unirse por IP**, escribir la IP del anfitrión y el alias propio.
5. Ambos marcan **Estoy listo**. El anfitrión pulsa **Iniciar turno**. Los dos deben cerrar la guía inicial antes de que avance el mundo.

Para jugar solo se conserva **Jugar → Individual** y la identificación de la clasificación existente.

## Demostración jugable

- Mostrar ambos alias y corduras. Cada jugador toma una denuncia en el computador con **E**. Deben aparecer dos hojas de casos distintos.
- Completar Evidencias y Verificación con sus controles habituales. Una estación ocupada debe rechazar el otro caso. Seguridad permite dejar el archivo desencriptándose y volver a recogerlo.
- Completar una estación, lanzar la hoja con **E** y dejar que el compañero la recoja y termine el caso. Cada participante recupera 5 de cordura; el saldo aumenta por una única recompensa.
- Comprar desde los dos equipos. Solo el comprador recibe el producto; ambos ven el descuento en **Saldo del equipo**. La clasificación conserva los puntos ganados. Con saldo para un solo producto, la segunda compra debe rechazarse sin cobrar.
- Probar café, los dos asientos, chocolate y dona. La cordura o el efecto personal solo cambia para quien los usa.
- En cada evento, comprobar en ambos equipos el escenario, sonidos, efectos y reparación: apagón, terremoto, incendio, inundación, lava e hielo. Usar el extintor desde el cliente y comprobar la recuperación de las mesas en el anfitrión.
- En incendio aparecen dos extintores: recoger uno por jugador y apagar mesas distintas. En un atasco de impresora aparecen dos llaves numeradas; cualquiera que tenga una puede reparar llevando la hoja correspondiente. No se pueden acaparar ambas herramientas del mismo tipo. Al agotarse un portador, su herramienta vuelve al punto de recogida y la del compañero se conserva. Individual mantiene una unidad.
- Caminar de frente al compañero: ambos cuerpos deben bloquearse. Probar también desde el cliente, rodearse y saltar. Un compañero agotado deja libre el paso.
- Usar papa tiempo: ambos pueden moverse mientras se detienen los plazos del mundo durante 12 segundos. Intentar otro uso y comprobar que conserva la carga. Probar reparación frente a Avatar: una resolución ya confirmada impide consumir la segunda carga.
- Abrir pausa o guía en ambos equipos. Cerrar solo una no debe reanudar el mundo. Cerrar las dos sí.
- Agotar al anfitrión. Debe observar al compañero y seguir funcionando el servidor; el superviviente puede recuperar la hoja y continuar. Agotar al segundo debe producir un único final compartido.
- Reintentar desde el anfitrión: ambos vuelven con 100 de cordura, sin saldo ni objetos anteriores. Cerrar una ventana durante la sesión debe llevar a la otra al menú con aviso; crear una sala nueva debe funcionar.

## Pruebas automáticas en un computador

Cerrar otras sesiones que usen UDP 7000. Desde PowerShell, en la raíz del repositorio:

```powershell
& .\proyecto-4-semestre\Pruebas\Multijugador\ejecutar_pruebas.ps1 `
  -Godot 'C:\ruta\Godot_v4.7-stable_win64_console.exe'
```

El script ejecuta reglas, menú, dos procesos con oficina real, versión incompatible y tercera conexión a una sala llena. Guarda salida y errores por proceso en `proyecto-4-semestre/.godot/qa_lan/`. Devuelve error ante una aserción fallida, error del motor o tiempo agotado. No modifica la clasificación personal: la prueba de partida usa archivos `user://prueba_lan_<PID>.json` separados.

Para ejecutar la partida de prueba manualmente, abrir dos terminales y lanzar una orden en cada una:

```powershell
& $Godot --headless --path .\proyecto-4-semestre --script res://Pruebas/Multijugador/prueba_lan.gd -- --host
& $Godot --headless --path .\proyecto-4-semestre --script res://Pruebas/Multijugador/prueba_lan.gd -- --client
```

`$Godot` debe contener la ruta del ejecutable. La prueba mueve personajes y resuelve minijuegos automáticamente; no es el modo de demostración para jugadores. Para revisar la sala con renderizado real, ejecutar `prueba_menu_lan.gd` sin `--headless`; guarda `lan_menu.png` y `lan_sala.png` en `.godot/`.

El protocolo de estas herramientas es `extratexted-lan-2`: actualizar ambos equipos antes de jugar. Para previsualizar la nueva llave compartida por el objeto y la animación, ejecutar `vista_herramientas.gd` sin `--headless`; guarda `.godot/vista_llave.png`.

## Registro pendiente de dos equipos reales

| Dato | Completar durante la demostración |
| --- | --- |
| Revisión Git y versión de Godot | |
| Exportación Windows y fecha | |
| Equipos e IP del anfitrión | |
| Ethernet o Wi-Fi | |
| Casos separados y colaboración | |
| Compras simultáneas y saldo | |
| Eventos y poderes en ambos equipos | |
| Pausa superpuesta, eliminación y reinicio | |
| Desconexión y sesión nueva | |
| Incidencias observadas | |

Consultar los resultados locales y el fallo preexistente de la prueba física del terremoto en [PLAN_MULTIJUGADOR.md](PLAN_MULTIJUGADOR.md). La exportación y la prueba entre dos computadores siguen pendientes de ejecución; no deben presentarse como verificadas.
