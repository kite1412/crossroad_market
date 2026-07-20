class_name SupplyBoxInventoryFlow
extends RefCounted

var supply_box: SupplyBox = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(supply_box_node: SupplyBox) -> void:
	supply_box = supply_box_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_available_items() -> Array[String]:
	if supply_box.one_time_only and supply_box._already_collected:
		return []

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var available: Array[String] = []
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var occurrence_counts: Dictionary = {}

	for item_id in supply_box.items_to_give:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var occurrence_index := int(occurrence_counts.get(item_id, 0))
		occurrence_counts[item_id] = occurrence_index + 1

		if not supply_box.one_time_only:
			available.append(item_id)
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var taken_count := int(supply_box._collected_items.get(item_id, 0))
		if occurrence_index >= taken_count:
			available.append(item_id)

	return available


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
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


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func collect_one(item_id: String) -> bool:
	if item_id not in supply_box.items_to_give:
		return false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var required_count := supply_box.items_to_give.count(item_id)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
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


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func mark_item_taken_without_inventory(item_id: String) -> void:
	if item_id not in supply_box.items_to_give:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var required_count := supply_box.items_to_give.count(item_id)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var taken_count := int(supply_box._collected_items.get(item_id, 0))
	if taken_count >= required_count:
		return

	supply_box._collected_items[item_id] = taken_count + 1


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_empty() -> bool:
	if not supply_box.one_time_only:
		return false
	if supply_box._already_collected:
		return true

	return _are_all_item_counts_taken()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_all_taken() -> bool:
	return supply_box._all_items_taken


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func mark_all_taken_without_inventory() -> void:
	_mark_all_item_counts_taken()

	if supply_box.one_time_only:
		supply_box._already_collected = true
		supply_box._all_items_taken = true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _are_all_item_counts_taken() -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var required_counts := _get_required_item_counts()

	for item_id in required_counts:
		if int(supply_box._collected_items.get(item_id, 0)) < int(required_counts[item_id]):
			return false

	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _mark_all_item_counts_taken() -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var required_counts := _get_required_item_counts()

	for item_id in required_counts:
		supply_box._collected_items[item_id] = int(required_counts[item_id])


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_required_item_counts() -> Dictionary:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var required_counts: Dictionary = {}

	for item_id in supply_box.items_to_give:
		required_counts[item_id] = int(required_counts.get(item_id, 0)) + 1

	return required_counts
