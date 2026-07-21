class_name StoreDStarLitePlanner
extends RefCounted

const MAX_COMPUTE_ITERATIONS: int = 4096

var _graph: StoreSemanticGraph = null
var _policy: StoreNavigationCostPolicy = null
var _start: StringName = StringName()
var _goal: StringName = StringName()
var _last_start: StringName = StringName()
var _km: float = 0.0
var _g: Dictionary = {}
var _rhs: Dictionary = {}
var _open: Array[Dictionary] = []
var _context: Dictionary = {}
var _revision: int = -1


func setup(
	graph: StoreSemanticGraph,
	policy: StoreNavigationCostPolicy
) -> void:
	if _graph == graph and _policy == policy:
		return
	_graph = graph
	_policy = policy
	_reset()


func get_path(
	start_node: StringName,
	goal_node: StringName,
	revision: int,
	context: Dictionary = {},
	changed_nodes: Array[StringName] = []
) -> Array[StringName]:
	if _graph == null or _policy == null:
		return []
	if not _graph.has_node(start_node) or not _graph.has_node(goal_node):
		return []

	var needs_initialize := (
		_goal != goal_node
		or _start == StringName()
		or _g.is_empty()
	)
	_context = context.duplicate(true)
	_context["goal_node"] = goal_node

	if needs_initialize:
		_initialize(start_node, goal_node, revision)
	else:
		_update_start(start_node)
		if revision != _revision:
			_revision = revision
			_notify_changed_nodes(changed_nodes)

	_compute_shortest_path()
	return _extract_path()


func clear() -> void:
	_reset()


func _initialize(
	start_node: StringName,
	goal_node: StringName,
	revision: int
) -> void:
	_reset()
	_start = start_node
	_last_start = start_node
	_goal = goal_node
	_revision = revision
	for node_id in _graph.get_node_ids():
		_g[node_id] = INF
		_rhs[node_id] = INF
	_rhs[_goal] = 0.0
	_insert_open(_goal, _calculate_key(_goal))


func _update_start(next_start: StringName) -> void:
	if next_start == _start:
		return
	if _last_start != StringName():
		_km += _heuristic(_last_start, next_start)
	_start = next_start
	_last_start = next_start


func _notify_changed_nodes(changed_nodes: Array[StringName]) -> void:
	var nodes_to_update: Array[StringName] = []
	if changed_nodes.is_empty():
		nodes_to_update = _graph.get_node_ids()
	else:
		for node_id in changed_nodes:
			if node_id not in nodes_to_update:
				nodes_to_update.append(node_id)
			for neighbor in _graph.get_neighbors(node_id):
				if neighbor not in nodes_to_update:
					nodes_to_update.append(neighbor)

	for node_id in nodes_to_update:
		_update_vertex(node_id)


func _compute_shortest_path() -> void:
	var iterations := 0
	while iterations < MAX_COMPUTE_ITERATIONS:
		iterations += 1
		var top_key := _get_top_key()
		var start_key := _calculate_key(_start)
		if (
			not _key_less(top_key, start_key)
			and _values_equal(_get_rhs(_start), _get_g(_start))
		):
			break
		if _open.is_empty():
			break

		var entry := _pop_open()
		var node_id := entry.get("node", StringName()) as StringName
		var old_key := Vector2(
			float(entry.get("k1", INF)),
			float(entry.get("k2", INF))
		)
		var new_key := _calculate_key(node_id)

		if _key_less(old_key, new_key):
			_insert_open(node_id, new_key)
		elif _get_g(node_id) > _get_rhs(node_id):
			_g[node_id] = _get_rhs(node_id)
			for predecessor in _graph.get_neighbors(node_id):
				_update_vertex(predecessor)
		else:
			_g[node_id] = INF
			_update_vertex(node_id)
			for predecessor in _graph.get_neighbors(node_id):
				_update_vertex(predecessor)


func _update_vertex(node_id: StringName) -> void:
	if node_id != _goal:
		var best_rhs := INF
		for neighbor in _graph.get_neighbors(node_id):
			var edge_cost := _graph.get_edge_cost(
				node_id,
				neighbor,
				_context
			)
			if edge_cost >= INF:
				continue
			best_rhs = minf(best_rhs, edge_cost + _get_g(neighbor))
		_rhs[node_id] = best_rhs

	_remove_open(node_id)
	if not _values_equal(_get_g(node_id), _get_rhs(node_id)):
		_insert_open(node_id, _calculate_key(node_id))


func _extract_path() -> Array[StringName]:
	var result: Array[StringName] = []
	if _start == StringName() or _goal == StringName():
		return result
	if _get_g(_start) >= INF and _get_rhs(_start) >= INF:
		return result

	var cursor := _start
	result.append(cursor)
	var visited: Dictionary = {cursor: true}
	var guard := 0
	while cursor != _goal and guard < _graph.get_node_ids().size() + 8:
		guard += 1
		var best_neighbor := StringName()
		var best_cost := INF
		for neighbor in _graph.get_neighbors(cursor):
			var edge_cost := _graph.get_edge_cost(
				cursor,
				neighbor,
				_context
			)
			if edge_cost >= INF:
				continue
			var candidate_cost := edge_cost + _get_g(neighbor)
			if candidate_cost < best_cost:
				best_cost = candidate_cost
				best_neighbor = neighbor

		if best_neighbor == StringName() or visited.has(best_neighbor):
			return []
		cursor = best_neighbor
		visited[cursor] = true
		result.append(cursor)
	return result if cursor == _goal else []


func _calculate_key(node_id: StringName) -> Vector2:
	var minimum := minf(_get_g(node_id), _get_rhs(node_id))
	return Vector2(
		minimum + _heuristic(_start, node_id) + _km,
		minimum
	)


func _heuristic(a: StringName, b: StringName) -> float:
	return _policy.heuristic(
		_graph.get_position(a),
		_graph.get_position(b)
	)


func _insert_open(node_id: StringName, key: Vector2) -> void:
	_remove_open(node_id)
	_open.append({
		"node": node_id,
		"k1": key.x,
		"k2": key.y
	})


func _remove_open(node_id: StringName) -> void:
	for index in range(_open.size() - 1, -1, -1):
		if StringName(_open[index].get("node", StringName())) == node_id:
			_open.remove_at(index)


func _pop_open() -> Dictionary:
	var best_index := 0
	var best_key := Vector2(INF, INF)
	for index in range(_open.size()):
		var candidate := Vector2(
			float(_open[index].get("k1", INF)),
			float(_open[index].get("k2", INF))
		)
		if _key_less(candidate, best_key):
			best_key = candidate
			best_index = index
	return _open.pop_at(best_index)


func _get_top_key() -> Vector2:
	if _open.is_empty():
		return Vector2(INF, INF)
	var best := Vector2(INF, INF)
	for entry in _open:
		var candidate := Vector2(
			float(entry.get("k1", INF)),
			float(entry.get("k2", INF))
		)
		if _key_less(candidate, best):
			best = candidate
	return best


func _key_less(a: Vector2, b: Vector2) -> bool:
	if a.x < b.x - 0.0001:
		return true
	if absf(a.x - b.x) <= 0.0001 and a.y < b.y - 0.0001:
		return true
	return false


func _values_equal(a: float, b: float) -> bool:
	if a >= INF and b >= INF:
		return true
	return is_equal_approx(a, b)


func _get_g(node_id: StringName) -> float:
	return float(_g.get(node_id, INF))


func _get_rhs(node_id: StringName) -> float:
	return float(_rhs.get(node_id, INF))


func _reset() -> void:
	_start = StringName()
	_goal = StringName()
	_last_start = StringName()
	_km = 0.0
	_g.clear()
	_rhs.clear()
	_open.clear()
	_context.clear()
	_revision = -1
