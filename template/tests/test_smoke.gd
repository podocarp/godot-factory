extends SceneTree
# Smoke test: prove headless sim + scene round-trip works.

func _init():
	var root := Node2D.new()
	root.name = "Level"
	for i in 3:
		var m := Marker2D.new()
		m.name = "Spawn%d" % i
		m.position = Vector2(i * 10, 0)
		root.add_child(m)
		m.owner = root  # owner AFTER add_child — owner must be an in-tree ancestor
	var ps := PackedScene.new()
	var err := ps.pack(root)
	assert(err == OK, "pack failed")
	err = ResourceSaver.save(ps, "res://levels/_smoke.tscn")
	assert(err == OK, "save failed")
	root.free()

	var loaded: PackedScene = load("res://levels/_smoke.tscn")
	assert(loaded != null, "reload failed")
	var inst := loaded.instantiate()
	assert(inst.get_child_count() == 3, "expected 3 children, got %d" % inst.get_child_count())
	inst.free()
	DirAccess.remove_absolute("res://levels/_smoke.tscn")
	print("PASS smoke: code-authored scene round-trips through PackedScene")
	quit(0)
