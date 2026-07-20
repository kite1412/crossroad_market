class_name SupplyBoxInventoryFlow
extends RefCounted

var supply_box: SupplyBox = null


func setup(supply_box_node: SupplyBox) -> void:
	supply_box = supply_box_node


func get_available_items() -> Array[String]:
	if supply_box.one_time_only and supply_box._already_collected:
		return []

	var available: Array[String] = []
	var occurrence_counts: Dictionary = {}

	for item_id in supply_box.items_to_give:
		var occurrence_index := int(occurrence_counts.get(item_id, 0))
		occurrence_counts[item_id] = occurrence_index + 1

		if not supply_box.one_time_only:
			available.append(item_id)
			continue

		var taken_count := int(supply_box._collected_items.get(item_id, 0))
		if occurrence_index >= taken_count:
			available.append(item_id)

	return available


func collect() -> Array[String]:
	if supply_box.one_time_only and supply_box._already_collected:
		return []

	for item_id in supply_box.items_to_give:
		Inventory.add_item(item_id)

	if supply_box.one_time_only:
		_mark_all_item_counts_taken()
		supply_box._already_collected = true
		supply_box._all_items_taken = true

	supply_box.items_collected.emit(supply_box.items_to_give)
	return supply_box.items_to_give


func collect_one(item_id: String) -> bool:
	if item_id not in supply_box.items_to_give:
		return false

	var required_count := supply_box.items_to_give.count(item_id)
	var taken_count := int(supply_box._collected_items.get(item_id, 0))

	if supply_box.one_time_only and taken_count >= required_count:
		return false

	Inventory.add_item(item_id)
	supply_box._collected_items[item_id] = taken_count + 1
	supply_box.item_taken.emit(item_id)

	if supply_box.one_time_only and _are_all_item_counts_taken():
		supply_box._already_collected = true
		supply_box._all_items_taken = true
		supply_box.items_collected.emit(supply_box.items_to_give)

	return true


func mark_item_taken_without_inventory(item_id: String) -> void:
	if item_id not in supply_box.items_to_give:
		return

	var required_count := supply_box.items_to_give.count(item_id)
	var taken_count := int(supply_box._collected_items.get(item_id, 0))
	if taken_count >= required_count:
		return

	supply_box._collected_items[item_id] = taken_count + 1


func is_empty() -> bool:
	if not supply_box.one_time_only:
		return false
	if supply_box._already_collected:
		return true

	return _are_all_item_counts_taken()


func is_all_taken() -> bool:
	return supply_box._all_items_taken


func mark_all_taken_without_inventory() -> void:
	_mark_all_item_counts_taken()

	if supply_box.one_time_only:
		supply_box._already_collected = true
		supply_box._all_items_taken = true


func _are_all_item_counts_taken() -> bool:
	var required_counts := _get_required_item_counts()

	for item_id in required_counts:
		if int(supply_box._collected_items.get(item_id, 0)) < int(required_counts[item_id]):
			return false

	return true


func _mark_all_item_counts_taken() -> void:
	var required_counts := _get_required_item_counts()

	for item_id in required_counts:
		supply_box._collected_items[item_id] = int(required_counts[item_id])


func _get_required_item_counts() -> Dictionary:
	var required_counts: Dictionary = {}

	for item_id in supply_box.items_to_give:
		required_counts[item_id] = int(required_counts.get(item_id, 0)) + 1

	return required_counts
