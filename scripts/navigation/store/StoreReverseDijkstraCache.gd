class_name StoreReverseDijkstraCache
extends RefCounted

var _graph: StoreSemanticGraph = null
var _cache: Dictionary = {}


func setup(graph: StoreSemanticGraph) -> void:
	if _graph == graph:
		return
	_graph = graph
	_cache.clear()


func clear() -> void:
	_cache.clear()


func get_path(
	start_node: StringName,
	goal_node: StringName,
	revision: int,
	context: Dictionary = {}
) -> Array[StringName]:
	if _graph == null:
		return []
	if not _graph.has_node(start_node) or not _graph.has_node(goal_node):
		return []

	var cache_key := _make_cache_key(goal_node, revision, context)
	if not _cache.has(cache_key):
		_cache[cache_key] = _build_reverse_tree(goal_node, context)

	var tree: Dictionary = _cache[cache_key]
	var next_hop: Dictionary = tree.get("next_hop", {})
	if start_node != goal_node and not next_hop.has(start_node):
		return []

	var result: Array[StringName] = [start_node]
	var cursor := start_node
	var guard := 0
	while cursor != goal_node and guard < _graph.get_node_ids().size() + 4:
		guard += 1
		cursor = next_hop.get(cursor, StringName()) as StringName
		if cursor == StringName():
			return []
		result.append(cursor)
	return result


func get_distance(
	start_node: StringName,
	goal_node: StringName,
	revision: int,
	context: Dictionary = {}
) -> float:
	var cache_key := _make_cache_key(goal_node, revision, context)
	if not _cache.has(cache_key):
		_cache[cache_key] = _build_reverse_tree(goal_node, context)
	var tree: Dictionary = _cache[cache_key]
	var distances: Dictionary = tree.get("distance", {})
	return float(distances.get(start_node, INF))


func _build_reverse_tree(
	goal_node: StringName,
	context: Dictionary
) -> Dictionary:
	var frontier: Array[StringName] = [goal_node]
	var distances: Dictionary = {goal_node: 0.0}
	var next_hop: Dictionary = {}
	var visited: Dictionary = {}

	while not frontier.is_empty():
		var current := _pop_lowest_distance(frontier, distances)
		if visited.has(current):
			continue
		visited[current] = true

		for predecessor in _graph.get_neighbors(current):
			var edge_context := context.duplicate(true)
			edge_context["goal_node"] = goal_node
			var edge_cost := _graph.get_edge_cost(
				predecessor,
				current,
				edge_context
			)
			if edge_cost >= INF:
				continue
			var next_distance := float(distances[current]) + edge_cost
			if next_distance >= float(distances.get(predecessor, INF)):
				continue
			distances[predecessor] = next_distance
			next_hop[predecessor] = current
			if predecessor not in frontier:
				frontier.append(predecessor)

	return {
		"distance": distances,
		"next_hop": next_hop
	}


func _pop_lowest_distance(
	frontier: Array[StringName],
	distances: Dictionary
) -> StringName:
	var best_index := 0
	var best_distance := INF
	for index in range(frontier.size()):
		var node_id := frontier[index]
		var distance := float(distances.get(node_id, INF))
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return frontier.pop_at(best_index)


func _make_cache_key(
	goal_node: StringName,
	revision: int,
	context: Dictionary
) -> String:
	return "%s|r%d|aq%d|q%d|radius%d|p%s" % [
		String(goal_node),
		revision,
		int(bool(context.get("avoid_queue_front", false))),
		int(context.get("queue_index", -1)),
		roundi(float(context.get("agent_radius", 10.5)) * 10.0),
		str(context.get("policy_signature", ""))
	]
