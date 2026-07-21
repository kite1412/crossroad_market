class_name StoreRuntimePathGraph
extends OptimizedStorePathGraph

## Store-only route operations that depend on customer state semantics.

const QUEUE_GRAPH_START_NODE_LIMIT: int = 6


func get_route_from_shelf_to_queue_target(
	shelf: Shelf,
	from_position: Vector2,
	queue_index: int
) -> Array[Vector2]:
	if (
		shelf == null
		or not is_instance_valid(shelf)
		or not from_position.is_finite()
	):
		return []

	var queue_target := get_queue_target_position(
		queue_index,
		from_position
	)
	if not queue_target.is_finite():
		return []

	var direct_candidates: Array[Dictionary] = []
	for route_variant in _make_route_variants(
		from_position,
		queue_target
	):
		var route := _variant_route_to_vector2_array(route_variant)
		if _is_shelf_queue_route_clear(
			from_position,
			route,
			shelf
		):
			_append_route_candidate(
				direct_candidates,
				from_position,
				route
			)

	var direct_route := _get_shortest_route(direct_candidates)
	if not direct_route.is_empty():
		return direct_route

	# Approach the assigned slot from its matching right-side marker. This keeps
	# Back1/Back2 customers out of QueueFront while preserving a predictable lane.
	var approach_node := _nav.get_queue_approach_node_name(queue_index)
	if approach_node == StringName():
		approach_node = _nav.get_queue_target_node_name(queue_index)
	if approach_node == StringName():
		return []

	var approach_marker: Marker2D = _nav.get_graph_marker(approach_node)
	if approach_marker == null:
		return []

	var candidates: Array[Dictionary] = []
	var start_nodes := super._get_nearest_graph_node_names_for_access(
		from_position,
		StringName(),
		QUEUE_GRAPH_START_NODE_LIMIT
	)
	for start_node in start_nodes:
		var start_marker: Marker2D = _nav.get_graph_marker(start_node)
		if start_marker == null:
			continue

		var graph_path := _nav.find_graph_path(start_node, approach_node)
		if graph_path.is_empty():
			continue

		var graph_route := _routes.build_route_from_graph_path(graph_path)
		for entry_route_variant in _make_route_variants(
			from_position,
			start_marker.global_position
		):
			var entry_route := _variant_route_to_vector2_array(
				entry_route_variant
			)
			var complete_route: Array[Vector2] = entry_route.duplicate()
			complete_route.append_array(graph_route)
			if (
				complete_route.is_empty()
				or complete_route.back().distance_to(
					approach_marker.global_position
				) > ROUTE_CLEARANCE_EPSILON
			):
				complete_route.append(approach_marker.global_position)
			complete_route.append(queue_target)
			complete_route = _routes.dedupe_route_points(complete_route)

			if not _is_shelf_queue_route_clear(
				from_position,
				complete_route,
				shelf
			):
				continue
			_append_route_candidate(
				candidates,
				from_position,
				complete_route
			)

	return _get_shortest_route(candidates)


func _is_shelf_queue_route_clear(
	from_position: Vector2,
	route: Array[Vector2],
	shelf: Shelf
) -> bool:
	return _clearance.is_checkout_route_from_access_clear(
		from_position,
		route,
		shelf,
		shelf.global_position
	)
