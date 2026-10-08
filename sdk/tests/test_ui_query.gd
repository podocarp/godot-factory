extends SceneTree
# Tests for UiQuery: query HUD/dialogue controls by test_id metadata and
# click buttons programmatically (pressed signal, no mouse coords).

var _fails := 0

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	_test_query()
	_test_click()
	EventBus.reset()
	quit(0 if _fails == 0 else 1)

func _report(name: String, err: String) -> void:
	if err == "":
		print("PASS ui_query: " + name)
	else:
		print("FAIL ui_query %s: %s" % [name, err])
		_fails += 1

func _test_query() -> void:
	var hud: HudController = load("res://prefabs/ui_hud.tscn").instantiate()
	root.add_child(hud)
	hud.add_quest("find_key", "Find the rusty key")
	var err := ""
	var hits := UiQuery.query(hud, "health_bar")
	if hits.size() != 1:
		err = "health_bar not found: %s" % str(hits)
	else:
		var h: Dictionary = hits[0]
		if h["role"] != "progress_bar" or h["visible"] != true or h["enabled"] != true:
			err = "health_bar role/visible/enabled wrong: %s" % str(h)
		if h["rect"].size() != 4:
			err = "rect not [x,y,w,h]: %s" % str(h["rect"])
	if UiQuery.query(hud, "quest_find_key").size() != 1:
		err = "dynamic quest label (test_id added at runtime) not found"
	if UiQuery.query(hud, "nope").size() != 0:
		err = "unknown id must return empty"
	var all := UiQuery.query(hud)  # all test_id'd controls
	if all.size() < 5:  # health_bar, quest_list, toast_label, crosshair, quest_find_key
		err = "full query found only %d: %s" % [all.size(), str(all)]
	root.remove_child(hud)
	hud.free()
	_report("query by test_id", err)

func _test_click() -> void:
	var box: DialogueBox = load("res://prefabs/dialogue_box.tscn").instantiate()
	root.add_child(box)
	var picks: Array = []
	box.choice_selected.connect(func(i: int) -> void: picks.append(i))
	box.show_choices("Elder", "Which road?", ["North", "South"])
	var err := ""
	if not UiQuery.click_by_test_id(box, "choice_1"):
		err = "click_by_test_id refused a live button"
	if picks != [1]:
		err = "click did not fire action: picks=%s" % str(picks)
	# closed dialogue: choice_0 is gone (queue_free) -> click must refuse, not crash
	if UiQuery.click_by_test_id(box, "choice_0"):
		err = "click on closed dialogue should refuse"
	# hidden button: refuse
	box.show_choices("Elder", "Wait", ["Hold"])
	var b := UiQuery.find_by_test_id(box, "choice_0")
	b.visible = false
	if UiQuery.click_by_test_id(box, "choice_0"):
		err = "click on hidden button should refuse"
	# describe() reports text for buttons
	box.show_choices("Elder", "Wait", ["Hold"])
	var d := UiQuery.query(box, "choice_0")
	if d.size() != 1 or d[0]["role"] != "button" or d[0]["text"] != "Hold":
		err = "describe button wrong: %s" % str(d)
	root.remove_child(box)
	box.free()
	_report("click_by_test_id fires pressed", err)
