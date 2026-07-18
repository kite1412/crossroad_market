extends Node

const ItemDatabaseLoader = preload("res://scripts/managers/items/ItemDatabaseLoader.gd")

var _items: Dictionary[StringName, ItemData] = {}
var _loader: ItemDatabaseLoader = ItemDatabaseLoader.new()


func _ready() -> void:
	_loader.setup(self)
	_load_items()


func _load_items() -> void:
	_loader.load_items()


func get_item(item_id: String) -> ItemData:
	return _loader.get_item(item_id)


func get_all_items() -> Array[ItemData]:
	return _loader.get_all_items()


func get_items_by_shelf(shelf_type: ItemData.ShelfType) -> Array[ItemData]:
	return _loader.get_items_by_shelf(shelf_type)
