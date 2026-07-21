class_name StoreRuntimePathGraph
extends OptimizedStorePathGraph

## Store-only compatibility graph. Layered navigation owns movement planning;
## this graph remains responsible for selecting and caching shelf access points.

const QUEUE_GRAPH_START_NODE_LIMIT: int = 6
const QUEUE_APPROACH_CONNECTOR_LIMIT: int = 4
const DEFAULT_SHELF_SIZE := Vector2(64, 48)
const LEGACY_DIRTY_MARGIN: float = 12.0

var _last_shelf_records: Dictionary = {}
var _has_shelf_snapshot: bool = false


func _init(
	store_node: Node2D = null,
	marker_root: Node2D = null
) -> void:
	super(store_node, marker_root)
	if store_node != null:
		_last_shelf_records = _collect_shelf_records()
		_has_shelf_snapshot = true


func setup(store_node: Node2D, marker_root: Node2D) -> void:
	super.setup(store_node, marker_root)
	if not _has_shelf_snapshot:
		_last_shelf_records = _collect_shelf_records()
		_has_shelf_snapshot = true


func invalidate_dynamic_navigation() -> void:
	var next_records := _collect_shelf_records()
	var dirty_regions := _get_dirty_regions(
		_last_shelf_records,
		next_records
	)

	_navigation_revision += 1
	invalidate_surface_graph_cache()

	for record_variant in next_records.values():
		if not (record_variant is Dictionary):
			continue
		var record := record_variant as Dictionary
		var shelf_variant: Variant = record.get("shelf", null)
		if not is_instance_valid(shelf_variant) or not (shelf_variant is Shelf):
			continue
		var shelf := shelf_variant as Shelf
		if _shelf_metadata_touches_dirty_region(shelf, dirty_regions):
			clear_shelf_access_metadata(shelf)
		elif _has_raw_access_metadata(shelf):
			shelf.set_meta(ACCESS_NAV_REVISION_META, _navigation_revision)

	_last_shelf_records = next_records
	_has_shelf_snapshot = true


func get_shelf_access_position(shelf: Shelf) -> Vector2:
	if shelf == null or not is_instance_valid(shelf):
		return Vector2.INF

	# If cache miss, try to compute and cache the access position
	if not has_cached_shelf_access_metadata(shelf):
		store_shelf_access_metadata(shelf, shelf.global_position)
		# If still no cache (e.g., computation failed), try base class fallback
		if not has_cached_shelf_access_metadata(shelf):
			return _compute_fallback_access_position(shelf)

	var stored_access: Variant = shelf.get_meta(
		ACCESS_META,
		Vector2.INF
	)
	if stored_access is Vector2:
		return stored_access as Vector2
	return Vector2.INF


func _compute_fallback_access_position(shelf: Shelf) -> Vector2:
	# Fallback: compute access position directly without caching
	# This handles cases where cache population fails
	var access_candidates := _shelf.get_shelf_access_candidates(
		shelf.global_position,
		true
	)
	var best_position := Vector2.INF
	var best_distance := INF

	for candidate in access_candidates:
		var access_point: Vector2 = candidate.get("access_point", Vector2.INF)
		if not access_point.is_finite():
			continue
		# Prefer the nearest access point
		var distance := shelf.global_position.distance_to(access_point)
		if distance < best_distance:
			best_distance = distance
			best_position = access_point

	return best_position


func get_route_from_shelf_to_queue_target(
	shelf: Shelf,
	from_position: Vector2,
	queue_index: int,
	npc_node: Node = null
) -> Array[Vector2]:
	if (
		shelf == null
		or not is_instance_valid(shelf)
		or not from_position.is_finite()
	):
		return []

	var queue_target := get_queue_target_position(
		queue_index,
		from_position
	)
	if not queue_target.is_finite():
		return []

	var direct_candidates: Array[Dictionary] = []
	for route_variant in _make_route_variants(
		from_position,
		queue_target
	):
		var route := _variant_route_to_vector2_array(route_variant)
		if _is_shelf_queue_route_clear(
			from_position,
			route,
			shelf,
			npc_node
		):
			_append_route_candidate(
				direct_candidates,
				from_position,
				route
			)

	var direct_route := _get_shortest_route(direct_candidates)
	if not direct_route.is_empty():
		return direct_route

	var approach_node := _nav.get_queue_approach_node_name(queue_index)
	if approach_node == StringName():
		approach_node = _nav.get_queue_target_node_name(queue_index)
	if approach_node == StringName():
		return []

	var approach_marker: Marker2D = _nav.get_graph_marker(approach_node)
	if approach_marker == null:
		return []

	var approach_connectors := super._get_nearest_graph_node_names_for_access(
		approach_marker.global_position,
		StringName(),
		QUEUE_APPROACH_CONNECTOR_LIMIT
	)
	var start_nodes := super._get_nearest_graph_node_names_for_access(
		from_position,
		StringName(),
		QUEUE_GRAPH_START_NODE_LIMIT
	)
	var candidates: Array[Dictionary] = []

	for start_node in start_nodes:
		var start_marker: Marker2D = _nav.get_graph_marker(start_node)
		if start_marker == null:
			continue

		for connector_node in approach_connectors:
			var connector_marker: Marker2D = _nav.get_graph_marker(
				connector_node
			)
			if connector_marker == null:
				continue

			var graph_path := _nav.find_graph_path(
				start_node,
				connector_node
			)
			if graph_path.is_empty():
				continue

			var graph_route := _routes.build_route_from_graph_path(
				graph_path
			)
			for entry_route_variant in _make_route_variants(
				from_position,
				start_marker.global_position
			):
				var entry_route := _variant_route_to_vector2_array(
					entry_route_variant
				)

				for approach_route_variant in _make_route_variants(
					connector_marker.global_position,
					approach_marker.global_position
				):
					var approach_route := _variant_route_to_vector2_array(
						approach_route_variant
					)
					var complete_route: Array[Vector2] = entry_route.duplicate()
					complete_route.append_array(graph_route)
					if (
						complete_route.is_empty()
						or complete_route.back().distance_to(
							connector_marker.global_position
						) > ROUTE_CLEARANCE_EPSILON
					):
						complete_route.append(
							connector_marker.global_position
						)

					complete_route.append_array(approach_route)
					complete_route.append(queue_target)
					complete_route = _routes.dedupe_route_points(
						complete_route
					)

					if not _is_shelf_queue_route_clear(
						from_position,
						complete_route,
						shelf,
						npc_node
					):
						continue
					_append_route_candidate(
						candidates,
						from_position,
						complete_route
					)

	return _get_shortest_route(candidates)


func _is_shelf_queue_route_clear(
	from_position: Vector2,
	route: Array[Vector2],
	shelf: Shelf,
	npc_node: Node
) -> bool:
	return _clearance.is_route_to_access_clear(
		from_position,
		route,
		shelf,
		npc_node
	)


func _has_raw_access_metadata(shelf: Shelf) -> bool:
	return (
		shelf != null
		and is_instance_valid(shelf)
		and shelf.has_meta(ACCESS_META)
		and shelf.has_meta(ACCESS_NODE_META)
	)


func _collect_shelf_records() -> Dictionary:
	var records: Dictionary = {}
	if _store == null or _store.get_tree() == null:
		return records

	for shelf_variant in _store.get_tree().get_nodes_in_group("shelves"):
		if not (shelf_variant is Shelf):
			continue
		var shelf := shelf_variant as Shelf
		if not is_instance_valid(shelf):
			continue
		if not _is_descendant_of(shelf, _store):
			continue
		if bool(shelf.get_meta("is_carried_storage_object", false)):
			continue
		if (
			shelf.has_meta("is_installed_in_store")
			and not bool(shelf.get_meta("is_installed_in_store", false))
		):
			continue
		records[shelf.get_instance_id()] = {
			"shelf": shelf,
			"position": shelf.global_position,
			"rect": _get_shelf_rect(shelf)
		}
	return records


func _get_dirty_regions(
	previous_records: Dictionary,
	next_records: Dictionary
) -> Array[Rect2]:
	var regions: Array[Rect2] = []
	for instance_id_variant in next_records.keys():
		var instance_id := int(instance_id_variant)
		var next_record: Dictionary = next_records[instance_id]
		var next_rect: Rect2 = next_record.get("rect", Rect2())
		if not previous_records.has(instance_id):
			regions.append(next_rect.grow(LEGACY_DIRTY_MARGIN))
			continue
		var previous_record: Dictionary = previous_records[instance_id]
		var previous_position: Vector2 = previous_record.get(
			"position",
			Vector2.INF
		)
		var next_position: Vector2 = next_record.get(
			"position",
			Vector2.INF
		)
		if (
			not previous_position.is_finite()
			or not next_position.is_finite()
			or not previous_position.is_equal_approx(next_position)
		):
			var previous_rect: Rect2 = previous_record.get("rect", Rect2())
			regions.append(previous_rect.grow(LEGACY_DIRTY_MARGIN))
			regions.append(next_rect.grow(LEGACY_DIRTY_MARGIN))

	for instance_id_variant in previous_records.keys():
		var instance_id := int(instance_id_variant)
		if next_records.has(instance_id):
			continue
		var removed_record: Dictionary = previous_records[instance_id]
		var removed_rect: Rect2 = removed_record.get("rect", Rect2())
		regions.append(removed_rect.grow(LEGACY_DIRTY_MARGIN))
	return regions


func _shelf_metadata_touches_dirty_region(
	shelf: Shelf,
	regions: Array[Rect2]
) -> bool:
	if not _has_raw_access_metadata(shelf):
		return true
	var stored_position: Variant = shelf.get_meta(
		ACCESS_POSITION_REVISION_META,
		Vector2.INF
	)
	if (
		not (stored_position is Vector2)
		or not (stored_position as Vector2).is_equal_approx(shelf.global_position)
	):
		return true
	if regions.is_empty():
		return false

	var access_variant: Variant = shelf.get_meta(ACCESS_META, Vector2.INF)
	var access_position := Vector2.INF
	if access_variant is Vector2:
		access_position = access_variant as Vector2
	for region in regions:
		if access_position.is_finite() and region.has_point(access_position):
			return true
		if region.intersects(_get_shelf_rect(shelf), true):
			return true

	var route := _metadata_route_to_vector2_array(
		shelf.get_meta(ACCESS_ROUTE_META, [])
	)
	var route_start := access_position
	var node_name := shelf.get_meta(
		ACCESS_NODE_META,
		StringName()
	) as StringName
	var node_marker: Marker2D = _nav.get_graph_marker(node_name)
	if node_marker != null:
		route_start = node_marker.global_position
	if (
		access_position.is_finite()
		and (
			route.is_empty()
			or route.back().distance_to(access_position) > ROUTE_CLEARANCE_EPSILON
		)
	):
		route.append(access_position)
	return _route_intersects_regions(route_start, route, regions)


func _metadata_route_to_vector2_array(value: Variant) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not (value is Array):
		return result
	for point_variant in value:
		if point_variant is Vector2:
			result.append(point_variant as Vector2)
	return result


func _route_intersects_regions(
	start_position: Vector2,
	route: Array[Vector2],
	regions: Array[Rect2]
) -> bool:
	var previous := start_position
	for point in route:
		for region in regions:
			if _segment_intersects_rect(previous, point, region):
				return true
		previous = point
	return false


func _segment_intersects_rect(
	from_position: Vector2,
	to_position: Vector2,
	rect: Rect2
) -> bool:
	if rect.has_point(from_position) or rect.has_point(to_position):
		return true
	var corners := [
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.end,
		rect.position + Vector2(0.0, rect.size.y)
	]
	for index in range(corners.size()):
		var next_index := (index + 1) % corners.size()
		if Geometry2D.segment_intersects_segment(
			from_position,
			to_position,
			corners[index] as Vector2,
			corners[next_index] as Vector2
		) != null:
			return true
	return false


func _get_shelf_rect(shelf: Shelf) -> Rect2:
	var collision_shape := shelf.get_node_or_null(
		"PhysicsBody/CollisionShape2D"
	) as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return Rect2(
			shelf.global_position - DEFAULT_SHELF_SIZE * 0.5,
			DEFAULT_SHELF_SIZE
		)
	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		return Rect2(
			shelf.global_position - DEFAULT_SHELF_SIZE * 0.5,
			DEFAULT_SHELF_SIZE
		)
	return Rect2(
		collision_shape.global_position - rectangle.size * 0.5,
		rectangle.size
	)


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current := node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false
