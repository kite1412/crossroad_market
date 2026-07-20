extends RefCounted
class_name StorePathGraphGraph

## Graph navigation functions for StorePathGraph.
## Handles marker lookups, A* pathfinding, neighbor discovery, and queue logic.

var _graph  # StorePathGraph – untyped to avoid cyclic class_name reference


func _init(graph = null) -> void:
	_graph = graph


# ---------------------------------------------------------------------------
#  Marker lookups
# ---------------------------------------------------------------------------

func get_graph_marker(node_name: StringName) -> Marker2D:
	if _graph._markers == null:
		return null

	return _graph._markers.get_node_or_null(String(node_name)) as Marker2D


func get_marker_position(node_name: StringName) -> Vector2:
	var marker := get_graph_marker(node_name)
	return marker.global_position if marker != null else Vector2.INF


func get_markers_by_role(role: StringName) -> Array[Marker2D]:
	var results: Array[Marker2D] = []
	if _graph._markers == null or not is_instance_valid(_graph._markers):
		return results

	for child in _graph._markers.get_children():
		var marker := child as Marker2D
		if marker != null and marker.has_meta("store_path_role"):
			var marker_role = marker.get_meta("store_path_role")
			if str(marker_role) == str(role):
				results.append(marker)

	return results


func get_graph_node_names() -> Array[StringName]:
	var node_names: Array[StringName] = []

	if _graph._markers == null:
		return node_names

	if _graph._cached_graph_node_count == _graph._markers.get_child_count():
		return _graph._cached_graph_node_names.duplicate()

	for child in _graph._markers.get_children():
		if child is Marker2D:
			node_names.append(StringName(child.name))

	node_names.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b)
	)

	_graph._cached_graph_node_names = node_names
	_graph._cached_graph_node_count = _graph._markers.get_child_count()
	return node_names


func get_marker_role(marker: Marker2D) -> StringName:
	if marker == null or not marker.has_meta(_graph.PATH_ROLE_META):
		return StringName()

	var role: Variant = marker.get_meta(_graph.PATH_ROLE_META)

	if role is StringName:
		return role as StringName

	if role is String:
		return StringName(role)

	return StringName()


func is_shelf_access_marker(marker: Marker2D) -> bool:
	if marker == null:
		return false

	var role := get_marker_role(marker)

	if role == _graph.ROLE_QUEUE_FRONT or role == _graph.ROLE_QUEUE_BACK or role == _graph.ROLE_CASHIER:
		return false

	if bool(marker.get_meta(_graph.SHELF_ANCHOR_META, false)):
		return true

	return role == _graph.ROLE_ENTRY or role == _graph.ROLE_EXIT


func get_role_node_name(role: StringName, fallback_node_name: StringName = StringName()) -> StringName:
	for node_name in get_graph_node_names():
		var marker := get_graph_marker(node_name)

		if get_marker_role(marker) == role:
			return node_name

	if fallback_node_name != StringName() and get_graph_marker(fallback_node_name) != null:
		return fallback_node_name

	return StringName()


func get_checkout_goal_node_names() -> Array[StringName]:
	var goals: Array[StringName] = []

	for role in _graph.CHECKOUT_GOAL_ROLES:
		for node_name in get_graph_node_names():
			if get_marker_role(get_graph_marker(node_name)) == role and node_name not in goals:
				goals.append(node_name)

	if goals.is_empty() and get_graph_marker(_graph.QUEUE_FRONT) != null:
		goals.append(_graph.QUEUE_FRONT)

	if get_graph_marker(_graph.CASHIER) != null and _graph.CASHIER not in goals:
		goals.append(_graph.CASHIER)

	return goals


# ---------------------------------------------------------------------------
#  Queue node helpers
# ---------------------------------------------------------------------------

func get_queue_target_node_name(queue_index: int) -> StringName:
	if queue_index <= 0:
		return get_role_node_name(_graph.ROLE_QUEUE_FRONT, _graph.QUEUE_FRONT)

	var queue_back_nodes := get_queue_back_node_names()

	if queue_back_nodes.is_empty():
		return get_role_node_name(_graph.ROLE_QUEUE_FRONT, _graph.QUEUE_FRONT)

	var back_index := mini(queue_index - 1, queue_back_nodes.size() - 1)
	return queue_back_nodes[back_index]


func get_queue_approach_node_name(queue_index: int) -> StringName:
	if queue_index <= 0:
		return get_role_node_name(_graph.ROLE_QUEUE_FRONT_RIGHT, StringName())

	var queue_back_right_nodes := get_queue_back_right_node_names()

	if queue_back_right_nodes.is_empty():
		return get_role_node_name(_graph.ROLE_QUEUE_FRONT_RIGHT, StringName())

	var back_index := mini(queue_index - 1, queue_back_right_nodes.size() - 1)
	return queue_back_right_nodes[back_index]


func get_queue_back_node_names() -> Array[StringName]:
	var queue_back_nodes: Array[StringName] = []

	for node_name in get_graph_node_names():
		if get_marker_role(get_graph_marker(node_name)) == _graph.ROLE_QUEUE_BACK:
			queue_back_nodes.append(node_name)

	queue_back_nodes.sort_custom(func(a: StringName, b: StringName) -> bool:
		return get_queue_marker_index(a) < get_queue_marker_index(b)
	)

	return queue_back_nodes


func get_queue_back_right_node_names() -> Array[StringName]:
	var queue_back_right_nodes: Array[StringName] = []

	for node_name in get_graph_node_names():
		if get_marker_role(get_graph_marker(node_name)) == _graph.ROLE_QUEUE_BACK_RIGHT:
			queue_back_right_nodes.append(node_name)

	queue_back_right_nodes.sort_custom(func(a: StringName, b: StringName) -> bool:
		return get_queue_marker_index(a) < get_queue_marker_index(b)
	)

	return queue_back_right_nodes


func get_queue_right_node_names() -> Array[StringName]:
	var queue_right_nodes: Array[StringName] = []

	var queue_front_right: StringName = get_role_node_name(_graph.ROLE_QUEUE_FRONT_RIGHT, StringName())

	if queue_front_right != StringName():
		queue_right_nodes.append(queue_front_right)

	queue_right_nodes.append_array(get_queue_back_right_node_names())
	queue_right_nodes.sort_custom(func(a: StringName, b: StringName) -> bool:
		return get_queue_marker_index(a) < get_queue_marker_index(b)
	)
	return queue_right_nodes


func get_nearest_queue_right_node_name(position: Vector2) -> StringName:
	var best_node := StringName()
	var best_distance := INF

	for node_name in get_queue_right_node_names():
		var marker := get_graph_marker(node_name)

		if marker == null:
			continue

		var distance := position.distance_to(marker.global_position)

		if distance >= best_distance:
			continue

		best_node = node_name
		best_distance = distance

	return best_node


func get_queue_marker_index(node_name: StringName) -> int:
	var marker := get_graph_marker(node_name)

	if marker == null or not marker.has_meta(&"store_queue_index"):
		return 999

	return int(marker.get_meta(&"store_queue_index"))


func is_queue_target_node(node_name: StringName) -> bool:
	var role := get_marker_role(get_graph_marker(node_name))
	return (
		role == _graph.ROLE_QUEUE_FRONT
		or role == _graph.ROLE_QUEUE_BACK
		or role == _graph.ROLE_QUEUE_FRONT_RIGHT
		or role == _graph.ROLE_QUEUE_BACK_RIGHT
	)


# ---------------------------------------------------------------------------
#  Graph pathfinding (A*)
# ---------------------------------------------------------------------------

func find_graph_path(start_node: StringName, goal_node: StringName) -> Array[StringName]:
	var result: Array[StringName] = []

	if start_node == StringName() or goal_node == StringName():
		return result

	var goal_position := get_marker_position(goal_node)
	var frontier: Array[StringName] = [start_node]
	var g_score := {start_node: 0.0}
	var f_score: Dictionary = {start_node: _graph._routes.get_euclidean_distance(get_marker_position(start_node), goal_position)}
	var previous := {}
	var visited := {}

	while not frontier.is_empty():
		var current := _pop_lowest_cost_node(frontier, f_score)

		if visited.has(current):
			continue

		visited[current] = true

		if current == goal_node:
			break

		for neighbor in get_graph_neighbors(current):
			if visited.has(neighbor):
				continue

			if neighbor != goal_node and is_queue_target_node(neighbor):
				continue

			var edge_cost := get_graph_edge_cost(current, neighbor)

			if edge_cost >= INF:
				continue

			var next_g := float(g_score[current]) + edge_cost

			if not g_score.has(neighbor) or next_g < float(g_score[neighbor]):
				g_score[neighbor] = next_g
				f_score[neighbor] = next_g + _graph._routes.get_euclidean_distance(get_marker_position(neighbor), goal_position)
				previous[neighbor] = current

				if neighbor not in frontier:
					frontier.append(neighbor)

	if not g_score.has(goal_node):
		return result

	var cursor := goal_node

	while cursor != start_node:
		result.push_front(cursor)
		cursor = previous.get(cursor, StringName()) as StringName

		if cursor == StringName():
			result.clear()
			return result

	result.push_front(start_node)
	return result


func find_checkout_graph_path(start_node: StringName) -> Array[StringName]:
	return find_best_graph_path(start_node, get_checkout_goal_node_names())


func find_best_graph_path(start_node: StringName, goal_nodes: Array[StringName]) -> Array[StringName]:
	var best_path: Array[StringName] = []
	var best_cost := INF

	for goal_node in goal_nodes:
		var path := find_graph_path(start_node, goal_node)

		if path.is_empty():
			continue

		var cost := get_graph_path_cost(path)

		if cost < best_cost:
			best_cost = cost
			best_path = path

	return best_path


func find_nearest_graph_node(position: Vector2) -> Dictionary:
	var best_result := {"valid": false}
	var best_score := INF

	for node_name in get_graph_node_names():
		var marker := get_graph_marker(node_name)

		if marker == null:
			continue

		var distance: float = _graph._routes.get_euclidean_distance(position, marker.global_position)

		if distance < best_score:
			best_score = distance
			best_result = {
				"valid": true,
				"node": node_name,
				"route": _graph._routes.make_orthogonal_route(position, marker.global_position, true),
				"distance": distance
			}

	return best_result


func find_nearest_reachable_graph_node_for_route(position: Vector2, goal_node: StringName) -> Dictionary:
	var goal_marker := get_graph_marker(goal_node)

	if goal_marker == null:
		return {"valid": false}

	var best_result := {"valid": false}
	var best_score := INF

	for node_name in get_graph_node_names():
		var marker := get_graph_marker(node_name)

		if marker == null:
			continue

		var entry_route: Array[Vector2] = _graph._routes.make_orthogonal_route(position, marker.global_position, true)

		if not _graph._clearance.is_route_clear_from_current_position(position, entry_route):
			pass
			continue

		var graph_path := find_graph_path(node_name, goal_node)

		if graph_path.is_empty():
			pass
			continue

		var route := entry_route.duplicate()
		route.append_array(_graph._routes.build_route_from_graph_path(graph_path))
		route = _graph._routes.dedupe_route_points(route)

		if is_queue_target_node(goal_node):
			if not _graph._clearance.is_queue_route_clear_from_current_position(position, route):
				pass
				continue
		elif not _graph._clearance.is_route_clear_from_current_position(position, route):
			pass
			continue

		var score: float = _graph._routes.get_route_distance(position, route)
		pass

		if score >= best_score:
			continue

		best_score = score
		best_result = {
			"valid": true,
			"node": node_name,
			"route": route,
			"distance": score
			}

	return best_result


# ---------------------------------------------------------------------------
#  Graph neighbor discovery
# ---------------------------------------------------------------------------

func get_graph_neighbors(node_name: StringName) -> Array[StringName]:
	var marker := get_graph_marker(node_name)

	if marker == null:
		return []

	var neighbors: Array[StringName] = []
	_append_axis_neighbor(neighbors, node_name, marker.global_position, true, -1.0)
	_append_axis_neighbor(neighbors, node_name, marker.global_position, true, 1.0)
	_append_axis_neighbor(neighbors, node_name, marker.global_position, false, -1.0)
	_append_axis_neighbor(neighbors, node_name, marker.global_position, false, 1.0)
	_append_diagonal_neighbor(neighbors, node_name, marker.global_position, -1.0, -1.0)
	_append_diagonal_neighbor(neighbors, node_name, marker.global_position, 1.0, -1.0)
	_append_diagonal_neighbor(neighbors, node_name, marker.global_position, -1.0, 1.0)
	_append_diagonal_neighbor(neighbors, node_name, marker.global_position, 1.0, 1.0)
	return neighbors


func _append_axis_neighbor(
	neighbors: Array[StringName],
	source_name: StringName,
	source_position: Vector2,
	horizontal: bool,
	direction: float
) -> void:
	var best_name := StringName()
	var best_distance := INF

	for candidate_name in get_graph_node_names():
		if candidate_name == source_name:
			continue

		if is_queue_target_node(candidate_name) or is_queue_target_node(source_name):
			continue

		var candidate := get_graph_marker(candidate_name)

		if candidate == null:
			continue

		var candidate_position := candidate.global_position
		var same_axis: bool = (
			absf(candidate_position.y - source_position.y) <= _graph.MARKER_ALIGNMENT_EPSILON
			if horizontal
			else absf(candidate_position.x - source_position.x) <= _graph.MARKER_ALIGNMENT_EPSILON
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

		var distance := absf(offset)

		if distance <= _graph.MARKER_ALIGNMENT_EPSILON or distance >= best_distance:
			continue

		if not _graph._clearance.is_route_clear(source_position, _graph._routes.make_orthogonal_route(source_position, candidate_position, true)):
			continue

		best_name = candidate_name
		best_distance = distance

	if best_name != StringName() and best_name not in neighbors:
		neighbors.append(best_name)


func _append_diagonal_neighbor(
	neighbors: Array[StringName],
	source_name: StringName,
	source_position: Vector2,
	dir_x: float,
	dir_y: float
) -> void:
	var best_name := StringName()
	var best_distance := INF

	for candidate_name in get_graph_node_names():
		if candidate_name == source_name:
			continue

		if is_queue_target_node(candidate_name) or is_queue_target_node(source_name):
			continue

		var candidate := get_graph_marker(candidate_name)

		if candidate == null:
			continue

		var candidate_position := candidate.global_position
		var dx: float = candidate_position.x - source_position.x
		var dy: float = candidate_position.y - source_position.y

		if absf(dx) <= _graph.MARKER_ALIGNMENT_EPSILON or absf(dy) <= _graph.MARKER_ALIGNMENT_EPSILON:
			continue

		if signf(dx) != signf(dir_x) or signf(dy) != signf(dir_y):
			continue

		var distance: float = source_position.distance_to(candidate_position)

		if distance <= _graph.MARKER_ALIGNMENT_EPSILON or distance >= best_distance:
			continue

		if not _graph._clearance.is_route_segment_clear(source_position, candidate_position):
			continue

		best_name = candidate_name
		best_distance = distance

	if best_name != StringName() and best_name not in neighbors:
		neighbors.append(best_name)


# ---------------------------------------------------------------------------
#  Edge cost helpers
# ---------------------------------------------------------------------------

func get_graph_edge_cost(from_node: StringName, to_node: StringName) -> float:
	var from_marker := get_graph_marker(from_node)
	var to_marker := get_graph_marker(to_node)

	if from_marker == null or to_marker == null:
		return INF

	return _graph._routes.get_euclidean_distance(from_marker.global_position, to_marker.global_position)


func get_graph_path_cost(path: Array[StringName]) -> float:
	var cost := 0.0

	for index in range(1, path.size()):
		cost += get_graph_edge_cost(path[index - 1], path[index])

	return cost


func _pop_lowest_cost_node(frontier: Array[StringName], distances: Dictionary) -> StringName:
	var best_index := 0
	var best_cost := INF

	for index in range(frontier.size()):
		var node_name := frontier[index]
		var cost := float(distances.get(node_name, INF))

		if cost < best_cost:
			best_cost = cost
			best_index = index

	return frontier.pop_at(best_index)
