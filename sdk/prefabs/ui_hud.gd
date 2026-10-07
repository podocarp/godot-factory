class_name HudController
extends Control
# Binds ui_hud.tscn nodes to game state: health bar <- a stat, quest list <-
# add_quest/update_quest, toasts <- notify() (queued, one visible at a time,
# advanced by the SimDriver clock — no wall-clock timers).
#
# Every bound node carries metadata "test_id" and unique_name_in_owner, so
# tests find them with %HealthBar etc. regardless of nesting.

@export var max_health: float = 100.0
## Seconds a toast stays up (in sim ticks via SimDriver; 60/s default).
@export var toast_duration: float = 3.0

@onready var _health: ProgressBar = %HealthBar
@onready var _quests: VBoxContainer = %QuestList
@onready var _toast: Label = %ToastLabel

var health: float = 100.0
var _quest_labels := {}  # quest_id -> Label
var _toast_queue: Array[String] = []
var _toast_ticks_left: int = 0

func _ready() -> void:
	# is_inside_tree guard: nodes may be configured before being added to a tree.
	var sd := get_tree().get_first_node_in_group("sim_driver") as SimDriver if is_inside_tree() else null
	if sd:
		sd.ticked.connect(_on_tick)
	set_health(health)

func set_health(value: float) -> void:
	health = clampf(value, 0.0, max_health)
	_health.value = health / max_health

func add_quest(quest_id: String, text: String) -> void:
	if _quest_labels.has(quest_id):
		return
	var l := Label.new()
	l.name = "Quest_" + quest_id
	l.set_meta("test_id", "quest_" + quest_id)
	l.text = "• " + text
	_quests.add_child(l)
	_quest_labels[quest_id] = l
	EventBus.bus().quest_updated.emit(quest_id, "active")

func update_quest(quest_id: String, text: String) -> void:
	var l: Label = _quest_labels.get(quest_id)
	if l:
		l.text = "✓ " + text
		EventBus.bus().quest_updated.emit(quest_id, "done")

func notify(message: String) -> void:
	_toast_queue.append(message)
	if _toast_ticks_left <= 0:
		_show_next_toast()

func _on_tick(_tick: int, dt: float) -> void:
	if _toast_ticks_left > 0:
		_toast_ticks_left -= 1
		if _toast_ticks_left <= 0:
			_toast.text = ""
			_show_next_toast()

func _show_next_toast() -> void:
	if _toast_queue.is_empty():
		return
	_toast.text = _toast_queue.pop_front()
	_toast_ticks_left = int(toast_duration * 60.0)
