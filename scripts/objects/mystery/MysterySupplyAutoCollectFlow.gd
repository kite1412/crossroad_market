class_name MysterySupplyAutoCollectFlow
extends RefCounted

var box: MysterySupplyBox = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(box_node: MysterySupplyBox) -> void:
	box = box_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func auto_collect_to_shelf() -> void:
	if box.is_empty():
		return

	if box.items_to_give.is_empty():
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item_id: String = box.items_to_give[0]
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var ghost_shelf: Shelf = get_ghost_shelf()

	if ghost_shelf == null:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var result: int = ghost_shelf.place_item(item_id)

	if result >= 0:
		mark_item_as_taken_without_inventory(item_id)
		box.item_taken.emit(item_id)
		box.items_collected.emit([item_id])


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func mark_item_as_taken_without_inventory(item_id: String) -> void:
	box._collected_items[item_id] = box._collected_items.get(item_id, 0) + 1

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var all_done: bool = true

	for it in box.items_to_give:
		if not box._collected_items.has(it):
			all_done = false
			break

	if all_done:
		box._already_collected = true
		box._all_items_taken = true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_ghost_shelf() -> Shelf:
	for shelf in box.get_tree().get_nodes_in_group("shelves"):
		if shelf is Shelf and shelf.shelf_type == ItemData.ShelfType.GHOST:
			return shelf

	return null
