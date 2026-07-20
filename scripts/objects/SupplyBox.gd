class_name SupplyBox
extends Node2D


@export var items_to_give: Array[String] = []
@export var one_time_only: bool = true

@warning_ignore("unused_signal")
signal items_collected(item_ids: Array[String])
@warning_ignore("unused_signal")
signal item_taken(item_id: String)

@warning_ignore("unused_private_class_variable")
var _already_collected: bool = false
@warning_ignore("unused_private_class_variable")
var _collected_items: Dictionary = {}
@warning_ignore("unused_private_class_variable")
var _all_items_taken: bool = false

@warning_ignore("unused_private_class_variable")
var _inventory_flow: SupplyBoxInventoryFlow = SupplyBoxInventoryFlow.new()
@warning_ignore("unused_private_class_variable")
var _presentation: SupplyBoxPresentation = SupplyBoxPresentation.new()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	_setup_supply_box_controllers()
	_setup_cursor_hover()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _setup_supply_box_controllers() -> void:
	_inventory_flow.setup(self)
	_presentation.setup(self)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_available_items() -> Array[String]:
	return _inventory_flow.get_available_items()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func collect() -> Array[String]:
	return _inventory_flow.collect()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func collect_one(item_id: String) -> bool:
	return _inventory_flow.collect_one(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func mark_item_taken_without_inventory(item_id: String) -> void:
	_inventory_flow.mark_item_taken_without_inventory(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_empty() -> bool:
	return _inventory_flow.is_empty()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_all_taken() -> bool:
	return _inventory_flow.is_all_taken()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func mark_all_taken_without_inventory() -> void:
	_inventory_flow.mark_all_taken_without_inventory()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_hover_display_name() -> String:
	return _presentation.get_hover_display_name()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _setup_cursor_hover() -> void:
	_presentation.setup_cursor_hover()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_cursor_mouse_entered() -> void:
	_presentation.on_cursor_mouse_entered()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_cursor_mouse_exited() -> void:
	_presentation.on_cursor_mouse_exited()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_cursor_tooltip(text: String) -> void:
	_presentation.show_cursor_tooltip(text)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _hide_cursor_tooltip() -> void:
	_presentation.hide_cursor_tooltip()
