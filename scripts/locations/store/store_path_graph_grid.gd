extends RefCounted
class_name StorePathGraphGrid

## Orthogonal A* over the store placement/access grid.
## This is the canonical route solver for Stardew-like NPC movement: four
## neighbors only, Manhattan heuristic, and collision-checked connector legs.

const CONNECTOR_LIMIT: int = 8
const CONNECTOR_SCAN_LIMIT: int = 48

var _graph


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _init(graph = null) -> void:
	_graph = graph


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_route(
	from_position: Vector2,
	target_position: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> Dictionary:
	if (
		_graph == null
		or not from_position.is_finite()
		or not target_position.is_finite()
	):
		return {"valid": false}

	if _graph._shelf_access_points.is_empty():
		return {"valid": false}

	var start_connectors := _get_connector_candidates(
		from_position,
		shelf_object,
		shelf_position,
		npc_node,
		false
	)
	var goal_connectors := _get_connector_candidates(
		target_position,
		shelf_object,
		shelf_position,
		npc_node,
		true
	)

	var best_result: Dictionary = {"valid": false}
	var best_distance := INF
	var path_cache: Dictionary = {}

	for start_connector in start_connectors:
		var start_index := int(start_connector.get("index", -1))
		if start_index < 0:
			continue

		for goal_connector in goal_connectors:
			var goal_index := int(goal_connector.get("index", -1))
			if goal_index < 0:
				continue

			var grid_path := _find_anchor_path(
				start_index,
				goal_index,
				shelf_object,
				shelf_position,
				npc_node,
				path_cache
			)
			if grid_path.is_empty():
				continue

			var route := _variant_route_to_vector2_array(
				start_connector.get("route", [])
			)
			_append_anchor_path(route, grid_path)
			route.append_array(
				_variant_route_to_vector2_array(
					goal_connector.get("route_to_target", [])
				)
			)
			route = _graph._routes.dedupe_route_points(route)

			if not _graph._clearance.is_route_clear(
				from_position,
				route,
				shelf_object,
				shelf_position,
				npc_node
			):
				continue

			var distance: float = _graph._routes.get_route_distance(
				from_position,
				route
			)
			if distance >= best_distance:
				continue

			best_distance = distance
			best_result = {
				"valid": true,
				"route": route,
				"distance": distance,
				"source": "orthogonal_grid"
			}

	return best_result


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_connector_candidates(
	position: Vector2,
	shelf_object: Node2D,
	shelf_position: Vector2,
	npc_node: Node,
	reverse_route: bool
) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	var anchor_candidates: Array[Dictionary] = []

	for index in range(_graph._shelf_access_points.size()):
		var anchor: Vector2 = _graph._shelf_access_points[index]
		anchor_candidates.append({
			"index": index,
			"anchor": anchor,
			"distance": _manhattan(position, anchor)
		})

	anchor_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", INF)) < float(b.get("distance", INF))
	)

	var scanned_count := 0
	for anchor_entry in anchor_candidates:
		scanned_count += 1
		if scanned_count > CONNECTOR_SCAN_LIMIT:
			break

		var index: int = int(anchor_entry.get("index", -1))
		if index < 0:
			continue

		var anchor: Vector2 = anchor_entry.get("anchor", Vector2.INF) as Vector2
		if not anchor.is_finite():
			continue

		if not _graph._clearance.is_npc_access_point_clear(
			anchor,
			shelf_object,
			shelf_position,
			npc_node
		):
			continue

		for horizontal_first in [true, false]:
			var route: Array[Vector2] = _graph._routes.make_orthogonal_route(
				position,
				anchor,
				horizontal_first
			)
			if reverse_route:
				route = _graph._routes.make_orthogonal_route(
					anchor,
					position,
					horizontal_first
				)

			var clear_start: Vector2 = position if not reverse_route else anchor
			if not _graph._clearance.is_route_clear(
				clear_start,
				route,
				shelf_object,
				shelf_position,
				npc_node
			):
				continue

				var distance: float = _graph._routes.get_route_distance(
					clear_start,
					route
				)
				var route_from_start: Array[Vector2] = []
				var route_to_target: Array[Vector2] = []
				if reverse_route:
					route_to_target.assign(route)
					route_from_start.append(anchor)
				else:
					route_from_start.assign(route)

				ranked.append({
					"index": index,
					"route": route_from_start,
					"route_to_target": route_to_target,
					"distance": distance + _manhattan(position, anchor)
				})

	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", INF)) < float(b.get("distance", INF))
	)

	var result: Array[Dictionary] = []
	for entry in ranked:
		if result.size() >= CONNECTOR_LIMIT:
			break
		result.append(entry)
	return result


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _find_anchor_path(
	start_index: int,
	goal_index: int,
	shelf_object: Node2D,
	shelf_position: Vector2,
	npc_node: Node,
	path_cache: Dictionary
) -> Array[int]:
	var cache_key := "%d>%d" % [start_index, goal_index]
	if path_cache.has(cache_key):
		return (path_cache[cache_key] as Array[int]).duplicate()

	var result: Array[int] = []
	if start_index == goal_index:
		result.append(start_index)
		path_cache[cache_key] = result
		return result

	var goal_pos: Vector2 = _graph._shelf_access_points[goal_index]
	var frontier: Array[int] = [start_index]
	var g_score: Dictionary = {start_index: 0.0}
	var f_score: Dictionary = {
		start_index: _manhattan(
			_graph._shelf_access_points[start_index],
			goal_pos
		)
	}
	var previous: Dictionary = {}
	var visited: Dictionary = {}

	while not frontier.is_empty():
		var current: int = _pop_lowest_cost_node(frontier, f_score)
		if visited.has(current):
			continue

		visited[current] = true
		if current == goal_index:
			break

		var current_position: Vector2 = _graph._shelf_access_points[current]
		for neighbor in _get_axis_neighbors(
			current,
			shelf_object,
			shelf_position,
			npc_node
		):
			if visited.has(neighbor):
				continue

			var neighbor_position: Vector2 = _graph._shelf_access_points[neighbor]
			var next_cost: float = (
				float(g_score.get(current, 0.0))
				+ _manhattan(current_position, neighbor_position)
			)

			if g_score.has(neighbor) and next_cost >= float(g_score[neighbor]):
				continue

			g_score[neighbor] = next_cost
			f_score[neighbor] = next_cost + _manhattan(
				neighbor_position,
				goal_pos
			)
			previous[neighbor] = current
			if neighbor not in frontier:
				frontier.append(neighbor)

	if not g_score.has(goal_index):
		path_cache[cache_key] = result
		return result

	var cursor := goal_index
	while cursor != start_index:
		result.push_front(cursor)
		cursor = int(previous.get(cursor, -1))
		if cursor < 0:
			result.clear()
			path_cache[cache_key] = result
			return result

	result.push_front(start_index)
	path_cache[cache_key] = result
	return result


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_axis_neighbors(
	source_index: int,
	shelf_object: Node2D,
	shelf_position: Vector2,
	npc_node: Node
) -> Array[int]:
	var neighbors: Array[int] = []
	if _graph._surface == null:
		return neighbors

	var source_position: Vector2 = _graph._shelf_access_points[source_index]
	var static_neighbors: Array[int] = _graph._surface._get_surface_anchor_neighbors(
		source_index
	)
	for neighbor_index in static_neighbors:
		if neighbor_index < 0 or neighbor_index >= _graph._shelf_access_points.size():
			continue

		var neighbor_position: Vector2 = _graph._shelf_access_points[neighbor_index]
		if not _graph._clearance.is_route_segment_clear(
			source_position,
			neighbor_position,
			shelf_object,
			shelf_position,
			npc_node
		):
			continue

		neighbors.append(neighbor_index)

	return neighbors


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _append_axis_neighbor(
	neighbors: Array[int],
	source_index: int,
	source_position: Vector2,
	horizontal: bool,
	direction: float,
	shelf_object: Node2D,
	shelf_position: Vector2,
	npc_node: Node
) -> void:
	var best_index := -1
	var best_distance := INF

	for candidate_index in range(_graph._shelf_access_points.size()):
		if candidate_index == source_index:
			continue

		var candidate_position: Vector2 = _graph._shelf_access_points[candidate_index]
		var same_axis: bool = (
			absf(candidate_position.y - source_position.y)
			<= _graph.SURFACE_ALIGNMENT_EPSILON
			if horizontal
			else absf(candidate_position.x - source_position.x)
			<= _graph.SURFACE_ALIGNMENT_EPSILON
		)
		if not same_axis:
			continue

		var offset: float = (
			candidate_position.x - source_position.x
			if horizontal
			else candidate_position.y - source_position.y
		)
		if signf(offset) != signf(direction):
			continue

		var distance: float = absf(offset)
		if (
			distance <= _graph.SURFACE_ALIGNMENT_EPSILON
			or distance > _graph.SURFACE_NEIGHBOR_MAX_DISTANCE
			or distance >= best_distance
		):
			continue

		if not _graph._clearance.is_route_segment_clear(
			source_position,
			candidate_position,
			shelf_object,
			shelf_position,
			npc_node
		):
			continue

		best_index = candidate_index
		best_distance = distance

	if best_index >= 0 and best_index not in neighbors:
		neighbors.append(best_index)


func _append_anchor_path(route: Array[Vector2], path: Array[int]) -> void:
	for index in path:
		if index < 0 or index >= _graph._shelf_access_points.size():
			continue
		route.append(_graph._shelf_access_points[index])


func _variant_route_to_vector2_array(route_variant: Variant) -> Array[Vector2]:
	var route: Array[Vector2] = []
	if not (route_variant is Array):
		return route
	for point_variant in route_variant:
		if point_variant is Vector2:
			route.append(point_variant as Vector2)
	return route


func _manhattan(a: Vector2, b: Vector2) -> float:
	return absf(a.x - b.x) + absf(a.y - b.y)


func _pop_lowest_cost_node(frontier: Array[int], costs: Dictionary) -> int:
	var best_index := 0
	var best_cost := INF
	for index in range(frontier.size()):
		var node := frontier[index]
		var cost := float(costs.get(node, INF))
		if cost < best_cost:
			best_cost = cost
			best_index = index
	return frontier.pop_at(best_index)
