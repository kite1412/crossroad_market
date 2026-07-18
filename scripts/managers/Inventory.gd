extends Node

const InventoryStore = preload("res://scripts/managers/inventory/InventoryStore.gd")

signal inventory_changed(item_id: String, new_quantity: int)

var _items: Dictionary = {}
var _store: InventoryStore = InventoryStore.new()


func _ready() -> void:
	_store.setup(self)


func add_item(item_id: String, amount: int = 1) -> void:
	_store.add_item(item_id, amount)


func remove_item(item_id: String, amount: int = 1) -> bool:
	return _store.remove_item(item_id, amount)


func get_quantity(item_id: String) -> int:
	return _store.get_quantity(item_id)


func has_item(item_id: String) -> bool:
	return _store.has_item(item_id)


func get_all() -> Dictionary:
	return _store.get_all()
