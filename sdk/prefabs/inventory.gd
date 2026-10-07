class_name Inventory
extends Node
# Slot-based inventory data model. Items are Item resources; stackable ones
# merge up to max_stack, non-stackable take one slot each. Emits `changed` and
# EventBus.inventory_changed so HUD/tests can react without polling.

signal changed

@export var capacity: int = 10
## Optional registry mapping item id -> Item resource, used by add_item_id().
@export var item_db: Dictionary = {}

# Each slot: {item: Item, count: int}
var slots: Array[Dictionary] = []

func _init(p_capacity: int = 10) -> void:
	capacity = p_capacity

func add_item(item: Item, count: int = 1) -> int:
	# Returns the number ADDED; leftover > 0 means the inventory filled up.
	if item == null or count <= 0:
		return 0
	var added := 0
	if item.stackable:
		for slot in slots:
			if slot.item == item and slot.count < item.max_stack:
				var move: int = mini(count - added, item.max_stack - slot.count)
				slot.count += move
				added += move
				if added == count:
					break
	while added < count:
		if slots.size() >= capacity:
			break
		# New slot takes a full stack for stackable items, 1 otherwise.
		var take: int = mini(count - added, item.max_stack) if item.stackable else 1
		slots.append({"item": item, "count": take})
		added += take
	if added > 0:
		_notify()
	return added

func add_item_id(item_id: String, count: int = 1) -> int:
	var item: Item = item_db.get(item_id)
	if item == null:
		push_warning("Inventory: unknown item id '%s'" % item_id)
		return 0
	return add_item(item, count)

func remove_item(item: Item, count: int = 1) -> int:
	# Returns the number REMOVED (may be < count if not held).
	if item == null or count <= 0:
		return 0
	var removed := 0
	for i in range(slots.size() - 1, -1, -1):
		if removed == count:
			break
		var slot: Dictionary = slots[i]
		if slot.item != item:
			continue
		var take: int = mini(count - removed, slot.count)
		slot.count -= take
		removed += take
		if slot.count <= 0:
			slots.remove_at(i)
	if removed > 0:
		_notify()
	return removed

func count_of(item: Item) -> int:
	var n := 0
	for slot in slots:
		if slot.item == item:
			n += slot.count
	return n

func has_item(item: Item, count: int = 1) -> bool:
	return count_of(item) >= count

func clear() -> void:
	slots.clear()
	_notify()

func to_dict() -> Dictionary:
	var arr := []
	for slot in slots:
		arr.append({"id": slot.item.id, "count": slot.count})
	return {"capacity": capacity, "slots": arr}

## Rebuild from to_dict() output. `db` maps item id -> Item resource.
## Unknown ids are skipped with a warning (save files survive item removals).
static func from_dict(data: Dictionary, db: Dictionary) -> Inventory:
	var inv := Inventory.new(int(data.get("capacity", 10)))
	for entry in data.get("slots", []):
		var item: Item = db.get(String(entry.get("id", "")))
		if item == null:
			push_warning("Inventory.from_dict: unknown id '%s'" % entry.get("id"))
			continue
		inv.add_item(item, int(entry.get("count", 1)))
	return inv

func _notify() -> void:
	changed.emit()
	EventBus.bus().inventory_changed.emit(slots)
