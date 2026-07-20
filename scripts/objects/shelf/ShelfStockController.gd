class_name ShelfStockController
extends RefCounted

var shelf: Shelf = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(shelf_node: Shelf) -> void:
	shelf = shelf_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func initialize_slots() -> void:
	shelf._slots.resize(shelf.max_slots)
	shelf._slots.fill(null)
	shelf._slot_quantities.resize(shelf.max_slots)
	shelf._slot_quantities.fill(0)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func place_item(item_id: String) -> int:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item: ItemData = ItemDatabase.get_item(item_id)
	if item == null:
		pass
		return -1

	if item.shelf_type != shelf.shelf_type:
		return -1

	if not Inventory.remove_item(item_id):
		return -1

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var slot := find_item_slot(item_id)
	if slot == -1:
		slot = get_empty_slot()
		if slot == -1:
			Inventory.add_item(item_id)
			return -1

	shelf._slots[slot] = item_id
	shelf._slot_quantities[slot] += 1
	shelf._refresh_slot_visual(slot, item_id)
	shelf.item_placed.emit(slot, item_id)
	return slot


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func stock_item_direct(item_id: String) -> int:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item: ItemData = ItemDatabase.get_item(item_id)
	if item == null:
		pass
		return -1

	if item.shelf_type != shelf.shelf_type:
		return -1

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var slot := find_item_slot(item_id)
	if slot == -1:
		slot = get_empty_slot()
		if slot == -1:
			return -1

	shelf._slots[slot] = item_id
	shelf._slot_quantities[slot] += 1
	shelf._refresh_slot_visual(slot, item_id)
	shelf.item_placed.emit(slot, item_id)
	return slot


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func remove_item(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= shelf._slots.size():
		return ""

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item_id: String = shelf._slots[slot_index]
	if item_id == null:
		return ""

	shelf._slot_quantities[slot_index] -= 1
	if shelf._slot_quantities[slot_index] <= 0:
		shelf._slot_quantities[slot_index] = 0
		shelf._slots[slot_index] = null
	shelf._refresh_slot_visual(slot_index, "")
	Inventory.add_item(item_id)
	shelf.item_removed.emit(slot_index, item_id)
	return item_id


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func remove_first_item() -> String:
	for i in shelf._slots.size():
		if shelf._slots[i] != null:
			return remove_item(i)

	return ""


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func take_item_for_npc(item_id: String) -> bool:
	for i in shelf._slots.size():
		if shelf._slots[i] == item_id:
			shelf._slot_quantities[i] -= 1
			if shelf._slot_quantities[i] <= 0:
				shelf._slot_quantities[i] = 0
				shelf._slots[i] = null
			shelf._refresh_slot_visual(i, "")
			shelf.item_removed.emit(i, item_id)
			return true
	return false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func has_item(item_id: String) -> bool:
	return shelf._slots.has(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func has_stock() -> bool:
	for item_id in shelf._slots:
		if item_id != null:
			return true

	return false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_first_stocked_item_id() -> String:
	for item_id in shelf._slots:
		if item_id != null:
			return item_id

	return ""


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_slot_content(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= shelf._slots.size():
		return ""

	return shelf._slots[slot_index] if shelf._slots[slot_index] != null else ""


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_empty_slot() -> int:
	for i in shelf._slots.size():
		if shelf._slots[i] == null:
			return i
	return -1


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_item_slot(item_id: String) -> int:
	for i in shelf._slots.size():
		if shelf._slots[i] == item_id:
			return i

	return -1
