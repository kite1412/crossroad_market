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
const ACCESS_SIDE_META: StringName = &"npc_access_side"
const ACCESS_CHECKOUT_SOURCE_META: StringName = &"npc_access_checkout_source"
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
const MAX_VERTICAL_SHELF_ACCESS_DISTANCE: float = 32.0
const SHELF_ACCESS_STANDING_CLEARANCE: float = 1.0
const MAX_SHELF_ACCESS_CANDIDATES: int = 96
const MAX_ACCESS_GRAPH_NODE_CANDIDATES: int = 4
const SURFACE_CONNECTOR_LIMIT: int = 2
const MAX_SURFACE_ROUTE_SEARCHES: int = 8
const SURFACE_ALIGNMENT_EPSILON: float = 2.0
const SURFACE_NEIGHBOR_MAX_DISTANCE: float = 36.0
const PERF_SHELF_THRESHOLD_MSEC: float = 16.0
const DEBUG_SHELF_DISTANCE_THRESHOLD: float = 48.0
const SHELF_ACCESS_DISTANCE_SCORE_WEIGHT: float = 1000.0
const DEBUG_QUEUE_TO_CASHIER_ROUTE: bool = true
const DEBUG_SHELF_ENTRY_ROUTE: bool = true
const DEBUG_DIRECT_CHECKOUT_VERBOSE: bool = false
const DEBUG_QUEUE_GRAPH_CANDIDATES_VERBOSE: bool = false

var _store: Node2D = null
var _markers: Node2D = null
var _shelf_access_points: Array[Vector2] = []
var _surface_neighbor_cache := {}
var _surface_neighbor_signature := ""
var _cached_shelf_anchor_positions: Array[Vector2] = []
var _cached_shelf_anchor_count: int = -1
var _cached_graph_node_names: Array[StringName] = []
var _cached_graph_node_count: int = -1
var _last_queue_route_candidate_debug_key: String = ""


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


func _get_marker_position(node_name: StringName) -> Vector2:
	var marker := _get_graph_marker(node_name)
	return marker.global_position if marker != null else Vector2.INF


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

	if marker == null:
		return fallback_position

	# Apply queue slot offset when using front marker fallback (no queue_back markers set up).
	# Without this, all NPCs with queue_index > 0 stack on the same front-marker position.
	var front_node := _get_role_node_name(ROLE_QUEUE_FRONT, QUEUE_FRONT)
	if queue_index > 0 and node_name == front_node:
		const QUEUE_SLOT_SPACING := Vector2(0, 22)
		return marker.global_position + QUEUE_SLOT_SPACING * queue_index

	return marker.global_position


func get_cashier_target_position(fallback_position: Vector2) -> Vector2:
	var marker := get_marker_for_role(ROLE_CASHIER, CASHIER)
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


func get_route_to_shelf_access(shelf: Shelf, from_position: Vector2 = Vector2.INF, npc_node: Node = null) -> Array[Vector2]:
	if shelf == null:
		return []

	var access_point := get_shelf_access_position(shelf)
	var graph_node := get_shelf_access_graph_node(shelf)

	if not access_point.is_finite() or graph_node == StringName():
		return []

	var route_start := from_position if from_position.is_finite() else _get_marker_position(_get_role_node_name(ROLE_ENTRY, ENTRY))
	var entry_route_result := _get_entry_to_access_route(access_point, shelf, graph_node, route_start, npc_node)

	if bool(entry_route_result.get("valid", false)):
		var entry_route := entry_route_result.get("route", []) as Array[Vector2]
		_print_shelf_entry_route_debug(shelf, access_point, graph_node, str(entry_route_result.get("source", "")), entry_route)
		return _dedupe_route_points(entry_route)

	var start_node := _find_nearest_graph_node(route_start)
	var path := _find_graph_path(start_node.get("node", _get_role_node_name(ROLE_ENTRY, ENTRY)) as StringName, graph_node) if bool(start_node.get("valid", false)) else []
	var route := (start_node.get("route", []) as Array[Vector2]).duplicate()
	route.append_array(_build_route_from_graph_path(path))
	_append_surface_access_route_to(route, shelf, graph_node, access_point, true)
	var fallback_route := _dedupe_route_points(route)
	_print_shelf_entry_route_debug(shelf, access_point, graph_node, "metadata_fallback", fallback_route)
	return fallback_route


func get_route_to_cashier_from(from_position: Vector2) -> Array[Vector2]:
	var start := _find_nearest_graph_node(from_position)

	if not bool(start.get("valid", false)):
		_print_cashier_route_debug(from_position, StringName(), StringName(), [], [], [], "no_start")
		return []

	var cashier_node := _get_role_node_name(ROLE_CASHIER, CASHIER)
	var cashier_marker := _get_graph_marker(cashier_node)
	var direct_routes: Array = []

	if cashier_marker != null:
		for order in [
			{"horizontal_first": true, "label": "horizontal"},
			{"horizontal_first": false, "label": "vertical"}
		]:
			var direct_route := _make_orthogonal_route(from_position, cashier_marker.global_position, bool(order.get("horizontal_first", true)))
			var direct_clear := _is_queue_route_clear_from_current_position(from_position, direct_route)
			direct_routes.append({
				"order": str(order.get("label", "")),
				"clear": direct_clear,
				"route": direct_route
			})

			if direct_clear:
				var direct_result := _dedupe_route_points(direct_route)
				_print_cashier_route_debug(
					from_position,
					start.get("node", StringName()) as StringName,
					cashier_node,
					[],
					direct_result,
					direct_routes,
					"direct_%s" % str(order.get("label", ""))
				)
				return direct_result

	var path := _find_graph_path(start.get("node", cashier_node) as StringName, cashier_node)
	var route := start.get("route", []) as Array[Vector2]
	route.append_array(_build_route_from_graph_path(path))
	var result := _dedupe_route_points(route)

	_print_cashier_route_debug(
		from_position,
		start.get("node", StringName()) as StringName,
		cashier_node,
		path,
		result,
		direct_routes,
		"graph"
	)
	return result


func get_route_to_queue_target_from(from_position: Vector2, queue_index: int) -> Array[Vector2]:
	var queue_target := get_queue_target_position(queue_index, from_position)
	var queue_node := _get_queue_target_node_name(queue_index)
	var direct_route: Array[Vector2] = [queue_target]
	var direct_clear := _is_queue_route_clear_from_current_position(from_position, direct_route)
	_print_queue_route_candidate_debug("direct_horizontal", from_position, queue_index, queue_node, queue_target, direct_route, _debug_queue_route_clear_from_current_position(from_position, direct_route))

	var direct_vertical_route := _make_orthogonal_route(from_position, queue_target, false)
	_print_queue_route_candidate_debug("direct_vertical", from_position, queue_index, queue_node, queue_target, direct_vertical_route, _debug_queue_route_clear_from_current_position(from_position, direct_vertical_route))

	if direct_clear:
		var direct_result := _dedupe_route_points(direct_route)
		return direct_result

	var queue_start := _find_nearest_reachable_graph_node_for_route(from_position, queue_node)

	if bool(queue_start.get("valid", false)):
		var queue_route := queue_start.get("route", []) as Array[Vector2]
		var appended_center := queue_route.is_empty() or _append_clear_queue_target_route_to(queue_route, queue_target, true, from_position)
		_print_queue_route_candidate_debug("nearest_center", from_position, queue_index, queue_node, queue_target, queue_route, _debug_queue_route_clear_from_current_position(from_position, queue_route), queue_start)

		if appended_center:
			var center_result := _dedupe_route_points(queue_route)
			return center_result
	else:
		_print_queue_route_candidate_debug("nearest_center", from_position, queue_index, queue_node, queue_target, [], {"valid": false, "blocked_reason": "no_reachable_graph_node"}, queue_start)

	var approach_node := _get_queue_approach_node_name(queue_index)

	if approach_node != StringName():
		var approach_start := _find_nearest_reachable_graph_node_for_route(from_position, approach_node)

		if bool(approach_start.get("valid", false)):
			var approach_route := approach_start.get("route", []) as Array[Vector2]
			var appended_right := _append_clear_queue_target_route_to(approach_route, queue_target, true, from_position)
			_print_queue_route_candidate_debug("right_marker_fallback", from_position, queue_index, approach_node, queue_target, approach_route, _debug_queue_route_clear_from_current_position(from_position, approach_route), approach_start)

			if appended_right:
				var right_result := _dedupe_route_points(approach_route)
				return right_result
		else:
			_print_queue_route_candidate_debug("right_marker_fallback", from_position, queue_index, approach_node, queue_target, [], {"valid": false, "blocked_reason": "no_reachable_graph_node"}, approach_start)

	return []


func get_route_from_shelf_to_cashier(shelf: Shelf) -> Array[Vector2]:
	if shelf == null:
		return []

	var access_point := get_shelf_access_position(shelf)
	var graph_node := get_shelf_access_graph_node(shelf)

	if not access_point.is_finite() or graph_node == StringName():
		return []

	var direct_target_node := _get_direct_checkout_target_node_name(access_point)
	var direct_target_marker := _get_graph_marker(direct_target_node)
	var direct_route: Array[Vector2] = []
	var direct_clear := false

	if direct_target_marker != null:
		direct_route = _make_orthogonal_route(access_point, direct_target_marker.global_position, true)
		direct_clear = _is_route_clear(access_point, direct_route, shelf, shelf.global_position)

		if direct_clear:
			var direct_result := _dedupe_route_points(direct_route)
			_print_shelf_to_checkout_debug(shelf, access_point, graph_node, direct_target_node, direct_clear, 0, "direct", direct_result)
			return direct_result

	var path := _find_checkout_graph_path(graph_node)
	var route := _get_surface_access_route(shelf, graph_node, access_point)
	var surface_route_points := route.size()
	route.reverse()
	route.append_array(_build_route_from_graph_path(path))
	var result := _dedupe_route_points(route)

	if not result.is_empty() and _is_route_clear(access_point, result, shelf, shelf.global_position):
		_print_shelf_to_checkout_debug(shelf, access_point, graph_node, direct_target_node, direct_clear, surface_route_points, "surface_fallback", result)
		return result

	_print_shelf_to_checkout_debug(shelf, access_point, graph_node, direct_target_node, direct_clear, surface_route_points, "empty", [])
	return []


func get_exit_route_from(from_position: Vector2, fallback_exit_position: Vector2) -> Array[Vector2]:
	var queue_right_route := _build_exit_route_via_queue_right(from_position, fallback_exit_position)

	if not queue_right_route.is_empty():
		return queue_right_route

	var start := _find_nearest_graph_node(from_position)

	if not bool(start.get("valid", false)):
		var no_start_route := _dedupe_route_points(_make_orthogonal_route(from_position, fallback_exit_position, true))
		return no_start_route

	var exit_node := _get_role_node_name(ROLE_EXIT, EXIT)
	var path := _find_graph_path(start.get("node", _get_role_node_name(ROLE_ENTRY, ENTRY)) as StringName, exit_node)

	if path.is_empty():
		var no_path_route := _dedupe_route_points(_make_orthogonal_route(from_position, fallback_exit_position, true))
		return no_path_route

	var route := start.get("route", []) as Array[Vector2]
	route.append_array(_build_route_from_graph_path(path))
	var result := _dedupe_route_points(route)
	return result


func has_reachable_shelf_access(object: Node2D, candidate: Vector2) -> bool:
	return bool(find_best_shelf_access(candidate, object).get("valid", false))


func find_best_shelf_access(candidate_position: Vector2, shelf_object: Node2D) -> Dictionary:
	return _find_best_shelf_access(candidate_position, shelf_object, false)


func find_best_vertical_shelf_access(candidate_position: Vector2, shelf_object: Node2D) -> Dictionary:
	return _find_best_shelf_access(candidate_position, shelf_object, true)


func _find_best_shelf_access(candidate_position: Vector2, shelf_object: Node2D, vertical_only: bool) -> Dictionary:
	var debug_start_usec := Time.get_ticks_usec()
	var candidates_start_usec := Time.get_ticks_usec()
	var candidates := _get_shelf_access_candidates(candidate_position, vertical_only)
	var candidates_elapsed_msec := _elapsed_msec(candidates_start_usec)
	var cashier_marker := get_marker_for_role(ROLE_CASHIER, CASHIER)
	var cashier_pos := cashier_marker.global_position if cashier_marker != null else Vector2.INF
	# Softcode vertical flow decision: prefer the side CLOSER to cashier counter.
	# If shelf is below counter (shelf_y > counter_y) → prefer BELOW approach.
	# If shelf is above counter (shelf_y < counter_y) → prefer ABOVE approach.
	# This ensures NPC routes through the cashier area, not around/behind it.
	var prefer_below := false
	if cashier_pos.is_finite() and candidate_position.is_finite():
		prefer_below = candidate_position.y < cashier_pos.y - 4.0
	const COUNTER_DIRECTION_PENALTY_SCALE: float = 1000.0

	var surface_searches := [0]
	var surface_route_cache := {}
	var surface_anchor_path_cache := {}
	var best_result := {"valid": false}
	var best_score := INF
	var checked_candidates := 0
	var blocked_candidates := 0
	var no_surface_route_candidates := 0
	var no_checkout_route_candidates := 0
	var valid_candidates := 0
	var clear_check_elapsed_msec := 0.0
	var reachable_elapsed_msec := 0.0
	var checkout_elapsed_msec := 0.0
	var scoring_elapsed_msec := 0.0
	# Track whether the preferred side (closer to counter) has at least one clear candidate.
	# Used to reject wrong-side candidates when preferred side already has a valid path.
	var preferred_side_cleared := false

	for access_candidate in candidates:
		checked_candidates += 1

		if checked_candidates > MAX_SHELF_ACCESS_CANDIDATES:
			break

		var access_point := access_candidate.get("access_point", Vector2.INF) as Vector2
		var vertical_access := bool(access_candidate.get("vertical_access", false))
		var access_side := str(access_candidate.get("access_side", ""))
		var vertical_distance := float(access_candidate.get("vertical_distance", INF))

		if not access_point.is_finite():
			continue

		if vertical_only and not vertical_access:
			continue

		var clear_start_usec := Time.get_ticks_usec()
		var clear_result := _debug_npc_access_point_clear(access_point, shelf_object, candidate_position)

		if bool(clear_result.get("valid", false)):
			# Track whether the preferred side (closer to counter) has at least one clear candidate.
			# If so, reject wrong-side candidates — they would require NPC to approach from the
			# opposite direction of the counter, which means going around/behind the counter.
			var candidate_is_preferred_side := (access_side == "below") == prefer_below
			if candidate_is_preferred_side:
				preferred_side_cleared = true
			elif prefer_below and cashier_pos.is_finite():
				# Shelf is below counter and this is an "above" candidate.
				# Since preferred side ("below") already has a clear path, skip this.
				clear_check_elapsed_msec += _elapsed_msec(clear_start_usec)
				blocked_candidates += 1
				continue
			elif not prefer_below and cashier_pos.is_finite():
				# Shelf is above counter and this is a "below" candidate.
				# Since preferred side ("above") already has a clear path, skip this.
				clear_check_elapsed_msec += _elapsed_msec(clear_start_usec)
				blocked_candidates += 1
				continue
		else:
			clear_check_elapsed_msec += _elapsed_msec(clear_start_usec)
			blocked_candidates += 1
			_print_shelf_vertical_candidate_debug(
				vertical_only,
				shelf_object,
				candidate_position,
				access_point,
				access_side,
				vertical_distance,
				false,
				false,
				StringName(),
				0,
				false,
				INF,
				"blocked",
				"invalid",
				clear_result,
				false
			)
			continue
		clear_check_elapsed_msec += _elapsed_msec(clear_start_usec)

		var direct_checkout := _get_direct_checkout_access(access_point, shelf_object, candidate_position)

		if bool(direct_checkout.get("valid", false)):
			var graph_node := direct_checkout.get("node", StringName()) as StringName
			var scoring_start_usec := Time.get_ticks_usec()
			var score := (
				float(access_candidate.get("vertical_distance", 0.0)) * SHELF_ACCESS_DISTANCE_SCORE_WEIGHT
				+ float(direct_checkout.get("distance", 0.0))
				+ float(access_candidate.get("horizontal_distance", 0.0)) * 0.25
			)
			# Softcode vertical direction bias: penalize wrong-side candidates
			# by their distance from the counter (wrong side = farther from counter).
			var candidate_prefer_below := access_side == "below"
			if prefer_below != candidate_prefer_below and cashier_pos.is_finite():
				var wrong_side_dist := absf(access_point.y - cashier_pos.y)
				score += wrong_side_dist * COUNTER_DIRECTION_PENALTY_SCALE
			scoring_elapsed_msec += _elapsed_msec(scoring_start_usec)
			valid_candidates += 1
			_print_shelf_vertical_candidate_debug(
				vertical_only,
				shelf_object,
				candidate_position,
				access_point,
				access_side,
				vertical_distance,
				true,
				true,
				graph_node,
				0,
				true,
				score,
				"valid",
				str(direct_checkout.get("checkout_source", "direct")),
				{},
				false
			)

			if score < best_score:
				best_score = score
				best_result = {
					"valid": true,
					"access_point": access_point,
					"graph_node": graph_node,
					"surface_route": [],
					"score": score,
					"access_side": access_candidate.get("access_side", ""),
					"checkout_source": direct_checkout.get("checkout_source", "")
				}

			continue

		var direct_checkout_attempts := direct_checkout.get("attempts", []) as Array
		var candidate_surface_searches := [0]
		var reachable_start_usec := Time.get_ticks_usec()
		var reachable_node := _find_reachable_graph_node_for_access(
			access_point,
			access_candidate.get("graph_node", StringName()) as StringName,
			shelf_object,
			candidate_position,
			candidate_surface_searches,
			surface_route_cache,
			surface_anchor_path_cache
		)
		surface_searches[0] = int(surface_searches[0]) + int(candidate_surface_searches[0])
		reachable_elapsed_msec += _elapsed_msec(reachable_start_usec)

		if not bool(reachable_node.get("valid", false)):
			no_surface_route_candidates += 1
			_print_shelf_vertical_candidate_debug(
				vertical_only,
				shelf_object,
				candidate_position,
				access_point,
				access_side,
				vertical_distance,
				true,
				false,
				StringName(),
				int(candidate_surface_searches[0]),
				false,
				INF,
				"no_surface_route",
				"invalid",
				reachable_node,
				false
			)
			continue

		var graph_node := reachable_node.get("node", StringName()) as StringName
		_print_direct_checkout_fallback_debug(
			vertical_only,
			shelf_object,
			candidate_position,
			access_point,
			access_side,
			direct_checkout_attempts,
			"surface_graph_candidate"
		)
		var checkout_start_usec := Time.get_ticks_usec()
		var graph_path := _find_checkout_graph_path(graph_node)
		checkout_elapsed_msec += _elapsed_msec(checkout_start_usec)

		if graph_path.is_empty():
			no_checkout_route_candidates += 1
			_print_shelf_vertical_candidate_debug(
				vertical_only,
				shelf_object,
				candidate_position,
				access_point,
				access_side,
				vertical_distance,
				true,
				true,
				graph_node,
				int(candidate_surface_searches[0]),
				false,
				INF,
				"no_checkout_route",
				"invalid",
				{},
				false
			)
			continue

		var scoring_start_usec := Time.get_ticks_usec()
		var score := (
			float(access_candidate.get("vertical_distance", 0.0)) * SHELF_ACCESS_DISTANCE_SCORE_WEIGHT
			+ float(reachable_node.get("distance", 0.0))
			+ _get_graph_path_cost(graph_path)
			+ float(access_candidate.get("horizontal_distance", 0.0)) * 0.25
		)
		# Softcode vertical direction bias: penalize wrong-side candidates
		# by their distance from the counter (wrong side = farther from counter).
		var candidate_prefer_below := access_side == "below"
		if prefer_below != candidate_prefer_below and cashier_pos.is_finite():
			var wrong_side_dist := absf(access_point.y - cashier_pos.y)
			score += wrong_side_dist * COUNTER_DIRECTION_PENALTY_SCALE
		scoring_elapsed_msec += _elapsed_msec(scoring_start_usec)
		valid_candidates += 1
		_print_shelf_vertical_candidate_debug(
			vertical_only,
			shelf_object,
			candidate_position,
			access_point,
			access_side,
			vertical_distance,
			true,
			true,
			graph_node,
			int(candidate_surface_searches[0]),
			true,
			score,
			"valid",
			"surface_graph",
			{},
			false
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
			"access_side": access_candidate.get("access_side", ""),
			"checkout_source": "surface_graph"
		}

	var total_elapsed_msec := _elapsed_msec(debug_start_usec)
	_print_shelf_access_perf_if_needed(
		shelf_object,
		candidate_position,
		vertical_only,
		best_result,
		{
			"total_ms": total_elapsed_msec,
			"candidates_ms": candidates_elapsed_msec,
			"clear_ms": clear_check_elapsed_msec,
			"reachable_ms": reachable_elapsed_msec,
			"checkout_ms": checkout_elapsed_msec,
			"scoring_ms": scoring_elapsed_msec,
			"candidate_count": candidates.size(),
			"checked": checked_candidates,
			"blocked": blocked_candidates,
			"no_surface_route": no_surface_route_candidates,
			"no_checkout_route": no_checkout_route_candidates,
			"valid": valid_candidates,
			"surface_searches": int(surface_searches[0])
		}
	)

	if bool(best_result.get("valid", false)):
		_print_selected_shelf_vertical_candidate_debug(vertical_only, shelf_object, candidate_position, best_result)
		return best_result

	return {"valid": false}


func store_shelf_access_metadata(object: Node2D, drop_position: Vector2) -> void:
	var result := find_best_vertical_shelf_access(drop_position, object)

	if not bool(result.get("valid", false)):
		clear_shelf_access_metadata(object)
		return

	_store_access_metadata_from_result(object, result)


func clear_shelf_access_metadata(object: Node2D) -> void:
	if object == null:
		return

	if object.has_meta(ACCESS_META):
		object.remove_meta(ACCESS_META)

	if object.has_meta(ACCESS_NODE_META):
		object.remove_meta(ACCESS_NODE_META)

	if object.has_meta(ACCESS_ROUTE_META):
		object.remove_meta(ACCESS_ROUTE_META)

	if object.has_meta(ACCESS_SIDE_META):
		object.remove_meta(ACCESS_SIDE_META)

	if object.has_meta(ACCESS_CHECKOUT_SOURCE_META):
		object.remove_meta(ACCESS_CHECKOUT_SOURCE_META)


func _store_access_metadata_from_result(object: Node2D, result: Dictionary) -> void:
	if object == null:
		return

	if not bool(result.get("valid", false)):
		return

	object.set_meta(ACCESS_META, result.get("access_point", Vector2.INF))
	object.set_meta(ACCESS_NODE_META, result.get("graph_node", StringName()))
	object.set_meta(ACCESS_ROUTE_META, result.get("surface_route", []))
	object.set_meta(ACCESS_SIDE_META, result.get("access_side", ""))
	object.set_meta(ACCESS_CHECKOUT_SOURCE_META, result.get("checkout_source", ""))


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
	surface_searches: Array = [],
	surface_route_cache: Dictionary = {},
	surface_anchor_path_cache: Dictionary = {}
) -> Dictionary:
	var graph_node_names := _get_nearest_graph_node_names_for_access(
		access_point,
		preferred_node,
		MAX_ACCESS_GRAPH_NODE_CANDIDATES
	)

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

	var best_result := {"valid": false}
	var best_score := INF

	for node_name in graph_node_names:
		if node_name == preferred_node:
			continue

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

	if bool(best_result.get("valid", false)):
		return best_result

	for node_name in graph_node_names:
		var marker := _get_graph_marker(node_name)

		if marker == null:
			continue

		var distance := _get_manhattan_distance(access_point, marker.global_position)

		if distance >= best_score:
			continue

		var surface_route := _find_surface_route_between_marker_and_access(
			node_name,
			access_point,
			shelf_object,
			shelf_position,
			surface_searches,
			surface_route_cache,
			surface_anchor_path_cache
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
	surface_searches: Array = [],
	surface_route_cache: Dictionary = {},
	surface_anchor_path_cache: Dictionary = {}
) -> Dictionary:
	var cache_key := _get_surface_route_cache_key(graph_node, access_point)

	if surface_route_cache.has(cache_key):
		return surface_route_cache[cache_key].duplicate(true)

	var debug_start_usec := Time.get_ticks_usec()
	var initial_surface_searches := int(surface_searches[0]) if not surface_searches.is_empty() else 0
	var marker := _get_graph_marker(graph_node)

	if marker == null or not access_point.is_finite():
		var missing_result := {"valid": false}
		surface_route_cache[cache_key] = missing_result
		_print_surface_route_perf_if_slow(
			debug_start_usec,
			graph_node,
			access_point,
			0,
			0,
			initial_surface_searches,
			surface_searches,
			false,
			INF,
			"missing_marker_or_access"
		)
		return missing_result.duplicate(true)

	if _shelf_access_points.is_empty():
		var empty_result := {"valid": false}
		surface_route_cache[cache_key] = empty_result
		_print_surface_route_perf_if_slow(
			debug_start_usec,
			graph_node,
			access_point,
			0,
			0,
			initial_surface_searches,
			surface_searches,
			false,
			INF,
			"empty_surface_points"
		)
		return empty_result.duplicate(true)

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
				var search_limit_result := {"valid": false}
				surface_route_cache[cache_key] = search_limit_result
				_print_surface_route_perf_if_slow(
					debug_start_usec,
					graph_node,
					access_point,
					marker_indices.size(),
					access_indices.size(),
					initial_surface_searches,
					surface_searches,
					false,
					best_distance,
					"search_limit"
				)
				return search_limit_result.duplicate(true)

			var access_anchor := _shelf_access_points[access_index]
			var access_route := _make_orthogonal_route(access_anchor, access_point, true)

			if not _is_route_clear(access_anchor, access_route, shelf_object, shelf_position):
				continue

			var surface_path := _find_surface_anchor_path(
				marker_index,
				access_index,
				shelf_object,
				shelf_position,
				surface_anchor_path_cache
			)

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
		var no_route_result := {"valid": false}
		surface_route_cache[cache_key] = no_route_result
		_print_surface_route_perf_if_slow(
			debug_start_usec,
			graph_node,
			access_point,
			marker_indices.size(),
			access_indices.size(),
			initial_surface_searches,
			surface_searches,
			false,
			best_distance,
			"no_route"
		)
		return no_route_result.duplicate(true)

	_print_surface_route_perf_if_slow(
		debug_start_usec,
		graph_node,
		access_point,
		marker_indices.size(),
		access_indices.size(),
		initial_surface_searches,
		surface_searches,
		true,
		best_distance,
		"valid"
	)

	var result := {
		"valid": true,
		"node": graph_node,
		"route": best_route,
		"distance": best_distance
	}
	surface_route_cache[cache_key] = result
	return result.duplicate(true)


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
	shelf_position: Vector2 = Vector2.INF,
	surface_anchor_path_cache: Dictionary = {}
) -> Array[int]:
	var cache_key := _get_surface_anchor_path_cache_key(start_index, goal_index)

	if surface_anchor_path_cache.has(cache_key):
		return (surface_anchor_path_cache[cache_key] as Array[int]).duplicate()

	var result: Array[int] = []

	if start_index < 0 or goal_index < 0:
		surface_anchor_path_cache[cache_key] = result
		return result

	if start_index >= _shelf_access_points.size() or goal_index >= _shelf_access_points.size():
		surface_anchor_path_cache[cache_key] = result
		return result

	if start_index == goal_index:
		result.append(start_index)
		surface_anchor_path_cache[cache_key] = result
		return result

	var frontier: Array[int] = [start_index]
	var g_score := {start_index: 0.0}
	var goal_pos := _shelf_access_points[goal_index]
	var f_score := {start_index: _shelf_access_points[start_index].distance_to(goal_pos)}
	var previous := {}
	var visited := {}

	while not frontier.is_empty():
		var current := _pop_lowest_cost_surface_node(frontier, f_score)

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
			var next_cost := float(g_score.get(current, 0.0)) + edge_cost

			if not g_score.has(neighbor) or next_cost < float(g_score[neighbor]):
				g_score[neighbor] = next_cost
				var h_cost := neighbor_position.distance_to(goal_pos)
				f_score[neighbor] = next_cost + h_cost
				previous[neighbor] = current

				if neighbor not in frontier:
					frontier.append(neighbor)

	if not g_score.has(goal_index):
		surface_anchor_path_cache[cache_key] = result
		return result

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


func _variant_route_to_vector2_array(route: Array) -> Array[Vector2]:
	var points: Array[Vector2] = []

	for point in route:
		if point is Vector2:
			points.append(point as Vector2)

	return points


func _elapsed_msec(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000.0


func _print_shelf_access_perf_if_needed(
	shelf_object: Node2D,
	shelf_position: Vector2,
	vertical_only: bool,
	result: Dictionary,
	summary: Dictionary
) -> void:
	var access_point := result.get("access_point", Vector2.INF) as Vector2
	var distance_to_shelf := shelf_position.distance_to(access_point) if access_point.is_finite() else INF
	var total_msec := float(summary.get("total_ms", 0.0))
	var should_print := total_msec >= PERF_SHELF_THRESHOLD_MSEC or distance_to_shelf > DEBUG_SHELF_DISTANCE_THRESHOLD or not bool(result.get("valid", false))

	if not should_print:
		return

	print(
		"[DEBUG][PERF_SHELF] stage=access_summary shelf=%s shelf_pos=%s vertical_only=%s valid=%s access_point=%s access_side=%s graph_node=%s distance_to_shelf=%.2f score=%s surface_route_points=%d summary=%s" % [
			_get_perf_shelf_name(shelf_object),
			str(shelf_position),
			str(vertical_only),
			str(result.get("valid", false)),
			str(access_point),
			str(result.get("access_side", "")),
			str(result.get("graph_node", StringName())),
			distance_to_shelf,
			str(result.get("score", INF)),
			_get_debug_route_point_count(result.get("surface_route", [])),
			str(summary)
		]
	)


func _print_shelf_vertical_candidate_debug(
	vertical_only: bool,
	shelf_object: Node2D,
	shelf_position: Vector2,
	access_point: Vector2,
	access_side: String,
	distance_to_shelf: float,
	clear: bool,
	reachable: bool,
	graph_node: StringName,
	surface_searches: int,
	checkout_path_valid: bool,
	score: float,
	reject_reason: String,
	checkout_source: String = "invalid",
	debug_result: Dictionary = {},
	selected: bool = false
) -> void:
	if not vertical_only:
		return

	print(
		"[DEBUG][SHELF_VERTICAL_DECISION] shelf=%s shelf_pos=%s access_point=%s access_side=%s distance_to_shelf=%.2f clear=%s reachable=%s graph_node=%s surface_searches=%d surface_route_points=%d checkout_path_valid=%s checkout_source=%s score=%s reject_reason=%s blocked_point=%s blocked_reason=%s blocker=%s selected=%s shelf_rect=%s standing_rect=%s rect_intersects=%s" % [
			_get_perf_shelf_name(shelf_object),
			str(shelf_position),
			str(access_point),
			access_side,
			distance_to_shelf,
			str(clear),
			str(reachable),
			str(graph_node),
			surface_searches,
			_get_debug_route_point_count(debug_result.get("route", [])),
			str(checkout_path_valid),
			checkout_source,
			str(score),
			reject_reason,
			str(debug_result.get("blocked_point", Vector2.INF)),
			str(debug_result.get("blocked_reason", "")),
			str(debug_result.get("blocker", "")),
			str(selected),
			str(_get_object_body_rect_at(shelf_object, shelf_position) if shelf_object != null else Rect2()),
			str(_get_npc_standing_rect(access_point)),
			str(_rect_has_area(_get_object_body_rect_at(shelf_object, shelf_position)) and _get_npc_standing_rect(access_point).intersects(_get_object_body_rect_at(shelf_object, shelf_position)) if shelf_object != null else false)
		]
	)


func _print_selected_shelf_vertical_candidate_debug(
	vertical_only: bool,
	shelf_object: Node2D,
	shelf_position: Vector2,
	result: Dictionary
) -> void:
	if not vertical_only:
		return

	var access_point := result.get("access_point", Vector2.INF) as Vector2
	_print_shelf_vertical_candidate_debug(
		vertical_only,
		shelf_object,
		shelf_position,
		access_point,
		str(result.get("access_side", "")),
		shelf_position.distance_to(access_point) if access_point.is_finite() else INF,
		true,
		true,
		result.get("graph_node", StringName()) as StringName,
		0,
		true,
		float(result.get("score", INF)),
		"selected",
		str(result.get("checkout_source", "")),
		{"route": result.get("surface_route", [])},
		true
	)


func _print_surface_route_perf_if_slow(
	start_usec: int,
	graph_node: StringName,
	access_point: Vector2,
	marker_index_count: int,
	access_index_count: int,
	initial_surface_searches: int,
	surface_searches: Array,
	valid: bool,
	best_distance: float,
	reason: String
) -> void:
	var elapsed_msec := _elapsed_msec(start_usec)

	if elapsed_msec < PERF_SHELF_THRESHOLD_MSEC:
		return

	var final_surface_searches := int(surface_searches[0]) if not surface_searches.is_empty() else initial_surface_searches

	print(
		"[DEBUG][PERF_SHELF] stage=surface_route node=%s access_point=%s valid=%s reason=%s marker_indices=%d access_indices=%d searches=%d best_distance=%s elapsed_ms=%.2f" % [
			str(graph_node),
			str(access_point),
			str(valid),
			reason,
			marker_index_count,
			access_index_count,
			final_surface_searches - initial_surface_searches,
			str(best_distance),
			elapsed_msec
		]
	)


func _get_perf_shelf_name(shelf_object: Node2D) -> String:
	return shelf_object.name if shelf_object != null else "<null>"


func _get_debug_route_point_count(route_variant: Variant) -> int:
	if not (route_variant is Array):
		return 0

	return (route_variant as Array).size()


func _get_surface_points_signature(points: Array[Vector2]) -> String:
	var parts: Array[String] = []

	for point in points:
		parts.append("%d,%d" % [roundi(point.x), roundi(point.y)])

	return "|".join(parts)


func _get_surface_route_cache_key(graph_node: StringName, access_point: Vector2) -> String:
	return "%s:%d,%d" % [str(graph_node), roundi(access_point.x), roundi(access_point.y)]


func _get_surface_anchor_path_cache_key(start_index: int, goal_index: int) -> String:
	return "%d:%d" % [start_index, goal_index]


func _get_entry_to_access_route(
	access_point: Vector2,
	shelf: Shelf,
	metadata_graph_node: StringName,
	from_position: Vector2,
	npc_node: Node = null
) -> Dictionary:
	var route_start := from_position if from_position.is_finite() else _get_marker_position(_get_role_node_name(ROLE_ENTRY, ENTRY))

	if not route_start.is_finite() or not access_point.is_finite():
		return {"valid": false}

	var direct_orders := [
		{"horizontal_first": true, "source": "direct_entry_horizontal"},
		{"horizontal_first": false, "source": "direct_entry_vertical"}
	]

	for order in direct_orders:
		var route := _make_orthogonal_route(route_start, access_point, bool(order.get("horizontal_first", true)))
		var debug_result := _debug_route_to_access_clear(route_start, route, shelf, npc_node)
		_print_shelf_entry_candidate_debug(
			shelf,
			access_point,
			metadata_graph_node,
			str(order.get("source", "")),
			route,
			debug_result
		)

		if not _is_route_to_access_clear(route_start, route, shelf, npc_node):
			continue

		return {
			"valid": true,
			"route": route,
			"distance": _get_route_distance(route_start, route),
			"source": order.get("source", "")
		}

	var best_result := {"valid": false}
	var best_score := INF
	var start_node := _find_nearest_graph_node(route_start)

	if not bool(start_node.get("valid", false)):
		return best_result

	var start_graph_node := start_node.get("node", _get_role_node_name(ROLE_ENTRY, ENTRY)) as StringName

	for node_name in _get_nearest_graph_node_names_for_access(access_point, metadata_graph_node, MAX_ACCESS_GRAPH_NODE_CANDIDATES):
		var marker := _get_graph_marker(node_name)

		if marker == null:
			continue

		var path := _find_graph_path(start_graph_node, node_name)

		if path.is_empty():
			continue

		var route := (start_node.get("route", []) as Array[Vector2]).duplicate()
		route.append_array(_build_route_from_graph_path(path))
		_append_orthogonal_route_to(route, access_point, true)
		route = _dedupe_route_points(route)
		var debug_result := _debug_route_to_access_clear(route_start, route, shelf, npc_node)
		debug_result["candidate_node"] = node_name
		debug_result["graph_path"] = path
		_print_shelf_entry_candidate_debug(
			shelf,
			access_point,
			metadata_graph_node,
			"nearest_graph",
			route,
			debug_result
		)

		if not _is_route_to_access_clear(route_start, route, shelf, npc_node):
			continue

		var score := _get_route_distance(route_start, route)

		if score >= best_score:
			continue

		best_score = score
		best_result = {
			"valid": true,
			"route": route,
			"distance": score,
			"source": "nearest_graph"
		}

	return best_result


func _get_direct_checkout_access(access_point: Vector2, shelf_object: Node2D, shelf_position: Vector2) -> Dictionary:
	var queue_front_node := _get_role_node_name(ROLE_QUEUE_FRONT, QUEUE_FRONT)
	var cashier_node := _get_role_node_name(ROLE_CASHIER, CASHIER)
	var attempts: Array[Dictionary] = []
	var candidates := [
		{"node": queue_front_node, "checkout_source": "direct_queue"},
		{"node": cashier_node, "checkout_source": "direct_cashier"}
	]
	var route_orders := [
		{"horizontal_first": true, "label": "horizontal"},
		{"horizontal_first": false, "label": "vertical"}
	]

	for candidate in candidates:
		var node_name := candidate.get("node", StringName()) as StringName
		var marker := _get_graph_marker(node_name)

		if marker == null:
			continue

		for route_order in route_orders:
			var horizontal_first := bool(route_order.get("horizontal_first", true))
			var route_label := str(route_order.get("label", "horizontal"))
			var route := _make_orthogonal_route(access_point, marker.global_position, horizontal_first)
			var clear := _is_checkout_route_from_access_clear(access_point, route, shelf_object, shelf_position)
			var debug_result := _debug_checkout_route_from_access_clear(access_point, route, shelf_object, shelf_position)
			attempts.append({
				"target_node": node_name,
				"target_position": marker.global_position,
				"route_order": route_label,
				"clear": clear,
				"route": route,
				"debug": debug_result
			})
			_print_direct_checkout_debug(access_point, node_name, marker.global_position, route_label, clear, route)

			if not clear:
				continue

			return {
				"valid": true,
				"node": node_name,
				"route": route,
				"distance": _get_route_distance(access_point, route),
				"checkout_source": "%s_%s" % [str(candidate.get("checkout_source", "")), route_label],
				"attempts": attempts
			}

	return {
		"valid": false,
		"attempts": attempts
	}


func _get_direct_checkout_target_node_name(from_position: Vector2) -> StringName:
	var queue_front_node := _get_role_node_name(ROLE_QUEUE_FRONT, QUEUE_FRONT)
	var cashier_node := _get_role_node_name(ROLE_CASHIER, CASHIER)

	for node_name in [queue_front_node, cashier_node]:
		var marker := _get_graph_marker(node_name)

		if marker == null:
			continue

		var route := _make_orthogonal_route(from_position, marker.global_position, true)

		if _is_route_clear(from_position, route):
			return node_name

	return queue_front_node if _get_graph_marker(queue_front_node) != null else cashier_node


func _print_shelf_to_checkout_debug(
	shelf: Shelf,
	access_point: Vector2,
	graph_node: StringName,
	direct_target_node: StringName,
	direct_clear: bool,
	surface_route_points: int,
	result_source: String,
	route: Array[Vector2]
) -> void:
	var first_point := route[0] if not route.is_empty() else Vector2.INF
	var last_point := route[route.size() - 1] if not route.is_empty() else Vector2.INF

	print(
		"[DEBUG][SHELF_TO_CHECKOUT] shelf=%s access_point=%s access_side=%s graph_node=%s direct_target=%s direct_clear=%s surface_route_points=%d result_source=%s route_points=%d first_point=%s last_point=%s route=%s" % [
			shelf.name if shelf != null else "<null>",
			str(access_point),
			str(shelf.get_meta(ACCESS_SIDE_META) if shelf != null and shelf.has_meta(ACCESS_SIDE_META) else ""),
			str(graph_node),
			str(direct_target_node),
			str(direct_clear),
			surface_route_points,
			result_source,
			route.size(),
			str(first_point),
			str(last_point),
			str(route)
		]
	)


func _print_direct_checkout_debug(
	access_point: Vector2,
	target_node: StringName,
	target_position: Vector2,
	route_order: String,
	clear: bool,
	route: Array[Vector2]
) -> void:
	if not DEBUG_DIRECT_CHECKOUT_VERBOSE and not clear:
		return

	print(
		"[DEBUG][DIRECT_CHECKOUT] access_point=%s target_node=%s target_position=%s route_order=%s clear=%s route=%s" % [
			str(access_point),
			str(target_node),
			str(target_position),
			route_order,
			str(clear),
			str(route)
		]
	)


func _print_direct_checkout_fallback_debug(
	vertical_only: bool,
	shelf_object: Node2D,
	shelf_position: Vector2,
	access_point: Vector2,
	access_side: String,
	attempts: Array,
	fallback_stage: String
) -> void:
	if not vertical_only:
		return

	var compact_attempts: Array[Dictionary] = []

	for attempt in attempts:
		if not attempt is Dictionary:
			continue

		var attempt_dict := attempt as Dictionary
		var debug_result := attempt_dict.get("debug", {}) as Dictionary
		var route := attempt_dict.get("route", []) as Array
		compact_attempts.append({
			"target_node": attempt_dict.get("target_node", StringName()),
			"target_position": attempt_dict.get("target_position", Vector2.INF),
			"route_order": attempt_dict.get("route_order", ""),
			"clear": attempt_dict.get("clear", false),
			"blocked_segment_index": debug_result.get("blocked_segment_index", -1),
			"blocked_point": debug_result.get("blocked_point", Vector2.INF),
			"blocked_reason": debug_result.get("blocked_reason", ""),
			"blocker": debug_result.get("blocker", ""),
			"route_points": route.size(),
			"route_distance": _get_route_distance(access_point, _variant_route_to_vector2_array(route))
		})

	print(
		"[DEBUG][DIRECT_CHECKOUT_FALLBACK] shelf=%s shelf_pos=%s access_point=%s access_side=%s fallback_stage=%s attempts=%s" % [
			_get_perf_shelf_name(shelf_object),
			str(shelf_position),
			str(access_point),
			access_side,
			fallback_stage,
			str(compact_attempts)
		]
	)


func _print_queue_route_candidate_debug(
	source: String,
	from_position: Vector2,
	queue_index: int,
	target_node: StringName,
	target_position: Vector2,
	route: Array[Vector2],
	debug_result: Dictionary,
	start_result: Dictionary = {}
) -> void:
	if not DEBUG_QUEUE_TO_CASHIER_ROUTE:
		return

	var debug_key := "%s:%d:%d,%d:%s:%s:%s:%d" % [
		source,
		queue_index,
		roundi(from_position.x),
		roundi(from_position.y),
		str(target_node),
		str(debug_result.get("blocked_point", Vector2.INF)),
		str(debug_result.get("blocked_reason", "")),
		route.size()
	]

	if not bool(debug_result.get("valid", false)) and debug_key == _last_queue_route_candidate_debug_key:
		return

	_last_queue_route_candidate_debug_key = debug_key

	print(
		"[DEBUG][QUEUE_ROUTE_CANDIDATE] source=%s queue_index=%d from_position=%s target_node=%s target_position=%s clear=%s blocked_segment_index=%s blocked_from=%s blocked_to=%s blocked_point=%s blocked_reason=%s blocker=%s graph_node=%s graph_distance=%s route_points=%d route_distance=%.2f first_point=%s last_point=%s route=%s" % [
			source,
			queue_index,
			str(from_position),
			str(target_node),
			str(target_position),
			str(debug_result.get("valid", false)),
			str(debug_result.get("blocked_segment_index", -1)),
			str(debug_result.get("blocked_from", Vector2.INF)),
			str(debug_result.get("blocked_to", Vector2.INF)),
			str(debug_result.get("blocked_point", Vector2.INF)),
			str(debug_result.get("blocked_reason", "")),
			str(debug_result.get("blocker", "")),
			str(start_result.get("node", "")),
			str(start_result.get("distance", INF)),
			route.size(),
			_get_route_distance(from_position, route),
			str(route[0] if not route.is_empty() else Vector2.INF),
			str(route[route.size() - 1] if not route.is_empty() else Vector2.INF),
			str(route)
		]
	)


func _print_queue_graph_candidate_debug(
	from_position: Vector2,
	goal_node: StringName,
	candidate_node: StringName,
	route: Array[Vector2],
	debug_result: Dictionary,
	graph_path: Array[StringName],
	stage: String
) -> void:
	if not DEBUG_QUEUE_TO_CASHIER_ROUTE:
		return

	if not DEBUG_QUEUE_GRAPH_CANDIDATES_VERBOSE and stage == "entry_blocked":
		return

	var debug_key := "%s:%d,%d:%s:%s:%s:%s:%d" % [
		stage,
		roundi(from_position.x),
		roundi(from_position.y),
		str(goal_node),
		str(candidate_node),
		str(debug_result.get("blocked_point", Vector2.INF)),
		str(debug_result.get("blocked_reason", "")),
		route.size()
	]

	if not bool(debug_result.get("valid", false)) and debug_key == _last_queue_route_candidate_debug_key:
		return

	_last_queue_route_candidate_debug_key = debug_key

	print(
		"[DEBUG][QUEUE_ROUTE_CANDIDATE] source=graph_candidate stage=%s from_position=%s goal_node=%s candidate_node=%s clear=%s blocked_segment_index=%s blocked_from=%s blocked_to=%s blocked_point=%s blocked_reason=%s blocker=%s graph_path=%s route_points=%d route_distance=%.2f first_point=%s last_point=%s route=%s" % [
			stage,
			str(from_position),
			str(goal_node),
			str(candidate_node),
			str(debug_result.get("valid", false)),
			str(debug_result.get("blocked_segment_index", -1)),
			str(debug_result.get("blocked_from", Vector2.INF)),
			str(debug_result.get("blocked_to", Vector2.INF)),
			str(debug_result.get("blocked_point", Vector2.INF)),
			str(debug_result.get("blocked_reason", "")),
			str(debug_result.get("blocker", "")),
			str(graph_path),
			route.size(),
			_get_route_distance(from_position, route),
			str(route[0] if not route.is_empty() else Vector2.INF),
			str(route[route.size() - 1] if not route.is_empty() else Vector2.INF),
			str(route)
		]
	)


func _print_shelf_entry_route_debug(
	shelf: Shelf,
	access_point: Vector2,
	metadata_graph_node: StringName,
	result_source: String,
	route: Array[Vector2]
) -> void:
	if not DEBUG_SHELF_ENTRY_ROUTE:
		return

	var first_point := route[0] if not route.is_empty() else Vector2.INF
	var last_point := route[route.size() - 1] if not route.is_empty() else Vector2.INF

	print(
		"[DEBUG][SHELF_ENTRY_ROUTE] shelf=%s access_point=%s access_side=%s metadata_graph_node=%s result_source=%s route_points=%d first_point=%s last_point=%s route=%s" % [
			shelf.name if shelf != null else "<null>",
			str(access_point),
			str(shelf.get_meta(ACCESS_SIDE_META) if shelf != null and shelf.has_meta(ACCESS_SIDE_META) else ""),
			str(metadata_graph_node),
			result_source,
			route.size(),
			str(first_point),
			str(last_point),
			str(route)
		]
	)


func _print_shelf_entry_candidate_debug(
	shelf: Shelf,
	access_point: Vector2,
	metadata_graph_node: StringName,
	result_source: String,
	route: Array[Vector2],
	debug_result: Dictionary
) -> void:
	if not DEBUG_SHELF_ENTRY_ROUTE:
		return

	print(
		"[DEBUG][SHELF_ENTRY_CANDIDATE] shelf=%s from_position=%s access_point=%s access_side=%s metadata_graph_node=%s candidate_source=%s candidate_node=%s clear=%s route_distance=%.2f blocked_segment_index=%s blocked_from=%s blocked_to=%s blocked_point=%s blocked_reason=%s blocker=%s is_start_blocked=%s graph_path=%s route_points=%d route=%s" % [
			shelf.name if shelf != null else "<null>",
			str(debug_result.get("route_start", Vector2.INF)),
			str(access_point),
			str(shelf.get_meta(ACCESS_SIDE_META) if shelf != null and shelf.has_meta(ACCESS_SIDE_META) else ""),
			str(metadata_graph_node),
			result_source,
			str(debug_result.get("candidate_node", "")),
			str(debug_result.get("valid", false)),
			float(debug_result.get("route_distance", 0.0)),
			str(debug_result.get("blocked_segment_index", -1)),
			str(debug_result.get("blocked_from", Vector2.INF)),
			str(debug_result.get("blocked_to", Vector2.INF)),
			str(debug_result.get("blocked_point", Vector2.INF)),
			str(debug_result.get("blocked_reason", "")),
			str(debug_result.get("blocker", "")),
			str(debug_result.get("is_start_blocked", false)),
			str(debug_result.get("graph_path", [])),
			route.size(),
			str(route)
		]
	)


func _print_cashier_route_debug(
	from_position: Vector2,
	start_node: StringName,
	cashier_node: StringName,
	graph_path: Array[StringName],
	route: Array[Vector2],
	direct_routes: Array,
	result_source: String
) -> void:
	if not DEBUG_QUEUE_TO_CASHIER_ROUTE:
		return

	var first_point := route[0] if not route.is_empty() else Vector2.INF
	var last_point := route[route.size() - 1] if not route.is_empty() else Vector2.INF
	print(
		"[DEBUG][CASHIER_ROUTE] from_position=%s start_node=%s cashier_node=%s result_source=%s graph_path=%s route_points=%d first_point=%s last_point=%s route_distance=%.2f direct_routes=%s route=%s" % [
			str(from_position),
			str(start_node),
			str(cashier_node),
			result_source,
			str(graph_path),
			route.size(),
			str(first_point),
			str(last_point),
			_get_route_distance(from_position, route),
			str(direct_routes),
			str(route)
		]
	)


func _get_nearest_graph_node_names_for_access(access_point: Vector2, preferred_node: StringName, limit: int) -> Array[StringName]:
	var names := _get_graph_node_names()
	var ranked: Array[Dictionary] = []

	for node_name in names:
		var marker := _get_graph_marker(node_name)

		if marker == null:
			continue

		ranked.append({
			"node": node_name,
			"distance": _get_manhattan_distance(access_point, marker.global_position)
		})

	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", INF)) < float(b.get("distance", INF))
	)

	var selected: Array[StringName] = []

	if preferred_node != StringName() and _get_graph_marker(preferred_node) != null:
		selected.append(preferred_node)

	for item in ranked:
		if selected.size() >= limit:
			break

		var node_name := item.get("node", StringName()) as StringName

		if node_name == StringName() or node_name in selected:
			continue

		selected.append(node_name)

	return selected


func _get_shelf_access_candidates(shelf_position: Vector2, vertical_only: bool = false) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []

	if vertical_only:
		_append_rect_vertical_shelf_access_candidates(candidates, shelf_position)

	for node_name in _get_graph_node_names():
		var marker := _get_graph_marker(node_name)

		if marker == null:
			continue

		if not _is_shelf_access_marker(marker):
			continue

		_append_shelf_access_candidate(candidates, marker.global_position, shelf_position, node_name, vertical_only)

	for access_point in _shelf_access_points:
		_append_shelf_access_candidate(candidates, access_point, shelf_position, StringName(), vertical_only)

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


func _append_rect_vertical_shelf_access_candidates(candidates: Array[Dictionary], shelf_position: Vector2) -> void:
	var shelf_object := _find_shelf_object_at_position(shelf_position)
	var shelf_rect := _get_object_body_rect_at(shelf_object, shelf_position) if shelf_object != null else Rect2()

	if not _rect_has_area(shelf_rect):
		return

	var standing_half_height := STANDING_SHAPE_SIZE.y * 0.5
	var standing_offset_y := STANDING_SHAPE_OFFSET.y
	var standing_center_above_y := shelf_rect.position.y - SHELF_ACCESS_STANDING_CLEARANCE - standing_half_height - standing_offset_y
	var standing_center_below_y := shelf_rect.position.y + shelf_rect.size.y + SHELF_ACCESS_STANDING_CLEARANCE + standing_half_height - standing_offset_y
	var x_positions: Array[float] = [
		shelf_position.x
	]

	for x_position in x_positions:
		_append_rect_shelf_access_candidate(candidates, Vector2(x_position, standing_center_above_y), shelf_position, "above")
		_append_rect_shelf_access_candidate(candidates, Vector2(x_position, standing_center_below_y), shelf_position, "below")


func _append_rect_shelf_access_candidate(
	candidates: Array[Dictionary],
	access_point: Vector2,
	shelf_position: Vector2,
	access_side: String
) -> void:
	if not access_point.is_finite():
		return

	var horizontal_distance := absf(access_point.x - shelf_position.x)
	var vertical_distance := absf(access_point.y - shelf_position.y)
	var direct_distance := access_point.distance_to(shelf_position)

	if direct_distance <= MARKER_ALIGNMENT_EPSILON or direct_distance > MAX_SHELF_ACCESS_DISTANCE:
		return

	if horizontal_distance > SHELF_ACCESS_COLUMN_EPSILON:
		return

	if vertical_distance > MAX_VERTICAL_SHELF_ACCESS_DISTANCE:
		return

	for candidate in candidates:
		var candidate_point := candidate.get("access_point", Vector2.INF) as Vector2

		if candidate_point.distance_to(access_point) <= MARKER_ALIGNMENT_EPSILON:
			return

	candidates.append({
		"access_point": access_point,
		"graph_node": StringName(),
		"vertical_access": true,
		"access_side": access_side,
		"tier": 0,
		"horizontal_distance": horizontal_distance,
		"vertical_distance": vertical_distance,
		"direct_distance": direct_distance
	})


func _find_shelf_object_at_position(shelf_position: Vector2) -> Node2D:
	if _store == null:
		return null

	for node in _store.get_tree().get_nodes_in_group("shelves"):
		var shelf := node as Node2D

		if shelf == null:
			continue

		if shelf.global_position.distance_to(shelf_position) <= MAX_VERTICAL_SHELF_ACCESS_DISTANCE:
			return shelf

	return null


func _append_shelf_access_candidate(
	candidates: Array[Dictionary],
	access_point: Vector2,
	shelf_position: Vector2,
	graph_node: StringName,
	vertical_only: bool = false
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

	if vertical_only and not vertical_access:
		return

	if vertical_access and vertical_distance > MAX_VERTICAL_SHELF_ACCESS_DISTANCE:
		return

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

		if not _is_route_clear_from_current_position(position, entry_route):
			_print_queue_graph_candidate_debug(position, goal_node, node_name, entry_route, _debug_route_clear_from_current_position(position, entry_route), [], "entry_blocked")
			continue

		var graph_path := _find_graph_path(node_name, goal_node)

		if graph_path.is_empty():
			_print_queue_graph_candidate_debug(position, goal_node, node_name, entry_route, {"valid": false, "blocked_reason": "no_graph_path"}, graph_path, "no_graph_path")
			continue

		var route := entry_route.duplicate()
		route.append_array(_build_route_from_graph_path(graph_path))
		route = _dedupe_route_points(route)

		if _is_queue_target_node(goal_node):
			if not _is_queue_route_clear_from_current_position(position, route):
				_print_queue_graph_candidate_debug(position, goal_node, node_name, route, _debug_queue_route_clear_from_current_position(position, route), graph_path, "route_blocked")
				continue
		elif not _is_route_clear_from_current_position(position, route):
			_print_queue_graph_candidate_debug(position, goal_node, node_name, route, _debug_route_clear_from_current_position(position, route), graph_path, "route_blocked")
			continue

		var score := _get_route_distance(position, route)
		_print_queue_graph_candidate_debug(position, goal_node, node_name, route, {"valid": true}, graph_path, "valid")

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

	var goal_position := _get_marker_position(goal_node)
	var frontier: Array[StringName] = [start_node]
	var g_score := {start_node: 0.0}
	var f_score := {start_node: _get_manhattan_distance(_get_marker_position(start_node), goal_position)}
	var previous := {}
	var visited := {}

	while not frontier.is_empty():
		var current := _pop_lowest_cost_node(frontier, f_score)

		if visited.has(current):
			continue

		visited[current] = true

		if current == goal_node:
			break

		for neighbor in _get_graph_neighbors(current):
			if visited.has(neighbor):
				continue

			if neighbor != goal_node and _is_queue_target_node(neighbor):
				continue

			var edge_cost := _get_graph_edge_cost(current, neighbor)

			if edge_cost >= INF:
				continue

			var next_g := float(g_score[current]) + edge_cost

			if not g_score.has(neighbor) or next_g < float(g_score[neighbor]):
				g_score[neighbor] = next_g
				f_score[neighbor] = next_g + _get_manhattan_distance(_get_marker_position(neighbor), goal_position)
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

	var addition: Array[Vector2] = [to_pos]

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


func _debug_route_clear(
	start: Vector2,
	route: Array[Vector2],
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF
) -> Dictionary:
	var current := start

	for index in range(route.size()):
		var point := route[index]
		var segment_result := _debug_route_segment_clear(current, point, shelf_object, shelf_position)

		if not bool(segment_result.get("valid", false)):
			segment_result["blocked_segment_index"] = index
			segment_result["blocked_from"] = current
			segment_result["blocked_to"] = point
			return segment_result

		current = point

	return {
		"valid": true,
		"blocked_segment_index": -1,
		"blocked_from": Vector2.INF,
		"blocked_to": Vector2.INF,
		"blocked_point": Vector2.INF,
		"blocked_reason": "",
		"blocker": ""
	}


func _is_checkout_route_from_access_clear(
	start: Vector2,
	route: Array[Vector2],
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF
) -> bool:
	var current := start

	for index in range(route.size()):
		var point := route[index]

		if index == 0:
			if not _is_route_segment_clear_except_start(current, point, shelf_object, shelf_position):
				return false
		elif not _is_route_segment_clear(current, point, shelf_object, shelf_position):
			return false

		current = point

	return true


func _debug_checkout_route_from_access_clear(
	start: Vector2,
	route: Array[Vector2],
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF
) -> Dictionary:
	var current := start

	for index in range(route.size()):
		var point := route[index]
		var segment_result := _debug_route_segment_clear_except_start(current, point, shelf_object, shelf_position) if index == 0 else _debug_route_segment_clear(current, point, shelf_object, shelf_position)

		if not bool(segment_result.get("valid", false)):
			segment_result["blocked_segment_index"] = index
			segment_result["blocked_from"] = current
			segment_result["blocked_to"] = point
			return segment_result

		current = point

	return {
		"valid": true,
		"blocked_segment_index": -1,
		"blocked_from": Vector2.INF,
		"blocked_to": Vector2.INF,
		"blocked_point": Vector2.INF,
		"blocked_reason": "",
		"blocker": ""
	}


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


func _is_queue_route_clear_from_current_position(start: Vector2, route: Array[Vector2]) -> bool:
	var current := start

	for index in range(route.size()):
		var point := route[index]
		var allow_blocked_endpoint := index == route.size() - 1

		if index == 0:
			if allow_blocked_endpoint:
				if not _is_route_segment_clear_except_start_and_endpoint(current, point):
					return false
			elif not _is_route_segment_clear_except_start(current, point):
				return false
		elif allow_blocked_endpoint:
			if not _is_route_segment_clear_except_endpoint(current, point):
				return false
		elif not _is_route_segment_clear(current, point):
			return false

		current = point

	return true


func _is_route_clear_from_current_position(start: Vector2, route: Array[Vector2]) -> bool:
	var current := start

	for index in range(route.size()):
		var point := route[index]

		if index == 0:
			if not _is_route_segment_clear_except_start(current, point):
				return false
		elif not _is_route_segment_clear(current, point):
			return false

		current = point

	return true


func _debug_queue_route_clear_from_current_position(start: Vector2, route: Array[Vector2]) -> Dictionary:
	if route.is_empty():
		return {"valid": true}

	var current := start

	for index in range(route.size()):
		var point := route[index]
		var allow_blocked_endpoint := index == route.size() - 1
		var segment_result := {}

		if index == 0 and allow_blocked_endpoint:
			segment_result = _debug_route_segment_clear_except_start_and_endpoint(current, point)
		elif index == 0:
			segment_result = _debug_route_segment_clear_except_start(current, point)
		elif allow_blocked_endpoint:
			segment_result = _debug_route_segment_clear_except_endpoint(current, point)
		else:
			segment_result = _debug_route_segment_clear(current, point)

		if not bool(segment_result.get("valid", false)):
			segment_result["blocked_segment_index"] = index
			segment_result["blocked_from"] = current
			segment_result["blocked_to"] = point
			return segment_result

		current = point

	return {"valid": true}


func _debug_route_clear_from_current_position(start: Vector2, route: Array[Vector2]) -> Dictionary:
	if route.is_empty():
		return {"valid": true}

	var current := start

	for index in range(route.size()):
		var point := route[index]
		var segment_result := _debug_route_segment_clear_except_start(current, point) if index == 0 else _debug_route_segment_clear(current, point)

		if not bool(segment_result.get("valid", false)):
			segment_result["blocked_segment_index"] = index
			segment_result["blocked_from"] = current
			segment_result["blocked_to"] = point
			return segment_result

		current = point

	return {"valid": true}


func _is_route_to_access_clear(start: Vector2, route: Array[Vector2], shelf: Shelf, npc_node: Node = null) -> bool:
	if route.is_empty():
		return true

	var current := start
	var shelf_position := shelf.global_position if shelf != null else Vector2.INF

	for index in range(route.size()):
		var point := route[index]
		var is_last_segment := index == route.size() - 1

		if index == 0 and is_last_segment:
			if not _is_route_segment_clear_except_start_and_endpoint(current, point, shelf, shelf_position, npc_node):
				return false
		elif index == 0:
			if not _is_route_segment_clear_except_start(current, point, shelf, shelf_position, npc_node):
				return false
		elif is_last_segment:
			if not _is_route_segment_clear_except_endpoint(current, point, shelf, shelf_position, npc_node):
				return false
		elif not _is_route_segment_clear(current, point, shelf, shelf_position, npc_node):
			return false

		current = point

	return true


func _debug_route_to_access_clear(start: Vector2, route: Array[Vector2], shelf: Shelf, npc_node: Node = null) -> Dictionary:
	var start_clear := _debug_npc_access_point_clear(start, null, Vector2.INF, npc_node)

	if route.is_empty():
		return {
			"valid": true,
			"route_start": start,
			"route_distance": 0.0,
			"is_start_blocked": not bool(start_clear.get("valid", false)),
			"start_blocker": start_clear.get("blocker", ""),
			"blocked_segment_index": -1,
			"blocked_from": Vector2.INF,
			"blocked_to": Vector2.INF,
			"blocked_point": Vector2.INF,
			"blocked_reason": "",
			"blocker": ""
		}

	var current := start
	var shelf_position := shelf.global_position if shelf != null else Vector2.INF

	for index in range(route.size()):
		var point := route[index]
		var is_last_segment := index == route.size() - 1
		var segment_result := {}

		if index == 0 and is_last_segment:
			segment_result = _debug_route_segment_clear_except_start_and_endpoint(current, point, shelf, shelf_position, npc_node)
		elif index == 0:
			segment_result = _debug_route_segment_clear_except_start(current, point, shelf, shelf_position, npc_node)
		elif is_last_segment:
			segment_result = _debug_route_segment_clear_except_endpoint(current, point, shelf, shelf_position, npc_node)
		else:
			segment_result = _debug_route_segment_clear(current, point, shelf, shelf_position, npc_node)

		if not bool(segment_result.get("valid", false)):
			segment_result["blocked_segment_index"] = index
			segment_result["blocked_from"] = current
			segment_result["blocked_to"] = point
			segment_result["route_start"] = start
			segment_result["route_distance"] = _get_route_distance(start, route)
			segment_result["is_start_blocked"] = not bool(start_clear.get("valid", false))
			segment_result["start_blocker"] = start_clear.get("blocker", "")
			return segment_result

		current = point

	return {
		"valid": true,
		"route_start": start,
		"route_distance": _get_route_distance(start, route),
		"is_start_blocked": not bool(start_clear.get("valid", false)),
		"start_blocker": start_clear.get("blocker", ""),
		"blocked_segment_index": -1,
		"blocked_from": Vector2.INF,
		"blocked_to": Vector2.INF,
		"blocked_point": Vector2.INF,
		"blocked_reason": "",
		"blocker": ""
	}


func _debug_route_segment_clear_except_endpoint(
	from_pos: Vector2,
	to_pos: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> Dictionary:
	if from_pos.distance_to(to_pos) <= ROUTE_CLEARANCE_EPSILON:
		return {"valid": true}

	if not is_equal_approx(from_pos.x, to_pos.x) and not is_equal_approx(from_pos.y, to_pos.y):
		return {"valid": false, "blocked_point": Vector2.INF, "blocked_reason": "diagonal_segment"}

	var distance := from_pos.distance_to(to_pos)
	var steps := maxi(1, int(ceil(distance / ROUTE_SAMPLE_STEP)))

	for index in range(steps):
		var point := from_pos.lerp(to_pos, float(index) / float(steps))
		var point_result := _debug_npc_access_point_clear(point, shelf_object, shelf_position, npc_node)

		if not bool(point_result.get("valid", false)):
			return {
				"valid": false,
				"blocked_point": point,
				"blocked_reason": "blocked_except_endpoint:%s" % str(point_result.get("blocked_reason", "")),
				"blocker": point_result.get("blocker", "")
			}

	return {"valid": true}


func _debug_route_segment_clear_except_start(
	from_pos: Vector2,
	to_pos: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> Dictionary:
	if from_pos.distance_to(to_pos) <= ROUTE_CLEARANCE_EPSILON:
		return {"valid": true}

	if not is_equal_approx(from_pos.x, to_pos.x) and not is_equal_approx(from_pos.y, to_pos.y):
		return {"valid": false, "blocked_point": Vector2.INF, "blocked_reason": "diagonal_segment"}

	var distance := from_pos.distance_to(to_pos)
	var steps := maxi(1, int(ceil(distance / ROUTE_SAMPLE_STEP)))

	for index in range(1, steps + 1):
		var point := from_pos.lerp(to_pos, float(index) / float(steps))
		var point_result := _debug_npc_access_point_clear(point, shelf_object, shelf_position, npc_node)

		if not bool(point_result.get("valid", false)):
			return {
				"valid": false,
				"blocked_point": point,
				"blocked_reason": "blocked_except_start:%s" % str(point_result.get("blocked_reason", "")),
				"blocker": point_result.get("blocker", "")
			}

	return {"valid": true}


func _debug_route_segment_clear_except_start_and_endpoint(
	from_pos: Vector2,
	to_pos: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> Dictionary:
	if from_pos.distance_to(to_pos) <= ROUTE_CLEARANCE_EPSILON:
		return {"valid": true}

	if not is_equal_approx(from_pos.x, to_pos.x) and not is_equal_approx(from_pos.y, to_pos.y):
		return {"valid": false, "blocked_point": Vector2.INF, "blocked_reason": "diagonal_segment"}

	var distance := from_pos.distance_to(to_pos)
	var steps := maxi(1, int(ceil(distance / ROUTE_SAMPLE_STEP)))

	for index in range(1, steps):
		var point := from_pos.lerp(to_pos, float(index) / float(steps))
		var point_result := _debug_npc_access_point_clear(point, shelf_object, shelf_position, npc_node)

		if not bool(point_result.get("valid", false)):
			return {
				"valid": false,
				"blocked_point": point,
				"blocked_reason": "blocked_except_start_and_endpoint:%s" % str(point_result.get("blocked_reason", "")),
				"blocker": point_result.get("blocker", "")
			}

	return {"valid": true}


func _debug_route_segment_clear(
	from_pos: Vector2,
	to_pos: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> Dictionary:
	if from_pos.distance_to(to_pos) <= ROUTE_CLEARANCE_EPSILON:
		return {"valid": true}

	if not is_equal_approx(from_pos.x, to_pos.x) and not is_equal_approx(from_pos.y, to_pos.y):
		return {"valid": false, "blocked_point": Vector2.INF, "blocked_reason": "diagonal_segment"}

	var distance := from_pos.distance_to(to_pos)
	var steps := maxi(1, int(ceil(distance / ROUTE_SAMPLE_STEP)))

	for index in range(steps + 1):
		var point := from_pos.lerp(to_pos, float(index) / float(steps))
		var point_result := _debug_npc_access_point_clear(point, shelf_object, shelf_position, npc_node)

		if not bool(point_result.get("valid", false)):
			return {
				"valid": false,
				"blocked_point": point,
				"blocked_reason": "blocked:%s" % str(point_result.get("blocked_reason", "")),
				"blocker": point_result.get("blocker", "")
			}

	return {"valid": true}


func _is_route_segment_clear_except_endpoint(
	from_pos: Vector2,
	to_pos: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> bool:
	if from_pos.distance_to(to_pos) <= ROUTE_CLEARANCE_EPSILON:
		return true

	if not is_equal_approx(from_pos.x, to_pos.x) and not is_equal_approx(from_pos.y, to_pos.y):
		return false

	var distance := from_pos.distance_to(to_pos)
	var steps := maxi(1, int(ceil(distance / ROUTE_SAMPLE_STEP)))

	for index in range(steps):
		var point := from_pos.lerp(to_pos, float(index) / float(steps))

		if not _is_npc_access_point_clear(point, shelf_object, shelf_position, npc_node):
			return false

	return true


func _is_route_segment_clear_except_start(
	from_pos: Vector2,
	to_pos: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> bool:
	if from_pos.distance_to(to_pos) <= ROUTE_CLEARANCE_EPSILON:
		return true

	if not is_equal_approx(from_pos.x, to_pos.x) and not is_equal_approx(from_pos.y, to_pos.y):
		return false

	var distance := from_pos.distance_to(to_pos)
	var steps := maxi(1, int(ceil(distance / ROUTE_SAMPLE_STEP)))

	for index in range(1, steps + 1):
		var point := from_pos.lerp(to_pos, float(index) / float(steps))

		if not _is_npc_access_point_clear(point, shelf_object, shelf_position, npc_node):
			return false

	return true


func _is_route_segment_clear_except_start_and_endpoint(
	from_pos: Vector2,
	to_pos: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> bool:
	if from_pos.distance_to(to_pos) <= ROUTE_CLEARANCE_EPSILON:
		return true

	if not is_equal_approx(from_pos.x, to_pos.x) and not is_equal_approx(from_pos.y, to_pos.y):
		return false

	var distance := from_pos.distance_to(to_pos)
	var steps := maxi(1, int(ceil(distance / ROUTE_SAMPLE_STEP)))

	for index in range(1, steps):
		var point := from_pos.lerp(to_pos, float(index) / float(steps))

		if not _is_npc_access_point_clear(point, shelf_object, shelf_position, npc_node):
			return false

	return true


func _is_route_segment_clear(
	from_pos: Vector2,
	to_pos: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> bool:
	if from_pos.distance_to(to_pos) <= ROUTE_CLEARANCE_EPSILON:
		return true

	if not is_equal_approx(from_pos.x, to_pos.x) and not is_equal_approx(from_pos.y, to_pos.y):
		return false

	var distance := from_pos.distance_to(to_pos)
	var steps := maxi(1, int(ceil(distance / ROUTE_SAMPLE_STEP)))

	for index in range(steps + 1):
		var point := from_pos.lerp(to_pos, float(index) / float(steps))

		if not _is_npc_access_point_clear(point, shelf_object, shelf_position, npc_node):
			return false

	return true


func _debug_npc_access_point_clear(
	position: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> Dictionary:
	if shelf_object != null and shelf_position.is_finite():
		var shelf_rect := _get_object_body_rect_at(shelf_object, shelf_position)

		if _rect_has_area(shelf_rect) and _get_npc_standing_rect(position).intersects(shelf_rect):
			return {
				"valid": false,
				"blocked_reason": "shelf_body_rect",
				"blocker": shelf_object.name
			}

	if _store == null:
		return {
			"valid": false,
			"blocked_reason": "missing_store",
			"blocker": "<store_null>"
		}

	var shape := RectangleShape2D.new()
	shape.size = STANDING_SHAPE_SIZE

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, position + STANDING_SHAPE_OFFSET)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = 1

	if npc_node is CollisionObject2D:
		query.exclude = [(npc_node as CollisionObject2D).get_rid()]

	var hits := _store.get_world_2d().direct_space_state.intersect_shape(query, 16)

	if hits.is_empty():
		return {"valid": true}

	var hit: Dictionary = hits[0]
	var collider: Variant = hit.get("collider", null)
	var collider_node := collider as Node
	var collider_name: String = collider_node.name if collider_node != null else str(collider)
	var collider_path: String = str(collider_node.get_path()) if collider_node != null and collider_node.is_inside_tree() else ""

	return {
		"valid": false,
		"blocked_reason": _get_debug_blocker_reason(collider_node),
		"blocker": "%s%s" % [collider_name, ":%s" % collider_path if collider_path != "" else ""]
	}


func _get_debug_blocker_reason(collider_node: Node) -> String:
	if collider_node == null:
		return "physics_body"

	var name_text := collider_node.name.to_lower()

	if collider_node is NPC:
		return "npc"

	if name_text.contains("player"):
		return "player"

	if name_text.contains("cashier"):
		return "cashier"

	if name_text.contains("shelf"):
		return "shelf"

	if name_text.contains("wall") or name_text.contains("bound"):
		return "wall_or_bounds"

	if name_text.contains("queue"):
		return "queue_area"

	return "%s:%s" % [collider_node.get_class(), collider_node.name]


func _is_npc_access_point_clear(
	position: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> bool:
	if shelf_object != null and shelf_position.is_finite():
		var shelf_rect := _get_object_body_rect_at(shelf_object, shelf_position)

		if _rect_has_area(shelf_rect) and _get_npc_standing_rect(position).intersects(shelf_rect):
			return false

	return _is_npc_standing_position_clear(position, npc_node)


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
		return _get_queue_marker_index(a) < _get_queue_marker_index(b)
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
	var queue_right_nodes := _get_queue_right_node_names()
	if queue_right_nodes.is_empty():
		return []

	var queue_right_node := _get_nearest_queue_right_node_name(from_position)

	if queue_right_node == StringName():
		return []

	var queue_right_marker := _get_graph_marker(queue_right_node)

	if queue_right_marker == null:
		return []

	var route: Array[Vector2] = [queue_right_marker.global_position]
	
	var start_index := queue_right_nodes.find(queue_right_node)
	for i in range(start_index + 1, queue_right_nodes.size()):
		var next_marker := _get_graph_marker(queue_right_nodes[i])
		if next_marker != null:
			route.append(next_marker.global_position)

	var last_node := queue_right_nodes.back() as StringName
	var exit_node := _get_role_node_name(ROLE_EXIT, EXIT)

	if exit_node != StringName():
		var exit_path := _find_graph_path(last_node, exit_node)

		if not exit_path.is_empty():
			route.append_array(_build_route_from_graph_path(exit_path))
			return _dedupe_route_points(route)

	# Build forced orthogonal route directly to fallback if graph is incomplete
	var last_pos: Vector2 = route.back() as Vector2 if not route.is_empty() else from_position
	route.append_array(_make_orthogonal_route(last_pos, fallback_exit_position, true))
	return _dedupe_route_points(route)


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
			
		if _is_queue_target_node(candidate_name) or _is_queue_target_node(source_name):
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
