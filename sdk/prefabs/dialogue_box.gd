class_name DialogueBox
extends Control
# Minimal dialogue UI: speaker + text + choice buttons. Games call show_line()
# / show_choices(); a click (or test pick()) emits choice_selected(index).

signal choice_selected(index: int)
signal finished

@onready var _speaker: Label = %SpeakerLabel
@onready var _text: Label = %TextLabel
@onready var _choices: VBoxContainer = %ChoiceList

func show_line(speaker: String, text: String) -> void:
	visible = true
	_speaker.text = speaker
	_text.text = text
	_clear_choices()

func show_choices(speaker: String, text: String, options: Array[String]) -> void:
	show_line(speaker, text)
	for i in options.size():
		var b := Button.new()
		b.name = "Choice%d" % i
		b.set_meta("test_id", "choice_%d" % i)
		b.text = options[i]
		b.pressed.connect(pick.bind(i))
		_choices.add_child(b)

func pick(index: int) -> void:
	# Guard: picking with no open dialogue is a no-op (tests rely on this).
	if not visible or index < 0 or index >= _choices.get_child_count():
		return
	choice_selected.emit(index)
	close()

func close() -> void:
	visible = false
	_clear_choices()

func _clear_choices() -> void:
	for c in _choices.get_children():
		c.queue_free()
