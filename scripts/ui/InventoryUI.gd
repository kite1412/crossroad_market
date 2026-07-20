extends Control


@onready var item_container: VBoxContainer = $Panel/VBoxContainer

@warning_ignore("unused_private_class_variable")
var _list_renderer: InventoryListRenderer = InventoryListRenderer.new()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	_list_renderer.setup(self)
	_setup_style()

	if not Inventory.inventory_changed.is_connected(_on_inventory_changed):
		Inventory.inventory_changed.connect(_on_inventory_changed)

	_refresh()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _setup_style() -> void:
	_list_renderer.setup_style()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_inventory_changed(_item_id: String, _quantity: int) -> void:
	_refresh()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _refresh() -> void:
	_list_renderer.refresh()
