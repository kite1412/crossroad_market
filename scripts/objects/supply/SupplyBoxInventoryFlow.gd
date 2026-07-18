class_name SupplyBoxInventoryFlow
extends RefCounted

var supply_box: SupplyBox = null


func setup(supply_box_node: SupplyBox) -> void:
	supply_box = supply_box_node


func get_available_items() -> Array[String]:
	if supply_box.one_time_only and supply_box._already_collected:
		return []
	var available: Array[String] = []
	for item_id in supply_box.items_to_give:
		if not supply_box.one_time_only:
			available.append(item_id)
		elif not supply_box._collected_items.has(item_id):
			available.append(item_id)
	return available


func collect() -> Array[String]:
	if supply_box.one_time_only and supply_box._already_collected:
		return []

	supply_box._already_collected = true

	for item_id in supply_box.items_to_give:
		Inventory.add_item(item_id)

	supply_box.items_collected.emit(supply_box.items_to_give)
	return supply_box.items_to_give


func collect_one(item_id: String) -> bool:
	if item_id not in supply_box.items_to_give:
		return false

	if supply_box.one_time_only and supply_box._collected_items.has(item_id):
		return false

	Inventory.add_item(item_id)
	supply_box._collected_items[item_id] = supply_box._collected_items.get(item_id, 0) + 1
	supply_box.item_taken.emit(item_id)

	if supply_box.one_time_only:
		var all_done := true
		for it in supply_box.items_to_give:
			if not supply_box._collected_items.has(it):
				all_done = false
				break
		if all_done:
			supply_box._already_collected = true
			supply_box._all_items_taken = true
			supply_box.items_collected.emit(supply_box.items_to_give)

	return true


func mark_item_taken_without_inventory(item_id: String) -> void:
	if item_id not in supply_box.items_to_give:
		return

	supply_box._collected_items[item_id] = supply_box._collected_items.get(item_id, 0) + 1


func is_empty() -> bool:
	if not supply_box.one_time_only:
		return false
	if supply_box.one_time_only and supply_box._already_collected:
		return true
	for item_id in supply_box.items_to_give:
		if not supply_box._collected_items.has(item_id):
			return false
	return true


func is_all_taken() -> bool:
	return supply_box._all_items_taken


func mark_all_taken_without_inventory() -> void:
	for item_id in supply_box.items_to_give:
		mark_item_taken_without_inventory(item_id)

	if supply_box.one_time_only:
		supply_box._already_collected = true
		supply_box._all_items_taken = true
