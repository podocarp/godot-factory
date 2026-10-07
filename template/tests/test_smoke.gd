extends SceneTree
# Smoke test: prove headless sim + scene round-trip works.
# Convention: no assert() in tests — a failed assert in _init leaves SceneTree
# running until the harness timeout. Check explicitly, print FAIL, quit(1).

func _fail(msg: String) -> void:
	print("FAIL smoke: " + msg)
	quit(1)

func _init():
	# git does not track empty dirs — a fresh clone may lack res://levels/
	DirAccess.make_dir_recursive_absolute("res://levels")

	var root := Node2D.new()
	root.name = "Level"
	for i in 3:
		var m := Marker2D.new()
		m.name = "Spawn%d" % i
		m.position = Vector2(i * 10, 0)
		root.add_child(m)
		m.owner = root  # owner AFTER add_child — owner must be an in-tree ancestor
	var ps := PackedScene.new()
	if ps.pack(root) != OK:
		_fail("pack failed"); return
	if ResourceSaver.save(ps, "res://levels/_smoke.tscn") != OK:
		_fail("save failed"); return
	root.free()

	var loaded: PackedScene = load("res://levels/_smoke.tscn")
	if loaded == null:
		_fail("reload failed"); return
	var inst := loaded.instantiate()
	if inst.get_child_count() != 3:
		_fail("expected 3 children, got %d" % inst.get_child_count()); return
	inst.free()
	DirAccess.remove_absolute("res://levels/_smoke.tscn")
	print("PASS smoke: code-authored scene round-trips through PackedScene")
	quit(0)
