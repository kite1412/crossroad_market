extends Node


@warning_ignore("unused_private_class_variable")
var _items: Dictionary[StringName, ItemData] = {}
@warning_ignore("unused_private_class_variable")
var _loader: ItemDatabaseLoader = ItemDatabaseLoader.new()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	_loader.setup(self)
	_load_items()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _load_items() -> void:
	_loader.load_items()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_item(item_id: String) -> ItemData:
	return _loader.get_item(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_all_items() -> Array[ItemData]:
	return _loader.get_all_items()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_items_by_shelf(shelf_type: ItemData.ShelfType) -> Array[ItemData]:
	return _loader.get_items_by_shelf(shelf_type)
