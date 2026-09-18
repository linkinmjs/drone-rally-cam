# Plan 03 — Identidad visual y sistema de UI propio

Depende de: 01 (glifos y navegación con el mando). Va después de 02 para no rehacer el visor: este plan no toca `hud/` ni `ui/drone_visor*`.

## 1. Contexto y diagnóstico

Los menús del juego son los del simulador de drones, copiados con sus rutas: mismo theme, misma paleta, mismos sonidos, mismo layout. El usuario lo nota ("es exactamente la misma que en el otro juego") y quiere una UI propia de Drone Rally Cam.

Lo que hay hoy (rutas relativas a `godot/`):

- **Paleta clara "minimal"** en `gui/theme/ui_palette.gd`: fondo `#F5F6F8`, superficie blanca, texto `#1B1F24`, acento azul `#2F7CF6`, `SCRIM = Color(0.961, 0.965, 0.973, 0.86)`. Es una paleta de aplicación de escritorio, no de juego.
- **El theme se genera por código** en `gui/theme/theme_builder.gd` (591 líneas): styleboxes, colores por estado y **iconos rasterizados proceduralmente** (`_ring_icon`, `_switch_icon`, `_checkbox_icon`, `_chevron_icon`, `_updown_icon`, `_tick_icon`, `_dot_icon`, `bar_texture`). Variaciones existentes: `DisplayLabel`, `TitleLabel`, `HeadingLabel`, `SubtitleLabel`, `CaptionLabel`, `SectionLabel`, `HintLabel`, `ValueLabel`, `KeyCap`, `MenuItemButton`, `PrimaryButton`, `DangerButton`, `GhostButton`, `Card`, `InsetPanel`, `Chip`, `ClearPanel`, `HudPreviewPanel`, `OverlayScrim`, `RowPanel`, `BodyText`. Se regenera con `godot --headless --path godot -s res://debug/tools/build_theme.gd` → `gui/theme/main_theme.tres`. Este sistema es bueno y se conserva: lo que cambia son los valores y los componentes.
- **Menús ilegibles sobre la etapa.** El scrim claro sobre un cielo claro deja la pausa y los resultados como papel blanco con poco contraste (capturas `08_pause_menu`, `13_results`), y el HUD sigue dibujado detrás: `Stage.open_pause_menu()` y `Stage.show_results()` (`game/stage.gd:110,122`) no ocultan la `CanvasLayer` `UI`.
- **Fuentes:** Recursive Sans (`gui/RecursiveSansLnrSt-Med.otf`, `-Bold.otf`) y Recursive Mono (`hud/RecursiveMonoLnrSt-Regular.otf`). Se mantienen: tienen buen rango de pesos y no hay que comprar nada.
- **Sin logo.** `icon.svg` es el robot de Godot; `export_presets.cfg` no tiene icono.
- **Glifos del mando dispersos.** `ui/input_hints.gd` tiene tablas Xbox y PlayStation y `Controls.is_playstation_pad()`; `gui/components/control_hints.gd` no las usa (el plan 01 lo corrige a nivel de texto; este plan lo convierte en un componente visual).
- **Sonidos de UI del simulador:** `Assets/Audio/UI/{hover,click,back,tick,error}.wav`, referenciados en `UI.SOUNDS` (`autoloads/ui.gd:13-19`). `UI` los conecta solo a todos los botones, rangos y pestañas.
- **Pantallas a rediseñar:** `gui/pause_menu.*`, `gui/options_menu/options_menu.*`, `audio_menu.*`, `game_settings_menu.*` + `hud_config.*`, `controls_menu/**`, `gui/quad_settings_menu.*` + `gui/rate_graph.gd`, `gui/help_page.*`, `gui/components/confirm_overlay.gd`, `ui/results_screen.*` (el layout de resultados con progreso es del plan 04; aquí solo el estilo).

## 2. Objetivo y criterio de terminado

- Ninguna pantalla se parece al simulador: paleta, tipografía, logo, glifos, sonidos y componentes propios.
- Pausa, Opciones (hub, Audio, Controles, Juego y HUD), Ajustes del dron y Ayuda rediseñados con la identidad nueva y navegables con el PS4.
- Todo menú sobre la etapa es legible con cielo de mediodía y el HUD no se ve detrás.
- El juego tiene logo (wordmark) e icono propios.
- El theme se sigue generando por código y un chequeo lo protege.

## 3. Decisiones de diseño

### Paleta "Rally al atardecer" (`UIPalette` v2)

Se cambian valores, **no nombres**: `HudStyle` (plan 02) lee `FONT_REGULAR`, `FONT_BOLD`, `FONT_MONO`, `HUD_REC`, `ACCENT` y `SUCCESS`.

| Token | Valor | Uso |
|---|---|---|
| `BG` | `#14161A` | Fondo de pantallas completas |
| `BG_TOP` / `BG_BOTTOM` | `#1B1E23` / `#101216` | Degradado de fondo |
| `SURFACE` | `#1E2126` | Tarjetas, paneles |
| `SURFACE_ALT` | `#262A31` | Filas, hover |
| `SURFACE_PRESSED` | `#2E333B` | Presionado |
| `BORDER` / `BORDER_STRONG` | `#2E333B` / `#3A4049` | Bordes |
| `TEXT` | `#F2EFE9` | Texto principal (crema) |
| `TEXT_2` | `#A7A39B` | Texto secundario |
| `TEXT_DISABLED` | `#5F5C57` | Deshabilitado |
| `ACCENT` | `#FF6A2B` | Naranja de cinta de rally: foco, primario |
| `ACCENT_HOVER` / `ACCENT_PRESSED` | `#FF8552` / `#E0561C` | Estados |
| `TEXT_ON_ACCENT` | `#1A0E08` | Texto sobre naranja |
| `HUD_REC` | `#FF3B30` | REC |
| `SUCCESS` | `#69C36F` | Confirmaciones, nota A |
| `WARN` (nuevo) | `#FFB020` | Advertencias, nota B |
| `DANGER` | `#FF5A4F` | Acciones destructivas |
| `SKY` (nuevo) | `#7FB7D8` | Secundario: mapa, valores, enlaces |
| `SCRIM` | `Color(0.05, 0.06, 0.08, 0.84)` | Scrim oscuro sobre el 3D |

Los colores de gráficos (`GRAPH_PITCH`, `GRAPH_ROLL`, `GRAPH_YAW`, `GRAPH_GRID`) se ajustan para fondo oscuro.

### Regla "oscuro sobre 3D"

- Todo menú que se abre sobre la etapa usa el scrim oscuro y un desenfoque barato: `gui/components/scrim.gd` dibuja un `BackBufferCopy` + `ColorRect` con `gui/theme/scrim_blur.gdshader` (desenfoque separable de 6 muestras sobre `SCREEN_TEXTURE` reducido). El desenfoque se puede apagar con `GameSettings` (el plan 07 lo expone en Gráficos; aquí queda la bandera).
- `Stage.open_pause_menu()` y `Stage.show_results()` ocultan la `CanvasLayer` `UI` (visor, `StageHud`, tablet, resumen) mientras hay un menú, y la restauran al cerrarlo.
- `MenuScreen._draw` con `Backdrop.SCRIM` usa el componente de scrim; con `OPAQUE` usa el degradado `BG_TOP`→`BG_BOTTOM`.

### Tipografía

Recursive, ya en el repo, con roles fijos:

| Rol | Fuente | Tamaño | Notas |
|---|---|---|---|
| Display | Sans Bold | 64 | Mayúsculas, títulos de pantalla |
| Title | Sans Bold | 40 | Títulos de sección |
| Heading | Sans Bold | 24 | Encabezados de tarjeta |
| Body | Sans Med | 20 | Texto corriente |
| Caption | Sans Med | 16 | Ayudas, pies |
| Value | Mono | 20–28 | Números, tiempos, notas |

### Componentes del theme

- **Nuevas variaciones** en `theme_builder.gd`: `StatChip` (etiqueta + valor mono en una píldora), `GradeLabel` (mono 72 con color por nota: S dorado `#FFC94A`, A `SUCCESS`, B `WARN`, C `DANGER`), `SliderRow` (fila con rótulo, slider y valor alineados), `SectionHeader` (rótulo en mayúsculas con una línea de acento de 24 px a la izquierda).
- **Cambiadas:** `OverlayScrim` (oscuro), `Card` (superficie + borde de 1 px + radio 12), `MenuItemButton` (56 px de alto, mayúsculas, sin relleno; en foco y hover una barra de acento de 4 px a la izquierda y el texto en crema pleno), `PrimaryButton` (fondo acento, texto `TEXT_ON_ACCENT`), `DangerButton` (contorno rojo), `GhostButton`, `KeyCap` (píldora oscura con borde), `HudPreviewPanel`. Anillo de foco: 2 px de acento más 1 px oscuro por fuera, para que se vea sobre cualquier fondo.
- Los iconos rasterizados (`_switch_icon`, `_checkbox_icon`, `_chevron_icon`, `_ring_icon`, `_updown_icon`, `_tick_icon`) se regeneran con los colores nuevos.
- `main_theme.tres` no se edita a mano nunca: siempre `build_theme.gd`.

### Logo e icono

- `gui/components/logo.gd` (`Logo`, un `Control`): dibuja el wordmark "DRONE RALLY CAM" en Recursive Sans Bold, en dos líneas ("DRONE RALLY" / "CAM"), entre corchetes de encuadre de gimbal `[ ]` dibujados con líneas, con el punto REC rojo arriba a la derecha. Escala con `size`. Se usa en la pausa (chico) y en el título del plan 04 (grande).
- `icon.svg` propio escrito a mano en el repo: cuadrado redondeado naranja `#FF6A2B`, silueta geométrica del dron en crema (cuerpo + cuatro brazos + hélices como círculos), punto REC rojo. Sin texto dentro del SVG (el importador no rasteriza fuentes).

### Glifos: `KeyCap`

`gui/components/key_cap.gd` (`KeyCap`, un `Control` dibujado por código) recibe una acción (`action: StringName`) o un glifo fijo. Con mando PlayStation dibuja ✕ azul, ○ rojo, □ rosa, △ verde en un círculo oscuro; L1/R1/L2/R2 como píldoras; la cruceta como una cruz con la dirección resaltada; Options/Share como píldoras. Con Xbox, A/B/X/Y con sus colores. Con teclado, una tecla con el nombre de `InputHints.key_name()`. Se actualiza con `Controls.input_device_changed` y al cerrar Controles. Lo usan `ControlHints`, `ConfirmOverlay`, `PauseMenu` (tarjeta de controles) y `HelpPage`. Los textos de juego (guía, checklist) siguen usando `InputHints.button()`; la tabla de nombres es una sola (`ui/input_hints.gd`).

Para la Ayuda, `KeyCap` expone `static func texture_for(action) -> Texture2D` (rasteriza a una `ImageTexture` cacheada) para incrustarlo en el `RichTextLabel` con `[img]`.

### Sonidos propios

`debug/tools/build_ui_sounds.gd` sintetiza los cinco sonidos como `AudioStreamWAV` y los guarda con `save_to_wav` en `Assets/Audio/UI/` con los mismos nombres, así `UI.SOUNDS` no cambia:

| Sonido | Receta |
|---|---|
| `hover` | Blip senoidal 1,8 kHz, 30 ms, ataque 2 ms, caída exponencial, muy bajo |
| `click` | Dos tonos 1,2 → 1,6 kHz de 25 ms con un transitorio de ruido de 3 ms |
| `back` | Barrido descendente 1,4 → 0,9 kHz, 70 ms |
| `tick` | Clic de 8 ms (ruido filtrado) + tono 2 kHz de 15 ms |
| `error` | Dos pulsos graves de 220 Hz con leve distorsión, 180 ms |

### Rediseño de pantallas

- **Pausa:** fondo con scrim oscuro y desenfoque. Columna izquierda: logo chico, "EN PAUSA", opciones con `MenuItemButton`. Panel derecho de contexto (`Card`): estado de la etapa (fase, auto, tiempo), tomas entregadas con su nota (`GradeLabel` chico), y una tarjeta de controles con `KeyCap` (armar, modo, grabar, vista, tomar/soltar control).
- **Opciones:** hub de tarjetas grandes (Juego y HUD, Audio, Controles; el plan 07 agrega Gráficos) con icono simple dibujado, título y una línea de descripción.
- **Audio:** filas `SliderRow` con el valor en porcentaje; interruptor de silencio al final.
- **Controles:** dos secciones navegables con L1/R1 (del plan 01): "Mando" (mando activo, zona muerta, ejes y botones en vivo, calibrar) y "Acciones" (lista de asignaciones con su `KeyCap`). El modelo 3D del dron y de la radio se mantiene como ilustración a la derecha.
- **Juego y HUD:** pestañas con el preview grande del visor (el del plan 02) a la derecha.
- **Ajustes del dron:** tres secciones con `SectionHeader` (Cámara FPV, Peso, Rates); el gráfico de rates (`gui/rate_graph.gd`) recoloreado para fondo oscuro.
- **Ayuda:** `BodyText` con `KeyCap` incrustados; secciones con `SectionHeader`; se desplaza con el stick derecho (agregar desplazamiento con `ui_up`/`ui_down` en el `RichTextLabel` cuando está enfocado).
- **Diálogo de confirmación:** `Card` centrada, título, texto, botones Cancelar (`GhostButton`) y Confirmar (`PrimaryButton` o `DangerButton`), fila de `KeyCap` debajo.
- **Resultados:** solo estilo en este plan (`GradeLabel`, `Card`, scrim); el contenido nuevo es del plan 04.

## 4. Archivos

**Crear:** `gui/components/key_cap.gd`, `gui/components/logo.gd`, `gui/components/scrim.gd`, `gui/theme/scrim_blur.gdshader`, `debug/tools/build_ui_sounds.gd`, `debug/headless_checks/check_theme.gd`.

**Modificar:** `gui/theme/ui_palette.gd`, `gui/theme/theme_builder.gd`, `gui/theme/main_theme.tres` (regenerado), `gui/menu_screen.gd`, `gui/components/control_hints.gd`, `gui/components/confirm_overlay.gd`, `gui/pause_menu.gd/.tscn`, `gui/options_menu/options_menu.gd/.tscn`, `audio_menu.gd/.tscn`, `game_settings_menu.gd/.tscn`, `hud_config.gd/.tscn`, `controls_menu/controls_menu.gd/.tscn` (y los `gui_controller_*` que dibujan colores), `gui/quad_settings_menu.gd/.tscn`, `gui/rate_graph.gd`, `gui/help_page.gd/.tscn`, `ui/results_screen.gd/.tscn` (estilo), `ui/input_hints.gd` (exponer lo que `KeyCap` necesita), `autoloads/game_settings.gd` (bandera de desenfoque), `game/stage.gd` (ocultar `UI` con menús), `icon.svg`, `Assets/Audio/UI/*.wav` (regenerados), `localization/translations.csv`, `debug/headless_checks/check_all.gd`, `debug/tools/screenshot_tour.gd`.

**Reutilizar:** el sistema de `theme_builder.gd` y sus rasterizadores de iconos, `InputHints`, `Controls.is_playstation_pad()`, `MenuScreen` y su flujo de submenús, `UI` (sonidos automáticos por botón).

## 5. Pasos

1. **Paleta y theme.** `UIPalette` v2, cambios y variaciones nuevas en `theme_builder.gd`, regenerar `main_theme.tres`. Crear `check_theme.gd` con las aserciones de variaciones y contraste. Correr todos los chequeos.
2. **Scrim oscuro con desenfoque** y ocultar la capa `UI` detrás de pausa y resultados.
3. **`KeyCap`** y su uso en `ControlHints`.
4. **Logo e `icon.svg`.**
5. **Sonidos generados** con `build_ui_sounds.gd`.
6. **Pausa y hub de Opciones.**
7. **Audio y Controles.**
8. **Juego y HUD y Ajustes del dron** (incluido `rate_graph.gd`).
9. **Ayuda y diálogo de confirmación.**
10. **Estilo de resultados**, tour completo y pruebas manuales.

## 6. Verificación

**Deben seguir en verde:** `check_gui`, `check_settings`, `check_scoring_ui`, `check_gamepad_nav` (plan 01) y el resto.

**Chequeo nuevo `check_theme.gd`:**
- `ThemeBuilder.build()` contiene todas las variaciones listadas (existentes y nuevas).
- Contraste (luminancia relativa WCAG): `TEXT`/`SURFACE` ≥ 7; `TEXT_2`/`SURFACE` ≥ 4,5; `TEXT_ON_ACCENT`/`ACCENT` ≥ 4,5; `TEXT`/`BG` ≥ 7.
- `main_theme.tres` está regenerado: el color de fondo de 5 styleboxes (`Button/normal`, `Card/panel`, `MenuItemButton/focus`, `OverlayScrim/panel`, `PrimaryButton/normal`) coincide con `build()`.
- `KeyCap` para `interact` con un mando PlayStation simulado da "□"; con Xbox, "X".
- Los cinco WAV de UI existen, duran más de 20 ms y menos de 400 ms.
- Con la pausa abierta, `stage.get_node("UI").visible` es falso; al reanudar vuelve a ser verdadero.

**Tour de capturas:** rehacer `08_pause_menu`, `09_options_controls`, `10_options_hud`, `11_drone_settings`, `12_help`, `13_results`; nuevas `08b_confirm_overlay`, `09b_options_audio`, `09c_options_hub`, `12b_help_keycaps`. Revisar legibilidad sobre cielo claro.

**Pruebas manuales con el PS4:**
1. Recorrer todos los menús: los pies de página muestran ✕ ○ y la cruceta con sus colores.
2. Pausar con cielo de mediodía de fondo: el texto se lee cómodo y el HUD no se ve.
3. Escuchar los sonidos de hover, clic, volver, tick (sliders) y error.
4. Cambiar de mando a teclado: los `KeyCap` cambian solos.
5. Revisar el icono en la barra de tareas al exportar.

## 7. Riesgos y qué no tocar

- **No renombrar** ninguna constante de `UIPalette` que use `HudStyle` (`FONT_*`, `HUD_REC`, `ACCENT`, `SUCCESS`); agregar nuevas sí.
- **No tocar** `hud/` ni `ui/drone_visor*`: el visor recibe la identidad a través de esas constantes.
- `HelpPage.SECTIONS` mantiene sus claves; solo cambia el formato.
- El desenfoque del scrim lee la pantalla: probarlo en la GPU del usuario; si baja mucho los fps, queda apagado por defecto hasta el plan 07.
- Los `.tscn` de menús tienen nodos referenciados por `%Nombre` desde los scripts y los chequeos (`ButtonResume`, `ButtonOptions`, etc.): mantener esos nombres aunque cambie el layout.
