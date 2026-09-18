# Plan 05 — Mundo y presentación estilizada

Depende de: 02 (el visor estable, porque este plan agrega un post de cámara y el marcador del auto usa el mundo). Si el usuario prefiere ver el mundo antes que el front-end, puede ir antes que 04.

Si al ejecutarlo se hace largo, se corta en **05a** (pasos 1–3: luz, terreno, camino, árboles) y **05b** (pasos 4–9: props, auto, dron, maleta, jugador, VFX).

## 1. Contexto y diagnóstico

El estilo elegido es **low-poly estilizado y pulido** (referencia: Art of Rally): formas simples, pero con paleta cuidada, luz baja y cálida, sombras largas, siluetas claras y mucho "set dressing". Hoy el mundo es un prototipo (rutas relativas a `godot/`):

- **Luz y entorno** (`world/stages/stage_01.tscn`): `ProceduralSkyMaterial`, un solo sol de energía 1,2 casi al mediodía, sombras hasta 250 m, **niebla volumétrica de densidad 0,0025 que blanquea todo a partir de unos 150 m** (capturas `05_stage_overview`, `13_results`), SSAO y glow por defecto, sin `CameraAttributes`, sin SDFGI ni sondas.
- **Terreno** (`world/stage_builder.gd`, `world/materials/terrain.gdshader`): 768 m a 1,5 m de resolución, una sola malla de 524 k triángulos; shader procedural sin texturas (pasto, roca por pendiente, tierra cerca del camino por color de vértice). De cerca se ven facetas y manchas (`07_road_edge`).
- **Camino** (`_build_road_mesh`, `world/stage_builder.gd:389`): una cinta plana de dos vértices de ancho elevada 4 cm. Parece pintado sobre el pasto.
- **Árboles** (`_build_scenery`, `:492`): **conos de 8 segmentos sobre cilindros de 6**, en dos `MultiMeshInstance3D` (troncos y copas), con color de copa al azar. Rocas: esferas de 7 segmentos. Cada árbol tiene dos `CollisionShape3D` propias (1.000 nodos en total; el plan 07 lo resuelve).
- **Cero props:** no hay largada ni meta, cintas, fardos, carteles, público, comisarios ni vehículos. Tampoco partículas: no hay un solo nodo de partículas en el proyecto.
- **Auto** (`car/rally_car.tscn`): nueve cajas y cuatro cilindros con colores planos (`Body`, `Stripe`, `Cabin`, `Roof`, `Spoiler`, `WheelFrontLeft/Right`, `WheelRearLeft/Right`, `HeadlightLeft/Right`). **Las ruedas no giran ni doblan**; no hay polvo; el número 7 solo existe como dato (`car_number`). El movimiento lo resuelve `_place()` (`car/rally_car.gd:120`) con desplazamiento lateral (`_lateral`) y derrape visual (`_drift`) a partir de la curvatura del perfil.
- **Dron y maleta:** el gimbal no tiene malla (`drone/gimbal.gd`, capa `DRONE_BODY_LAYER` para ocultar el cuerpo a sus cámaras). La maleta (`player/drone_case.tscn`: `Base`, `Foam`, `Lid`, `LatchLeft/Right`, `DroneSpot`) aparece ya abierta y no se anima.
- **Jugador** (`player/player.tscn`): cápsula con `Head/Camera3D`; sin balanceo al caminar, sin maleta visible, sin sombra propia.
- **Ganchos sin usar:** `autoloads/event_bus.gd` declara `drone_deployed`, `drone_recovered`, `drone_crashed(drone, speed)`, `battery_low`, `battery_depleted`, `recording_started`, `recording_stopped`, `recording_aborted`, `shot_score_updated`, `car_started`, `car_finished`; ninguna los usa para presentación.
- **Herramientas que ya sirven para colocar cosas:** `StageBuilder.road_samples` (una muestra cada 2 m), `driving_curve`, `get_height()`, `get_road_distance()`, `_slope_at()`, `tree_positions`, `_multimesh()`, y `_find_clear_spot()` del tour (`debug/tools/screenshot_tour.gd:194`), que busca un punto llano a 12 m del camino sin árboles cerca.

## 2. Objetivo y criterio de terminado

Las capturas `02_player_roadside`, `05_stage_overview`, `06_car_close` y `07_road_edge` se ven como un juego low-poly pulido:

- Sol bajo y cálido, sombras largas y suaves, lejanía con perspectiva aérea en vez de niebla blanca.
- Terreno con variación de color y relieve legible; camino con banquina, corona y huellas.
- Árboles con silueta (pinos escalonados, frondosos, arbustos) que se mecen con el viento; pasto junto al camino.
- Un tramo que se lee como rally: arco de largada, pancarta de meta, carteles de kilómetro, cintas en las curvas, fardos, público, comisario, camioneta de asistencia.
- Auto con ruedas que giran y doblan, balanceo, número visible y polvo.
- Maleta que se abre al desplegar, jugador con balanceo y maleta en la mano, gimbal visible.
- Choque, aterrizaje y grabación con respuesta visual, todo colgado de `EventBus`.

## 3. Decisiones de diseño

### Luz, cielo y post

- Recurso compartido `world/environment/rally_env.tres` (el `Environment`) y escena `world/environment/rally_sun.tscn` (el `DirectionalLight3D`), usados por todas las etapas.
- **Sol:** elevación ≈ 32°, azimut lateral al camino (las sombras cruzan el tramo), `light_energy = 1.6`, color `#FFE7C2`, `light_angular_distance = 1.2` (sombras suaves), `directional_shadow_mode = PARALLEL_4_SPLITS`, `directional_shadow_max_distance = 300`, `shadow_blur = 1.5`.
- **Cielo:** `PhysicalSkyMaterial` con tono cálido (Rayleigh algo más bajo, Mie cálido), `sun_disk_scale = 3`. Ambiente y reflejos desde el cielo con `ambient_light_energy = 0.6`.
- **Tonemap:** ACES, exposición 1,0, blanco 6.
- **Glow:** intensidad 0,35, mezcla softlight, umbral 1,1. **SSAO:** radio 1,5, intensidad 1,2.
- **Niebla volumétrica apagada.** Niebla de profundidad `fog_density = 0.0012`, `fog_aerial_perspective = 0.6`, `fog_sky_affect = 0.35`, más niebla de altura (`fog_height = -20`, `fog_height_density = 0.03`) para que los valles se vean profundos.
- **Ajustes:** saturación 1,08, contraste 1,05.
- **Look de cámara** solo en las cámaras del dron: `ui/post/camera_look.gdshader` en un `CanvasLayer` del visor (viñeta suave y grano fino animado). La cámara del jugador queda limpia.

### Terreno y camino

- `terrain.gdshader`: variación macro con dos octavas, tinte por altura (valles más oscuros y fríos, lomas más cálidas), oscurecimiento en pliegues según la pendiente, bandas de pasto seco. El ruido se lee de una `NoiseTexture2D` precalculada en vez de calcular `fbm` por píxel (también ayuda al plan 07).
- **Camino:** `_build_road_mesh` pasa a cinco vértices por muestra (banquina exterior, borde, centro con corona de +6 cm, borde, banquina exterior) con banquina inclinada de 1,2 m que se funde con el terreno. `road.gdshader` gana huellas más marcadas, piedras sueltas y un borde de pasto que invade.
- `_flatten_road` no cambia: la geometría del camino es solo visual sobre el terreno ya aplanado.

### Árboles y pasto

- `world/props/tree_mesh.gd` (`TreeMesh`) genera por código, con `SurfaceTool` y normales por cara (look facetado):
  - **Pino:** tres conos escalonados con leve jitter y un tronco corto.
  - **Frondoso:** 4–5 esferas bajas (6 segmentos) agrupadas, con degradado de color por vértice (más claro arriba).
  - **Arbusto:** una o dos esferas achatadas.
- Sin alpha cards (evita problemas de orden y de sombras).
- El tipo de cada árbol se elige con un generador **separado** sembrado con `scenery_seed + 1`, así la secuencia de posiciones (`tree_positions`) queda idéntica a la de hoy.
- `foliage.tres` pasa a `ShaderMaterial` con balanceo por viento en `vertex()` (seno por posición y altura; amplitud baja).
- Matas de pasto en un `MultiMesh` a 3–15 m del borde del camino.
- Se mantienen `_multimesh()` y `tree_positions`.

### Props del rally

- `StageBuilder.find_clear_spot(near: Vector3, distance_from_road := 12.0, clearance := 7.0) -> Vector3`: la lógica de `screenshot_tour._find_clear_spot` pasa al builder, y el tour la llama.
- `world/props/prop_meshes.gd`: mallas low-poly por código (arco, pancarta, cartel, estaca, fardo, persona de cápsulas con torso y cabeza, bandera, camioneta de cajas).
- `world/props/prop_catalog.gd` (`PropCatalog`) coloca con `scenery_seed + 2`, a partir de `road_samples` y `driving_curve`:
  - **Arco de largada** en el kilómetro 0 y **pancarta de meta** al final, perpendiculares al camino.
  - **Tablero de kilómetro** cada 500 m.
  - **Cinta roja y blanca con estacas** en el lado exterior de las curvas con curvatura por encima de un umbral (misma curvatura que usa `SpeedProfile`).
  - **Fardos** en el exterior de las tres curvas más cerradas.
  - **Tres grupos de público** (4–6 personas de cápsulas, colores variados) en claros hallados con `find_clear_spot`, mirando al camino.
  - **Comisario con bandera** junto a la largada y en un punto intermedio.
  - **Camioneta de asistencia** y un toldo junto a la largada.
  - **Postes y alambrado** en un tramo recto.
- Mismo `MultiMesh` por tipo de prop. Colisión solo en la camioneta y los fardos (`StaticBody3D`, capa `terrain`); el resto sin colisión.

### Auto

- Ruedas: rotación en X a `speed / 0.33` rad/s; las delanteras doblan en Y según la curvatura del perfil y `_drift` (hasta 25°).
- Carrocería: balanceo lateral según la aceleración lateral (`speed² · curvatura`) y cabeceo al frenar/acelerar (derivada de `speed`), con suavizado. Se aplica a un nodo `Chassis` nuevo que agrupa las mallas, no al `AnimatableBody3D`.
- Detalles: número 7 en puertas y techo con `Label3D` (fuente de `UIPalette.FONT_BOLD`), antena, faldones.
- **Polvo:** `GPUParticles3D` detrás de cada rueda trasera, cantidad proporcional a la velocidad, quads con degradado de alfa y color del camino, vida 1,6 s, se agrandan y suben. Salpicadura de piedras chica en curvas cerradas.
- `CollisionShape3D` y `get_scoring_aabb()` no cambian (el puntaje depende de ellos).

### Dron, maleta y jugador

- Malla del gimbal (caja + lente) hija de `Gimbal`, en `DRONE_BODY_LAYER` para que sus cámaras no la vean.
- Maleta: script `player/drone_case.gd`; la tapa (`Lid`) se abre con un Tween al desplegar y se cierra al guardar; la espuma gana un hueco con la forma del dron. Emite `EventBus.case_opened` / `case_closed`.
- Jugador: balanceo de cámara al caminar (amplitud y frecuencia según la velocidad, menor agachado), `EventBus.player_step(surface: StringName)` en cada paso (`&"gravel"` si `get_road_distance` < ancho del camino, `&"grass"` si no). Maleta en la mano: malla hija de `Head` en una capa que solo ve la cámara del jugador, visible mientras `has_kit`. Sombra propia con una malla `SHADOWS_ONLY`.

### Feedback: `StageFeedback`

- Nodo nuevo `game/stage_feedback.gd` (`StageFeedback`) en `game/stage.tscn`. Una tabla une cada señal de `EventBus` con su respuesta:
  - `drone_crashed` → chispas + polvo en el punto del choque; sacudida de cámara si se está en la vista piloto.
  - `drone_deployed` / `drone_recovered` → polvo chico al apoyar el dron.
  - Aterrizaje (distancia al suelo < 1 m con el dron armado y bajando) → anillo de polvo.
  - `recording_started` / `recording_stopped` / `recording_aborted`, `battery_low` / `battery_depleted`, `car_started` / `car_finished`, `player_step`, `case_opened` / `case_closed` → por ahora solo audio.
- Cada respuesta llama también a `Audio.play_event(&"id", posición)`. En este plan `Audio.play_event` es un stub que no hace nada si el id no está en su tabla (vacía); el plan 06 la llena.
- Partículas como escenas en `vfx/` (`vfx/dust_puff.tscn`, `vfx/sparks.tscn`, `vfx/landing_ring.tscn`) con un pool chico por tipo.

### Presupuesto

El tour imprime `Performance.get_monitor(RENDER_TOTAL_DRAW_CALLS_IN_FRAME)` y `RENDER_TOTAL_PRIMITIVES_IN_FRAME` por captura. Meta: menos de 450 draw calls en `05_stage_overview`. Si se pasa, se revisa antes de seguir (MultiMesh por tipo, sin materiales únicos por instancia).

## 4. Archivos

**Crear:** `world/environment/rally_env.tres`, `world/environment/rally_sun.tscn`, `world/props/tree_mesh.gd`, `world/props/prop_meshes.gd`, `world/props/prop_catalog.gd`, `world/materials/foliage.gdshader`, `world/materials/grass.gdshader`, `world/materials/noise_macro.tres` (`NoiseTexture2D`), `ui/post/camera_look.gdshader`, `player/drone_case.gd`, `game/stage_feedback.gd`, `vfx/dust_puff.tscn`, `vfx/sparks.tscn`, `vfx/landing_ring.tscn`, `vfx/car_dust.tscn`, `debug/headless_checks/check_world_presentation.gd`.

**Modificar:** `world/stage_builder.gd` (camino de 5 vértices, árboles, pasto, `find_clear_spot`, llamada a `PropCatalog`), `world/stage_world.gd`, `world/stages/stage_01.tscn` (y `stage_02.tscn` si el plan 04 ya la creó: ambas usan el entorno compartido), `world/materials/terrain.gdshader`, `road.gdshader`, `foliage.tres`, `car/rally_car.tscn/.gd`, `drone/drones/rally_drone.tscn`, `player/drone_case.tscn`, `player/player.gd/.tscn`, `game/stage.tscn`, `autoloads/event_bus.gd` (`player_step`, `case_opened`, `case_closed`), `autoloads/audio.gd` (stub `play_event`), `ui/drone_visor.gd` (capa del look de cámara), `debug/tools/screenshot_tour.gd`, `debug/headless_checks/check_all.gd`.

**Reutilizar:** `_multimesh()`, `road_samples`, `driving_curve`, `get_height()`, `get_road_distance()`, `_slope_at()`, `tree_positions`, `SpeedProfile.curvature_at()`, `Gimbal.DRONE_BODY_LAYER`, señales de `EventBus`.

## 5. Pasos

1. **Entorno y sol compartidos** + look de cámara del dron. Tour: comparar `05_stage_overview` antes y después.
2. **Terreno y camino.** Shader con ruido precalculado; camino de 5 vértices. `check_car` y `check_stage` en verde.
3. **Árboles y pasto.** `TreeMesh`, selección de tipo con generador aparte, viento, pasto. Aserción: `tree_positions` idéntico al de antes del cambio (guardar el hash en el chequeo).
4. **`find_clear_spot` en el builder y catálogo de props.** El tour usa el método nuevo.
5. **Auto:** `Chassis`, ruedas, balanceo, número, polvo.
6. **Gimbal, maleta y jugador.**
7. **`StageFeedback`, VFX y stub de audio.**
8. **Presupuesto en el tour.**
9. **Chequeo nuevo, tour completo y pruebas manuales.**

## 6. Verificación

**Deben seguir en verde:** `check_stage` (el auto completa, el dron despega, el clip tiene muestras), `check_car`, `check_control_state`, `check_load`, `check_scorer` (la visibilidad del auto no debe empeorar por props), `check_stage_info` (marcador del dron, checklist) y el resto.

**Chequeo nuevo `check_world_presentation.gd`:**
- Con la misma semilla, dos construcciones dan las mismas `tree_positions` y las mismas transformaciones de props; el hash de `tree_positions` coincide con el de antes de este plan.
- Ningún prop sólido (camioneta, fardos, público, estacas) está a menos de `road_width / 2 + 1` m del centro del camino; los arcos y la pancarta cruzan el camino a más de 5 m de altura libre.
- El arco de largada está cerca de `road_samples[0]` y la pancarta de meta cerca de la última muestra.
- `StageFeedback` está conectado a todas las señales de su tabla.
- Las partículas del auto tienen `emitting == false` con el auto quieto y `true` corriendo a más de 5 m/s.
- `WheelFrontLeft` cambia de rotación después de 30 frames con el auto corriendo.
- La tapa de la maleta rota después de `ControlState.deploy()`.
- Guardas del entorno: energía del sol entre 1,2 y 2,0, niebla volumétrica apagada, `fog_density` menor que 0,002.

**Tour de capturas:** rehacer `02_player_roadside`, `03_drone_deployed`, `05_stage_overview`, `06_car_close`, `07_road_edge`; nuevas `03b_case_open`, `05b_start_arch`, `06b_car_dust`, `07b_trees_close`, `15_golden_hour` (vista baja a contraluz). Mirar cada captura: sin parpadeos de sombra, sin árboles flotando, sin props dentro del camino.

**Pruebas manuales con el PS4:**
1. Recorrer a pie desde el spawn hasta el camino: balanceo, pasto, carteles.
2. Desplegar y guardar el dron: la maleta se abre y se cierra.
3. Filmar el paso del auto de cerca: ruedas, polvo, número legible.
4. Chocar el dron contra el suelo: chispas y polvo; en vista piloto, sacudida.
5. Aterrizar suave: anillo de polvo.
6. Volar alto: la lejanía se ve con perspectiva aérea, no blanca.

## 7. Riesgos y qué no tocar

- **No tocar** `_flatten_road`, `driving_curve`, `SpeedProfile`, `get_scoring_aabb()`, las capas físicas ni el `ground_mask` del dron.
- **El puntaje mira la visibilidad del auto** con rayos contra las capas `terrain` y `car` (`filming/recorder.gd`, `occlusion_mask`). Los props con colisión en la capa `terrain` cerca del camino (fardos) pueden tapar al auto: es realista, pero si `check_scorer` o `check_stage` empeoran, sacarlos de esa capa.
- **Los `Label3D` y props no deben tapar al auto en la cámara del gimbal** de forma sistemática: no ubicar público entre el camino y los claros donde suele pararse el jugador.
- El terreno de 524 k triángulos no se divide en este plan (lo hace el plan 07).
- El orden de los generadores aleatorios importa para el determinismo: los árboles usan `scenery_seed`, el tipo `scenery_seed + 1`, los props `scenery_seed + 2`.
- `StageBuilder` es `@tool`: los props y árboles nuevos tienen que verse también en el editor al tocar "Regenerar".
