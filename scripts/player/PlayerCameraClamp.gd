extends Camera2D

const _LOCATION_BOUNDS: Dictionary = {
	&"store": ^"StoreStructure/Boundaries",
	&"home": ^"HomeCollisionBounds/WorldBounds",
	&"yard": ^"Bounds",
}

var _is_clamping: bool = false


func _process(_delta: float) -> void:
	var bounds_node := _find_camera_bounds()

	if bounds_node == null:
		if _is_clamping:
			_clear_limits()
		return

	_apply_collision_limits(bounds_node)


func _find_camera_bounds() -> Node:
	var node := get_parent()
	while node != null:
		for location_group in _LOCATION_BOUNDS:
			if node.is_in_group(location_group):
				return node.get_node_or_null(_LOCATION_BOUNDS[location_group])
		node = node.get_parent()
	return null


func _apply_collision_limits(bounds_node: Node) -> void:
	var extent_points: Array[Vector2] = []

	for col_node in bounds_node.find_children("", "CollisionShape2D"):
		@warning_ignore("shadowed_variable")
		var col: CollisionShape2D = col_node as CollisionShape2D
		if col == null or col.shape == null:
			continue

		if col.shape is RectangleShape2D:
			_append_rectangle_extent_points(col, col.shape as RectangleShape2D, extent_points)
		elif col.shape is WorldBoundaryShape2D:
			# Yard's new Bounds are editor-placed infinite boundary lines. Their
			# CollisionShape2D origins describe the camera rectangle corners.
			extent_points.append(col.global_position)

	if extent_points.is_empty():
		if _is_clamping:
			_clear_limits()
		return

	var min_x: float = INF
	var max_x: float = -INF
	var min_y: float = INF
	var max_y: float = -INF

	for point in extent_points:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)

	if is_equal_approx(min_x, max_x) or is_equal_approx(min_y, max_y):
		if _is_clamping:
			_clear_limits()
		return

	limit_left = floori(min_x)
	limit_right = ceili(max_x)
	limit_top = floori(min_y)
	limit_bottom = ceili(max_y)
	_is_clamping = true


func _append_rectangle_extent_points(
	col: CollisionShape2D,
	rect_shape: RectangleShape2D,
	extent_points: Array[Vector2]
) -> void:
	var half: Vector2 = rect_shape.size * 0.5
	for corner in [
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	]:
		extent_points.append(col.to_global(corner))


func _clear_limits() -> void:
	limit_left = -10000000
	limit_right = 10000000
	limit_top = -10000000
	limit_bottom = 10000000
	_is_clamping = false
