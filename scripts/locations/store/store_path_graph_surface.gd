extends RefCounted
class_name StorePathGraphSurface

## Surface-graph pathfinding for StorePathGraph.
## Handles A* over _shelf_access_points and neighbor caching.

@warning_ignore("unused_private_class_variable")
var _graph  # StorePathGraph – untyped to avoid cyclic class_name reference


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _init(graph = null) -> void:
	_graph = graph


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_surface_route_between_marker_and_access(
	graph_node: StringName,
	access_point: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	surface_searches: Array = [],
	surface_route_cache: Dictionary = {},
	surface_anchor_path_cache: Dictionary = {}
) -> Dictionary:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var cache_key := _get_surface_route_cache_key(graph_node, access_point)

	if surface_route_cache.has(cache_key):
		return surface_route_cache[cache_key].duplicate(true)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var debug_start_usec := Time.get_ticks_usec()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var initial_surface_searches := int(surface_searches[0]) if not surface_searches.is_empty() else 0
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var marker: Marker2D = _graph._nav.get_graph_marker(graph_node)

	if marker == null or not access_point.is_finite():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var missing_result := {"valid": false}
		surface_route_cache[cache_key] = missing_result
		pass
		return missing_result.duplicate(true)

	if _graph._shelf_access_points.is_empty():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var empty_result := {"valid": false}
		surface_route_cache[cache_key] = empty_result
		pass
		return empty_result.duplicate(true)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var marker_position := marker.global_position
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var access_indices := _get_nearest_surface_anchor_indices(
		access_point,
		_graph.SURFACE_CONNECTOR_LIMIT,
		shelf_object,
		shelf_position
	)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var marker_indices := _get_nearest_surface_anchor_indices(
		marker_position,
		_graph.SURFACE_CONNECTOR_LIMIT,
		shelf_object,
		shelf_position
	)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_route: Array[Vector2] = []
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_distance := INF

	for marker_index in marker_indices:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var marker_anchor: Vector2 = _graph._shelf_access_points[marker_index]
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var marker_route: Array[Vector2] = _graph._routes.make_orthogonal_route(marker_position, marker_anchor, true)

		if not _graph._clearance.is_route_clear(marker_position, marker_route, shelf_object, shelf_position):
			continue

		for access_index in access_indices:
			if not _reserve_surface_route_search(surface_searches):
				@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
				var search_limit_result := {"valid": false}
				surface_route_cache[cache_key] = search_limit_result
				pass
				return search_limit_result.duplicate(true)

			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var access_anchor: Vector2 = _graph._shelf_access_points[access_index]
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var access_route: Array[Vector2] = _graph._routes.make_orthogonal_route(access_anchor, access_point, true)

			if not _graph._clearance.is_route_clear(access_anchor, access_route, shelf_object, shelf_position):
				continue

			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var surface_path := _find_surface_anchor_path(
				marker_index,
				access_index,
				shelf_object,
				shelf_position,
				surface_anchor_path_cache
			)

			if surface_path.is_empty():
				continue

			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var route := marker_route.duplicate()
			_append_surface_anchor_path_to_route(route, surface_path)
			route.append_array(access_route)
			route = _graph._routes.dedupe_route_points(route)

			if route.is_empty() or not _graph._clearance.is_route_clear(marker_position, route, shelf_object, shelf_position):
				continue

			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var distance: float = _graph._routes.get_route_distance(marker_position, route)

			if distance < best_distance:
				best_distance = distance
				best_route = route

	if best_route.is_empty():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var no_route_result := {"valid": false}
		surface_route_cache[cache_key] = no_route_result
		pass
		return no_route_result.duplicate(true)

	pass

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var result := {
		"valid": true,
		"node": graph_node,
		"route": best_route,
		"distance": best_distance
	}
	surface_route_cache[cache_key] = result
	return result.duplicate(true)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _reserve_surface_route_search(surface_searches: Array) -> bool:
	if surface_searches.is_empty():
		return true

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var current := int(surface_searches[0])

	if current >= _graph.MAX_SURFACE_ROUTE_SEARCHES:
		return false

	surface_searches[0] = current + 1
	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_nearest_surface_anchor_indices(
	position: Vector2,
	limit: int,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF
) -> Array[int]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var indices: Array[int] = []

	if not position.is_finite():
		return indices

	for index in range(_graph._shelf_access_points.size()):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var point: Vector2 = _graph._shelf_access_points[index]

		if not _graph._clearance.is_npc_access_point_clear(point, shelf_object, shelf_position):
			continue

		indices.append(index)

	indices.sort_custom(func(a: int, b: int) -> bool:
		return _graph._shelf_access_points[a].distance_to(position) < _graph._shelf_access_points[b].distance_to(position)
	)

	if indices.size() <= limit:
		return indices

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var limited: Array[int] = []

	for index in range(limit):
		limited.append(indices[index])

	return limited


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _find_surface_anchor_path(
	start_index: int,
	goal_index: int,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	surface_anchor_path_cache: Dictionary = {}
) -> Array[int]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var cache_key := _get_surface_anchor_path_cache_key(start_index, goal_index)

	if surface_anchor_path_cache.has(cache_key):
		return (surface_anchor_path_cache[cache_key] as Array[int]).duplicate()

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var result: Array[int] = []

	if start_index < 0 or goal_index < 0:
		surface_anchor_path_cache[cache_key] = result
		return result

	if start_index >= _graph._shelf_access_points.size() or goal_index >= _graph._shelf_access_points.size():
		surface_anchor_path_cache[cache_key] = result
		return result

	if start_index == goal_index:
		result.append(start_index)
		surface_anchor_path_cache[cache_key] = result
		return result

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var frontier: Array[int] = [start_index]
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var g_score := {start_index: 0.0}
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var goal_pos: Vector2 = _graph._shelf_access_points[goal_index]
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var f_score: Dictionary = {start_index: _graph._shelf_access_points[start_index].distance_to(goal_pos)}
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var previous := {}
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var visited := {}

	while not frontier.is_empty():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var current := _pop_lowest_cost_surface_node(frontier, f_score)

		if visited.has(current):
			continue

		visited[current] = true

		if current == goal_index:
			break

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var current_position: Vector2 = _graph._shelf_access_points[current]

		for neighbor in _get_surface_anchor_neighbors(current):
			if visited.has(neighbor):
				continue

			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var neighbor_position: Vector2 = _graph._shelf_access_points[neighbor]

			if not _graph._clearance.is_route_segment_clear(current_position, neighbor_position, shelf_object, shelf_position):
				continue

			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var edge_cost := current_position.distance_to(neighbor_position)
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var next_cost: float = float(g_score.get(current, 0.0)) + edge_cost

			if not g_score.has(neighbor) or next_cost < float(g_score[neighbor]):
				g_score[neighbor] = next_cost
				@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
				var h_cost: float = neighbor_position.distance_to(goal_pos)
				f_score[neighbor] = next_cost + h_cost
				previous[neighbor] = current

				if neighbor not in frontier:
					frontier.append(neighbor)

	if not g_score.has(goal_index):
		surface_anchor_path_cache[cache_key] = result
		return result

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var cursor := goal_index

	while cursor != start_index:
		result.push_front(cursor)
		cursor = int(previous.get(cursor, -1))

		if cursor < 0:
			result.clear()
			surface_anchor_path_cache[cache_key] = result
			return result

	result.push_front(start_index)
	surface_anchor_path_cache[cache_key] = result
	return result


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _append_surface_anchor_path_to_route(route: Array[Vector2], path: Array[int]) -> void:
	for index in path:
		if index < 0 or index >= _graph._shelf_access_points.size():
			continue

		route.append(_graph._shelf_access_points[index])


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_surface_anchor_neighbors(index: int) -> Array[int]:
	_ensure_surface_neighbor_cache()

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var raw_neighbors: Variant = _graph._surface_neighbor_cache.get(index, [])
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var neighbors: Array[int] = []

	if raw_neighbors is Array:
		for neighbor in raw_neighbors:
			if neighbor is int:
				neighbors.append(neighbor)

	return neighbors


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ensure_surface_neighbor_cache() -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var signature: String = _graph._get_surface_points_signature(_graph._shelf_access_points)

	if _graph._surface_neighbor_signature == signature:
		return

	_graph._surface_neighbor_cache.clear()
	_graph._surface_neighbor_signature = signature

	for index in range(_graph._shelf_access_points.size()):
		_graph._surface_neighbor_cache[index] = _find_axis_surface_neighbors(index)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _find_axis_surface_neighbors(source_index: int) -> Array[int]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var neighbors: Array[int] = []

	if source_index < 0 or source_index >= _graph._shelf_access_points.size():
		return neighbors

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var source_position: Vector2 = _graph._shelf_access_points[source_index]
	_append_surface_axis_neighbor(neighbors, source_index, source_position, true, -1.0)
	_append_surface_axis_neighbor(neighbors, source_index, source_position, true, 1.0)
	_append_surface_axis_neighbor(neighbors, source_index, source_position, false, -1.0)
	_append_surface_axis_neighbor(neighbors, source_index, source_position, false, 1.0)
	return neighbors


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _append_surface_axis_neighbor(
	neighbors: Array[int],
	source_index: int,
	source_position: Vector2,
	horizontal: bool,
	direction: float
) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_index := -1
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_distance := INF

	for candidate_index in range(_graph._shelf_access_points.size()):
		if candidate_index == source_index:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var candidate_position: Vector2 = _graph._shelf_access_points[candidate_index]
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var same_axis: bool = (
			absf(candidate_position.y - source_position.y) <= _graph.SURFACE_ALIGNMENT_EPSILON
			if horizontal
			else absf(candidate_position.x - source_position.x) <= _graph.SURFACE_ALIGNMENT_EPSILON
		)

		if not same_axis:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var offset: float = (
			candidate_position.x - source_position.x
			if horizontal
			else candidate_position.y - source_position.y
		)

		if signf(offset) != signf(direction):
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var distance := absf(offset)

		if distance <= _graph.SURFACE_ALIGNMENT_EPSILON or distance > _graph.SURFACE_NEIGHBOR_MAX_DISTANCE:
			continue

		if distance >= best_distance:
			continue

		if not _graph._clearance.is_route_segment_clear(source_position, candidate_position):
			continue

		best_index = candidate_index
		best_distance = distance

	if best_index >= 0 and best_index not in neighbors:
		neighbors.append(best_index)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _pop_lowest_cost_surface_node(frontier: Array[int], distances: Dictionary) -> int:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_index := 0
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_cost := INF

	for index in range(frontier.size()):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var node_index := frontier[index]
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var cost := float(distances.get(node_index, INF))

		if cost < best_cost:
			best_cost = cost
			best_index = index

	return frontier.pop_at(best_index)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_surface_route_cache_key(graph_node: StringName, access_point: Vector2) -> String:
	return "%s:%d,%d" % [str(graph_node), roundi(access_point.x), roundi(access_point.y)]


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_surface_anchor_path_cache_key(start_index: int, goal_index: int) -> String:
	return "%d:%d" % [start_index, goal_index]
