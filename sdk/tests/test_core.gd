extends SceneTree
# Core contracts: EntityRegistry, EventBus, SimDriver (determinism).

func _init() -> void:
	# Run on the first frame: nodes are not "in tree" during _init and
	# freeing tree children before the loop starts corrupts the heap at exit.
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	var ok := true
	ok = _test_registry() and ok
	ok = _test_event_bus() and ok
	ok = _test_sim_driver() and ok
	EventBus.reset()  # drop connections before exit (see event_bus.gd)
	quit(0 if ok else 1)

func _test_registry() -> bool:
	var reg := EntityRegistry.new()
	root.add_child(reg)
	var a := Node3D.new()
	a.name = "junk_name"
	root.add_child(a)
	var b := Node3D.new()
	root.add_child(b)
	var ok_all := true
	ok_all = reg.register(a, "gate_1") and ok_all
	# Registration renames for stable addressing.
	ok_all = String(a.name) == "gate_1" and ok_all
	ok_all = reg.get_entity("gate_1") == a and ok_all
	ok_all = reg.has_entity("gate_1") and not reg.has_entity("nope") and ok_all
	# Duplicate ids are refused, first registration wins.
	ok_all = not reg.register(b, "gate_1") and reg.get_entity("gate_1") == a and ok_all
	# Freeing unregisters (no stale entries).
	a.free()
	ok_all = not reg.has_entity("gate_1") and ok_all
	reg.free()
	print("PASS core: EntityRegistry" if ok_all else "FAIL core: EntityRegistry")
	return ok_all

func _test_event_bus() -> bool:
	var got: Array = []
	EventBus.bus().interacted.connect(func(t: Node) -> void: got.append(t))
	var target := Node.new()
	EventBus.bus().interacted.emit(target)
	var ok_all: bool = got.size() == 1 and got[0] == target
	# Singleton: bus() returns the same instance.
	ok_all = EventBus.bus() == EventBus.bus() and ok_all
	print("PASS core: EventBus typed signals" if ok_all else "FAIL core: EventBus")
	return ok_all

func _test_sim_driver() -> bool:
	var sd := SimDriver.new()
	root.add_child(sd)
	var ticks: Array = []
	sd.ticked.connect(func(t: int, _dt: float) -> void: ticks.append(t))
	sd.enabled = false  # no real frames in this test; drive manually
	sd.simulate(1.0)  # 60 Hz default -> 60 ticks
	var ok_all := ticks.size() == 60 and sd.tick == 60
	# Seeded RNG is reproducible across resets.
	sd.reset(1234)
	var seq_a: Array = []
	for _i in 5:
		seq_a.append(sd.rng.randf())
	sd.reset(1234)
	var seq_b: Array = []
	for _i in 5:
		seq_b.append(sd.rng.randf())
	ok_all = seq_a == seq_b and ok_all
	sd.free()
	print("PASS core: SimDriver fixed-step + seeded RNG" if ok_all else "FAIL core: SimDriver")
	return ok_all
