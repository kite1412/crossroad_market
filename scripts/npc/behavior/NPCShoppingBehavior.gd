class_name NPCShoppingBehavior
extends RefCounted


static func get_requested_items(shopping_list: Array[String], fallback_item_id: String) -> Array[String]:
	if not shopping_list.is_empty():
		return shopping_list.duplicate()

	return [fallback_item_id] if fallback_item_id != "" else []


static func find_shelf_with_item(tree: SceneTree, item_id: String) -> Shelf:
	if tree == null:
		return null

	for shelf in tree.get_nodes_in_group("shelves"):
		if shelf is Shelf and shelf.has_item(item_id):
			return shelf

	return null


static func find_matching_shelf(tree: SceneTree, item_id: String) -> Shelf:
	if tree == null:
		return null

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item: ItemData = ItemDatabase.get_item(item_id)

	if item == null:
		return null

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var stocked_shelf := find_shelf_with_item(tree, item_id)

	if stocked_shelf != null:
		return stocked_shelf

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var fallback_shelf: Shelf = null

	for shelf in tree.get_nodes_in_group("shelves"):
		if not shelf is Shelf:
			continue

		if shelf.shelf_type != item.shelf_type:
			continue

		if shelf.has_item(item_id):
			return shelf

		if fallback_shelf == null:
			fallback_shelf = shelf

	return fallback_shelf


static func find_alternative_item(tree: SceneTree, item_id: String, original_item_id: String) -> String:
	if tree == null:
		return ""

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var target_type := ItemData.ShelfType.HUMAN
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var wanted_item: ItemData = ItemDatabase.get_item(item_id)

	if wanted_item != null:
		target_type = wanted_item.shelf_type

	for shelf in tree.get_nodes_in_group("shelves"):
		if not shelf is Shelf:
			continue

		if shelf.shelf_type != target_type:
			continue

		for i in shelf.max_slots:
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var shelf_item_id: String = shelf.get_slot_content(i)

			if shelf_item_id != "" and shelf_item_id != original_item_id:
				return shelf_item_id

	return ""


static func find_first_stocked_item_for_shelf_type(tree: SceneTree, shelf_type: ItemData.ShelfType) -> String:
	if tree == null:
		return ""

	for shelf in tree.get_nodes_in_group("shelves"):
		if not shelf is Shelf:
			continue

		if shelf.shelf_type != shelf_type:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var item_id: String = shelf.get_first_stocked_item_id()

		if item_id != "":
			return item_id

	return ""


static func get_shelf_visit_position(shelf: Shelf, visit_offset: Vector2) -> Vector2:
	return shelf.global_position + visit_offset
