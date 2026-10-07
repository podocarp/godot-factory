extends SceneTree
# Prefab round-trip: every .tscn loads, instantiates, keeps its script,
# exported params, and stable test handles (unique_name_in_owner + test_id).

const PREFABS := [
	"camera_first_person", "camera_third_person",
	"player_first_person", "player_third_person",
	"interaction_system", "inventory", "ui_hud",
	"pickup", "trigger_zone", "dialogue_box",
]

func _init() -> void:
	var fails := 0
	for p in PREFABS:
		var err := _check(p)
		if err == "":
			print("PASS prefab: %s round-trips" % p)
		else:
			print("FAIL prefab %s: %s" % [p, err])
			fails += 1
	quit(0 if fails == 0 else 1)

func _check(name: String) -> String:
	var ps: PackedScene = load("res://prefabs/%s.tscn" % name)
	if ps == null:
		return "cannot load"
	var n := ps.instantiate()
	if n == null:
		return "cannot instantiate"
	if n.get_script() == null:
		n.free()
		return "script not packed into scene"
	var err := _extra(name, n)
	n.free()
	return err

func _extra(name: String, n: Node) -> String:
	match name:
		"camera_first_person":
			return "" if n is Camera3D and n.has_method("apply_look") else "not a look camera"
		"camera_third_person":
			if not (n is SpringArm3D) or n.get("spring_length") <= 0.0:
				return "spring arm missing/rest length unset"
			return "" if n.get_node_or_null("Camera") is Camera3D else "no child Camera3D"
		"player_first_person":
			return _check_player(n, "CameraFirstPerson")
		"player_third_person":
			return _check_player(n, "CameraThirdPerson")
		"interaction_system":
			return "" if n.get("range") > 0.0 else "range param missing"
		"inventory":
			return "" if n.get("capacity") == 10 else "capacity param missing"
		"ui_hud":
			for id in ["HealthBar", "QuestList", "ToastLabel", "Crosshair"]:
				if n.get_node_or_null("%" + id) == null:
					return "missing unique node %" + id
				if n.get_node("%" + id).get_meta("test_id", "") == "":
					return "%" + id + " missing test_id metadata"
			return ""
		"pickup":
			if not (n is Interactable):
				return "root is not Interactable"
			return "" if n.get_node_or_null("Collision") else "no collision shape"
		"trigger_zone":
			if not (n is Area3D):
				return "root is not Area3D"
			return "" if n.get_node_or_null("Collision") else "no collision shape"
		"dialogue_box":
			for id in ["SpeakerLabel", "TextLabel", "ChoiceList"]:
				if n.get_node_or_null("%" + id) == null:
					return "missing unique node %" + id
			return ""
	return ""

func _check_player(n: Node, cam_name: String) -> String:
	if not (n is CharacterBody3D):
		return "root is not CharacterBody3D"
	var cam := n.get_node_or_null(cam_name)
	if cam == null:
		return "missing camera " + cam_name
	if n.get("camera_pivot_path") != NodePath(cam_name):
		return "camera_pivot_path not wired to camera"
	if n.get_node_or_null("Inventory") == null:
		return "missing Inventory child"
	return ""
