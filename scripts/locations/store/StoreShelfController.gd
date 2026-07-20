class_name StoreShelfController
extends RefCounted


static func get_carried_object_from_player(player: Node2D) -> Node2D:
	if player == null:
		return null

	for child in player.get_children():
		if child is Node2D and child.has_meta("is_carried_storage_object"):
			if bool(child.get_meta("is_carried_storage_object")):
				return child as Node2D

	return null


static func is_player_carrying_shelf_named(player: Node2D, shelf_name: String) -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var carried_object := get_carried_object_from_player(player)
	return carried_object != null and carried_object.name == shelf_name


static func is_descendant_of(node: Node, ancestor: Node) -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var current := node

	while current != null:
		if current == ancestor:
			return true

		current = current.get_parent()

	return false


static func is_player_behind_depth_object(
	player: Node2D,
	object: Node2D,
	half_width: float,
	back_offset: float,
	front_offset: float
) -> bool:
	if player == null or object == null or not is_instance_valid(object):
		return false

	if not object.visible:
		return false

	if object.has_meta("is_carried_storage_object") and bool(object.get_meta("is_carried_storage_object")):
		return false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var player_pos: Vector2 = player.global_position
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var object_pos: Vector2 = object.global_position
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var overlaps_x: bool = abs(player_pos.x - object_pos.x) <= half_width
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var overlaps_y: bool = (
		player_pos.y >= object_pos.y - back_offset
		and player_pos.y <= object_pos.y + front_offset
	)

	return overlaps_x and overlaps_y and player_pos.y < object_pos.y


static func get_shelf_stock_count(shelf: Shelf) -> int:
	if shelf == null:
		return 0

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var stock_count := 0

	for slot_index in shelf.max_slots:
		if shelf.get_slot_content(slot_index) != "":
			stock_count += 1

	return stock_count
