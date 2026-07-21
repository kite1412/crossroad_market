class_name OptimizedStorePathGraph
extends StorePathGraph

## StorePathGraph variant used by the Store runtime.
##
## The original route goals remain intact: direct, orthogonal, marker A*, and
## surface-grid routes are still available. Only the expensive metadata pass
## immediately after shelf placement is bounded; live NPC route selection keeps
## the complete StorePathGraph behavior.

const PLACEMENT_ACCESS_CANDIDATE_LIMIT: int = 8
const PLACEMENT_GRAPH_NODE_LIMIT: int = 8
const PLACEMENT_SURFACE_NODE_LIMIT: int = 2
const FAST_PLACEMENT_GRAPH_NODE_LIMIT: int = 8
const LIVE_ACCESS_GRAPH_NODE_LIMIT: int = 8
const LIVE_ACCESS_SHELF_ANCHOR_LIMIT: int = 2
const SHELF_ENTRY_BLOCKER_META: StringName = &"store_path_blocks_shelf_entry"
const SHELF_ENTRY_BLOCKER_RADIUS_META: StringName = &"store_path_shelf_entry_block_radius"
const DEFAULT_SHELF_ENTRY_BLOCKER_RADIUS: float = 22.0
const StoreRuntimeDebugProbeScript = preload("res://scripts/debug/StoreRuntimeDebugProbe.gd")


func set_shelf_access_points(points: Array[Vector2]) -> void:
	# StoreNpcRoutes asks for the graph on many NPC/state calls. Avoid rebuilding
	# signatures and invalidating the surface cache when the placement grid is
	# exactly the same as the one already installed.
	if points.size() == _shelf_access_points.size() and points == _shelf_access_points:
		return

	super.set_shelf_access_points(points)


func store_shelf_access_metadata(
	object: Node2D,
	drop_position: Vector2
) -> void:
	if object == null or not is_instance_valid(object):
		return

	var access_result := _find_fast_vertical_shelf_access(
		drop_position,
		object
	)

	if not bool(access_result.get("valid", false)):
		clear_shelf_access_metadata(object)
		return

	_store_access_metadata_from_result(object, access_result)


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
	_append_fast_marker_access_routes(
		candidates,
		from_position,
		access_position,
		shelf_graph_node,
		shelf,
		npc_node
	)
	if candidates.is_empty():
		_append_shelf_quad_access_fallback_routes(
			candidates,
			from_position,
			access_position,
			shelf,
			npc_node
		)

	var result := _get_shortest_route(candidates)
	if result.is_empty():
		_record_path_graph_probe(&"npc_shelf_access_route_empty", {
			"from": _format_vector(from_position),
			"access": _format_vector(access_position),
			"shelf_id": String(shelf.get_shelf_id()),
			"shelf_revision": shelf.get_revision(),
			"shelf_graph_node": String(shelf_graph_node),
			"candidate_count": candidates.size()
		})

	return result


func get_shelf_egress_route_to_queue_from(
	shelf: Shelf,
	from_position: Vector2,
	queue_index: int,
	destination: Vector2,
	npc_node: Node = null
) -> Array[Vector2]:
	if shelf == null or not is_instance_valid(shelf):
		return []
	if not from_position.is_finite():
		return []

	var access_position := get_shelf_access_position(shelf)
	if not access_position.is_finite():
		return []

	var anchor_nodes := _get_ranked_shelf_anchor_nodes(access_position)
	if anchor_nodes.is_empty():
		return []

	var candidates: Array[Dictionary] = []
	var rejected_candidates := 0
	for anchor_node in anchor_nodes:
		var anchor_position: Vector2 = _nav.get_marker_position(anchor_node)
		if not anchor_position.is_finite():
			continue

		var queue_route := _get_anchor_route_to_queue_egress(
			anchor_position,
			queue_index,
			destination
		)
		if queue_route.is_empty():
			var queue_egress_target := get_queue_egress_target_position(
				queue_index,
				destination
			)
			if not queue_egress_target.is_finite():
				queue_egress_target = destination
			if not queue_egress_target.is_finite():
				continue
			queue_route = _routes.make_orthogonal_route(
				anchor_position,
				queue_egress_target,
				true
			)

		for horizontal_first in [true, false]:
			var direct_anchor_route: Array[Vector2] = _routes.make_orthogonal_route(
				from_position,
				anchor_position,
				horizontal_first
			)
			direct_anchor_route.append_array(queue_route)
			direct_anchor_route = _routes.dedupe_route_points(direct_anchor_route)
			if _clearance.is_queue_route_clear_from_current_position(
				from_position,
				direct_anchor_route
			):
				_append_route_candidate(
					candidates,
					from_position,
					direct_anchor_route
				)
			else:
				rejected_candidates += 1

		for first_leg_horizontal in [true, false]:
			var first_leg: Array[Vector2] = _routes.make_orthogonal_route(
				from_position,
				access_position,
				first_leg_horizontal
			)
			for second_leg_horizontal in [true, false]:
				var candidate_route: Array[Vector2] = first_leg.duplicate()
				candidate_route.append_array(
					_routes.make_orthogonal_route(
						access_position,
						anchor_position,
						second_leg_horizontal
					)
				)
				candidate_route.append_array(queue_route)
				candidate_route = _routes.dedupe_route_points(candidate_route)
				if _clearance.is_queue_route_clear_from_current_position(
					from_position,
					candidate_route
				):
					_append_route_candidate(candidates, from_position, candidate_route)
				else:
					rejected_candidates += 1

	var route := _get_shortest_route(candidates)
	_record_path_graph_probe(&"npc_shelf_egress_anchor_select", {
		"from": _format_vector(from_position),
		"access": _format_vector(access_position),
		"queue_index": queue_index,
		"destination": _format_vector(destination),
		"anchor_count": anchor_nodes.size(),
		"candidate_count": candidates.size(),
		"rejected_candidates": rejected_candidates,
		"route_points": route.size()
	})
	return route


func _get_anchor_route_to_queue_target(
	anchor_position: Vector2,
	queue_index: int,
	destination: Vector2
) -> Array[Vector2]:
	if not anchor_position.is_finite():
		return []

	var approach_node := _nav.get_queue_approach_node_name(queue_index)
	var target_node := _nav.get_queue_target_node_name(queue_index)
	var approach_position := _nav.get_marker_position(approach_node)
	var target_position := _nav.get_marker_position(target_node)
	if not target_position.is_finite():
		target_position = get_queue_target_position(queue_index, destination)
	if not target_position.is_finite():
		target_position = destination
	if not target_position.is_finite():
		return []

	var candidates: Array[Dictionary] = []
	if approach_position.is_finite():
		for horizontal_first in [false, true]:
			var route: Array[Vector2] = _build_route_leg(
				anchor_position,
				approach_position,
				null,
				Vector2.INF,
				null,
				horizontal_first
			)
			var route_to_target := route.duplicate()
			if (
				target_position.is_finite()
				and approach_position.distance_to(target_position)
				> MARKER_ALIGNMENT_EPSILON
			):
				route_to_target.append_array(
					_routes.make_orthogonal_route(
						approach_position,
						target_position,
						true
					)
				)
			route_to_target = _routes.dedupe_route_points(route_to_target)
			if _clearance.is_queue_route_clear(anchor_position, route_to_target):
				_append_route_candidate(candidates, anchor_position, route)

	if candidates.is_empty():
		var graph_route := get_route_to_queue_target_from(
			anchor_position,
			queue_index
		)
		if not graph_route.is_empty():
			_append_route_candidate(candidates, anchor_position, graph_route)

	for horizontal_first in [true, false]:
		_append_route_candidate(
			candidates,
			anchor_position,
			_routes.make_orthogonal_route(
				anchor_position,
				target_position,
				horizontal_first
			)
		)

	return _get_shortest_route(candidates)


func _get_anchor_route_to_queue_egress(
	anchor_position: Vector2,
	queue_index: int,
	destination: Vector2
) -> Array[Vector2]:
	if not anchor_position.is_finite():
		return []

	var approach_node := _nav.get_queue_approach_node_name(queue_index)
	var approach_position := _nav.get_marker_position(approach_node)
	if not approach_position.is_finite():
		approach_position = get_queue_egress_target_position(
			queue_index,
			destination
		)
	if not approach_position.is_finite():
		return []

	var candidates: Array[Dictionary] = []
	for horizontal_first in [true, false]:
		var route: Array[Vector2] = _routes.make_orthogonal_route(
			anchor_position,
			approach_position,
			horizontal_first
		)
		if route.is_empty():
			route.append(approach_position)
		route = _routes.dedupe_route_points(route)
		if _clearance.is_queue_route_clear(anchor_position, route):
			_append_route_candidate(candidates, anchor_position, route)

	var result := _get_shortest_route(candidates)
	_record_path_graph_probe(&"npc_queue_egress_anchor_route", {
		"queue_index": queue_index,
		"anchor": _format_vector(anchor_position),
		"approach": _format_vector(approach_position),
		"destination": _format_vector(destination),
		"candidate_count": candidates.size(),
		"route_points": result.size()
	})
	return result


func get_queue_egress_target_position(
	queue_index: int,
	fallback_position: Vector2
) -> Vector2:
	var approach_node := _nav.get_queue_approach_node_name(queue_index)
	var approach_position := _nav.get_marker_position(approach_node)
	if approach_position.is_finite():
		return approach_position
	return get_queue_target_position(queue_index, fallback_position)


func _build_route_leg(
	from_position: Vector2,
	to_position: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null,
	horizontal_first: bool = true
) -> Array[Vector2]:
	if not from_position.is_finite() or not to_position.is_finite():
		return []

	var grid_result: Dictionary = _grid.find_route(
		from_position,
		to_position,
		shelf_object,
		shelf_position,
		npc_node
	)
	if bool(grid_result.get("valid", false)):
		var grid_route := _variant_route_to_vector2_array(
			grid_result.get("route", [])
		)
		if not grid_route.is_empty():
			return grid_route

	return _routes.make_orthogonal_route(
		from_position,
		to_position,
		horizontal_first
	)


func _append_fast_live_access_routes(
	candidates: Array[Dictionary],
	from_position: Vector2,
	access_position: Vector2,
	shelf: Shelf,
	npc_node: Node
) -> void:
	for horizontal_first in [true, false]:
		var route: Array[Vector2] = _routes.make_orthogonal_route(
			from_position,
			access_position,
			horizontal_first
		)
		if _clearance.is_route_to_access_clear(
			from_position,
			route,
			shelf,
			npc_node
		):
			_append_route_candidate(candidates, from_position, route)


func _append_fast_marker_access_routes(
	candidates: Array[Dictionary],
	from_position: Vector2,
	access_position: Vector2,
	shelf_graph_node: StringName,
	shelf: Shelf,
	npc_node: Node
) -> void:
	var marker_nodes: Array[StringName] = []
	_append_nearest_shelf_anchor_nodes(marker_nodes, access_position)
	var has_shelf_anchor := not marker_nodes.is_empty()
	var aisle_node: StringName = _nav.get_role_node_name(
		&"aisle_right",
		AISLE_RIGHT
	)
	if (
		not has_shelf_anchor
		and shelf_graph_node != StringName()
		and shelf_graph_node not in marker_nodes
	):
		marker_nodes.append(shelf_graph_node)
	if (
		not has_shelf_anchor
		and aisle_node != StringName()
		and aisle_node not in marker_nodes
	):
		marker_nodes.append(aisle_node)

	for marker_node in marker_nodes:
		var marker_position: Vector2 = _nav.get_marker_position(marker_node)
		if not marker_position.is_finite():
			continue

		for first_leg_horizontal in [true, false]:
			var route: Array[Vector2] = _routes.make_orthogonal_route(
				from_position,
				marker_position,
				first_leg_horizontal
			)
			for second_leg_horizontal in [true, false]:
				var candidate_route: Array[Vector2] = route.duplicate()
				candidate_route.append_array(
					_routes.make_orthogonal_route(
						marker_position,
						access_position,
						second_leg_horizontal
					)
				)
				candidate_route = _routes.dedupe_route_points(candidate_route)
				if not _is_shelf_entry_route_allowed(
					from_position,
					candidate_route
				):
					continue
				if _clearance.is_route_to_access_clear(
					from_position,
					candidate_route,
					shelf,
					npc_node
				):
					_append_route_candidate(
						candidates,
						from_position,
						candidate_route
					)


func _append_shelf_quad_access_fallback_routes(
	candidates: Array[Dictionary],
	from_position: Vector2,
	access_position: Vector2,
	shelf: Shelf,
	npc_node: Node
) -> void:
	var quad_marker := _get_nearest_shelf_quad_marker(access_position)
	if quad_marker == null:
		_record_path_graph_probe(&"npc_shelf_access_route_fallback", {
			"reason": "missing_shelf_quad",
			"from": _format_vector(from_position),
			"access": _format_vector(access_position)
		})
		return

	var before_count := candidates.size()
	for first_leg_horizontal in [false, true]:
		var route: Array[Vector2] = _routes.make_orthogonal_route(
			from_position,
			quad_marker.global_position,
			first_leg_horizontal
		)
		for second_leg_horizontal in [false, true]:
			var candidate_route: Array[Vector2] = route.duplicate()
			candidate_route.append_array(
				_routes.make_orthogonal_route(
					quad_marker.global_position,
					access_position,
					second_leg_horizontal
				)
			)
			candidate_route = _routes.dedupe_route_points(candidate_route)
			if not _is_shelf_entry_route_allowed(from_position, candidate_route):
				continue
			if _clearance.is_route_to_access_clear(
				from_position,
				candidate_route,
				shelf,
				npc_node
			):
				_append_route_candidate(
					candidates,
					from_position,
					candidate_route
				)

	_record_path_graph_probe(&"npc_shelf_access_route_fallback", {
		"reason": "built",
		"from": _format_vector(from_position),
		"access": _format_vector(access_position),
		"shelf_quad": String(quad_marker.name),
		"shelf_quad_position": _format_vector(quad_marker.global_position),
		"added_candidates": candidates.size() - before_count
	})


func _get_nearest_shelf_quad_marker(from_position: Vector2) -> Marker2D:
	if _markers == null:
		return null

	var best_marker: Marker2D = null
	var best_distance := INF
	for child in _markers.get_children():
		var marker := child as Marker2D
		if marker == null:
			continue
		if not String(marker.name).begins_with("StorePathShelfQuad"):
			continue

		var distance := from_position.distance_to(marker.global_position)
		if distance >= best_distance:
			continue

		best_marker = marker
		best_distance = distance

	return best_marker


func _append_nearest_shelf_anchor_nodes(
	marker_nodes: Array[StringName],
	access_position: Vector2
) -> void:
	var anchor_nodes: Array[Dictionary] = []
	for node_name in _nav.get_graph_node_names():
		var marker: Marker2D = _nav.get_graph_marker(node_name)
		if marker == null:
			continue
		if not bool(marker.get_meta(SHELF_ANCHOR_META, false)):
			continue

		anchor_nodes.append({
			"node": node_name,
			"distance": marker.global_position.distance_to(access_position)
		})

	anchor_nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", INF)) < float(b.get("distance", INF))
	)

	var appended_count := 0
	for anchor_entry in anchor_nodes:
		if appended_count >= LIVE_ACCESS_SHELF_ANCHOR_LIMIT:
			return

		var node_name := anchor_entry.get("node", StringName()) as StringName
		if node_name == StringName() or node_name in marker_nodes:
			continue

		marker_nodes.append(node_name)
		appended_count += 1


func _get_nearest_shelf_anchor_node(access_position: Vector2) -> StringName:
	var marker_nodes: Array[StringName] = []
	_append_nearest_shelf_anchor_nodes(marker_nodes, access_position)
	if marker_nodes.is_empty():
		return StringName()
	return marker_nodes.front()


func _get_ranked_shelf_anchor_nodes(access_position: Vector2) -> Array[StringName]:
	var ranked_nodes: Array[Dictionary] = []
	for node_name in _nav.get_graph_node_names():
		var marker: Marker2D = _nav.get_graph_marker(node_name)
		if marker == null:
			continue
		if not bool(marker.get_meta(SHELF_ANCHOR_META, false)):
			continue

		ranked_nodes.append({
			"node": node_name,
			"distance": marker.global_position.distance_to(access_position)
		})

	ranked_nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", INF)) < float(b.get("distance", INF))
	)

	var result: Array[StringName] = []
	for entry in ranked_nodes:
		var node_name := entry.get("node", StringName()) as StringName
		if node_name != StringName():
			result.append(node_name)

	return result


func _is_shelf_entry_route_allowed(
	from_position: Vector2,
	route: Array[Vector2]
) -> bool:
	if _markers == null:
		return true

	var current := from_position
	for target in route:
		if not _is_shelf_entry_segment_allowed(current, target):
			return false
		current = target

	return true


func _is_shelf_entry_segment_allowed(
	from_position: Vector2,
	to_position: Vector2
) -> bool:
	if from_position.distance_to(to_position) <= MARKER_ALIGNMENT_EPSILON:
		return true

	for child in _markers.get_children():
		var marker := child as Marker2D
		if marker == null:
			continue
		if not bool(marker.get_meta(SHELF_ENTRY_BLOCKER_META, false)):
			continue

		var marker_position := marker.global_position
		var block_radius := float(marker.get_meta(
			SHELF_ENTRY_BLOCKER_RADIUS_META,
			DEFAULT_SHELF_ENTRY_BLOCKER_RADIUS
		))
		if _distance_to_segment(
			marker_position,
			from_position,
			to_position
		) <= block_radius:
			return false

	return true


func _distance_to_segment(
	point: Vector2,
	segment_start: Vector2,
	segment_end: Vector2
) -> float:
	var segment := segment_end - segment_start
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return point.distance_to(segment_start)

	var progress := clampf(
		(point - segment_start).dot(segment) / length_squared,
		0.0,
		1.0
	)
	return point.distance_to(segment_start + segment * progress)


func _find_fast_vertical_shelf_access(
	shelf_position: Vector2,
	shelf_object: Node2D
) -> Dictionary:
	var marker_port_result := _find_fast_marker_port_access(
		shelf_position,
		shelf_object
	)
	if bool(marker_port_result.get("valid", false)):
		return marker_port_result

	var access_candidates := _shelf.get_shelf_access_candidates(
		shelf_position,
		true
	)
	var best_result: Dictionary = {"valid": false}
	var best_score := INF
	var checked_candidates := 0

	for access_candidate in access_candidates:
		checked_candidates += 1
		if checked_candidates > PLACEMENT_ACCESS_CANDIDATE_LIMIT:
			break

		var access_position := access_candidate.get(
			"access_point",
			Vector2.INF
		) as Vector2
		if not access_position.is_finite():
			continue

		if not _clearance.is_npc_access_point_clear(
			access_position,
			shelf_object,
			shelf_position
		):
			continue

		var connection := _find_fast_access_connection(
			access_position,
			access_candidate.get("graph_node", StringName()) as StringName,
			shelf_object,
			shelf_position
		)
		if not bool(connection.get("valid", false)):
			continue

		var graph_node := connection.get("node", StringName()) as StringName
		var score: float = (
			float(access_candidate.get("tier", 2)) * 10000.0
			+ float(access_candidate.get("vertical_distance", 0.0))
			+ float(connection.get("distance", 0.0))
			+ float(access_candidate.get("horizontal_distance", 0.0)) * 0.25
		)
		if score >= best_score:
			continue

		best_score = score
		best_result = {
			"valid": true,
			"access_point": access_position,
			"graph_node": graph_node,
			"surface_route": connection.get("route", []),
			"score": score,
			"access_side": str(access_candidate.get("access_side", "")),
			"access_source": str(access_candidate.get("access_source", "")),
			"port_id": str(access_candidate.get("port_id", "")),
			"checkout_source": &"fast_direct"
		}

	return best_result


func _record_path_graph_probe(
	label: StringName,
	context: Dictionary
) -> void:
	StoreRuntimeDebugProbeScript.record(label, 0.0, context, 0.0)


func _format_vector(value: Vector2) -> String:
	if not value.is_finite():
		return "inf,inf"
	return "%.1f,%.1f" % [value.x, value.y]


func _find_fast_marker_port_access(
	shelf_position: Vector2,
	shelf_object: Node2D
) -> Dictionary:
	var shelf := shelf_object as Shelf
	if shelf == null or not is_instance_valid(shelf):
		return {"valid": false}

	var best_result: Dictionary = {"valid": false}
	var best_score := INF
	for port in shelf.get_interaction_ports():
		var access_position := port.get("position", Vector2.INF) as Vector2
		if not access_position.is_finite():
			continue

		var vertical_distance := absf(access_position.y - shelf_position.y)
		var horizontal_distance := absf(access_position.x - shelf_position.x)
		if horizontal_distance > SHELF_ACCESS_COLUMN_EPSILON:
			continue
		if not _clearance.is_npc_access_point_clear(
			access_position,
			shelf_object,
			shelf_position
		):
			continue

		var connection := _find_fast_access_connection(
			access_position,
			StringName(),
			shelf_object,
			shelf_position
		)
		if not bool(connection.get("valid", false)):
			continue

		var score: float = (
			vertical_distance
			+ float(connection.get("distance", 0.0))
			+ horizontal_distance * 0.25
		)
		if score >= best_score:
			continue

		best_score = score
		best_result = {
			"valid": true,
			"access_point": access_position,
			"graph_node": connection.get("node", StringName()),
			"surface_route": connection.get("route", []),
			"score": score,
			"access_side": "below" if access_position.y >= shelf_position.y else "above",
			"access_source": "marker_port",
			"port_id": str(port.get("port_id", "")),
			"checkout_source": &"fast_marker_port"
		}

	return best_result


func _find_fast_access_connection(
	access_position: Vector2,
	preferred_node: StringName,
	shelf_object: Node2D,
	shelf_position: Vector2
) -> Dictionary:
	var node_names := super._get_nearest_graph_node_names_for_access(
		access_position,
		preferred_node,
		FAST_PLACEMENT_GRAPH_NODE_LIMIT
	)
	var best_result: Dictionary = {"valid": false}
	var best_distance := INF

	for node_name in node_names:
		var graph_marker: Marker2D = _nav.get_graph_marker(node_name)
		if graph_marker == null:
			continue

		if _nav.find_checkout_graph_path(node_name).is_empty():
			continue

		for horizontal_first in [true, false]:
			var route: Array[Vector2] = _routes.make_orthogonal_route(
				graph_marker.global_position,
				access_position,
				horizontal_first
			)
			if not _clearance.is_route_clear(
				graph_marker.global_position,
				route,
				shelf_object,
				shelf_position
			):
				continue

			var distance := _routes.get_route_distance(
				graph_marker.global_position,
				route
			)
			if distance >= best_distance:
				continue

			best_distance = distance
			best_result = {
				"valid": true,
				"node": node_name,
				"route": route,
				"distance": distance
			}

	return best_result


func _find_bounded_vertical_shelf_access(
	shelf_position: Vector2,
	shelf_object: Node2D
) -> Dictionary:
	var access_candidates := _shelf.get_shelf_access_candidates(
		shelf_position,
		true
	)
	var cashier_marker: Marker2D = get_marker_for_role(ROLE_CASHIER, CASHIER)
	var cashier_position := Vector2.INF
	if cashier_marker != null:
		cashier_position = cashier_marker.global_position

	var prefer_below := false
	if cashier_position.is_finite() and shelf_position.is_finite():
		prefer_below = shelf_position.y < cashier_position.y - 4.0

	var best_result: Dictionary = {"valid": false}
	var best_score := INF
	var checked_candidates := 0

	for access_candidate in access_candidates:
		checked_candidates += 1
		if checked_candidates > PLACEMENT_ACCESS_CANDIDATE_LIMIT:
			break

		var access_position := access_candidate.get(
			"access_point",
			Vector2.INF
		) as Vector2
		if not access_position.is_finite():
			continue

		if not _clearance.is_npc_access_point_clear(
			access_position,
			shelf_object,
			shelf_position
		):
			continue

		var connection := _find_bounded_access_connection(
			access_position,
			access_candidate.get("graph_node", StringName()) as StringName,
			shelf_object,
			shelf_position
		)
		if not bool(connection.get("valid", false)):
			continue

		var graph_node := connection.get("node", StringName()) as StringName
		var checkout_path: Array[StringName] = _nav.find_checkout_graph_path(graph_node)
		if checkout_path.is_empty():
			continue

		var access_side := str(access_candidate.get("access_side", ""))
		var candidate_prefers_below := access_side == "below"
		var score: float = (
			float(access_candidate.get("vertical_distance", 0.0))
			* SHELF_ACCESS_DISTANCE_SCORE_WEIGHT
			+ float(connection.get("distance", 0.0))
			+ _nav.get_graph_path_cost(checkout_path)
			+ float(access_candidate.get("horizontal_distance", 0.0)) * 0.25
		)

		if (
			cashier_position.is_finite()
			and prefer_below != candidate_prefers_below
		):
			score += absf(
				access_position.y - cashier_position.y
			) * COUNTER_DIRECTION_PENALTY_SCALE

		if score >= best_score:
			continue

		best_score = score
		best_result = {
			"valid": true,
			"access_point": access_position,
			"graph_node": graph_node,
			"surface_route": connection.get("route", []),
			"score": score,
			"access_side": access_side,
			"checkout_source": connection.get(
				"source",
				"bounded_placement"
			)
		}

	return best_result


func _find_bounded_access_connection(
	access_position: Vector2,
	preferred_node: StringName,
	shelf_object: Node2D,
	shelf_position: Vector2
) -> Dictionary:
	# Call the parent selector directly with a placement-only limit. Live route
	# methods continue using the normal MAX_ACCESS_GRAPH_NODE_CANDIDATES value.
	var node_names := super._get_nearest_graph_node_names_for_access(
		access_position,
		preferred_node,
		PLACEMENT_GRAPH_NODE_LIMIT
	)
	var best_result: Dictionary = {"valid": false}
	var best_distance := INF

	for node_name in node_names:
		var graph_marker: Marker2D = _nav.get_graph_marker(node_name)
		if graph_marker == null:
			continue

		var route_variants: Array = []
		var grid_result := _grid.find_route(
			graph_marker.global_position,
			access_position,
			shelf_object,
			shelf_position
		)
		if bool(grid_result.get("valid", false)):
			route_variants.append(grid_result.get("route", []))
		route_variants.append(
			_routes.make_orthogonal_route(
				graph_marker.global_position,
				access_position,
				true
			)
		)
		route_variants.append(
			_routes.make_orthogonal_route(
				graph_marker.global_position,
				access_position,
				false
			)
		)

		for route_variant in route_variants:
			if not (route_variant is Array):
				continue

			var route: Array[Vector2] = []
			for point_variant in route_variant:
				if point_variant is Vector2:
					route.append(point_variant as Vector2)

			if not _clearance.is_route_clear(
				graph_marker.global_position,
				route,
				shelf_object,
				shelf_position
			):
				continue

			var distance := _routes.get_route_distance(
				graph_marker.global_position,
				route
			)
			if distance >= best_distance:
				continue

			best_distance = distance
			best_result = {
				"valid": true,
				"node": node_name,
				"route": route,
				"distance": distance,
				"source": "bounded_direct"
			}

	if bool(best_result.get("valid", false)):
		return best_result

	var surface_searches: Array = [0]
	var surface_route_cache: Dictionary = {}
	var surface_anchor_path_cache: Dictionary = {}
	var surface_count := 0

	for node_name in node_names:
		surface_count += 1
		if surface_count > PLACEMENT_SURFACE_NODE_LIMIT:
			break

		var surface_result := _surface.find_surface_route_between_marker_and_access(
			node_name,
			access_position,
			shelf_object,
			shelf_position,
			surface_searches,
			surface_route_cache,
			surface_anchor_path_cache
		)
		if not bool(surface_result.get("valid", false)):
			continue

		var surface_distance := float(surface_result.get("distance", INF))
		if surface_distance >= best_distance:
			continue

		best_distance = surface_distance
		best_result = surface_result.duplicate(true)
		best_result["source"] = "bounded_surface"

	return best_result
