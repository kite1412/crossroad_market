extends "res://scripts/locations/store/StoreNpcRoutes.gd"

const DebugStorePathGraphScript = preload(
	"res://scripts/debug/StorePathDebugGraph.gd"
)
const DEBUG_STORE_ROUTE_PROFILE: bool = true
const SLOW_GRAPH_SETUP_THRESHOLD_MSEC: float = 2.0
const MARKER_MATCH_DISTANCE: float = 10.0


func get_npc_route_to_queue_target_from(
	from_position: Vector2,
	queue_index: int
) -> Array[Vector2]:
	var started_usec = Time.get_ticks_usec()
	var route = super.get_npc_route_to_queue_target_from(
		from_position,
		queue_index
	)
	if DEBUG_STORE_ROUTE_PROFILE:
		var message = (
			"[STORE_QUEUE_ROUTE] queue_index=%d elapsed_ms=%.3f from=%s "
			+ "target=%s route=%s"
		) % [
			queue_index,
			float(Time.get_ticks_usec() - started_usec) / 1000.0,
			str(from_position),
			str(get_npc_queue_target(queue_index, from_position)),
			_format_route(route)
		]
		print(message)
	return route


func get_npc_route_from_shelf_to_cashier(
	shelf: Shelf
) -> Array[Vector2]:
	if shelf == null or not is_instance_valid(shelf):
		return []

	var started_usec = Time.get_ticks_usec()
	var route = super.get_npc_route_from_shelf_to_cashier(shelf)
	if DEBUG_STORE_ROUTE_PROFILE:
		print(
			"[STORE_SHELF_EGRESS] shelf=%s elapsed_ms=%.3f route=%s"
			% [
				"%s@%s" % [shelf.name, str(shelf.global_position)],
				float(Time.get_ticks_usec() - started_usec) / 1000.0,
				_format_route(route)
			]
		)
	return route


func get_store_path_graph() -> StorePathGraph:
	var total_started_usec = Time.get_ticks_usec()
	var needs_debug_graph = (
		store._store_path_graph == null
		or store._store_path_graph.get_script() != DebugStorePathGraphScript
	)

	if needs_debug_graph:
		store._store_path_graph = DebugStorePathGraphScript.new(
			store,
			store.store_path_markers
		)
	else:
		store._store_path_graph.setup(
			store,
			store.store_path_markers
		)

	var grid_started_usec = Time.get_ticks_usec()
	var grid_points: Array[Vector2] = store._get_shelf_placement_grid_positions()
	var grid_elapsed_msec = float(
		Time.get_ticks_usec() - grid_started_usec
	) / 1000.0

	var set_points_started_usec = Time.get_ticks_usec()
	store._store_path_graph.set_shelf_access_points(grid_points)
	var set_points_elapsed_msec = float(
		Time.get_ticks_usec() - set_points_started_usec
	) / 1000.0
	var total_elapsed_msec = float(
		Time.get_ticks_usec() - total_started_usec
	) / 1000.0

	if (
		DEBUG_STORE_ROUTE_PROFILE
		and total_elapsed_msec >= SLOW_GRAPH_SETUP_THRESHOLD_MSEC
	):
		var message = (
			"[STORE_GRAPH_SETUP] new_graph=%s grid_points=%d grid_ms=%.3f "
			+ "set_points_ms=%.3f total_ms=%.3f"
		) % [
			str(needs_debug_graph),
			grid_points.size(),
			grid_elapsed_msec,
			set_points_elapsed_msec,
			total_elapsed_msec
		]
		print(message)

	return store._store_path_graph


func _format_route(route: Array[Vector2]) -> String:
	if route.is_empty():
		return "[]"

	var formatted: Array[String] = []
	for point in route:
		var marker_name = _get_nearest_marker_name(point)
		if marker_name != "":
			formatted.append("%s:%s" % [marker_name, str(point)])
		else:
			formatted.append(str(point))
	return "[" + ", ".join(formatted) + "]"


func _get_nearest_marker_name(point: Vector2) -> String:
	if store == null or store.store_path_markers == null:
		return ""

	var nearest_name = ""
	var nearest_distance = INF
	for child in store.store_path_markers.get_children():
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
