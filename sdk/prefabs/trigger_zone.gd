class_name TriggerZone
extends Area3D
# Volume that fires a named event when a body enters. `once` (default) latches
# after the first fire so walking back and forth doesn't retrigger quests.

signal fired(event_name: String)

@export var event_name: String = ""
@export var once: bool = true

var fired_count: int = 0
var _inside := 0  # reference count: overlapping bodies must not double-fire

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_body_entered)
	area_exited.connect(_on_body_exited)

func _on_body_entered(_node: Node3D) -> void:
	_inside += 1
	if once and fired_count > 0:
		return
	fired_count += 1
	fired.emit(event_name)
	EventBus.bus().trigger_fired.emit(event_name)

func _on_body_exited(_node: Node3D) -> void:
	_inside = maxi(0, _inside - 1)

func reset() -> void:
	fired_count = 0
