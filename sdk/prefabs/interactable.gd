class_name Interactable
extends StaticBody3D
# Base contract for anything the interaction system can target. Subclasses
# override can_interact()/on_interact(); the interaction system enforces the
# shared cooldown so subclasses never re-implement timing.

signal interacted_by(player: Node)

## Seconds between accepted interacts. 0 = no limit.
@export var cooldown: float = 0.0
## Optional prompt shown by UI (e.g. "Take key").
@export var prompt: String = "Interact"

var _last_interact_tick: int = -1000000

func can_interact(player: Node) -> bool:
	return is_interactable()

func interact(player: Node) -> bool:
	# Cooldown is checked here (not in can_interact) so highlight stays honest
	# while spam-input is rejected.
	if not can_interact(player):
		return false
	if not _cooldown_ready():
		return false
	_last_interact_tick = _tick()
	var ok := on_interact(player)
	if ok:
		interacted_by.emit(player)
		EventBus.bus().interacted.emit(self)
	return ok

## Subclass hook: do the thing. Return true if the interaction was consumed.
func on_interact(_player: Node) -> bool:
	return true

## Subclasses that get consumed (pickups) override to return false afterwards.
func is_interactable() -> bool:
	return true

func _cooldown_ready() -> bool:
	if cooldown <= 0.0:
		return true
	return (_tick() - _last_interact_tick) * _step() >= cooldown

func _tick() -> int:
	var sd := get_tree().get_first_node_in_group("sim_driver") as SimDriver
	return sd.tick if sd else 0

func _step() -> float:
	var sd := get_tree().get_first_node_in_group("sim_driver") as SimDriver
	return (1.0 / sd.tick_rate) if sd else 1.0 / 60.0
