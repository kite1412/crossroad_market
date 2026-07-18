class_name InventoryListRenderer
extends RefCounted

var inventory_ui: Control = null


func setup(ui_node: Control) -> void:
	inventory_ui = ui_node


func setup_style() -> void:
	inventory_ui.item_container.add_theme_constant_override("separation", 4)


func refresh() -> void:
	for child in inventory_ui.item_container.get_children():
		child.queue_free()

	var items: Dictionary = Inventory.get_all()

	if items.is_empty():
		var empty_label := Label.new()
		empty_label.text = "(empty)"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		empty_label.add_theme_font_size_override("font_size", 10)
		empty_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		inventory_ui.item_container.add_child(empty_label)
		return

	for item_id in items:
		var quantity: int = items[item_id]
		var item_data: ItemData = ItemDatabase.get_item(item_id)
		var display_name: String = item_data.display_name if item_data else item_id

		var label := Label.new()
		label.text = "%s x%d" % [display_name, quantity]
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color.WHITE)

		inventory_ui.item_container.add_child(label)
