# Plan 01 — Gamepad en menús

Depende de: nada. Es el primero porque desbloquea probar todo lo demás con el PS4.

## 1. Contexto y diagnóstico

El usuario juega con un mando PS4. En los menús (pausa, opciones, controles, ajustes del dron, ayuda, diálogo de confirmación, resultados) reportó que "no se pueden seleccionar bien algunas opciones, por ejemplo confirmar". La investigación encontró diez causas; la primera explica casi todo lo que se siente mal.

Rutas relativas a `godot/`.

1. **Al pausar, el menú se abre sin foco.** `Stage.open_pause_menu()` y `Stage.show_results()` ponen `Input.mouse_mode = Input.MOUSE_MODE_VISIBLE` (`game/stage.gd:118` y `:133`); `PauseMenu.set_menu_visibility` hace lo mismo (`gui/pause_menu.gd:62`). Al descapturar el cursor, Windows emite un `InputEventMouseMotion` con un `relative` grande. `UI._input` lo toma como uso del mouse (`autoloads/ui.gd:164-167`), `set_input_kind(MOUSE)` **suelta el foco** (`ui.gd:152-155`) y `MenuScreen.grab_initial_focus` se niega a retomarlo mientras `UI.is_using_mouse()` (`gui/menu_screen.gd:123-127`). Resultado: la pausa y los resultados quedan sin nada enfocado aunque el jugador tenga el mando en la mano.
2. **La primera ✕ se pierde.** Con el foco fuera del contexto activo, `UI._input` usa la primera acción de navegación para "mostrar dónde está el foco" y la marca como manejada (`ui.gd:191-198`, `set_input_as_handled` en `:197`); el release se descarta antes (`ui.gd:178`). Cada confirmación necesita dos ✕, y si el mouse se mueve entre medio, siempre dos.
3. **En el diálogo de confirmación "Confirmar" es inalcanzable con el stick.** `ConfirmOverlay` apila `[Cancelar] [Confirmar]` en horizontal, enfoca Cancelar (`gui/components/confirm_overlay.gd:109-117`) y apunta `focus_neighbor_top/bottom` de cada botón **a sí mismo** (`:90-91`). No tiene handler propio de `ui_accept` (solo `ui_cancel` y `pause_menu`, `:120-130`). En el esquema de navegación por defecto, `BETAFLIGHT`, el stick derecho hacia la derecha no mueve el foco: dispara `ui_accept` (`autoloads/stick_navigation.gd:93-104`), así que el gesto de "aceptar" **pulsa Cancelar**. Este es el fallo que reportó el usuario.
4. **Mover un stick nunca cuenta como "gamepad".** Solo `InputEventJoypadButton` pasa a `InputKind.GAMEPAD` (`ui.gd:175-176`). Sin eso no hay anillo de foco ni sonido de hover, y el pie de página muestra teclas de teclado.
5. **`project.godot` no define ningún `ui_*`.** Rigen los valores por defecto de Godot, que ligan `ui_left/right/up/down` al D-pad **y a los ejes 0 y 1** (stick izquierdo). En este juego esos ejes son `yaw` y `throttle` (`project.godot` sección `[input]`), y `StickNavigation` además sintetiza `ui_*` desde pitch/roll/yaw. Son dos sistemas analógicos que no se conocen: el nativo no tiene repetición controlada, así que salta de a dos opciones, invierte `CheckButton` con el temblor del stick (`ui.gd:218-223`) y en el esquema `YAW_SELECT` una sola empujada dispara `ui_right` nativo y `ui_accept` a la vez.
6. **Controles se come los botones del mando.** Con la lista de mandos abierta (`auto_detect_controller`, `gui/options_menu/controls_menu/controls_menu.gd:111-118,213`) o con el popup de asignación escuchando (`:124-133`), `ControlsMenu._input` marca como manejado todo evento de pad. El popup de asignación solo cancela con Esc de teclado (`binding_popup.gd:160-172`).
7. **Los controles de valor atrapan la navegación horizontal.** `UI._input` usa izquierda/derecha para cambiar `OptionButton` y `CheckButton` (`ui.gd:204-223`) y los `HSlider` hacen lo propio. En Controles (tres columnas), Ajustes del dron (dos columnas con scroll) y Audio (todo sliders) no hay forma de pasar de columna con el pad. Además, las pestañas de un `TabContainer` no son enfocables (el `TabBar` es un hijo interno): en Opciones > Juego y HUD la pestaña HUD solo se abre con mouse.
8. **Reanudar puede colgarse.** `PauseMenu.unpause_game()` libera el menú y recién después `Stage._on_pause_resumed` espera a que se suelten botones y sticks (`game/stage.gd:144-159`). `StickNavigation.any_axis_deflected()` usa un umbral fijo de 0,4 sin la zona muerta del usuario (`stick_navigation.gd:115-118`) y no hay timeout: un stick con deriva deja el juego pausado sin menú y sin salida.
9. **El pie de página enseña botones equivocados.** `ControlHints._rebuild` escribe "A" y "B" literales para gamepad y cae a "Enter / Esc" en cualquier otro caso (`gui/components/control_hints.gd:84-99`). Nunca usa `InputHints.joy_button_name()` ni `Controls.is_playstation_pad()`, que ya existen (`ui/input_hints.gd`, `autoloads/controls.gd`).
10. **La calibración rompe el teclado.** `CalibrationMenu._on_calibration_done` usa `InputMap.action_erase_events` sobre pitch/roll/yaw/throttle (`calibration_menu.gd:180-190`), lo que borra también W/S/A/D y las flechas, y deja asignar el mismo eje a dos controles.

Por qué los chequeos no lo vieron: `debug/headless_checks/check_gui.gd:32` fuerza `UI.set_input_kind(UI.InputKind.KEYBOARD)` antes de probar la pausa. Ningún script de juego bloquea la GUI en pausa: todos leen con `_unhandled_input` y `PROCESS_MODE_INHERIT`.

## 2. Objetivo y criterio de terminado

Solo con el PS4, sin tocar teclado ni mouse:

- Abrir la pausa con Options y ver el foco en "Continuar" desde el primer frame.
- Navegar con cruceta, stick izquierdo o stick derecho, de a una opción por empujada, con repetición al mantener.
- Aceptar con **una sola** ✕ y volver con ○.
- En "Reiniciar etapa" y "Salir", llegar a **Confirmar** con cualquier dirección y confirmarlo.
- Reanudar aunque un stick tenga deriva, en menos de medio segundo.
- Recorrer Controles (las tres columnas), Audio, Ajustes del dron (las dos columnas) y la pestaña HUD de Juego y HUD.
- Asignar un botón en Controles y cancelar la asignación con el mando.
- Ver ✕ ○ y la cruceta en el pie de página de cada menú (A B con un mando Xbox).
- Teclado y mouse siguen funcionando igual que hoy.

## 3. Decisiones de diseño

1. **`ui_*` explícitos en `project.godot`, sin ejes.** Declarar `ui_accept` (Enter, Espacio, KP Enter, botón 0), `ui_cancel` (Esc, botón 1), `ui_up`/`ui_down`/`ui_left`/`ui_right` (flechas + D-pad 11–14), `ui_focus_next`/`ui_focus_prev` (Tab / Shift+Tab + R1 / L1, botones 10 y 9). Ningún `InputEventJoypadMotion` en acciones `ui_*`: `StickNavigation` queda como la única fuente analógica de navegación. L1/R1 no chocan con armar y grabar porque en los menús el juego está en pausa y esos lectores son `_unhandled_input` con `PROCESS_MODE_INHERIT`. La sección `[input]` se edita a mano de ahora en más (el generador que se usó en la iteración 2 queda obsoleto). `InputMap.load_from_project_settings()` (chequeos, tour, `Controls.reset_controller_bindings()`) recupera estas acciones sin cambios.
2. **Esquema de navegación `GAMEPAD`, por defecto.** Nuevo valor en `StickNavigation.Scheme`: pitch → `ui_up`/`ui_down`, roll y yaw → `ui_left`/`ui_right`, **nunca** aceptar ni cancelar con un stick. Usa la repetición que ya existe (`THRESHOLD`, `RELEASE`, `INITIAL_DELAY`, `REPEAT`). `BETAFLIGHT` y `YAW_SELECT` quedan para radios sin botones. Para no heredar el `0` guardado por instalaciones anteriores, la clave de `GameSettings.game_config` cambia de `nav_scheme` a `stick_nav` con valor por defecto `GAMEPAD`. La opción de Opciones > Juego pasa a tener tres valores con textos nuevos (`GAME_STICK_NAVIGATION_GAMEPAD`, …) y un texto de ayuda que explica cuándo usar cada uno.
3. **Detección del dispositivo en `UI`.** Botón de pad → `GAMEPAD`. Eje de pad con |valor| > 0,5 → `GAMEPAD`, salvo que ya esté en `STICKS`. `StickNavigation._fire` → `STICKS` (como hoy). El mouse solo pasa a `MOUSE` si está visible, `relative.length() > 9` **y** pasaron más de 400 ms desde la última llamada a `UI.show_mouse()`. `UI.show_mouse()` es un helper nuevo que pone el mouse visible y guarda el instante; reemplaza a `Input.mouse_mode = MOUSE_MODE_VISIBLE` en `Stage.open_pause_menu`, `Stage.show_results` y `PauseMenu.set_menu_visibility`. Así el salto del cursor al descapturar ya no cuenta como mouse. Además `MenuScreen.grab_initial_focus` toma el foco si `Controls.using_gamepad`, aunque `input_kind` sea `MOUSE`.
4. **`ui_accept` no se pierde.** En `UI._input`, si llega una acción de navegación sin foco dentro del contexto activo: se enfoca con `grab_initial_focus(true)`; las direcciones se consumen como hoy, pero `ui_accept` **se reenvía** con `Input.parse_input_event` en el frame siguiente (una sola vez, con una bandera para no entrar en bucle), de modo que la primera ✕ actúa sobre el control recién enfocado. Si en el reenvío tampoco hay foco, se descarta.
5. **Diálogo de confirmación navegable.** `focus_neighbor_top` y `focus_neighbor_bottom` de cada botón apuntan al otro. El foco inicial sigue en Cancelar (la opción segura), pero Confirmar queda a un toque en cualquier dirección. El overlay maneja `ui_accept` en su `_input`: si el foco no está en uno de sus botones, enfoca Cancelar y consume; si está, deja pasar para que el `Button` lo procese. Debajo de los botones, una fila de ayuda "✕ Aceptar · ○ Cancelar" con los glifos del dispositivo (plan 03 la reemplaza por `KeyCap`).
6. **L1/R1 cambian de sección.** `MenuScreen` agrega `focus_groups()`: los hijos marcados con la meta `focus_group` (en orden de árbol) o, si la pantalla tiene un `TabContainer` con la meta `section_tabs`, sus pestañas. `ui_focus_next`/`ui_focus_prev` enfocan el primer control enfocable del grupo siguiente/anterior (con ciclo) o cambian `current_tab` y enfocan el primer control de la nueva pestaña. Se marcan: las tres columnas de Controles, las dos columnas de Ajustes del dron, el `TabContainer` de Juego y HUD, y en Audio la columna de sliders y la fila de botones. El pie de página agrega "L1/R1 Sección" en esas pantallas.
7. **Reanudar con timeout y zona muerta.** `Stage._on_pause_resumed` espera como máximo 0,5 s a que se suelten `ui_accept`, `ui_cancel`, `pause_menu` y los sticks; pasado ese tiempo despausa igual. `StickNavigation.any_axis_deflected()` usa `maxf(RELEASE, GameSettings.get_stick_deadzone() + 0.15)` como umbral.
8. **Controles no se come el mando.** `ControlsMenu._input` intercepta eventos de pad solo mientras `auto_detect_controller` está activo por un clic de mouse (no por abrir la lista con ✕) o mientras el popup está escuchando. En `BindingPopup` escuchando, Options (`pause_menu`) siempre cancela; cualquier otro botón es candidato. Tras capturar, el popup muestra Confirmar y Cancelar navegables con el mismo grafo de foco que el diálogo de confirmación.
9. **Pie de página con los glifos correctos.** `ControlHints` arma los chips de aceptar/volver con `InputHints.joy_button_name(JOY_BUTTON_A)` y `(JOY_BUTTON_B)` (✕/○ en PlayStation, A/B en Xbox) y la cruceta con `UI_KEY_DPAD`. Si `input_kind` es `MOUSE` pero `Controls.using_gamepad` es verdadero, muestra los del mando. En `STICKS` con el esquema `GAMEPAD`, muestra "Stick: navegar" + ✕/○.
10. **Calibración sin efectos colaterales.** `CalibrationMenu._on_calibration_done` usa `Controls.erase_joypad_events(action)` en lugar de `InputMap.action_erase_events`, y durante la calibración un eje ya asignado no se acepta para otro control (mensaje "Ese eje ya está asignado a …").

## 4. Archivos

**Modificar**
- `project.godot` — acciones `ui_*` (decisión 1).
- `autoloads/ui.gd` — reglas de `InputKind`, `show_mouse()`, reenvío de `ui_accept`.
- `autoloads/stick_navigation.gd` — esquema `GAMEPAD`, umbral de `any_axis_deflected`.
- `autoloads/game_settings.gd` — clave `stick_nav`, default `GAMEPAD`, getters/setters.
- `gui/menu_screen.gd` — foco con mando, grupos de L1/R1.
- `gui/components/confirm_overlay.gd` — grafo de foco, `ui_accept`, fila de ayuda.
- `gui/components/control_hints.gd` — glifos y chip de sección.
- `gui/pause_menu.gd` — `UI.show_mouse()`.
- `gui/options_menu/game_settings_menu.gd/.tscn` — opción de navegación con tres valores; meta `section_tabs`.
- `gui/options_menu/audio_menu.tscn`, `gui/quad_settings_menu.tscn`, `gui/options_menu/controls_menu/controls_menu.tscn` — metas `focus_group`.
- `gui/options_menu/controls_menu/controls_menu.gd`, `binding_popup.gd`, `calibration_menu.gd`.
- `game/stage.gd` — `UI.show_mouse()`, timeout al reanudar.
- `localization/translations.csv` — `GAME_STICK_NAVIGATION_GAMEPAD`, texto de ayuda de la opción, `UI_HINT_SECTION`, `CAL_AXIS_TAKEN`, y actualizar `HELP_MENU_NAVIGATION`.
- `debug/headless_checks/check_all.gd` — registrar el chequeo nuevo.

**Crear**
- `debug/headless_checks/check_gamepad_nav.gd`.

**Reutilizar**
- `InputHints.joy_button_name()`, `Controls.is_playstation_pad()`, `Controls.using_gamepad`, `Controls.erase_joypad_events()`.
- `HeadlessCheck.action()`, `focus_name()`, `find_child_with_script()`.
- `StickNavigation.assume_joypad` para simular un mando en headless.

## 5. Pasos

1. **Acciones `ui_*` explícitas.** Editar `project.godot`. Crear `check_gamepad_nav.gd` con la primera aserción: ninguna acción `ui_*` tiene `InputEventJoypadMotion`. Correr los 13 chequeos.
2. **Esquema `GAMEPAD`.** Enum, `action_for`, clave `stick_nav` en `GameSettings` y la opción en Juego. Aserción: con `GAMEPAD`, empujar roll a la derecha produce `ui_right` y nunca `ui_accept`.
3. **Detección del dispositivo.** `UI.show_mouse()`, ventana de 400 ms, eje de pad → `GAMEPAD`, `grab_initial_focus` con mando. Reemplazar los `mouse_mode = VISIBLE` de `Stage` y `PauseMenu`. Aserción: pausa + `UI.show_mouse()` + un `InputEventMouseMotion` de 800 px → el foco sigue en `ButtonResume`.
4. **Diálogo de confirmación.** Grafo de foco, `ui_accept` propio, fila de ayuda. Aserciones: D-pad derecha mueve a Confirmar y una sola pulsación del botón 0 devuelve `true`; lo mismo con el stick derecho en esquema `GAMEPAD`.
5. **Reenvío de `ui_accept`.** Aserción: con el foco soltado a propósito, un solo botón 0 sobre la pausa abre la opción enfocada (contar pulsaciones con una señal).
6. **Reanudar.** Timeout y umbral con zona muerta. Aserción: con un eje simulado a 0,5 permanente (`Input.action_press(&"roll_right", 0.5)`), la reanudación termina en menos de 0,6 s.
7. **Grupos L1/R1.** `MenuScreen.focus_groups()` y las metas en las pantallas. Aserciones: en Juego y HUD, R1 cambia `current_tab`; en Controles, R1 lleva el foco de la columna izquierda a la de asignaciones.
8. **Controles y popup de asignación.** Aserción: en Controles, D-pad abajo mueve el foco sin abrir el popup; con el popup escuchando, `pause_menu` lo cancela.
9. **Pie de página.** Aserción: con `input_kind = GAMEPAD` y un mando PlayStation simulado, los chips contienen "✕" y "○"; con Xbox, "A" y "B". (Para simular el tipo de mando, agregar a `Controls` una variable de prueba `force_playstation: int = -1` que `is_playstation_pad()` respeta si es 0 o 1.)
10. **Calibración.** `erase_joypad_events` y rechazo de ejes repetidos. Aserción: tras simular una calibración, `throttle_up` conserva su evento de tecla W.
11. **Ayuda y pruebas manuales.** Actualizar `HELP_MENU_NAVIGATION` (L1/R1, esquemas). Hacer la lista manual de abajo.

## 6. Verificación

**Deben seguir en verde:** los 13 chequeos, en especial `check_gui`, `check_input` y `check_settings`. `check_gui.gd:32` sigue forzando `KEYBOARD`: el chequeo nuevo cubre el mando.

**Chequeo nuevo `check_gamepad_nav.gd`** (con `StickNavigation.assume_joypad = true`, inyectando `InputEventJoypadButton` y `InputEventJoypadMotion` con `Input.parse_input_event`, y restaurando el esquema y `assume_joypad` al final):
- Ninguna acción `ui_*` tiene eventos de eje.
- Esquema `GAMEPAD`: el roll produce `ui_left`/`ui_right`, nunca `ui_accept`/`ui_cancel`.
- Pausa + `UI.show_mouse()` + `MouseMotion` de 800 px → foco en `ButtonResume` e `input_kind` distinto de `MOUSE`.
- Una sola pulsación del botón 0 sobre "Opciones" abre Opciones.
- Diálogo de confirmación: D-pad derecha + botón 0 → `true`; D-pad abajo también llega a Confirmar; el stick derecho con esquema `GAMEPAD` llega a Confirmar.
- Reanudación con eje deflectado termina en menos de 0,6 s.
- En Controles, D-pad abajo mueve el foco y no hay popup abierto; R1 cambia de columna.
- En Juego y HUD, R1 cambia `current_tab`.
- Pie de página: glifos PlayStation y Xbox según el mando simulado.
- Tras calibrar, los eventos de teclado de pitch/roll/yaw/throttle siguen presentes.

**Tour de capturas:** en `08_pause_menu`, llamar `UI.set_input_kind(UI.InputKind.GAMEPAD)` antes de capturar para ver el foco y los glifos. Nueva `08b_confirm_overlay` con el diálogo de "Reiniciar etapa" abierto y el foco en Confirmar.

**Pruebas manuales con el PS4:**
1. Options pausa con el foco en Continuar; ✕ continúa sin mover el dron ni cambiar el modo.
2. Reiniciar etapa → Confirmar con la cruceta, con el stick izquierdo y con el stick derecho.
3. Salir → Cancelar con ○.
4. Opciones > Audio: mover sliders con izquierda/derecha y pasar a "Volver" con R1.
5. Opciones > Controles: recorrer las tres columnas con L1/R1, asignar "Grabar" a otro botón, cancelar una asignación con Options.
6. Opciones > Juego y HUD: pasar a la pestaña HUD con R1 y cambiar un preset.
7. Ajustes del dron: pasar de la columna del dron a la de rates con R1.
8. Calibrar los ejes y después volar con teclado para comprobar que W/S/A/D y las flechas siguen funcionando.
9. Con el stick apenas tocado al reanudar, el juego vuelve igual.

## 7. Riesgos y qué no tocar

- **No tocar** `drone/radio_controller.gd` ni el mapeo de juego (A = modo, L1 = armar, R1 = grabar, etc.): la pausa ya los aísla.
- `UI.set_input_kind(MOUSE)` debe seguir soltando el foco cuando el mouse se usa de verdad: es lo que evita el anillo de foco al usar el mouse.
- El reenvío de `ui_accept` puede provocar doble acción si el control recién enfocado ya procesó el evento original; la bandera de "reenviado una vez" y el chequeo de pulsaciones lo cubren.
- `L1/R1` como `ui_focus_next/prev` afectan a cualquier `Control` enfocable fuera de `MenuScreen` (por ejemplo `LineEdit` de los `SpinBox`); ya están con `FOCUS_CLICK` en Ajustes del dron (`quad_settings_menu.gd:132-135`), mantenerlo.
- Si una radio real se configura con el esquema `GAMEPAD`, sus sticks solo navegan; la ayuda de la opción lo explica.
