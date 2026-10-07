extends SceneTree
# Behavior tests for UI-ish systems: trigger zones, dialogue box, HUD.
# Same headless conventions as test_systems.gd (run on first frame,
# EventBus.reset() before quit).

var _fails := 0

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	_test_trigger_zone()
	_test_dialogue()
	_test_hud()
	EventBus.reset()  # drop connections before exit (see event_bus.gd)
	quit(0 if _fails == 0 else 1)

func _report(name: String, err: String) -> void:
	if err == "":
		print("PASS system: " + name)
	else:
		print("FAIL system %s: %s" % [name, err])
		_fails += 1

func _test_trigger_zone() -> void:
	var err := ""
	var zone: TriggerZone = load("res://prefabs/trigger_zone.tscn").instantiate()
	zone.event_name = "ambush"
	root.add_child(zone)
	var got: Array = []
	EventBus.bus().trigger_fired.connect(func(n: String) -> void: got.append(n))
	zone._on_body_entered(Node3D.new())
	zone._on_body_entered(Node3D.new())  # overlapping body must not double-fire
	if got != ["ambush"]:
		err = "once-mode fired %s" % str(got)
	zone.reset()
	zone._on_body_entered(Node3D.new())
	if got.size() != 2:
		err = "reset() did not rearm"
	root.remove_child(zone)
	zone.free()
	_report("trigger zone once/repeat", err)

func _test_dialogue() -> void:
	var err := ""
	var box: DialogueBox = load("res://prefabs/dialogue_box.tscn").instantiate()
	root.add_child(box)
	var picks: Array = []
	box.choice_selected.connect(func(i: int) -> void: picks.append(i))
	box.show_choices("Elder", "Which road?", ["North", "South"])
	if box._choices.get_child_count() != 2:
		err = "choices not built"
	box.pick(1)
	if picks != [1] or box.visible:
		err = "pick() did not emit/close"
	box.pick(0)  # closed dialogue: must be a no-op
	if picks.size() != 1:
		err = "pick() fired on closed box"
	root.remove_child(box)
	box.free()
	_report("dialogue box choices", err)

func _test_hud() -> void:
	var err := ""
	var hud: HudController = load("res://prefabs/ui_hud.tscn").instantiate()
	var sd := SimDriver.new()
	sd.enabled = false
	sd.add_to_group("sim_driver")  # before add_child: HUD _ready looks it up
	root.add_child(sd)
	root.add_child(hud)
	hud.set_health(50.0)
	if hud.get_node("%HealthBar").value != 0.5:
		err = "health bar not bound (got %f)" % hud.get_node("%HealthBar").value
	hud.add_quest("find_key", "Find the rusty key")
	var qlist := hud.get_node("%QuestList")
	if qlist.get_child_count() != 1:
		err = "quest not added"
	hud.update_quest("find_key", "Key found")
	if not String(qlist.get_child(0).text).begins_with("✓"):
		err = "quest update text wrong"
	hud.notify("Took damage")
	hud.notify("Low health")
	if hud.get_node("%ToastLabel").text != "Took damage":
		err = "first toast not shown"
	sd.simulate(3.0)  # toast_duration default 3s (simulate takes seconds)
	if hud.get_node("%ToastLabel").text != "Low health":
		err = "toast queue did not advance (got '%s')" % hud.get_node("%ToastLabel").text
	root.remove_child(hud)
	hud.free()
	sd.free()
	_report("hud health/quests/toast queue", err)
