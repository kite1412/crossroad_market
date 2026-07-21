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
const STORE_ENTRY_FALLBACK_POSITION := Vector2(240, 204)

var store: Node = null
var _navigation_service: StoreNavigationService = null
var _last_shelf_layout_signature: String = ""
var _has_shelf_layout_signature: bool = false


func setup(store_node: Node) -> void:
	store = store_node
	if store != null:
		get_store_path_graph()


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


func get_npc_shelf_access_position(shelf: Shelf) -> Vector2:
	return get_store_path_graph().get_shelf_access_position(shelf)


func get_npc_shelf_visit_position(
	shelf: Shelf,
	_npc: Node = null
) -> Vector2:
	if not has_npc_shelf_access_metadata(shelf):
		return Vector2.INF
	return get_npc_shelf_access_position(shelf)


func has_npc_shelf_access_metadata(shelf: Shelf) -> bool:
	return get_store_path_graph().has_cached_shelf_access_metadata(shelf)


func get_npc_route_to_shelf_access(
	shelf: Shelf,
	from_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> Array[Vector2]:
	if not has_npc_shelf_access_metadata(shelf):
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
	var exit_route := get_npc_exit_route_from(route_end, npc_node)
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
	return get_npc_exit_route_from(from_position, npc_node)


func get_npc_local_avoidance_adjustment(
	npc: NPC,
	desired_target: Vector2
) -> Dictionary:
	var service := get_navigation_service()
	if service == null:
		return {"target": desired_target, "wait": false}
	return service.get_local_avoidance_adjustment(npc, desired_target)


func invalidate_navigation() -> void:
	var graph := get_store_path_graph()
	if graph.has_method("invalidate_dynamic_navigation"):
		graph.call("invalidate_dynamic_navigation")
	if _navigation_service != null:
		_navigation_service.invalidate_all()


func get_navigation_service() -> StoreNavigationService:
	var graph := get_store_path_graph()
	_ensure_navigation_service(graph)
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

	var layout_signature := _get_shelf_layout_signature()
	if (
		not needs_runtime_graph
		and _has_shelf_layout_signature
		and layout_signature != _last_shelf_layout_signature
		and store._store_path_graph.has_method("invalidate_dynamic_navigation")
	):
		store._store_path_graph.call("invalidate_dynamic_navigation")

	_last_shelf_layout_signature = layout_signature
	_has_shelf_layout_signature = true
	var anchors: Array[Vector2] = store._get_shelf_placement_grid_positions()
	store._store_path_graph.set_shelf_access_points(anchors)
	_ensure_navigation_service(store._store_path_graph, anchors)
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
	anchors: Array[Vector2] = []
) -> void:
	if store == null or graph == null:
		return
	if _navigation_service == null:
		_navigation_service = NavigationServiceScript.new()
	var next_anchors := anchors
	if next_anchors.is_empty():
		next_anchors = store._get_shelf_placement_grid_positions()
	_navigation_service.setup(
		store,
		store.store_path_markers,
		graph,
		next_anchors
	)


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


func _append_unique_route_point(
	route: Array[Vector2],
	point: Vector2
) -> void:
	if not point.is_finite():
		return
	if not route.is_empty() and route.back().distance_to(point) <= 2.0:
		return
	route.append(point)
