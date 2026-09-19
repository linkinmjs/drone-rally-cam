## First-person pilot view: fixed to the frame and tilted up like a racing drone's camera, so
## the image leans with the drone (the gimbal view stays level). Angle and field of view come
## from Options > Drone. Wide rectilinear lens, no fisheye.
## Adapted from drone-simulator's FPVCamera (GPL-3.0).
class_name PilotCamera
extends Camera3D


func _ready() -> void:
	cull_mask &= ~(Gimbal.DRONE_BODY_LAYER | Player.VIEW_MODEL_LAYER)
	keep_aspect = Camera3D.KEEP_WIDTH
	var _discard := QuadSettings.settings_updated.connect(apply_quad_settings)
	apply_quad_settings()


func apply_quad_settings() -> void:
	transform.basis = Basis(Vector3.RIGHT, deg_to_rad(QuadSettings.angle))
	fov = clampf(QuadSettings.fov, 60.0, 120.0)


## Screen position of a world direction, for the HUD's real horizon. NAN when behind.
func project_direction(direction: Vector3) -> Vector2:
	return HUDDraw.project_direction(self, direction)
