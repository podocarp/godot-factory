class_name EventBus
extends RefCounted
# Typed global signal hub. This nixpkgs Godot build has no `static signal`
# support, so the hub is a lazily-created RefCounted singleton: connect with
# EventBus.bus().interacted.connect(...) — still typed signals, no string
# names, and it works under `--script` runs where autoloads may not exist.

signal item_picked_up(item: Item, count: int)
signal interacted(target: Node)
signal trigger_fired(event_name: String)
signal quest_updated(quest_id: String, status: String)
signal inventory_changed(slots: Array)

static var _bus: EventBus

static func bus() -> EventBus:
	if _bus == null:
		_bus = EventBus.new()
	return _bus

## Tear down the singleton (tests: prevents connections holding freed locals
## past the GDScript VM shutdown, which crashes the exit path).
static func reset() -> void:
	if _bus != null:
		_bus = null
