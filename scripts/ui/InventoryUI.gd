extends Control

const InventoryListRenderer = preload("res://scripts/ui/inventory/InventoryListRenderer.gd")

@onready var item_container: VBoxContainer = $Panel/VBoxContainer

var _list_renderer: InventoryListRenderer = InventoryListRenderer.new()


func _ready() -> void:
	_list_renderer.setup(self)
	_setup_style()

	if not Inventory.inventory_changed.is_connected(_on_inventory_changed):
		Inventory.inventory_changed.connect(_on_inventory_changed)

	_refresh()


func _setup_style() -> void:
	_list_renderer.setup_style()


func _on_inventory_changed(_item_id: String, _quantity: int) -> void:
	_refresh()


func _refresh() -> void:
	_list_renderer.refresh()
