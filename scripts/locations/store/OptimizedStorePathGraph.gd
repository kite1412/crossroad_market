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
	_append_fast_live_access_routes(
		candidates,
		from_position,
		access_position,
		shelf,
		npc_node
	)
	_append_fast_marker_access_routes(
		candidates,
		from_position,
		access_position,
		shelf_graph_node,
		shelf,
		npc_node
	)

	return _get_shortest_route(candidates)


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
	var aisle_node: StringName = _nav.get_role_node_name(
		&"aisle_right",
		AISLE_RIGHT
	)
	if aisle_node != StringName():
		marker_nodes.append(aisle_node)
	if shelf_graph_node != StringName() and shelf_graph_node not in marker_nodes:
		marker_nodes.append(shelf_graph_node)

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


func _find_fast_vertical_shelf_access(
	shelf_position: Vector2,
	shelf_object: Node2D
) -> Dictionary:
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
			"checkout_source": &"fast_direct"
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
