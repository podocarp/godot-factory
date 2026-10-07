class_name EntityRegistry
extends Node
# id -> Node lookup with stable names. Levels built by level_builder.gd name
# their entities by spec id; games resolve them here instead of deep get_node
# paths, so scene structure can change without breaking gameplay code.
#
# Entries are WeakRefs: a freed entity must never leave a dangling pointer
# (freeing a node while a hard reference is held corrupts the heap in 4.7),
# and there is no reliable "node was freed" signal — tree_exiting only fires
# on removal, not free(). Dead refs are pruned lazily on access.

var _entries: Dictionary = {}  # id -> WeakRef

func register(entity: Node, id: String) -> bool:
	if entity == null or id == "":
		return false
	if has_entity(id):
		push_warning("EntityRegistry: duplicate id '%s' ignored" % id)
		return false
	# Stable names: tests and code address entities by id, not by tree path.
	if String(entity.name) != id:
		entity.name = id
	_entries[id] = weakref(entity)
	return true

func get_entity(id: String) -> Node:
	var ref: WeakRef = _entries.get(id)
	if ref == null:
		return null
	var node := ref.get_ref() as Node
	if node == null:
		_entries.erase(id)  # entity was freed: prune now
	return node

func has_entity(id: String) -> bool:
	return get_entity(id) != null

func unregister(id: String) -> void:
	_entries.erase(id)

func ids() -> Array:
	var out: Array = []
	for id in _entries.keys():
		if has_entity(id):
			out.append(id)
	return out
