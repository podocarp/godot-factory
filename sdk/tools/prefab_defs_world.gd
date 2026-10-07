class_name PrefabDefsWorld
extends RefCounted
# Node-tree builders for world/UI prefabs (interaction, inventory, HUD,
# pickup, trigger, dialogue), used by tools/build_prefabs.gd.

## Node factory: create, set props, parent, THEN own (owner must be an
## in-tree ancestor; build_prefabs re-owns everything to the packed root).
func _n(cls: String, parent: Node, props := {}) -> Node:
	var n: Node = ClassDB.instantiate(cls)
	for k in props:
		n.set(k, props[k])
	parent.add_child(n)
	n.owner = parent
	return n

func _script(node: Node, path: String) -> void:
	var s: Script = load(path)
	assert(s != null, "script failed to load: " + path)
	node.set_script(s)

## Tint a mesh so placeholders read distinctly in screenshots.
func _mesh(mesh: Mesh, mat_color: Color) -> Mesh:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = mat_color
	mesh.material = mat
	return mesh

func interaction_system() -> Node:
	var n := Node.new()
	n.name = "InteractionSystem"
	_script(n, "res://prefabs/interaction_system.gd")
	n.set("range", 3.0)
	return n

func inventory() -> Node:
	var n := Node.new()
	n.name = "Inventory"
	_script(n, "res://prefabs/inventory.gd")
	n.set("capacity", 10)
	n.add_to_group("inventory")  # group is packed into the scene
	return n

func ui_hud() -> Node:
	var hud := Control.new()
	hud.name = "UiHud"
	_script(hud, "res://prefabs/ui_hud.gd")
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	# unique_name_in_owner + test_id metadata: stable handles for tests/games.
	var health := _n("ProgressBar", hud, {"name": "HealthBar",
		"unique_name_in_owner": true, "show_percentage": false,
		"min_value": 0.0, "max_value": 1.0, "custom_minimum_size": Vector2(200, 16)})
	health.set_meta("test_id", "health_bar")
	health.position = Vector2(16, 16)
	var quests := _n("VBoxContainer", hud, {"name": "QuestList",
		"unique_name_in_owner": true})
	quests.set_meta("test_id", "quest_list")
	quests.position = Vector2(16, 48)
	var toast := _n("Label", hud, {"name": "ToastLabel", "unique_name_in_owner": true})
	toast.set_meta("test_id", "toast_label")
	toast.position = Vector2(16, 300)
	var cross := _n("Label", hud, {"name": "Crosshair",
		"unique_name_in_owner": true, "text": "+",
		"horizontal_alignment": HORIZONTAL_ALIGNMENT_CENTER,
		"vertical_alignment": VERTICAL_ALIGNMENT_CENTER})
	cross.set_meta("test_id", "crosshair")
	cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	return hud

func pickup() -> Node:
	var p := StaticBody3D.new()  # Interactable extends StaticBody3D
	p.name = "Pickup"
	_script(p, "res://prefabs/pickup.gd")
	var col := _n("CollisionShape3D", p, {"name": "Collision"})
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 0.4, 0.4)
	col.shape = box
	var mesh := _n("MeshInstance3D", p, {"name": "Visual"})
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 0.3, 0.3)
	mesh.mesh = _mesh(bm, Color(1.0, 0.8, 0.2))
	return p

func trigger_zone() -> Node:
	var z := Area3D.new()
	z.name = "TriggerZone"
	_script(z, "res://prefabs/trigger_zone.gd")
	var col := _n("CollisionShape3D", z, {"name": "Collision"})
	var box := BoxShape3D.new()
	box.size = Vector3(4, 3, 4)
	col.shape = box
	return z

func dialogue_box() -> Node:
	var d := Control.new()
	d.name = "DialogueBox"
	_script(d, "res://prefabs/dialogue_box.gd")
	d.visible = false
	d.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	d.offset_top = -160.0
	var panel := _n("PanelContainer", d, {"name": "Panel"})
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var col := _n("VBoxContainer", panel, {"name": "Column"})
	var speaker := _n("Label", col, {"name": "SpeakerLabel", "unique_name_in_owner": true})
	speaker.set_meta("test_id", "speaker")
	var text := _n("Label", col, {"name": "TextLabel", "unique_name_in_owner": true,
		"autowrap_mode": TextServer.AUTOWRAP_WORD_SMART})
	text.set_meta("test_id", "text")
	var choices := _n("VBoxContainer", col, {"name": "ChoiceList",
		"unique_name_in_owner": true})
	choices.set_meta("test_id", "choice_list")
	return d
