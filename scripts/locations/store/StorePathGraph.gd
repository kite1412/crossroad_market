class_name StorePathGraph
extends RefCounted

const ENTRY: StringName = &"StorePathEntry"
const EXIT: StringName = &"StorePathExit"
const AISLE_RIGHT: StringName = &"StorePathAisleRight"
const CASHIER: StringName = &"StorePathCashier"
const QUEUE_FRONT: StringName = &"StorePathQueueFront"
const ACCESS_META: StringName = &"npc_access_point"
const ACCESS_NODE_META: StringName = &"npc_access_graph_node"
const ACCESS_ROUTE_META: StringName = &"npc_access_surface_route"
const PATH_ROLE_META: StringName = &"store_path_role"
const SHELF_ANCHOR_META: StringName = &"store_path_allow_shelf_anchor"
const ROLE_ENTRY: StringName = &"entry"
const ROLE_EXIT: StringName = &"exit"
const ROLE_CASHIER: StringName = &"cashier"
const ROLE_QUEUE_FRONT: StringName = &"queue_front"
const ROLE_QUEUE_BACK: StringName = &"queue_back"
const ROLE_QUEUE_FRONT_RIGHT: StringName = &"queue_front_right"
const ROLE_QUEUE_BACK_RIGHT: StringName = &"queue_back_right"
const CHECKOUT_GOAL_ROLES: Array[StringName] = [ROLE_QUEUE_FRONT, ROLE_CASHIER]
const STANDING_SHAPE_SIZE := Vector2(21, 9)
const STANDING_SHAPE_OFFSET := Vector2(0, -8)
const ROUTE_SAMPLE_STEP: float = 8.0
const ROUTE_CLEARANCE_EPSILON: float = 2.0
const MARKER_ALIGNMENT_EPSILON: float = 2.0
const SHELF_ACCESS_COLUMN_EPSILON: float = 8.0
const SHELF_ACCESS_NEAR_COLUMN_EPSILON: float = 28.0
const MAX_SHELF_ACCESS_DISTANCE: float = 96.0
const MAX_SHELF_ACCESS_CANDIDATES: int = 96
const SURFACE_CONNECTOR_LIMIT: int = 4
const MAX_SURFACE_ROUTE_SEARCHES: int = 24
const SURFACE_ALIGNMENT_EPSILON: float = 2.0
const SURFACE_NEIGHBOR_MAX_DISTANCE: float = 36.0
const DEBUG_SHELF_ACCESS_FAILURES: bool = false

var _store: Node2D = null
var _markers: Node2D = null
var _shelf_access_points: Array[Vector2] = []
var _surface_neighbor_cache := {}
var _surface_neighbor_signature := ""
var _cached_shelf_anchor_positions: Array[Vector2] = []
var _cached_shelf_anchor_count: int = -1
var _cached_graph_node_names: Array[StringName] = []
var _cached_graph_node_count: int = -1


func _init(store: Node2D = null, markers: Node2D = null) -> void:
	_store = store
	_markers = markers


func setup(store: Node2D, markers: Node2D) -> void:
	_store = store
	_markers = markers


func set_shelf_access_points(points: Array[Vector2]) -> void:
	var next_points := points.duplicate()

	if _get_surface_points_signature(next_points) != _get_surface_points_signature(_shelf_access_points):
		_surface_neighbor_cache.clear()
		_surface_neighbor_signature = ""

	_shelf_access_points = next_points


func invalidate_surface_graph_cache() -> void:
	_surface_neighbor_cache.clear()
	_surface_neighbor_signature = ""


func get_marker_for_role(role: StringName, fallback_node_name: StringName = StringName()) -> Marker2D:
	var role_node := _get_role_node_name(role, fallback_node_name)

	if role_node == StringName():
		return null

	return _get_graph_marker(role_node)


func get_shelf_anchor_positions() -> Array[Vector2]:
	var graph_nodes := _get_graph_node_names()

	if _cached_shelf_anchor_count == graph_nodes.size():
		return _cached_shelf_anchor_positions.duplicate()

	var positions: Array[Vector2] = []

	for node_name in graph_nodes:
		var marker := _get_graph_marker(node_name)

		if marker == null:
			continue

		if bool(marker.get_meta(SHELF_ANCHOR_META, false)):
			positions.append(marker.global_position)

	_cached_shelf_anchor_positions = positions
	_cached_shelf_anchor_count = graph_nodes.size()
	return positions.duplicate()


func get_queue_target_position(queue_index: int, fallback_position: Vector2) -> Vector2:
	var node_name := _get_queue_target_node_name(queue_index)
	var marker := _get_graph_marker(node_name)
	return marker.global_position if marker != null else fallback_position


func get_entry_route_to_shelf(shelf_position: Vector2, from_position: Vector2 = Vector2.INF) -> Array[Vector2]:
	var entry_node := _get_role_node_name(ROLE_ENTRY, ENTRY)
	var aisle_node := _get_role_node_name(&"aisle_right", AISLE_RIGHT)
	var start: Dictionary = _find_nearest_graph_node(from_position) if from_position.is_finite() else {
		"valid": true,
		"node": entry_node,
		"route": _build_route_from_graph_path([entry_node])
	}

	if not bool(start.get("valid", false)):
		return _dedupe_route_points(_make_orthogonal_route(from_position, shelf_position, true))

	var path := _find_graph_path(start.get("node", entry_node) as StringName, aisle_node)
	var route := start.get("route", []) as Array[Vector2]
	route.append_array(_build_route_from_graph_path(path))
	_append_orthogonal_route_to(route, shelf_position, true, from_position)
	return _dedupe_route_points(route)


func get_shelf_access_position(shelf: Shelf) -> Vector2:
	if shelf == null:
		return Vector2.INF

	if shelf.has_meta(ACCESS_META):
		var access_point: Variant = shelf.get_meta(ACCESS_META)

		if access_point is Vector2:
			return access_point as Vector2

	var result := find_best_vertical_shelf_access(shelf.global_position, shelf)
	_store_access_metadata_from_result(shelf, result)
	return result.get("access_point", Vector2.INF) as Vector2


func has_cached_shelf_access_metadata(shelf: Shelf) -> bool:
	if shelf == null:
		return false

	return shelf.has_meta(ACCESS_META) and shelf.has_meta(ACCESS_NODE_META)


func get_route_to_shelf_access(shelf: Shelf) -> Array[Vector2]:
	if shelf == null:
		return []

	var access_point := get_shelf_access_position(shelf)
	var graph_node := get_shelf_access_graph_node(shelf)

	if not access_point.is_finite() or graph_node == StringName():
		return []

	var path := _find_graph_path(_get_role_node_name(ROLE_ENTRY, ENTRY), graph_node)
	var route := _build_route_from_graph_path(path)
	_append_surface_access_route_to(route, shelf, graph_node, access_point, true)
	return _dedupe_route_points(route)


func get_route_to_cashier_from(from_position: Vector2) -> Array[Vector2]:
	var start := _find_nearest_graph_node(from_position)

	if not bool(start.get("valid", false)):
		return []

	var path := _find_checkout_graph_path(start.get("node", CASHIER) as StringName)
	var route := start.get("route", []) as Array[Vector2]
	route.append_array(_build_route_from_graph_path(path))
	return _dedupe_route_points(route)


func get_route_to_queue_target_from(from_position: Vector2, queue_index: int) -> Array[Vector2]:
	var queue_target := get_queue_target_position(queue_index, from_position)
	var queue_node := _get_queue_target_node_name(queue_index)
	var direct_route := _make_orthogonal_route(from_position, queue_target, true)

	if _is_queue_route_clear(from_position, direct_route):
		return _dedupe_route_points(direct_route)

	var queue_start := _find_nearest_reachable_graph_node_for_route(from_position, queue_node)

	if bool(queue_start.get("valid", false)):
		var queue_route := queue_start.get("route", []) as Array[Vector2]
		var appended_center := queue_route.is_empty() or _append_clear_queue_target_route_to(queue_route, queue_target, true, from_position)

		if appended_center:
			return _dedupe_route_points(queue_route)

	var approach_node := _get_queue_approach_node_name(queue_index)

	if approach_node != StringName():
		var approach_start := _find_nearest_reachable_graph_node_for_route(from_position, approach_node)

		if bool(approach_start.get("valid", false)):
			var approach_route := approach_start.get("route", []) as Array[Vector2]
			var appended_right := _append_clear_queue_target_route_to(approach_route, queue_target, true, from_position)

			if appended_right:
				return _dedupe_route_points(approach_route)

	return []


func get_route_from_shelf_to_cashier(shelf: Shelf) -> Array[Vector2]:
	if shelf == null:
		return []

	var access_point := get_shelf_access_position(shelf)
	var graph_node := get_shelf_access_graph_node(shelf)

	if not access_point.is_finite() or graph_node == StringName():
		return []

	var path := _find_checkout_graph_path(graph_node)
	var route := _get_surface_access_route(shelf, graph_node, access_point)
	route.reverse()
	route.append_array(_build_route_from_graph_path(path))
	return _dedupe_route_points(route)


func get_exit_route_from(from_position: Vector2, fallback_exit_position: Vector2) -> Array[Vector2]:
	var queue_right_route := _build_exit_route_via_queue_right(from_position, fallback_exit_position)

	if not queue_right_route.is_empty():
		return queue_right_route

	var start := _find_nearest_graph_node(from_position)

	if not bool(start.get("valid", false)):
		return _dedupe_route_points(_make_orthogonal_route(from_position, fallback_exit_position, true))

	var exit_node := _get_role_node_name(ROLE_EXIT, EXIT)
	var path := _find_graph_path(start.get("node", _get_role_node_name(ROLE_ENTRY, ENTRY)) as StringName, exit_node)

	if path.is_empty():
		return _dedupe_route_points(_make_orthogonal_route(from_position, fallback_exit_position, true))

	var route := start.get("route", []) as Array[Vector2]
	route.append_array(_build_route_from_graph_path(path))
	return _dedupe_route_points(route)


func has_reachable_shelf_access(object: Node2D, candidate: Vector2) -> bool:
	return bool(find_best_shelf_access(candidate, object).get("valid", false))


func find_best_shelf_access(candidate_position: Vector2, shelf_object: Node2D) -> Dictionary:
	return _find_best_shelf_access(candidate_position, shelf_object, false)


func find_best_vertical_shelf_access(candidate_position: Vector2, shelf_object: Node2D) -> Dictionary:
	return _find_best_shelf_access(candidate_position, shelf_object, true)


func _find_best_shelf_access(candidate_position: Vector2, shelf_object: Node2D, vertical_only: bool) -> Dictionary:
	var checked_candidates := 0
	var candidates := _get_shelf_access_candidates(candidate_position)
	var blocked_candidates := 0
	var no_route_candidates := 0
	var no_checkout_candidates := 0
	var surface_searches := [0]
	var best_result := {"valid": false}
	var best_score := INF

	for access_candidate in candidates:
		checked_candidates += 1

		if checked_candidates > MAX_SHELF_ACCESS_CANDIDATES:
			break

		var access_point := access_candidate.get("access_point", Vector2.INF) as Vector2
		var vertical_access := bool(access_candidate.get("vertical_access", false))

		if not access_point.is_finite():
			continue

		if vertical_only and not vertical_access:
			continue

		if not _is_npc_access_point_clear(access_point, shelf_object, candidate_position):
			blocked_candidates += 1
			continue

		var reachable_node := _find_reachable_graph_node_for_access(
			access_point,
			access_candidate.get("graph_node", StringName()) as StringName,
			shelf_object,
			candidate_position,
			surface_searches
		)

		if not bool(reachable_node.get("valid", false)):
			no_route_candidates += 1
			continue

		var graph_node := reachable_node.get("node", StringName()) as StringName
		var graph_path := _find_checkout_graph_path(graph_node)

		if graph_path.is_empty():
			no_checkout_candidates += 1
			continue

		var score := (
			float(reachable_node.get("distance", 0.0))
			+ _get_graph_path_cost(graph_path)
			+ float(access_candidate.get("vertical_distance", 0.0)) * 0.1
			+ float(access_candidate.get("horizontal_distance", 0.0)) * 0.25
		)

		if score >= best_score:
			continue

		best_score = score
		best_result = {
			"valid": true,
			"access_point": access_point,
			"graph_node": graph_node,
			"surface_route": reachable_node.get("route", []),
			"score": score,
			"access_side": access_candidate.get("access_side", "")
		}

	if bool(best_result.get("valid", false)):
		return best_result

	_print_shelf_access_failure(
		candidate_position,
		candidates.size(),
		checked_candidates,
		blocked_candidates,
		no_route_candidates,
		no_checkout_candidates
	)
	return {"valid": false}


func store_shelf_access_metadata(object: Node2D, drop_position: Vector2) -> void:
	var result := find_best_vertical_shelf_access(drop_position, object)

	if not bool(result.get("valid", false)):
		clear_shelf_access_metadata(object)
		return

	object.set_meta(ACCESS_META, result.get("access_point", Vector2.INF))
	object.set_meta(ACCESS_NODE_META, result.get("graph_node", StringName()))


func clear_shelf_access_metadata(object: Node2D) -> void:
	if object == null:
		return

	if object.has_meta(ACCESS_META):
		object.remove_meta(ACCESS_META)

	if object.has_meta(ACCESS_NODE_META):
		object.remove_meta(ACCESS_NODE_META)

	if object.has_meta(ACCESS_ROUTE_META):
		object.remove_meta(ACCESS_ROUTE_META)


func _store_access_metadata_from_result(object: Node2D, result: Dictionary) -> void:
	if object == null:
		return

	if not bool(result.get("valid", false)):
		return

	object.set_meta(ACCESS_META, result.get("access_point", Vector2.INF))
	object.set_meta(ACCESS_NODE_META, result.get("graph_node", StringName()))
	object.set_meta(ACCESS_ROUTE_META, result.get("surface_route", []))


func get_shelf_access_graph_node(shelf: Shelf) -> StringName:
	if shelf == null:
		return StringName()

	if shelf.has_meta(ACCESS_NODE_META):
		var graph_node: Variant = shelf.get_meta(ACCESS_NODE_META)

		if graph_node is StringName:
			return graph_node as StringName

		if graph_node is String:
			return StringName(graph_node)

	var result := find_best_vertical_shelf_access(shelf.global_position, shelf)
	_store_access_metadata_from_result(shelf, result)
	return result.get("graph_node", StringName()) as StringName


func _find_nearest_reachable_graph_node(
	access_point: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF
) -> Dictionary:
	var best_result := {"valid": false}
	var best_score := INF

	for node_name in _get_graph_node_names():
		var marker := _get_graph_marker(node_name)

		if marker == null:
			continue

		var route := _make_orthogonal_route(access_point, marker.global_position, true)

		if not _is_route_clear(access_point, route, shelf_object, shelf_position):
			continue

		var distance := _get_manhattan_distance(access_point, marker.global_position)

		if distance < best_score:
			best_score = distance
			best_result = {
				"valid": true,
				"node": node_name,
				"route": route,
				"distance": distance
			}

	return best_result


func _find_reachable_graph_node_for_access(
	access_point: Vector2,
	preferred_node: StringName,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	surface_searches: Array = []
) -> Dictionary:
	if preferred_node != StringName():
		var preferred_marker := _get_graph_marker(preferred_node)

		if preferred_marker != null:
			var preferred_route := _make_orthogonal_route(preferred_marker.global_position, access_point, true)

			if _is_route_clear(preferred_marker.global_position, preferred_route, shelf_object, shelf_position):
				return {
					"valid": true,
					"node": preferred_node,
					"route": preferred_route,
					"distance": _get_manhattan_distance(access_point, preferred_marker.global_position)
				}

			var preferred_surface_route := _find_surface_route_between_marker_and_access(
				preferred_node,
				access_point,
				shelf_object,
				shelf_position,
				surface_searches
			)

			if bool(preferred_surface_route.get("valid", false)):
				return preferred_surface_route

	var best_result := {"valid": false}
	var best_score := INF

	for node_name in _get_graph_node_names():
		var marker := _get_graph_marker(node_name)

		if marker == null:
			continue

		var direct_route := _make_orthogonal_route(marker.global_position, access_point, true)
		var distance := _get_manhattan_distance(access_point, marker.global_position)

		if _is_route_clear(marker.global_position, direct_route, shelf_object, shelf_position):
			if distance < best_score:
				best_score = distance
				best_result = {
					"valid": true,
					"node": node_name,
					"route": direct_route,
					"distance": distance
				}
			continue

		var surface_route := _find_surface_route_between_marker_and_access(
			node_name,
			access_point,
			shelf_object,
			shelf_position,
			surface_searches
		)

		if not bool(surface_route.get("valid", false)):
			continue

		distance = float(surface_route.get("distance", INF))

		if distance < best_score:
			best_score = distance
			best_result = surface_route

	return best_result


func _append_surface_access_route_to(
	route: Array[Vector2],
	shelf: Shelf,
	graph_node: StringName,
	access_point: Vector2,
	route_from_graph: bool
) -> void:
	var access_route := _get_surface_access_route(shelf, graph_node, access_point)

	if access_route.is_empty():
		_append_orthogonal_route_to(route, access_point, true)
		return

	if not route_from_graph:
		access_route.reverse()

	route.append_array(access_route)


func _get_surface_access_route(shelf: Shelf, graph_node: StringName, access_point: Vector2) -> Array[Vector2]:
	if shelf != null and shelf.has_meta(ACCESS_ROUTE_META):
		var route_meta: Variant = shelf.get_meta(ACCESS_ROUTE_META)

		if route_meta is Array:
			var route: Array[Vector2] = []

			for point in route_meta:
				if point is Vector2:
					route.append(point)

			if not route.is_empty():
				return route

	var result := _find_surface_route_between_marker_and_access(
		graph_node,
		access_point,
		shelf,
		shelf.global_position if shelf != null else Vector2.INF
	)

	if bool(result.get("valid", false)):
		var rebuilt_route := result.get("route", []) as Array[Vector2]

		if shelf != null:
			shelf.set_meta(ACCESS_ROUTE_META, rebuilt_route)

		return rebuilt_route

	return []


func _find_surface_route_between_marker_and_access(
	graph_node: StringName,
	access_point: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	surface_searches: Array = []
) -> Dictionary:
	var marker := _get_graph_marker(graph_node)

	if marker == null or not access_point.is_finite():
		return {"valid": false}

	if _shelf_access_points.is_empty():
		return {"valid": false}

	var marker_position := marker.global_position
	var access_indices := _get_nearest_surface_anchor_indices(
		access_point,
		SURFACE_CONNECTOR_LIMIT,
		shelf_object,
		shelf_position
	)
	var marker_indices := _get_nearest_surface_anchor_indices(
		marker_position,
		SURFACE_CONNECTOR_LIMIT,
		shelf_object,
		shelf_position
	)
	var best_route: Array[Vector2] = []
	var best_distance := INF

	for marker_index in marker_indices:
		var marker_anchor := _shelf_access_points[marker_index]
		var marker_route := _make_orthogonal_route(marker_position, marker_anchor, true)

		if not _is_route_clear(marker_position, marker_route, shelf_object, shelf_position):
			continue

		for access_index in access_indices:
			if not _reserve_surface_route_search(surface_searches):
				return {"valid": false}

			var access_anchor := _shelf_access_points[access_index]
			var access_route := _make_orthogonal_route(access_anchor, access_point, true)

			if not _is_route_clear(access_anchor, access_route, shelf_object, shelf_position):
				continue

			var surface_path := _find_surface_anchor_path(marker_index, access_index, shelf_object, shelf_position)

			if surface_path.is_empty():
				continue

			var route := marker_route.duplicate()
			_append_surface_anchor_path_to_route(route, surface_path)
			route.append_array(access_route)
			route = _dedupe_route_points(route)

			if route.is_empty() or not _is_route_clear(marker_position, route, shelf_object, shelf_position):
				continue

			var distance := _get_route_distance(marker_position, route)

			if distance < best_distance:
				best_distance = distance
				best_route = route

	if best_route.is_empty():
		return {"valid": false}

	return {
		"valid": true,
		"node": graph_node,
		"route": best_route,
		"distance": best_distance
	}


func _reserve_surface_route_search(surface_searches: Array) -> bool:
	if surface_searches.is_empty():
		return true

	var current := int(surface_searches[0])

	if current >= MAX_SURFACE_ROUTE_SEARCHES:
		return false

	surface_searches[0] = current + 1
	return true


func _get_nearest_surface_anchor_indices(
	position: Vector2,
	limit: int,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF
) -> Array[int]:
	var indices: Array[int] = []

	if not position.is_finite():
		return indices

	for index in range(_shelf_access_points.size()):
		var point := _shelf_access_points[index]

		if not _is_npc_access_point_clear(point, shelf_object, shelf_position):
			continue

		indices.append(index)

	indices.sort_custom(func(a: int, b: int) -> bool:
		return _shelf_access_points[a].distance_to(position) < _shelf_access_points[b].distance_to(position)
	)

	if indices.size() <= limit:
		return indices

	var limited: Array[int] = []

	for index in range(limit):
		limited.append(indices[index])

	return limited


func _find_surface_anchor_path(
	start_index: int,
	goal_index: int,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF
) -> Array[int]:
	var result: Array[int] = []

	if start_index < 0 or goal_index < 0:
		return result

	if start_index >= _shelf_access_points.size() or goal_index >= _shelf_access_points.size():
		return result

	if start_index == goal_index:
		result.append(start_index)
		return result

	var frontier: Array[int] = [start_index]
	var distances := {start_index: 0.0}
	var previous := {}
	var visited := {}

	while not frontier.is_empty():
		var current := _pop_lowest_cost_surface_node(frontier, distances)

		if visited.has(current):
			continue

		visited[current] = true

		if current == goal_index:
			break

		var current_position := _shelf_access_points[current]

		for neighbor in _get_surface_anchor_neighbors(current):
			if visited.has(neighbor):
				continue

			var neighbor_position := _shelf_access_points[neighbor]

			if not _is_route_segment_clear(current_position, neighbor_position, shelf_object, shelf_position):
				continue

			var edge_cost := current_position.distance_to(neighbor_position)
			var next_cost := float(distances[current]) + edge_cost

			if not distances.has(neighbor) or next_cost < float(distances[neighbor]):
				distances[neighbor] = next_cost
				previous[neighbor] = current

				if neighbor not in frontier:
					frontier.append(neighbor)

	if not distances.has(goal_index):
		return result

	var cursor := goal_index

	while cursor != start_index:
		result.push_front(cursor)
		cursor = int(previous.get(cursor, -1))

		if cursor < 0:
			result.clear()
			return result

	result.push_front(start_index)
	return result


func _append_surface_anchor_path_to_route(route: Array[Vector2], path: Array[int]) -> void:
	for index in path:
		if index < 0 or index >= _shelf_access_points.size():
			continue

		route.append(_shelf_access_points[index])


func _get_surface_anchor_neighbors(index: int) -> Array[int]:
	_ensure_surface_neighbor_cache()

	var raw_neighbors: Variant = _surface_neighbor_cache.get(index, [])
	var neighbors: Array[int] = []

	if raw_neighbors is Array:
		for neighbor in raw_neighbors:
			if neighbor is int:
				neighbors.append(neighbor)

	return neighbors


func _ensure_surface_neighbor_cache() -> void:
	var signature := _get_surface_points_signature(_shelf_access_points)

	if _surface_neighbor_signature == signature:
		return

	_surface_neighbor_cache.clear()
	_surface_neighbor_signature = signature

	for index in range(_shelf_access_points.size()):
		_surface_neighbor_cache[index] = _find_axis_surface_neighbors(index)


func _find_axis_surface_neighbors(source_index: int) -> Array[int]:
	var neighbors: Array[int] = []

	if source_index < 0 or source_index >= _shelf_access_points.size():
		return neighbors

	var source_position := _shelf_access_points[source_index]
	_append_surface_axis_neighbor(neighbors, source_index, source_position, true, -1.0)
	_append_surface_axis_neighbor(neighbors, source_index, source_position, true, 1.0)
	_append_surface_axis_neighbor(neighbors, source_index, source_position, false, -1.0)
	_append_surface_axis_neighbor(neighbors, source_index, source_position, false, 1.0)
	return neighbors


func _append_surface_axis_neighbor(
	neighbors: Array[int],
	source_index: int,
	source_position: Vector2,
	horizontal: bool,
	direction: float
) -> void:
	var best_index := -1
	var best_distance := INF

	for candidate_index in range(_shelf_access_points.size()):
		if candidate_index == source_index:
			continue

		var candidate_position := _shelf_access_points[candidate_index]
		var same_axis := (
			absf(candidate_position.y - source_position.y) <= SURFACE_ALIGNMENT_EPSILON
			if horizontal
			else absf(candidate_position.x - source_position.x) <= SURFACE_ALIGNMENT_EPSILON
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

		if distance <= SURFACE_ALIGNMENT_EPSILON or distance > SURFACE_NEIGHBOR_MAX_DISTANCE:
			continue

		if distance >= best_distance:
			continue

		if not _is_route_segment_clear(source_position, candidate_position):
			continue

		best_index = candidate_index
		best_distance = distance

	if best_index >= 0 and best_index not in neighbors:
		neighbors.append(best_index)


func _pop_lowest_cost_surface_node(frontier: Array[int], distances: Dictionary) -> int:
	var best_index := 0
	var best_cost := INF

	for index in range(frontier.size()):
		var node_index := frontier[index]
		var cost := float(distances.get(node_index, INF))

		if cost < best_cost:
			best_cost = cost
			best_index = index

	return frontier.pop_at(best_index)


func _get_route_distance(start: Vector2, route: Array[Vector2]) -> float:
	var distance := 0.0
	var cursor := start

	for point in route:
		distance += cursor.distance_to(point)
		cursor = point

	return distance


func _get_surface_points_signature(points: Array[Vector2]) -> String:
	var parts: Array[String] = []

	for point in points:
		parts.append("%d,%d" % [roundi(point.x), roundi(point.y)])

	return "|".join(parts)


func _print_shelf_access_failure(
	shelf_position: Vector2,
	total: int,
	checked: int,
	blocked: int,
	no_route: int,
	no_checkout: int
) -> void:
	if not DEBUG_SHELF_ACCESS_FAILURES:
		return

	print(
		"SHELF_ACCESS_DEBUG event=failed shelf_pos=%s total=%d checked=%d blocked=%d no_route=%d no_checkout=%d"
		% [shelf_position, total, checked, blocked, no_route, no_checkout]
	)


func _get_shelf_access_candidates(shelf_position: Vector2) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []

	for node_name in _get_graph_node_names():
		var marker := _get_graph_marker(node_name)

		if marker == null:
			continue

		if not _is_shelf_access_marker(marker):
			continue

		_append_shelf_access_candidate(candidates, marker.global_position, shelf_position, node_name)

	for access_point in _shelf_access_points:
		_append_shelf_access_candidate(candidates, access_point, shelf_position, StringName())

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var tier_a := int(a.get("tier", 2))
		var tier_b := int(b.get("tier", 2))

		if tier_a != tier_b:
			return tier_a < tier_b

		var point_a := a.get("access_point", Vector2.INF) as Vector2
		var point_b := b.get("access_point", Vector2.INF) as Vector2

		var horizontal_a := float(a.get("horizontal_distance", INF))
		var horizontal_b := float(b.get("horizontal_distance", INF))

		if not is_equal_approx(horizontal_a, horizontal_b):
			return horizontal_a < horizontal_b

		var vertical_a := float(a.get("vertical_distance", INF))
		var vertical_b := float(b.get("vertical_distance", INF))

		if not is_equal_approx(vertical_a, vertical_b):
			return vertical_a < vertical_b

		return float(a.get("direct_distance", INF)) < float(b.get("direct_distance", INF))
	)

	return candidates


func _append_shelf_access_candidate(
	candidates: Array[Dictionary],
	access_point: Vector2,
	shelf_position: Vector2,
	graph_node: StringName
) -> void:
	if not access_point.is_finite():
		return

	var horizontal_distance := absf(access_point.x - shelf_position.x)
	var vertical_distance := absf(access_point.y - shelf_position.y)
	var direct_distance := access_point.distance_to(shelf_position)
	var access_side := "below" if access_point.y >= shelf_position.y else "above"

	if direct_distance <= MARKER_ALIGNMENT_EPSILON or direct_distance > MAX_SHELF_ACCESS_DISTANCE:
		return

	var vertical_access := horizontal_distance <= SHELF_ACCESS_COLUMN_EPSILON and vertical_distance > MARKER_ALIGNMENT_EPSILON
	var tier := 2

	if vertical_access:
		tier = 0
	elif horizontal_distance <= SHELF_ACCESS_NEAR_COLUMN_EPSILON and vertical_distance > MARKER_ALIGNMENT_EPSILON:
		tier = 1

	candidates.append({
		"access_point": access_point,
		"graph_node": graph_node,
		"vertical_access": vertical_access,
		"access_side": access_side,
		"tier": tier,
		"horizontal_distance": horizontal_distance,
		"vertical_distance": vertical_distance,
		"direct_distance": direct_distance
	})


func _find_nearest_graph_node(position: Vector2) -> Dictionary:
	var best_result := {"valid": false}
	var best_score := INF

	for node_name in _get_graph_node_names():
		var marker := _get_graph_marker(node_name)

		if marker == null:
			continue

		var distance := _get_manhattan_distance(position, marker.global_position)

		if distance < best_score:
			best_score = distance
			best_result = {
				"valid": true,
				"node": node_name,
				"route": _make_orthogonal_route(position, marker.global_position, true),
				"distance": distance
			}

	return best_result


func _find_nearest_reachable_graph_node_for_route(position: Vector2, goal_node: StringName) -> Dictionary:
	var goal_marker := _get_graph_marker(goal_node)

	if goal_marker == null:
		return {"valid": false}

	var best_result := {"valid": false}
	var best_score := INF

	for node_name in _get_graph_node_names():
		var marker := _get_graph_marker(node_name)

		if marker == null:
			continue

		var entry_route := _make_orthogonal_route(position, marker.global_position, true)

		if not _is_route_clear(position, entry_route):
			continue

		var graph_path := _find_graph_path(node_name, goal_node)

		if graph_path.is_empty():
			continue

		var route := entry_route.duplicate()
		route.append_array(_build_route_from_graph_path(graph_path))
		route = _dedupe_route_points(route)

		if _is_queue_target_node(goal_node):
			if not _is_queue_route_clear(position, route):
				continue
		elif not _is_route_clear(position, route):
			continue

		var score := _get_route_distance(position, route)

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


func _find_graph_path(start_node: StringName, goal_node: StringName) -> Array[StringName]:
	var result: Array[StringName] = []

	if start_node == StringName() or goal_node == StringName():
		return result

	if _get_graph_marker(start_node) == null or _get_graph_marker(goal_node) == null:
		return result

	var frontier: Array[StringName] = [start_node]
	var distances := {start_node: 0.0}
	var previous := {}
	var visited := {}

	while not frontier.is_empty():
		var current := _pop_lowest_cost_node(frontier, distances)

		if visited.has(current):
			continue

		visited[current] = true

		if current == goal_node:
			break

		for neighbor in _get_graph_neighbors(current):
			if visited.has(neighbor):
				continue

			var edge_cost := _get_graph_edge_cost(current, neighbor)

			if edge_cost >= INF:
				continue

			var next_cost := float(distances[current]) + edge_cost

			if not distances.has(neighbor) or next_cost < float(distances[neighbor]):
				distances[neighbor] = next_cost
				previous[neighbor] = current

				if neighbor not in frontier:
					frontier.append(neighbor)

	if not distances.has(goal_node):
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


func _find_checkout_graph_path(start_node: StringName) -> Array[StringName]:
	return _find_best_graph_path(start_node, _get_checkout_goal_node_names())


func _find_best_graph_path(start_node: StringName, goal_nodes: Array[StringName]) -> Array[StringName]:
	var best_path: Array[StringName] = []
	var best_cost := INF

	for goal_node in goal_nodes:
		var path := _find_graph_path(start_node, goal_node)

		if path.is_empty():
			continue

		var cost := _get_graph_path_cost(path)

		if cost < best_cost:
			best_cost = cost
			best_path = path

	return best_path


func _build_route_from_graph_path(path: Array[StringName]) -> Array[Vector2]:
	var route: Array[Vector2] = []
	var previous_position := Vector2.INF

	for node_name in path:
		var marker := _get_graph_marker(node_name)

		if marker == null:
			continue

		if previous_position.is_finite():
			route.append_array(_make_orthogonal_route(previous_position, marker.global_position, true))
		else:
			route.append(marker.global_position)

		previous_position = marker.global_position

	return _dedupe_route_points(route)


func _append_orthogonal_route_to(
	route: Array[Vector2],
	to_pos: Vector2,
	horizontal_first: bool = true,
	fallback_from_pos: Vector2 = Vector2.INF
) -> void:
	var from_pos := fallback_from_pos

	if not route.is_empty():
		from_pos = route[route.size() - 1]

	if not from_pos.is_finite():
		route.append(to_pos)
		return

	route.append_array(_make_orthogonal_route(from_pos, to_pos, horizontal_first))


func _append_clear_orthogonal_route_to(
	route: Array[Vector2],
	to_pos: Vector2,
	horizontal_first: bool = true,
	fallback_from_pos: Vector2 = Vector2.INF
) -> bool:
	var from_pos := fallback_from_pos

	if not route.is_empty():
		from_pos = route[route.size() - 1]

	if not from_pos.is_finite():
		route.append(to_pos)
		return true

	var addition := _make_orthogonal_route(from_pos, to_pos, horizontal_first)

	if not _is_route_clear(from_pos, addition):
		return false

	route.append_array(addition)
	return true


func _append_clear_queue_target_route_to(
	route: Array[Vector2],
	to_pos: Vector2,
	horizontal_first: bool = true,
	fallback_from_pos: Vector2 = Vector2.INF
) -> bool:
	var from_pos := fallback_from_pos

	if not route.is_empty():
		from_pos = route[route.size() - 1]

	if not from_pos.is_finite():
		route.append(to_pos)
		return true

	var addition := _make_orthogonal_route(from_pos, to_pos, horizontal_first)

	if not _is_queue_route_clear(from_pos, addition):
		return false

	route.append_array(addition)
	return true


func _prepend_orthogonal_route(from_pos: Vector2, route: Array[Vector2], horizontal_first: bool = true) -> Array[Vector2]:
	if route.is_empty():
		return []

	var result := _make_orthogonal_route(from_pos, route[0], horizontal_first)
	result.append_array(route)
	return _dedupe_route_points(result)


func _make_orthogonal_route(from_pos: Vector2, to_pos: Vector2, horizontal_first: bool = true) -> Array[Vector2]:
	var route: Array[Vector2] = []

	if from_pos.distance_to(to_pos) <= 2.0:
		return route

	var corner := Vector2(to_pos.x, from_pos.y) if horizontal_first else Vector2(from_pos.x, to_pos.y)

	if from_pos.distance_to(corner) > 2.0:
		route.append(corner)

	if corner.distance_to(to_pos) > 2.0:
		route.append(to_pos)

	return route


func _dedupe_route_points(route: Array[Vector2]) -> Array[Vector2]:
	var deduped: Array[Vector2] = []

	for point in route:
		if not point.is_finite():
			continue

		if not deduped.is_empty() and deduped[deduped.size() - 1].distance_to(point) <= 2.0:
			continue

		deduped.append(point)

	return deduped


func _is_route_clear(
	start: Vector2,
	route: Array[Vector2],
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF
) -> bool:
	var current := start

	for point in route:
		if not _is_route_segment_clear(current, point, shelf_object, shelf_position):
			return false

		current = point

	return true


func _is_queue_route_clear(start: Vector2, route: Array[Vector2]) -> bool:
	var current := start

	for index in range(route.size()):
		var point := route[index]
		var allow_blocked_endpoint := index == route.size() - 1

		if allow_blocked_endpoint:
			if not _is_route_segment_clear_except_endpoint(current, point):
				return false
		elif not _is_route_segment_clear(current, point):
			return false

		current = point

	return true


func _is_route_segment_clear_except_endpoint(from_pos: Vector2, to_pos: Vector2) -> bool:
	if from_pos.distance_to(to_pos) <= ROUTE_CLEARANCE_EPSILON:
		return true

	if not is_equal_approx(from_pos.x, to_pos.x) and not is_equal_approx(from_pos.y, to_pos.y):
		return false

	var distance := from_pos.distance_to(to_pos)
	var steps := maxi(1, int(ceil(distance / ROUTE_SAMPLE_STEP)))

	for index in range(steps):
		var point := from_pos.lerp(to_pos, float(index) / float(steps))

		if not _is_npc_access_point_clear(point):
			return false

	return true


func _is_route_segment_clear(
	from_pos: Vector2,
	to_pos: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF
) -> bool:
	if from_pos.distance_to(to_pos) <= ROUTE_CLEARANCE_EPSILON:
		return true

	if not is_equal_approx(from_pos.x, to_pos.x) and not is_equal_approx(from_pos.y, to_pos.y):
		return false

	var distance := from_pos.distance_to(to_pos)
	var steps := maxi(1, int(ceil(distance / ROUTE_SAMPLE_STEP)))

	for index in range(steps + 1):
		var point := from_pos.lerp(to_pos, float(index) / float(steps))

		if not _is_npc_access_point_clear(point, shelf_object, shelf_position):
			return false

	return true


func _is_npc_access_point_clear(
	position: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF
) -> bool:
	if shelf_object != null and shelf_position.is_finite():
		var shelf_rect := _get_object_body_rect_at(shelf_object, shelf_position)

		if _rect_has_area(shelf_rect) and _get_npc_standing_rect(position).intersects(shelf_rect):
			return false

	return _is_npc_standing_position_clear(position)


func _is_npc_standing_position_clear(position: Vector2, npc: Node = null) -> bool:
	if _store == null:
		return false

	var shape := RectangleShape2D.new()
	shape.size = STANDING_SHAPE_SIZE

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, position + STANDING_SHAPE_OFFSET)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = 1

	if npc is CollisionObject2D:
		query.exclude = [(npc as CollisionObject2D).get_rid()]

	var hits := _store.get_world_2d().direct_space_state.intersect_shape(query, 16)
	return hits.is_empty()


func _get_npc_standing_rect(position: Vector2) -> Rect2:
	var center := position + STANDING_SHAPE_OFFSET
	return Rect2(center - STANDING_SHAPE_SIZE * 0.5, STANDING_SHAPE_SIZE)


func _get_object_body_rect_at(object: Node2D, candidate: Vector2) -> Rect2:
	var collision_shape := _get_object_collision_shape(object)

	if collision_shape == null:
		return Rect2(candidate - Vector2(32, 24), Vector2(64, 48))

	var rectangle := collision_shape.shape as RectangleShape2D

	if rectangle == null:
		return Rect2(candidate - Vector2(32, 24), Vector2(64, 48))

	var center := candidate + collision_shape.position
	return Rect2(center - rectangle.size * 0.5, rectangle.size)


func _get_object_collision_shape(object: Node2D) -> CollisionShape2D:
	if object == null:
		return null

	return object.get_node_or_null("PhysicsBody/CollisionShape2D") as CollisionShape2D


func _rect_has_area(rect: Rect2) -> bool:
	return rect.size.x > 0.0 and rect.size.y > 0.0


func _get_graph_marker(node_name: StringName) -> Marker2D:
	if _markers == null:
		return null

	return _markers.get_node_or_null(String(node_name)) as Marker2D


func _get_graph_node_names() -> Array[StringName]:
	var node_names: Array[StringName] = []

	if _markers == null:
		return node_names

	if _cached_graph_node_count == _markers.get_child_count():
		return _cached_graph_node_names.duplicate()

	for child in _markers.get_children():
		if child is Marker2D:
			node_names.append(StringName(child.name))

	node_names.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b)
	)

	_cached_graph_node_names = node_names
	_cached_graph_node_count = _markers.get_child_count()
	return node_names


func _get_checkout_goal_node_names() -> Array[StringName]:
	var goals: Array[StringName] = []

	for role in CHECKOUT_GOAL_ROLES:
		for node_name in _get_graph_node_names():
			if _get_marker_role(_get_graph_marker(node_name)) == role and node_name not in goals:
				goals.append(node_name)

	if goals.is_empty() and _get_graph_marker(QUEUE_FRONT) != null:
		goals.append(QUEUE_FRONT)

	if _get_graph_marker(CASHIER) != null and CASHIER not in goals:
		goals.append(CASHIER)

	return goals


func _get_queue_target_node_name(queue_index: int) -> StringName:
	if queue_index <= 0:
		return _get_role_node_name(ROLE_QUEUE_FRONT, QUEUE_FRONT)

	var queue_back_nodes := _get_queue_back_node_names()

	if queue_back_nodes.is_empty():
		return _get_role_node_name(ROLE_QUEUE_FRONT, QUEUE_FRONT)

	var back_index := mini(queue_index - 1, queue_back_nodes.size() - 1)
	return queue_back_nodes[back_index]


func _get_queue_approach_node_name(queue_index: int) -> StringName:
	if queue_index <= 0:
		return _get_role_node_name(ROLE_QUEUE_FRONT_RIGHT, StringName())

	var queue_back_right_nodes := _get_queue_back_right_node_names()

	if queue_back_right_nodes.is_empty():
		return _get_role_node_name(ROLE_QUEUE_FRONT_RIGHT, StringName())

	var back_index := mini(queue_index - 1, queue_back_right_nodes.size() - 1)
	return queue_back_right_nodes[back_index]


func _get_queue_back_node_names() -> Array[StringName]:
	var queue_back_nodes: Array[StringName] = []

	for node_name in _get_graph_node_names():
		if _get_marker_role(_get_graph_marker(node_name)) == ROLE_QUEUE_BACK:
			queue_back_nodes.append(node_name)

	queue_back_nodes.sort_custom(func(a: StringName, b: StringName) -> bool:
		var marker_a := _get_graph_marker(a)
		var marker_b := _get_graph_marker(b)

		if marker_a == null or marker_b == null:
			return String(a) < String(b)

		return marker_a.global_position.y < marker_b.global_position.y
	)

	return queue_back_nodes


func _get_queue_back_right_node_names() -> Array[StringName]:
	var queue_back_right_nodes: Array[StringName] = []

	for node_name in _get_graph_node_names():
		if _get_marker_role(_get_graph_marker(node_name)) == ROLE_QUEUE_BACK_RIGHT:
			queue_back_right_nodes.append(node_name)

	queue_back_right_nodes.sort_custom(func(a: StringName, b: StringName) -> bool:
		return _get_queue_marker_index(a) < _get_queue_marker_index(b)
	)

	return queue_back_right_nodes


func _get_queue_right_node_names() -> Array[StringName]:
	var queue_right_nodes: Array[StringName] = []

	var queue_front_right := _get_role_node_name(ROLE_QUEUE_FRONT_RIGHT, StringName())

	if queue_front_right != StringName():
		queue_right_nodes.append(queue_front_right)

	queue_right_nodes.append_array(_get_queue_back_right_node_names())
	queue_right_nodes.sort_custom(func(a: StringName, b: StringName) -> bool:
		return _get_queue_marker_index(a) < _get_queue_marker_index(b)
	)
	return queue_right_nodes


func _get_nearest_queue_right_node_name(position: Vector2) -> StringName:
	var best_node := StringName()
	var best_distance := INF

	for node_name in _get_queue_right_node_names():
		var marker := _get_graph_marker(node_name)

		if marker == null:
			continue

		var distance := position.distance_to(marker.global_position)

		if distance >= best_distance:
			continue

		best_node = node_name
		best_distance = distance

	return best_node


func _build_exit_route_via_queue_right(from_position: Vector2, fallback_exit_position: Vector2) -> Array[Vector2]:
	var queue_right_node := _get_nearest_queue_right_node_name(from_position)

	if queue_right_node == StringName():
		return []

	var queue_right_marker := _get_graph_marker(queue_right_node)

	if queue_right_marker == null:
		return []

	var route := _make_orthogonal_route(from_position, queue_right_marker.global_position, true)
	var route_to_right_clear := _is_route_clear(from_position, route)

	if not route_to_right_clear:
		return []

	var exit_node := _get_role_node_name(ROLE_EXIT, EXIT)

	if exit_node != StringName():
		var exit_path := _find_graph_path(queue_right_node, exit_node)

		if not exit_path.is_empty():
			route.append_array(_build_route_from_graph_path(exit_path))
			return _dedupe_route_points(route)

	var appended_exit := _append_clear_orthogonal_route_to(route, fallback_exit_position, true, from_position)

	if appended_exit:
		return _dedupe_route_points(route)

	return []


func _get_queue_marker_index(node_name: StringName) -> int:
	var marker := _get_graph_marker(node_name)

	if marker == null or not marker.has_meta(&"store_queue_index"):
		return 999

	return int(marker.get_meta(&"store_queue_index"))


func _is_queue_target_node(node_name: StringName) -> bool:
	var role := _get_marker_role(_get_graph_marker(node_name))
	return (
		role == ROLE_QUEUE_FRONT
		or role == ROLE_QUEUE_BACK
		or role == ROLE_QUEUE_FRONT_RIGHT
		or role == ROLE_QUEUE_BACK_RIGHT
	)


func _get_role_node_name(role: StringName, fallback_node_name: StringName = StringName()) -> StringName:
	for node_name in _get_graph_node_names():
		var marker := _get_graph_marker(node_name)

		if _get_marker_role(marker) == role:
			return node_name

	if fallback_node_name != StringName() and _get_graph_marker(fallback_node_name) != null:
		return fallback_node_name

	return StringName()


func _get_marker_role(marker: Marker2D) -> StringName:
	if marker == null or not marker.has_meta(PATH_ROLE_META):
		return StringName()

	var role: Variant = marker.get_meta(PATH_ROLE_META)

	if role is StringName:
		return role as StringName

	if role is String:
		return StringName(role)

	return StringName()


func _is_shelf_access_marker(marker: Marker2D) -> bool:
	if marker == null:
		return false

	var role := _get_marker_role(marker)

	if role == ROLE_QUEUE_FRONT or role == ROLE_QUEUE_BACK or role == ROLE_CASHIER:
		return false

	if bool(marker.get_meta(SHELF_ANCHOR_META, false)):
		return true

	return role == ROLE_ENTRY or role == ROLE_EXIT


func _get_graph_neighbors(node_name: StringName) -> Array[StringName]:
	var marker := _get_graph_marker(node_name)

	if marker == null:
		return []

	var neighbors: Array[StringName] = []
	_append_axis_neighbor(neighbors, node_name, marker.global_position, true, -1.0)
	_append_axis_neighbor(neighbors, node_name, marker.global_position, true, 1.0)
	_append_axis_neighbor(neighbors, node_name, marker.global_position, false, -1.0)
	_append_axis_neighbor(neighbors, node_name, marker.global_position, false, 1.0)
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

	for candidate_name in _get_graph_node_names():
		if candidate_name == source_name:
			continue

		var candidate := _get_graph_marker(candidate_name)

		if candidate == null:
			continue

		var candidate_position := candidate.global_position
		var same_axis := (
			absf(candidate_position.y - source_position.y) <= MARKER_ALIGNMENT_EPSILON
			if horizontal
			else absf(candidate_position.x - source_position.x) <= MARKER_ALIGNMENT_EPSILON
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

		if distance <= MARKER_ALIGNMENT_EPSILON or distance >= best_distance:
			continue

		if not _is_route_clear(source_position, _make_orthogonal_route(source_position, candidate_position, true)):
			continue

		best_name = candidate_name
		best_distance = distance

	if best_name != StringName() and best_name not in neighbors:
		neighbors.append(best_name)


func _get_graph_edge_cost(from_node: StringName, to_node: StringName) -> float:
	var from_marker := _get_graph_marker(from_node)
	var to_marker := _get_graph_marker(to_node)

	if from_marker == null or to_marker == null:
		return INF

	return _get_manhattan_distance(from_marker.global_position, to_marker.global_position)


func _get_graph_path_cost(path: Array[StringName]) -> float:
	var cost := 0.0

	for index in range(1, path.size()):
		cost += _get_graph_edge_cost(path[index - 1], path[index])

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


func _get_manhattan_distance(from_pos: Vector2, to_pos: Vector2) -> float:
	return absf(from_pos.x - to_pos.x) + absf(from_pos.y - to_pos.y)
