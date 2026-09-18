# Plan 07 — Rendimiento y opciones gráficas

Depende de: 05 (mide el mundo terminado, con props, árboles nuevos y partículas) y 03 (el menú Gráficos usa los componentes de la identidad nueva).

## 1. Contexto y diagnóstico

Rutas relativas a `godot/`.

- **Terreno en una sola malla.** `_build_terrain` (`world/stage_builder.gd:306`) arma un único `ArrayMesh` de 513×513 muestras (≈ 263 k vértices, 524 k triángulos) en un solo `MeshInstance3D`. Sin LOD, sin `visibility_range`, sin división en partes: se dibuja completo aunque se vea una fracción, y proyecta sombras entero.
- **Colisión de árboles con 1.000 nodos.** `_build_scenery` crea un `StaticBody3D` "TreeColliders" con dos `CollisionShape3D` por árbol (tronco cilíndrico y copa cónica convexa), más un `ConvexPolygonShape3D` por roca en "RockColliders" (`world/stage_builder.gd:546-597`). Son unos 1.070 nodos que se crean en cada carga y reinicio.
- **Vegetación en dos `MultiMeshInstance3D` globales** (troncos y copas; el plan 05 agrega tipos y pasto): todo el bosque se envía a la GPU siempre, lejos o cerca.
- **Sin LOD ni oclusión** en todo el proyecto (no hay `visibility_range`, `OccluderInstance3D` ni `mesh_lod`).
- **Ajustes de render fijos** en `project.godot`: MSAA 4×, sombras suaves en calidad alta, anisotrópico 8×, `rendering_method.mobile = "forward_plus"` (una línea sin efecto en escritorio que conviene limpiar). **No hay menú de gráficos**: `gui/options_menu/options_menu.gd` lo dice en su cabecera ("no graphics menu"); Opciones tiene Juego y HUD, Audio y Controles.
- Tras el plan 05 se suman: entorno con sombras PSSM de 4 cortes a 300 m, SSAO, glow, partículas del auto y de feedback, props en `MultiMesh`, desenfoque del scrim (plan 03).
- El tour ya puede imprimir draw calls y primitivas por captura (plan 05).

## 2. Objetivo y criterio de terminado

- **60 fps estables a 1080p con el preset Medio** en la máquina del usuario (RTX 3060), volando a 120 m con el auto en carrera y en la vista más cargada del tour (`05_stage_overview`).
- Terreno y vegetación por partes, con nivel de detalle según la distancia y sin cortes visibles.
- Colisión de árboles y rocas sin nodos por forma.
- Opciones > Gráficos con presets Bajo, Medio, Alto y Personalizado, aplicados en vivo y guardados.
- Un overlay de métricas con F3 para medir mientras se juega.

## 3. Decisiones de diseño

### Medir primero

Antes de tocar nada, correr el tour y una prueba en ventana con F3 (paso 1) y anotar en el propio plan (sección "Mediciones") fps, tiempo de frame, draw calls y primitivas en `05_stage_overview` y volando a 120 m. Todos los objetivos se comparan contra esa línea de base.

### Terreno por chunks

- `world/terrain_chunk.gd` (`TerrainChunk`): el terreno se divide en 8×8 chunks de 96 m (768 / 8), cada uno con dos mallas generadas del mismo heightmap: **LOD0** a resolución completa y **LOD1** con una de cada cuatro muestras (y bordes cosidos con faldones verticales de 2 m para que no se vean grietas).
- Cambio de nivel con `visibility_range_begin`/`visibility_range_end` y `visibility_range_fade_mode = SELF`: LOD0 hasta 220 m, LOD1 desde 200 m.
- LOD1 no proyecta sombras (`cast_shadow = OFF`); las sombras lejanas las cubre el último corte PSSM con LOD0 cercano.
- **El `HeightMapShape3D` único se mantiene** (colisión exacta, no cambia). `get_height()` y `get_road_distance()` siguen leyendo los mismos arrays.
- El color de vértice (tierra cerca del camino) se conserva por chunk.

### Vegetación y props por celdas

- `world/scatter_layer.gd` (`ScatterLayer`): reparte las transformaciones de cada tipo (troncos, copas de cada tipo, pasto, rocas, props) en celdas de 96 m, un `MultiMeshInstance3D` por celda y tipo.
- Dos mallas por tipo de árbol: la del plan 05 (cerca) y una simplificada (lejos: pino como un solo cono de 5 lados, frondoso como una esfera de 4 segmentos). Cerca hasta 250 m; lejos entre 230 y 900 m, sin sombras.
- Pasto solo hasta 120 m con `fade`. Props chicos (estacas, carteles) hasta 300 m.
- `tree_positions`, `find_clear_spot()` y las posiciones de los props no cambian: solo cambia cómo se agrupan para dibujar.

### Colisiones sin nodos

- `TreeColliders` y `RockColliders` siguen existiendo como `StaticBody3D` (así el sensor de choques y el puntaje ven el mismo objeto), pero las formas se agregan con `PhysicsServer3D.body_add_shape(body.get_rid(), shape.get_rid(), transform)` en lugar de un `CollisionShape3D` por forma. Las `Shape3D` se comparten entre árboles del mismo tamaño redondeado (cilindro y cono por escala cuantizada a 0,05).
- Se guarda una referencia a las `Shape3D` en el builder para que no se liberen.

### Sombras, efectos y ajustes de proyecto

- En Medio: `directional_shadow_max_distance = 220`, 4 cortes, atlas 4096; en Bajo: 150 m, 2 cortes, atlas 2048, SSAO y glow apagados.
- Quitar `renderer/rendering_method.mobile` de `project.godot`.
- El ruido del terreno ya viene de textura (plan 05); en LOD1 se usa una sola octava.

### Opciones > Gráficos

- `GameSettings.graphics_config` guardado en la sección `[graphics]` de `GameSettings.cfg` (el mismo archivo que ya aíslan los chequeos y el tour):

| Clave | Bajo | Medio | Alto |
|---|---|---|---|
| `shadow_quality` (0–3) | 1 | 2 | 3 |
| `shadow_distance` | 150 | 220 | 300 |
| `ssao` | no | sí | sí |
| `glow` | no | sí | sí |
| `sdfgi` | no | no | sí |
| `msaa` (0/2/4) | 0 | 2 | 4 |
| `taa` | no | no | no |
| `render_scale` | 0,75 | 1,0 | 1,0 |
| `vegetation_distance` | 0,6 | 1,0 | 1,3 (multiplica los rangos) |
| `scrim_blur` | no | sí | sí |
| `vsync` | sí | sí | sí |
| `fullscreen` | sí | sí | sí |
| `max_fps` | 0 (sin límite) | 0 | 0 |

- `GameSettings.apply_graphics()` aplica en vivo: `Viewport.msaa_3d`, `scaling_3d_scale`, `DisplayServer.window_set_vsync_mode`, `window_set_mode`, `Engine.max_fps`, y sobre el `Environment` compartido (`world/environment/rally_env.tres`) SSAO, glow y SDFGI; el sol y los `ScatterLayer`/`TerrainChunk` escuchan `graphics_updated` para sombras y distancias.
- Menú `gui/options_menu/graphics_menu.tscn/.gd` (`MenuScreen`) con el estilo del plan 03: selector de preset arriba; filas con `SliderRow`, `OptionButton` y `CheckButton`; cambiar una fila pasa el preset a Personalizado. Se agrega como tarjeta en el hub de Opciones.
- Primer arranque: preset Medio.

### Overlay de métricas

`debug/stats_overlay.gd` (autoload liviano o nodo agregado por `Stage` en builds de desarrollo): F3 muestra fps, tiempo de frame, draw calls, primitivas, objetos visibles, memoria de video, y el preset activo. Se oculta en exportaciones de release salvo que se active desde la línea de comandos (`-- --stats`).

## 4. Archivos

**Crear:** `world/terrain_chunk.gd`, `world/scatter_layer.gd`, `gui/options_menu/graphics_menu.tscn`, `gui/options_menu/graphics_menu.gd`, `debug/stats_overlay.gd`, `debug/headless_checks/check_performance.gd`.

**Modificar:** `world/stage_builder.gd` (chunks, scatter por celdas, colisiones por `PhysicsServer3D`), `world/props/tree_mesh.gd` (mallas lejanas), `world/props/prop_catalog.gd` (usar `ScatterLayer`), `world/environment/rally_env.tres`, `world/environment/rally_sun.tscn` (o su script) para escuchar los ajustes, `autoloads/game_settings.gd` (`graphics_config`, presets, `apply_graphics`, señal), `gui/options_menu/options_menu.gd/.tscn` (tarjeta Gráficos, quitar el comentario "no graphics menu"), `project.godot` (limpieza), `localization/translations.csv` (textos de Gráficos), `debug/tools/screenshot_tour.gd` (captura lejana y métricas), `debug/headless_checks/check_all.gd`, `README.md` del repo.

**Reutilizar:** `get_height()`, `_heights`, `_road_distance`, `_multimesh()` como base de `ScatterLayer`, `tree_positions`, las transformaciones del plan 05, el aislamiento de `GameSettings.cfg` en chequeos y tour.

## 5. Pasos

1. **Línea de base.** Overlay F3 y métricas del tour; anotar números en la sección "Mediciones" de este archivo.
2. **Chunks de terreno** con LOD0/LOD1 y faldones. Aserción de alturas idénticas.
3. **Scatter por celdas** con mallas cercanas y lejanas y pasto con distancia corta.
4. **Colisiones por `PhysicsServer3D`** para árboles y rocas.
5. **`graphics_config`**, presets y `apply_graphics()` en vivo.
6. **Menú Gráficos** en Opciones.
7. **Medir de nuevo** con el tour y con F3 volando; ajustar distancias y presets hasta cumplir el objetivo.
8. **Pruebas manuales** y actualización del README.

## 6. Verificación

**Deben seguir en verde:** `check_stage`, `check_car`, `check_drone`, `check_world_presentation` (plan 05: mismas `tree_positions` y props), `check_stage_info` (marcador y distancias), `check_flow` (plan 04: construcción asíncrona igual a la síncrona) y el resto.

**Chequeo nuevo `check_performance.gd`:**
- El terreno tiene 64 chunks y cada uno dos mallas con `visibility_range` configurado.
- `get_height()` en 20 puntos al azar da lo mismo que antes del cambio (hash guardado en el chequeo).
- `PhysicsServer3D.body_get_shape_count(TreeColliders)` es el doble de la cantidad de árboles, y `TreeColliders` no tiene hijos `CollisionShape3D`.
- Un rayo hacia abajo sobre un árbol conocido golpea su copa (la colisión sigue donde estaba).
- Las mallas lejanas de vegetación tienen `visibility_range_end` y `cast_shadow = OFF`.
- Guardar y cargar `graphics_config` en el directorio aislado conserva los valores; aplicar el preset Bajo cambia `get_viewport().msaa_3d` y apaga SSAO en el `Environment`.

**Tour de capturas:** imprimir draw calls y primitivas en cada captura; nueva `16_far_view_lod` desde 600 m de altura para revisar la transición de niveles; rehacer `05_stage_overview` y comparar con la del plan 05 (misma imagen salvo detalles lejanos).

**Pruebas manuales con el PS4 y F3:**
1. Preset Medio: volar a 120 m sobre el bosque con el auto en carrera; fps ≥ 60 sostenidos.
2. Recorrer a pie la zona de largada: sin saltos visibles al cambiar de nivel de detalle.
3. Cambiar de preset en vivo desde la pausa: el cambio se aplica sin reiniciar.
4. Preset Bajo y Alto: comparar fps y aspecto.
5. Reiniciar la etapa: la carga es más rápida que antes (anotar el tiempo en "Mediciones").
6. Chocar el dron contra un árbol: el choque se detecta igual que antes.

## 7. Riesgos y qué no tocar

- **No dividir el `HeightMapShape3D`** ni cambiar la `resolution` del terreno: la física y el aplanado del camino dependen de ellos.
- `tree_positions`, `find_clear_spot()` y las posiciones de los props deben dar exactamente lo mismo con chunks y celdas.
- El `CrashSensor` y el puntaje reconocen los obstáculos por el cuerpo y la capa: mantener `TreeColliders` y `RockColliders` como cuerpos en la capa `terrain`.
- Las formas creadas por código se liberan si nadie las referencia: guardarlas en el builder.
- El desenfoque del scrim y SDFGI quedan apagados en Bajo.
- `StageBuilder` es `@tool`: los chunks y celdas tienen que verse en el editor tras "Regenerar".

## Mediciones

(Completar al ejecutar el plan: línea de base y resultado final, con la misma captura y la misma ruta de vuelo.)

| Momento | Escena | fps | ms/frame | Draw calls | Primitivas | Carga de etapa |
|---|---|---|---|---|---|---|
| Antes | `05_stage_overview` | | | | | |
| Antes | Vuelo a 120 m | | | | | |
| Después (Medio) | `05_stage_overview` | | | | | |
| Después (Medio) | Vuelo a 120 m | | | | | |
