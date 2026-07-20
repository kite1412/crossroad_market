class_name StorePathGraph
extends RefCounted

## Thin facade over modular pathfinding components.
## All business logic is delegated to the helper modules below:
##   _routes     – orthogonal / direct route builders, dedup, distance
##   _clearance  – collision queries, segment / route clearance
##   _nav        – marker lookups, A* graph pathfinding, queue helpers
##   _shelf      – shelf access candidate generation
##   _surface    – A* over shelf_access_points grid

# ── Constants (also read by helpers via _graph.<CONST>) ──────────────────────
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
const SHELF_ACCESS_DISTANCE_SCORE_WEIGHT: float = 1000.0

# ── Shared state (helpers access via _graph._store etc.) ─────────────────────
@warning_ignore("unused_private_class_variable")
var _store: Node2D = null
@warning_ignore("unused_private_class_variable")
var _markers: Node2D = null
@warning_ignore("unused_private_class_variable")
var _shelf_access_points: Array[Vector2] = []
@warning_ignore("unused_private_class_variable")
var _surface_neighbor_cache := {}
@warning_ignore("unused_private_class_variable")
var _surface_neighbor_signature := ""
@warning_ignore("unused_private_class_variable")
var _cached_shelf_anchor_positions: Array[Vector2] = []
@warning_ignore("unused_private_class_variable")
var _cached_shelf_anchor_count: int = -1
@warning_ignore("unused_private_class_variable")
var _cached_graph_node_names: Array[StringName] = []
@warning_ignore("unused_private_class_variable")
var _cached_graph_node_count: int = -1

# ── Helpers ──────────────────────────────────────────────────────────────────
@warning_ignore("unused_private_class_variable")
var _routes: StorePathGraphRoutes
@warning_ignore("unused_private_class_variable")
var _clearance: StorePathGraphClearance
@warning_ignore("unused_private_class_variable")
var _nav: StorePathGraphGraph
@warning_ignore("unused_private_class_variable")
var _shelf: StorePathGraphShelfAccess
@warning_ignore("unused_private_class_variable")
var _surface: StorePathGraphSurface


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _init(store: Node2D = null, markers: Node2D = null) -> void:
	_store = store
	_markers = markers
	_routes = StorePathGraphRoutes.new(self)
	_clearance = StorePathGraphClearance.new(self)
	_nav = StorePathGraphGraph.new(self)
	_shelf = StorePathGraphShelfAccess.new(self)
	_surface = StorePathGraphSurface.new(self)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(store: Node2D, markers: Node2D) -> void:
	_store = store
	_markers = markers


# ── Surface point management ─────────────────────────────────────────────────

@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_shelf_access_points(points: Array[Vector2]) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var next_points := points.duplicate()

	if _get_surface_points_signature(next_points) != _get_surface_points_signature(_shelf_access_points):
		_surface_neighbor_cache.clear()
		_surface_neighbor_signature = ""

	_shelf_access_points = next_points


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func invalidate_surface_graph_cache() -> void:
	_surface_neighbor_cache.clear()
	_surface_neighbor_signature = ""


# ── Marker convenience ───────────────────────────────────────────────────────

@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_marker_for_role(role: StringName, fallback_node_name: StringName = StringName()) -> Marker2D:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var role_node := _nav.get_role_node_name(role, fallback_node_name)

	if role_node == StringName():
		return null

	return _nav.get_graph_marker(role_node)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_shelf_anchor_positions() -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var graph_nodes := _nav.get_graph_node_names()

	if _cached_shelf_anchor_count == graph_nodes.size():
		return _cached_shelf_anchor_positions.duplicate()

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var positions: Array[Vector2] = []

	for node_name in graph_nodes:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var marker: Marker2D = _nav.get_graph_marker(node_name)

		if marker == null:
			continue

		if bool(marker.get_meta(SHELF_ANCHOR_META, false)):
			positions.append(marker.global_position)

	_cached_shelf_anchor_positions = positions
	_cached_shelf_anchor_count = graph_nodes.size()
	return positions.duplicate()


# ── Queue / cashier positions ────────────────────────────────────────────────

@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_queue_target_position(queue_index: int, fallback_position: Vector2) -> Vector2:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var node_name := _nav.get_queue_target_node_name(queue_index)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var marker: Marker2D = _nav.get_graph_marker(node_name)

	if marker == null:
		return fallback_position

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var front_node := _nav.get_role_node_name(ROLE_QUEUE_FRONT, QUEUE_FRONT)
	if queue_index > 0 and node_name == front_node:
		const QUEUE_SLOT_SPACING := Vector2(0, 22)
		return marker.global_position + QUEUE_SLOT_SPACING * queue_index

	return marker.global_position


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_cashier_target_position(fallback_position: Vector2) -> Vector2:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var marker: Marker2D = get_marker_for_role(ROLE_CASHIER, CASHIER)
	return marker.global_position if marker != null else fallback_position


# ── Route builders (public API) ──────────────────────────────────────────────

@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_entry_route_to_shelf(shelf_position: Vector2, from_position: Vector2 = Vector2.INF) -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var entry_node := _nav.get_role_node_name(ROLE_ENTRY, ENTRY)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var aisle_node := _nav.get_role_node_name(&"aisle_right", AISLE_RIGHT)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var start: Dictionary = _nav.find_nearest_graph_node(from_position) if from_position.is_finite() else {
		"valid": true,
		"node": entry_node,
		"route": _routes.build_route_from_graph_path([entry_node])
	}

	if not bool(start.get("valid", false)):
		return _routes.dedupe_route_points(_routes.make_orthogonal_route(from_position, shelf_position, true))

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var path: Array[StringName] = _nav.find_graph_path(start.get("node", entry_node) as StringName, aisle_node)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route := start.get("route", []) as Array[Vector2]
	route.append_array(_routes.build_route_from_graph_path(path))
	_routes.append_orthogonal_route_to(route, shelf_position, true, from_position)
	return _routes.dedupe_route_points(route)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_shelf_access_position(shelf: Shelf) -> Vector2:
	if shelf == null:
		return Vector2.INF

	if shelf.has_meta(ACCESS_META):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var access_point: Variant = shelf.get_meta(ACCESS_META)

		if access_point is Vector2:
			return access_point as Vector2

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var result := find_best_vertical_shelf_access(shelf.global_position, shelf)
	_store_access_metadata_from_result(shelf, result)
	return result.get("access_point", Vector2.INF) as Vector2


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func has_cached_shelf_access_metadata(shelf: Shelf) -> bool:
	if shelf == null:
		return false

	return shelf.has_meta(ACCESS_META) and shelf.has_meta(ACCESS_NODE_META)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_route_to_shelf_access(shelf: Shelf, from_position: Vector2 = Vector2.INF, npc_node: Node = null) -> Array[Vector2]:
	if shelf == null:
		return []

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var access_point := get_shelf_access_position(shelf)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var graph_node := get_shelf_access_graph_node(shelf)

	if not access_point.is_finite() or graph_node == StringName():
		return []

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route_start: Vector2 = from_position if from_position.is_finite() else _nav.get_marker_position(_nav.get_role_node_name(ROLE_ENTRY, ENTRY))
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var entry_route_result := _get_entry_to_access_route(access_point, shelf, graph_node, route_start, npc_node)

	if bool(entry_route_result.get("valid", false)):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var entry_route := entry_route_result.get("route", []) as Array[Vector2]
		pass
		return _routes.dedupe_route_points(entry_route)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var start_node: Dictionary = _nav.find_nearest_graph_node(route_start)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var path: Array[StringName] = _nav.find_graph_path(start_node.get("node", _nav.get_role_node_name(ROLE_ENTRY, ENTRY)) as StringName, graph_node) if bool(start_node.get("valid", false)) else []
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route := (start_node.get("route", []) as Array[Vector2]).duplicate()
	route.append_array(_routes.build_route_from_graph_path(path))
	_append_surface_access_route_to(route, shelf, graph_node, access_point, true)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var fallback_route := _routes.dedupe_route_points(route)
	pass
	return fallback_route


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_route_to_cashier_from(from_position: Vector2) -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var start: Dictionary = _nav.find_nearest_graph_node(from_position)

	if not bool(start.get("valid", false)):
		pass
		return []

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var cashier_node: StringName = _nav.get_role_node_name(ROLE_CASHIER, CASHIER)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var cashier_marker: Marker2D = _nav.get_graph_marker(cashier_node)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var direct_routes: Array = []

	if cashier_marker != null:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var direct_diagonal_route := _routes.make_direct_route(
			from_position,
			cashier_marker.global_position
		)

		if (
			direct_diagonal_route.is_empty()
			or _clearance.is_any_direction_segment_clear(
				from_position,
				cashier_marker.global_position,
				null,
				Vector2.INF,
				null,
				true,
				true
			)
		):
			return _routes.dedupe_route_points(direct_diagonal_route)

		for order in [
			{"horizontal_first": true, "label": "horizontal"},
			{"horizontal_first": false, "label": "vertical"}
		]:
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var direct_route := _routes.make_orthogonal_route(from_position, cashier_marker.global_position, bool(order.get("horizontal_first", true)))
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var direct_clear := _clearance.is_queue_route_clear_from_current_position(from_position, direct_route)
			direct_routes.append({
				"order": str(order.get("label", "")),
				"clear": direct_clear,
				"route": direct_route
			})

			if direct_clear:
				@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
				var direct_result := _routes.dedupe_route_points(direct_route)
				pass
				return direct_result

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var path: Array[StringName] = _nav.find_graph_path(start.get("node", cashier_node) as StringName, cashier_node)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route := start.get("route", []) as Array[Vector2]
	route.append_array(_routes.build_route_from_graph_path(path))
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var result := _routes.dedupe_route_points(route)

	pass
	return result


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_shelf_wait_position(index: int = 0) -> Vector2:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var role_name := "shelf_wait"
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var all_markers: Array[Marker2D] = _nav.get_markers_by_role(role_name)
	if all_markers.is_empty():
		return Vector2.INF

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var selected_marker: Marker2D = null
	for marker in all_markers:
		if marker.get_meta("store_wait_index", 0) == index:
			selected_marker = marker
			break

	if selected_marker == null:
		selected_marker = all_markers[index % all_markers.size()]

	return selected_marker.global_position


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_route_to_queue_target_from(from_position: Vector2, queue_index: int) -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var queue_target := get_queue_target_position(queue_index, from_position)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var queue_node: StringName = _nav.get_queue_target_node_name(queue_index)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var direct_route: Array[Vector2] = [queue_target]
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var direct_clear := _clearance.is_queue_route_clear_from_current_position(from_position, direct_route)
	pass

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var direct_vertical_route := _routes.make_orthogonal_route(from_position, queue_target, false)
	pass

	if direct_clear:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var direct_result := _routes.dedupe_route_points(direct_route)
		return direct_result

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var queue_start: Dictionary = _nav.find_nearest_reachable_graph_node_for_route(from_position, queue_node)

	if bool(queue_start.get("valid", false)):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var queue_route := queue_start.get("route", []) as Array[Vector2]
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var appended_center := queue_route.is_empty() or _routes.append_clear_queue_target_route_to(queue_route, queue_target, true, from_position)
		pass

		if appended_center:
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var center_result := _routes.dedupe_route_points(queue_route)
			return center_result
	else:
		pass

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var approach_node: StringName = _nav.get_queue_approach_node_name(queue_index)

	if approach_node != StringName():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var approach_start: Dictionary = _nav.find_nearest_reachable_graph_node_for_route(from_position, approach_node)

		if bool(approach_start.get("valid", false)):
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var approach_route := approach_start.get("route", []) as Array[Vector2]
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var appended_right := _routes.append_clear_queue_target_route_to(approach_route, queue_target, true, from_position)
			pass

			if appended_right:
				@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
				var right_result := _routes.dedupe_route_points(approach_route)
				return right_result
		else:
			pass

	return []


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_route_from_shelf_to_cashier(shelf: Shelf) -> Array[Vector2]:
	if shelf == null:
		return []

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var access_point := get_shelf_access_position(shelf)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var graph_node := get_shelf_access_graph_node(shelf)

	if not access_point.is_finite() or graph_node == StringName():
		return []

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var direct_target_node := _get_direct_checkout_target_node_name(access_point)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var direct_target_marker: Marker2D = _nav.get_graph_marker(direct_target_node)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var direct_route: Array[Vector2] = []
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var direct_clear := false

	if direct_target_marker != null:
		direct_route = _routes.make_direct_route(access_point, direct_target_marker.global_position)
		direct_clear = (
			direct_route.is_empty()
			or _clearance.is_any_direction_segment_clear(
				access_point,
				direct_target_marker.global_position,
				shelf,
				shelf.global_position,
				null,
				true,
				false
			)
		)

		if direct_clear:
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var direct_result := _routes.dedupe_route_points(direct_route)
			pass
			return direct_result

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var path: Array[StringName] = _nav.find_checkout_graph_path(graph_node)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route := _get_surface_access_route(shelf, graph_node, access_point)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var surface_route_points := route.size()
	route.reverse()
	route.append_array(_routes.build_route_from_graph_path(path))
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var result := _routes.dedupe_route_points(route)

	if not result.is_empty() and _clearance.is_route_clear(access_point, result, shelf, shelf.global_position):
		pass
		return result

	pass
	return []


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_cashier_exit_route(from_position: Vector2, fallback_exit_position: Vector2) -> Array[Vector2]:
	return _build_cashier_exit_route_via_queue_right(from_position, fallback_exit_position)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _build_cashier_exit_route_via_queue_right(from_position: Vector2, fallback_exit_position: Vector2) -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var queue_right_nodes: Array[StringName] = _nav.get_queue_right_node_names()

	if queue_right_nodes.size() < 3:
		return []

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route: Array[Vector2] = []

	for node_name in queue_right_nodes:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var marker: Marker2D = _nav.get_graph_marker(node_name)

		if marker == null:
			return []

		route.append(marker.global_position)

	if not _clearance.is_route_clear_from_current_position(from_position, route):
		return []

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var exit_node: StringName = _nav.get_role_node_name(ROLE_EXIT, EXIT)

	if exit_node != StringName():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var last_queue_position: Vector2 = route.back()
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var graph_rejoin: Dictionary = _nav.find_nearest_reachable_graph_node_for_route(last_queue_position, exit_node)

		if bool(graph_rejoin.get("valid", false)):
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var graph_route := graph_rejoin.get("route", []) as Array[Vector2]

			route.append_array(graph_route)
			return _routes.dedupe_route_points(route)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var last_position: Vector2 = route.back()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var fallback_route := _routes.make_orthogonal_route(last_position, fallback_exit_position, true)

	if not _clearance.is_route_clear_from_current_position(last_position, fallback_route):
		return []

	route.append_array(fallback_route)
	return _routes.dedupe_route_points(route)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_exit_route_from(from_position: Vector2, fallback_exit_position: Vector2) -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var exit_node: StringName = _nav.get_role_node_name(ROLE_EXIT, EXIT)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var start: Dictionary = _nav.find_nearest_reachable_graph_node_for_route(from_position, exit_node)

	if bool(start.get("valid", false)):
		return _routes.dedupe_route_points(start.get("route", []) as Array[Vector2])

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var fallback := _routes.make_orthogonal_route(from_position, fallback_exit_position, true)

	if _clearance.is_route_clear_from_current_position(from_position, fallback):
		return _routes.dedupe_route_points(fallback)

	return []


# ── Shelf access ─────────────────────────────────────────────────────────────

@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func has_reachable_shelf_access(object: Node2D, candidate: Vector2) -> bool:
	return bool(find_best_shelf_access(candidate, object).get("valid", false))


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_best_shelf_access(candidate_position: Vector2, shelf_object: Node2D) -> Dictionary:
	return _find_best_shelf_access(candidate_position, shelf_object, false)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_best_vertical_shelf_access(candidate_position: Vector2, shelf_object: Node2D) -> Dictionary:
	return _find_best_shelf_access(candidate_position, shelf_object, true)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _find_best_shelf_access(candidate_position: Vector2, shelf_object: Node2D, vertical_only: bool) -> Dictionary:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var debug_start_usec := Time.get_ticks_usec()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var candidates_start_usec := Time.get_ticks_usec()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var candidates := _shelf.get_shelf_access_candidates(candidate_position, vertical_only)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var candidates_elapsed_msec := _elapsed_msec(candidates_start_usec)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var cashier_marker: Marker2D = get_marker_for_role(ROLE_CASHIER, CASHIER)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var cashier_pos := cashier_marker.global_position if cashier_marker != null else Vector2.INF
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var prefer_below := false
	if cashier_pos.is_finite() and candidate_position.is_finite():
		prefer_below = candidate_position.y < cashier_pos.y - 4.0
	const COUNTER_DIRECTION_PENALTY_SCALE: float = 1000.0

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var surface_searches := [0]
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var surface_route_cache := {}
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var surface_anchor_path_cache := {}
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_result := {"valid": false}
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_score := INF
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var checked_candidates := 0
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var blocked_candidates := 0
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var no_surface_route_candidates := 0
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var no_checkout_route_candidates := 0
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var valid_candidates := 0
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var clear_check_elapsed_msec := 0.0
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var reachable_elapsed_msec := 0.0
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var checkout_elapsed_msec := 0.0
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var scoring_elapsed_msec := 0.0
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var preferred_side_cleared := false

	for access_candidate in candidates:
		checked_candidates += 1

		if checked_candidates > MAX_SHELF_ACCESS_CANDIDATES:
			break

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var access_point := access_candidate.get("access_point", Vector2.INF) as Vector2
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var vertical_access := bool(access_candidate.get("vertical_access", false))
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var access_side := str(access_candidate.get("access_side", ""))
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var vertical_distance := float(access_candidate.get("vertical_distance", INF))

		if not access_point.is_finite():
			continue

		if vertical_only and not vertical_access:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var clear_start_usec := Time.get_ticks_usec()
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var clear_result := _clearance.debug_npc_access_point_clear(access_point, shelf_object, candidate_position)

		if bool(clear_result.get("valid", false)):
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var candidate_is_preferred_side := (access_side == "below") == prefer_below
			if candidate_is_preferred_side:
				preferred_side_cleared = true
			elif prefer_below and cashier_pos.is_finite():
				clear_check_elapsed_msec += _elapsed_msec(clear_start_usec)
				blocked_candidates += 1
				continue
			elif not prefer_below and cashier_pos.is_finite():
				clear_check_elapsed_msec += _elapsed_msec(clear_start_usec)
				blocked_candidates += 1
				continue
		else:
			clear_check_elapsed_msec += _elapsed_msec(clear_start_usec)
			blocked_candidates += 1
			pass
			continue
		clear_check_elapsed_msec += _elapsed_msec(clear_start_usec)

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var direct_checkout := _get_direct_checkout_access(access_point, shelf_object, candidate_position)

		if bool(direct_checkout.get("valid", false)):
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var graph_node := direct_checkout.get("node", StringName()) as StringName
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var scoring_start_usec := Time.get_ticks_usec()
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var score := (
				float(access_candidate.get("vertical_distance", 0.0)) * SHELF_ACCESS_DISTANCE_SCORE_WEIGHT
				+ float(direct_checkout.get("distance", 0.0))
				+ float(access_candidate.get("horizontal_distance", 0.0)) * 0.25
			)
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var candidate_prefer_below := access_side == "below"
			if prefer_below != candidate_prefer_below and cashier_pos.is_finite():
				@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
				var wrong_side_dist := absf(access_point.y - cashier_pos.y)
				score += wrong_side_dist * COUNTER_DIRECTION_PENALTY_SCALE
			scoring_elapsed_msec += _elapsed_msec(scoring_start_usec)
			valid_candidates += 1
			pass

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

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var direct_checkout_attempts := direct_checkout.get("attempts", []) as Array
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var candidate_surface_searches := [0]
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var reachable_start_usec := Time.get_ticks_usec()
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
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
			pass
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var graph_node := reachable_node.get("node", StringName()) as StringName
		pass
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var checkout_start_usec := Time.get_ticks_usec()
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var graph_path: Array[StringName] = _nav.find_checkout_graph_path(graph_node)
		checkout_elapsed_msec += _elapsed_msec(checkout_start_usec)

		if graph_path.is_empty():
			no_checkout_route_candidates += 1
			pass
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var scoring_start_usec := Time.get_ticks_usec()
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var score := (
			float(access_candidate.get("vertical_distance", 0.0)) * SHELF_ACCESS_DISTANCE_SCORE_WEIGHT
			+ float(reachable_node.get("distance", 0.0))
			+ _nav.get_graph_path_cost(graph_path)
			+ float(access_candidate.get("horizontal_distance", 0.0)) * 0.25
		)
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var candidate_prefer_below := access_side == "below"
		if prefer_below != candidate_prefer_below and cashier_pos.is_finite():
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var wrong_side_dist := absf(access_point.y - cashier_pos.y)
			score += wrong_side_dist * COUNTER_DIRECTION_PENALTY_SCALE
		scoring_elapsed_msec += _elapsed_msec(scoring_start_usec)
		valid_candidates += 1
		pass

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

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var total_elapsed_msec := _elapsed_msec(debug_start_usec)
	pass

	if bool(best_result.get("valid", false)):
		pass
		return best_result

	return {"valid": false}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func store_shelf_access_metadata(object: Node2D, drop_position: Vector2) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var result := find_best_vertical_shelf_access(drop_position, object)

	if not bool(result.get("valid", false)):
		clear_shelf_access_metadata(object)
		return

	_store_access_metadata_from_result(object, result)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
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

	object.set_meta("npc_path_ready", false)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
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
	object.set_meta("npc_path_ready", true)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_shelf_access_graph_node(shelf: Shelf) -> StringName:
	if shelf == null:
		return StringName()

	if shelf.has_meta(ACCESS_NODE_META):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var graph_node: Variant = shelf.get_meta(ACCESS_NODE_META)

		if graph_node is StringName:
			return graph_node as StringName

		if graph_node is String:
			return StringName(graph_node)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var result := find_best_vertical_shelf_access(shelf.global_position, shelf)
	_store_access_metadata_from_result(shelf, result)
	return result.get("graph_node", StringName()) as StringName


# ── Internal route helpers ───────────────────────────────────────────────────

@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _find_nearest_reachable_graph_node(
	access_point: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF
) -> Dictionary:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_result := {"valid": false}
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_score := INF

	for node_name in _nav.get_graph_node_names():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var marker: Marker2D = _nav.get_graph_marker(node_name)

		if marker == null:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var route := _routes.make_orthogonal_route(access_point, marker.global_position, true)

		if not _clearance.is_route_clear(access_point, route, shelf_object, shelf_position):
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var distance := _routes.get_euclidean_distance(access_point, marker.global_position)

		if distance < best_score:
			best_score = distance
			best_result = {
				"valid": true,
				"node": node_name,
				"route": route,
				"distance": distance
			}

	return best_result


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _find_reachable_graph_node_for_access(
	access_point: Vector2,
	preferred_node: StringName,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	surface_searches: Array = [],
	surface_route_cache: Dictionary = {},
	surface_anchor_path_cache: Dictionary = {}
) -> Dictionary:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var graph_node_names := _get_nearest_graph_node_names_for_access(
		access_point,
		preferred_node,
		MAX_ACCESS_GRAPH_NODE_CANDIDATES
	)

	if preferred_node != StringName():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var preferred_marker: Marker2D = _nav.get_graph_marker(preferred_node)

		if preferred_marker != null:
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var preferred_route := _routes.make_orthogonal_route(preferred_marker.global_position, access_point, true)

			if _clearance.is_route_clear(preferred_marker.global_position, preferred_route, shelf_object, shelf_position):
				return {
					"valid": true,
					"node": preferred_node,
					"route": preferred_route,
					"distance": _routes.get_euclidean_distance(access_point, preferred_marker.global_position)
				}

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_result := {"valid": false}
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_score := INF

	for node_name in graph_node_names:
		if node_name == preferred_node:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var marker: Marker2D = _nav.get_graph_marker(node_name)

		if marker == null:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var direct_route := _routes.make_orthogonal_route(marker.global_position, access_point, true)
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var distance := _routes.get_euclidean_distance(access_point, marker.global_position)

		if _clearance.is_route_clear(marker.global_position, direct_route, shelf_object, shelf_position):
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
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var marker: Marker2D = _nav.get_graph_marker(node_name)

		if marker == null:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var distance := _routes.get_euclidean_distance(access_point, marker.global_position)

		if distance >= best_score:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var surface_route := _surface.find_surface_route_between_marker_and_access(
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


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _append_surface_access_route_to(
	route: Array[Vector2],
	shelf: Shelf,
	graph_node: StringName,
	access_point: Vector2,
	route_from_graph: bool
) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var access_route := _get_surface_access_route(shelf, graph_node, access_point)

	if access_route.is_empty():
		_routes.append_orthogonal_route_to(route, access_point, true)
		return

	if not route_from_graph:
		access_route.reverse()

	route.append_array(access_route)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_surface_access_route(shelf: Shelf, graph_node: StringName, access_point: Vector2) -> Array[Vector2]:
	if shelf != null and shelf.has_meta(ACCESS_ROUTE_META):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var route_meta: Variant = shelf.get_meta(ACCESS_ROUTE_META)

		if route_meta is Array:
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var route: Array[Vector2] = []

			for point in route_meta:
				if point is Vector2:
					route.append(point)

			if not route.is_empty():
				return route

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var result := _surface.find_surface_route_between_marker_and_access(
		graph_node,
		access_point,
		shelf,
		shelf.global_position if shelf != null else Vector2.INF
	)

	if bool(result.get("valid", false)):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var rebuilt_route := result.get("route", []) as Array[Vector2]

		if shelf != null:
			shelf.set_meta(ACCESS_ROUTE_META, rebuilt_route)

		return rebuilt_route

	return []


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_entry_to_access_route(
	access_point: Vector2,
	shelf: Shelf,
	metadata_graph_node: StringName,
	from_position: Vector2,
	npc_node: Node = null
) -> Dictionary:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route_start: Vector2 = from_position if from_position.is_finite() else _nav.get_marker_position(_nav.get_role_node_name(ROLE_ENTRY, ENTRY))

	if not route_start.is_finite() or not access_point.is_finite():
		return {"valid": false}

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var direct_orders := [
		{"horizontal_first": true, "source": "direct_entry_horizontal"},
		{"horizontal_first": false, "source": "direct_entry_vertical"}
	]

	for order in direct_orders:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var route := _routes.make_orthogonal_route(route_start, access_point, bool(order.get("horizontal_first", true)))
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var debug_result := _clearance.debug_route_to_access_clear(route_start, route, shelf, npc_node)
		pass

		if not _clearance.is_route_to_access_clear(route_start, route, shelf, npc_node):
			continue

		return {
			"valid": true,
			"route": route,
			"distance": _routes.get_route_distance(route_start, route),
			"source": order.get("source", "")
		}

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_result := {"valid": false}
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_score := INF
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var start_node: Dictionary = _nav.find_nearest_graph_node(route_start)

	if not bool(start_node.get("valid", false)):
		return best_result

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var start_graph_node := start_node.get("node", _nav.get_role_node_name(ROLE_ENTRY, ENTRY)) as StringName

	for node_name in _get_nearest_graph_node_names_for_access(access_point, metadata_graph_node, MAX_ACCESS_GRAPH_NODE_CANDIDATES):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var marker: Marker2D = _nav.get_graph_marker(node_name)

		if marker == null:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var path: Array[StringName] = _nav.find_graph_path(start_graph_node, node_name)

		if path.is_empty():
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var route := (start_node.get("route", []) as Array[Vector2]).duplicate()
		route.append_array(_routes.build_route_from_graph_path(path))
		_routes.append_orthogonal_route_to(route, access_point, true)
		route = _routes.dedupe_route_points(route)
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var debug_result := _clearance.debug_route_to_access_clear(route_start, route, shelf, npc_node)
		debug_result["candidate_node"] = node_name
		debug_result["graph_path"] = path
		pass

		if not _clearance.is_route_to_access_clear(route_start, route, shelf, npc_node):
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var score := _routes.get_route_distance(route_start, route)

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


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_direct_checkout_access(access_point: Vector2, shelf_object: Node2D, shelf_position: Vector2) -> Dictionary:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var queue_front_node: StringName = _nav.get_role_node_name(ROLE_QUEUE_FRONT, QUEUE_FRONT)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var cashier_node: StringName = _nav.get_role_node_name(ROLE_CASHIER, CASHIER)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var attempts: Array[Dictionary] = []

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var checkout_candidates := [
		{
			"node": queue_front_node,
			"checkout_source": "direct_queue"
		},
		{
			"node": cashier_node,
			"checkout_source": "direct_cashier"
		}
	]

	for candidate in checkout_candidates:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var node_name := candidate.get(
			"node",
			StringName()
		) as StringName

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var marker: Marker2D = _nav.get_graph_marker(node_name)

		if marker == null:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var route := _routes.make_direct_route(
			access_point,
			marker.global_position
		)

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var clear := (
			route.is_empty()
			or _clearance.is_any_direction_segment_clear(
				access_point,
				marker.global_position,
				shelf_object,
				shelf_position,
				null,
				true,
				false
			)
		)

		attempts.append({
			"target_node": node_name,
			"target_position": marker.global_position,
			"route_order": "direct_diagonal",
			"clear": clear,
			"route": route
		})

		if not clear:
			continue

		return {
			"valid": true,
			"node": node_name,
			"route": route,
			"distance": access_point.distance_to(
				marker.global_position
			),
			"checkout_source": "%s_diagonal" % str(
				candidate.get("checkout_source", "")
			),
			"attempts": attempts
		}

	return {
		"valid": false,
		"attempts": attempts
	}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_direct_checkout_target_node_name(from_position: Vector2) -> StringName:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var queue_front_node: StringName = _nav.get_role_node_name(ROLE_QUEUE_FRONT, QUEUE_FRONT)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var cashier_node: StringName = _nav.get_role_node_name(ROLE_CASHIER, CASHIER)

	for node_name in [queue_front_node, cashier_node]:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var marker: Marker2D = _nav.get_graph_marker(node_name)

		if marker == null:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var route := _routes.make_orthogonal_route(from_position, marker.global_position, true)

		if _clearance.is_route_clear(from_position, route):
			return node_name

	return queue_front_node if _nav.get_graph_marker(queue_front_node) != null else cashier_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_nearest_graph_node_names_for_access(access_point: Vector2, preferred_node: StringName, limit: int) -> Array[StringName]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var names: Array[StringName] = _nav.get_graph_node_names()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var ranked: Array[Dictionary] = []

	for node_name in names:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var marker: Marker2D = _nav.get_graph_marker(node_name)

		if marker == null:
			continue

		ranked.append({
			"node": node_name,
			"distance": _routes.get_euclidean_distance(access_point, marker.global_position)
		})

	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", INF)) < float(b.get("distance", INF))
	)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var selected: Array[StringName] = []

	if preferred_node != StringName() and _nav.get_graph_marker(preferred_node) != null:
		selected.append(preferred_node)

	for item in ranked:
		if selected.size() >= limit:
			break

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var node_name := item.get("node", StringName()) as StringName

		if node_name == StringName() or node_name in selected:
			continue

		selected.append(node_name)

	return selected


# ── Exit route via queue right ───────────────────────────────────────────────

@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _build_exit_route_via_queue_right(from_position: Vector2, fallback_exit_position: Vector2) -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var queue_right_nodes: Array[StringName] = _nav.get_queue_right_node_names()
	if queue_right_nodes.is_empty():
		return []

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var queue_right_node: StringName = _nav.get_nearest_queue_right_node_name(from_position)

	if queue_right_node == StringName():
		return []

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var queue_right_marker: Marker2D = _nav.get_graph_marker(queue_right_node)

	if queue_right_marker == null:
		return []

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route: Array[Vector2] = [queue_right_marker.global_position]

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var start_index: int = queue_right_nodes.find(queue_right_node)
	for i in range(start_index + 1, queue_right_nodes.size()):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var next_marker: Marker2D = _nav.get_graph_marker(queue_right_nodes[i])
		if next_marker != null:
			route.append(next_marker.global_position)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var last_node := queue_right_nodes.back() as StringName
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var exit_node: StringName = _nav.get_role_node_name(ROLE_EXIT, EXIT)

	if exit_node != StringName():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var exit_path: Array[StringName] = _nav.find_graph_path(last_node, exit_node)

		if not exit_path.is_empty():
			route.append_array(_routes.build_route_from_graph_path(exit_path))
			return _routes.dedupe_route_points(route)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var last_pos: Vector2 = route.back() as Vector2 if not route.is_empty() else from_position
	route.append_array(_routes.make_orthogonal_route(last_pos, fallback_exit_position, true))
	return _routes.dedupe_route_points(route)


# ── Utility ──────────────────────────────────────────────────────────────────

@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _variant_route_to_vector2_array(route: Array) -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var points: Array[Vector2] = []

	for point in route:
		if point is Vector2:
			points.append(point as Vector2)

	return points


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _elapsed_msec(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000.0


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_perf_shelf_name(shelf_object: Node2D) -> String:
	return shelf_object.name if shelf_object != null else "<null>"


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_debug_route_point_count(route_variant: Variant) -> int:
	if not (route_variant is Array):
		return 0

	return (route_variant as Array).size()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_surface_points_signature(points: Array[Vector2]) -> String:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var parts: Array[String] = []

	for point in points:
		parts.append("%d,%d" % [roundi(point.x), roundi(point.y)])

	return "|".join(parts)
