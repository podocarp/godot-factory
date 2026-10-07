class_name Pickup
extends Interactable
# One-shot world pickup: on interact, adds its item to the player's inventory
# and hides itself. `is_interactable()` goes false so the interaction system
# stops highlighting it even before the queue-free frame ends.

@export var item: Item
@export var count: int = 1
## Where to look up an Inventory: node name/path under the player, or a node
## with class Inventory reachable from the player. Empty = search groups.
@export var inventory_path: NodePath = ^"Inventory"

var taken := false

func on_interact(player: Node) -> bool:
	if taken or item == null:
		return false
	var inv := _find_inventory(player)
	if inv == null:
		push_warning("Pickup: no Inventory found for player")
		return false
	if inv.add_item(item, count) == 0:
		return false  # inventory full: leave the pickup in the world
	taken = true
	visible = false
	# Disable collision so the ray stops hitting it.
	for c in get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", true)
	EventBus.bus().item_picked_up.emit(item, count)
	return true

func is_interactable() -> bool:
	return not taken

func _find_inventory(player: Node) -> Inventory:
	if player == null:
		return null
	var n := player.get_node_or_null(inventory_path)
	if n is Inventory:
		return n
	# Fallback: any Inventory in the tree (single-player assumption).
	var found := get_tree().get_first_node_in_group("inventory")
	return found as Inventory
