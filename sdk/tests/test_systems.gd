extends SceneTree
# Behavior tests for data systems: inventory, pickup + interaction contract.
# All headless, no Input singleton — systems
# expose test hooks (try_interact, pick, test_input) instead.

var _fails := 0

func _init() -> void:
	# Nodes are not "in tree" during _init (no _ready, get_tree() == null), so
	# run the suite on the first processed frame instead.
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	_test_inventory()
	_test_pickup_interaction()
	EventBus.reset()  # drop connections before exit (see event_bus.gd)
	quit(0 if _fails == 0 else 1)

func _report(name: String, err: String) -> void:
	if err == "":
		print("PASS system: " + name)
	else:
		print("FAIL system %s: %s" % [name, err])
		_fails += 1

func _test_inventory() -> void:
	var sword := Item.new("sword", "Sword")
	sword.stackable = false
	var gem := Item.new("gem", "Gem")
	gem.max_stack = 5
	var inv := Inventory.new(3)
	var err := ""
	# Stacking respects max_stack, spills into new slots.
	inv.add_item(gem, 10)  # fills slot1 (5) + slot2 (5)
	if inv.count_of(gem) != 10 or inv.slots.size() != 2:
		err = "stacking wrong: %d in %d slots" % [inv.count_of(gem), inv.slots.size()]
	# Non-stackable takes one slot each.
	inv.add_item(sword, 1)
	if inv.slots.size() != 3:
		err = "sword should fill slot 3"
	# Capacity enforced: every slot full, leftover reported.
	if inv.add_item(gem, 1) != 0:
		err = "full inventory accepted more"
	# Remove + serialize round-trip.
	var changed_fired := [false]
	inv.changed.connect(func() -> void: changed_fired[0] = true)
	inv.remove_item(gem, 2)
	if inv.count_of(gem) != 8 or not changed_fired[0]:
		err = "remove/changed signal wrong"
	var db := {"sword": sword, "gem": gem}
	var copy := Inventory.from_dict(inv.to_dict(), db)
	if copy.count_of(gem) != 8 or copy.count_of(sword) != 1:
		err = "serialize round-trip lost items"
	_report("inventory stack/remove/serialize", err)

func _test_pickup_interaction() -> void:
	var err := ""
	var pickup: Pickup = load("res://prefabs/pickup.tscn").instantiate()
	var key := Item.new("key", "Rusty Key")
	key.stackable = false
	pickup.item = key
	var player := Node3D.new()
	var inv := Inventory.new(5)
	inv.name = "Inventory"  # matches the pickup's default inventory_path
	player.add_child(inv)
	var level := Node3D.new()
	root.add_child(level)  # level must be in-tree before its children resolve get_tree()
	level.add_child(pickup)
	level.add_child(player)
	# Interact contract: succeeds once, then not interactable (one-shot).
	if not pickup.interact(player):
		err = "first interact failed"
	elif inv.count_of(key) != 1:
		err = "item not added to inventory"
	elif pickup.interact(player):
		err = "pickup was not one-shot"
	elif pickup.is_interactable():
		err = "taken pickup still interactable"
	# Cooldown: an Interactable with cooldown rejects the second quick interact.
	var zone := Interactable.new()
	zone.cooldown = 1.0
	level.add_child(zone)  # must be in tree for SimDriver group lookup
	var sd := SimDriver.new()
	sd.enabled = false
	sd.add_to_group("sim_driver")  # before add_child: _ready looks the group up
	level.add_child(sd)
	if not zone.interact(player):
		err = "cooldown: first interact failed"
	elif zone.interact(player):
		err = "cooldown did not block second interact"
	sd.simulate(1.5)
	if not zone.interact(player):
		err = "cooldown did not expire"
	level.free()
	_report("pickup + interactable cooldown", err)


