extends RefCounted

## Shared state and public route API for StorePathGraph.

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
const MAX_ACCESS_GRAPH_NODE_CANDIDATES: int = 64
const SURFACE_CONNECTOR_LIMIT: int = 2
const MAX_SURFACE_ROUTE_SEARCHES: int = 16
const SURFACE_ALIGNMENT_EPSILON: float = 2.0
const SURFACE_NEIGHBOR_MAX_DISTANCE: float = 36.0
const SHELF_ACCESS_DISTANCE_SCORE_WEIGHT: float = 1000.0
const COUNTER_DIRECTION_PENALTY_SCALE: float = 1000.0

var _store: Node2D = null
var _markers: Node2D = null
var _shelf_access_points: Array[Vector2] = []
var _surface_neighbor_cache: Dictionary = {}
var _surface_neighbor_signature: String = ""
var _cached_shelf_anchor_positions: Array[Vector2] = []
var _cached_shelf_anchor_count: int = -1
var _cached_graph_node_names: Array[StringName] = []
var _cached_graph_node_count: int = -1

var _routes: StorePathGraphRoutes
var _clearance: StorePathGraphClearance
var _nav: StorePathGraphGraph
var _shelf: StorePathGraphShelfAccess
var _surface: StorePathGraphSurface


func _init(store_node: Node2D = null, marker_root: Node2D = null) -> void:
	_store = store_node
	_markers = marker_root
	_routes = StorePathGraphRoutes.new(self)
	_clearance = StorePathGraphClearance.new(self)
	_nav = StorePathGraphGraph.new(self)
	_shelf = StorePathGraphShelfAccess.new(self)
	_surface = StorePathGraphSurface.new(self)


func setup(store_node: Node2D, marker_root: Node2D) -> void:
	_store = store_node
	if _markers != marker_root:
		_markers = marker_root
		_cached_graph_node_names.clear()
		_cached_graph_node_count = -1
		_cached_shelf_anchor_positions.clear()
		_cached_shelf_anchor_count = -1


func set_shelf_access_points(points: Array[Vector2]) -> void:
	var next_points: Array[Vector2] = points.duplicate()
	var next_signature := _get_surface_points_signature(next_points)
	var current_signature := _get_surface_points_signature(_shelf_access_points)
	if next_signature != current_signature:
		_surface_neighbor_cache.clear()
		_surface_neighbor_signature = ""
	_shelf_access_points = next_points


func invalidate_surface_graph_cache() -> void:
	_surface_neighbor_cache.clear()
	_surface_neighbor_signature = ""


func get_marker_for_role(
	role: StringName,
	fallback_node_name: StringName = StringName()
) -> Marker2D:
	var role_node := _nav.get_role_node_name(role, fallback_node_name)
	if role_node == StringName():
		return null
	return _nav.get_graph_marker(role_node)


func get_shelf_anchor_positions() -> Array[Vector2]:
	var graph_nodes := _nav.get_graph_node_names()
	if _cached_shelf_anchor_count == graph_nodes.size():
		return _cached_shelf_anchor_positions.duplicate()

	var positions: Array[Vector2] = []
	for node_name in graph_nodes:
		var graph_marker: Marker2D = _nav.get_graph_marker(node_name)
		if graph_marker == null:
			continue
		if bool(graph_marker.get_meta(SHELF_ANCHOR_META, false)):
			positions.append(graph_marker.global_position)

	_cached_shelf_anchor_positions = positions
	_cached_shelf_anchor_count = graph_nodes.size()
	return positions.duplicate()


func get_queue_target_position(
	queue_index: int,
	fallback_position: Vector2
) -> Vector2:
	var queue_node := _nav.get_queue_target_node_name(queue_index)
	var queue_marker: Marker2D = _nav.get_graph_marker(queue_node)
	if queue_marker == null:
		return fallback_position

	var front_node := _nav.get_role_node_name(ROLE_QUEUE_FRONT, QUEUE_FRONT)
	if queue_index > 0 and queue_node == front_node:
		const QUEUE_SLOT_SPACING := Vector2(0, 22)
		return queue_marker.global_position + QUEUE_SLOT_SPACING * queue_index
	return queue_marker.global_position


func get_cashier_target_position(fallback_position: Vector2) -> Vector2:
	var cashier_marker: Marker2D = get_marker_for_role(ROLE_CASHIER, CASHIER)
	if cashier_marker == null:
		return fallback_position
	return cashier_marker.global_position


func get_entry_route_to_shelf(
	shelf_position: Vector2,
	from_position: Vector2 = Vector2.INF
) -> Array[Vector2]:
	var route_start := from_position
	if not route_start.is_finite():
		route_start = _nav.get_marker_position(
			_nav.get_role_node_name(ROLE_ENTRY, ENTRY)
		)
	if not route_start.is_finite() or not shelf_position.is_finite():
		return []

	var direct_candidates: Array[Dictionary] = []
	_append_clear_route_variants(
		direct_candidates,
		route_start,
		shelf_position,
		null,
		Vector2.INF,
		false
	)
	var direct_route := _get_shortest_route(direct_candidates)
	if not direct_route.is_empty():
		return direct_route

	var aisle_node := _nav.get_role_node_name(&"aisle_right", AISLE_RIGHT)
	var graph_result := _nav.find_nearest_reachable_graph_node_for_route(
		route_start,
		aisle_node
	)
	if not bool(graph_result.get("valid", false)):
		return []

	var graph_route := _variant_route_to_vector2_array(
		graph_result.get("route", [])
	)
	var graph_end := route_start
	if not graph_route.is_empty():
		graph_end = graph_route.back()
	graph_route.append_array(
		_routes.make_orthogonal_route(graph_end, shelf_position, true)
	)
	graph_route = _routes.dedupe_route_points(graph_route)
	if not _clearance.is_route_clear_from_current_position(
		route_start,
		graph_route
	):
		return []
	return graph_route


func get_shelf_access_position(shelf: Shelf) -> Vector2:
	if shelf == null:
		return Vector2.INF
	if shelf.has_meta(ACCESS_META):
		var stored_access: Variant = shelf.get_meta(ACCESS_META)
		if stored_access is Vector2:
			return stored_access as Vector2

	var access_result := find_best_vertical_shelf_access(
		shelf.global_position,
		shelf
	)
	_store_access_metadata_from_result(shelf, access_result)
	return access_result.get("access_point", Vector2.INF) as Vector2


func has_cached_shelf_access_metadata(shelf: Shelf) -> bool:
	if shelf == null:
		return false
	return shelf.has_meta(ACCESS_META) and shelf.has_meta(ACCESS_NODE_META)


func get_route_to_shelf_access(
	shelf: Shelf,
	from_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> Array[Vector2]:
	if shelf == null or not from_position.is_finite():
		return []

	var access_position := get_shelf_access_position(shelf)
	var shelf_graph_node := get_shelf_access_graph_node(shelf)
	if not access_position.is_finite() or shelf_graph_node == StringName():
		return []

	var candidates: Array[Dictionary] = []
	_append_access_route_variants(
		candidates,
		from_position,
		access_position,
		shelf,
		npc_node
	)

	for candidate_node in _get_nearest_graph_node_names_for_access(
		access_position,
		shelf_graph_node,
		MAX_ACCESS_GRAPH_NODE_CANDIDATES
	):
		var graph_result := _nav.find_nearest_reachable_graph_node_for_route(
			from_position,
			candidate_node
		)
		if not bool(graph_result.get("valid", false)):
			continue

		var route := _variant_route_to_vector2_array(
			graph_result.get("route", [])
		)
		var route_end := from_position
		if not route.is_empty():
			route_end = route.back()
		var access_connection := _get_connection_from_graph_node_to_access(
			candidate_node,
			access_position,
			shelf
		)

		if access_connection.is_empty():
			for horizontal_first in [true, false]:
				var fallback_connection := _routes.make_orthogonal_route(
					route_end,
					access_position,
					horizontal_first
				)
				var fallback_route := route.duplicate()
				fallback_route.append_array(fallback_connection)
				fallback_route = _routes.dedupe_route_points(fallback_route)
				if _clearance.is_route_to_access_clear(
					from_position,
					fallback_route,
					shelf,
					npc_node
				):
					_append_route_candidate(
						candidates,
						from_position,
						fallback_route
					)
			continue

		var complete_route := route.duplicate()
		complete_route.append_array(access_connection)
		complete_route = _routes.dedupe_route_points(complete_route)
		if _clearance.is_route_to_access_clear(
			from_position,
			complete_route,
			shelf,
			npc_node
		):
			_append_route_candidate(
				candidates,
				from_position,
				complete_route
			)

	return _get_shortest_route(candidates)


func get_route_to_cashier_from(from_position: Vector2) -> Array[Vector2]:
	return _get_shortest_checkout_route(from_position, null)


func get_shelf_wait_position(index: int = 0) -> Vector2:
	var wait_markers: Array[Marker2D] = _nav.get_markers_by_role(&"shelf_wait")
	if wait_markers.is_empty():
		return Vector2.INF
	for wait_marker in wait_markers:
		if int(wait_marker.get_meta("store_wait_index", 0)) == index:
			return wait_marker.global_position
	return wait_markers[index % wait_markers.size()].global_position


func get_route_to_queue_target_from(
	from_position: Vector2,
	queue_index: int
) -> Array[Vector2]:
	var queue_target := get_queue_target_position(queue_index, from_position)
	var direct_route: Array[Vector2] = [queue_target]
	if _clearance.is_queue_route_clear_from_current_position(
		from_position,
		direct_route
	):
		return direct_route

	var queue_node := _nav.get_queue_target_node_name(queue_index)
	var graph_result := _nav.find_nearest_reachable_graph_node_for_route(
		from_position,
		queue_node
	)
	if not bool(graph_result.get("valid", false)):
		return []
	return _routes.dedupe_route_points(
		_variant_route_to_vector2_array(graph_result.get("route", []))
	)


func get_route_from_shelf_to_cashier(shelf: Shelf) -> Array[Vector2]:
	if shelf == null:
		return []
	var access_position := get_shelf_access_position(shelf)
	if not access_position.is_finite():
		return []
	return _get_shortest_checkout_route(access_position, shelf)


func get_cashier_exit_route(
	from_position: Vector2,
	fallback_exit_position: Vector2
) -> Array[Vector2]:
	return _build_cashier_exit_route_via_queue_right(
		from_position,
		fallback_exit_position
	)


func get_exit_route_from(
	from_position: Vector2,
	fallback_exit_position: Vector2
) -> Array[Vector2]:
	var exit_node := _nav.get_role_node_name(ROLE_EXIT, EXIT)
	var graph_result := _nav.find_nearest_reachable_graph_node_for_route(
		from_position,
		exit_node
	)
	if bool(graph_result.get("valid", false)):
		return _routes.dedupe_route_points(
			_variant_route_to_vector2_array(graph_result.get("route", []))
		)

	var fallback_route := _routes.make_orthogonal_route(
		from_position,
		fallback_exit_position,
		true
	)
	if _clearance.is_route_clear_from_current_position(
		from_position,
		fallback_route
	):
		return _routes.dedupe_route_points(fallback_route)
	return []


func has_reachable_shelf_access(
	object: Node2D,
	candidate: Vector2
) -> bool:
	return bool(find_best_shelf_access(candidate, object).get("valid", false))


# Override contracts implemented by StorePathGraph.gd.
func find_best_shelf_access(
	_candidate_position: Vector2,
	_shelf_object: Node2D
) -> Dictionary:
	return {"valid": false}


func find_best_vertical_shelf_access(
	_candidate_position: Vector2,
	_shelf_object: Node2D
) -> Dictionary:
	return {"valid": false}


func _get_surface_points_signature(_points: Array[Vector2]) -> String:
	return ""


func _append_clear_route_variants(
	_candidates: Array[Dictionary],
	_from_position: Vector2,
	_target_position: Vector2,
	_shelf_object: Node2D,
	_shelf_position: Vector2,
	_ignore_endpoint: bool
) -> void:
	pass


func _get_shortest_route(_candidates: Array[Dictionary]) -> Array[Vector2]:
	return []


func _variant_route_to_vector2_array(_route_variant: Variant) -> Array[Vector2]:
	return []


func _store_access_metadata_from_result(
	_object: Node2D,
	_result: Dictionary
) -> void:
	pass


func get_shelf_access_graph_node(_shelf_node: Shelf) -> StringName:
	return StringName()


func _append_access_route_variants(
	_candidates: Array[Dictionary],
	_from_position: Vector2,
	_access_position: Vector2,
	_shelf_node: Shelf,
	_npc_node: Node
) -> void:
	pass


func _get_nearest_graph_node_names_for_access(
	_access_position: Vector2,
	_preferred_node: StringName,
	_limit: int
) -> Array[StringName]:
	return []


func _get_connection_from_graph_node_to_access(
	_graph_node: StringName,
	_access_position: Vector2,
	_shelf_node: Shelf
) -> Array[Vector2]:
	return []


func _append_route_candidate(
	_candidates: Array[Dictionary],
	_from_position: Vector2,
	_route: Array[Vector2]
) -> void:
	pass


func _get_shortest_checkout_route(
	_from_position: Vector2,
	_source_shelf: Shelf
) -> Array[Vector2]:
	return []


func _build_cashier_exit_route_via_queue_right(
	_from_position: Vector2,
	_fallback_exit_position: Vector2
) -> Array[Vector2]:
	return []
