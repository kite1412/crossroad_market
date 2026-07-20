extends Camera2D

const _LOCATION_BOUNDS: Dictionary = {
	&"store": ^"StoreStructure/Boundaries",
	&"home": ^"HomeCollisionBounds/WorldBounds",
	&"yard": ^"YardBounds",
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
	var min_x: float = INF
	var max_x: float = -INF
	var min_y: float = INF
	var max_y: float = -INF
	var found := false

	for col_node in bounds_node.find_children("", "CollisionShape2D"):
		@warning_ignore("shadowed_variable")
		var col: CollisionShape2D = col_node as CollisionShape2D
		if col == null or col.shape == null or not col.shape is RectangleShape2D:
			continue

		var rect_shape: RectangleShape2D = col.shape
		var half: Vector2 = rect_shape.size * 0.5
		var pos: Vector2 = col.global_position

		min_x = minf(min_x, pos.x - half.x)
		max_x = maxf(max_x, pos.x + half.x)
		min_y = minf(min_y, pos.y - half.y)
		max_y = maxf(max_y, pos.y + half.y)
		found = true

	if not found:
		if _is_clamping:
			_clear_limits()
		return

	limit_left = int(min_x)
	limit_right = int(max_x)
	limit_top = int(min_y)
	limit_bottom = int(max_y)
	_is_clamping = true


func _clear_limits() -> void:
	limit_left = -10000000
	limit_right = 10000000
	limit_top = -10000000
	limit_bottom = 10000000
	_is_clamping = false
