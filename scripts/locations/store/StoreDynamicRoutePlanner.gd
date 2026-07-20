class_name StoreDynamicRoutePlanner
extends RefCounted

const MAX_GRAPH_NODE_CANDIDATES: int = 12
const POINT_EPSILON: float = 2.0

var store: Node = null


func setup(store_node: Node) -> void:
	store = store_node


func get_route_to_shelf_access(
	graph: StorePathGraph,
	shelf: Shelf,
	from_position: Vector2,
	npc_node: Node = null
) -> Array[Vector2]:
	if graph == null or shelf == null or not is_instance_valid(shelf):
		return []

	var access_position := graph.get_shelf_access_position(shelf)
	if not access_position.is_finite() or not from_position.is_finite():
		return []

	var candidates: Array[Dictionary] = []
	_append_shelf_direct_candidates(
		candidates,
		graph,
		shelf,
		from_position,
		access_position,
		npc_node
	)

	var preferred_node := graph.get_shelf_access_graph_node(shelf)
	for target_node in _get_ranked_graph_nodes(
		graph,
		access_position,
		preferred_node,
		false
	):
		var graph_result: Dictionary = graph._nav.find_nearest_reachable_graph_node_for_route(
			from_position,
			target_node
		)
		if not bool(graph_result.get("valid", false)):
			continue

		var graph_route := _variant_route_to_vector2_array(
			graph_result.get("route", [])
		)
		for horizontal_first in [true, false]:
			var route := graph_route.duplicate()
			var route_end := from_position
			if not route.is_empty():
				route_end = route.back()
			route.append_array(
				graph._routes.make_orthogonal_route(
					route_end,
					access_position,
					horizontal_first
				)
			)
			route = graph._routes.dedupe_route_points(route)

			if not graph._clearance.is_route_to_access_clear(
				from_position,
				route,
				shelf,
				npc_node
			):
				continue

			_append_route_candidate(
				candidates,
				graph,
				from_position,
				route,
				"graph_to_shelf"
			)

	return _get_shortest_route(candidates)


func get_shortest_checkout_route(
	graph: StorePathGraph,
	from_position: Vector2,
	source_shelf: Shelf = null
) -> Array[Vector2]:
	if graph == null or not from_position.is_finite():
		return []

	var candidates: Array[Dictionary] = []
	var checkout_nodes: Array[StringName] = graph._nav.get_checkout_goal_node_names()

	for checkout_node in checkout_nodes:
		var checkout_marker: Marker2D = graph._nav.get_graph_marker(checkout_node)
		if checkout_marker == null:
			continue

		_append_checkout_direct_candidates(
			candidates,
			graph,
			from_position,
			checkout_marker.global_position,
			source_shelf,
			"direct_%s" % String(checkout_node)
		)

	if source_shelf == null:
		for checkout_node in checkout_nodes:
			var graph_result: Dictionary = graph._nav.find_nearest_reachable_graph_node_for_route(
				from_position,
				checkout_node
			)
			if not bool(graph_result.get("valid", false)):
				continue

			var route := _variant_route_to_vector2_array(
				graph_result.get("route", [])
			)
			if not graph._clearance.is_route_clear_from_current_position(
				from_position,
				route
			):
				continue

			_append_route_candidate(
				candidates,
				graph,
				from_position,
				route,
				"graph_checkout"
			)
	else:
		_append_shelf_graph_checkout_candidates(
			candidates,
			graph,
			from_position,
			source_shelf,
			checkout_nodes
		)

	return _get_shortest_route(candidates)


func _append_shelf_direct_candidates(
	candidates: Array[Dictionary],
	graph: StorePathGraph,
	shelf: Shelf,
	from_position: Vector2,
	access_position: Vector2,
	npc_node: Node
) -> void:
	var direct_route: Array[Vector2] = [access_position]
	if graph._clearance.is_route_to_access_clear(
		from_position,
		direct_route,
		shelf,
		npc_node
	):
		_append_route_candidate(
			candidates,
			graph,
			from_position,
			direct_route,
			"direct_diagonal_to_shelf"
		)

	for horizontal_first in [true, false]:
		var route := graph._routes.make_orthogonal_route(
			from_position,
			access_position,
			horizontal_first
		)
		if not graph._clearance.is_route_to_access_clear(
			from_position,
			route,
			shelf,
			npc_node
		):
			continue

		_append_route_candidate(
			candidates,
			graph,
			from_position,
			route,
			"orthogonal_to_shelf"
		)


func _append_checkout_direct_candidates(
	candidates: Array[Dictionary],
	graph: StorePathGraph,
	from_position: Vector2,
	target_position: Vector2,
	source_shelf: Shelf,
	source_label: String
) -> void:
	var diagonal_route: Array[Vector2] = [target_position]
	if _is_checkout_route_clear(
		graph,
		from_position,
		diagonal_route,
		source_shelf
	):
		_append_route_candidate(
			candidates,
			graph,
			from_position,
			diagonal_route,
			"%s_diagonal" % source_label
		)

	for horizontal_first in [true, false]:
		var route := graph._routes.make_orthogonal_route(
			from_position,
			target_position,
			horizontal_first
		)
		if not _is_checkout_route_clear(
			graph,
			from_position,
			route,
			source_shelf
		):
			continue

		_append_route_candidate(
			candidates,
			graph,
			from_position,
			route,
			"%s_orthogonal" % source_label
		)


func _append_shelf_graph_checkout_candidates(
	candidates: Array[Dictionary],
	graph: StorePathGraph,
	from_position: Vector2,
	source_shelf: Shelf,
	checkout_nodes: Array[StringName]
) -> void:
	var preferred_node := graph.get_shelf_access_graph_node(source_shelf)
	var graph_nodes := _get_ranked_graph_nodes(
		graph,
		from_position,
		preferred_node,
		false
	)

	for start_node in graph_nodes:
		var start_marker: Marker2D = graph._nav.get_graph_marker(start_node)
		if start_marker == null:
			continue

		for horizontal_first in [true, false]:
			var start_route := graph._routes.make_orthogonal_route(
				from_position,
				start_marker.global_position,
				horizontal_first
			)
			if not graph._clearance.is_checkout_route_from_access_clear(
				from_position,
				start_route,
				source_shelf,
				source_shelf.global_position
			):
				continue

			for checkout_node in checkout_nodes:
				var graph_path: Array[StringName] = graph._nav.find_graph_path(
					start_node,
					checkout_node
				)
				if graph_path.is_empty():
					continue

				var route := start_route.duplicate()
				route.append_array(
					graph._routes.build_route_from_graph_path(graph_path)
				)
				route = graph._routes.dedupe_route_points(route)

				if not graph._clearance.is_checkout_route_from_access_clear(
					from_position,
					route,
					source_shelf,
					source_shelf.global_position
				):
					continue

				_append_route_candidate(
					candidates,
					graph,
					from_position,
					route,
					"shelf_graph_checkout"
				)


func _is_checkout_route_clear(
	graph: StorePathGraph,
	from_position: Vector2,
	route: Array[Vector2],
	source_shelf: Shelf
) -> bool:
	if source_shelf != null and is_instance_valid(source_shelf):
		return graph._clearance.is_checkout_route_from_access_clear(
			from_position,
			route,
			source_shelf,
			source_shelf.global_position
		)

	return graph._clearance.is_route_clear_from_current_position(
		from_position,
		route
	)


func _get_ranked_graph_nodes(
	graph: StorePathGraph,
	position: Vector2,
	preferred_node: StringName,
	include_queue_nodes: bool
) -> Array[StringName]:
	var ranked: Array[Dictionary] = []

	for node_name in graph._nav.get_graph_node_names():
		if not include_queue_nodes and graph._nav.is_queue_target_node(node_name):
			continue

		var graph_marker: Marker2D = graph._nav.get_graph_marker(node_name)
		if graph_marker == null:
			continue

		ranked.append({
			"node": node_name,
			"distance": position.distance_to(graph_marker.global_position)
		})

	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", INF)) < float(b.get("distance", INF))
	)

	var result: Array[StringName] = []
	if preferred_node != StringName():
		result.append(preferred_node)

	for entry in ranked:
		if result.size() >= MAX_GRAPH_NODE_CANDIDATES:
			break

		var node_name := entry.get("node", StringName()) as StringName
		if node_name == StringName() or node_name in result:
			continue
		result.append(node_name)

	return result


func _append_route_candidate(
	candidates: Array[Dictionary],
	graph: StorePathGraph,
	from_position: Vector2,
	route: Array[Vector2],
	source: String
) -> void:
	var clean_route := graph._routes.dedupe_route_points(route)
	if clean_route.is_empty():
		return

	for point in clean_route:
		if not point.is_finite():
			return

	candidates.append({
		"route": clean_route,
		"distance": graph._routes.get_route_distance(
			from_position,
			clean_route
		),
		"source": source
	})


func _get_shortest_route(candidates: Array[Dictionary]) -> Array[Vector2]:
	var best_route: Array[Vector2] = []
	var best_distance := INF

	for candidate in candidates:
		var distance := float(candidate.get("distance", INF))
		if distance >= best_distance:
			continue

		best_distance = distance
		best_route = _variant_route_to_vector2_array(
			candidate.get("route", [])
		)

	return best_route


func _variant_route_to_vector2_array(route_variant: Variant) -> Array[Vector2]:
	var route: Array[Vector2] = []
	if not (route_variant is Array):
		return route

	for point_variant in route_variant:
		if point_variant is Vector2:
			var point := point_variant as Vector2
			if route.is_empty() or route.back().distance_to(point) > POINT_EPSILON:
				route.append(point)

	return route
