extends "res://scripts/locations/store/StoreShelfPlacementController.gd"

const STORE_ENTRY_DROP_BLOCK_ROLES: Array[StringName] = [
	&"entry",
	&"exit",
	&"enter_store"
]
const QUEUE_DROP_BLOCK_ROLES: Array[StringName] = [
	&"queue_front",
	&"queue_back",
	&"queue_front_right",
	&"queue_back_right",
	&"queue_exit_right"
]
const STORE_ENTRY_DROP_BLOCK_SIZE := Vector2(88, 56)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func evaluate_shelf_drop_restriction(
	object: Node2D,
	candidate: Vector2
) -> Dictionary:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var object_rect := get_object_body_rect_at(object, candidate)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var entrance_restricted_rect := get_marker_drop_restricted_rect(
		object_rect,
		STORE_ENTRY_DROP_BLOCK_ROLES,
		STORE_ENTRY_DROP_BLOCK_SIZE
	)

	if rect_has_area(entrance_restricted_rect):
		return make_drop_restriction(
			true,
			DROP_REJECTION_CASHIER_FLOW,
			"Keep the store entrance clear.",
			entrance_restricted_rect,
			true
		)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var queue_restricted_rect := get_queue_marker_drop_restricted_rect(
		object_rect
	)

	if rect_has_area(queue_restricted_rect):
		return make_drop_restriction(
			true,
			DROP_REJECTION_CASHIER_FLOW,
			"Keep the customer queue path clear.",
			queue_restricted_rect,
			true
		)

	if not is_drop_position_clear(object, candidate):
		return make_drop_restriction(
			true,
			DROP_REJECTION_COLLISION,
			"I can't place the shelf on another object.",
			object_rect,
			false
		)

	return make_drop_restriction()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_queue_drop_block_markers() -> Array[Marker2D]:
	return get_drop_block_markers_for_roles(QUEUE_DROP_BLOCK_ROLES)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_marker_drop_restricted_rect(
	object_rect: Rect2,
	roles: Array[StringName],
	block_size: Vector2
) -> Rect2:
	for marker in get_drop_block_markers_for_roles(roles):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var marker_rect := Rect2(
			marker.global_position - block_size * 0.5,
			block_size
		)

		if object_rect.intersects(marker_rect):
			return marker_rect

	return Rect2()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_drop_block_markers_for_roles(
	roles: Array[StringName]
) -> Array[Marker2D]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var markers: Array[Marker2D] = []

	if store == null or store.store_path_markers == null:
		return markers

	for child in store.store_path_markers.get_children():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		@warning_ignore("shadowed_variable", "shadowed_variable_base_class")
		var marker_node := child as Marker2D
		if marker_node == null or not marker_node.has_meta("store_path_role"):
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var role := StringName(str(marker_node.get_meta("store_path_role")))
		if role in roles:
			markers.append(marker_node)

	return markers
