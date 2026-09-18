# Drone Rally Cam — Planes "next level"

Siete planes para llevar el prototipo a una calidad profesional. Se ejecutan **uno por sesión**, en el orden de abajo, con Opus. Cada plan es autónomo: trae su diagnóstico con evidencia, sus decisiones, sus archivos, sus pasos y su verificación.

Estado de partida (commit `278182f` en `master`): Fase 1 + iteración 2. El juego se juega completo con gamepad PS4 o teclado y mouse; hay 13 chequeos headless y un tour de capturas. Los menús y el HUD vienen trasplantados del simulador de drones y todavía se ven como tal.

## Orden y dependencias

| # | Plan | Depende de | Motivo del lugar |
|---|---|---|---|
| 01 | [Gamepad en menús](01-gamepad-en-menus.md) | — | Desbloquea probar todo lo demás con el PS4. Correcciones puntuales, sin rediseño. |
| 02 | [Visor del dron v2](02-visor-del-dron-v2.md) | 01 | La pantalla que más se ve; corrige lógica y layout. Independiente del theme de menús. |
| 03 | [Identidad visual y UI propia](03-identidad-visual-y-ui-propia.md) | 01 | Necesita el pad para validar pies de página y glifos. Va después de 02 para no rehacer el visor dos veces. |
| 04 | [Front-end y flujo](04-front-end-y-flujo.md) | 03 | Título, menú principal, selección, carga y resultados con progreso: usa los componentes de 03. |
| 05 | [Mundo y presentación](05-mundo-y-presentacion.md) | 02 | El plan más grande. Define `StageFeedback` (EventBus → VFX + ganchos de audio). Puede ir antes de 04 si se prefiere ver el mundo primero. |
| 06 | [Audio](06-audio.md) | 05 | Rellena los ganchos `Audio.play_event` que 05 deja declarados. |
| 07 | [Rendimiento y opciones gráficas](07-rendimiento-y-opciones-graficas.md) | 05, 03 | Mide el mundo terminado (chunks, LOD, colliders) y agrega el menú Gráficos. |

Después de 01 hay dos pistas posibles: **UI** (03 → 04) y **mundo** (02 → 05 → 06 → 07). El orden recomendado es 01, 02, 03, 04, 05, 06, 07.

## Decisiones de dirección ya tomadas

- **Estilo visual:** low-poly estilizado y pulido (referencia: Art of Rally). Sin comprar assets: todo procedural, SVG o hecho en el repo.
- **Identidad "Rally al atardecer":** fondos oscuros cálidos (`#14161A` / `#1E2126`), texto crema `#F2EFE9`, acento naranja de cinta de rally `#FF6A2B`, rojo REC `#FF3B30`, azul cielo `#7FB7D8` como secundario. Wordmark "DRONE RALLY CAM" en Recursive Bold entre corchetes de gimbal con el punto REC.
- **Mando principal:** PS4. Los carteles muestran ✕ ○ □ △ / L1 R1 / Options / Share cuando hay un mando PlayStation y A B X Y cuando es Xbox. Teclado y mouse siempre a la par.
- **Contrato de tokens de estilo:** `ui/hud_style.gd` (`HudStyle`) es del plan 02 y es la única receta de estilo del visor. `gui/theme/ui_palette.gd` (`UIPalette`) es del plan 03. Lo único compartido son constantes que ya existen y nadie renombra: `UIPalette.FONT_REGULAR`, `FONT_BOLD`, `FONT_MONO`, `HUD_REC`, `ACCENT`, `SUCCESS`. El plan 02 hace que `HudStyle` lea REC y acento de ahí; el plan 03 cambia valores, no nombres, y no toca `hud/` ni `ui/drone_visor*`.

## Convenciones para todos los planes

- **Código:** GDScript tipado como el resto del repo (`var _discard := señal.connect(...)`, `:=` siempre que el tipo se infiera, `@onready` con `as`). Sin dependencias externas.
- **Textos:** los de menús van por clave en `godot/localization/translations.csv` (columnas `keys,es,en`, todas las filas con 3 columnas); los textos de juego (radio, guía, comentarios del productor) siguen en español directo.
- **No tocar:** el modelo de vuelo y los PID (`drone/flight_controller/**`), `Gimbal.angular_speed`, los umbrales de `filming/shot_scorer.gd` y `filming/shot_report.gd`, la generación del camino (`StageBuilder._flatten_road`, `driving_curve`) ni `SpeedProfile`. Cada plan lista además su propio "no tocar".
- **Chequeos:** los 13 chequeos headless siguen en verde. Los nuevos se registran en `godot/debug/headless_checks/check_all.gd` y heredan de `HeadlessCheck` (helpers `expect`, `note`, `physics_frames`, `process_frames`, `action`, `focus_name`, `find_child_with_script`, `add_floor`). Nunca se afloja una aserción para que pase: se arregla el código.
- **Aislamiento:** todo archivo nuevo de usuario (progreso, gráficos) se redirige en `_isolate_settings()` de `check_all.gd` y de `debug/tools/screenshot_tour.gd`, como ya se hace con Controles, Audio, Juego y Ajustes del dron. Los chequeos y el tour nunca tocan `user://config`.
- **Tour de capturas:** cada plan agrega sus capturas a `debug/tools/screenshot_tour.gd` y las revisa con la herramienta de lectura de imágenes antes de dar por terminado.
- **Cierre de un plan:** chequeos en verde, tour renderizado y revisado, pruebas manuales con el PS4 hechas, `README.md` del repo actualizado si cambia algo que describe, commit en `master` y push.

## Cómo ejecutar un plan con Opus

1. Abrir el plan y leer entero "Contexto y diagnóstico": tiene la evidencia `archivo:línea` del estado actual. Verificar que sigue vigente (los planes anteriores pueden haber movido cosas).
2. Seguir los pasos en orden. Cada paso deja el juego funcionando y los chequeos en verde.
3. Después de agregar un `class_name` o una escena nueva, reimportar antes de correr chequeos.
4. Al terminar, correr todo y renderizar el tour.

```sh
# Desde la raíz del repo (el proyecto está en godot/)
godot --headless --path godot --import
godot --headless --path godot --fixed-fps 100 res://debug/headless_checks/check_all.tscn
godot --headless --path godot --fixed-fps 100 res://debug/headless_checks/check_all.tscn -- --only=visor
godot --path godot --resolution 1920x1080 res://debug/tools/screenshot_tour.tscn -- --out=C:/carpeta/capturas
godot --headless --path godot -s res://debug/tools/build_theme.gd
```

En esta máquina `godot` es `C:/Users/Mauri/Godot/Godot_4.7/Godot_v4.7-stable_win64_console.exe`. El editor del usuario suele estar abierto: no cerrar procesos de Godot que no se hayan lanzado desde la sesión, y avisar cuando se edita `project.godot` para que recargue sin guardar encima.

## Plantilla de cada plan

1. **Contexto y diagnóstico** — qué hay hoy y por qué no alcanza, con evidencia.
2. **Objetivo y criterio de terminado** — qué tiene que verse y funcionar al final.
3. **Decisiones de diseño** — lo que ya está decidido; Opus no lo rediscute salvo que sea inviable, y en ese caso lo dice.
4. **Archivos** — crear, modificar, borrar, y qué reutilizar.
5. **Pasos** — de 5 a 12, cada uno verificable.
6. **Verificación** — chequeos existentes que deben seguir, chequeo nuevo con lo que afirma, capturas del tour, pruebas manuales con el PS4.
7. **Riesgos y qué no tocar.**
