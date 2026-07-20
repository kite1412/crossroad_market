extends Camera2D

const _STORE_GROUP: StringName = &"store"
const _SUB_LOCATION_GROUPS: Array[StringName] = [&"yard", &"storage", &"home"]
const _BOUNDARIES_PATH: NodePath = ^"StoreStructure/Boundaries"

var _is_clamping: bool = false


func _process(_delta: float) -> void:
	var store := _find_store_scene()

	if store == null:
		if _is_clamping:
			_clear_limits()
		return

	var boundaries := store.get_node_or_null(_BOUNDARIES_PATH) as Node2D
	if boundaries == null:
		if _is_clamping:
			_clear_limits()
		return

	_apply_boundaries_limits(boundaries)


func _find_store_scene() -> Node:
	var node := get_parent()
	while node != null:
		for group_name in _SUB_LOCATION_GROUPS:
			if node.is_in_group(group_name):
				return null
		if node.is_in_group(_STORE_GROUP):
			return node
		node = node.get_parent()
	return null


func _apply_boundaries_limits(boundaries: Node2D) -> void:
	var min_x: float = INF
	var max_x: float = -INF
	var min_y: float = INF
	var max_y: float = -INF
	var found := false


	for col_node in boundaries.find_children("", "CollisionShape2D"):
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
