class_name Inspect
extends RefCounted
# Semantic observation API (memo §5): compact JSON-serializable snapshots of a
# live scene tree, so agents observe game state as data instead of hand-rolled
# field pokes or pixels. Pair with SnapshotDiff for small change lists.
#
# Node state comes from a `snapshot()` method when the node implements one
# (game-specific, the richest source), else curated per-type properties.
# Events come from an opt-in EventBus recorder (record_events()); snapshots
# carry the events recorded so far, so diffing two snapshots yields the new
# events between them.

const DEFAULT_MAX_NODES := 256

static var _events: Array[String] = []
static var _bus: EventBus  # bus instance we recorded on (EventBus.reset() swaps it)

## Attach the event recorder to EventBus.bus(). Idempotent; call again after
## EventBus.reset() (the old bus and its connections are gone).
static func record_events() -> void:
	var bus := EventBus.bus()
	if bus == _bus:
		return
	_bus = bus
	bus.item_picked_up.connect(func(item: Item, count: int) -> void:
		_events.append("item_picked_up:%s x%d" % [item.id, count]))
	bus.interacted.connect(func(target: Node) -> void:
		_events.append("interacted:%s" % target.name))
	bus.trigger_fired.connect(func(event_name: String) -> void:
		_events.append("trigger_fired:%s" % event_name))
	bus.quest_updated.connect(func(quest_id: String, status: String) -> void:
		_events.append("quest_updated:%s=%s" % [quest_id, status]))
	bus.inventory_changed.connect(func(_slots: Array) -> void:
		_events.append("inventory_changed"))

## Clear the recorded event log (per-test isolation).
static func reset_events() -> void:
	_events.clear()

## Snapshot `root` (pass SceneTree.root). opts:
##   group: String       — only nodes in this group
##   type: String        — only nodes where is_type_of(type)
##   id_prefix: String   — only nodes whose entity_id (metadata, fallback: name) starts with it
##   max_nodes: int      — cap; sets "truncated": true when hit
static func snapshot(root: Node, opts: Dictionary = {}) -> Dictionary:
	var nodes: Array = []
	var complete := _walk(root, opts, nodes, int(opts.get("max_nodes", DEFAULT_MAX_NODES)))
	var tick := 0
	var tree := root.get_tree()
	if tree:
		var sd := tree.get_first_node_in_group("sim_driver") as SimDriver
		if sd:
			tick = sd.tick
	var out := {"tick": tick, "nodes": nodes, "events": _events.duplicate()}
	if not complete:
		out["truncated"] = true
	return out

## false when the cap was hit (caller sets the truncation flag).
static func _walk(node: Node, opts: Dictionary, out: Array, cap: int) -> bool:
	if _matches(node, opts):
		if out.size() >= cap:
			return false
		out.append(_entry(node))
	for c in node.get_children():
		if not _walk(c, opts, out, cap):
			return false
	return true

static func _matches(node: Node, opts: Dictionary) -> bool:
	if opts.has("group") and not node.is_in_group(String(opts["group"])):
		return false
	if opts.has("type") and not _is_type(node, String(opts["type"])):
		return false
	if opts.has("id_prefix") and not _id(node).begins_with(String(opts["id_prefix"])):
		return false
	return true

## type selector matches the exact class, any ancestor class, or the node's
## GDScript class_name (is_type_of is C++-only and ClassDB lacks script
## classes, so check get_script().get_global_name() too).
static func _is_type(node: Node, type: String) -> bool:
	var s: Script = node.get_script()
	if s != null and s.get_global_name() == type:
		return true
	var cls := node.get_class()
	while cls != "":
		if cls == type:
			return true
		cls = ClassDB.get_parent_class(cls)
	return false

static func _id(node: Node) -> String:
	# level_builder ids arrive as metadata; EntityRegistry renames nodes to ids.
	var m: Variant = node.get_meta("entity_id", "")
	return String(m) if m != "" else String(node.name)

static func _entry(node: Node) -> Dictionary:
	# Prefer the GDScript class_name (semantic: "Pickup" not "StaticBody3D").
	var type := node.get_class()
	var s: Script = node.get_script()
	if s != null and s.get_global_name() != "":
		type = String(s.get_global_name())
	var e := {"path": String(node.get_path()), "type": type, "state": _state(node)}
	var m: Variant = node.get_meta("entity_id", "")
	if m != "":
		e["id"] = String(m)
	return e

static func _state(node: Node) -> Dictionary:
	if node.has_method("snapshot"):
		var s = node.call("snapshot")
		return s if s is Dictionary else {"value": s}
	if node is Inventory:
		return node.to_dict()
	if node is Interactable:
		return {"prompt": node.prompt, "interactable": node.is_interactable()}
	if node is Control:
		var s := {"visible": node.visible, "enabled": UiQuery._enabled(node)}
		# separate `is` branches: GDScript narrows types per-branch, not across `or`
		if node is Label:
			s["text"] = node.text
		elif node is Button:
			s["text"] = node.text
		elif node is ProgressBar:
			s["value"] = node.value
		return s
	if node is Node3D:
		var p := (node as Node3D).global_position
		return {"pos": [p.x, p.y, p.z]}
	return {}
