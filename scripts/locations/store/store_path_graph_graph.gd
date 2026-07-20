extends RefCounted
class_name StorePathGraphGraph

## Graph navigation functions for StorePathGraph
## Handles graph markers, pathfinding, and neighbors

## Reference to constants (set by parent)
var _constants: StorePathGraphConstants

func _init(consts: StorePathGraphConstants = null) -> void:
	_constants = consts


## Gets a graph marker by node name
func get_graph_marker(node_name: StringName, markers: Node2D = null) -> Marker2D:
	if markers == null:
		return null

	return markers.get_node_or_null(String(node_name)) as Marker2D


## Gets all graph node names
func get_graph_node_names(markers: Node2D = null) -> Array[StringName]:
	var node_names: Array[StringName] = []

	if markers == null:
		return node_names

	for child in markers.get_children():
		if child is Marker2D:
			node_names.append(StringName(child.name))

	node_names.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b)
	)

	return node_names


## Gets the checkout goal node names
func get_checkout_goal_node_names(
	markers: Node2D = null,
	get_graph_node_names_func: Callable = Callable(),
	get_marker_role_func: Callable = Callable()
) -> Array[StringName]:
	var goals: Array[StringName] = []

	var graph_node_names = get_graph_node_names_func.call() if get_graph_node_names_func.is_valid() else get_graph_node_names(markers)

	for role in _constants.CHECKOUT_GOAL_ROLES:
		for node_name in graph_node_names:
			var marker = get_graph_marker(node_name, markers)
			if get_marker_role_func.call(marker) == role and node_name not in goals:
				goals.append(node_name)

	if goals.is_empty() and get_graph_marker(_constants.QUEUE_FRONT, markers) != null:
		goals.append(_constants.QUEUE_FRONT)

	if get_graph_marker(_constants.CASHIER, markers) != null and _constants.CASHIER not in goals:
		goals.append(_constants.CASHIER)

	return goals


## Gets the role of a marker
func get_marker_role(marker: Marker2D) -> StringName:
	if marker == null or not marker.has_meta(_constants.PATH_ROLE_META):
		return StringName()

	var role: Variant = marker.get_meta(_constants.PATH_ROLE_META)

	if role is StringName:
		return role as StringName

	if role is String:
		return StringName(role)

	return StringName()


## Checks if a marker is a shelf access marker
func is_shelf_access_marker(marker: Marker2D) -> bool:
	if marker == null:
		return false

	var role := get_marker_role(marker)

	if role == _constants.ROLE_QUEUE_FRONT or role == _constants.ROLE_QUEUE_BACK or role == _constants.ROLE_CASHIER:
		return false

	if bool(marker.get_meta(_constants.SHELF_ANCHOR_META, false)):
		return true

	return role == _constants.ROLE_ENTRY or role == _constants.ROLE_EXIT


## Gets the role node name for a given role
func get_role_node_name(
	role: StringName,
	fallback_node_name: StringName,
	markers: Node2D = null,
	get_graph_node_names_func: Callable = Callable(),
	get_marker_role_func: Callable = Callable()
) -> StringName:
	var graph_node_names = get_graph_node_names_func.call() if get_graph_node_names_func.is_valid() else get_graph_node_names(markers)

	for node_name in graph_node_names:
		var marker = get_graph_marker(node_name, markers)

		if get_marker_role_func.call(marker) == role:
			return node_name

	if fallback_node_name != StringName() and get_graph_marker(fallback_node_name, markers) != null:
		return fallback_node_name

	return StringName()


## Finds the nearest graph node to a position
func find_nearest_graph_node(
	position: Vector2,
	markers: Node2D = null,
	get_graph_node_names_func: Callable = Callable(),
	get_marker_role_func: Callable = Callable(),
	make_orthogonal_route_func: Callable = Callable()
) -> Dictionary:
	var best_result := {"valid": false}
	var best_score := INF

	var graph_node_names = get_graph_node_names_func.call() if get_graph_node_names_func.is_valid() else get_graph_node_names(markers)

	for node_name in graph_node_names:
		var marker = get_graph_marker(node_name, markers)

		if marker == null:
			continue

		var distance := position.distance_to(marker.global_position)

		if distance < best_score:
			best_score = distance
			best_result = {
				"valid": true,
				"node": node_name,
				"route": make_orthogonal_route_func.call(position, marker.global_position, true) if make_orthogonal_route_func.is_valid() else [],
				"distance": distance
			}

	return best_result


## Finds graph path using A* algorithm
func find_graph_path(
	start_node: StringName,
	goal_node: StringName,
	markers: Node2D = null,
	is_queue_target_node_func: Callable = Callable(),
	get_graph_edge_cost_func: Callable = Callable(),
	get_marker_position_func: Callable = Callable()
) -> Array[StringName]:
	var result: Array[StringName] = []

	if start_node == StringName() or goal_node == StringName():
		return result

	var goal_position := get_marker_position_func.call(goal_node, markers) if get_marker_position_func.is_valid() else Vector2.INF
	var start_position := get_marker_position_func.call(start_node, markers) if get_marker_position_func.is_valid() else Vector2.INF
	var frontier: Array[StringName] = [start_node]
	var g_score := {start_node: 0.0}
	var f_score := {start_node: start_position.distance_to(goal_position) if goal_position.is_finite() and start_position.is_finite() else INF}
	var previous := {}
	var visited := {}

	while not frontier.is_empty():
		var current := _pop_lowest_cost_node(frontier, f_score)

		if visited.has(current):
			continue

		visited[current] = true

		if current == goal_node:
			break

		for neighbor in _get_graph_neighbors(current, markers, is_queue_target_node_func):
			if visited.has(neighbor):
				continue

			var edge_cost := get_graph_edge_cost_func.call(current, neighbor, markers) if get_graph_edge_cost_func.is_valid() else INF

			if edge_cost >= INF:
				continue

			var next_g := float(g_score[current]) + edge_cost

			if not g_score.has(neighbor) or next_g < float(g_score[neighbor]):
				g_score[neighbor] = next_g
				var neighbor_pos = get_marker_position_func.call(neighbor, markers) if get_marker_position_func.is_valid() else Vector2.INF
				f_score[neighbor] = next_g + (neighbor_pos.distance_to(goal_position) if neighbor_pos.is_finite() else INF)
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


## Gets graph neighbors (axis-aligned and diagonal)
func _get_graph_neighbors(
	node_name: StringName,
	markers: Node2D = null,
	is_queue_target_node_func: Callable = Callable()
) -> Array[StringName]:
	var marker = get_graph_marker(node_name, markers)

	if marker == null:
		return []

	var neighbors: Array[StringName] = []
	_append_axis_neighbor(neighbors, node_name, marker.global_position, true, -1.0, markers, is_queue_target_node_func)
	_append_axis_neighbor(neighbors, node_name, marker.global_position, true, 1.0, markers, is_queue_target_node_func)
	_append_axis_neighbor(neighbors, node_name, marker.global_position, false, -1.0, markers, is_queue_target_node_func)
	_append_axis_neighbor(neighbors, node_name, marker.global_position, false, 1.0, markers, is_queue_target_node_func)
	_append_diagonal_neighbor(neighbors, node_name, marker.global_position, -1.0, -1.0, markers, is_queue_target_node_func)
	_append_diagonal_neighbor(neighbors, node_name, marker.global_position, 1.0, -1.0, markers, is_queue_target_node_func)
	_append_diagonal_neighbor(neighbors, node_name, marker.global_position, -1.0, 1.0, markers, is_queue_target_node_func)
	_append_diagonal_neighbor(neighbors, node_name, marker.global_position, 1.0, 1.0, markers, is_queue_target_node_func)
	return neighbors


func _append_axis_neighbor(
	neighbors: Array[StringName],
	source_name: StringName,
	source_position: Vector2,
	horizontal: bool,
	direction: float,
	markers: Node2D = null,
	is_queue_target_node_func: Callable = Callable()
) -> void:
	var best_name := StringName()
	var best_distance := INF

	var graph_node_names = get_graph_node_names(markers)

	for candidate_name in graph_node_names:
		if candidate_name == source_name:
			continue

		if is_queue_target_node_func.call(candidate_name) or is_queue_target_node_func.call(source_name):
			continue

		var candidate := get_graph_marker(candidate_name, markers)

		if candidate == null:
			continue

		var candidate_position := candidate.global_position
		var same_axis := (
			absf(candidate_position.y - source_position.y) <= _constants.MARKER_ALIGNMENT_EPSILON
			if horizontal
			else absf(candidate_position.x - source_position.x) <= _constants.MARKER_ALIGNMENT_EPSILON
		)

		if not same_axis:
			continue

		var offset := (
			candidate_position.x - source_position.x
			if horizontal
			else candidate_position.y - source_position.y
		)

		if signf(offset) != signf(direction):
			continue

		var distance := absf(offset)

		if distance <= _constants.MARKER_ALIGNMENT_EPSILON or distance >= best_distance:
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
	dir_y: float,
	markers: Node2D = null,
	is_queue_target_node_func: Callable = Callable()
) -> void:
	var best_name := StringName()
	var best_distance := INF

	var graph_node_names = get_graph_node_names(markers)

	for candidate_name in graph_node_names:
		if candidate_name == source_name:
			continue

		if is_queue_target_node_func.call(candidate_name) or is_queue_target_node_func.call(source_name):
			continue

		var candidate := get_graph_marker(candidate_name, markers)

		if candidate == null:
			continue

		var candidate_position := candidate.global_position
		var dx := candidate_position.x - source_position.x
		var dy := candidate_position.y - source_position.y

		if absf(dx) <= _constants.MARKER_ALIGNMENT_EPSILON or absf(dy) <= _constants.MARKER_ALIGNMENT_EPSILON:
			continue

		if signf(dx) != signf(dir_x) or signf(dy) != signf(dir_y):
			continue

		var distance := source_position.distance_to(candidate_position)

		if distance <= _constants.MARKER_ALIGNMENT_EPSILON or distance >= best_distance:
			continue

		best_name = candidate_name
		best_distance = distance

	if best_name != StringName() and best_name not in neighbors:
		neighbors.append(best_name)


## Checks if a node is a queue target node
func is_queue_target_node(node_name: StringName) -> bool:
	# This is a simplified check - the actual implementation uses marker role
	return (
		String(node_name).contains("queue") or
		String(node_name).contains("Queue")
	)


## Gets the graph edge cost between two nodes
func get_graph_edge_cost(from_node: StringName, to_node: StringName, markers: Node2D = null) -> float:
	var from_marker := get_graph_marker(from_node, markers)
	var to_marker := get_graph_marker(to_node, markers)

	if from_marker == null or to_marker == null:
		return INF

	return from_marker.global_position.distance_to(to_marker.global_position)


## Gets the marker position for a node
func get_marker_position(node_name: StringName, markers: Node2D = null) -> Vector2:
	var marker := get_graph_marker(node_name, markers)
	return marker.global_position if marker != null else Vector2.INF


## Gets the graph path cost
func get_graph_path_cost(path: Array[StringName], markers: Node2D = null) -> float:
	var cost := 0.0

	for index in range(1, path.size()):
		cost += get_graph_edge_cost(path[index - 1], path[index], markers)

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
