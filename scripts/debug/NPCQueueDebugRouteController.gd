extends "res://scripts/npc/runtime/NPCResolvedExitRouteController.gd"

const DEBUG_ROUTE_PROFILE: bool = true
const SLOW_ROUTE_THRESHOLD_MSEC: float = 2.0
const ROUTE_LOG_COOLDOWN_MSEC: int = 500
const MARKER_MATCH_DISTANCE: float = 10.0

var _last_route_log_key: String = ""
var _last_route_log_msec: int = -1000000


func build_movement_route(destination: Vector2) -> Array[Vector2]:
	var started_usec = Time.get_ticks_usec()
	var result = super.build_movement_route(destination)
	var elapsed_msec = float(Time.get_ticks_usec() - started_usec) / 1000.0

	var queue_index = NPC.current_queue.find(npc)
	var should_log = (
		elapsed_msec >= SLOW_ROUTE_THRESHOLD_MSEC
		or npc.current_state == NPC.State.WAIT_IN_QUEUE
		or npc.current_state == NPC.State.WALK_TO_SHELF
	)
	if DEBUG_ROUTE_PROFILE and should_log:
		var store = get_store_route_provider()
		var route_text = _format_route(result, store)
		var key = "%s|%d|%d|%s|%s" % [
			_get_npc_label(),
			npc.current_state,
			queue_index,
			str(destination),
			route_text
		]
		var message = (
			"[NPC_ROUTE_PROFILE] npc=%s state=%d queue_index=%d "
			+ "elapsed_ms=%.3f destination=%s points=%d route=%s"
		) % [
			_get_npc_label(),
			npc.current_state,
			queue_index,
			elapsed_msec,
			str(destination),
			result.size(),
			route_text
		]
		_log_throttled(key, message)

	return result


func get_shelf_egress_queue_route(
	store: Node,
	queue_index: int,
	destination: Vector2
) -> Array[Vector2]:
	var started_usec = Time.get_ticks_usec()
	var result = super.get_shelf_egress_queue_route(
		store,
		queue_index,
		destination
	)
	var elapsed_msec = float(Time.get_ticks_usec() - started_usec) / 1000.0

	if DEBUG_ROUTE_PROFILE:
		var message = (
			"[NPC_QUEUE_EGRESS] npc=%s queue_index=%d elapsed_ms=%.3f "
			+ "destination=%s points=%d route=%s"
		) % [
			_get_npc_label(),
			queue_index,
			elapsed_msec,
			str(destination),
			result.size(),
			_format_route(result, store)
		]
		print(message)

	return result


func _format_route(route: Array[Vector2], store: Node) -> String:
	if route.is_empty():
		return "[]"

	var formatted: Array[String] = []
	for point in route:
		var marker_name = _get_nearest_marker_name(store, point)
		if marker_name != "":
			formatted.append("%s:%s" % [marker_name, str(point)])
		else:
			formatted.append(str(point))
	return "[" + ", ".join(formatted) + "]"


func _get_nearest_marker_name(store: Node, point: Vector2) -> String:
	if store == null:
		return ""

	var marker_root_variant: Variant = store.get("store_path_markers")
	if not is_instance_valid(marker_root_variant):
		return ""
	if not (marker_root_variant is Node2D):
		return ""

	var marker_root = marker_root_variant as Node2D
	var nearest_name = ""
	var nearest_distance = INF
	for child in marker_root.get_children():
		if not (child is Marker2D):
			continue
		var marker = child as Marker2D
		var distance = marker.global_position.distance_to(point)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_name = str(marker.name)

	if nearest_distance <= MARKER_MATCH_DISTANCE:
		return nearest_name
	return ""


func _log_throttled(key: String, message: String) -> void:
	var now_msec = Time.get_ticks_msec()
	if (
		key == _last_route_log_key
		and now_msec - _last_route_log_msec < ROUTE_LOG_COOLDOWN_MSEC
	):
		return

	_last_route_log_key = key
	_last_route_log_msec = now_msec
	print(message)


func _get_npc_label() -> String:
	if npc == null:
		return "<null>"
	if npc.npc_data != null and npc.npc_data.npc_id != "":
		return npc.npc_data.npc_id
	return str(npc.name)
