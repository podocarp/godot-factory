class_name Item
extends Resource
# Data for a pickable/stackable item. One .tres (or runtime instance) per item
# type; Inventory counts stacks, never duplicates the resource.

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
## Items with stackable=false occupy one slot each regardless of max_stack.
@export var stackable: bool = true
@export var max_stack: int = 99

func _init(p_id: String = "", p_name: String = "") -> void:
	id = p_id
	display_name = p_name
