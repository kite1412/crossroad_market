class_name StorePathGraph
extends "res://scripts/locations/store/StorePathGraphBase.gd"

## Shelf-access scoring and route candidate selection for StorePathGraph.


func find_best_shelf_access(
	candidate_position: Vector2,
	shelf_object: Node2D
) -> Dictionary:
	return _find_best_shelf_access(candidate_position, shelf_object, false)


func find_best_vertical_shelf_access(
	candidate_position: Vector2,
	shelf_object: Node2D
) -> Dictionary:
	return _find_best_shelf_access(candidate_position, shelf_object, true)


func _find_best_shelf_access(
	candidate_position: Vector2,
	shelf_object: Node2D,
	vertical_only: bool
) -> Dictionary:
	var candidates := _shelf.get_shelf_access_candidates(
		candidate_position,
		vertical_only
	)
	var cashier_marker: Marker2D = get_marker_for_role(ROLE_CASHIER, CASHIER)
	var cashier_position := Vector2.INF
	if cashier_marker != null:
		cashier_position = cashier_marker.global_position

	var prefer_below := false
	if cashier_position.is_finite() and candidate_position.is_finite():
		prefer_below = candidate_position.y < cashier_position.y - 4.0

	var best_result: Dictionary = {"valid": false}
	var best_score := INF
	var evaluated_count := 0
	var surface_route_cache: Dictionary = {}
	var surface_anchor_path_cache: Dictionary = {}

	for access_candidate in candidates:
		evaluated_count += 1
		if evaluated_count > MAX_SHELF_ACCESS_CANDIDATES:
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
			candidate_position
		):
			continue

		var surface_searches: Array = [0]
		var reachable_result := _find_reachable_graph_node_for_access(
			access_position,
			access_candidate.get("graph_node", StringName()) as StringName,
			shelf_object,
			candidate_position,
			surface_searches,
			surface_route_cache,
			surface_anchor_path_cache
		)
		if not bool(reachable_result.get("valid", false)):
			continue

		var reachable_graph_node := reachable_result.get(
			"node",
			StringName()
		) as StringName
		var checkout_path := _nav.find_checkout_graph_path(reachable_graph_node)
		if checkout_path.is_empty():
			continue

		var access_side := str(access_candidate.get("access_side", ""))
		var candidate_prefers_below := access_side == "below"
		var route_score := (
			float(access_candidate.get("vertical_distance", 0.0))
			* SHELF_ACCESS_DISTANCE_SCORE_WEIGHT
			+ float(reachable_result.get("distance", 0.0))
			+ _nav.get_graph_path_cost(checkout_path)
			+ float(access_candidate.get("horizontal_distance", 0.0)) * 0.25
		)

		if (
			cashier_position.is_finite()
			and prefer_below != candidate_prefers_below
		):
			route_score += absf(
				access_position.y - cashier_position.y
			) * COUNTER_DIRECTION_PENALTY_SCALE

		if route_score >= best_score:
			continue

		best_score = route_score
		best_result = {
			"valid": true,
			"access_point": access_position,
			"graph_node": reachable_graph_node,
			"surface_route": reachable_result.get("route", []),
			"score": route_score,
			"access_side": access_side,
			"checkout_source": "surface_graph"
		}

	return best_result


func store_shelf_access_metadata(
	object: Node2D,
	drop_position: Vector2
) -> void:
	var access_result := find_best_vertical_shelf_access(
		drop_position,
		object
	)
	if not bool(access_result.get("valid", false)):
		clear_shelf_access_metadata(object)
		return
	_store_access_metadata_from_result(object, access_result)


func clear_shelf_access_metadata(object: Node2D) -> void:
	if object == null:
		return

	for metadata_key in [
		ACCESS_META,
		ACCESS_NODE_META,
		ACCESS_ROUTE_META,
		ACCESS_SIDE_META,
		ACCESS_CHECKOUT_SOURCE_META
	]:
		if object.has_meta(metadata_key):
			object.remove_meta(metadata_key)

	object.set_meta("npc_path_ready", false)


func _store_access_metadata_from_result(
	object: Node2D,
	result: Dictionary
) -> void:
	if object == null or not bool(result.get("valid", false)):
		return

	object.set_meta(ACCESS_META, result.get("access_point", Vector2.INF))
	object.set_meta(ACCESS_NODE_META, result.get("graph_node", StringName()))
	object.set_meta(ACCESS_ROUTE_META, result.get("surface_route", []))
	object.set_meta(ACCESS_SIDE_META, result.get("access_side", ""))
	object.set_meta(
		ACCESS_CHECKOUT_SOURCE_META,
		result.get("checkout_source", "")
	)
	object.set_meta("npc_path_ready", true)


func get_shelf_access_graph_node(shelf: Shelf) -> StringName:
	if shelf == null:
		return StringName()

	if shelf.has_meta(ACCESS_NODE_META):
		var stored_graph_node: Variant = shelf.get_meta(ACCESS_NODE_META)
		if stored_graph_node is StringName:
			return stored_graph_node as StringName
		if stored_graph_node is String:
			return StringName(stored_graph_node)

	var access_result := find_best_vertical_shelf_access(
		shelf.global_position,
		shelf
	)
	_store_access_metadata_from_result(shelf, access_result)
	return access_result.get("graph_node", StringName()) as StringName


func _find_reachable_graph_node_for_access(
	access_position: Vector2,
	preferred_node: StringName,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	surface_searches: Array = [],
	surface_route_cache: Dictionary = {},
	surface_anchor_path_cache: Dictionary = {}
) -> Dictionary:
	var candidate_nodes := _get_nearest_graph_node_names_for_access(
		access_position,
		preferred_node,
		MAX_ACCESS_GRAPH_NODE_CANDIDATES
	)
	var best_result: Dictionary = {"valid": false}
	var best_distance := INF

	for candidate_node in candidate_nodes:
		var graph_marker: Marker2D = _nav.get_graph_marker(candidate_node)
		if graph_marker == null:
			continue

		for horizontal_first in [true, false]:
			var direct_route := _routes.make_orthogonal_route(
				graph_marker.global_position,
				access_position,
				horizontal_first
			)
			if not _clearance.is_route_clear(
				graph_marker.global_position,
				direct_route,
				shelf_object,
				shelf_position
			):
				continue

			var direct_distance := _routes.get_route_distance(
				graph_marker.global_position,
				direct_route
			)
			if direct_distance < best_distance:
				best_distance = direct_distance
				best_result = {
					"valid": true,
					"node": candidate_node,
					"route": direct_route,
					"distance": direct_distance
				}

		var surface_result := _surface.find_surface_route_between_marker_and_access(
			candidate_node,
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
		if surface_distance < best_distance:
			best_distance = surface_distance
			best_result = surface_result

	return best_result


func _get_connection_from_graph_node_to_access(
	graph_node: StringName,
	access_position: Vector2,
	shelf: Shelf
) -> Array[Vector2]:
	if shelf != null and shelf.has_meta(ACCESS_ROUTE_META):
		var stored_node := get_shelf_access_graph_node(shelf)
		if stored_node == graph_node:
			var stored_route := _variant_route_to_vector2_array(
				shelf.get_meta(ACCESS_ROUTE_META)
			)
			if not stored_route.is_empty():
				return stored_route

	var shelf_position := Vector2.INF
	if shelf != null:
		shelf_position = shelf.global_position
	var surface_result := _surface.find_surface_route_between_marker_and_access(
		graph_node,
		access_position,
		shelf,
		shelf_position
	)
	if not bool(surface_result.get("valid", false)):
		return []
	return _variant_route_to_vector2_array(surface_result.get("route", []))


func _get_shortest_checkout_route(
	from_position: Vector2,
	source_shelf: Shelf,
	target_role: StringName = StringName()
) -> Array[Vector2]:
	if not from_position.is_finite():
		return []

	var candidates: Array[Dictionary] = []
	var checkout_nodes := _nav.get_checkout_goal_node_names()
	if target_role != StringName():
		var fallback_node := (
			CASHIER
			if target_role == ROLE_CASHIER
			else QUEUE_FRONT
		)
		var target_node := _nav.get_role_node_name(
			target_role,
			fallback_node
		)
		checkout_nodes.clear()
		if target_node != StringName():
			checkout_nodes.append(target_node)

	for checkout_node in checkout_nodes:
		var checkout_marker: Marker2D = _nav.get_graph_marker(checkout_node)
		if checkout_marker == null:
			continue

		var diagonal_route: Array[Vector2] = [checkout_marker.global_position]
		if _is_checkout_route_clear(
			from_position,
			diagonal_route,
			source_shelf
		):
			_append_route_candidate(candidates, from_position, diagonal_route)

		for horizontal_first in [true, false]:
			var direct_route := _routes.make_orthogonal_route(
				from_position,
				checkout_marker.global_position,
				horizontal_first
			)
			if _is_checkout_route_clear(
				from_position,
				direct_route,
				source_shelf
			):
				_append_route_candidate(candidates, from_position, direct_route)

	if source_shelf == null:
		for checkout_node in checkout_nodes:
			var graph_result := _nav.find_nearest_reachable_graph_node_for_route(
				from_position,
				checkout_node
			)
			if not bool(graph_result.get("valid", false)):
				continue
			var graph_route := _variant_route_to_vector2_array(
				graph_result.get("route", [])
			)
			_append_route_candidate(candidates, from_position, graph_route)
	else:
		var preferred_node := get_shelf_access_graph_node(source_shelf)
		for start_node in _get_nearest_graph_node_names_for_access(
			from_position,
			preferred_node,
			MAX_ACCESS_GRAPH_NODE_CANDIDATES
		):
			var start_marker: Marker2D = _nav.get_graph_marker(start_node)
			if start_marker == null:
				continue

			for horizontal_first in [true, false]:
				var start_route := _routes.make_orthogonal_route(
					from_position,
					start_marker.global_position,
					horizontal_first
				)
				if not _is_checkout_route_clear(
					from_position,
					start_route,
					source_shelf
				):
					continue

				for checkout_node in checkout_nodes:
					var graph_path := _nav.find_graph_path(
						start_node,
						checkout_node
					)
					if graph_path.is_empty():
						continue

					var complete_route := start_route.duplicate()
					complete_route.append_array(
						_routes.build_route_from_graph_path(graph_path)
					)
					complete_route = _routes.dedupe_route_points(
						complete_route
					)
					if not _is_checkout_route_clear(
						from_position,
						complete_route,
						source_shelf
					):
						continue
					_append_route_candidate(
						candidates,
						from_position,
						complete_route
					)

	return _get_shortest_route(candidates)


func _is_checkout_route_clear(
	from_position: Vector2,
	route: Array[Vector2],
	source_shelf: Shelf
) -> bool:
	if source_shelf != null and is_instance_valid(source_shelf):
		return _clearance.is_checkout_route_from_access_clear(
			from_position,
			route,
			source_shelf,
			source_shelf.global_position
		)
	return _clearance.is_route_clear_from_current_position(
		from_position,
		route
	)


func _append_access_route_variants(
	candidates: Array[Dictionary],
	from_position: Vector2,
	access_position: Vector2,
	shelf: Shelf,
	npc_node: Node
) -> void:
	var diagonal_route: Array[Vector2] = [access_position]
	if _clearance.is_route_to_access_clear(
		from_position,
		diagonal_route,
		shelf,
		npc_node
	):
		_append_route_candidate(candidates, from_position, diagonal_route)

	for horizontal_first in [true, false]:
		var route := _routes.make_orthogonal_route(
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


func _append_clear_route_variants(
	candidates: Array[Dictionary],
	from_position: Vector2,
	target_position: Vector2,
	shelf_object: Node2D,
	shelf_position: Vector2,
	ignore_endpoint: bool
) -> void:
	var diagonal_route: Array[Vector2] = [target_position]
	if _clearance.is_any_direction_segment_clear(
		from_position,
		target_position,
		shelf_object,
		shelf_position,
		null,
		true,
		ignore_endpoint
	):
		_append_route_candidate(candidates, from_position, diagonal_route)

	for horizontal_first in [true, false]:
		var route := _routes.make_orthogonal_route(
			from_position,
			target_position,
			horizontal_first
		)
		if _clearance.is_route_clear(
			from_position,
			route,
			shelf_object,
			shelf_position
		):
			_append_route_candidate(candidates, from_position, route)


func _append_route_candidate(
	candidates: Array[Dictionary],
	from_position: Vector2,
	route: Array[Vector2]
) -> void:
	var clean_route := _routes.dedupe_route_points(route)
	if clean_route.is_empty():
		return
	for point in clean_route:
		if not point.is_finite():
			return
	candidates.append({
		"route": clean_route,
		"distance": _routes.get_route_distance(from_position, clean_route)
	})


func _get_shortest_route(candidates: Array[Dictionary]) -> Array[Vector2]:
	var best_route: Array[Vector2] = []
	var best_distance := INF
	for candidate in candidates:
		var route_distance := float(candidate.get("distance", INF))
		if route_distance >= best_distance:
			continue
		best_distance = route_distance
		best_route = _variant_route_to_vector2_array(
			candidate.get("route", [])
		)
	return best_route


func _get_nearest_graph_node_names_for_access(
	access_position: Vector2,
	preferred_node: StringName,
	limit: int
) -> Array[StringName]:
	var ranked: Array[Dictionary] = []
	for node_name in _nav.get_graph_node_names():
		if _nav.is_queue_target_node(node_name):
			continue
		var graph_marker: Marker2D = _nav.get_graph_marker(node_name)
		if graph_marker == null:
			continue
		ranked.append({
			"node": node_name,
			"distance": access_position.distance_to(graph_marker.global_position)
		})

	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", INF)) < float(b.get("distance", INF))
	)

	var selected: Array[StringName] = []
	if preferred_node != StringName() and _nav.get_graph_marker(preferred_node) != null:
		selected.append(preferred_node)

	for ranked_entry in ranked:
		if selected.size() >= limit:
			break
		var ranked_node := ranked_entry.get("node", StringName()) as StringName
		if ranked_node == StringName() or ranked_node in selected:
			continue
		selected.append(ranked_node)
	return selected


func _build_cashier_exit_route_via_queue_right(
	from_position: Vector2,
	fallback_exit_position: Vector2
) -> Array[Vector2]:
	var right_nodes := _nav.get_queue_right_node_names()
	if right_nodes.is_empty():
		return get_exit_route_from(from_position, fallback_exit_position)

	var nearest_right_node := _nav.get_nearest_queue_right_node_name(from_position)
	if nearest_right_node == StringName():
		return get_exit_route_from(from_position, fallback_exit_position)

	var start_index := right_nodes.find(nearest_right_node)
	var route: Array[Vector2] = []
	for index in range(start_index, right_nodes.size()):
		var route_marker: Marker2D = _nav.get_graph_marker(right_nodes[index])
		if route_marker != null:
			route.append(route_marker.global_position)

	if not _clearance.is_route_clear_from_current_position(from_position, route):
		return get_exit_route_from(from_position, fallback_exit_position)

	var route_end := from_position
	if not route.is_empty():
		route_end = route.back()
	var exit_route := get_exit_route_from(route_end, fallback_exit_position)
	route.append_array(exit_route)
	return _routes.dedupe_route_points(route)


func _variant_route_to_vector2_array(route_variant: Variant) -> Array[Vector2]:
	var route: Array[Vector2] = []
	if not (route_variant is Array):
		return route
	for point_variant in route_variant:
		if point_variant is Vector2:
			var point := point_variant as Vector2
			if route.is_empty() or route.back().distance_to(point) > 2.0:
				route.append(point)
	return route


func _get_surface_points_signature(points: Array[Vector2]) -> String:
	var signature_parts := PackedStringArray()
	for point in points:
		signature_parts.append("%.3f,%.3f" % [point.x, point.y])
	return "|".join(signature_parts)
