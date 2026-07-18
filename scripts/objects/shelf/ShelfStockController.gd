class_name ShelfStockController
extends RefCounted

var shelf: Shelf = null


func setup(shelf_node: Shelf) -> void:
	shelf = shelf_node


func initialize_slots() -> void:
	shelf._slots.resize(shelf.max_slots)
	shelf._slots.fill(null)


func place_item(item_id: String) -> int:
	var item: ItemData = ItemDatabase.get_item(item_id)
	if item == null:
		push_warning("Shelf: item '%s' not found in database" % item_id)
		return -1

	if item.shelf_type != shelf.shelf_type:
		return -1

	var slot := get_empty_slot()
	if slot == -1:
		return -1

	if not Inventory.remove_item(item_id):
		return -1

	shelf._slots[slot] = item_id
	shelf._refresh_slot_visual(slot, item_id)
	shelf.item_placed.emit(slot, item_id)
	return slot


func stock_item_direct(item_id: String) -> int:
	var item: ItemData = ItemDatabase.get_item(item_id)
	if item == null:
		push_warning("Shelf: item '%s' not found in database" % item_id)
		return -1

	if item.shelf_type != shelf.shelf_type:
		return -1

	var slot := get_empty_slot()
	if slot == -1:
		return -1

	shelf._slots[slot] = item_id
	shelf._refresh_slot_visual(slot, item_id)
	shelf.item_placed.emit(slot, item_id)
	return slot


func remove_item(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= shelf._slots.size():
		return ""

	var item_id: String = shelf._slots[slot_index]
	if item_id == null:
		return ""

	shelf._slots[slot_index] = null
	shelf._refresh_slot_visual(slot_index, "")
	Inventory.add_item(item_id)
	shelf.item_removed.emit(slot_index, item_id)
	return item_id


func remove_first_item() -> String:
	for i in shelf._slots.size():
		if shelf._slots[i] != null:
			return remove_item(i)

	return ""


func take_item_for_npc(item_id: String) -> bool:
	for i in shelf._slots.size():
		if shelf._slots[i] == item_id:
			shelf._slots[i] = null
			shelf._refresh_slot_visual(i, "")
			shelf.item_removed.emit(i, item_id)
			return true
	return false


func has_item(item_id: String) -> bool:
	return shelf._slots.has(item_id)


func has_stock() -> bool:
	for item_id in shelf._slots:
		if item_id != null:
			return true

	return false


func get_first_stocked_item_id() -> String:
	for item_id in shelf._slots:
		if item_id != null:
			return item_id

	return ""


func get_slot_content(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= shelf._slots.size():
		return ""

	return shelf._slots[slot_index] if shelf._slots[slot_index] != null else ""


func get_empty_slot() -> int:
	for i in shelf._slots.size():
		if shelf._slots[i] == null:
			return i
	return -1
