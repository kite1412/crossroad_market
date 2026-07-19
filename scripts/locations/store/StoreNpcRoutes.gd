class_name StoreNpcRoutes
extends Node

const STORE_ENTRY_FALLBACK_POSITION := Vector2(240, 204)
const CHECKOUT_RIGHT_ROUTE_MARKERS: Array[StringName] = [
	&"StorePathQueueFrontRight",
	&"StorePathQueueBack1Right",
	&"StorePathQueueBack2Right",
	&"StorePathQueueExitRight"
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


func get_npc_exit_route_from_cashier(
	from_position: Vector2
) -> Array[Vector2]:
	var mandatory_markers := _get_checkout_right_markers()

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

	return route


func get_store_path_graph() -> StorePathGraph:
	if store._store_path_graph == null:
		store._store_path_graph = StorePathGraph.new(
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
	marker: Marker2D,
	fallback: Vector2
) -> Vector2:
	if marker == null:
		return fallback
	return marker.global_position


func _get_checkout_right_markers() -> Array[Marker2D]:
	var result: Array[Marker2D] = []

	if store == null or store.store_path_markers == null:
		return result

	for marker_name in CHECKOUT_RIGHT_ROUTE_MARKERS:
		var marker := store.store_path_markers.get_node_or_null(
			String(marker_name)
		) as Marker2D

		if marker == null:
			return []

		result.append(marker)

	return result


func _get_checkout_route_start_index(
	from_position: Vector2,
	markers: Array[Marker2D]
) -> int:
	var final_marker := markers.back()

	# Once the NPC has reached the bottom of the mandatory right lane, route
	# rebuilds must continue into the main graph instead of sending it back to
	# QueueFrontRight.
	if from_position.y >= final_marker.global_position.y - 4.0:
		return markers.size()

	var nearest_index := -1
	var nearest_distance := INF

	for index in range(markers.size()):
		var distance := from_position.distance_to(
			markers[index].global_position
		)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index

	if nearest_distance <= CHECKOUT_ROUTE_RESUME_DISTANCE:
		return mini(nearest_index + 1, markers.size())

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
