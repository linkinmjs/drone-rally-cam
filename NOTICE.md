# Avisos de origen

Drone Rally Cam es una obra derivada de **GodotDrone**, © Cykyrios, distribuida bajo la GNU General Public License v3.0 (https://github.com/Cykyrios/GodotDrone). El código llegó a este proyecto a través de [drone-simulator](https://github.com/linkinmjs/drone-simulator), la adaptación de GodotDrone a Godot 4.7. Todo el juego se distribuye bajo la misma licencia; ver [LICENSE](LICENSE).

## Archivos tomados del original sin cambios

- `godot/drone/{frame,motor,propeller,pid,controller_action,led}.gd` y `godot/drone/led.tscn`
- `godot/drone/flight_controller/flight_command.gd`
- `godot/drone/flight_controller/flight_mode/flight_mode_{acro,horizon,launch,turtle}.gd`
- `godot/drone/drones/drone1.tscn` y `godot/drone/parts/propellers/*`
- `godot/asset_import/import_drone_parts.gd`
- `godot/debug/cameras/{follow_camera,flyaround_camera}.{gd,tscn}`
- Modelos: `godot/Assets/Drones/Parts/` (Frame1, Motor1, Propeller1)
- Sonidos de motores: `godot/Assets/Audio/SFX/Propellers/*.wav`, tal como vienen en el repositorio original
- Textura de grilla: `godot/Assets/grid_material.tres` y `godot/Assets/grid_texture.png`

## Archivos modificados (2026)

Cada uno lleva un comentario al principio que describe el cambio.

- `godot/drone/drone.gd`: sin HUD, carreras ni checkpoints. Configuración exportada en lugar de `QuadSettings`. Agrega guardado y despliegue del dron y la altura sobre el suelo.
- `godot/drone/flight_controller/flight_controller.gd`: modo por defecto configurable, captura de objetivos y rumbo al armar, armado con acelerador centrado en los modos con retención, ciclo fijo de modos, límite de potencia por batería, bloqueo de armado, autodesarme al aterrizar, reinicio de integrales en el suelo y regreso automático desde la recuperación.
- `godot/drone/flight_controller/flight_mode/flight_mode.gd`, `flight_mode_speed.gd` y `flight_mode_track.gd`: acelerador de reposo, sticks relativos al rumbo y aterrizaje suave.
- `godot/drone/flight_controller/flight_mode/flight_mode_recover.gd`: se nivela manteniendo la altura en lugar de descender a 5 m/s, y solo desarma volcado en el suelo.
- `godot/drone/flight_controller/flight_state.gd`: distancia al suelo.
- `godot/drone/control_profile.gd`: ahora es un `Resource`.
- `godot/drone/radio_controller.gd`: se puede desactivar, tiene zona muerta y admite el mouse como stick.
- `godot/autoloads/controls.gd`: sin dependencia de `Global`, conserva los atajos de teclado y agrega las acciones del juego.
- `godot/drone/battery.gd`: reescrito. El original estaba sin implementar.

El resto del código y los recursos son originales de Drone Rally Cam.
