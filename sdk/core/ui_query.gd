class_name UiQuery
extends RefCounted
# UI automation tree (memo §6): query Controls by their `test_id` metadata
# (the convention sdk HUD/dialogue prefabs already write) and drive them
# without mouse coordinates — click_by_test_id emits `pressed` programmatically,
# so UI tests survive resolution/style/renderer differences.

## Find the node carrying metadata test_id == id under `root` (depth-first).
## Nodes pending deletion (queue_free'd, still in tree) are skipped so tests
## never drive stale widgets. Returns null when absent.
static func find_by_test_id(root: Node, id: String) -> Control:
	for c in root.get_children():
		var found := find_by_test_id(c, id)
		if found != null:
			return found
	if root is Control and not root.is_queued_for_deletion() \
			and String(root.get_meta("test_id", "")) == id:
		return root as Control
	return null

## {test_id, role, visible, enabled, text, rect} for one control.
## rect is the global rect in canvas coords — diagnostics only (memo §6).
static func describe(node: Control) -> Dictionary:
	return {
		"test_id": String(node.get_meta("test_id", "")),
		"role": _role(node),
		"visible": node.visible and node.is_visible_in_tree(),
		"enabled": _enabled(node),
		"text": _text(node),
		"rect": _rect(node),
	}

## Query the tree: list of describe() for every test_id'd control, or only
## `id` when given (empty list if not found).
static func query(root: Node, id: String = "") -> Array:
	var out: Array = []
	if id != "":
		var n := find_by_test_id(root, id)
		if n != null:
			out.append(describe(n))
		return out
	_collect(root, out)
	return out

## Fire a button's `pressed` signal as if the user clicked it.
## Returns false (no crash) when the id is missing, not a Button, hidden,
## or disabled — a UI test asserting on a dead click must see the refusal.
static func click_by_test_id(root: Node, id: String) -> bool:
	var n := find_by_test_id(root, id)
	if n == null or not (n is Button):
		return false
	var b := n as Button
	if not b.visible or b.disabled:
		return false
	b.pressed.emit()
	return true

static func _collect(node: Node, out: Array) -> void:
	if node is Control and not node.is_queued_for_deletion() \
			and node.get_meta("test_id", "") != "":
		out.append(describe(node as Control))
	for c in node.get_children():
		_collect(c, out)

static func _role(node: Control) -> String:
	if node is Button:
		return "button"
	if node is LineEdit:
		return "text_field"
	if node is ProgressBar:
		return "progress_bar"
	if node is Label:
		return "text"
	if node is Container:
		return "list"
	return node.get_class().to_lower()

## "enabled" lives on BaseButton (disabled), not Control; other controls are
## always interactive in this SDK (LineEdit.editable is checked separately).
static func _enabled(node: Control) -> bool:
	if node is BaseButton:
		return not node.disabled
	if node is LineEdit:
		return node.editable
	return true

static func _text(node: Control) -> String:
	# separate `is` branches: GDScript narrows types per-branch, not across `or`
	if node is Label:
		return node.text
	if node is Button:
		return node.text
	if node is LineEdit:
		return node.text
	return ""

static func _rect(node: Control) -> Array:
	var r := node.get_global_rect()
	return [r.position.x, r.position.y, r.size.x, r.size.y]
