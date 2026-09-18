# Plan 04 — Front-end y flujo

Depende de: 03 (identidad visual, `Logo`, `KeyCap`, variaciones del theme). Usa el entorno actual para el fondo del título; el plan 05 lo mejora sin cambiar este plan.

## 1. Contexto y diagnóstico

Rutas relativas a `godot/`.

- **No hay front-end.** `project.godot` arranca directo en la etapa (`run/main_scene="res://game/stage.tscn"`). No hay pantalla de título, menú principal, selección de etapa, pantalla de carga ni transiciones.
- **Reinicio brusco.** `Stage.restart()` hace `get_tree().reload_current_scene()` (`game/stage.gd:136-138`): la etapa se reconstruye entera de forma síncrona (terreno de 513×513 muestras, camino, 1.070 formas de colisión; `StageBuilder.build()`, `world/stage_builder.gd:87-105`) sin fundido ni aviso; la ventana se congela un momento.
- **Salir cierra el juego.** "Salir" en la pausa y en los resultados llama a `get_tree().quit()` (`gui/pause_menu.gd:111`, `ui/results_screen.gd:107`).
- **Sin persistencia.** Las notas desaparecen al cerrar. Solo se guardan ajustes en `user://config/*.cfg`. `ShotReport` (`filming/shot_report.gd`) ya es un `Resource` con campos `@export`, así que se puede guardar tal cual con `ResourceSaver`.
- **Una sola etapa.** `world/stages/stage_01.tscn` define el camino con 20 puntos (`road_points`) y semillas (`terrain_seed`, `scenery_seed`) sobre `StageBuilder`; hacer otra etapa es cambiar esos datos.
- **Construcción del tramo:** `build()` encadena `_generate_heights()`, `_build_road_line()`, `_flatten_road()` (solo arrays) y después `_build_terrain()`, `_build_road_mesh()`, `_build_bounds()`, `_build_scenery()` (nodos, mallas y colisiones). `StageWorld._ready` llama a `build()` si no está construido y le pasa la curva al auto (`world/stage_world.gd`). `Stage._ready` usa el mundo ya construido (spawn del jugador, recorder, visor, tablet).
- **Exportación sin identidad:** `export_presets.cfg` tiene `application/icon=""`, `file_version=""`, `product_version=""`.
- La pantalla de resultados actual (`ui/results_screen.*`) lista las tomas de la corrida con nota y comentario, y ofrece Reiniciar y Salir.

## 2. Objetivo y criterio de terminado

- El juego arranca en una **pantalla de título** con el logo sobre una escena 3D viva.
- **Menú principal:** Jugar, Etapas, Opciones, Ayuda, Salir.
- **Selección de etapa** con al menos dos etapas, mejor nota, tomas entregadas y etapas bloqueadas.
- **Pantalla de carga** con barra de progreso real mientras se construye el tramo, sin congelar la ventana.
- **Resultados** con récord, progreso de desbloqueo y "Siguiente etapa / Repetir / Menú".
- **Progreso guardado** entre sesiones.
- **Transiciones** con fundido en todos los cambios de escena; "Salir" de la pausa vuelve al menú (con confirmación); "Salir" del menú principal cierra el juego.
- La exportación tiene icono, nombre y versión.
- La etapa se sigue pudiendo abrir sola (editor, chequeos, tour).

## 3. Decisiones de diseño

### Escenas y transiciones

- **`game/main.tscn` (`Main`)** pasa a ser la escena principal. Es un nodo liviano que muestra la pantalla de título al arrancar y administra qué pantalla está activa. La etapa **sigue funcionando instanciada sola**: si `Stage` no encuentra un `Main` (o `SceneTransition.current_stage_info` está vacío), usa sus valores exportados.
- **Autoload `SceneTransition`** (`autoloads/scene_transition.gd`, `CanvasLayer` en capa 100, `PROCESS_MODE_ALWAYS`): `fade_to_scene(path: String, payload := {})`, `fade_to_packed(packed: PackedScene, payload := {})`, `reload_stage()`, `current_payload() -> Dictionary`. Fundido a negro de 0,25 s; para entrar a una etapa, un "obturador" (dos barras horizontales que se cierran y se abren). Mientras transiciona ignora entradas y despausa el árbol antes de cambiar de escena.
- `Stage.restart()` pasa por `SceneTransition.reload_stage()`, que muestra la pantalla de carga.

### Título y menú principal

- **Título** (`gui/front/title_screen.tscn`): fondo 3D liviano `gui/front/title_backdrop.tscn` (el dron `drone/drones/drone1.tscn` girando lento sobre 40 m de camino, cámara en órbita suave, el entorno de la etapa), el `Logo` grande del plan 03, y "Pulsá ✕ para empezar" con `KeyCap` (Enter con teclado). Cualquier `ui_accept` pasa al menú.
- **Menú principal** (`gui/front/main_menu.tscn`, `MenuScreen`): Jugar (entra a la última etapa desbloqueada), Etapas, Opciones (reutiliza `gui/options_menu/options_menu.tscn`), Ayuda (reutiliza `gui/help_page.tscn`), Salir (con confirmación). Panel derecho con el progreso resumido (etapas completadas, mejor nota global).
- **Selección de etapa** (`gui/front/stage_select.tscn`): lista desde el catálogo con tarjetas: nombre, longitud, descripción de una línea, mejor nota (`GradeLabel`), tomas entregadas, candado si está bloqueada. Una miniatura del trazado dibujada con los `road_points` de la etapa (misma técnica que `StageMap`, sin construir el terreno).

### Catálogo de etapas

- `world/stages/stage_info.gd` (`StageInfo`, `Resource`): `id: StringName`, `display_name: String`, `scene: String` (ruta), `description: String`, `length_km: float`, `unlock_after: StringName` (id de la etapa previa, vacío si no hay), `unlock_grade: String` ("B" por defecto).
- `world/stages/stage_catalog.gd` (`StageCatalog`, `Resource` con `stages: Array[StageInfo]`) y `world/stages/stage_catalog.tres` con dos etapas: `stage_01` ("Bosque de pinos") y `stage_02` (otro trazado, otras semillas; mismo `stage_world.gd`).
- `Stage` recibe el `StageInfo` por el payload de `SceneTransition` (o `@export var stage_id := &"stage_01"` si se abre solo) y lo usa para guardar el progreso y para el título de la tablet.
- Regla de desbloqueo: una etapa se abre al entregar en la anterior una toma con nota igual o mejor que `unlock_grade`.

### Carga asíncrona del tramo

- `StageBuilder.build_async()` hace lo mismo que `build()` en pasos y emite `build_progress(fraction: float, label: String)`:
  1. `_generate_heights`, `_build_road_line`, `_flatten_road` en un `WorkerThreadPool.add_task` (solo tocan arrays y la `Curve3D`; nada de nodos). Progreso 0 → 0,5.
  2. `_build_terrain`, `_build_road_mesh`, `_build_bounds`, `_build_scenery` en el hilo principal, con `await get_tree().process_frame` entre cada uno (y dentro de `_build_scenery`, cada 100 árboles). Progreso 0,5 → 1.
- `build()` síncrono se conserva tal cual para el editor (`@tool`), los chequeos y el tour.
- `StageWorld` gana `var build_async := false` y la señal `world_ready`. Con `build_async`, su `_ready` no construye; `Stage._ready` hace `await world.build_ready()` (que construye async si hace falta y termina con `car.setup(...)`) antes de ubicar al jugador y conectar todo.
- **Pantalla de carga** (`gui/front/loading_screen.tscn`): fondo oscuro, nombre de la etapa, barra con el progreso de `build_progress`, un consejo al azar (claves `TIP_*` en el CSV, reutilizando textos de la ayuda) y `KeyCap` de los controles principales. Se mantiene encima de la etapa hasta `world_ready` y se retira con el obturador.
- El resultado asíncrono es idéntico al síncrono: mismas alturas, misma curva, mismas posiciones de árboles (lo afirma un chequeo).

### Progreso guardado

- Autoload `Progress` (`autoloads/progress.gd`) con `save_path := "user://save/progress.tres"` (redirigible), `data: SaveData`, `load_progress()`, `save_progress()`, `record_run(stage_id, clips: Array[ShotReport]) -> RunResult`, `is_unlocked(stage_id) -> bool`, `best_grade(stage_id) -> String`.
- `filming/save_data.gd` (`SaveData`, `Resource`): `version: int`, `stages: Dictionary` de `StringName` a `StageProgress`.
- `filming/stage_progress.gd` (`StageProgress`, `Resource`): `best_grade`, `best_mean_score`, `runs`, `clips_delivered`, `last_clips: Array[ShotReport]`, `last_played: String` (fecha ISO).
- `RunResult` (clase interna o diccionario): `new_record: bool`, `unlocked: StringName` (etapa desbloqueada en esta corrida, si alguna).
- Se guarda con `ResourceSaver.save()`; se carga con `ResourceLoader.load(path, "", CACHE_MODE_IGNORE)`. Si el archivo no existe o está roto, se empieza de cero sin romper (y se avisa con `push_warning`).
- `check_all.gd` y `screenshot_tour.gd` redirigen `Progress.save_path` en `_isolate_settings()` y borran el archivo de prueba al empezar.

### Resultados y pausa

- **Resultados** (`ui/results_screen.*`, rediseñado con el estilo del plan 03): mejor nota grande, lista de tomas, "¡Nuevo récord!" si corresponde, "Desbloqueaste: Etapa 2" si corresponde, botones **Siguiente etapa** (si hay y está desbloqueada), **Repetir**, **Menú principal**. `restart_requested` se conserva (lo usa `check_scoring_ui`) y se suman `next_requested` y `menu_requested`.
- **Pausa:** "Salir" pasa a "Volver al menú" (confirmación) y lleva al menú principal por `SceneTransition`; en el menú principal "Salir" cierra el juego.
- `Stage.show_results()` llama a `Progress.record_run()` antes de mostrar la pantalla.

### Proyecto y exportación

- `project.godot`: `run/main_scene="res://game/main.tscn"`, `config/version="0.3.0"`, `config/icon="res://icon.svg"`, autoloads `SceneTransition` y `Progress` después de `UI`.
- `export_presets.cfg`: icono (`icon.ico` generado desde el SVG, o el `.svg` si la plataforma lo acepta), `file_version`, `product_version`, `company_name`, `product_name`; se mantiene `exclude_filter="debug/headless_checks/*"`.

## 4. Archivos

**Crear:** `game/main.tscn`, `game/main.gd`, `autoloads/scene_transition.gd`, `autoloads/progress.gd`, `filming/save_data.gd`, `filming/stage_progress.gd`, `gui/front/title_screen.tscn/.gd`, `gui/front/title_backdrop.tscn/.gd`, `gui/front/main_menu.tscn/.gd`, `gui/front/stage_select.tscn/.gd`, `gui/front/loading_screen.tscn/.gd`, `gui/front/track_thumbnail.gd`, `world/stages/stage_info.gd`, `world/stages/stage_catalog.gd`, `world/stages/stage_catalog.tres`, `world/stages/stage_02.tscn`, `debug/headless_checks/check_flow.gd`.

**Modificar:** `world/stage_builder.gd` (`build_async`, `build_progress`), `world/stage_world.gd` (`build_async`, `world_ready`), `game/stage.gd` (payload, `await` del mundo, `restart` por transición, `Progress.record_run`), `gui/pause_menu.gd/.tscn` (Volver al menú), `ui/results_screen.gd/.tscn`, `ui/tablet.gd` (nombre de la etapa desde `StageInfo`), `project.godot`, `export_presets.cfg`, `localization/translations.csv` (menú, selección, carga, consejos, resultados), `debug/headless_checks/check_all.gd`, `debug/tools/screenshot_tour.gd`, `README.md` del repo.

**Reutilizar:** `MenuScreen`, `UI.confirm`, `Logo`, `KeyCap`, `GradeLabel`, `options_menu.tscn`, `help_page.tscn`, `StageMap` (técnica de proyección para la miniatura), `ShotReport`.

## 5. Pasos

1. **Progreso.** `Progress`, `SaveData`, `StageProgress`; aislamiento en chequeos y tour; aserciones de ida y vuelta en `check_flow`.
2. **Catálogo y segunda etapa.** `StageInfo`, `StageCatalog`, `stage_catalog.tres`, `stage_02.tscn` (probar que el auto completa el tramo nuevo con `check_car` apuntado a la etapa 2, o una aserción en `check_flow`).
3. **Construcción asíncrona.** `build_async`, `build_progress`, `StageWorld.world_ready`, `Stage` esperando al mundo. Aserción de determinismo.
4. **`SceneTransition`.** Fundido y obturador; `Stage.restart()` por transición.
5. **Título** con su fondo 3D y el logo.
6. **Menú principal y selección de etapa** con miniaturas y candados.
7. **Pantalla de carga** conectada a `build_progress`.
8. **Resultados con progreso**; pausa con "Volver al menú".
9. **`Main` como escena principal** y metadatos de exportación.
10. **Tour, README y pruebas manuales.**

## 6. Verificación

**Deben seguir en verde:** los chequeos existentes y los de los planes 01–03. `check_gui`, `check_stage`, `check_stage_info` y `check_scoring_ui` instancian `stage.tscn` directo: tiene que seguir funcionando con `build()` síncrono.

**Chequeo nuevo `check_flow.gd`:**
- `Main` arranca en la pantalla de título; un `ui_accept` lleva al menú principal con el foco en "Jugar".
- El catálogo tiene al menos dos etapas y todas sus escenas existen y se instancian.
- `build_async()` emite progreso monótono de 0 a 1 y, con la misma semilla, `get_height()` en 5 puntos, `road_samples.size()` y `tree_positions` coinciden con `build()`.
- `Progress`: guardar y cargar en el directorio aislado conserva notas y tomas; `record_run` con una toma A marca récord y desbloquea la etapa 2; con una toma C no desbloquea.
- `SceneTransition.reload_stage()` termina con una etapa nueva en el árbol y el árbol despausado.
- La pantalla de resultados con récord muestra "Nuevo récord" y el botón "Siguiente etapa" cuando corresponde.

**Tour de capturas:** nuevas `00_title`, `00b_main_menu`, `00c_stage_select`, `00d_loading`; rehacer `13_results`; nueva `14_results_next` (con récord y desbloqueo). El tour sigue instanciando `stage.tscn` directo para el resto.

**Pruebas manuales con el PS4:**
1. Arrancar el juego exportado o desde el editor con F5: título, menú, Jugar.
2. Terminar la etapa 1 con una toma B o mejor: resultados con récord y desbloqueo; Siguiente etapa.
3. Pausa > Volver al menú; Etapas: la etapa 2 aparece desbloqueada.
4. Cerrar el juego, volver a abrirlo: el progreso sigue.
5. Repetir desde resultados: la carga muestra la barra y la ventana no se congela.
6. Menú principal > Salir con confirmación.

## 7. Riesgos y qué no tocar

- **El hilo de trabajo no toca nodos** ni la `SceneTree`: solo arrays, la `Curve3D` y variables del builder. Cualquier `add_child` va en el hilo principal.
- `StageBuilder` es `@tool`: el botón "Regenerar" del editor debe seguir usando `build()` síncrono.
- **No guardar progreso en `user://config`** (es de ajustes y los chequeos lo manejan distinto).
- El orden de autoloads importa: `Progress` y `SceneTransition` después de `UI`; ninguno reproduce audio ni crea ventanas en `_ready` (los chequeos corren headless).
- `check_scoring_ui` usa `stage.results` y la señal `restart_requested`: mantener ambos.
- No tocar el perfil de velocidad ni el camino de la etapa 1: la etapa 2 es otra escena con otros datos.
