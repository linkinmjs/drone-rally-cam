# Drone Rally Cam

Sos un operador de cámara aérea solitario en un rally. Llegás a pie al tramo, desplegás tu dron y tenés una sola oportunidad de conseguir la toma perfecta cuando pasa cada auto.

El diseño completo está en [docs/Drone Rally Cam — Documento de diseño.pdf](docs/). No es la palabra final: el juego va a cambiar a medida que lo probemos.

## Estado: Fase 1 + iteración de legibilidad y controles

La Fase 1 responde una sola pregunta: **¿es divertido esperar y filmar un solo paso de un auto?**

- **Un tramo hecho a mano.** Terreno generado por semilla, un camino de ripio de unos 1,4 km, árboles y rocas.
- **Un auto.** Sigue el camino con un perfil de velocidad calculado a partir del agarre y las curvas.
- **El dron.** Usa la física del [simulador de drones](https://github.com/linkinmjs/drone-simulator), con gimbal estabilizado, batería y grabación con REC.
- **Puntaje por cuadro.** Encuadre, tamaño, estabilidad y visibilidad. Cada clip recibe una nota C, B, A o S.
- **El jugador en primera persona.** Camina, despliega el dron desde la maleta, lo pilotea y lo guarda.

La segunda iteración suma lo que faltaba para entender el juego y volar como en el simulador:

- **Tablet con el mapa.** Muestra el camino, dónde estás vos, el dron y el auto, y cuándo llega el auto a tu punto. Se abre sola al empezar con el briefing.
- **Radio y checklist.** La radio avisa la largada, los parciales, la cuenta regresiva hasta tu punto con beeps y cuando el auto pasó. La checklist marca el paso actual.
- **Visor de vuelo del simulador.** Sticks en pantalla, horizonte, altura, velocidad, modo de vuelo y estado ARMADO / DESARMADO, con presets Cine, Piloto y Completo.
- **Vista de piloto.** Una cámara FPV fija al chasis que muestra cómo se inclina el dron. Se alterna con la del gimbal, que es la que graba.
- **Puntaje legible.** Barras en vivo con un consejo mientras grabás, resumen con el motivo de cada aspecto y pantalla de resultados al final.
- **Guía de pilotaje.** Dice qué hacer en cada momento (armar, despegar, encuadrar, grabar, aterrizar) y dónde poner el acelerador.
- **Menús del simulador.** Pausa, Opciones (Juego y HUD, Audio, Controles con calibración y zona muerta), Ajustes del dron (rates, expo, modo por defecto, ángulo y campo de visión de la cámara FPV) y Ayuda.

## Cómo se juega

El auto larga a los 45 segundos. Mirá en la tablet dónde pasa cerca tuyo, desplegá el dron, despegá antes de que llegue el auto y grabá su paso con el gimbal. Al terminar cada clip aparece la nota; al llegar el auto a meta, los resultados.

El mapeo del gamepad es el del simulador. Todo se puede reasignar en Opciones > Controles, y los carteles del juego muestran los nombres de tu mando (Xbox o PlayStation).

| Acción | Gamepad (Xbox / PlayStation) | Teclado y mouse |
| --- | --- | --- |
| Caminar / mirar | Stick izquierdo / derecho | WASD / mouse |
| Trotar / agacharse | L3 / B (○) | Shift / Ctrl |
| Desplegar o guardar el dron | X (□) | E |
| Tablet con el mapa | Cruz ↑ | M |
| Tomar o soltar el control | Y (△) | Tab |
| Armar / desarmar | LB (L1) | Espacio |
| Subir y bajar / girar | Stick izquierdo | W y S / A y D |
| Avanzar y moverse de costado | Stick derecho | Flechas o mouse |
| Cambiar modo de vuelo | A (✕) | M |
| Grabar / detener | RB (R1) | Clic izquierdo |
| Vista de piloto / gimbal | X (□) | C |
| Inclinar el gimbal | LT y RT (L2 y R2) | R y F o rueda |
| Volver al punto de despegue | Back (Share) | Retroceso |
| Pausa | Start (Options) | Esc |
| Reiniciar la etapa al terminar | | Enter |

Detalles del vuelo:

- **Modo por defecto: Estabilizado.** Se elige en Ajustes del dron. Los sticks mandan la velocidad directamente: el dron responde enseguida y, al soltarlos, frena hasta un punto calculado según su velocidad y se queda quieto ahí. Se arma con el acelerador al centro.
- **Actitud y Acro.** Como en el simulador: el acelerador controla el empuje y se arma con el acelerador abajo. Usan los rates y la expo de Ajustes del dron. Conviene volarlos con la vista de piloto.
- **Mouse.** Solo mueve el dron cuando usás teclado y mouse. Si tocás el gamepad, el mouse deja de actuar hasta que presiones una tecla.
- **Soltar el control.** Si soltás el control en pleno vuelo, el dron pasa a Estabilizado y se queda quieto.
- **Choques y batería.** Un choque fuerte desarma el dron y pierde el clip. Al 0 % de batería el dron cae y hay que guardarlo en la maleta para cambiarla.

La configuración se guarda en `user://config` (Controles, Audio, Juego y HUD, Ajustes del dron).

## Abrir el proyecto

Requiere **Godot 4.7** con el renderer Forward+. El proyecto está en la carpeta `godot/`: abrí `godot/project.godot` desde el editor.

- **Escena principal:** `res://game/stage.tscn`, la etapa completa.
- **Campo de pruebas de vuelo:** `res://debug/test_flat_level.tscn`, un piso plano con un auto que da vueltas a un óvalo. Tab alterna entre la cámara del dron y una cámara de persecución.
- **Tramo:** `res://world/stages/stage_01.tscn`. El nodo `StageBuilder` tiene los puntos del camino, la semilla y el botón **Regenerar**.

## Estructura

| Carpeta | Contenido |
| --- | --- |
| `godot/drone/` | Física, controlador de vuelo, modos, radio, gimbal, batería y sensor de choques |
| `godot/world/` | Generador del tramo, materiales y escenas de tramos |
| `godot/car/` | Auto, perfil de velocidad y sonido de motor |
| `godot/filming/` | Grabación y puntaje de tomas |
| `godot/player/` | Jugador en primera persona, maleta e interactuables |
| `godot/game/` | Etapa y máquina de estados de control |
| `godot/ui/` | Visor del dron, HUD de la etapa, tablet y mapa, radio, guía, resumen y resultados |
| `godot/hud/` | HUD de vuelo tomado del simulador (sticks, horizonte, lecturas, modo, estado) |
| `godot/gui/` | Menús tomados del simulador: pausa, opciones, controles y calibración, ajustes del dron, ayuda y theme |
| `godot/localization/` | Textos de los menús y el HUD en español e inglés |
| `godot/autoloads/` | `Controls`, `EventBus`, `Audio`, `GameSettings`, `QuadSettings`, `UI` y `StickNavigation` |
| `godot/debug/` | Campo de pruebas, cámaras de debug, chequeos automáticos y capturas |

Estos son los valores de diseño que más conviene tocar al probar:

- **Espera hasta la largada:** `start_delay` en `game/stage.tscn`.
- **Autonomía:** `capacity_mah` en el nodo `Battery` del dron. Hoy da unos 3 minutos de vuelo estacionario.
- **Auto:** `skill`, `grip` y `top_speed` en `car/rally_car.tscn`.
- **Puntaje:** pesos y umbrales en `filming/shot_scorer.gd` y `filming/shot_report.gd`.

## Chequeos automáticos

Hay trece chequeos que corren sin ventana. Usan su propia carpeta de configuración, así que tus ajustes no cambian los resultados:

- **Carga:** todos los recursos del juego cargan sin errores.
- **Dron:** vuelo, respuesta y frenado del Estabilizado, choque, despegue en pendiente, aterrizaje y recuperación.
- **Auto:** tramo, perfil de velocidad, llegada a meta e impacto contra el dron.
- **Entrada:** teclado, mouse, mapeo del gamepad, cambio de dispositivo, zona muerta y nombres de botones.
- **Gimbal y batería.**
- **Puntaje.**
- **Estados de control:** caminar, desplegar, pilotear y guardar.
- **Etapa:** una pasada completa del loop.
- **Menús:** pausa, opciones y cada submenú, confirmación y reanudar sin que el botón llegue al dron.
- **Ajustes:** guardar y cargar rates, cámara, modo por defecto y zona muerta, y que el dron los use.
- **Vista de piloto:** cambio de cámara, horizonte y datos del HUD.
- **Información de la etapa:** mapa, cuenta regresiva, radio, checklist y marcador del dron.
- **Puntaje en pantalla:** consejos, motivos, guía de pilotaje y resultados.

```sh
godot --headless --path godot --import
godot --headless --path godot --fixed-fps 100 res://debug/headless_checks/check_all.tscn
```

Para correr solo algunos, agregá `-- --only=drone`. El nombre se compara por coincidencia parcial. Después de agregar un `class_name` nuevo, repetí `--import` para que Godot actualice la caché de clases.

Para ver el juego sin jugarlo, este comando guarda capturas de varias vistas de la etapa. Necesita GPU:

```sh
godot --path godot res://debug/tools/screenshot_tour.tscn -- --out=C:/carpeta/de/capturas
```

## Publicación en itch.io

Cada push dispara `.github/workflows/deploy-to-itch.yml`. El workflow importa los recursos con Godot 4.7, corre los chequeos, exporta Windows y Linux y, solo en pushes a `master`, sube los builds a itch.io con butler en los canales `windows` y `linux`.

Para que funcione:

1. Creá el proyecto en itch.io con **Kind of project: Downloadable**.
2. En GitHub, en *Settings > Secrets and variables > Actions*, configurá estos secretos:
   - `BUTLER_API_KEY`, que se obtiene en https://itch.io/user/settings/api-keys.
   - `ITCHIO_GAME`, el nombre del juego en itch.
   - `ITCHIO_USERNAME`, tu usuario de itch.

## Origen y licencia

La simulación de dron viene de [GodotDrone](https://github.com/Cykyrios/GodotDrone), de Cykyrios, a través de su adaptación a Godot 4.7 en [drone-simulator](https://github.com/linkinmjs/drone-simulator). Ese código es GPL-3.0, así que este juego también se distribuye bajo la **GPL-3.0** (ver [LICENSE](LICENSE)). El detalle de qué archivos derivan del original y qué se modificó está en [NOTICE.md](NOTICE.md).
