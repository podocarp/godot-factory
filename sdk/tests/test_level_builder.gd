extends SceneTree
# LevelBuilder: JSON spec -> .tscn -> reload, asserting ids, transforms, params.

const SPEC := """
{
	"name": "test_level",
	"entities": [
		{"prefab": "res://prefabs/pickup.tscn", "id": "gem_1",
		 "transform": {"pos": [1.5, 0.5, -2.0], "rot_y": 1.5708, "scale": [2, 2, 2]},
		 "params": {"prompt": "Take gem", "cooldown": 0.5}},
		{"prefab": "res://prefabs/trigger_zone.tscn", "id": "gate_zone",
		 "transform": {"pos": [0, 0, 0]},
		 "params": {"event_name": "gate_open", "once": false}},
		{"prefab": "res://prefabs/player_third_person.tscn", "id": "player_1",
		 "transform": {"pos": [0, 1, 0], "rot_y": 3.14}}
	]
}
"""

const SPEC_PATH := "res://tests/_spec.json"
const OUT_PATH := "res://levels/_test_level.tscn"

func _init() -> void:
	var err := _run()
	DirAccess.remove_absolute(SPEC_PATH)
	DirAccess.remove_absolute(OUT_PATH)
	if err == "":
		print("PASS level_builder: spec -> tscn -> reload keeps ids/transforms/params")
		quit(0)
	else:
		print("FAIL level_builder: " + err)
		quit(1)

func _run() -> String:
	var f := FileAccess.open(SPEC_PATH, FileAccess.WRITE)
	f.store_string(SPEC)
	f.close()
	var res := LevelBuilder.new().build_from_file(SPEC_PATH, OUT_PATH)
	if not res.ok:
		return "build failed: " + str(res.errors)
	var ps: PackedScene = load(OUT_PATH)
	if ps == null:
		return "saved level will not load"
	var level := ps.instantiate()
	if String(level.name) != "test_level":
		return "level name wrong: " + str(level.name)
	if level.get_child_count() != 3:
		return "expected 3 entities, got %d" % level.get_child_count()
	# Ids become stable node names.
	for id in ["gem_1", "gate_zone", "player_1"]:
		if level.get_node_or_null(NodePath(id)) == null:
			return "missing entity '" + id + "'"
	# Transforms survived the round-trip.
	var gem := level.get_node("gem_1") as Node3D
	if gem.position.distance_to(Vector3(1.5, 0.5, -2.0)) > 1e-4:
		return "gem pos wrong: " + str(gem.position)
	if not is_equal_approx(gem.rotation.y, 1.5708):
		return "gem rot_y wrong: %f" % gem.rotation.y
	if not is_equal_approx(gem.scale.x, 2.0):
		return "gem scale wrong: " + str(gem.scale)
	# Params applied via node.set() and persisted.
	if gem.prompt != "Take gem" or not is_equal_approx(gem.cooldown, 0.5):
		return "gem params wrong"
	var zone := level.get_node("gate_zone") as TriggerZone
	if zone.event_name != "gate_open" or zone.once:
		return "zone params wrong"
	# Unknown params are surfaced as errors, not silently dropped.
	var bad := LevelBuilder.new().build({"entities": [
		{"prefab": "res://prefabs/pickup.tscn", "id": "x",
		 "params": {"not_a_real_param": 1}}]})
	var found := false
	for e in bad.errors:
		if e.contains("not_a_real_param"):
			found = true
	bad.root.free()
	if not found:
		return "unknown param not reported"
	level.free()
	return ""
