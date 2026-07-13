class_name CashierPanel
extends RefCounted


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
	cashier_panel.offset_bottom = -20.0
	cashier_layer.add_child(cashier_panel)

	var root := VBoxContainer.new()
	root.name = "Content"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 8.0
	root.offset_top = 4.0
	root.offset_right = -8.0
	root.offset_bottom = -4.0
	root.add_theme_constant_override("separation", 3)
	cashier_panel.add_child(root)

	var panel_title := Label.new()
	panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(panel_title)

	var customer_label := Label.new()
	root.add_child(customer_label)

	var request_label := Label.new()
	request_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	request_label.theme_type_variation = "SmallLabel"
	root.add_child(request_label)

	var selected_label := Label.new()
	root.add_child(selected_label)

	var guide_label := Label.new()
	guide_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_label.theme_type_variation = "SmallLabel"
	root.add_child(guide_label)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 4)
	root.add_child(action_row)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 54)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var item_list := VBoxContainer.new()
	scroll.add_child(item_list)

	return {
		"layer": cashier_layer,
		"panel": cashier_panel,
		"title": panel_title,
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
