# Plan 06 — Audio

Depende de: 05 (el nodo `StageFeedback` y el stub `Audio.play_event` que ese plan deja declarados). Si el plan 04 ya está hecho, también suma la música del título.

## 1. Contexto y diagnóstico

Rutas relativas a `godot/`.

- **Buses:** `default_bus_layout.tres` tiene `Master`, `Motors`, `Car` y `UI`, **sin ningún efecto** (ni limitador, ni reverb, ni filtros).
- **Archivos de audio:** 13 en total. Ocho de motores de dron (`Assets/Audio/SFX/Propellers/idle.wav`, `motor1.wav` … `motor7.wav`, heredados de GodotDrone) y cinco de UI (`Assets/Audio/UI/*.wav`, que el plan 03 regenera).
- **Motores del dron:** cada `Motor` crea 8 `AudioStreamPlayer` **no posicionales** en el bus `Motors` y hace crossfade entre dos según las RPM (`drone/motor.gd:36-64`); con cuatro motores son 32 reproductores. La atenuación por distancia es un truco en `Stage._update_motor_volume()` (`game/stage.gd:205-214`), que baja el volumen del bus entero según la distancia de la cámara al dron.
- **Auto:** motor procedural en `car/engine_audio.gd` (generador por muestra, 6 marchas, ruido de ripio, Doppler) en un `AudioStreamPlayer3D` del bus `Car`. Funciona bien.
- **Radio:** solo texto; el único sonido es `UI.play("tick")` a 10 y 5 s de la llegada del auto (`ui/radio_feed.gd:83`), el mismo clic de los menús.
- **Faltan por completo:** ambiente (viento, pájaros), pasos, maleta, armado y desarmado, inicio y fin de grabación, aviso de batería, choque, estática y voz de radio, música o fondo sonoro del título, y cualquier diferencia de mezcla entre jugar y estar en pausa.
- `autoloads/audio.gd` guarda `master_volume`, `motors_volume`, `car_volume`, `ui_volume` y `muted` en `user://config/Audio.cfg`; `gui/options_menu/audio_menu.*` tiene una fila por volumen.
- Tras el plan 05, `game/stage_feedback.gd` llama a `Audio.play_event(&"id", posición)` para cada evento, y `EventBus` tiene `player_step(surface)`, `case_opened` y `case_closed`.

## 2. Objetivo y criterio de terminado

- El tramo suena vivo: viento que cambia con la altura, pájaros esporádicos, pasos sobre pasto y ripio, la maleta al abrir y cerrar.
- El dron tiene sonidos de armado y desarmado, inicio y fin de grabación, aviso de batería baja y agotada, y choque; sus motores suenan desde donde está el dron.
- La radio suena como radio: estática al abrir, un "chatter" breve en cada anuncio y beeps propios en la cuenta regresiva.
- En pausa todo se amortigua; al reanudar vuelve.
- Opciones > Audio controla Master, Motores, Auto, Ambiente, Efectos, Radio, Interfaz y Silencio.
- Todo el audio se genera en el repo (sin descargas).

## 3. Decisiones de diseño

### Buses

| Bus | Envía a | Efectos |
|---|---|---|
| `Master` | — | `AudioEffectLimiter` (techo −1 dB) |
| `Motors` | `Master` | `AudioEffectLowPassFilter` (apagado; se activa en pausa) |
| `Car` | `Master` | `AudioEffectLowPassFilter` (ídem) |
| `Ambient` (nuevo) | `Master` | `AudioEffectLowPassFilter` (ídem) |
| `SFX` (nuevo) | `Master` | — |
| `Radio` (nuevo) | `Master` | `AudioEffectBandPassFilter` (300–3400 Hz) + `AudioEffectDistortion` leve |
| `UI` | `Master` | — |

### Sonidos generados offline

`debug/tools/build_sfx.gd` (script de `SceneTree`, como `build_theme.gd`) sintetiza cada sonido como `AudioStreamWAV` de 22 050 Hz mono y lo guarda con `save_to_wav` en `Assets/Audio/SFX/generated/`. Los parámetros viven en una tabla al principio del script para poder retocarlos y regenerar.

| Id | Receta | Bus |
|---|---|---|
| `wind_loop` | Ruido rosa filtrado paso bajo con LFO lento de volumen y de corte, 12 s, loop sin corte | Ambient |
| `birds_1..3` | Chirridos FM cortos (2–4 notas, 2–5 kHz) | Ambient |
| `step_grass_1..4` | Ruido filtrado con envolvente corta y grave | SFX |
| `step_gravel_1..4` | Ruido con transitorios granulares | SFX |
| `case_open` / `case_close` | Clic metálico (dos transitorios) + roce | SFX |
| `arm` / `disarm` | Tres tonos ascendentes / descendentes tipo ESC | SFX |
| `rec_start` / `rec_stop` | Beep 1,2 kHz / doble beep 1,6 kHz | SFX |
| `battery_low` | Triple beep 880 Hz | SFX |
| `battery_empty` | Tono descendente largo | SFX |
| `crash` | Golpe grave + ráfaga de ruido + rebote de plástico | SFX |
| `radio_open` | Ráfaga de estática con clic de squelch | Radio |
| `radio_chatter_1..3` | Ruido con envolvente silábica (formantes simples), 0,8–1,5 s | Radio |
| `radio_beep` | Beep de cuenta regresiva | Radio |
| `title_pad` | Pad de 60 s (acordes lentos de senos con detune) en loop | Ambient |

### API de `Audio`

```gdscript
func play_event(id: StringName, position := Vector3.INF) -> void
func set_ambient_intensity(value: float) -> void  # 0..1, viento
func duck(enabled: bool) -> void                  # filtros de pausa
```

- Tabla `EVENTS` en `autoloads/audio.gd`: id → `{paths: Array[String], bus, volume_db, pitch_jitter, positional}`. Si hay varias rutas, elige una al azar sin repetir la última.
- Pool de 8 `AudioStreamPlayer3D` y 4 `AudioStreamPlayer` creados en `_ready` sin reproducir nada. Si el pool está lleno, se reemplaza el más viejo.
- `duck(true)` activa los paso bajo de `Motors`, `Car` y `Ambient` (corte 700 Hz) y baja 6 dB `Ambient`; `Stage` lo llama al abrir la pausa y los resultados, y `duck(false)` al reanudar.
- `audio_settings` suma `ambient_volume`, `sfx_volume` y `radio_volume` (valores por defecto 0,8; 1,0; 0,9) y `update_volumes()` los aplica.

### Motores del dron

- Se agrega `drone/drone_audio.gd` (nodo `DroneAudio` hijo del dron): **un** banco de 8 `AudioStreamPlayer3D` en el centro del dron, con el mismo crossfade por RPM que hoy hace `Motor`, usando el promedio de las cuatro RPM. `unit_size` y `max_distance` ajustados para que se oiga a 60–80 m.
- `drone/motor.gd` gana `@export var own_audio := true`; `rally_drone.tscn` lo pone en `false` en los cuatro motores. La física del motor no se toca.
- `Stage._update_motor_volume()` se elimina: la atenuación la hace el `AudioStreamPlayer3D`. Para que el piloto siempre oiga su dron, mientras se pilotea `DroneAudio` sube un "piso" de volumen (equivalente al actual de −14 dB) con un segundo `AudioStreamPlayer` no posicional muy bajo que se mezcla según la distancia.

### Ambiente y radio

- Un `AudioStreamPlayer` de viento en loop en el bus `Ambient`; `Stage` actualiza `Audio.set_ambient_intensity()` con la altura de la cámara activa (más viento arriba) y un poco de variación lenta.
- Pájaros: cada 6–15 s, un `birds_*` en una posición al azar a 30–80 m de la cámara, en un árbol de `tree_positions`.
- `RadioFeed.announce()` reproduce `radio_open` + un `radio_chatter_*`; la cuenta regresiva usa `radio_beep` en lugar de `UI.play("tick")`.
- Pasos: `StageFeedback` recibe `player_step(surface)` y llama `play_event(&"step_gravel")` o `&"step_grass"` en la posición de los pies.

### Opciones > Audio

Filas nuevas: Ambiente, Efectos, Radio (además de Master, Motores, Auto, Interfaz, Silencio). Con el estilo `SliderRow` del plan 03 y la navegación L1/R1 del plan 01.

## 4. Archivos

**Crear:** `debug/tools/build_sfx.gd`, `Assets/Audio/SFX/generated/*.wav` (generados), `drone/drone_audio.gd`, `debug/headless_checks/check_audio.gd`.

**Modificar:** `default_bus_layout.tres`, `autoloads/audio.gd`, `autoloads/event_bus.gd` (si falta alguna señal), `drone/motor.gd` (`own_audio`), `drone/drones/rally_drone.tscn` (`DroneAudio`, `own_audio = false`), `game/stage.gd` (quitar `_update_motor_volume`, `duck`, intensidad del viento, pájaros), `game/stage_feedback.gd` (ids definitivos), `ui/radio_feed.gd`, `gui/options_menu/audio_menu.tscn/.gd`, `gui/front/title_screen.gd` (pad del título, si existe), `localization/translations.csv` (`AUD_AMBIENT`, `AUD_SFX`, `AUD_RADIO`), `debug/headless_checks/check_all.gd`.

**Reutilizar:** el crossfade de `drone/motor.gd`, `car/engine_audio.gd` tal cual (solo verificar su bus), `StageFeedback`, `EventBus`, `tree_positions`.

## 5. Pasos

1. **Buses y efectos** en `default_bus_layout.tres`; `Audio.update_volumes()` con los buses nuevos.
2. **Generador de SFX** y los WAV. Escuchar cada uno y ajustar la tabla.
3. **`Audio.play_event`**, pool y tabla `EVENTS`; `StageFeedback` pasa a usar ids reales.
4. **Motores posicionales** con `DroneAudio`; quitar el truco de volumen del bus.
5. **Ambiente:** viento por altura y pájaros.
6. **Radio:** estática, chatter y beeps propios.
7. **Amortiguación en pausa y resultados.**
8. **Opciones > Audio** con las filas nuevas.
9. **Chequeo nuevo y pruebas manuales.**

## 6. Verificación

**Deben seguir en verde:** `check_gui` (menú de Audio), `check_drone` (los motores siguen funcionando sin sus reproductores propios), `check_stage`, `check_settings` y el resto. `check_all` mantiene la espera de 300 ms entre chequeos para que el hilo de audio libere los streams.

**Chequeo nuevo `check_audio.gd`:**
- Existen los buses `Ambient`, `SFX` y `Radio`, y `Master` tiene un limitador.
- Todos los ids de `Audio.EVENTS` apuntan a archivos que existen, duran más de 20 ms y cargan como `AudioStreamWAV`.
- 20 llamadas seguidas a `play_event` con posición dejan como máximo 8 reproductores 3D activos.
- `Audio.duck(true)` activa el paso bajo de `Motors`, `Car` y `Ambient`; `duck(false)` lo desactiva. Abrir la pausa de una etapa activa el `duck`.
- Guardar y cargar `ambient_volume`, `sfx_volume` y `radio_volume` en el directorio aislado conserva los valores.
- El dron instanciado tiene un `DroneAudio` con 8 `AudioStreamPlayer3D` y sus `Motor` no crearon reproductores propios.

**Tour de capturas:** sin capturas nuevas (el audio no se ve); verificar que el tour sigue corriendo sin errores de audio en la consola.

**Pruebas manuales con el PS4 (con auriculares):**
1. Caminar por pasto y por el camino: pasos distintos.
2. Abrir y cerrar la maleta.
3. Armar, desarmar, empezar y terminar una grabación.
4. Subir a 60 m: el viento crece; bajar: se calma.
5. Esperar al auto: radio con estática y chatter en la largada y en cada parcial; beeps a 10 y 5 s.
6. Alejarse caminando del dron en vuelo: el motor se oye desde su posición.
7. Pausar: todo se apaga como detrás de una pared; reanudar vuelve.
8. Dejar que la batería llegue a baja y a vacía; chocar el dron.
9. Mover cada volumen de Opciones > Audio y comprobar que afecta lo suyo.

## 7. Riesgos y qué no tocar

- **No tocar** la física de `drone/motor.gd` (empuje, RPM, par): solo la creación de sus reproductores.
- `car/engine_audio.gd` se deja como está; solo se confirma su bus.
- **Nada se reproduce en `_ready` de los autoloads**: los chequeos corren headless y el pool se crea sin sonar.
- Los WAV generados se versionan en el repo: mantenerlos cortos (el loop de viento de 12 s mono a 22 kHz pesa unos 530 KB; el pad del título, unos 2,6 MB; si pesa demasiado, bajar a 30 s).
- El distorsionador de la radio puede saturar con volúmenes altos: el limitador de `Master` lo contiene, pero revisar a oído.
