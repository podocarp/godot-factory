extends SceneTree
# Code-authored prefab generator — the canonical example of FACTORY.md rule 1:
# build Node trees in GDScript, set `owner` AFTER add_child, PackedScene.pack(),
# ResourceSaver.save(). Run: godot --headless --path sdk --script res://tools/build_prefabs.gd
# Generated .tscn files under prefabs/ are reviewable output, never hand-edited.
# Node-tree builders live in prefab_defs_actors.gd / prefab_defs_world.gd.

const OUT := "res://prefabs/"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var actors := PrefabDefsActors.new()
	var world := PrefabDefsWorld.new()
	_build("camera_first_person.tscn", actors.camera_first_person())
	_build("camera_third_person.tscn", actors.camera_third_person())
	_build("player_first_person.tscn", actors.player_first_person())
	_build("player_third_person.tscn", actors.player_third_person())
	_build("interaction_system.tscn", world.interaction_system())
	_build("inventory.tscn", world.inventory())
	_build("ui_hud.tscn", world.ui_hud())
	_build("pickup.tscn", world.pickup())
	_build("trigger_zone.tscn", world.trigger_zone())
	_build("dialogue_box.tscn", world.dialogue_box())
	print("PASS build_prefabs: 10 prefabs written to " + OUT)
	quit(0)

func _build(file: String, root: Node) -> void:
	_own_all(root, root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	assert(err == OK, "pack %s: %d" % [file, err])
	err = ResourceSaver.save(ps, OUT + file)
	assert(err == OK, "save %s: %d" % [file, err])
	root.free()

## Set EVERY descendant's owner to the packed root. Containers must NOT own
## their children: PackedScene.pack() silently strips children owned by a
## container node, and root-owned descendants keep unique_name_in_owner (%)
## lookups working at any depth.
func _own_all(root: Node, node: Node) -> void:
	for c in node.get_children():
		c.owner = root
		_own_all(root, c)
