# Plan 02 — Visor del dron v2

Depende de: 01 (para probar el visor y el preview de Opciones con el PS4).

## 1. Contexto y diagnóstico

Mientras se pilotea, la pantalla la dibujan varias capas que no se conocen entre sí. En `game/stage.tscn`, dentro de la `CanvasLayer` `UI`: `StageHud` (la capa "a pie", que **sigue visible al pilotear**), `DroneVisor` (visible solo pilotando), `ClipSummary` (encima del visor) y `Tablet`. Dentro de `DroneVisor` (`ui/drone_visor.gd`) hay además un HUD de vuelo trasplantado del simulador (`hud/hud.tscn`: mira, horizonte, cintas laterales, brújula, lecturas, badge de modo, estado, sticks, indicador REC, tabla de RPM), el marcador del auto, tercios, borde de grabación, barras de puntaje, guía de pilotaje, REC/STBY, batería, línea de atajos y alerta.

El usuario reportó elementos superpuestos e indicadores incorrectos. Una auditoría completa (rutas relativas a `godot/`) encontró:

### Datos y lógica

- **D1, crítico: el horizonte de la vista gimbal está mal.** `_apply_view` fuerza `hud.forced_horizon_mode = "attitude"` en la vista gimbal (`ui/drone_visor.gd:133`): dibuja la inclinación **del dron** mientras la imagen del gimbal está estabilizada y apuntando −25°. En la captura `04_drone_view_car` la línea queda a unos 340 px del horizonte real. La opción "Horizonte: Real (cámara)" no tiene efecto en la vista principal. `debug/headless_checks/check_pilot_view.gd:33` fija este comportamiento.
- **D2: la velocidad vertical se calcula mal.** `(hud_position.y − _previous_altitude) / maxf(hud_timer, 1e-3)` (`hud/hud.gd:185`) divide por el intervalo configurado y no por la ventana que realmente se acumuló (`hud_delta`). A 20 fps con el HUD a 60 Hz marca el triple.
- **D3: pico falso de VS.** `_previous_altitude` (`hud.gd:58`) no se reinicia en `reset_data()` ni al volver al despegue: el primer valor después de un respawn puede marcar "▼120".
- **D4: la altura salta de referencia.** `_feed_hud` usa la distancia al suelo y, si es INF, cae en silencio a la altura mundial `pos.y` (`drone_visor.gd:173-179`).
- **D5: TORTUGA y LANZAMIENTO nunca se muestran.** `HUDStatus._on_armed` hace `match mode:` contra `FlightMode.Type.TURTLE` (un entero) cuando la señal emite el objeto `FlightMode` (`hud/hud_status.gd:57-58`).
- **D6: el aviso de choque dura cero frames.** `drone_crashed` escribe "DRON ESTRELLADO" y en el mismo frame `recording_aborted` lo pisa con "TOMA PERDIDA" (`drone_visor.gd:86,89`); a la vez `StageHud` muestra un tercer mensaje abajo.
- **D7: alertas viejas.** `_alert_time` solo decae dentro de `_process`, que no corre con el visor oculto: un choque o batería baja mientras se camina aparece al tomar el control.
- **D8:** la clave `altitude` también prende y apaga DIST y GMB (`drone_visor.gd:136-137`), pero la opción dice solo "Altura".
- **D9:** grabando desde la vista piloto, las barras, el borde y el consejo se calculan sobre la imagen del gimbal (que no se ve) y el REC pierde "VISTA PILOTO".
- **D10–D12, guía:** con batería baja y el dron en el suelo dice "aterrizá" (`ui/pilot_guide.gd:66` evalúa batería antes que altura); el panel no se oculta con texto vacío; desarmado en el aire tras un choque dice "para armar".
- **D13:** un clip de 0,7 s dice "Duración 0:00" (`HudStyle.format_time` trunca a segundos).
- **D14:** el marcador del auto está apagado en el preset por defecto y solo aparece con el auto corriendo (`autoloads/game_settings.gd:18-30`, `drone_visor.gd` `_update_car_marker`).
- **D17/D18:** VEL es la velocidad 3D (`hud.gd:182`), así que subir en vertical se ve en VEL y en VS; GMB no tiene signo.
- **Código muerto:** el promedio de ángulos y de sticks (`hud_angles`, `first_angles`, `get_adjusted_angles`, `hud.gd:44-50,110,204,236,243`) se calcula y nadie lo lee; la clave `"rec"` no existe en los ajustes y `HUDRecIndicator` solo aparece en el preview.

### Layout a 1920×1080

- **L1:** las lecturas terminan en y≈424 y el resumen de toma empieza en y≈425, anclado al centro-derecha con un desplazamiento a mano (`ui/clip_summary.gd:29-32`): un comentario de dos líneas lo hace crecer hacia arriba sobre las lecturas.
- **L2:** cuatro bloques centrados arriba con 4–12 px entre sí: estado de la etapa (y 28), radio (66–124), brújula (132–228, preset Completo), alerta (240–292).
- **L3:** `HUDStatus` ("DESARMADO", y 600–640) cae sobre la línea de horizonte con cabeceo de +5…+8°.
- **L4:** el aviso de `StageHud` (y ≈846–880) toca las cajas de sticks (y 884).
- **L5:** barras de puntaje (314 px) y guía (hasta 432 px) comparten ancla abajo-izquierda y saltan al empezar y terminar de grabar.
- **L6:** las cintas laterales (Completo) se dibujan en x 640 y 1280, sobre el sujeto.
- **L8:** el badge de modo desborda con "RECUPERACIÓN".

### Redundancias y estilo

- El armado se dice tres veces a la vez (estado bajo la mira, guía, línea de atajos); hay dos indicadores REC con dos rojos distintos; la recuperación se anuncia tres veces; altura y velocidad aparecen dos veces con unidades distintas (lecturas y cintas); hay dos widgets de stick con tamaños y estilos distintos (`hud/hud_stick_input.gd` 128 px radio 4, `ui/stick_hint.gd` 96 px radio 8).
- Tres recetas de texto (`HudStyle.make_label` mono con contorno 0,75; `HUDDraw.text` negrita/mono con sombra 0,35; `hud/hud_theme.tres` contorno opaco), 13 tamaños de fuente, cuatro estilos de panel (alfa 0,45/0,50/0,85/0,93; radio 6/8/16), cinco colores fuera de `HudStyle`, márgenes escritos a mano (20/28/40/60/66/150/200/240).

### Preview de Opciones y rendimiento

- El preview de Opciones > Juego y HUD (`gui/options_menu/hud_config.gd`) instancia solo `hud.tscn`: muestra un REC que el juego nunca dibuja, el badge "ACRO", "DESARMADO" fijo, y 4 de los 15 interruptores (guía, barras, tercios, marcador del auto) no cambian nada.
- `_update_hint()` rearma siete etiquetas por frame consultando el InputMap (`drone_visor.gd:229`); `add_theme_color_override` se llama en cada frame en REC, batería y consejo; la guía busca `Battery` con `get_node` por frame; componentes ocultos igual reciben `queue_redraw`.

## 2. Objetivo y criterio de terminado

Un visor que se lee como el de un dron de cámara profesional:

- Regiones fijas sin superposiciones a 1920×1080 con cualquier preset, grabando o no.
- **Una sola capa dueña de los mensajes**, con prioridad y sin pisarse.
- Datos correctos: horizonte real en ambas vistas, VS correcta y sin picos, altura sobre el suelo o "---", VEL horizontal, GMB con signo, TORTUGA y LANZAMIENTO visibles.
- Un solo lenguaje visual (fuente, tamaños, paneles, colores, márgenes).
- El preview de Opciones muestra el mismo visor que el juego y todos los interruptores hacen algo.

## 3. Decisiones de diseño

### Grilla

Tokens en `HudStyle`: `MARGIN = 48`, `GUTTER = 16`, `COLUMN_W = 420`. `drone_visor.gd` construye las regiones en código, cada una como un contenedor con nombre (`RegionTopLeft`, `RegionTopCenter`, …) para que los chequeos midan sus rectángulos.

| Región | Contenido |
|---|---|
| Arriba izquierda | Bloque REC (punto + `REC 0:12 / 0:30`, o `STBY`), etiqueta de vista (`GIMBAL` / `VISTA PILOTO · graba el gimbal`), chip de modo con estado (`ESTABILIZADO · ARMADO`) |
| Arriba centro | Una línea de mensajes (`VisorMessages`) y debajo la línea de radio (último anuncio o `Llega a tu punto en 0:12`) |
| Arriba derecha | Columna (`VBoxContainer`, ancho `COLUMN_W`): batería (porcentaje, tiempo, barra), lecturas (ALT, VEL, VS, DIST, GMB, RUMBO) y debajo el `ClipSummary` |
| Centro | Mira, horizonte, tercios (solo vista gimbal) |
| Abajo izquierda | Un único panel de asistencia de `COLUMN_W`: `PilotGuide` sin grabar, `ScoreBars` grabando; mismo ancho y misma ancla |
| Abajo centro | Dos `StickHint` de 96 px |
| Borde inferior | Línea de atajos |
| Mundo | Marcador del auto |

`StageHud` se oculta por completo mientras se pilotea. `RadioFeed` se separa en lógica y dibujo: la lógica sigue en la etapa, expone `last_announcement()` y `countdown_text()`, y tanto `StageHud` como el visor las dibujan.

### Qué muere, qué se reescribe, qué se conserva

- **Se borran:** `hud/hud_rpm.gd/.tscn`, `hud/hud_side_tapes.gd`, `hud/hud_compass_tape.gd` (el rumbo pasa a ser una lectura numérica), `hud/hud_rec_indicator.gd`, `hud/hud_stick_input.gd/.tscn`, `hud/hud_theme.tres`, el promedio de ángulos y sticks de `hud.gd`, la rama `"rec"` de `_component_for_key`, y las claves `rpm` y `side_tapes` de `GameSettings.HUD_BOOL_KEYS` y de los presets (con migración: se ignoran si aparecen en un `GameSettings.cfg` viejo).
- **`hud_status.gd` deja de ser un texto bajo la mira.** Su estado (DESARMADO, ARMADO, TORTUGA, LANZAMIENTO, RECUPERACIÓN) se muestra en el chip de modo; los fallos de armado van a la cola de mensajes. Se conserva la clase como objeto con `.text` y los métodos `_on_armed`, `_on_disarmed`, `_on_arm_failed`, `_on_mode_changed`, porque `check_pilot_view` los usa.
- **Se reescriben:** `hud.gd` como capa de vuelo delgada que conserva los nombres que usan los chequeos (`horizon`, `crosshair`, `readouts`, `sticks`, `mode_badge`, `status`, `latest_position`, `latest_left_stick`, `latest_right_stick`, `show_component`, `apply_hud_config`, `set_camera`); `hud_readouts.gd` como columna compacta; `hud_mode_badge.gd` como chip que se dimensiona según el texto.
- **Se conservan:** `HUDHorizon`, `HUDCrosshair`, `HUDDraw` (sus colores pasan a leerse de `HudStyle`), `WorldMarker`, `StickHint` (queda como único widget de stick; `hud.sticks` pasa a ser el contenedor de los dos), `ScoreBar`.

### Cola de mensajes

Nuevo `ui/visor_messages.gd` (`VisorMessages`, un `Control`):

```gdscript
enum Level {INFO, WARN, ALERT}
func post(text: String, level := Level.INFO, seconds := 2.5, key := &"") -> void
func clear(key := &"") -> void
func current_text() -> String
```

- Muestra un mensaje a la vez. Gana el de mayor nivel; a igual nivel, el más reciente. Un `post` con una `key` existente reemplaza al anterior. Guarda como máximo tres pendientes.
- INFO en blanco, WARN en ámbar, ALERT en rojo, más grande y con parpadeo suave.
- El tiempo de cada mensaje solo corre mientras el visor está visible.
- Choque y toma perdida se funden: `drone_crashed` publica `"DRON ESTRELLADO"` con key `crash`; si en el mismo frame llega `recording_aborted`, reemplaza con `"DRON ESTRELLADO · TOMA PERDIDA"`.
- `Stage` gana `notify(text: String, level := VisorMessages.Level.INFO)`: pilotando va al visor, caminando va al aviso de `StageHud`. Todas las conexiones directas de `EventBus` a `show_alert` y los `hud.show_notice` de `Stage` pasan por `notify`.

### Horizonte (D1)

`hud.set_camera()` recibe siempre la cámara activa (gimbal o piloto) y `forced_horizon_mode` se elimina. En la vista gimbal el horizonte usa el modo "camera" con la cámara del gimbal: la línea coincide con el horizonte real y se mueve con el gimbal. La opción "Horizonte" de Opciones afecta solo a la vista piloto y su texto lo dice ("Horizonte en vista piloto").

### Números

- VS: `(alt − prev) / ventana_real`, donde la ventana es el `hud_delta` acumulado; `_previous_altitude` se reinicia en `reset_data()` y al recibir `drone.respawned` y `drone.deployed` (D2, D3).
- ALT: distancia al suelo; si es INF se muestra `---` y la VS se congela en `---` (D4).
- VEL: velocidad horizontal (D17). GMB: con signo y flecha ▲/▼ como la VS (D18). RUMBO: grados 0–359 desde la cámara activa.
- `_on_armed` compara con `mode is FlightModeTurtle` y `mode is FlightModeLaunch` (D5).
- `HudStyle.format_time` muestra décimas por debajo de 60 s (`12,4 s`); el resto de los usos de minutos:segundos sigue igual (D13).
- Claves nuevas en `GameSettings.HUD_BOOL_KEYS`: `distance`, `gimbal`, `heading` (esta última pasa a significar la lectura RUMBO); `altitude` controla solo ALT y VS (D8). `car_marker` pasa a estar encendido en Piloto y Completo, y el marcador se ve con el auto en el camino aunque todavía no haya largado (etiqueta "Auto 7 · largada") (D14).
- Grabando en vista piloto: la etiqueta de vista sigue diciendo `VISTA PILOTO · graba el gimbal`, las barras llevan el título "Puntaje (gimbal)" y los tercios se ocultan (D9).
- Guía: primero se evalúa si el dron está en el suelo (con batería baja en tierra: "Guardá el dron y cambiá la batería"), el panel se oculta si el texto queda vacío, y desarmado en el aire o volcado dice "Dron caído: {respawn} para volver al despegue" (D10–D12).

### Estilo

`HudStyle` v2 es la única receta del visor: una fuente para rótulos (`UIPalette.FONT_BOLD`) y una para valores (`UIPalette.FONT_MONO`), un solo tratamiento de legibilidad (contorno 0,6 de alfa, tamaño/6), cinco tamaños (`SIZE_XS = 14`, `SIZE_S = 18`, `SIZE_M = 22`, `SIZE_L = 28`, `SIZE_XL = 44`), un panel (`panel()`: fondo negro 0,55, radio 8, margen 12), colores `WHITE`, `DIM`, `AMBER`, `GREEN`, y `REC` y `ACCENT` leídos de `UIPalette.HUD_REC` y `UIPalette.ACCENT`. `HUDDraw.text` usa los mismos colores y el mismo contorno. Todo panel del visor, la guía, las barras, el resumen, la checklist de `StageHud` y la tablet usan `HudStyle.panel()`.

### Rendimiento

- La línea de atajos se reconstruye solo con `Controls.input_device_changed`, con el cambio de vista, al armar/desarmar y al cerrar el menú de Controles; un contador `hint_rebuilds` lo expone para el chequeo.
- Los `add_theme_color_override` se hacen solo cuando el color cambia; los nodos (`Battery`, `Gimbal`, `PilotCamera`) se cachean en `setup()`; los componentes ocultos no reciben datos ni `queue_redraw`.

### Preview de Opciones

`gui/options_menu/hud_config.tscn` instancia `DroneVisor` con `preview_mode = true`: datos falsos (el `_update_preview` actual de `HUD` más REC y batería simulados, modo ESTABILIZADO · ARMADO) y el mismo layout. Así los 15 interruptores cambian lo que se ve.

## 4. Archivos

**Crear:** `ui/visor_messages.gd`, `debug/headless_checks/check_visor.gd`.

**Modificar:** `ui/drone_visor.gd`, `ui/hud_style.gd`, `hud/hud.gd`, `hud/hud.tscn`, `hud/hud_readouts.gd`, `hud/hud_mode_badge.gd`, `hud/hud_status.gd`, `hud/hud_draw.gd`, `hud/hud_horizon.gd` (sin el modo forzado), `ui/pilot_guide.gd`, `ui/score_bars.gd`, `ui/clip_summary.gd`, `ui/stage_hud.gd`, `ui/radio_feed.gd`, `ui/tablet.gd` (panel común), `game/stage.gd` (`notify`, ocultar `StageHud` al pilotear), `autoloads/game_settings.gd`, `gui/options_menu/hud_config.gd/.tscn`, `localization/translations.csv` (textos de las claves nuevas y de la opción de horizonte), `debug/headless_checks/check_pilot_view.gd`, `check_scoring_ui.gd`, `check_all.gd`, `debug/tools/screenshot_tour.gd`.

**Borrar:** `hud/hud_rpm.gd`, `hud/hud_rpm.tscn`, `hud/hud_side_tapes.gd`, `hud/hud_compass_tape.gd`, `hud/hud_rec_indicator.gd`, `hud/hud_stick_input.gd`, `hud/hud_stick_input.tscn`, `hud/hud_theme.tres` (con sus `.uid`).

**Reutilizar:** `HUDDraw.project_direction` (ya funciona con cualquier `Camera3D`), `HudStyle.anchor`, `ShotAdvice`, `StickHint`, `ScoreBar`, `WorldMarker`, señales de `EventBus` y de `FlightController`.

## 5. Pasos

1. **`HudStyle` v2.** Tokens, `panel()`, tamaños, colores leídos de `UIPalette`; `HUDDraw` delega sus colores. Pasar todos los paneles existentes a `HudStyle.panel()`. Correr los chequeos.
2. **`VisorMessages` y `Stage.notify`.** Reemplazar `show_alert` y las conexiones directas. Aserciones de la cola en `check_visor`.
3. **HUD delgado.** Borrar los componentes muertos, reescribir `hud.gd` conservando la API usada por los chequeos, `hud_status` sin Label visible. Actualizar `check_pilot_view`: la aserción de preset Completo pasa de `rpm_table.visible` a "`readouts` muestra RUMBO y el marcador del auto está encendido".
4. **Grilla del visor.** Construir las regiones con nombre; mover REC, vista, chip, batería y lecturas; `StageHud` oculto al pilotear; radio dibujada por el visor.
5. **Horizonte y números.** Modo "camera" con la cámara activa; `check_pilot_view.gd:33` pasa a afirmar `hud.horizon.mode == "camera"` y `hud.horizon.camera == gimbal.camera`. VS, ALT, VEL, GMB, RUMBO, TORTUGA/LANZAMIENTO.
6. **Chip de modo y guía.** Estado dentro del chip; fallos de armado a la cola; guía con el orden corregido y oculta cuando no tiene texto.
7. **Panel de asistencia único y resumen de toma en la columna derecha.** Mismo ancho para guía y barras; `ClipSummary` como hijo de la columna derecha (sin desplazamientos a mano); `format_time` con décimas.
8. **Claves y presets.** `distance`, `gimbal`, `heading`, `car_marker` por defecto; marcador del auto antes de la largada; migración de claves viejas; textos en Opciones.
9. **Preview real en Opciones.** `DroneVisor` en `preview_mode` dentro de `hud_config.tscn`.
10. **Rendimiento.** Atajos por señal con contador, colores solo al cambiar, nodos cacheados.
11. **Tour y pruebas manuales.**

## 6. Verificación

**Deben seguir en verde:** los chequeos existentes, con `check_pilot_view` actualizado según los pasos 3 y 5 (se reemplazan aserciones que describían el comportamiento incorrecto por las del comportamiento correcto, sin quitar cobertura) y `check_scoring_ui` (guía y resumen).

**Chequeo nuevo `check_visor.gd`:**
- La cámara del horizonte es la cámara activa en la vista gimbal y en la vista piloto.
- VS: dos `update_data` separados 0,1 s con +1 m de altura dan 10 m/s (±0,5), no 30; después de `drone.reset_to()` la VS es 0.
- ALT: con distancia al suelo INF, la lectura muestra `---`.
- `hud.status._on_armed(<FlightModeTurtle>)` deja un texto que contiene "TORTUGA".
- Cola: un ALERT gana a un INFO publicado después; dos `post` con la misma key dejan uno; choque + toma perdida en el mismo frame dejan "DRON ESTRELLADO · TOMA PERDIDA"; con el visor oculto el tiempo no corre.
- **Sin solapes:** para cada preset (Cine, Piloto, Completo), grabando y sin grabar, los rectángulos globales de las regiones visibles no se intersecan a 1920×1080 (el `ClipSummary` visible incluido).
- `hint_rebuilds` no aumenta durante 100 frames sin cambios de dispositivo, vista ni armado.
- En preview de Opciones, apagar `pilot_guide` oculta la guía del visor de preview.

**Tour de capturas:** rehacer `04_drone_view_car`, `04b_pilot_view`, `04c_clip_summary`, `10_options_hud`; nuevas `04d_visor_full` (preset Completo grabando) y `04e_visor_alert` (choque con toma perdida). Revisar cada captura buscando superposiciones.

**Pruebas manuales con el PS4:**
1. Presets Cine, Piloto y Completo, con y sin grabar, en ambas vistas.
2. El horizonte coincide con el horizonte real al subir y bajar el gimbal con L2/R2.
3. Chocar el dron grabando: un solo mensaje "DRON ESTRELLADO · TOMA PERDIDA".
4. Dejar bajar la batería: aviso ámbar, luego rojo; la guía dice qué hacer en tierra y en el aire.
5. Cambiar de vista mientras se graba.
6. Volver al despegue con Share: la VS no salta.
7. Opciones > Juego y HUD: cada interruptor cambia el preview.

## 7. Riesgos y qué no tocar

- **No tocar** `filming/shot_scorer.gd`, `filming/recorder.gd` (salvo lo que ya expone), `drone/gimbal.gd` ni el controlador de vuelo.
- `Stage` debe seguir funcionando instanciado solo (lo hacen los chequeos y el tour).
- Los chequeos acceden a `stage.visor.hud.horizon`, `.readouts`, `.status`, `.sticks`, `.latest_*`: mantener esos nombres.
- `show_component` mantiene la semántica de las claves que sobreviven.
- `UIPalette` es del plan 03: aquí solo se leen sus constantes existentes, no se agregan ni renombran.
- El preview de Opciones usa `DroneVisor` sin dron: `setup()` debe aceptar la ausencia de dron en `preview_mode` sin errores.
