class_name StoreNpcRoutes
extends Node

const StoreRuntimePathGraphScript = preload(
	"res://scripts/locations/store/StoreRuntimePathGraph.gd"
)
const NavigationServiceScript = preload(
	"res://scripts/navigation/store/StoreNavigationRuntimeService.gd"
)
const NavigationRequestScript = preload(
	"res://scripts/navigation/store/StoreNavigationRequest.gd"
)
const ShelfAccessCoordinatorScript = preload(
	"res://scripts/navigation/store/StoreShelfAccessCoordinator.gd"
)

const STORE_ENTRY_FALLBACK_POSITION := Vector2(240, 204)
const CHECKOUT_RIGHT_ROUTE_MARKERS: Array[StringName] = [
	&"StorePathQueueFrontRight",
	&"StorePathQueueBack1Right",
	&"StorePathQueueBack2Right",
	&"StorePathQueueExitRight"
]
const SINGLE_CUSTOMER_EXIT_ROUTE_MARKERS: Array[StringName] = [
	&"StorePathQueueFront",
	&"StorePathQueueBack2",
	&"StorePathAisleRight",
	&"StorePathExit"
]
const CHECKOUT_GRAPH_REJOIN_MARKER: StringName = &"StorePathAisleRight"
const CHECKOUT_ROUTE_RESUME_DISTANCE: float = 18.0

var store: Node = null
var _navigation_service: StoreNavigationService = null
var _shelf_access_coordinator: StoreShelfAccessCoordinator = null
var _navigation_anchors: Array[Vector2] = []
var _anchors_initialized: bool = false
var _last_shelf_layout_signature: String = ""
var _has_shelf_layout_signature: bool = false


func setup(store_node: Node) -> void:
	store = store_node
	set_process(store != null)
	if store != null:
		get_store_path_graph()


func _process(_delta: float) -> void:
	if _shelf_access_coordinator != null:
		_shelf_access_coordinator.process_pending_jobs()


func get_npc_entry_route_to_shelf(
	shelf_position: Vector2,
	from_position: Vector2 = Vector2.INF
) -> Array[Vector2]:
	var start_position := from_position
	if not start_position.is_finite():
		start_position = get_marker_position_or(
			store.npc_enter_store_marker,
			STORE_ENTRY_FALLBACK_POSITION
		)

	var service := get_navigation_service()
	if service != null:
		var route := service.plan_to_position(
			start_position,
			shelf_position,
			null
		)
		if not route.is_empty():
			return route

	return get_store_path_graph().get_entry_route_to_shelf(
		shelf_position,
		from_position
	)


func request_npc_shelf_access_state(
	shelf: Shelf,
	high_priority: bool = false
) -> StringName:
	var graph := get_store_path_graph()
	_ensure_shelf_access_coordinator(graph)
	if _shelf_access_coordinator == null:
		return StoreShelfAccessCoordinator.INVALID
	return _shelf_access_coordinator.request_access(shelf, high_priority)


func get_npc_shelf_access_state(shelf: Shelf) -> StringName:
	if _shelf_access_coordinator == null:
		return request_npc_shelf_access_state(shelf)
	var state := _shelf_access_coordinator.get_state(shelf)
	if state == StoreShelfAccessCoordinator.INVALID:
		return request_npc_shelf_access_state(shelf)
	return state


func get_npc_shelf_access_position(shelf: Shelf) -> Vector2:
	if request_npc_shelf_access_state(shelf) != StoreShelfAccessCoordinator.READY:
		return Vector2.INF
	return _shelf_access_coordinator.get_ready_position(shelf)


func get_npc_shelf_visit_position(
	shelf: Shelf,
	_npc: Node = null
) -> Vector2:
	return get_npc_shelf_access_position(shelf)


func has_npc_shelf_access_metadata(shelf: Shelf) -> bool:
	var graph := get_store_path_graph()
	return graph != null and graph.has_cached_shelf_access_metadata(shelf)


func get_npc_route_to_shelf_access(
	shelf: Shelf,
	from_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> Array[Vector2]:
	if request_npc_shelf_access_state(shelf, true) != StoreShelfAccessCoordinator.READY:
		return []

	var service := get_navigation_service()
	if service != null:
		var route := service.plan_to_shelf(
			shelf,
			from_position,
			npc_node
		)
		if not route.is_empty():
			return route

	return get_store_path_graph().get_route_to_shelf_access(
		shelf,
		from_position,
		npc_node
	)


func get_npc_route_to_cashier_from(
	from_position: Vector2,
	npc_node: Node = null
) -> Array[Vector2]:
	var service := get_navigation_service()
	if service != null:
		var route := service.plan_to_cashier(from_position, npc_node)
		if not route.is_empty():
			return route
	return get_store_path_graph().get_route_to_queue_target_from(
		from_position,
		0
	)


func get_npc_route_to_queue_target_from(
	from_position: Vector2,
	queue_index: int,
	npc_node: Node = null
) -> Array[Vector2]:
	var service := get_navigation_service()
	if service != null:
		var route := service.plan_to_queue(
			from_position,
			queue_index,
			null,
			npc_node
		)
		if not route.is_empty():
			return route
	return get_store_path_graph().get_route_to_queue_target_from(
		from_position,
		queue_index
	)


func get_npc_route_from_shelf_to_queue_target(
	shelf: Shelf,
	from_position: Vector2,
	queue_index: int,
	npc_node: Node = null
) -> Array[Vector2]:
	var service := get_navigation_service()
	if service != null:
		var route := service.plan_to_queue(
			from_position,
			queue_index,
			shelf,
			npc_node
		)
		if not route.is_empty():
			return route

	var graph := get_store_path_graph()
	if graph.has_method("get_route_from_shelf_to_queue_target"):
		return _to_vector2_route(
			graph.call(
				"get_route_from_shelf_to_queue_target",
				shelf,
				from_position,
				queue_index,
				npc_node
			)
		)
	return []


func get_npc_queue_target(
	queue_index: int,
	fallback_position: Vector2
) -> Vector2:
	return get_store_path_graph().get_queue_target_position(
		queue_index,
		fallback_position
	)


func get_npc_cashier_target(fallback_position: Vector2) -> Vector2:
	return get_store_path_graph().get_queue_target_position(
		0,
		fallback_position
	)


func get_npc_cashier_face_target(fallback_position: Vector2) -> Vector2:
	return get_store_path_graph().get_cashier_target_position(
		fallback_position
	)


func get_npc_route_from_shelf_to_cashier(
	shelf: Shelf,
	npc_node: Node = null
) -> Array[Vector2]:
	if shelf == null or not is_instance_valid(shelf):
		return []
	var access_position := get_npc_shelf_access_position(shelf)
	if not access_position.is_finite():
		return []
	return get_npc_route_from_shelf_to_queue_target(
		shelf,
		access_position,
		0,
		npc_node
	)


func get_npc_exit_route_from(
	from_position: Vector2,
	npc_node: Node = null
) -> Array[Vector2]:
	var service := get_navigation_service()
	if service != null:
		var route := service.plan_to_exit(from_position, npc_node)
		if not route.is_empty():
			return route

	var exit_position := get_marker_position_or(
		store.npc_exit_marker,
		STORE_ENTRY_FALLBACK_POSITION
	)
	return get_store_path_graph().get_exit_route_from(
		from_position,
		exit_position
	)


func get_npc_shelf_wait_position(index: int = 0) -> Vector2:
	return get_store_path_graph().get_shelf_wait_position(index)


func get_npc_single_customer_exit_route(
	from_position: Vector2,
	npc_node: Node = null
) -> Array[Vector2]:
	var service := get_navigation_service()
	if service != null:
		var route := service.plan_checkout_exit(from_position, npc_node)
		if not route.is_empty():
			return route

	var fallback_route := _build_named_marker_route(
		from_position,
		SINGLE_CUSTOMER_EXIT_ROUTE_MARKERS
	)
	if not fallback_route.is_empty():
		return fallback_route
	return get_npc_exit_route_from(from_position, npc_node)


func get_npc_exit_route_from_shelf(
	shelf: Shelf,
	from_position: Vector2,
	npc_node: Node = null
) -> Array[Vector2]:
	if shelf == null or not is_instance_valid(shelf):
		return get_npc_exit_route_from(from_position, npc_node)

	var service := get_navigation_service()
	if service != null:
		var request := NavigationRequestScript.new() as StoreNavigationRequest
		request.start_position = from_position
		request.goal_type = StoreNavigationRequest.GOAL_EXIT
		request.source_shelf = shelf
		request.npc = npc_node
		request.force_semantic = true
		request.allow_direct = false
		var route := service.plan(request)
		if not route.is_empty():
			return route

	var legacy_route := get_npc_route_from_shelf_to_cashier(
		shelf,
		npc_node
	)
	if legacy_route.is_empty():
		return get_npc_exit_route_from(from_position, npc_node)
	var route_end := legacy_route.back()
	var exit_route := get_npc_single_customer_exit_route(
		route_end,
		npc_node
	)
	for point in exit_route:
		_append_unique_route_point(legacy_route, point)
	return legacy_route


func get_npc_exit_route_from_cashier(
	from_position: Vector2,
	npc_node: Node = null
) -> Array[Vector2]:
	var service := get_navigation_service()
	if service != null:
		var route := service.plan_checkout_exit(from_position, npc_node)
		if not route.is_empty():
			return route
	return _build_checkout_fallback_route(from_position)


func get_npc_local_avoidance_adjustment(
	npc: NPC,
	desired_target: Vector2
) -> Dictionary:
	var service := get_navigation_service()
	if service == null:
		return {"target": desired_target, "wait": false}
	return service.get_local_avoidance_adjustment(npc, desired_target)


func invalidate_npc_shelf_access(shelf: Shelf) -> void:
	var graph := get_store_path_graph()
	_ensure_shelf_access_coordinator(graph)
	if _shelf_access_coordinator != null:
		_shelf_access_coordinator.invalidate_shelf(shelf, true)


func invalidate_navigation() -> void:
	var graph := get_store_path_graph()
	if graph.has_method("invalidate_dynamic_navigation"):
		graph.call("invalidate_dynamic_navigation")
	if _shelf_access_coordinator != null:
		_shelf_access_coordinator.invalidate_all(false)
	if _navigation_service != null:
		_navigation_service.invalidate_all()


func get_navigation_service() -> StoreNavigationService:
	var graph := get_store_path_graph()
	_ensure_navigation_service(graph, _navigation_anchors)
	return _navigation_service


func get_store_path_graph() -> StorePathGraph:
	if store == null:
		return null

	var needs_runtime_graph := (
		store._store_path_graph == null
		or store._store_path_graph.get_script() != StoreRuntimePathGraphScript
	)
	if needs_runtime_graph:
		store._store_path_graph = StoreRuntimePathGraphScript.new(
			store,
			store.store_path_markers
		)
	else:
		store._store_path_graph.setup(
			store,
			store.store_path_markers
		)

	if not _anchors_initialized:
		_navigation_anchors = store._get_shelf_placement_grid_positions()
		_anchors_initialized = true
	store._store_path_graph.set_shelf_access_points(_navigation_anchors)

	var layout_signature := _get_shelf_layout_signature()
	var layout_changed := (
		_has_shelf_layout_signature
		and layout_signature != _last_shelf_layout_signature
	)
	if (
		layout_changed
		and not needs_runtime_graph
		and store._store_path_graph.has_method("invalidate_dynamic_navigation")
	):
		store._store_path_graph.call("invalidate_dynamic_navigation")

	_last_shelf_layout_signature = layout_signature
	_has_shelf_layout_signature = true
	_ensure_shelf_access_coordinator(store._store_path_graph)
	if layout_changed and _shelf_access_coordinator != null:
		_shelf_access_coordinator.invalidate_all(false)
	_ensure_navigation_service(store._store_path_graph, _navigation_anchors)
	return store._store_path_graph


func get_marker_position_or(
	marker_node: Marker2D,
	fallback: Vector2
) -> Vector2:
	if marker_node == null:
		return fallback
	return marker_node.global_position


func _ensure_navigation_service(
	graph: StorePathGraph,
	anchors: Array[Vector2]
) -> void:
	if store == null or graph == null:
		return
	if _navigation_service == null:
		_navigation_service = NavigationServiceScript.new()
	_navigation_service.setup(
		store,
		store.store_path_markers,
		graph,
		anchors
	)


func _ensure_shelf_access_coordinator(graph: StorePathGraph) -> void:
	if store == null or graph == null:
		return
	if _shelf_access_coordinator == null:
		_shelf_access_coordinator = ShelfAccessCoordinatorScript.new()
	_shelf_access_coordinator.setup(store, graph)


func _get_shelf_layout_signature() -> String:
	if store == null or store.get_tree() == null:
		return ""
	var parts := PackedStringArray()
	for shelf_variant in store.get_tree().get_nodes_in_group("shelves"):
		if not (shelf_variant is Shelf):
			continue
		var shelf := shelf_variant as Shelf
		if not is_instance_valid(shelf) or not _is_descendant_of_store(shelf):
			continue
		parts.append(
			"%d:%d:%d" % [
				shelf.get_instance_id(),
				roundi(shelf.global_position.x),
				roundi(shelf.global_position.y)
			]
		)
	parts.sort()
	return "|".join(parts)


func _is_descendant_of_store(node: Node) -> bool:
	var current := node
	while current != null:
		if current == store:
			return true
		current = current.get_parent()
	return false


func _to_vector2_route(route_variant: Variant) -> Array[Vector2]:
	var route: Array[Vector2] = []
	if not (route_variant is Array):
		return route
	for point_variant in route_variant:
		if point_variant is Vector2:
			_append_unique_route_point(route, point_variant as Vector2)
	return route


func _build_checkout_fallback_route(
	from_position: Vector2
) -> Array[Vector2]:
	var mandatory_markers := _get_named_markers(
		CHECKOUT_RIGHT_ROUTE_MARKERS
	)
	if mandatory_markers.size() != CHECKOUT_RIGHT_ROUTE_MARKERS.size():
		return []

	var rejoin_marker := store.store_path_markers.get_node_or_null(
		String(CHECKOUT_GRAPH_REJOIN_MARKER)
	) as Marker2D
	if rejoin_marker == null:
		return []

	var route: Array[Vector2] = []
	var start_index := _get_checkout_route_start_index(
		from_position,
		mandatory_markers
	)
	for index in range(start_index, mandatory_markers.size()):
		_append_unique_route_point(
			route,
			mandatory_markers[index].global_position
		)

	_append_unique_route_point(route, rejoin_marker.global_position)
	var exit_position := get_marker_position_or(
		store.npc_exit_marker,
		STORE_ENTRY_FALLBACK_POSITION
	)
	var graph_route := get_store_path_graph().get_exit_route_from(
		rejoin_marker.global_position,
		exit_position
	)
	for point in graph_route:
		_append_unique_route_point(route, point)
	_append_unique_route_point(route, exit_position)
	return route


func _build_named_marker_route(
	from_position: Vector2,
	marker_names: Array[StringName]
) -> Array[Vector2]:
	var route_markers := _get_named_markers(marker_names)
	if route_markers.size() != marker_names.size():
		return []

	var route: Array[Vector2] = []
	var start_index := _get_checkout_route_start_index(
		from_position,
		route_markers
	)
	for index in range(start_index, route_markers.size()):
		_append_unique_route_point(
			route,
			route_markers[index].global_position
		)
	return route


func _get_named_markers(
	marker_names: Array[StringName]
) -> Array[Marker2D]:
	var result: Array[Marker2D] = []
	if store == null or store.store_path_markers == null:
		return result

	for marker_name in marker_names:
		var route_marker := store.store_path_markers.get_node_or_null(
			String(marker_name)
		) as Marker2D
		if route_marker == null:
			return []
		result.append(route_marker)
	return result


func _get_checkout_route_start_index(
	from_position: Vector2,
	route_markers: Array[Marker2D]
) -> int:
	var final_marker: Marker2D = route_markers.back()
	if from_position.y >= final_marker.global_position.y - 4.0:
		return route_markers.size()

	var nearest_index := -1
	var nearest_distance := INF
	for index in range(route_markers.size()):
		var distance := from_position.distance_to(
			route_markers[index].global_position
		)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index

	if nearest_distance <= CHECKOUT_ROUTE_RESUME_DISTANCE:
		var nearest_marker: Marker2D = route_markers[nearest_index]
		if from_position.y < nearest_marker.global_position.y - 4.0:
			return nearest_index
		return mini(nearest_index + 1, route_markers.size())
	return 0


func _append_unique_route_point(
	route: Array[Vector2],
	point: Vector2
) -> void:
	if not point.is_finite():
		return
	if not route.is_empty() and route.back().distance_to(point) <= 2.0:
		return
	route.append(point)
