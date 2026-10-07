class_name LevelBuilder
extends RefCounted
# JSON level spec -> .tscn level, fully headless (FACTORY.md rule 1). Agents
# write a spec like:
#   {"name": "level_01", "entities": [
#      {"prefab": "res://prefabs/pickup.tscn", "id": "gem_1",
#       "transform": {"pos": [1, 0, -2], "rot_y": 1.57, "scale": [1, 1, 1]},
#       "params": {"prompt": "Take gem"}}]}
# then: LevelBuilder.new().build_from_file(spec, "res://levels/level_01.tscn").
#
# Params are applied with node.set(key, value); unknown keys are reported, not
# silently dropped, so spec typos surface in tests.

class BuildResult:
	extends RefCounted
	var ok := true
	var errors: Array[String] = []
	var root: Node

## Build from a parsed spec Dictionary. Returns BuildResult (never throws).
func build(spec: Dictionary) -> BuildResult:
	var res := BuildResult.new()
	var root := Node3D.new()
	root.name = String(spec.get("name", "Level"))
	for e in spec.get("entities", []):
		_place(root, e, res)
	res.root = root
	return res

func build_from_file(spec_path: String, out_path: String) -> BuildResult:
	var f := FileAccess.open(spec_path, FileAccess.READ)
	var res := BuildResult.new()
	if f == null:
		res.ok = false
		res.errors.append("cannot open spec: " + spec_path)
		return res
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is not Dictionary:
		res.ok = false
		res.errors.append("spec is not a JSON object")
		return res
	var built := build(parsed)
	if built.ok:
		var err := save(built.root, out_path)
		if err != OK:
			built.ok = false
			built.errors.append("save failed: %d" % err)
	built.root.free()
	return built

## Pack + save a built level root.
func save(root: Node, out_path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(out_path.get_base_dir()))
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		return err
	return ResourceSaver.save(ps, out_path)

func _place(root: Node, e: Dictionary, res: BuildResult) -> void:
	var id := String(e.get("id", ""))
	var prefab_path := String(e.get("prefab", ""))
	if id == "" or prefab_path == "":
		res.ok = false
		res.errors.append("entity needs 'id' and 'prefab': %s" % e)
		return
	var ps: PackedScene = load(prefab_path)
	if ps == null:
		res.ok = false
		res.errors.append("prefab not found: " + prefab_path)
		return
	var node := ps.instantiate()
	node.name = id  # stable name == spec id (EntityRegistry convention)
	root.add_child(node)
	node.owner = root  # owner AFTER add_child
	_apply_transform(node, e.get("transform", {}))
	for k in e.get("params", {}):
		if _has_property(node, k):
			node.set(k, e["params"][k])
		else:
			res.errors.append("%s: unknown param '%s'" % [id, k])
			# Not fatal: games may extend prefabs; but it's surfaced.

func _apply_transform(node: Node3D, t: Dictionary) -> void:
	if t.has("pos"):
		node.position = _vec3(t["pos"])
	if t.has("rot_y"):
		node.rotation.y = float(t["rot_y"])
	if t.has("scale"):
		node.scale = _vec3(t["scale"])

static func _vec3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a.size() >= 3 else Vector3.ONE

static func _has_property(node: Node, key: String) -> bool:
	for p in node.get_property_list():
		if p.name == key:
			return true
	return false
