class_name InteractionSystem
extends Node
# Raycast-from-eye interaction: highlights the Interactable under the crosshair
# and fires `interacted(target)` on the "interact" action. Lives as a sibling of
# the player camera (see interaction_system.tscn); `eye` defaults to the
# viewport camera when unset.

signal interacted(target: Interactable)
signal highlight_changed(target: Interactable)

@export var player: Node3D
@export var eye: Camera3D
@export var range: float = 3.0
@export var action: StringName = &"interact"

var current: Interactable

func _physics_process(_delta: float) -> void:
	var hit := _cast()
	if hit != current:
		current = hit
		highlight_changed.emit(current)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(action):
		try_interact()

## Public so tests can trigger interact without Input actions.
func try_interact() -> bool:
	if current and current.interact(player):
		interacted.emit(current)
		return true
	return false

func _cast() -> Interactable:
	var cam := eye
	if cam == null and is_inside_tree():
		cam = get_viewport().get_camera_3d()
	if cam == null:
		return null
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * range
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = true
	var hit: Dictionary = get_viewport().world_3d.direct_space_state.intersect_ray(q)
	return _as_interactable(hit.get("collider"))

## Walk up from a collider (may be a child Area3D/shape) to the Interactable.
static func _as_interactable(node: Node) -> Interactable:
	while node:
		if node is Interactable:
			return node
		node = node.get_parent()
	return null
