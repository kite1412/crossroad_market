class_name StoreRuntimePathGraph
extends OptimizedStorePathGraph

## Store-only route operations that depend on customer state semantics.

const QUEUE_GRAPH_START_NODE_LIMIT: int = 6
const QUEUE_APPROACH_CONNECTOR_LIMIT: int = 4


func get_shelf_access_position(shelf: Shelf) -> Vector2:
	# StorePathGraphBase falls back to the exhaustive planner when metadata is
	# absent. Runtime reads must never trigger that synchronous fallback; metadata
	# is produced explicitly by the bounded placement/warmup flow.
	if shelf == null or not is_instance_valid(shelf):
		return Vector2.INF
	if not has_cached_shelf_access_metadata(shelf):
		return Vector2.INF

	var stored_access: Variant = shelf.get_meta(
		ACCESS_META,
		Vector2.INF
	)
	if stored_access is Vector2:
		return stored_access as Vector2
	return Vector2.INF


func get_route_from_shelf_to_queue_target(
	shelf: Shelf,
	from_position: Vector2,
	queue_index: int,
	npc_node: Node = null
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
			shelf,
			npc_node
		):
			_append_route_candidate(
				direct_candidates,
				from_position,
				route
			)

	var direct_route := _get_shortest_route(direct_candidates)
	if not direct_route.is_empty():
		return direct_route

	# Approach the assigned slot from its matching right-side marker. Back1/Back2
	# customers therefore never need QueueFront as an intermediate waypoint.
	var approach_node := _nav.get_queue_approach_node_name(queue_index)
	if approach_node == StringName():
		approach_node = _nav.get_queue_target_node_name(queue_index)
	if approach_node == StringName():
		return []

	var approach_marker: Marker2D = _nav.get_graph_marker(approach_node)
	if approach_marker == null:
		return []

	# Queue markers are intentionally excluded from normal graph edges. Connect
	# the assigned approach marker to a few nearby non-queue graph nodes instead
	# of asking A* to use the queue marker as a graph goal.
	var approach_connectors := super._get_nearest_graph_node_names_for_access(
		approach_marker.global_position,
		StringName(),
		QUEUE_APPROACH_CONNECTOR_LIMIT
	)
	var start_nodes := super._get_nearest_graph_node_names_for_access(
		from_position,
		StringName(),
		QUEUE_GRAPH_START_NODE_LIMIT
	)
	var candidates: Array[Dictionary] = []

	for start_node in start_nodes:
		var start_marker: Marker2D = _nav.get_graph_marker(start_node)
		if start_marker == null:
			continue

		for connector_node in approach_connectors:
			var connector_marker: Marker2D = _nav.get_graph_marker(
				connector_node
			)
			if connector_marker == null:
				continue

			var graph_path := _nav.find_graph_path(
				start_node,
				connector_node
			)
			if graph_path.is_empty():
				continue

			var graph_route := _routes.build_route_from_graph_path(
				graph_path
			)
			for entry_route_variant in _make_route_variants(
				from_position,
				start_marker.global_position
			):
				var entry_route := _variant_route_to_vector2_array(
					entry_route_variant
				)

				for approach_route_variant in _make_route_variants(
					connector_marker.global_position,
					approach_marker.global_position
				):
					var approach_route := _variant_route_to_vector2_array(
						approach_route_variant
					)
					var complete_route: Array[Vector2] = entry_route.duplicate()
					complete_route.append_array(graph_route)
					if (
						complete_route.is_empty()
						or complete_route.back().distance_to(
							connector_marker.global_position
						) > ROUTE_CLEARANCE_EPSILON
					):
						complete_route.append(
							connector_marker.global_position
						)

					complete_route.append_array(approach_route)
					complete_route.append(queue_target)
					complete_route = _routes.dedupe_route_points(
						complete_route
					)

					if not _is_shelf_queue_route_clear(
						from_position,
						complete_route,
						shelf,
						npc_node
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
	shelf: Shelf,
	npc_node: Node
) -> bool:
	# This variant ignores the source overlap, the assigned slot endpoint, the
	# source shelf body, and the moving NPC's own collider.
	return _clearance.is_route_to_access_clear(
		from_position,
		route,
		shelf,
		npc_node
	)
