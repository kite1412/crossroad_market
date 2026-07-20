extends RefCounted
class_name StorePathGraphGraph

## Marker lookup and A* navigation for StorePathGraph.

var _graph = null


func _init(graph_owner = null) -> void:
	_graph = graph_owner


func get_graph_marker(node_name: StringName) -> Marker2D:
	if _graph == null or _graph._markers == null:
		return null
	return _graph._markers.get_node_or_null(String(node_name)) as Marker2D


func get_marker_position(node_name: StringName) -> Vector2:
	var graph_marker = get_graph_marker(node_name)
	if graph_marker == null:
		return Vector2.INF
	return graph_marker.global_position


func get_markers_by_role(role: StringName) -> Array[Marker2D]:
	var result: Array[Marker2D] = []
	if (
		_graph == null
		or _graph._markers == null
		or not is_instance_valid(_graph._markers)
	):
		return result

	for child in _graph._markers.get_children():
		var role_marker = child as Marker2D
		if role_marker == null:
			continue
		if get_marker_role(role_marker) == role:
			result.append(role_marker)

	return result


func get_graph_node_names() -> Array[StringName]:
	var node_names: Array[StringName] = []
	if _graph == null or _graph._markers == null:
		return node_names

	var child_count = _graph._markers.get_child_count()
	if _graph._cached_graph_node_count == child_count:
		return _graph._cached_graph_node_names.duplicate()

	for child in _graph._markers.get_children():
		if child is Marker2D:
			node_names.append(StringName(child.name))

	node_names.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b)
	)

	_graph._cached_graph_node_names = node_names
	_graph._cached_graph_node_count = child_count
	return node_names


func get_marker_role(role_marker: Marker2D) -> StringName:
	if role_marker == null or not role_marker.has_meta(_graph.PATH_ROLE_META):
		return StringName()

	var stored_role: Variant = role_marker.get_meta(_graph.PATH_ROLE_META)
	if stored_role is StringName:
		return stored_role as StringName
	if stored_role is String:
		return StringName(stored_role)
	return StringName()


func is_shelf_access_marker(access_marker: Marker2D) -> bool:
	if access_marker == null:
		return false

	var marker_role = get_marker_role(access_marker)
	if (
		marker_role == _graph.ROLE_QUEUE_FRONT
		or marker_role == _graph.ROLE_QUEUE_BACK
		or marker_role == _graph.ROLE_CASHIER
	):
		return false

	if bool(access_marker.get_meta(_graph.SHELF_ANCHOR_META, false)):
		return true

	return (
		marker_role == _graph.ROLE_ENTRY
		or marker_role == _graph.ROLE_EXIT
	)


func get_role_node_name(
	role: StringName,
	fallback_node_name: StringName = StringName()
) -> StringName:
	for node_name in get_graph_node_names():
		var role_marker = get_graph_marker(node_name)
		if get_marker_role(role_marker) == role:
			return node_name

	if (
		fallback_node_name != StringName()
		and get_graph_marker(fallback_node_name) != null
	):
		return fallback_node_name

	return StringName()


func get_checkout_goal_node_names() -> Array[StringName]:
	var goals: Array[StringName] = []

	for checkout_role in _graph.CHECKOUT_GOAL_ROLES:
		for node_name in get_graph_node_names():
			var goal_marker = get_graph_marker(node_name)
			if (
				get_marker_role(goal_marker) == checkout_role
				and node_name not in goals
			):
				goals.append(node_name)

	if goals.is_empty() and get_graph_marker(_graph.QUEUE_FRONT) != null:
		goals.append(_graph.QUEUE_FRONT)

	if (
		get_graph_marker(_graph.CASHIER) != null
		and _graph.CASHIER not in goals
	):
		goals.append(_graph.CASHIER)

	return goals


func get_queue_target_node_name(queue_index: int) -> StringName:
	if queue_index <= 0:
		return get_role_node_name(
			_graph.ROLE_QUEUE_FRONT,
			_graph.QUEUE_FRONT
		)

	var queue_back_nodes = get_queue_back_node_names()
	if queue_back_nodes.is_empty():
		return get_role_node_name(
			_graph.ROLE_QUEUE_FRONT,
			_graph.QUEUE_FRONT
		)

	var back_index = mini(queue_index - 1, queue_back_nodes.size() - 1)
	return queue_back_nodes[back_index]


func get_queue_approach_node_name(queue_index: int) -> StringName:
	if queue_index <= 0:
		return get_role_node_name(
			_graph.ROLE_QUEUE_FRONT_RIGHT,
			StringName()
		)

	var right_nodes = get_queue_back_right_node_names()
	if right_nodes.is_empty():
		return get_role_node_name(
			_graph.ROLE_QUEUE_FRONT_RIGHT,
			StringName()
		)

	var back_index = mini(queue_index - 1, right_nodes.size() - 1)
	return right_nodes[back_index]


func get_queue_back_node_names() -> Array[StringName]:
	var result: Array[StringName] = []
	for node_name in get_graph_node_names():
		if get_marker_role(get_graph_marker(node_name)) == _graph.ROLE_QUEUE_BACK:
			result.append(node_name)

	result.sort_custom(func(a: StringName, b: StringName) -> bool:
		return get_queue_marker_index(a) < get_queue_marker_index(b)
	)
	return result


func get_queue_back_right_node_names() -> Array[StringName]:
	var result: Array[StringName] = []
	for node_name in get_graph_node_names():
		if (
			get_marker_role(get_graph_marker(node_name))
			== _graph.ROLE_QUEUE_BACK_RIGHT
		):
			result.append(node_name)

	result.sort_custom(func(a: StringName, b: StringName) -> bool:
		return get_queue_marker_index(a) < get_queue_marker_index(b)
	)
	return result


func get_queue_right_node_names() -> Array[StringName]:
	var result: Array[StringName] = []
	var front_right_node = get_role_node_name(
		_graph.ROLE_QUEUE_FRONT_RIGHT,
		StringName()
	)
	if front_right_node != StringName():
		result.append(front_right_node)

	result.append_array(get_queue_back_right_node_names())
	result.sort_custom(func(a: StringName, b: StringName) -> bool:
		return get_queue_marker_index(a) < get_queue_marker_index(b)
	)
	return result


func get_nearest_queue_right_node_name(position: Vector2) -> StringName:
	var best_node = StringName()
	var best_distance = INF

	for node_name in get_queue_right_node_names():
		var right_marker = get_graph_marker(node_name)
		if right_marker == null:
			continue

		var marker_distance = position.distance_to(right_marker.global_position)
		if marker_distance >= best_distance:
			continue

		best_node = node_name
		best_distance = marker_distance

	return best_node


func get_queue_marker_index(node_name: StringName) -> int:
	var queue_marker = get_graph_marker(node_name)
	if queue_marker == null or not queue_marker.has_meta(&"store_queue_index"):
		return 999
	return int(queue_marker.get_meta(&"store_queue_index"))


func is_queue_target_node(node_name: StringName) -> bool:
	var marker_role = get_marker_role(get_graph_marker(node_name))
	return (
		marker_role == _graph.ROLE_QUEUE_FRONT
		or marker_role == _graph.ROLE_QUEUE_BACK
		or marker_role == _graph.ROLE_QUEUE_FRONT_RIGHT
		or marker_role == _graph.ROLE_QUEUE_BACK_RIGHT
	)


func find_graph_path(
	start_node: StringName,
	goal_node: StringName
) -> Array[StringName]:
	var result: Array[StringName] = []
	if start_node == StringName() or goal_node == StringName():
		return result
	if get_graph_marker(start_node) == null or get_graph_marker(goal_node) == null:
		return result

	var goal_position = get_marker_position(goal_node)
	var frontier: Array[StringName] = [start_node]
	var g_score: Dictionary = {start_node: 0.0}
	var f_score: Dictionary = {
		start_node: get_marker_position(start_node).distance_to(goal_position)
	}
	var previous: Dictionary = {}
	var visited: Dictionary = {}

	while not frontier.is_empty():
		var current_node = _pop_lowest_cost_node(frontier, f_score)
		if visited.has(current_node):
			continue

		visited[current_node] = true
		if current_node == goal_node:
			break

		for neighbor_node in get_graph_neighbors(current_node):
			if visited.has(neighbor_node):
				continue
			if (
				neighbor_node != goal_node
				and is_queue_target_node(neighbor_node)
			):
				continue

			var edge_cost = get_graph_edge_cost(
				current_node,
				neighbor_node
			)
			if edge_cost >= INF:
				continue

			var tentative_cost = float(g_score[current_node]) + edge_cost
			if (
				not g_score.has(neighbor_node)
				or tentative_cost < float(g_score[neighbor_node])
			):
				g_score[neighbor_node] = tentative_cost
				f_score[neighbor_node] = (
					tentative_cost
					+ get_marker_position(neighbor_node).distance_to(goal_position)
				)
				previous[neighbor_node] = current_node
				if neighbor_node not in frontier:
					frontier.append(neighbor_node)

	if not g_score.has(goal_node):
		return result

	var cursor = goal_node
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


func find_best_graph_path(
	start_node: StringName,
	goal_nodes: Array[StringName]
) -> Array[StringName]:
	var best_path: Array[StringName] = []
	var best_cost = INF

	for goal_node in goal_nodes:
		var candidate_path = find_graph_path(start_node, goal_node)
		if candidate_path.is_empty():
			continue

		var candidate_cost = get_graph_path_cost(candidate_path)
		if candidate_cost < best_cost:
			best_cost = candidate_cost
			best_path = candidate_path

	return best_path


func find_nearest_graph_node(position: Vector2) -> Dictionary:
	var best_result: Dictionary = {"valid": false}
	var best_distance = INF

	for node_name in get_graph_node_names():
		var graph_marker = get_graph_marker(node_name)
		if graph_marker == null:
			continue

		var marker_distance = position.distance_to(graph_marker.global_position)
		if marker_distance >= best_distance:
			continue

		best_distance = marker_distance
		best_result = {
			"valid": true,
			"node": node_name,
			"route": _graph._routes.make_orthogonal_route(
				position,
				graph_marker.global_position,
				true
			),
			"distance": marker_distance
		}

	return best_result


func find_nearest_reachable_graph_node_for_route(
	position: Vector2,
	goal_node: StringName
) -> Dictionary:
	if get_graph_marker(goal_node) == null:
		return {"valid": false}

	var best_result: Dictionary = {"valid": false}
	var best_route_distance = INF

	for start_node in get_graph_node_names():
		var start_marker = get_graph_marker(start_node)
		if start_marker == null:
			continue

		var graph_path = find_graph_path(start_node, goal_node)
		if graph_path.is_empty():
			continue

		for horizontal_first in [true, false]:
			var entry_route = _graph._routes.make_orthogonal_route(
				position,
				start_marker.global_position,
				horizontal_first
			)
			if not _graph._clearance.is_route_clear_from_current_position(
				position,
				entry_route
			):
				continue

			var complete_route = entry_route.duplicate()
			complete_route.append_array(
				_graph._routes.build_route_from_graph_path(graph_path)
			)
			complete_route = _graph._routes.dedupe_route_points(complete_route)

			var route_is_clear = false
			if is_queue_target_node(goal_node):
				route_is_clear = _graph._clearance.is_queue_route_clear_from_current_position(
					position,
					complete_route
				)
			else:
				route_is_clear = _graph._clearance.is_route_clear_from_current_position(
					position,
					complete_route
				)

			if not route_is_clear:
				continue

			var route_distance = _graph._routes.get_route_distance(
				position,
				complete_route
			)
			if route_distance >= best_route_distance:
				continue

			best_route_distance = route_distance
			best_result = {
				"valid": true,
				"node": start_node,
				"route": complete_route,
				"distance": route_distance
			}

	return best_result


func get_graph_neighbors(node_name: StringName) -> Array[StringName]:
	var source_marker = get_graph_marker(node_name)
	if source_marker == null:
		return []

	var neighbors: Array[StringName] = []
	_append_axis_neighbor(
		neighbors,
		node_name,
		source_marker.global_position,
		true,
		-1.0
	)
	_append_axis_neighbor(
		neighbors,
		node_name,
		source_marker.global_position,
		true,
		1.0
	)
	_append_axis_neighbor(
		neighbors,
		node_name,
		source_marker.global_position,
		false,
		-1.0
	)
	_append_axis_neighbor(
		neighbors,
		node_name,
		source_marker.global_position,
		false,
		1.0
	)

	for direction in [
		Vector2(-1, -1),
		Vector2(1, -1),
		Vector2(-1, 1),
		Vector2(1, 1)
	]:
		_append_diagonal_neighbor(
			neighbors,
			node_name,
			source_marker.global_position,
			direction.x,
			direction.y
		)

	return neighbors


func _append_axis_neighbor(
	neighbors: Array[StringName],
	source_name: StringName,
	source_position: Vector2,
	horizontal: bool,
	direction: float
) -> void:
	var best_name = StringName()
	var best_distance = INF

	for candidate_name in get_graph_node_names():
		if candidate_name == source_name:
			continue
		if is_queue_target_node(candidate_name) or is_queue_target_node(source_name):
			continue

		var candidate_marker = get_graph_marker(candidate_name)
		if candidate_marker == null:
			continue

		var candidate_position = candidate_marker.global_position
		var aligned = false
		var offset = 0.0
		if horizontal:
			aligned = (
				absf(candidate_position.y - source_position.y)
				<= _graph.MARKER_ALIGNMENT_EPSILON
			)
			offset = candidate_position.x - source_position.x
		else:
			aligned = (
				absf(candidate_position.x - source_position.x)
				<= _graph.MARKER_ALIGNMENT_EPSILON
			)
			offset = candidate_position.y - source_position.y

		if not aligned or signf(offset) != signf(direction):
			continue

		var candidate_distance = absf(offset)
		if (
			candidate_distance <= _graph.MARKER_ALIGNMENT_EPSILON
			or candidate_distance >= best_distance
		):
			continue

		var segment_route = _graph._routes.make_orthogonal_route(
			source_position,
			candidate_position,
			horizontal
		)
		if not _graph._clearance.is_route_clear(
			source_position,
			segment_route
		):
			continue

		best_name = candidate_name
		best_distance = candidate_distance

	if best_name != StringName() and best_name not in neighbors:
		neighbors.append(best_name)


func _append_diagonal_neighbor(
	neighbors: Array[StringName],
	source_name: StringName,
	source_position: Vector2,
	direction_x: float,
	direction_y: float
) -> void:
	var best_name = StringName()
	var best_distance = INF

	for candidate_name in get_graph_node_names():
		if candidate_name == source_name:
			continue
		if is_queue_target_node(candidate_name) or is_queue_target_node(source_name):
			continue

		var candidate_marker = get_graph_marker(candidate_name)
		if candidate_marker == null:
			continue

		var candidate_position = candidate_marker.global_position
		var delta_x = candidate_position.x - source_position.x
		var delta_y = candidate_position.y - source_position.y
		if (
			absf(delta_x) <= _graph.MARKER_ALIGNMENT_EPSILON
			or absf(delta_y) <= _graph.MARKER_ALIGNMENT_EPSILON
		):
			continue
		if signf(delta_x) != signf(direction_x):
			continue
		if signf(delta_y) != signf(direction_y):
			continue

		var candidate_distance = source_position.distance_to(candidate_position)
		if (
			candidate_distance <= _graph.MARKER_ALIGNMENT_EPSILON
			or candidate_distance >= best_distance
		):
			continue
		if not _graph._clearance.is_route_segment_clear(
			source_position,
			candidate_position
		):
			continue

		best_name = candidate_name
		best_distance = candidate_distance

	if best_name != StringName() and best_name not in neighbors:
		neighbors.append(best_name)


func get_graph_edge_cost(
	from_node: StringName,
	to_node: StringName
) -> float:
	var from_marker = get_graph_marker(from_node)
	var to_marker = get_graph_marker(to_node)
	if from_marker == null or to_marker == null:
		return INF
	return from_marker.global_position.distance_to(to_marker.global_position)


func get_graph_path_cost(path: Array[StringName]) -> float:
	var total_cost = 0.0
	for index in range(1, path.size()):
		total_cost += get_graph_edge_cost(path[index - 1], path[index])
	return total_cost


func _pop_lowest_cost_node(
	frontier: Array[StringName],
	distances: Dictionary
) -> StringName:
	var best_index = 0
	var best_cost = INF

	for index in range(frontier.size()):
		var candidate_node = frontier[index]
		var candidate_cost = float(distances.get(candidate_node, INF))
		if candidate_cost < best_cost:
			best_cost = candidate_cost
			best_index = index

	return frontier.pop_at(best_index)
