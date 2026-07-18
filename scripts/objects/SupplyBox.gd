class_name SupplyBox
extends Node2D

const SupplyBoxInventoryFlow = preload("res://scripts/objects/supply/SupplyBoxInventoryFlow.gd")
const SupplyBoxPresentation = preload("res://scripts/objects/supply/SupplyBoxPresentation.gd")

@export var items_to_give: Array[String] = []
@export var one_time_only: bool = true

signal items_collected(item_ids: Array[String])
signal item_taken(item_id: String)

var _already_collected: bool = false
var _collected_items: Dictionary = {}
var _all_items_taken: bool = false

var _inventory_flow: SupplyBoxInventoryFlow = SupplyBoxInventoryFlow.new()
var _presentation: SupplyBoxPresentation = SupplyBoxPresentation.new()


func _ready() -> void:
	_setup_supply_box_controllers()
	_setup_cursor_hover()


func _setup_supply_box_controllers() -> void:
	_inventory_flow.setup(self)
	_presentation.setup(self)


func get_available_items() -> Array[String]:
	return _inventory_flow.get_available_items()


func collect() -> Array[String]:
	return _inventory_flow.collect()


func collect_one(item_id: String) -> bool:
	return _inventory_flow.collect_one(item_id)


func mark_item_taken_without_inventory(item_id: String) -> void:
	_inventory_flow.mark_item_taken_without_inventory(item_id)


func is_empty() -> bool:
	return _inventory_flow.is_empty()


func is_all_taken() -> bool:
	return _inventory_flow.is_all_taken()


func mark_all_taken_without_inventory() -> void:
	_inventory_flow.mark_all_taken_without_inventory()


func get_hover_display_name() -> String:
	return _presentation.get_hover_display_name()


func _setup_cursor_hover() -> void:
	_presentation.setup_cursor_hover()


func _on_cursor_mouse_entered() -> void:
	_presentation.on_cursor_mouse_entered()


func _on_cursor_mouse_exited() -> void:
	_presentation.on_cursor_mouse_exited()


func _show_cursor_tooltip(text: String) -> void:
	_presentation.show_cursor_tooltip(text)


func _hide_cursor_tooltip() -> void:
	_presentation.hide_cursor_tooltip()
