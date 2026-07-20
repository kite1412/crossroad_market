extends "res://scripts/locations/store/OptimizedStorePathGraph.gd"

const DEBUG_GRAPH_PROFILE: bool = true
const SLOW_GRAPH_THRESHOLD_MSEC: float = 2.0


func set_shelf_access_points(points: Array[Vector2]) -> void:
	var started_usec := Time.get_ticks_usec()
	super.set_shelf_access_points(points)
	_log_graph_stage(
		"set_shelf_access_points",
		started_usec,
		"point_count=%d" % points.size()
	)


func store_shelf_access_metadata(
	object: Node2D,
	drop_position: Vector2
) -> void:
	var shelf_label := "<invalid>"
	if is_instance_valid(object):
		shelf_label = "%s@%s" % [object.name, str(drop_position)]

	var started_usec := Time.get_ticks_usec()
	super.store_shelf_access_metadata(object, drop_position)
	var ready_after := false
	if is_instance_valid(object):
		ready_after = bool(object.get_meta("npc_path_ready", false))

	_log_graph_stage(
		"store_shelf_access_metadata",
		started_usec,
		"shelf=%s ready_after=%s access_points=%d"
		% [shelf_label, str(ready_after), _shelf_access_points.size()],
		true
	)


func _log_graph_stage(
	stage: String,
	started_usec: int,
	details: String,
	always_log: bool = false
) -> void:
	if not DEBUG_GRAPH_PROFILE:
		return

	var elapsed_msec := float(Time.get_ticks_usec() - started_usec) / 1000.0
	if not always_log and elapsed_msec < SLOW_GRAPH_THRESHOLD_MSEC:
		return

	print(
		"[STORE_GRAPH_PROFILE] stage=%s elapsed_ms=%.3f %s"
		% [stage, elapsed_msec, details]
	)
