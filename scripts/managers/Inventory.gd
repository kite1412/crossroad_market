extends Node


@warning_ignore("unused_signal")
signal inventory_changed(item_id: String, new_quantity: int)

@warning_ignore("unused_private_class_variable")
var _items: Dictionary = {}
@warning_ignore("unused_private_class_variable")
var _store: InventoryStore = InventoryStore.new()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	_store.setup(self)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func add_item(item_id: String, amount: int = 1) -> void:
	_store.add_item(item_id, amount)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func remove_item(item_id: String, amount: int = 1) -> bool:
	return _store.remove_item(item_id, amount)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_quantity(item_id: String) -> int:
	return _store.get_quantity(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func has_item(item_id: String) -> bool:
	return _store.has_item(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_all() -> Dictionary:
	return _store.get_all()
