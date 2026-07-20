class_name StorageRestockFlow
extends Node


const RESTOCK_SCROLL_STEP: int = 28
const RESTOCK_ACTION_BUTTON_HEIGHT: float = 20.0
const RESTOCK_CHECKOUT_BUTTON_WIDTH: float = 76.0
const RESTOCK_CLOSE_BUTTON_WIDTH: float = 56.0

var storage: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(storage_node: Node) -> void:
	storage = storage_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func open_restock_panel() -> void:
	storage._restock_checkout_completed_this_session = false
	storage.restock_panel_opened.emit()
	ensure_restock_panel()
	render_restock_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func ensure_restock_panel() -> void:
	if storage._restock_layer != null and is_instance_valid(storage._restock_layer):
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var panel_nodes := StorageRestockPanel.ensure(storage)
	storage._restock_layer = panel_nodes["layer"] as CanvasLayer
	storage._restock_panel = panel_nodes["panel"] as ColorRect
	storage._restock_item_list = panel_nodes["item_list"] as VBoxContainer
	storage._restock_wallet_label = panel_nodes["wallet_label"] as Label
	storage._restock_selected_label = panel_nodes["selected_label"] as Label
	storage._restock_guide_label = panel_nodes["guide_label"] as Label
	storage._restock_action_row = panel_nodes["action_row"] as Container


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func render_restock_panel() -> void:
	if storage._restock_panel == null:
		return

	if storage._restock_layer != null:
		storage._restock_layer.visible = true

	storage._restock_panel.visible = true
	StorageRestockPanel.clear_container(storage._restock_item_list)
	StorageRestockPanel.clear_container(storage._restock_action_row)
	update_restock_wallet()

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var items := get_restock_items()

	for item in items:
		if item == null:
			continue

		storage._restock_item_list.add_child(create_restock_item_row(item))

	if storage._selected_restock_item_id == "" and not items.is_empty():
		storage._selected_restock_item_id = items[0].item_id

	render_restock_detail()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func create_restock_item_row(item: ItemData) -> Control:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 19)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_theme_constant_override("separation", 1)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var select_button := Button.new()
	select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_button.custom_minimum_size = Vector2(82, 19)
	select_button.mouse_filter = Control.MOUSE_FILTER_STOP
	select_button.focus_mode = Control.FOCUS_ALL
	select_button.clip_text = true
	select_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	select_button.text = "%s  %dG" % [item.display_name, get_item_buy_cost(item)]
	select_button.add_theme_font_size_override("font_size", 7)
	select_button.pressed.connect(func() -> void:
		storage._selected_restock_item_id = item.item_id
		render_restock_panel()
	)
	connect_restock_scroll_forwarding(select_button)
	row.add_child(select_button)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var quantity_controls := HBoxContainer.new()
	quantity_controls.custom_minimum_size = Vector2(68, 19)
	quantity_controls.size_flags_horizontal = Control.SIZE_SHRINK_END
	quantity_controls.add_theme_constant_override("separation", 1)
	row.add_child(quantity_controls)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var minus_button := Button.new()
	minus_button.text = "-"
	minus_button.custom_minimum_size = Vector2(19, 19)
	minus_button.mouse_filter = Control.MOUSE_FILTER_STOP
	minus_button.focus_mode = Control.FOCUS_ALL
	minus_button.add_theme_font_size_override("font_size", 7)
	minus_button.pressed.connect(func() -> void:
		add_restock_cart_quantity(item.item_id, -1)
	)
	connect_restock_scroll_forwarding(minus_button)
	quantity_controls.add_child(minus_button)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var qty_label := Label.new()
	qty_label.custom_minimum_size = Vector2(26, 19)
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	qty_label.text = str(get_restock_cart_quantity(item.item_id))
	qty_label.add_theme_font_size_override("font_size", 7)
	quantity_controls.add_child(qty_label)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var plus_button := Button.new()
	plus_button.text = "+"
	plus_button.custom_minimum_size = Vector2(19, 19)
	plus_button.mouse_filter = Control.MOUSE_FILTER_STOP
	plus_button.focus_mode = Control.FOCUS_ALL
	plus_button.add_theme_font_size_override("font_size", 7)
	plus_button.pressed.connect(func() -> void:
		add_restock_cart_quantity(item.item_id, 1)
	)
	connect_restock_scroll_forwarding(plus_button)
	quantity_controls.add_child(plus_button)

	return row


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func render_restock_detail() -> void:
	StorageRestockPanel.clear_container(storage._restock_action_row)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item := ItemDatabase.get_item(storage._selected_restock_item_id)

	if item == null:
		storage._restock_selected_label.text = "Select an item."
		storage._restock_guide_label.text = ""
		add_restock_close_button()
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var buy_cost := get_item_buy_cost(item)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var shelf_label := "Ghost" if item.shelf_type == ItemData.ShelfType.GHOST else "Human"
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var cart_qty := get_restock_cart_quantity(item.item_id)
	storage._restock_selected_label.text = "%s\nShelf: %s\nBuy: %dG | In bag: %d\nCart: x%d | Subtotal: %dG" % [
		item.display_name,
		shelf_label,
		buy_cost,
		Inventory.get_quantity(item.item_id),
		cart_qty,
		cart_qty * buy_cost
	]
	storage._restock_guide_label.text = "Checkout sends one delivery box outside in the yard."

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var summary_label := Label.new()
	summary_label.text = format_restock_cart_summary()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.max_lines_visible = 2
	summary_label.add_theme_font_size_override("font_size", 7)
	storage._restock_action_row.add_child(summary_label)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var total_label := Label.new()
	total_label.text = "Cart Total: %dG" % get_restock_cart_total()
	total_label.add_theme_font_size_override("font_size", 8)
	storage._restock_action_row.add_child(total_label)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var checkout_button := Button.new()
	checkout_button.text = "Checkout"
	configure_restock_action_button(checkout_button, RESTOCK_CHECKOUT_BUTTON_WIDTH)
	checkout_button.disabled = not has_restock_cart_items()
	checkout_button.pressed.connect(checkout_restock_cart)
	connect_restock_scroll_forwarding(checkout_button)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var close_button := create_restock_close_button()
	add_restock_action_button_row([checkout_button, close_button])


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func add_restock_close_button() -> void:
	add_restock_action_button_row([create_restock_close_button()])


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func create_restock_close_button() -> Button:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var close_button := Button.new()
	close_button.text = "Close"
	configure_restock_action_button(close_button, RESTOCK_CLOSE_BUTTON_WIDTH)
	close_button.pressed.connect(hide_restock_panel)
	connect_restock_scroll_forwarding(close_button)
	return close_button


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func configure_restock_action_button(button: Button, width: float) -> void:
	button.custom_minimum_size = Vector2(width, RESTOCK_ACTION_BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", 8)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func add_restock_action_button_row(buttons: Array[Button]) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 2)
	storage._restock_action_row.add_child(row)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	for button in buttons:
		row.add_child(button)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func add_restock_cart_quantity(item_id: String, delta: int) -> void:
	if item_id == "" or delta == 0:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var quantity := get_restock_cart_quantity(item_id) + delta

	if quantity <= 0:
		storage._restock_cart.erase(item_id)
	else:
		storage._restock_cart[item_id] = quantity

	storage._selected_restock_item_id = item_id
	render_restock_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func checkout_restock_cart() -> void:
	if not has_restock_cart_items():
		storage._show_notification("Add items to the cart first.", 0.9)
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var total := get_restock_cart_total()

	if total <= 0:
		storage._show_notification("Add items to the cart first.", 0.9)
		return

	if not EconomyManager.spend_gold(total):
		storage._show_notification("Not enough gold.", 0.9)
		render_restock_panel()
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var order_items := get_restock_cart_order_items()
	storage._restock_cart.clear()
	storage.restock_order_purchased.emit(order_items)
	storage._restock_checkout_completed_this_session = true
	storage._show_notification("Restock ordered. Pick it up in the yard.", 1.2)
	render_restock_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_restock_cart_quantity(item_id: String) -> int:
	return int(storage._restock_cart.get(item_id, 0))


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func connect_restock_scroll_forwarding(control: Control) -> void:
	control.gui_input.connect(func(event: InputEvent) -> void:
		forward_restock_scroll_input(event, control)
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func forward_restock_scroll_input(event: InputEvent, from_control: Control) -> void:
	if not (event is InputEventMouseButton):
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var mouse_event := event as InputEventMouseButton

	if not mouse_event.pressed:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var direction := 0

	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		direction = -1
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		direction = 1

	if direction == 0:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var scroll := find_parent_scroll_container(from_control)

	if scroll == null:
		return

	scroll.scroll_vertical += direction * RESTOCK_SCROLL_STEP
	storage.get_viewport().set_input_as_handled()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_parent_scroll_container(from_control: Control) -> ScrollContainer:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var node: Node = from_control

	while node != null:
		if node is ScrollContainer:
			return node as ScrollContainer

		node = node.get_parent()

	return null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func has_restock_cart_items() -> bool:
	for item_id in storage._restock_cart.keys():
		if int(storage._restock_cart[item_id]) > 0:
			return true

	return false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func format_restock_cart_summary() -> String:
	if not has_restock_cart_items():
		return "Cart: empty"

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var parts: Array[String] = []

	for item_id in storage._restock_cart.keys():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var quantity := int(storage._restock_cart[item_id])

		if quantity <= 0:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var item := ItemDatabase.get_item(str(item_id))
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var item_name := str(item_id)

		if item != null:
			item_name = item.display_name

		parts.append("%s x%d" % [item_name, quantity])

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var packed_parts := PackedStringArray(parts)
	return "Cart: %s" % ", ".join(packed_parts)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_restock_cart_total() -> int:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var total := 0

	for item_id in storage._restock_cart.keys():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var item := ItemDatabase.get_item(str(item_id))

		if item == null:
			continue

		total += get_item_buy_cost(item) * int(storage._restock_cart[item_id])

	return total


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_restock_cart_order_items() -> Array[Dictionary]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var order_items: Array[Dictionary] = []

	for item_id in storage._restock_cart.keys():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var quantity := int(storage._restock_cart[item_id])

		if quantity <= 0:
			continue

		order_items.append({
			"item_id": str(item_id),
			"quantity": quantity
		})

	return order_items


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func hide_restock_panel() -> void:
	if storage._restock_panel != null:
		storage._restock_panel.visible = false

	if storage._restock_layer != null:
		storage._restock_layer.visible = false

	storage.restock_panel_closed.emit(storage._restock_checkout_completed_this_session)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_restock_items() -> Array[ItemData]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var items: Array[ItemData] = []

	for item in ItemDatabase.get_all_items():
		if item == null:
			continue

		if item.shelf_type == ItemData.ShelfType.GHOST and not storage._mystery_phase_unlocked:
			continue

		items.append(item)

	items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		if a.shelf_type != b.shelf_type:
			return int(a.shelf_type) < int(b.shelf_type)

		return a.display_name < b.display_name
	)
	return items


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_item_buy_cost(item: ItemData) -> int:
	if item.buy_cost > 0:
		return item.buy_cost

	return maxi(1, ceili(float(item.sell_price) * 0.5))


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func update_restock_wallet() -> void:
	if storage._restock_wallet_label != null:
		storage._restock_wallet_label.text = "Wallet: %dG" % EconomyManager.gold


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_gold_changed(_amount: int) -> void:
	update_restock_wallet()
