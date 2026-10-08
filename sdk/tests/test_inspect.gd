extends SceneTree
# Tests for the semantic inspection API: Inspect.snapshot (selectors, cap,
# snapshot() hook) + SnapshotDiff (exact change list). Headless conventions
# per sdk/README: run on first frame, EventBus.reset() before quit.

var _fails := 0

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	Inspect.record_events()
	_test_snapshot_and_diff()
	_test_selectors_and_cap()
	Inspect.reset_events()
	EventBus.reset()
	quit(0 if _fails == 0 else 1)

func _report(name: String, err: String) -> void:
	if err == "":
		print("PASS inspect: " + name)
	else:
		print("FAIL inspect %s: %s" % [name, err])
		_fails += 1

# A node implementing snapshot(): Inspect must prefer it over properties.
class Probe extends Node3D:
	var charge := 0
	func snapshot() -> Dictionary:
		return {"charge": charge}

func _build_world() -> Dictionary:
	# root-ish container with 2 Interactables (Pickup) + Inventory, like a mini level.
	var w := Node.new()
	w.name = "World"
	var gem := Item.new("gem", "Gem")
	var p1: Pickup = load("res://prefabs/pickup.tscn").instantiate()
	p1.name = "gem_1"
	p1.item = gem
	p1.set_meta("entity_id", "gem_1")
	var p2: Pickup = load("res://prefabs/pickup.tscn").instantiate()
	p2.name = "gem_2"
	p2.item = gem
	p2.set_meta("entity_id", "gem_2")
	var inv := Inventory.new(5)
	inv.name = "Inventory"
	inv.add_item(gem, 2)
	w.add_child(p1)
	w.add_child(p2)
	w.add_child(inv)
	root.add_child(w)
	return {"w": w, "p1": p1, "inv": inv, "gem": gem}

func _test_snapshot_and_diff() -> void:
	var world := _build_world()
	var w: Node = world["w"]
	var err := ""
	var s1 := Inspect.snapshot(w)
	# exact structure: 2 id'd entities + inventory (+ pickup collision/mesh kids),
	# inventory state from to_dict()
	if s1.get("truncated") != null:
		err = "unexpected truncated flag"
	var id_count := 0
	for n in s1["nodes"]:
		if n.has("id"):
			id_count += 1
	if id_count != 2:
		err = "expected 2 id'd entities, got %d of %d" % [id_count, s1["nodes"].size()]
	var inv_entry: Dictionary = {}
	for n in s1["nodes"]:
		if n.get("id", "") == "gem_1":
			if n["type"] != "Pickup":
				err = "gem_1 type %s" % n["type"]
		if n["path"].ends_with("Inventory"):
			inv_entry = n
	if inv_entry == null or inv_entry["state"].get("slots", []) != [{"id": "gem", "count": 2}]:
		err = "inventory state wrong: %s" % str(inv_entry)
	# mutate: take gem_1 into the inventory (group fallback finds it), then diff
	world["inv"].add_to_group("inventory")
	var p1: Pickup = world["p1"]
	var dummy := Node3D.new()  # player stand-in: no Inventory child -> group fallback
	if not p1.on_interact(dummy):
		err = "pickup on_interact failed"
	dummy.free()
	var s2 := Inspect.snapshot(w)
	var d := SnapshotDiff.diff(s1, s2)
	# exact change list: inventory slots changed, gem_1 interactable flipped,
	# events grew (item_picked_up and/or inventory_changed recorded)
	var changed_keys := {}
	for c in d["changed"]:
		changed_keys["%s|%s" % [c["path"].get_file(), c["key"]]] = c
	if d["added"] != [] or d["removed"] != []:
		err = "unexpected add/remove: %s" % str(d)
	if not changed_keys.has("Inventory|slots"):
		err = "inventory change missing: %s" % str(d["changed"])
	else:
		var c = changed_keys["Inventory|slots"]
		# diff is per state-key: old/new are the slot arrays themselves
		if c["old"] != [{"id": "gem", "count": 2}]:
			err = "diff old value wrong: %s" % str(c)
		if (c["new"] as Array).is_empty():
			err = "diff new value empty"
	if not changed_keys.has("gem_1|interactable"):
		err = "gem_1 interactable flip missing (taken=%s): %s" % [world["p1"].taken, str(d["changed"])]
	if d["new_events"].is_empty():
		err = "no new events recorded: %s" % str(d)
	if SnapshotDiff.is_empty(d):
		err = "is_empty true on a real diff"
	root.remove_child(w)
	w.free()
	_report("snapshot + exact diff", err)

func _test_selectors_and_cap() -> void:
	var world := _build_world()
	var w: Node = world["w"]
	var err := ""
	# by entity_id prefix
	var only_gems := Inspect.snapshot(w, {"id_prefix": "gem_"})
	if only_gems["nodes"].size() != 2:
		err = "id_prefix got %d" % only_gems["nodes"].size()
	# by type
	var only_inv := Inspect.snapshot(w, {"type": "Inventory"})
	if only_inv["nodes"].size() != 1 or only_inv["nodes"][0]["type"] != "Inventory":
		err = "type filter got %s" % str(only_inv["nodes"])
	# by group
	(world["inv"] as Inventory).add_to_group("inventory")
	var by_group := Inspect.snapshot(w, {"group": "inventory"})
	if by_group["nodes"].size() != 1:
		err = "group filter got %d" % by_group["nodes"].size()
	# cap + truncation flag
	var capped := Inspect.snapshot(w, {"max_nodes": 2})
	if capped["nodes"].size() != 2 or capped.get("truncated") != true:
		err = "cap/truncation wrong: %s" % str(capped)
	# snapshot() hook preference (get_class() reports Node3D for GDScript
	# subclasses, so select the probe by id, not by script class name)
	var probe := Probe.new()
	probe.name = "Probe"
	w.add_child(probe)
	var sp := Inspect.snapshot(w, {"id_prefix": "Probe"})
	if sp["nodes"].size() != 1 or sp["nodes"][0]["state"] != {"charge": 0}:
		err = "snapshot() hook not used: %s" % str(sp["nodes"])
	root.remove_child(w)
	w.free()
	_report("selectors, cap, snapshot() hook", err)
