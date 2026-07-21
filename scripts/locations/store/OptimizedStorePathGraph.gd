class_name OptimizedStorePathGraph
extends StorePathGraph

## Store path graph optimized for runtime shelf movement.
##
## The fast path validates direct and orthogonal movement first. Marker and
## surface A* are fallback mechanisms only, rather than work that is always
## performed after a valid direct route has already been found.

const SurfaceGridScript = preload(
	"res://scripts/locations/store/store_path_graph_surface_grid.gd"
)

const PLACEMENT_ACCESS_CANDIDATE_LIMIT: int = 8
const PLACEMENT_GRAPH_NODE_LIMIT: int = 6
const PLACEMENT_SURFACE_ACCESS_LIMIT: int = 2
const PLACEMENT_SURFACE_NODE_LIMIT: int = 1
const LIVE_GRAPH_START_NODE_LIMIT: int = 6
const FAILED_ACCESS_RETRY_MSEC: int = 1000

const ACCESS_POSITION_REVISION_META: StringName = &"npc_access_position_revision"
const ACCESS_NAV_REVISION_META: StringName = &"npc_access_navigation_revision"
const ACCESS_RETRY_AFTER_META: StringName = &"npc_access_retry_after_msec"
const ACCESS_FAILED_POSITION_META: StringName = &"npc_access_failed_position"
const ACCESS_FAILED_REVISION_META: StringName = &"npc_access_failed_revision"

var _navigation_revision: int = 0


func _init(
	store_node: Node2D = null,
	marker_root: Node2D = null
) -> void:
	super(store_node, marker_root)
	_surface = SurfaceGridScript.new(self)


func set_shelf_access_points(points: Array[Vector2]) -> void:
	if points.size() == _shelf_access_points.size() and points == _shelf_access_points:
		return

	super.set_shelf_access_points(points)
	_navigation_revision += 1


func invalidate_dynamic_navigation() -> void:
	_navigation_revision += 1
	invalidate_surface_graph_cache()

	if _store == null or _store.get_tree() == null:
		return

	for shelf_variant in _store.get_tree().get_nodes_in_group("shelves"):
		if not (shelf_variant is Shelf):
			continue
		var shelf := shelf_variant as Shelf
		if is_instance_valid(shelf):
			clear_shelf_access_metadata(shelf)


func has_cached_shelf_access_metadata(shelf: Shelf) -> bool:
	if shelf == null or not is_instance_valid(shelf):
		return false
	if not super.has_cached_shelf_access_metadata(shelf):
		return false
	if int(shelf.get_meta(ACCESS_NAV_REVISION_META, -1)) != _navigation_revision:
		return false

	var stored_position: Variant = shelf.get_meta(
		ACCESS_POSITION_REVISION_META,
		Vector2.INF
	)
	return (
		stored_position is Vector2
		and (stored_position as Vector2).is_equal_approx(shelf.global_position)
	)


func clear_shelf_access_metadata(object: Node2D) -> void:
	super.clear_shelf_access_metadata(object)
	if object == null:
		return
	for metadata_key in [
		ACCESS_POSITION_REVISION_META,
		ACCESS_NAV_REVISION_META,
		ACCESS_RETRY_AFTER_META,
		ACCESS_FAILED_POSITION_META,
		ACCESS_FAILED_REVISION_META
	]:
		if object.has_meta(metadata_key):
			object.remove_meta(metadata_key)


func store_shelf_access_metadata(
	object: Node2D,
	drop_position: Vector2
) -> void:
	if object == null or not is_instance_valid(object):
		return
	if _has_current_access_metadata(object, drop_position):
		return
	if _is_failed_access_retry_cooling_down(object, drop_position):
		return

	var access_result := _find_bounded_vertical_shelf_access(
		drop_position,
		object
	)
	if not bool(access_result.get("valid", false)):
		super.clear_shelf_access_metadata(object)
		object.set_meta(ACCESS_FAILED_POSITION_META, drop_position)
		object.set_meta(ACCESS_FAILED_REVISION_META, _navigation_revision)
		object.set_meta(
			ACCESS_RETRY_AFTER_META,
			Time.get_ticks_msec() + FAILED_ACCESS_RETRY_MSEC
		)
		return

	_store_access_metadata_from_result(object, access_result)
	object.set_meta(ACCESS_POSITION_REVISION_META, drop_position)
	object.set_meta(ACCESS_NAV_REVISION_META, _navigation_revision)
	_clear_failed_access_retry(object)


func get_route_to_shelf_access(
	shelf: Shelf,
	from_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> Array[Vector2]:
	if (
		shelf == null
		or not is_instance_valid(shelf)
		or not from_position.is_finite()
		or not has_cached_shelf_access_metadata(shelf)
	):
		return []

	var access_position := get_shelf_access_position(shelf)
	var shelf_graph_node := get_shelf_access_graph_node(shelf)
	if not access_position.is_finite() or shelf_graph_node == StringName():
		return []

	var direct_candidates: Array[Dictionary] = []
	_append_access_route_variants(
		direct_candidates,
		from_position,
		access_position,
		shelf,
		npc_node
	)
	var direct_route := _get_shortest_route(direct_candidates)
	if not direct_route.is_empty():
		return direct_route

	return _build_bounded_graph_route_to_access(
		shelf,
		from_position,
		access_position,
		shelf_graph_node,
		npc_node
	)


func _build_bounded_graph_route_to_access(
	shelf: Shelf,
	from_position: Vector2,
	access_position: Vector2,
	shelf_graph_node: StringName,
	npc_node: Node
) -> Array[Vector2]:
	var access_connection := _get_connection_from_graph_node_to_access(
		shelf_graph_node,
		access_position,
		shelf
	)
	if access_connection.is_empty():
		return []

	var candidates: Array[Dictionary] = []
	var start_nodes := super._get_nearest_graph_node_names_for_access(
		from_position,
		StringName(),
		LIVE_GRAPH_START_NODE_LIMIT
	)

	for start_node in start_nodes:
		var start_marker: Marker2D = _nav.get_graph_marker(start_node)
		if start_marker == null:
			continue

		var graph_path := _nav.find_graph_path(start_node, shelf_graph_node)
		if graph_path.is_empty():
			continue

		var graph_route := _routes.build_route_from_graph_path(graph_path)
		for entry_route_variant in _make_route_variants(
			from_position,
			start_marker.global_position
		):
			var entry_route := _variant_route_to_vector2_array(
				entry_route_variant
			)
			var complete_route: Array[Vector2] = entry_route.duplicate()
			complete_route.append_array(graph_route)
			complete_route.append_array(access_connection)
			complete_route = _routes.dedupe_route_points(complete_route)

			if not _clearance.is_route_to_access_clear(
				from_position,
				complete_route,
				shelf,
				npc_node
			):
				continue
			_append_route_candidate(candidates, from_position, complete_route)

	return _get_shortest_route(candidates)


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

	var clear_candidates: Array[Dictionary] = []
	var best_result: Dictionary = {"valid": false}
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

		clear_candidates.append(access_candidate)
		var connection := _find_bounded_direct_access_connection(
			access_position,
			access_candidate.get("graph_node", StringName()) as StringName,
			shelf_object,
			shelf_position
		)
		if not bool(connection.get("valid", false)):
			continue

		var scored_result := _make_scored_access_result(
			access_candidate,
			connection,
			shelf_position,
			cashier_position,
			prefer_below
		)
		if _is_better_access_result(scored_result, best_result):
			best_result = scored_result

	if bool(best_result.get("valid", false)):
		return best_result

	var surface_candidate_count := mini(
		clear_candidates.size(),
		PLACEMENT_SURFACE_ACCESS_LIMIT
	)
	for index in range(surface_candidate_count):
		var access_candidate: Dictionary = clear_candidates[index]
		var access_position := access_candidate.get(
			"access_point",
			Vector2.INF
		) as Vector2
		var connection := _find_bounded_surface_access_connection(
			access_position,
			access_candidate.get("graph_node", StringName()) as StringName,
			shelf_object,
			shelf_position
		)
		if not bool(connection.get("valid", false)):
			continue

		var scored_result := _make_scored_access_result(
			access_candidate,
			connection,
			shelf_position,
			cashier_position,
			prefer_below
		)
		if _is_better_access_result(scored_result, best_result):
			best_result = scored_result

	return best_result


func _find_bounded_direct_access_connection(
	access_position: Vector2,
	preferred_node: StringName,
	shelf_object: Node2D,
	shelf_position: Vector2
) -> Dictionary:
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

		for route_variant in _make_route_variants(
			graph_marker.global_position,
			access_position
		):
			var route := _variant_route_to_vector2_array(route_variant)
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

	return best_result


func _find_bounded_surface_access_connection(
	access_position: Vector2,
	preferred_node: StringName,
	shelf_object: Node2D,
	shelf_position: Vector2
) -> Dictionary:
	var node_names := super._get_nearest_graph_node_names_for_access(
		access_position,
		preferred_node,
		PLACEMENT_SURFACE_NODE_LIMIT
	)
	var surface_searches: Array = [0]
	var surface_route_cache: Dictionary = {}
	var surface_anchor_path_cache: Dictionary = {}
	var best_result: Dictionary = {"valid": false}
	var best_distance := INF

	for node_name in node_names:
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


func _make_scored_access_result(
	access_candidate: Dictionary,
	connection: Dictionary,
	shelf_position: Vector2,
	cashier_position: Vector2,
	prefer_below: bool
) -> Dictionary:
	var graph_node := connection.get("node", StringName()) as StringName
	var checkout_path := _nav.find_checkout_graph_path(graph_node)
	if checkout_path.is_empty():
		return {"valid": false}

	var access_position := access_candidate.get(
		"access_point",
		Vector2.INF
	) as Vector2
	var access_side := str(access_candidate.get("access_side", ""))
	var score := (
		float(access_candidate.get("vertical_distance", 0.0))
		* SHELF_ACCESS_DISTANCE_SCORE_WEIGHT
		+ float(connection.get("distance", 0.0))
		+ _nav.get_graph_path_cost(checkout_path)
		+ float(access_candidate.get("horizontal_distance", 0.0)) * 0.25
	)

	if (
		cashier_position.is_finite()
		and prefer_below != (access_side == "below")
	):
		score += absf(
			access_position.y - cashier_position.y
		) * COUNTER_DIRECTION_PENALTY_SCALE

	return {
		"valid": true,
		"access_point": access_position,
		"graph_node": graph_node,
		"surface_route": connection.get("route", []),
		"score": score,
		"access_side": access_side,
		"checkout_source": connection.get("source", "bounded_placement"),
		"shelf_position": shelf_position
	}


func _is_better_access_result(
	candidate: Dictionary,
	current: Dictionary
) -> bool:
	if not bool(candidate.get("valid", false)):
		return false
	if not bool(current.get("valid", false)):
		return true
	return float(candidate.get("score", INF)) < float(current.get("score", INF))


func _make_route_variants(
	from_position: Vector2,
	to_position: Vector2
) -> Array:
	return [
		[to_position],
		_routes.make_orthogonal_route(from_position, to_position, true),
		_routes.make_orthogonal_route(from_position, to_position, false)
	]


func _has_current_access_metadata(
	object: Node2D,
	position: Vector2
) -> bool:
	if not (object is Shelf):
		return false
	var shelf := object as Shelf
	return (
		has_cached_shelf_access_metadata(shelf)
		and position.is_equal_approx(shelf.global_position)
	)


func _is_failed_access_retry_cooling_down(
	object: Node2D,
	position: Vector2
) -> bool:
	if int(object.get_meta(ACCESS_FAILED_REVISION_META, -1)) != _navigation_revision:
		return false
	var failed_position: Variant = object.get_meta(
		ACCESS_FAILED_POSITION_META,
		Vector2.INF
	)
	if not (failed_position is Vector2):
		return false
	if not (failed_position as Vector2).is_equal_approx(position):
		return false
	return Time.get_ticks_msec() < int(
		object.get_meta(ACCESS_RETRY_AFTER_META, 0)
	)


func _clear_failed_access_retry(object: Node2D) -> void:
	for metadata_key in [
		ACCESS_RETRY_AFTER_META,
		ACCESS_FAILED_POSITION_META,
		ACCESS_FAILED_REVISION_META
	]:
		if object.has_meta(metadata_key):
			object.remove_meta(metadata_key)
