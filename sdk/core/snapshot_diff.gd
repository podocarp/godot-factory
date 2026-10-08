class_name SnapshotDiff
extends RefCounted
# Diff two Inspect.snapshot() dictionaries into a compact change list so the
# agent loop ships deltas, not full dumps (memo §5: "concise diffs rather
# than raw logs"). Keys nodes by tree path; compares state per key.
# Output: {added: [path], removed: [path], changed: [{path, key, old, new}],
#          new_events: [String]} — all sorted for determinism.

static func diff(a: Dictionary, b: Dictionary) -> Dictionary:
	var am := _by_path(a)
	var bm := _by_path(b)
	var out := {"added": [], "removed": [], "changed": [], "new_events": []}
	for p in bm.keys():
		if not am.has(p):
			out["added"].append(p)
	for p in am.keys():
		if not bm.has(p):
			out["removed"].append(p)
		else:
			_diff_state(String(p), am[p], bm[p], out["changed"])
	(out["added"] as Array).sort()
	(out["removed"] as Array).sort()
	(out["changed"] as Array).sort_custom(func(x, y) -> bool:
		var kx := "%s/%s" % [x["path"], x["key"]]
		var ky := "%s/%s" % [y["path"], y["key"]]
		return kx < ky)
	# Events are append-only; new events = the tail past the old log. If the
	# log was reset in between (not a prefix), report the whole new log.
	var ea: Array = a.get("events", [])
	var eb: Array = b.get("events", [])
	out["new_events"] = eb.slice(ea.size()) if _is_prefix(ea, eb) else eb.duplicate()
	return out

static func _is_prefix(prefix: Array, arr: Array) -> bool:
	if prefix.size() > arr.size():
		return false
	for i in prefix.size():
		if prefix[i] != arr[i]:
			return false
	return true

## True when nothing changed — cheap gate for "did this step do anything?".
static func is_empty(d: Dictionary) -> bool:
	return d.get("added", []).is_empty() and d.get("removed", []).is_empty() \
		and d.get("changed", []).is_empty() and d.get("new_events", []).is_empty()

static func _by_path(snap: Dictionary) -> Dictionary:
	var m := {}
	for n in snap.get("nodes", []):
		m[n["path"]] = n
	return m

static func _diff_state(path: String, na: Dictionary, nb: Dictionary, out: Array) -> void:
	var sa: Dictionary = na.get("state", {})
	var sb: Dictionary = nb.get("state", {})
	var keys := sa.keys()
	for k in sb.keys():
		if not keys.has(k):
			keys.append(k)
	keys.sort()
	for k in keys:
		var va = sa.get(k)
		var vb = sb.get(k)
		if va != vb:  # Dictionary/Array compare by value in GDScript
			out.append({"path": path, "key": k, "old": va, "new": vb})
