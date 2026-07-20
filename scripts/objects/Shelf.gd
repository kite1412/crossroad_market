class_name Shelf
extends Node2D

const ShelfStockController = preload("res://scripts/objects/shelf/ShelfStockController.gd")
const ShelfVisualController = preload("res://scripts/objects/shelf/ShelfVisualController.gd")
const ShelfHoverController = preload("res://scripts/objects/shelf/ShelfHoverController.gd")

@export var shelf_type: ItemData.ShelfType = ItemData.ShelfType.HUMAN
@export var max_slots: int = 9

signal item_placed(slot_index: int, item_id: String)
signal item_removed(slot_index: int, item_id: String)

var _slots: Array = []
var _slot_quantities: Array[int] = []
var _is_shelf_hovered: bool = false

var _stock_controller: ShelfStockController = ShelfStockController.new()
var _visual_controller: ShelfVisualController = ShelfVisualController.new()
var _hover_controller: ShelfHoverController = ShelfHoverController.new()


func _ready() -> void:
	_setup_shelf_controllers()
	y_sort_enabled = false
	_stock_controller.initialize_slots()
	_apply_shelf_color()
	_setup_cursor_hover()


func _setup_shelf_controllers() -> void:
	_stock_controller.setup(self)
	_visual_controller.setup(self)
	_hover_controller.setup(self)


func _apply_shelf_color() -> void:
	_visual_controller.apply_shelf_color()


func apply_ghost_glow(enabled: bool) -> void:
	_visual_controller.apply_ghost_glow(enabled)


func place_item(item_id: String) -> int:
	return _stock_controller.place_item(item_id)


func stock_item_direct(item_id: String) -> int:
	return _stock_controller.stock_item_direct(item_id)


func remove_item(slot_index: int) -> String:
	return _stock_controller.remove_item(slot_index)


func remove_first_item() -> String:
	return _stock_controller.remove_first_item()


func take_item_for_npc(item_id: String) -> bool:
	return _stock_controller.take_item_for_npc(item_id)


func has_item(item_id: String) -> bool:
	return _stock_controller.has_item(item_id)


func has_stock() -> bool:
	return _stock_controller.has_stock()


func get_first_stocked_item_id() -> String:
	return _stock_controller.get_first_stocked_item_id()


func get_slot_content(slot_index: int) -> String:
	return _stock_controller.get_slot_content(slot_index)


func get_hover_display_name() -> String:
	match shelf_type:
		ItemData.ShelfType.GHOST:
			return "Ghost Shelf"
		_:
			return "Human Shelf"


func _get_empty_slot() -> int:
	return _stock_controller.get_empty_slot()


func _apply_visual_tint(color: Color) -> void:
	_visual_controller.apply_visual_tint(color)


func _refresh_slot_visual(slot_index: int, item_id: String) -> void:
	_visual_controller.refresh_slot_visual(slot_index, item_id)


func _setup_cursor_hover() -> void:
	_hover_controller.setup_cursor_hover()


func _on_shelf_mouse_entered() -> void:
	_hover_controller.on_shelf_mouse_entered()


func _on_shelf_mouse_exited() -> void:
	_hover_controller.on_shelf_mouse_exited()


func _on_slot_mouse_entered(slot_index: int) -> void:
	_hover_controller.on_slot_mouse_entered(slot_index)


func _on_slot_mouse_exited() -> void:
	_hover_controller.on_slot_mouse_exited()


func _get_slot_hover_name(slot_index: int) -> String:
	return _hover_controller.get_slot_hover_name(slot_index)


func _show_cursor_tooltip(text: String) -> void:
	_hover_controller.show_cursor_tooltip(text)


func _hide_cursor_tooltip() -> void:
	_hover_controller.hide_cursor_tooltip()
