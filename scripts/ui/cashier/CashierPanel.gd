class_name CashierPanel
extends RefCounted

const PANEL_TITLE_FONT_SIZE: int = 9
const PANEL_FONT_SIZE: int = 8
const PANEL_HINT_FONT_SIZE: int = 7


static func ensure(owner: Node) -> Dictionary:
	var cashier_layer := CanvasLayer.new()
	cashier_layer.name = "CashierUILayer"
	cashier_layer.layer = 20
	owner.add_child(cashier_layer)

	var cashier_panel := ColorRect.new()
	cashier_panel.name = "CashierPanel"
	cashier_panel.color = Color(0.12, 0.08, 0.05, 0.94)
	cashier_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cashier_panel.offset_left = 24.0
	cashier_panel.offset_top = 62.0
	cashier_panel.offset_right = -24.0
	cashier_panel.offset_bottom = -10.0
	cashier_panel.clip_contents = true
	cashier_layer.add_child(cashier_panel)

	var root := VBoxContainer.new()
	root.name = "Content"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 10.0
	root.offset_top = 6.0
	root.offset_right = -10.0
	root.offset_bottom = -6.0
	root.add_theme_constant_override("separation", 3)
	root.clip_contents = true
	cashier_panel.add_child(root)

	var shell_title := Label.new()
	shell_title.text = "STORE OS"
	shell_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shell_title.add_theme_font_size_override("font_size", PANEL_TITLE_FONT_SIZE)
	root.add_child(shell_title)

	var panel_title := Label.new()
	panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_title.add_theme_font_size_override("font_size", PANEL_TITLE_FONT_SIZE)
	root.add_child(panel_title)

	var content_row := HBoxContainer.new()
	content_row.name = "CheckoutColumns"
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 5)
	content_row.clip_contents = true
	root.add_child(content_row)

	var item_column := VBoxContainer.new()
	item_column.name = "ItemColumn"
	item_column.custom_minimum_size = Vector2(220, 0)
	item_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_column.add_theme_constant_override("separation", 2)
	item_column.clip_contents = true
	content_row.add_child(item_column)

	var item_title := Label.new()
	item_title.text = "ITEM LIST"
	item_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_title.theme_type_variation = "SmallLabel"
	item_title.add_theme_font_size_override("font_size", PANEL_FONT_SIZE)
	item_column.add_child(item_title)

	var scroll := ScrollContainer.new()
	scroll.name = "ItemScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Keep the item list's natural height so ScrollContainer can expose all rows.
	# An expanding child is otherwise allowed to match the viewport and its
	# overflow can be clipped without producing a usable vertical range.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.clip_contents = true
	item_column.add_child(scroll)

	var item_margin := MarginContainer.new()
	item_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	item_margin.add_theme_constant_override("margin_right", 10)
	scroll.add_child(item_margin)

	var item_list := VBoxContainer.new()
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	item_list.add_theme_constant_override("separation", 2)
	item_margin.add_child(item_list)

	var detail_column := VBoxContainer.new()
	detail_column.name = "DetailColumn"
	detail_column.custom_minimum_size = Vector2(166, 0)
	detail_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_column.add_theme_constant_override("separation", 3)
	detail_column.clip_contents = true
	content_row.add_child(detail_column)

	var customer_label := Label.new()
	customer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	customer_label.add_theme_font_size_override("font_size", PANEL_FONT_SIZE)
	detail_column.add_child(customer_label)

	var request_label := Label.new()
	request_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	request_label.theme_type_variation = "SmallLabel"
	request_label.add_theme_font_size_override("font_size", PANEL_FONT_SIZE)
	detail_column.add_child(request_label)

	var selected_label := Label.new()
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_label.add_theme_font_size_override("font_size", PANEL_FONT_SIZE)
	detail_column.add_child(selected_label)

	var guide_label := Label.new()
	guide_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_label.theme_type_variation = "SmallLabel"
	guide_label.max_lines_visible = 1
	guide_label.add_theme_font_size_override("font_size", PANEL_HINT_FONT_SIZE)
	detail_column.add_child(guide_label)

	var action_row := VBoxContainer.new()
	action_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	action_row.add_theme_constant_override("separation", 2)
	detail_column.add_child(action_row)

	return {
		"layer": cashier_layer,
		"panel": cashier_panel,
		"title": panel_title,
		"item_title": item_title,
		"customer_label": customer_label,
		"request_label": request_label,
		"selected_label": selected_label,
		"guide_label": guide_label,
		"action_row": action_row,
		"item_list": item_list
	}


static func clear_container(container: Container) -> void:
	if container == null:
		return

	for child in container.get_children():
		child.queue_free()
