class_name StoreNpcRoutes
extends Node

const OptimizedStorePathGraphScript = preload(
	"res://scripts/locations/store/OptimizedStorePathGraph.gd"
)
const STORE_ENTRY_FALLBACK_POSITION := Vector2(240, 204)
const CHECKOUT_RIGHT_ROUTE_MARKERS: Array[StringName] = [
	&"StorePathQueueFrontRight",
	&"StorePathQueueBack1Right",
	&"StorePathQueueBack2Right",
	&"StorePathQueueExitRight"
]
const SINGLE_CUSTOMER_EXIT_ROUTE_MARKERS: Array[StringName] = [
	&"StorePathQueueFront",
	&"StorePathQueueBack2",
	&"StorePathAisleRight",
	&"StorePathExit"
]
const CHECKOUT_GRAPH_REJOIN_MARKER: StringName = &"StorePathAisleRight"
const CHECKOUT_ROUTE_RESUME_DISTANCE: float = 18.0

var store: Node = null


func setup(store_node: Node) -> void:
	store = store_node


func get_npc_entry_route_to_shelf(
	shelf_position: Vector2,
	from_position: Vector2 = Vector2.INF
) -> Array[Vector2]:
	return get_store_path_graph().get_entry_route_to_shelf(
		shelf_position,
		from_position
	)


func get_npc_shelf_access_position(shelf: Shelf) -> Vector2:
	return get_store_path_graph().get_shelf_access_position(shelf)


func get_npc_shelf_visit_position(
	shelf: Shelf,
	_npc: Node = null
) -> Vector2:
	if not has_npc_shelf_access_metadata(shelf):
		return Vector2.INF
	return get_npc_shelf_access_position(shelf)


func has_npc_shelf_access_metadata(shelf: Shelf) -> bool:
	return get_store_path_graph().has_cached_shelf_access_metadata(shelf)


func get_npc_route_to_shelf_access(
	shelf: Shelf,
	from_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> Array[Vector2]:
	if not has_npc_shelf_access_metadata(shelf):
		return []
	return get_store_path_graph().get_route_to_shelf_access(
		shelf,
		from_position,
		npc_node
	)


func get_npc_route_to_cashier_from(
	from_position: Vector2
) -> Array[Vector2]:
	return get_store_path_graph().get_route_to_cashier_from(from_position)


func get_npc_route_to_queue_target_from(
	from_position: Vector2,
	queue_index: int
) -> Array[Vector2]:
	return get_store_path_graph().get_route_to_queue_target_from(
		from_position,
		queue_index
	)


func get_npc_queue_target(
	queue_index: int,
	fallback_position: Vector2
) -> Vector2:
	return get_store_path_graph().get_queue_target_position(
		queue_index,
		fallback_position
	)


func get_npc_cashier_target(fallback_position: Vector2) -> Vector2:
	return get_store_path_graph().get_cashier_target_position(
		fallback_position
	)


func get_npc_route_from_shelf_to_cashier(
	shelf: Shelf
) -> Array[Vector2]:
	if shelf == null or not is_instance_valid(shelf):
		return []
	return get_store_path_graph().get_route_from_shelf_to_cashier(shelf)


func get_npc_exit_route_from(
	from_position: Vector2
) -> Array[Vector2]:
	var exit_position := get_marker_position_or(
		store.npc_exit_marker,
		STORE_ENTRY_FALLBACK_POSITION
	)
	return get_store_path_graph().get_exit_route_from(
		from_position,
		exit_position
	)


func get_npc_shelf_wait_position(index: int = 0) -> Vector2:
	return get_store_path_graph().get_shelf_wait_position(index)


func get_npc_single_customer_exit_route(
	from_position: Vector2
) -> Array[Vector2]:
	return _build_named_marker_route(
		from_position,
		SINGLE_CUSTOMER_EXIT_ROUTE_MARKERS
	)


func get_npc_exit_route_from_shelf(
	shelf: Shelf,
	from_position: Vector2
) -> Array[Vector2]:
	if shelf == null or not is_instance_valid(shelf):
		return get_npc_exit_route_from(from_position)

	# Move away from the source shelf through the same collision-aware path used
	# after shopping, then join the normal single-customer exit lane.
	var route := get_npc_route_from_shelf_to_cashier(shelf)
	if route.is_empty():
		return get_npc_exit_route_from(from_position)

	var route_end: Vector2 = route.back()
	var exit_route := get_npc_single_customer_exit_route(route_end)
	if exit_route.is_empty():
		exit_route = get_npc_exit_route_from(route_end)

	for point in exit_route:
		_append_unique_route_point(route, point)
	return route


func get_npc_exit_route_from_cashier(
	from_position: Vector2
) -> Array[Vector2]:
	var mandatory_markers := _get_named_markers(
		CHECKOUT_RIGHT_ROUTE_MARKERS
	)
	if mandatory_markers.size() != CHECKOUT_RIGHT_ROUTE_MARKERS.size():
		return []

	var rejoin_marker := store.store_path_markers.get_node_or_null(
		String(CHECKOUT_GRAPH_REJOIN_MARKER)
	) as Marker2D
	if rejoin_marker == null:
		return []

	var route: Array[Vector2] = []
	var start_index := _get_checkout_route_start_index(
		from_position,
		mandatory_markers
	)
	for index in range(start_index, mandatory_markers.size()):
		route.append(mandatory_markers[index].global_position)

	_append_unique_route_point(route, rejoin_marker.global_position)
	var exit_position := get_marker_position_or(
		store.npc_exit_marker,
		STORE_ENTRY_FALLBACK_POSITION
	)
	var graph_route := get_store_path_graph().get_exit_route_from(
		rejoin_marker.global_position,
		exit_position
	)
	for point in graph_route:
		_append_unique_route_point(route, point)

	# Keep the real exit as the final mandatory waypoint even when the graph is
	# already rejoined at AisleRight.
	_append_unique_route_point(route, exit_position)
	return route


func get_store_path_graph() -> StorePathGraph:
	var needs_optimized_graph := (
		store._store_path_graph == null
		or store._store_path_graph.get_script() != OptimizedStorePathGraphScript
	)

	if needs_optimized_graph:
		store._store_path_graph = OptimizedStorePathGraphScript.new(
			store,
			store.store_path_markers
		)
	else:
		store._store_path_graph.setup(
			store,
			store.store_path_markers
		)

	store._store_path_graph.set_shelf_access_points(
		store._get_shelf_placement_grid_positions()
	)
	return store._store_path_graph


func get_marker_position_or(
	marker_node: Marker2D,
	fallback: Vector2
) -> Vector2:
	if marker_node == null:
		return fallback
	return marker_node.global_position


func _build_named_marker_route(
	from_position: Vector2,
	marker_names: Array[StringName]
) -> Array[Vector2]:
	var route_markers := _get_named_markers(marker_names)
	if route_markers.size() != marker_names.size():
		return []

	var route: Array[Vector2] = []
	var start_index := _get_checkout_route_start_index(
		from_position,
		route_markers
	)
	for index in range(start_index, route_markers.size()):
		_append_unique_route_point(
			route,
			route_markers[index].global_position
		)
	return route


func _get_named_markers(
	marker_names: Array[StringName]
) -> Array[Marker2D]:
	var result: Array[Marker2D] = []
	if store == null or store.store_path_markers == null:
		return result

	for marker_name in marker_names:
		var route_marker := store.store_path_markers.get_node_or_null(
			String(marker_name)
		) as Marker2D
		if route_marker == null:
			return []
		result.append(route_marker)
	return result


func _get_checkout_route_start_index(
	from_position: Vector2,
	route_markers: Array[Marker2D]
) -> int:
	var final_marker: Marker2D = route_markers.back()
	if from_position.y >= final_marker.global_position.y - 4.0:
		return route_markers.size()

	var nearest_index := -1
	var nearest_distance := INF
	for index in range(route_markers.size()):
		var distance := from_position.distance_to(
			route_markers[index].global_position
		)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index

	if nearest_distance <= CHECKOUT_ROUTE_RESUME_DISTANCE:
		var nearest_marker: Marker2D = route_markers[nearest_index]
		if from_position.y < nearest_marker.global_position.y - 4.0:
			return nearest_index
		return mini(nearest_index + 1, route_markers.size())
	return 0


func _append_unique_route_point(
	route: Array[Vector2],
	point: Vector2
) -> void:
	if not point.is_finite():
		return
	if not route.is_empty() and route.back().distance_to(point) <= 2.0:
		return
	route.append(point)
