extends StorePathGraphSurface
class_name StorePathGraphSurfaceGrid

## Surface-grid implementation with row/column buckets.
##
## The previous cache builder compared every anchor with every other anchor for
## each axis direction. With 525 placement points that produced more than one
## million candidate comparisons and physics queries on the first surface A*.
## This implementation groups points by their shared row and column, then only
## inspects nearby points on that axis.


func _ensure_surface_neighbor_cache() -> void:
	var signature: String = _graph._get_surface_points_signature(
		_graph._shelf_access_points
	)
	if _graph._surface_neighbor_signature == signature:
		return

	_graph._surface_neighbor_cache.clear()
	_graph._surface_neighbor_signature = signature

	for index in range(_graph._shelf_access_points.size()):
		_graph._surface_neighbor_cache[index] = []

	var row_buckets := _build_axis_buckets(true)
	var column_buckets := _build_axis_buckets(false)
	_connect_axis_buckets(row_buckets, true)
	_connect_axis_buckets(column_buckets, false)


func _build_axis_buckets(horizontal: bool) -> Dictionary:
	var buckets: Dictionary = {}
	for index in range(_graph._shelf_access_points.size()):
		var point: Vector2 = _graph._shelf_access_points[index]
		var axis_value := point.y if horizontal else point.x
		# Placement anchors are generated from a stable grid. Three decimals keep
		# rows/columns deterministic without merging neighboring grid lines.
		var bucket_key := "%.3f" % axis_value
		var indices: Array = buckets.get(bucket_key, [])
		indices.append(index)
		buckets[bucket_key] = indices
	return buckets


func _connect_axis_buckets(buckets: Dictionary, horizontal: bool) -> void:
	for bucket_variant in buckets.values():
		if not (bucket_variant is Array):
			continue

		var ordered_indices: Array = bucket_variant
		ordered_indices.sort_custom(func(a: Variant, b: Variant) -> bool:
			var point_a: Vector2 = _graph._shelf_access_points[int(a)]
			var point_b: Vector2 = _graph._shelf_access_points[int(b)]
			return point_a.x < point_b.x if horizontal else point_a.y < point_b.y
		)

		for ordered_index in range(ordered_indices.size()):
			_append_nearest_clear_axis_neighbor(
				ordered_indices,
				ordered_index,
				-1,
				horizontal
			)
			_append_nearest_clear_axis_neighbor(
				ordered_indices,
				ordered_index,
				1,
				horizontal
			)


func _append_nearest_clear_axis_neighbor(
	ordered_indices: Array,
	ordered_index: int,
	step: int,
	horizontal: bool
) -> void:
	var source_index := int(ordered_indices[ordered_index])
	var source_position: Vector2 = _graph._shelf_access_points[source_index]
	var cursor := ordered_index + step

	while cursor >= 0 and cursor < ordered_indices.size():
		var candidate_index := int(ordered_indices[cursor])
		var candidate_position: Vector2 = _graph._shelf_access_points[candidate_index]
		var distance := (
			absf(candidate_position.x - source_position.x)
			if horizontal
			else absf(candidate_position.y - source_position.y)
		)

		if distance > _graph.SURFACE_NEIGHBOR_MAX_DISTANCE:
			return
		if distance <= _graph.SURFACE_ALIGNMENT_EPSILON:
			cursor += step
			continue

		if _graph._clearance.is_route_segment_clear(
			source_position,
			candidate_position
		):
			var neighbors: Array = _graph._surface_neighbor_cache.get(
				source_index,
				[]
			)
			if candidate_index not in neighbors:
				neighbors.append(candidate_index)
				_graph._surface_neighbor_cache[source_index] = neighbors
			return

		# Preserve the previous behavior: when the nearest point is blocked, a
		# farther point on the same axis may still be selected within the limit.
		cursor += step
