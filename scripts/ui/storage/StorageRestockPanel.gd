class_name StorageRestockPanel
extends RefCounted

const PANEL_TITLE_FONT_SIZE: int = 9
const PANEL_FONT_SIZE: int = 8
const PANEL_HINT_FONT_SIZE: int = 7


static func ensure(owner: Node) -> Dictionary:
	var layer := CanvasLayer.new()
	layer.name = "StorageRestockLayer"
	layer.layer = 20
	layer.visible = false
	owner.add_child(layer)

	var panel := ColorRect.new()
	panel.name = "StorageRestockPanel"
	panel.color = Color(0.1, 0.08, 0.07, 0.94)
	panel.visible = false
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24.0
	panel.offset_top = 62.0
	panel.offset_right = -24.0
	panel.offset_bottom = -10.0
	panel.clip_contents = true
	layer.add_child(panel)

	var root := VBoxContainer.new()
	root.name = "Content"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 10.0
	root.offset_top = 6.0
	root.offset_right = -10.0
	root.offset_bottom = -6.0
	root.add_theme_constant_override("separation", 3)
	root.clip_contents = true
	panel.add_child(root)

	var shell_title := Label.new()
	shell_title.text = "STORAGE OS"
	shell_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shell_title.add_theme_font_size_override("font_size", PANEL_TITLE_FONT_SIZE)
	root.add_child(shell_title)

	var title := Label.new()
	title.text = "STORAGE RESTOCK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", PANEL_TITLE_FONT_SIZE)
	root.add_child(title)

	var content_row := HBoxContainer.new()
	content_row.name = "RestockColumns"
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 4)
	content_row.clip_contents = true
	root.add_child(content_row)

	var item_column := VBoxContainer.new()
	item_column.custom_minimum_size = Vector2(168, 0)
	item_column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	item_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_column.add_theme_constant_override("separation", 2)
	item_column.clip_contents = true
	content_row.add_child(item_column)

	var item_title := Label.new()
	item_title.text = "ITEM LIST"
	item_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_title.add_theme_font_size_override("font_size", PANEL_FONT_SIZE)
	item_column.add_child(item_title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 76)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.follow_focus = true
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.clip_contents = true
	item_column.add_child(scroll)

	var item_margin := MarginContainer.new()
	item_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	item_margin.add_theme_constant_override("margin_right", 6)
	scroll.add_child(item_margin)

	var item_list := VBoxContainer.new()
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	item_list.add_theme_constant_override("separation", 2)
	item_margin.add_child(item_list)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.custom_minimum_size = Vector2(204, 76)
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	detail_scroll.follow_focus = true
	detail_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	detail_scroll.clip_contents = true
	content_row.add_child(detail_scroll)

	var detail_margin := MarginContainer.new()
	detail_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	detail_margin.add_theme_constant_override("margin_right", 6)
	detail_scroll.add_child(detail_margin)

	var detail_column := VBoxContainer.new()
	detail_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	detail_column.add_theme_constant_override("separation", 3)
	detail_column.clip_contents = true
	detail_margin.add_child(detail_column)

	var wallet_label := Label.new()
	wallet_label.add_theme_font_size_override("font_size", PANEL_FONT_SIZE)
	detail_column.add_child(wallet_label)

	var selected_label := Label.new()
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_label.add_theme_font_size_override("font_size", PANEL_FONT_SIZE)
	detail_column.add_child(selected_label)

	var guide_label := Label.new()
	guide_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_label.theme_type_variation = "SmallLabel"
	guide_label.max_lines_visible = 2
	guide_label.add_theme_font_size_override("font_size", PANEL_HINT_FONT_SIZE)
	detail_column.add_child(guide_label)

	var action_row := VBoxContainer.new()
	action_row.custom_minimum_size = Vector2(0, 42)
	action_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	action_row.add_theme_constant_override("separation", 2)
	detail_column.add_child(action_row)

	return {
		"layer": layer,
		"panel": panel,
		"item_list": item_list,
		"wallet_label": wallet_label,
		"selected_label": selected_label,
		"guide_label": guide_label,
		"action_row": action_row
	}


static func clear_container(container: Container) -> void:
	if container == null:
		return

	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
