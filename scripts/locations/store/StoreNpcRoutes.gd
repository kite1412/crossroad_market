class_name StoreNpcRoutes
extends Node

const OptimizedStorePathGraphScript = preload(
	"res://scripts/locations/store/OptimizedStorePathGraph.gd"
)
const StoreRuntimeDebugProbeScript = preload("res://scripts/debug/StoreRuntimeDebugProbe.gd")
const NPCQueueReservationControllerScript = preload("res://scripts/npc/runtime/NPCQueueReservationController.gd")
const STORE_ENTRY_FALLBACK_POSITION = Vector2(240, 204)
const QUEUE_SHELF_TRANSIT_FRONT: StringName = &"StorePathQueueFront"
const QUEUE_SHELF_TRANSIT_BACK1: StringName = &"StorePathQueueBack1"
const QUEUE_SHELF_TRANSIT_BACK2: StringName = &"StorePathQueueBack2"
const QUEUE_SHELF_TRANSIT_FULL: StringName = &"StorepathParsenpc"
const QUEUE_SHELF_TRANSIT_MARKERS: Array[StringName] = [
	QUEUE_SHELF_TRANSIT_FRONT,
	QUEUE_SHELF_TRANSIT_BACK1,
	QUEUE_SHELF_TRANSIT_BACK2
]
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
const CHECKOUT_EXIT_SAFE_START_MARKER: StringName = &"StorePathQueueFront"
const CHECKOUT_GRAPH_REJOIN_MARKER: StringName = &"StorePathAisleRight"
const CHECKOUT_ROUTE_RESUME_DISTANCE: float = 18.0
const CHECKOUT_EXIT_BLOCK_DISTANCE: float = 22.0
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
	var safe_start_marker := _get_named_marker(CHECKOUT_EXIT_SAFE_START_MARKER)
	var used_safe_start := false
	if start_index == 0 and safe_start_marker != null:
		current = _append_orthogonal_route_leg(
			route,
			current,
			safe_start_marker.global_position,
			false
		)
		used_safe_start = true
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

	_record_route_probe(&"npc_checkout_exit_route_plan", {
		"from": _format_vector(from_position),
		"exit": _format_vector(exit_position),
		"start_index": start_index,
		"mandatory_markers": _format_marker_names(mandatory_markers),
		"safe_start_marker": (
			String(safe_start_marker.name)
			if safe_start_marker != null
			else ""
		),
		"safe_start_position": _format_vector(
			safe_start_marker.global_position
			if safe_start_marker != null
			else Vector2.INF
		),
		"used_safe_start": used_safe_start,
		"rejoin_marker": String(rejoin_marker.name),
		"rejoin_position": _format_vector(rejoin_marker.global_position),
		"route_points": route.size(),
		"first_point": _format_vector(route[0] if not route.is_empty() else Vector2.INF),
		"second_point": _format_vector(route[1] if route.size() > 1 else Vector2.INF),
		"first_segment_from": _format_vector(from_position),
		"first_segment_to": _format_vector(route[0] if not route.is_empty() else Vector2.INF),
		"graph_tail_points": graph_route.size()
	})
	_record_route_probe(&"npc_exit_route_select", {
		"reason": "checkout_right_lane",
		"from": _format_vector(from_position),
		"exit": _format_vector(exit_position),
		"route_points": route.size(),
		"graph_tail_points": graph_route.size()
	})
	return route


func _format_marker_names(markers: Array[Marker2D]) -> String:
	var names: Array[String] = []
	for marker in markers:
		if marker == null:
			continue
		names.append(String(marker.name))
	return ",".join(names)


func get_npc_checkout_exit_blocking_context(
	waiting_npc: Node,
	queue_index: int
) -> Dictionary:
	var lane_markers := _get_named_markers(CHECKOUT_RIGHT_ROUTE_MARKERS)
	var cashier_marker := _get_named_marker(&"StorePathCashier")
	if cashier_marker != null:
		lane_markers.push_front(cashier_marker)

	if lane_markers.is_empty():
		return {"blocked": false, "reason": "missing_lane_markers"}

	var route_points: Array[Vector2] = []
	for marker in lane_markers:
		route_points.append(marker.global_position)

	var tree := store.get_tree() if store != null else null
	if tree == null:
		return {"blocked": false, "reason": "missing_tree"}

	for node in tree.get_nodes_in_group("npcs"):
		var other := node as NPC
		if other == null:
			continue
		if other == waiting_npc:
			continue
		if not is_instance_valid(other) or other.is_queued_for_deletion():
			continue
		if other.current_state != NPC.State.EXIT:
			continue
		if not other._exit_after_checkout:
			continue

		var nearest_marker := ""
		var nearest_distance := INF
		for index in range(route_points.size()):
			var distance := other.global_position.distance_to(route_points[index])
			if distance >= nearest_distance:
				continue
			nearest_distance = distance
			nearest_marker = String(lane_markers[index].name)

		if nearest_distance > CHECKOUT_EXIT_BLOCK_DISTANCE:
			continue

		return {
			"blocked": true,
			"reason": "checkout_exit_lane_occupied",
			"queue_index": queue_index,
			"blocker_id": other.get_instance_id(),
			"blocker_state": int(other.current_state),
			"blocker_position": _format_vector(other.global_position),
			"nearest_marker": nearest_marker,
			"nearest_marker_distance": snappedf(nearest_distance, 0.01)
		}

	return {"blocked": false, "reason": "clear"}


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
		# The placement surface is static for the lifetime of Store.tscn. Install
		# its points once with the graph instead of rebuilding/comparing the same
		# array on every NPC shelf and route query.
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

	var graph := get_store_path_graph()
	var access_position := graph.get_shelf_access_position(shelf)
	if not access_position.is_finite():
		_record_route_probe(&"npc_transit_queue_bypass_select", {
			"reason": "invalid_access",
			"queue_size": NPCQueueReservationControllerScript.size(),
			"active_queue_size": active_queue_size,
			"from": _format_vector(from_position),
			"shelf_id": String(shelf.get_shelf_id())
		})
		return []

	var shelf_quad := _get_queue_transit_shelf_quad_marker(access_position)
	if not _is_right_side_shelf_access(access_position, shelf_quad):
		_record_route_probe(&"npc_shelf_transit_bridge_selected", {
			"reason": "left_or_center_shelf_uses_normal_route",
			"queue_size": NPCQueueReservationControllerScript.size(),
			"active_queue_size": active_queue_size,
			"from": _format_vector(from_position),
			"access": _format_vector(access_position),
			"shelf_quad": String(shelf_quad.name) if shelf_quad != null else "",
			"shelf_id": String(shelf.get_shelf_id()),
			"shelf_revision": shelf.get_revision()
		})
		return []

	var bridge_result := _get_available_queue_shelf_transit_marker(npc_node)
	var transit_marker := bridge_result.get("marker", null) as Marker2D
	if transit_marker == null:
		_record_route_probe(&"npc_shelf_transit_bridge_selected", {
			"reason": "missing_transit_marker",
			"queue_size": NPCQueueReservationControllerScript.size(),
			"active_queue_size": active_queue_size,
			"occupied_slots": str(bridge_result.get("occupied_slots", "")),
			"from": _format_vector(from_position),
			"access": _format_vector(access_position),
			"shelf_quad": String(shelf_quad.name) if shelf_quad != null else "",
			"shelf_id": String(shelf.get_shelf_id()),
			"shelf_revision": shelf.get_revision()
		})
		return []

	var candidates: Array[Dictionary] = []
	if shelf_quad != null:
		var transit_route := _build_shelf_access_candidate_route(
			from_position,
			[transit_marker.global_position],
			shelf_quad,
			access_position
		)
		_append_shelf_transit_candidate(
			candidates,
			&"queue_bridge_to_shelf_quad",
			transit_route,
			from_position,
			-12.0,
			{
				"bridge_marker": String(transit_marker.name),
				"bridge_position": _format_vector(
					transit_marker.global_position
				),
				"bridge_reason": str(bridge_result.get("reason", "")),
				"occupied_slots": str(bridge_result.get("occupied_slots", "")),
				"shelf_quad": String(shelf_quad.name),
				"shelf_quad_position": _format_vector(shelf_quad.global_position)
			}
		)

	var transit_only_route := _build_shelf_access_candidate_route(
		from_position,
		[transit_marker.global_position],
		null,
		access_position
	)
	_append_shelf_transit_candidate(
		candidates,
		&"queue_bridge_to_access",
		transit_only_route,
		from_position,
		6.0,
		{
			"bridge_marker": String(transit_marker.name),
			"bridge_position": _format_vector(transit_marker.global_position),
			"bridge_reason": str(bridge_result.get("reason", "")),
			"occupied_slots": str(bridge_result.get("occupied_slots", ""))
		}
	)

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", INF)) < float(b.get("score", INF))
	)
	var selected: Dictionary = candidates.front() if not candidates.is_empty() else {}
	var route: Array[Vector2] = selected.get("route", []) as Array[Vector2]
	_record_route_probe(&"npc_shelf_transit_bridge_selected", {
		"reason": "built" if not route.is_empty() else "empty",
		"queue_size": NPCQueueReservationControllerScript.size(),
		"active_queue_size": active_queue_size,
		"selected_kind": StringName(str(selected.get("kind", &""))),
		"selected_score": snappedf(float(selected.get("score", 0.0)), 0.01),
		"bridge_marker": String(transit_marker.name),
		"bridge_position": _format_vector(transit_marker.global_position),
		"bridge_reason": str(bridge_result.get("reason", "")),
		"occupied_slots": str(bridge_result.get("occupied_slots", "")),
		"shelf_quad": String(shelf_quad.name) if shelf_quad != null else "",
		"shelf_quad_position": _format_vector(
			shelf_quad.global_position if shelf_quad != null else Vector2.INF
		),
		"from": _format_vector(from_position),
		"access": _format_vector(access_position),
		"shelf_id": String(shelf.get_shelf_id()),
		"shelf_revision": shelf.get_revision(),
		"candidate_count": candidates.size(),
		"route_points": route.size()
	})
	return route


func _build_shelf_access_candidate_route(
	from_position: Vector2,
	via_points: Array[Vector2],
	shelf_quad: Marker2D,
	access_position: Vector2
) -> Array[Vector2]:
	var route: Array[Vector2] = []
	var current := from_position
	for via_point in via_points:
		current = _append_orthogonal_route_leg(route, current, via_point, true)

	if shelf_quad != null:
		current = _append_orthogonal_route_leg(
			route,
			current,
			shelf_quad.global_position,
			false
		)

	_append_orthogonal_route_leg(route, current, access_position, true)
	return _dedupe_route_points(route)


func _append_shelf_transit_candidate(
	candidates: Array[Dictionary],
	kind: StringName,
	route: Array[Vector2],
	from_position: Vector2,
	score_bias: float,
	context: Dictionary
) -> void:
	if route.is_empty():
		context["kind"] = String(kind)
		context["reason"] = "empty"
		_record_route_probe(&"npc_transit_queue_candidate", context)
		return

	var route_distance := _get_route_distance(from_position, route)
	var score := route_distance + score_bias
	context["kind"] = String(kind)
	context["reason"] = "accepted"
	context["route_points"] = route.size()
	context["route_distance"] = snappedf(route_distance, 0.01)
	context["score"] = snappedf(score, 0.01)
	_record_route_probe(&"npc_transit_queue_candidate", context)
	candidates.append({
		"kind": kind,
		"route": route,
		"score": score
	})


func _get_route_distance(from_position: Vector2, route: Array[Vector2]) -> float:
	var distance := 0.0
	var previous := from_position
	for point in route:
		if previous.is_finite():
			distance += previous.distance_to(point)
		previous = point
	return distance


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


func _get_available_queue_shelf_transit_marker(npc_node: Node) -> Dictionary:
	var occupied_slots := _get_occupied_normal_queue_transit_slots(npc_node)
	for marker_name in QUEUE_SHELF_TRANSIT_MARKERS:
		if bool(occupied_slots.get(marker_name, false)):
			continue

		var marker := _get_named_marker(marker_name)
		if marker == null:
			continue

		return {
			"marker": marker,
			"reason": "normal_queue_slot_available",
			"occupied_slots": _format_queue_transit_occupancy(occupied_slots)
		}

	var fallback_marker := _get_named_marker(QUEUE_SHELF_TRANSIT_FULL)
	return {
		"marker": fallback_marker,
		"reason": "normal_queue_slots_full",
		"occupied_slots": _format_queue_transit_occupancy(occupied_slots)
	}


func _get_occupied_normal_queue_transit_slots(npc_node: Node) -> Dictionary:
	var occupied: Dictionary = {}
	for marker_name in QUEUE_SHELF_TRANSIT_MARKERS:
		occupied[marker_name] = false

	NPCQueueReservationControllerScript.prune_invalid()
	for queue_index in range(NPC.current_queue.size()):
		var queued_variant: Variant = NPC.current_queue[queue_index]
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
		if _queued_npc_is_at_checkout(queued_npc):
			continue

		var occupied_marker_name := _get_nearest_occupied_queue_transit_slot(
			queued_npc
		)
		if occupied_marker_name == StringName():
			occupied_marker_name = _get_queue_transit_slot_name_for_index(
				queue_index
			)
		if occupied_marker_name == StringName():
			continue
		occupied[occupied_marker_name] = true

	return occupied


func _queued_npc_is_at_checkout(queued_npc: NPC) -> bool:
	if queued_npc._is_moving_from_queue_to_cashier:
		return true

	var cashier_marker := _get_named_marker(&"StorePathCashier")
	if cashier_marker == null:
		return false

	return queued_npc.global_position.distance_to(cashier_marker.global_position) <= (
		CHECKOUT_EXIT_BLOCK_DISTANCE
	)


func _get_queue_transit_slot_name_for_index(queue_index: int) -> StringName:
	if QUEUE_SHELF_TRANSIT_MARKERS.is_empty():
		return StringName()
	var marker_index := clampi(
		queue_index,
		0,
		QUEUE_SHELF_TRANSIT_MARKERS.size() - 1
	)
	return QUEUE_SHELF_TRANSIT_MARKERS[marker_index]


func _get_nearest_occupied_queue_transit_slot(queued_npc: NPC) -> StringName:
	var best_marker_name := StringName()
	var best_distance := INF
	for marker_name in QUEUE_SHELF_TRANSIT_MARKERS:
		var marker := _get_named_marker(marker_name)
		if marker == null:
			continue

		var position_distance := queued_npc.global_position.distance_to(
			marker.global_position
		)
		var target_distance := INF
		if queued_npc.target_position.is_finite():
			target_distance = queued_npc.target_position.distance_to(
				marker.global_position
			)
		var distance := minf(position_distance, target_distance)
		if distance >= best_distance:
			continue

		best_marker_name = marker_name
		best_distance = distance

	if best_distance > CHECKOUT_EXIT_BLOCK_DISTANCE:
		return StringName()
	return best_marker_name


func _format_queue_transit_occupancy(occupied_slots: Dictionary) -> String:
	var parts: Array[String] = []
	for marker_name in QUEUE_SHELF_TRANSIT_MARKERS:
		parts.append(
			"%s=%s" % [
				String(marker_name),
				"1" if bool(occupied_slots.get(marker_name, false)) else "0"
			]
		)
	return ",".join(parts)


func _is_right_side_shelf_access(
	access_position: Vector2,
	shelf_quad: Marker2D
) -> bool:
	if shelf_quad != null:
		var quad_name := String(shelf_quad.name)
		if quad_name.ends_with("NE") or quad_name.ends_with("SE"):
			return true
		if quad_name.ends_with("NW") or quad_name.ends_with("SW"):
			return false

	var queue_front := _get_named_marker(QUEUE_SHELF_TRANSIT_FRONT)
	if queue_front != null:
		return access_position.x > queue_front.global_position.x + 32.0

	return access_position.x > STORE_ENTRY_FALLBACK_POSITION.x + 32.0


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
