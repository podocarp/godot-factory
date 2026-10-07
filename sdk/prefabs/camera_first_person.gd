class_name FirstPersonLook
extends Camera3D
# Mouse-look for FPS rigs. Yaw is applied to the camera itself so a parent
# (player body) can own position; pitch is clamped to avoid flipping.

@export var sensitivity: float = 0.0025
## Pitch clamp in degrees up/down.
@export var pitch_limit_deg: float = 89.0

var pitch: float = 0.0
var yaw: float = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_look(event.relative.x, event.relative.y)

## Public so tests (and remapped-input games) can drive look without a mouse.
func apply_look(dx: float, dy: float) -> void:
	yaw -= dx * sensitivity
	pitch = clampf(pitch - dy * sensitivity,
		deg_to_rad(-pitch_limit_deg), deg_to_rad(pitch_limit_deg))
	rotation = Vector3(pitch, yaw, 0.0)
