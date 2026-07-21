class_name StoreRuntimeDebugProbe
extends RefCounted


const MAX_EVENTS: int = 80
const DEFAULT_THRESHOLD_MSEC: float = 4.0

static var enabled: bool = true
static var _events: Array[Dictionary] = []


static func record(
	label: StringName,
	duration_msec: float,
	context: Dictionary = {},
	threshold_msec: float = DEFAULT_THRESHOLD_MSEC
) -> void:
	if not enabled:
		return
	if duration_msec < threshold_msec:
		return

	_events.append({
		"label": label,
		"elapsed_msec": duration_msec,
		"context": context.duplicate(true),
		"time_msec": Time.get_ticks_msec()
	})
	while _events.size() > MAX_EVENTS:
		_events.pop_front()


static func get_events() -> Array[Dictionary]:
	return _events.duplicate(true)


static func get_summary() -> Dictionary:
	var counts: Dictionary = {}
	var max_elapsed: Dictionary = {}
	for event in _events:
		var label := StringName(str(event.get("label", &"unknown")))
		counts[label] = int(counts.get(label, 0)) + 1
		max_elapsed[label] = maxf(
			float(max_elapsed.get(label, 0.0)),
			float(event.get("elapsed_msec", 0.0))
		)

	return {
		"enabled": enabled,
		"event_count": _events.size(),
		"counts": counts,
		"max_elapsed_msec": max_elapsed
	}


static func clear() -> void:
	_events.clear()


static func elapsed_msec(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000.0
