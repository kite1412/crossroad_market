class_name CashierStoreOSRenderer
extends RefCounted

var cashier: Cashier = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(cashier_node: Cashier) -> void:
	cashier = cashier_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func render_store_os_home(
	status_text: String = "No customer at checkout.",
	guide_text: String = "Use POS when a customer arrives."
) -> void:
	ensure_cashier_panel()
	cashier._set_store_os_app(cashier.STORE_OS_APP_POS)
	clear_container(cashier._item_list)
	clear_container(cashier._action_row)
	cashier._lock_player_actions()

	cashier._cashier_panel.visible = true
	cashier._panel_title.text = "POS APP"
	set_item_title("ITEM LIST")
	cashier._customer_label.text = "Customer: -"
	cashier._request_label.text = status_text
	cashier._selected_label.text = "Cart: - | Total 0G"
	cashier._guide_label.visible = true
	cashier._guide_label.text = guide_text

	for item in cashier._get_store_items():
		if item != null:
			cashier._item_list.add_child(create_catalog_item_row(item))

	add_cashier_action_button(
		"Close OS",
		cashier.CASHIER_CLOSE_BUTTON_WIDTH,
		"Close Store OS.",
		Callable(cashier, "_close_store_os")
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func render_pos_app() -> void:
	if not cashier._has_scanned_customer():
		render_empty_pos_app()
	elif cashier._scanned_total > 0:
		show_paid_panel()
	else:
		show_scan_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_scan_panel() -> void:
	ensure_cashier_panel()
	cashier._set_store_os_app(cashier.STORE_OS_APP_POS)
	clear_container(cashier._item_list)
	clear_container(cashier._action_row)
	cashier._lock_player_actions()

	cashier._cashier_panel.visible = true
	cashier._panel_title.text = "CHECKOUT"
	set_item_title("ITEM LIST")
	cashier._customer_label.text = "Customer: %s" % cashier._get_scanned_customer_name()
	cashier._request_label.text = cashier._get_ask_again_panel_text()
	cashier._set_panel_guidance_once(
		"scan",
		"Select an item, add it to cart, then confirm."
	)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var store_items: Array[ItemData] = cashier._get_store_items()

	for item in store_items:
		if item == null:
			continue

		cashier._item_list.add_child(create_scan_item_row(item))

	add_cashier_action_button(
		"Add Item",
		cashier.CASHIER_SECONDARY_BUTTON_WIDTH,
		"Add the selected item to the cart.",
		Callable(cashier, "_on_add_item_pressed")
	)

	add_cart_rows_to_panel()

	add_cashier_action_button(
		"Confirm Cart",
		cashier.CASHIER_PRIMARY_BUTTON_WIDTH,
		"Check the cart against the customer's request.",
		Callable(cashier, "_on_confirm_scan_pressed")
	)

	add_cashier_action_button(
		"Ask Again %d/2" % cashier._ask_again_count,
		cashier.CASHIER_SECONDARY_BUTTON_WIDTH,
		"Repeat the customer's request. After 3 asks, they leave.",
		Callable(cashier, "_on_ask_again_pressed")
	)

	add_app_navigation_buttons()

	cashier._update_selected_label()

	cashier._item_list.queue_sort()
	cashier._item_scroll.queue_sort()
	cashier.call_deferred("_refresh_cashier_item_scroll")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func add_cart_rows_to_panel() -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var pending_label := Label.new()
	pending_label.text = "Selected Item: %s" % cashier._get_pending_item_label()
	pending_label.add_theme_font_size_override("font_size", cashier.CASHIER_BUTTON_FONT_SIZE)
	pending_label.clip_text = true
	pending_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cashier._action_row.add_child(pending_label)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var cart_title := Label.new()
	cart_title.text = "Cart"
	cart_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cart_title.add_theme_font_size_override("font_size", cashier.CASHIER_BUTTON_FONT_SIZE)
	cashier._action_row.add_child(cart_title)

	if cashier._cart_quantities.is_empty():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var empty_label := Label.new()
		empty_label.text = "(empty)"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", cashier.CASHIER_BUTTON_FONT_SIZE)
		cashier._action_row.add_child(empty_label)
	else:
		for item_id in cashier._get_cart_item_ids_ordered():
			cashier._action_row.add_child(create_cart_row(item_id))

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var total_label := Label.new()
	total_label.text = "Total: %dG" % cashier._calculate_selected_total()
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_label.add_theme_font_size_override("font_size", cashier.CASHIER_BUTTON_FONT_SIZE)
	cashier._action_row.add_child(total_label)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func create_cart_row(item_id: String) -> Control:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 3)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item_label := Label.new()
	item_label.text = cashier._get_cart_row_label(item_id)
	item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_label.add_theme_font_size_override("font_size", cashier.CASHIER_BUTTON_FONT_SIZE)
	item_label.clip_text = true
	item_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(item_label)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var plus_button := Button.new()
	plus_button.text = "+"
	plus_button.custom_minimum_size = Vector2(22, cashier.CASHIER_BUTTON_MIN_HEIGHT)
	plus_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	cashier._configure_button_guidance(plus_button, "Add one more of this item.")
	plus_button.pressed.connect(Callable(cashier, "_on_increment_cart_item_pressed").bind(item_id))
	row.add_child(plus_button)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var minus_button := Button.new()
	minus_button.text = "-"
	minus_button.custom_minimum_size = Vector2(22, cashier.CASHIER_BUTTON_MIN_HEIGHT)
	minus_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	cashier._configure_button_guidance(minus_button, "Remove one quantity of this item.")
	minus_button.pressed.connect(Callable(cashier, "_on_decrement_cart_item_pressed").bind(item_id))
	row.add_child(minus_button)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var delete_button := Button.new()
	delete_button.text = "Del"
	delete_button.custom_minimum_size = Vector2(34, cashier.CASHIER_BUTTON_MIN_HEIGHT)
	delete_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	cashier._configure_button_guidance(delete_button, "Remove this item row from the cart.")
	delete_button.pressed.connect(Callable(cashier, "_on_delete_cart_item_pressed").bind(item_id))
	row.add_child(delete_button)

	return row


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_paid_panel() -> void:
	if cashier._is_story_gift_checkout():
		show_gooby_choice_panel()
		return

	ensure_cashier_panel()
	cashier._set_store_os_app(cashier.STORE_OS_APP_POS)
	clear_container(cashier._item_list)
	clear_container(cashier._action_row)
	cashier._lock_player_actions()

	cashier._cashier_panel.visible = true
	cashier._panel_title.text = "PAID"
	set_item_title("ITEM LIST")
	cashier._customer_label.text = "Customer: %s" % cashier._get_scanned_customer_name()
	cashier._request_label.text = cashier._get_ask_again_panel_text()
	cashier._selected_label.text = "Cart: %s | Total %dG" % [cashier._scanned_item_label, cashier._scanned_total]
	cashier._set_panel_guidance_once(
		"paid",
		"Receive Payment finishes this paid checkout. Back to Scan lets you correct the selected item."
	)

	add_cashier_action_button(
		"Receive Payment",
		cashier.CASHIER_PRIMARY_BUTTON_WIDTH,
		"Finish checkout and add this sale to revenue.",
		Callable(cashier, "_process_paid")
	)

	add_cashier_action_button(
		"Back to Scan Items",
		cashier.CASHIER_SECONDARY_BUTTON_WIDTH,
		"Return to item selection and correct the scan.",
		Callable(cashier, "_show_scan_panel")
	)

	add_app_navigation_buttons()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_gooby_choice_panel() -> void:
	ensure_cashier_panel()
	cashier._set_store_os_app(cashier.STORE_OS_APP_POS)
	clear_container(cashier._item_list)
	clear_container(cashier._action_row)
	cashier._lock_player_actions()

	cashier._cashier_panel.visible = true
	cashier._panel_title.text = "GOOBY REQUEST"
	set_item_title("ITEM LIST")
	cashier._customer_label.text = "Customer: %s" % cashier._get_scanned_customer_name()
	cashier._request_label.text = cashier._get_ask_again_panel_text()
	cashier._selected_label.text = "Item: %s | Revenue: 0G" % cashier._scanned_item_label
	cashier._set_panel_guidance_once(
		"gooby_choice",
		"Give Item improves trust with no gold. Refuse Sale returns the item and continues the night consequence."
	)

	add_cashier_action_button(
		"Give Item (+Trust, +0G)",
		cashier.CASHIER_PRIMARY_BUTTON_WIDTH,
		"Give Gooby the item, gain trust, and earn no revenue.",
		Callable(cashier, "_process_gooby_gift")
	)

	add_cashier_action_button(
		"Refuse Sale (Return Item)",
		cashier.CASHIER_PRIMARY_BUTTON_WIDTH,
		"Return the item and continue the night consequence.",
		Callable(cashier, "_process_gooby_refuse")
	)

	add_cashier_action_button(
		"Back to Scan Items",
		cashier.CASHIER_SECONDARY_BUTTON_WIDTH,
		"Return to item selection before deciding.",
		Callable(cashier, "_show_scan_panel")
	)

	add_app_navigation_buttons()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_store_os_app(app_id: StringName) -> void:
	cashier._active_store_os_app = app_id


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_item_title(text: String) -> void:
	if cashier._item_title == null:
		return

	cashier._item_title.text = text


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func refresh_cashier_item_scroll() -> void:
	if cashier._item_list == null or cashier._item_scroll == null:
		return

	cashier._item_list.queue_sort()
	cashier._item_scroll.queue_sort()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func render_empty_pos_app() -> void:
	ensure_cashier_panel()
	cashier._set_store_os_app(cashier.STORE_OS_APP_POS)
	clear_container(cashier._item_list)
	clear_container(cashier._action_row)
	cashier._lock_player_actions()

	cashier._cashier_panel.visible = true
	cashier._panel_title.text = "POS APP"
	set_item_title("ITEM LIST")
	cashier._customer_label.text = "Customer: -"
	cashier._request_label.text = "No customer at checkout."
	cashier._selected_label.text = "Cart: - | Total 0G"
	cashier._guide_label.visible = true
	cashier._guide_label.text = "Wait for a customer, then press E at the cashier."

	for item in cashier._get_store_items():
		if item != null:
			cashier._item_list.add_child(create_catalog_item_row(item))

	add_app_navigation_buttons()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func create_scan_item_row(item: ItemData) -> Control:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = cashier.ITEM_SWATCH_SIZE
	swatch.color = cashier._get_item_shelf_color(item)
	row.add_child(swatch)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var button := Button.new()
	button.text = "%s  %dG" % [item.display_name, item.sell_price]
	button.custom_minimum_size = Vector2(0, cashier.CASHIER_BUTTON_MIN_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cashier._configure_button_guidance(button, "Select this item before adding it to the cart.")
	button.toggle_mode = true
	button.button_pressed = item.item_id == cashier._pending_item_id
	button.pressed.connect(Callable(cashier, "_on_scan_item_pressed").bind(item.item_id))
	row.add_child(button)
	if item.item_id == cashier._pending_item_id:
		button.call_deferred("grab_focus")
		cashier._item_scroll.call_deferred("ensure_control_visible", button)

	return row


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func create_catalog_item_row(item: ItemData) -> Control:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = cashier.ITEM_SWATCH_SIZE
	swatch.color = cashier._get_item_shelf_color(item)
	row.add_child(swatch)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var label := Label.new()
	label.text = "%s  %dG" % [item.display_name, item.sell_price]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", cashier.CASHIER_BUTTON_FONT_SIZE)
	row.add_child(label)

	return row


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func add_app_navigation_buttons() -> void:
	add_cashier_action_button(
		"Close OS",
		cashier.CASHIER_CLOSE_BUTTON_WIDTH,
		"Close Store OS.",
		Callable(cashier, "_close_store_os")
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func close_store_os() -> void:
	hide_cashier_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func ensure_cashier_panel() -> void:
	if cashier._cashier_layer != null and is_instance_valid(cashier._cashier_layer):
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var panel_nodes := CashierPanel.ensure(cashier)
	cashier._cashier_layer = panel_nodes["layer"] as CanvasLayer
	cashier._cashier_panel = panel_nodes["panel"] as ColorRect
	cashier._panel_title = panel_nodes["title"] as Label
	cashier._item_title = panel_nodes["item_title"] as Label
	cashier._customer_label = panel_nodes["customer_label"] as Label
	cashier._request_label = panel_nodes["request_label"] as Label
	cashier._selected_label = panel_nodes["selected_label"] as Label
	cashier._guide_label = panel_nodes["guide_label"] as Label
	cashier._action_row = panel_nodes["action_row"] as Container
	cashier._item_list = panel_nodes["item_list"] as VBoxContainer
	cashier._item_scroll = panel_nodes["item_scroll"] as ScrollContainer
	cashier._patience_bar = panel_nodes["patience_bar"] as ProgressBar


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_panel_guidance_once(key: String, text: String) -> void:
	if cashier._guide_label == null:
		return

	if cashier._seen_panel_guidance.has(key):
		cashier._guide_label.visible = false
		cashier._guide_label.text = ""
		return

	cashier._seen_panel_guidance[key] = true
	cashier._guide_label.visible = true
	cashier._guide_label.text = text


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func configure_button_guidance(button: Button, tooltip: String) -> void:
	if button == null:
		return

	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", cashier.CASHIER_BUTTON_FONT_SIZE)

	if button.custom_minimum_size.y < cashier.CASHIER_BUTTON_MIN_HEIGHT:
		button.custom_minimum_size.y = cashier.CASHIER_BUTTON_MIN_HEIGHT


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func add_cashier_action_button(text: String, width: float, tooltip: String, pressed: Callable) -> Button:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 2)
	cashier._action_row.add_child(row)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, cashier.CASHIER_BUTTON_MIN_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	configure_button_guidance(button, tooltip)

	if pressed.is_valid():
		button.pressed.connect(pressed)

	row.add_child(button)
	return button


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func hide_cashier_panel() -> void:
	if cashier._cashier_panel != null:
		cashier._cashier_panel.visible = false
	cashier._unlock_player_actions()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func clear_container(container: Container) -> void:
	CashierPanel.clear_container(container)
