class_name InventoryStore
extends RefCounted

var inventory: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(inventory_node: Node) -> void:
	inventory = inventory_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func add_item(item_id: String, amount: int = 1) -> void:
	inventory._items[item_id] = get_quantity(item_id) + amount
	inventory.inventory_changed.emit(item_id, inventory._items[item_id])


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func remove_item(item_id: String, amount: int = 1) -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var current: int = get_quantity(item_id)
	if current < amount:
		return false
	inventory._items[item_id] = current - amount
	if inventory._items[item_id] == 0:
		inventory._items.erase(item_id)
	inventory.inventory_changed.emit(item_id, get_quantity(item_id))
	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_quantity(item_id: String) -> int:
	return inventory._items.get(item_id, 0)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func has_item(item_id: String) -> bool:
	return get_quantity(item_id) > 0


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_all() -> Dictionary:
	return inventory._items.duplicate()
