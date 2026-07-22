class_name StoreNpcRoutes
extends Node

const OptimizedStorePathGraphScript = preload(
	"res://scripts/locations/store/OptimizedStorePathGraph.gd"
)
const StoreRuntimeDebugProbeScript = preload("res://scripts/debug/StoreRuntimeDebugProbe.gd")
const NPCQueueReservationControllerScript = preload("res://scripts/npc/runtime/NPCQueueReservationController.gd")
const STORE_ENTRY_FALLBACK_POSITION = Vector2(240, 204)
const QUEUE_SHELF_TRANSIT_BACK1: StringName = &"StorePathQueueBack1"
const QUEUE_SHELF_TRANSIT_BACK2: StringName = &"StorePathQueueBack2"
const QUEUE_SHELF_TRANSIT_FULL: StringName = &"StorepathParsenpc"
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
const STORE_EXIT_LANE_MARKERS: Array[StringName] = [
	&"StorePathQueueBack2",
	&"StorePathAisleRight",
	&"StorePathExit"
]
const CHECKOUT_APPROACH_ROUTE_MARKERS: Array[StringName] = [
	&"StorePathQueueFront",
	&"StorePathCashier"
]
const CHECKOUT_GRAPH_REJOIN_MARKER: StringName = &"StorePathAisleRight"
const CHECKOUT_ROUTE_RESUME_DISTANCE: float = 18.0
const SHELF_QUAD_MARKER_PREFIX: String = "StorePathShelfQuad"

var store: Node = null


func setup(store_node: Node) -> void:
	store = store_node


func get_npc_entry_route_to_shelf(
	shelf_position: Vector2,
	from_position: Vector2 = Vector2.INF
) -> Array[Vector2]:
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
	var queue_transit_route := _build_queue_aware_shelf_transit_route(
		shelf,
		from_position,
		npc_node
	)
	if not queue_transit_route.is_empty():
		return queue_transit_route

	return get_store_path_graph().get_route_to_shelf_access(
		shelf,
		from_position,
		npc_node
	)


func get_npc_route_to_cashier_from(
	from_position: Vector2
) -> Array[Vector2]:
	var checkout_approach_route := _build_checkout_approach_route(
		from_position
	)
	if not checkout_approach_route.is_empty():
		return checkout_approach_route

	return get_store_path_graph().get_route_to_cashier_from(from_position)


func get_npc_route_to_queue_target_from(
	from_position: Vector2,
	queue_index: int
) -> Array[Vector2]:
	return get_store_path_graph().get_route_to_queue_target_from(
		from_position,
		queue_index
	)


func get_npc_shelf_egress_route_to_queue_from(
	shelf: Shelf,
	from_position: Vector2,
	queue_index: int,
	destination: Vector2,
	npc_node: Node = null
) -> Array[Vector2]:
	if shelf == null or not is_instance_valid(shelf):
		return []
	var graph := get_store_path_graph()
	if not graph.has_method("get_shelf_egress_route_to_queue_from"):
		return []
	return graph.get_shelf_egress_route_to_queue_from(
		shelf,
		from_position,
		queue_index,
		destination,
		npc_node
	)


func get_npc_marker_lane_route_to_queue_egress(
	from_position: Vector2,
	queue_index: int,
	fallback_position: Vector2
) -> Array[Vector2]:
	if not from_position.is_finite():
		return []

	var shelf_quad := _get_nearest_shelf_quad_marker(from_position)
	var queue_marker := _get_queue_slot_marker(queue_index)
	if shelf_quad == null or queue_marker == null:
		_record_route_probe(&"npc_marker_lane_egress_route", {
			"reason": "missing_marker",
			"queue_index": queue_index,
			"from": _format_vector(from_position),
			"has_shelf_quad": shelf_quad != null,
			"has_queue_marker": queue_marker != null
		})
		return []

	var route: Array[Vector2] = []
	var current := from_position
	current = _append_orthogonal_route_leg(
		route,
		current,
		shelf_quad.global_position,
		false
	)
	var cashier_axis_horizontal_first := _get_cashier_axis_horizontal_first(
		shelf_quad
	)
	current = _append_orthogonal_route_leg(
		route,
		current,
		queue_marker.global_position,
		cashier_axis_horizontal_first
	)

	if route.is_empty() and fallback_position.is_finite():
		_append_orthogonal_route_leg(route, current, fallback_position, true)

	_record_route_probe(&"npc_marker_lane_egress_route", {
		"reason": "built",
		"queue_index": queue_index,
		"from": _format_vector(from_position),
		"shelf_quad": String(shelf_quad.name),
		"shelf_quad_position": _format_vector(shelf_quad.global_position),
		"queue_marker": String(queue_marker.name),
		"queue_position": _format_vector(queue_marker.global_position),
		"axis_order": (
			"horizontal_first"
			if cashier_axis_horizontal_first
			else "vertical_first"
		),
		"route_points": route.size()
	})
	_record_route_probe(&"npc_cashier_axis_policy", {
		"source": "marker_lane_fallback",
		"anchor": String(shelf_quad.name),
		"anchor_position": _format_vector(shelf_quad.global_position),
		"approach": _format_vector(queue_marker.global_position),
		"axis_order": (
			"horizontal_first"
			if cashier_axis_horizontal_first
			else "vertical_first"
		),
		"route_points": route.size()
	})
	return route


func get_npc_queue_egress_target(
	queue_index: int,
	fallback_position: Vector2
) -> Vector2:
	return get_npc_queue_target(queue_index, fallback_position)


func get_npc_queue_target(
	queue_index: int,
	fallback_position: Vector2
) -> Vector2:
	return get_store_path_graph().get_queue_target_position(
		queue_index,
		fallback_position
	)


func get_npc_cashier_target(fallback_position: Vector2) -> Vector2:
	return get_store_path_graph().get_cashier_target_position(
		fallback_position
	)


func get_npc_route_from_shelf_to_cashier(
	shelf: Shelf
) -> Array[Vector2]:
	if shelf == null or not is_instance_valid(shelf):
		return []
	return get_store_path_graph().get_route_from_shelf_to_cashier(shelf)


func get_npc_exit_route_from(
	from_position: Vector2
) -> Array[Vector2]:
	var exit_position = get_marker_position_or(
		store.npc_exit_marker,
		STORE_ENTRY_FALLBACK_POSITION
	)
	var graph_route = get_store_path_graph().get_exit_route_from(
		from_position,
		exit_position
	)
	if not graph_route.is_empty():
		_record_route_probe(&"npc_exit_route_select", {
			"reason": "graph",
			"from": _format_vector(from_position),
			"exit": _format_vector(exit_position),
			"route_points": graph_route.size()
		})
		return graph_route

	return _build_exit_lane_route(
		from_position,
		exit_position,
		"graph_empty"
	)


func get_npc_shelf_wait_position(index: int = 0) -> Vector2:
	var wait_position := get_store_path_graph().get_shelf_wait_position(index)
	if wait_position.is_finite():
		return wait_position

	var aisle_marker := _get_named_marker(CHECKOUT_GRAPH_REJOIN_MARKER)
	if aisle_marker != null:
		return aisle_marker.global_position

	if store != null and store.npc_exit_marker != null:
		return store.npc_exit_marker.global_position
	return STORE_ENTRY_FALLBACK_POSITION


func get_npc_single_customer_exit_route(
	from_position: Vector2
) -> Array[Vector2]:
	var route := _build_named_marker_route(
		from_position,
		SINGLE_CUSTOMER_EXIT_ROUTE_MARKERS
	)
	if not route.is_empty():
		_record_route_probe(&"npc_exit_route_select", {
			"reason": "single_customer_markers",
			"from": _format_vector(from_position),
			"route_points": route.size()
		})
		return route

	var exit_position = get_marker_position_or(
		store.npc_exit_marker,
		STORE_ENTRY_FALLBACK_POSITION
	)
	return _build_exit_lane_route(
		from_position,
		exit_position,
		"single_customer_empty"
	)


func get_npc_exit_route_from_shelf(
	shelf: Shelf,
	from_position: Vector2
) -> Array[Vector2]:
	if shelf == null or not is_instance_valid(shelf):
		return get_npc_exit_route_from(from_position)

	# Move away from the source shelf through the same collision-aware path used
	# after shopping, then join the normal single-customer exit lane.
	var route = get_npc_route_from_shelf_to_cashier(shelf)
	if route.is_empty():
		return get_npc_exit_route_from(from_position)

	var route_end: Vector2 = route.back()
	var exit_route = get_npc_single_customer_exit_route(route_end)
	if exit_route.is_empty():
		exit_route = get_npc_exit_route_from(route_end)

	for point in exit_route:
		_append_unique_route_point(route, point)
	return route


func get_npc_exit_route_from_cashier(
	from_position: Vector2
) -> Array[Vector2]:
	var exit_position = get_marker_position_or(
		store.npc_exit_marker,
		STORE_ENTRY_FALLBACK_POSITION
	)
	var center_exit_route := _build_exit_lane_route_if_centered(
		from_position,
		exit_position
	)
	if not center_exit_route.is_empty():
		return center_exit_route

	var mandatory_markers = _get_named_markers(
		CHECKOUT_RIGHT_ROUTE_MARKERS
	)
	if mandatory_markers.size() != CHECKOUT_RIGHT_ROUTE_MARKERS.size():
		return _build_exit_lane_route(
			from_position,
			exit_position,
			"missing_checkout_right_marker"
		)

	var rejoin_marker = store.store_path_markers.get_node_or_null(
		String(CHECKOUT_GRAPH_REJOIN_MARKER)
	) as Marker2D
	if rejoin_marker == null:
		return _build_exit_lane_route(
			from_position,
			exit_position,
			"missing_rejoin_marker"
		)

	var route: Array[Vector2] = []
	var current := from_position
	var start_index = _get_checkout_route_start_index(
		from_position,
		mandatory_markers
	)
	for index in range(start_index, mandatory_markers.size()):
		current = _append_orthogonal_route_leg(
			route,
			current,
			mandatory_markers[index].global_position,
			true
		)

	current = _append_orthogonal_route_leg(
		route,
		current,
		rejoin_marker.global_position,
		true
	)
	var graph_route = get_store_path_graph().get_exit_route_from(
		rejoin_marker.global_position,
		exit_position
	)
	for point in graph_route:
		current = _append_orthogonal_route_leg(route, current, point, true)

	# Keep the real exit as the final mandatory waypoint even when the graph is
	# already rejoined at AisleRight.
	_append_orthogonal_route_leg(route, current, exit_position, true)
	route = _dedupe_route_points(route)
	if route.is_empty():
		return _build_exit_lane_route(
			from_position,
			exit_position,
			"checkout_right_empty"
		)

	_record_route_probe(&"npc_exit_route_select", {
		"reason": "checkout_right_lane",
		"from": _format_vector(from_position),
		"exit": _format_vector(exit_position),
		"route_points": route.size(),
		"graph_tail_points": graph_route.size()
	})
	return route


func get_store_path_graph() -> StorePathGraph:
	var needs_optimized_graph: bool = (
		store._store_path_graph == null
		or store._store_path_graph.get_script() != OptimizedStorePathGraphScript
	)

	if needs_optimized_graph:
		store._store_path_graph = OptimizedStorePathGraphScript.new(
			store,
			store.store_path_markers
		)
	else:
		store._store_path_graph.setup(
			store,
			store.store_path_markers
		)

	store._store_path_graph.set_shelf_access_points(
		store._get_shelf_placement_grid_positions()
	)
	return store._store_path_graph


func get_marker_position_or(
	marker_node: Marker2D,
	fallback: Vector2
) -> Vector2:
	if marker_node == null:
		return fallback
	return marker_node.global_position


func _build_named_marker_route(
	from_position: Vector2,
	marker_names: Array[StringName]
) -> Array[Vector2]:
	var route_markers = _get_named_markers(marker_names)
	if route_markers.size() != marker_names.size():
		return []

	var route: Array[Vector2] = []
	var current := from_position
	var start_index = _get_checkout_route_start_index(
		from_position,
		route_markers
	)
	for index in range(start_index, route_markers.size()):
		current = _append_orthogonal_route_leg(
			route,
			current,
			route_markers[index].global_position,
			true
		)
	return route


func _build_checkout_approach_route(from_position: Vector2) -> Array[Vector2]:
	var route_markers = _get_named_markers(CHECKOUT_APPROACH_ROUTE_MARKERS)
	if route_markers.size() != CHECKOUT_APPROACH_ROUTE_MARKERS.size():
		return []

	var nearest_index := -1
	var nearest_distance := INF
	for index in range(route_markers.size()):
		var distance := from_position.distance_to(
			route_markers[index].global_position
		)
		if distance >= nearest_distance:
			continue
		nearest_distance = distance
		nearest_index = index

	var start_index := 0
	if nearest_distance <= CHECKOUT_ROUTE_RESUME_DISTANCE:
		start_index = mini(nearest_index + 1, route_markers.size() - 1)

	var route: Array[Vector2] = []
	var current := from_position
	for index in range(start_index, route_markers.size()):
		current = _append_orthogonal_route_leg(
			route,
			current,
			route_markers[index].global_position,
			true
		)
	return route


func _build_exit_lane_route_if_centered(
	from_position: Vector2,
	exit_position: Vector2
) -> Array[Vector2]:
	var cashier_marker := _get_named_marker(&"StorePathCashier")
	if cashier_marker == null:
		return []

	if from_position.x > cashier_marker.global_position.x + 16.0:
		return []
	if from_position.y < cashier_marker.global_position.y - 8.0:
		return []

	return _build_exit_lane_route(
		from_position,
		exit_position,
		"center_cashier_exit"
	)


func _build_exit_lane_route(
	from_position: Vector2,
	exit_position: Vector2,
	reason: String
) -> Array[Vector2]:
	if not from_position.is_finite():
		_record_route_probe(&"npc_exit_route_select", {
			"reason": "invalid_from",
			"source_reason": reason,
			"exit": _format_vector(exit_position)
		})
		return []

	var route: Array[Vector2] = []
	var current := from_position
	var used_markers: Array[String] = []
	var route_markers := _get_named_markers(STORE_EXIT_LANE_MARKERS)
	for marker in route_markers:
		if marker.global_position.y < current.y - 4.0:
			continue

		current = _append_orthogonal_route_leg(
			route,
			current,
			marker.global_position,
			true
		)
		used_markers.append(String(marker.name))

	current = _append_orthogonal_route_leg(route, current, exit_position, true)
	route = _dedupe_route_points(route)
	_record_route_probe(&"npc_exit_route_select", {
		"reason": reason,
		"from": _format_vector(from_position),
		"exit": _format_vector(exit_position),
		"route_points": route.size(),
		"markers": ",".join(used_markers)
	})
	return route


func _get_named_markers(
	marker_names: Array[StringName]
) -> Array[Marker2D]:
	var result: Array[Marker2D] = []
	if store == null or store.store_path_markers == null:
		return result

	for marker_name in marker_names:
		var route_marker = store.store_path_markers.get_node_or_null(
			String(marker_name)
		) as Marker2D
		if route_marker == null:
			return []
		result.append(route_marker)
	return result


func _get_named_marker(marker_name: StringName) -> Marker2D:
	if store == null or store.store_path_markers == null:
		return null
	return store.store_path_markers.get_node_or_null(String(marker_name)) as Marker2D


func _get_nearest_shelf_quad_marker(from_position: Vector2) -> Marker2D:
	if store == null or store.store_path_markers == null:
		return null

	var best_marker: Marker2D = null
	var best_distance := INF
	for child in store.store_path_markers.get_children():
		var marker := child as Marker2D
		if marker == null:
			continue
		if not String(marker.name).begins_with(SHELF_QUAD_MARKER_PREFIX):
			continue

		var distance := from_position.distance_to(marker.global_position)
		if distance >= best_distance:
			continue

		best_marker = marker
		best_distance = distance

	return best_marker


func _build_queue_aware_shelf_transit_route(
	shelf: Shelf,
	from_position: Vector2,
	npc_node: Node
) -> Array[Vector2]:
	if shelf == null or not is_instance_valid(shelf):
		return []
	if not from_position.is_finite():
		return []
	if npc_node == null or not is_instance_valid(npc_node):
		return []

	var active_queue_size := _get_active_shopping_queue_size(npc_node)
	if active_queue_size <= 0:
		return []

	var transit_marker := _get_queue_shelf_transit_marker(active_queue_size)
	if transit_marker == null:
		_record_route_probe(&"npc_transit_queue_bypass_select", {
			"reason": "missing_transit_marker",
			"queue_size": NPCQueueReservationControllerScript.size(),
			"active_queue_size": active_queue_size,
			"from": _format_vector(from_position),
			"shelf_id": String(shelf.get_shelf_id())
		})
		return []

	var graph := get_store_path_graph()
	var access_position := graph.get_shelf_access_position(shelf)
	if not access_position.is_finite():
		_record_route_probe(&"npc_transit_queue_bypass_select", {
			"reason": "invalid_access",
			"queue_size": NPCQueueReservationControllerScript.size(),
			"active_queue_size": active_queue_size,
			"chosen_bypass_marker": String(transit_marker.name),
			"from": _format_vector(from_position),
			"shelf_id": String(shelf.get_shelf_id())
		})
		return []

	var route: Array[Vector2] = []
	var current := from_position
	current = _append_orthogonal_route_leg(
		route,
		current,
		transit_marker.global_position,
		true
	)

	var shelf_quad := _get_queue_transit_shelf_quad_marker(access_position)
	if shelf_quad != null:
		current = _append_orthogonal_route_leg(
			route,
			current,
			shelf_quad.global_position,
			false
		)
	current = _append_orthogonal_route_leg(route, current, access_position, true)

	route = _dedupe_route_points(route)
	_record_route_probe(&"npc_transit_queue_bypass_select", {
		"reason": "built" if not route.is_empty() else "empty",
		"queue_size": NPCQueueReservationControllerScript.size(),
		"active_queue_size": active_queue_size,
		"chosen_bypass_marker": String(transit_marker.name),
		"chosen_bypass_position": _format_vector(transit_marker.global_position),
		"shelf_quad": String(shelf_quad.name) if shelf_quad != null else "",
		"shelf_quad_position": _format_vector(
			shelf_quad.global_position if shelf_quad != null else Vector2.INF
		),
		"from": _format_vector(from_position),
		"access": _format_vector(access_position),
		"shelf_id": String(shelf.get_shelf_id()),
		"shelf_revision": shelf.get_revision(),
		"route_points": route.size()
	})
	return route


func _get_active_shopping_queue_size(npc_node: Node) -> int:
	NPCQueueReservationControllerScript.prune_invalid()
	var count := 0
	for queued_variant in NPC.current_queue:
		if not (queued_variant is NPC):
			continue

		var queued_npc := queued_variant as NPC
		if queued_npc == npc_node:
			continue
		if not is_instance_valid(queued_npc):
			continue
		if queued_npc.is_queued_for_deletion():
			continue
		if queued_npc.current_state != NPC.State.WAIT_IN_QUEUE:
			continue

		count += 1
	return count


func _get_queue_shelf_transit_marker(queue_size: int) -> Marker2D:
	var marker_name := QUEUE_SHELF_TRANSIT_FULL
	if queue_size <= 1:
		marker_name = QUEUE_SHELF_TRANSIT_BACK1
	elif queue_size <= 3:
		marker_name = QUEUE_SHELF_TRANSIT_BACK2

	if store == null or store.store_path_markers == null:
		return null
	return store.store_path_markers.get_node_or_null(String(marker_name)) as Marker2D


func _get_queue_transit_shelf_quad_marker(access_position: Vector2) -> Marker2D:
	if store == null or store.store_path_markers == null:
		return null

	var best_marker: Marker2D = null
	var best_score := INF
	for child in store.store_path_markers.get_children():
		var marker := child as Marker2D
		if marker == null:
			continue
		if not String(marker.name).begins_with(SHELF_QUAD_MARKER_PREFIX):
			continue

		var below_score := 0.0
		if marker.global_position.y < access_position.y + 24.0:
			below_score = 10000.0

		var score := (
			below_score
			+ absf(marker.global_position.x - access_position.x)
			+ absf(marker.global_position.y - access_position.y) * 0.25
		)
		if score >= best_score:
			continue

		best_marker = marker
		best_score = score

	if best_marker != null:
		return best_marker
	return _get_nearest_shelf_quad_marker(access_position)


func _get_queue_slot_marker(queue_index: int) -> Marker2D:
	var marker_names: Array[StringName] = [
		&"StorePathQueueFront",
		&"StorePathQueueBack1",
		&"StorePathQueueBack2"
	]
	var marker_index := clampi(queue_index, 0, marker_names.size() - 1)
	var marker_name := marker_names[marker_index]
	if store == null or store.store_path_markers == null:
		return null
	return store.store_path_markers.get_node_or_null(String(marker_name)) as Marker2D


func _get_cashier_axis_horizontal_first(shelf_quad: Marker2D) -> bool:
	if shelf_quad == null:
		return true

	var cashier_marker := _get_named_marker(&"StorePathCashier")
	if cashier_marker == null:
		return true

	return shelf_quad.global_position.y > cashier_marker.global_position.y + 24.0


func _get_checkout_route_start_index(
	from_position: Vector2,
	route_markers: Array[Marker2D]
) -> int:
	var final_marker: Marker2D = route_markers.back()
	if from_position.y >= final_marker.global_position.y - 4.0:
		return route_markers.size()

	var nearest_index = -1
	var nearest_distance = INF
	for index in range(route_markers.size()):
		var distance = from_position.distance_to(
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


func _dedupe_route_points(route: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point in route:
		_append_unique_route_point(result, point)
	return result


func _append_orthogonal_route_leg(
	route: Array[Vector2],
	from_position: Vector2,
	to_position: Vector2,
	horizontal_first: bool = true
) -> Vector2:
	if not to_position.is_finite():
		return from_position

	if not from_position.is_finite():
		_append_unique_route_point(route, to_position)
		return to_position

	if from_position.distance_to(to_position) <= 2.0:
		_append_unique_route_point(route, to_position)
		return to_position

	if (
		absf(from_position.x - to_position.x) > 0.5
		and absf(from_position.y - to_position.y) > 0.5
	):
		var intermediate := (
			Vector2(to_position.x, from_position.y)
			if horizontal_first
			else Vector2(from_position.x, to_position.y)
		)
		_append_unique_route_point(route, intermediate)

	_append_unique_route_point(route, to_position)
	return to_position


func _record_route_probe(label: StringName, context: Dictionary) -> void:
	StoreRuntimeDebugProbeScript.record(label, 0.0, context, 0.0)


func _format_vector(value: Vector2) -> String:
	return "%.1f,%.1f" % [value.x, value.y]
