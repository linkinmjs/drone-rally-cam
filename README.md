# Drone Rally Cam

Sos un operador de cámara aérea solitario en un rally. Llegás a pie al tramo, desplegás tu dron y tenés una sola oportunidad de conseguir la toma perfecta cuando pasa cada auto.

El diseño completo está en [docs/Drone Rally Cam — Documento de diseño.pdf](docs/). No es la palabra final: el juego va a cambiar a medida que lo probemos.

## Estado: Fase 1, iteración de legibilidad y controles, front-end y mundo estilizado (v0.3.0)

La Fase 1 responde una sola pregunta: **¿es divertido esperar y filmar un solo paso de un auto?**

- **Un tramo hecho a mano.** Terreno generado por semilla, un camino de ripio de unos 1,4 km, árboles y rocas.
- **Un auto.** Sigue el camino con un perfil de velocidad calculado a partir del agarre y las curvas.
- **El dron.** Usa la física del [simulador de drones](https://github.com/linkinmjs/drone-simulator), con gimbal estabilizado, batería y grabación con REC.
- **Puntaje por cuadro.** Encuadre, tamaño, estabilidad y visibilidad. Cada clip recibe una nota C, B, A o S.
- **El jugador en primera persona.** Camina, despliega el dron desde la maleta, lo pilotea y lo guarda.

La segunda iteración suma lo que faltaba para entender el juego y volar como en el simulador:

- **Tablet con el mapa.** Muestra el camino, dónde estás vos, el dron y el auto, y cuándo llega el auto a tu punto. Se abre sola al empezar con el briefing.
- **Radio y checklist.** La radio avisa la largada, los parciales, la cuenta regresiva hasta tu punto con beeps y cuando el auto pasó. La checklist marca el paso actual.
- **Visor del dron.** Pensado para filmar y ordenado en regiones fijas que no se superponen: REC, cámara en vista, modo y estado arriba a la izquierda; una sola línea de avisos y la radio arriba al centro; batería y lecturas (altura sobre el suelo, velocidad, velocidad vertical, distancia, gimbal y rumbo) arriba a la derecha; horizonte real de la cámara en el centro; guía o puntaje y sticks abajo. Presets Cine, Piloto y Completo, con vista previa en Opciones > Juego y HUD.
- **Vista de piloto.** Una cámara FPV fija al chasis que muestra cómo se inclina el dron. Se alterna con la del gimbal, que es la que graba.
- **Puntaje legible.** Barras en vivo con un consejo mientras grabás, resumen con el motivo de cada aspecto y pantalla de resultados al final.
- **Guía de pilotaje.** Dice qué hacer en cada momento (armar, despegar, encuadrar, grabar, aterrizar) y dónde poner el acelerador.
- **Menús propios.** Identidad "Rally al atardecer": fondos oscuros cálidos, texto crema y el naranja de las cintas de rally, con logo e icono propios. La pausa muestra el estado de la etapa, las tomas entregadas y los controles principales; Opciones es un hub de tarjetas (Juego y HUD con vista previa del visor, Audio, Controles con calibración y zona muerta); Ajustes del dron tiene rates, expo, modo por defecto, ángulo y campo de visión de la cámara FPV; la Ayuda dibuja los botones de tu mando. Los menús sobre la etapa oscurecen y desenfocan la escena y ocultan el visor.

Con el front-end el juego ya es un juego completo de punta a punta:

- **Título y menú principal.** El juego arranca en la pantalla de título, con el logo sobre una escena 3D. El menú principal lleva a Jugar (la última etapa desbloqueada), Etapas, Opciones, Ayuda y Salir.
- **Dos etapas.** "Bosque de pinos" y "Lomas del valle", más larga y con horquillas cerradas. La segunda se abre al entregar en la primera una toma B o mejor.
- **Progreso guardado.** La mejor nota de cada etapa, las tomas entregadas y los desbloqueos quedan guardados entre sesiones.
- **Carga y transiciones.** Mientras se genera el tramo, una pantalla de carga muestra el mapa de la etapa, la barra de progreso real y un consejo, sin congelar la ventana. Los cambios de pantalla usan un fundido o un obturador de cámara.
- **Resultados con progreso.** La mejor nota de la pasada, "¡Nuevo récord!" y la etapa desbloqueada, con Siguiente etapa, Repetir etapa y Menú principal. La pausa ofrece "Volver al menú".

El mundo tiene un estilo low-poly propio, sin assets externos:

- **Luz de atardecer.** Un sol bajo y cálido con sombras largas y un cielo y una lejanía cálidos, compartidos por las dos etapas y el título.
- **Terreno, camino y bosque.** El terreno cambia de tono con la altura y oscurece los pliegues. El camino tiene corona, banquinas y huellas. Hay pinos, árboles frondosos y arbustos que se mecen con el viento, y matas de pasto cerca del camino.
- **Ambiente de rally.** Arco de largada y pancarta de meta, carteles de kilómetro, cinta y estacas en las curvas cerradas, fardos en las tres más cerradas, público, comisarios con bandera, la camioneta de asistencia y un alambrado.
- **Un auto vivo.** Las ruedas giran y las delanteras doblan, la carrocería se inclina en las curvas y al frenar, lleva su número y levanta polvo al correr.
- **Dron, maleta y jugador.** El gimbal tiene su cámara a la vista, la maleta se abre al desplegar y se cierra al guardar, la cámara se balancea al caminar y la maleta se ve en tu mano mientras la llevás.
- **Efectos.** Chispas y polvo al chocar, con una sacudida en la vista de piloto; polvo al desplegar y al guardar; un anillo de polvo al aterrizar; y una viñeta y un grano suaves en las cámaras del dron. Cada evento ya llama a `Audio.play_event`, que todavía no suena.

## Cómo se juega

Desde el menú principal, Jugar te lleva a la última etapa desbloqueada. El auto larga a los 45 segundos. Mirá en la tablet dónde pasa cerca tuyo, desplegá el dron, despegá antes de que llegue el auto y grabá su paso con el gimbal. Al terminar cada clip aparece la nota; al llegar el auto a meta, los resultados.

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

En los menús, la cruceta o cualquiera de los dos sticks mueven el foco, ✕ acepta, ○ vuelve y L1/R1 pasan de columna o de pestaña (con teclado: flechas, Enter, Esc y Tab). Si usás una radio sin botones, elegí el esquema Betaflight o Yaw en Opciones > Juego y HUD.

Detalles del vuelo:

- **Modo por defecto: Estabilizado.** Se elige en Ajustes del dron. Los sticks mandan la velocidad directamente: el dron responde enseguida y, al soltarlos, frena hasta un punto calculado según su velocidad y se queda quieto ahí. Se arma con el acelerador al centro.
- **Actitud y Acro.** Como en el simulador: el acelerador controla el empuje y se arma con el acelerador abajo. Usan los rates y la expo de Ajustes del dron. Conviene volarlos con la vista de piloto.
- **Mouse.** Solo mueve el dron cuando usás teclado y mouse. Si tocás el gamepad, el mouse deja de actuar hasta que presiones una tecla.
- **Soltar el control.** Si soltás el control en pleno vuelo, el dron pasa a Estabilizado y se queda quieto.
- **Choques y batería.** Un choque fuerte desarma el dron y pierde el clip. Al 0 % de batería el dron cae y hay que guardarlo en la maleta para cambiarla.

La configuración se guarda en `user://config` (Controles, Audio, Juego y HUD, Ajustes del dron) y el progreso en `user://save/progress.tres`.

## Abrir el proyecto

Requiere **Godot 4.7** con el renderer Forward+. El proyecto está en la carpeta `godot/`: abrí `godot/project.godot` desde el editor.

- **Escena principal:** `res://game/main.tscn`, el título y el menú principal.
- **Etapa sola:** `res://game/stage.tscn` se puede abrir y correr directo (F6): juega la etapa 1 sin pasar por el menú.
- **Campo de pruebas de vuelo:** `res://debug/test_flat_level.tscn`, un piso plano con un auto que da vueltas a un óvalo. Tab alterna entre la cámara del dron y una cámara de persecución.
- **Tramos:** `res://world/stages/stage_01.tscn` y `stage_02.tscn`. El nodo `StageBuilder` tiene los puntos del camino, la semilla y el botón **Regenerar**. El catálogo de etapas (nombre, descripción y qué las desbloquea) está en `res://world/stages/stage_catalog.tres`.

## Estructura

| Carpeta | Contenido |
| --- | --- |
| `godot/drone/` | Física, controlador de vuelo, modos, radio, gimbal, batería y sensor de choques |
| `godot/world/` | Generador del tramo, luz y cielo compartidos (`world/environment/`), árboles y props de rally (`world/props/`), materiales, escenas de tramos y catálogo de etapas |
| `godot/car/` | Auto, perfil de velocidad y sonido de motor |
| `godot/filming/` | Grabación y puntaje de tomas, progreso guardado |
| `godot/player/` | Jugador en primera persona, maleta e interactuables |
| `godot/game/` | Escena principal, etapa, máquina de estados de control y respuesta a los eventos (efectos y ganchos de sonido) |
| `godot/ui/` | Visor del dron y su look de cámara, HUD de la etapa, tablet y mapa, radio, guía, resumen y resultados |
| `godot/hud/` | Capa de vuelo del visor, derivada del simulador (horizonte, mira, lecturas, chip de modo y estado, sticks) |
| `godot/gui/` | Título, menú principal, etapas y carga (`gui/front/`), menús (pausa, opciones, controles y calibración, ajustes del dron, ayuda), componentes propios (botones del mando, logo, scrim) y el theme generado por código |
| `godot/vfx/` | Partículas: polvo del auto, polvo, chispas y anillo de aterrizaje |
| `godot/localization/` | Textos de los menús y el HUD en español e inglés |
| `godot/autoloads/` | `Controls`, `EventBus`, `Audio`, `GameSettings`, `QuadSettings`, `UI`, `StickNavigation`, `Progress` y `SceneTransition` |
| `godot/debug/` | Campo de pruebas, cámaras de debug, chequeos automáticos y capturas |

Estos son los valores de diseño que más conviene tocar al probar:

- **Espera hasta la largada:** `start_delay` en `game/stage.tscn`.
- **Autonomía:** `capacity_mah` en el nodo `Battery` del dron. Hoy da unos 3 minutos de vuelo estacionario.
- **Auto:** `skill`, `grip` y `top_speed` en `car/rally_car.tscn`.
- **Puntaje:** pesos y umbrales en `filming/shot_scorer.gd` y `filming/shot_report.gd`.
- **Luz y cielo:** `world/environment/rally_env.tres` y `world/environment/rally_sun.tscn`, compartidos por todas las etapas.

## Chequeos automáticos

Hay dieciocho chequeos que corren sin ventana. Usan su propia carpeta de configuración, así que tus ajustes no cambian los resultados:

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
- **Menús con mando:** foco al pausar, una sola ✕ alcanza, Confirmar alcanzable en el diálogo, sticks que solo navegan, reanudar sin colgarse, L1/R1 por sección, glifos del mando y calibración que conserva el teclado.
- **Identidad de los menús:** variaciones y contrastes del theme, `main_theme.tres` regenerado, botones del mando dibujados (✕ ○ □ △ o A B X Y), sonidos de la interfaz, y menús que ocultan el visor y desenfocan la etapa detrás de un solo scrim.
- **Flujo:** título y menú principal, catálogo de etapas, la carga por pasos genera el mismo tramo que la carga de una vez, progreso guardado y desbloqueos, la etapa 2 se puede recorrer, cargar, reiniciar y volver al menú por transición, y resultados con récord y siguiente etapa.
- **Visor:** horizonte real en la vista gimbal, altura y velocidad vertical correctas, modos tortuga y lanzamiento, avisos con prioridad (choque y toma perdida en uno solo), sin superposiciones con ningún preset ni resolución, atajos que no se rearman cada frame y vista previa de Opciones igual al visor.
- **Mundo:** la misma semilla da los mismos árboles (en el lugar de siempre) y los mismos props, nada sólido sobre el camino, arcos en la largada y la meta, sol bajo sin niebla que blanquee la lejanía, efectos conectados a todos los eventos, polvo y ruedas del auto, tapa de la maleta, choque con chispas y polvo, y pisadas en ripio o pasto.

```sh
godot --headless --path godot --import
godot --headless --path godot --fixed-fps 100 res://debug/headless_checks/check_all.tscn
```

Para correr solo algunos, agregá `-- --only=drone`. El nombre se compara por coincidencia parcial. Después de agregar un `class_name` nuevo, repetí `--import` para que Godot actualice la caché de clases.

Para ver el juego sin jugarlo, este comando guarda capturas de varias vistas de la etapa e imprime cuántas llamadas de dibujo y primitivas costó cada una. Necesita GPU:

```sh
godot --path godot res://debug/tools/screenshot_tour.tscn -- --out=C:/carpeta/de/capturas
```

El theme de los menús (`gui/theme/main_theme.tres`) y los sonidos de la interfaz (`Assets/Audio/UI/`) se generan por código a partir de `gui/theme/ui_palette.gd` y de las recetas de `debug/tools/build_ui_sounds.gd`. Después de cambiarlos, regeneralos (nunca se editan a mano):

```sh
godot --headless --path godot -s res://debug/tools/build_theme.gd
godot --headless --path godot -s res://debug/tools/build_ui_sounds.gd
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
