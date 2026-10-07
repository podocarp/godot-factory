class_name PrefabDefsActors
extends RefCounted
# Node-tree builders for camera/player prefabs, used by tools/build_prefabs.gd
# (the canonical code-authored-prefab pipeline; FACTORY.md rule 1). Nodes are
# parented here; build_prefabs re-owns everything to the packed root.

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

# ---- cameras ---------------------------------------------------------------

func camera_first_person() -> Node:
	var cam := Camera3D.new()
	cam.name = "CameraFirstPerson"
	_script(cam, "res://prefabs/camera_first_person.gd")
	cam.current = true
	cam.position = Vector3(0, 1.6, 0)  # eye height
	return cam

func camera_third_person() -> Node:
	var arm := SpringArm3D.new()
	arm.name = "CameraThirdPerson"
	_script(arm, "res://prefabs/camera_third_person.gd")
	arm.spring_length = 4.0
	arm.margin = 0.2  # collision-avoidance margin around the camera
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.position = Vector3(0, 0, 4)  # rest distance behind the pivot
	arm.add_child(cam)
	cam.owner = arm
	return arm

# ---- players ---------------------------------------------------------------

func _capsule_body(root: Node, radius: float, height: float) -> void:
	var col := _n("CollisionShape3D", root, {"name": "Collision"})
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = height
	col.shape = cap
	var mesh := _n("MeshInstance3D", root, {"name": "BodyMesh"})
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = height
	mesh.mesh = _mesh(cm, Color(0.4, 0.6, 0.9))

func player_first_person() -> Node:
	var p := CharacterBody3D.new()
	p.name = "PlayerFirstPerson"
	_script(p, "res://prefabs/player_mover.gd")
	_capsule_body(p, 0.4, 1.7)
	var cam := camera_first_person()
	p.add_child(cam)
	cam.owner = p
	# Mover needs the camera yaw for camera-relative movement.
	p.set("camera_pivot_path", NodePath("CameraFirstPerson"))
	var inv := PrefabDefsWorld.new().inventory()
	p.add_child(inv)
	inv.owner = p
	return p

func player_third_person() -> Node:
	var p := CharacterBody3D.new()
	p.name = "PlayerThirdPerson"
	_script(p, "res://prefabs/player_mover.gd")
	_capsule_body(p, 0.4, 1.7)
	var rig := camera_third_person()
	p.add_child(rig)
	rig.owner = p
	# Rig follows the body; mover steers by rig yaw.
	p.set("camera_pivot_path", NodePath("CameraThirdPerson"))
	rig.set("target_path", NodePath(".."))  # NodePath export survives pack()
	var inv := PrefabDefsWorld.new().inventory()
	p.add_child(inv)
	inv.owner = p
	return p
