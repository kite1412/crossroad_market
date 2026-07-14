extends StaticBody2D

const CashierCheckoutHistory = preload("res://scripts/ui/cashier/CashierCheckoutHistory.gd")
const CashierCheckoutService = preload("res://scripts/ui/cashier/CashierCheckoutService.gd")
const CashierPanel = preload("res://scripts/ui/cashier/CashierPanel.gd")
const NPCQueueSystem = preload("res://scripts/npc/behavior/NPCQueueSystem.gd")

const GOOBY_ID: String = "gooby"
const STORY_INTERACTION_TRUST_GAIN: int = 20
const CASHIER_BUTTON_FONT_SIZE: int = 8
const CASHIER_BUTTON_MIN_HEIGHT: float = 20.0
const STORE_OS_APP_POS: StringName = &"pos"
const STORE_OS_APP_RESTOCK: StringName = &"restock"

@onready var interaction_area: Area2D = $InteractionArea

signal checkout_done(npc: NPC, item_id: String, price: int)

var _scanned_npc: NPC = null
var _scanned_item_id: String = ""
var _scanned_item_label: String = ""
var _scanned_total: int = 0
var _checkout_history: Array[Dictionary] = []
var _target_item_ids: Array[String] = []
var _selected_item_ids: Array[String] = []
var _pending_item_id: String = ""
var _ask_again_count: int = 0
var _cashier_layer: CanvasLayer = null
var _cashier_panel: ColorRect = null
var _panel_title: Label = null
var _customer_label: Label = null
var _request_label: Label = null
var _selected_label: Label = null
var _guide_label: Label = null
var _pos_tab_button: Button = null
var _restock_tab_button: Button = null
var _item_list: VBoxContainer = null
var _action_row: Container = null
var _cashier_lock_active: bool = false
var _seen_panel_guidance: Dictionary = {}
var _active_store_os_app: StringName = STORE_OS_APP_POS


func _ready() -> void:
	_setup_cursor_hover()


func _exit_tree() -> void:
	_unlock_player_actions()


func reset_runtime_ui() -> void:
	_hide_cashier_panel()


func try_checkout() -> void:
	if not _is_player_nearby():
		return

	if _has_scanned_customer():
		if _cashier_panel != null and _cashier_panel.visible:
			_show_notification("Use the cashier panel.", 0.8)
		elif _scanned_total <= 0:
			_show_scan_panel()
		else:
			_show_paid_panel()
		return

	var first_npc: NPC = _get_first_checkout_npc()
	if first_npc == null:
		if _has_customer_approaching_counter():
			_show_notification("Customer is still walking to the counter.", 1.2)
		else:
			print("No customer waiting at counter.")
			_show_notification("No customer waiting at counter.", 1.2)
		return

	_process_scan(first_npc)


func _unhandled_input(event: InputEvent) -> void:
	if _cashier_panel == null or not _cashier_panel.visible:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_hide_cashier_panel()
			get_viewport().set_input_as_handled()
		return

	if not event is InputEventKey:
		return

	if not event.pressed or event.echo:
		return

	if event.keycode == KEY_ESCAPE:
		_hide_cashier_panel()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		if _scanned_total > 0:
			if _is_story_gift_checkout():
				_show_notification("Choose whether to give the item or refuse Gooby.", 1.0)
			else:
				_process_paid()
		else:
			_on_confirm_scan_pressed()
		get_viewport().set_input_as_handled()


func _is_player_nearby() -> bool:
	if interaction_area == null:
		return false

	for body in interaction_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			return true

	for area in interaction_area.get_overlapping_areas():
		if area.is_in_group("player"):
			return true

		var parent: Node = area.get_parent()

		if parent != null and parent.is_in_group("player"):
			return true

	return false

func _get_first_checkout_npc() -> NPC:
	NPCQueueSystem.prune_invalid(NPC.current_queue)

	if NPC.current_queue.is_empty():
		return null

	var front_npc := NPC.current_queue[0]

	if not is_instance_valid(front_npc):
		return null

	if front_npc.current_state != NPC.State.CHECKOUT:
		return null

	return front_npc

func _has_customer_approaching_counter() -> bool:
	for npc in NPC.current_queue:
		if not is_instance_valid(npc):
			continue

		if npc.current_state == NPC.State.WAIT_IN_QUEUE or npc.current_state == NPC.State.CHECKOUT:
			return true

	return false

func _process_scan(npc: NPC) -> void:
	if not is_instance_valid(npc):
		return

	var item_id: String = npc.item_to_buy
	var item_label: String = npc.get_checkout_item_label() if npc.has_method("get_checkout_item_label") else item_id
	var price: int = npc.get_checkout_total() if npc.has_method("get_checkout_total") else 0

	if price <= 0:
		var item_data: ItemData = ItemDatabase.get_item(item_id)

		if item_data != null:
			price = item_data.sell_price
			item_label = item_data.display_name

	if price <= 0:
		push_error("Cashier: item '%s' not found" % item_id)
		return
	_scanned_npc = npc
	_scanned_item_id = item_id
	_scanned_item_label = item_label
	_scanned_total = 0
	_target_item_ids = npc.get_cart_item_ids() if npc.has_method("get_cart_item_ids") else [item_id]
	_selected_item_ids.clear()
	_pending_item_id = ""
	_ask_again_count = 0

	print("SCAN: %s - %dG" % [item_label, price])
	_show_customer_request_bubble()
	_show_scan_panel()


func _process_paid() -> void:
	if not _has_scanned_customer():
		_clear_scan()
		return

	var npc: NPC = _scanned_npc
	var item_id: String = _scanned_item_id
	var item_label: String = _scanned_item_label
	var price: int = _scanned_total

	if price <= 0:
		_show_notification("Scan items first.", 0.8)
		_show_scan_panel()
		return

	npc.complete_checkout()

	if npc.checkout_outcome == "reject_return":
		if _is_gooby_npc(npc):
			_request_gooby_slime_follow_up()
			_notify_store_gooby_resolved()
			_show_notification(
				"Refused Gooby. Trust +0. The item returns to the shelf... something else is coming.",
				3.0
			)
		else:
			_apply_story_interaction_trust(npc)
			_show_notification("Checkout rejected. The item returns to the shelf.", 2.0)
		_add_history(npc, item_label, 0, "REJECTED")
		_clear_scan()
		return

	checkout_done.emit(npc, item_id, price)
	_add_history(npc, item_label, price, "PAID")
	print("PAID: %s for %dG" % [item_label, price])
	var story_trust_gain := _apply_story_interaction_trust(npc)
	if story_trust_gain > 0:
		_show_notification("PAID | %s | +%dG | Trust +%d" % [item_label, price, story_trust_gain], 1.8)
	else:
		_show_notification("PAID | %s | +%dG" % [item_label, price], 1.4)
	_clear_scan()


func _process_gooby_gift() -> void:
	if not _has_scanned_customer():
		_clear_scan()
		return

	var npc := _scanned_npc
	var item_label := _scanned_item_label

	if npc.has_method("complete_story_gift"):
		npc.complete_story_gift("You'd really give this to me...? Thank you.")
	else:
		npc.complete_checkout()

	var trust_gain := _apply_story_interaction_trust(npc)
	_request_gooby_slime_follow_up()
	_notify_store_gooby_resolved()
	_add_history(npc, item_label, 0, "GIFT")
	_show_notification(
		"Gooby Trust +%d | No revenue gained. Phantom Ice Cream is gone." % trust_gain,
		2.4
	)
	_clear_scan()


func _process_gooby_refuse() -> void:
	if not _has_scanned_customer():
		_clear_scan()
		return

	var npc := _scanned_npc
	var item_label := _scanned_item_label

	if npc.has_method("reject_checkout_and_return_items"):
		npc.reject_checkout_and_return_items("Boo... I understand.")
	else:
		npc.complete_checkout()

	_request_gooby_slime_follow_up()
	_notify_store_gooby_resolved()

	_add_history(npc, item_label, 0, "REFUSED")
	_show_notification(
		"Refused Gooby. Trust +0. The item returns to the shelf... something else is coming.",
		3.0
	)
	_clear_scan()


func _has_scanned_customer() -> bool:
	return _scanned_npc != null and is_instance_valid(_scanned_npc)


func _clear_scan() -> void:
	_scanned_npc = null
	_scanned_item_id = ""
	_scanned_item_label = ""
	_scanned_total = 0
	_target_item_ids.clear()
	_selected_item_ids.clear()
	_pending_item_id = ""
	_ask_again_count = 0
	_hide_cashier_panel()


func _add_history(npc: NPC, item_label: String, total: int, status: String) -> void:
	CashierCheckoutHistory.add_entry(_checkout_history, npc, item_label, total, status)


func get_checkout_history() -> Array[Dictionary]:
	return _checkout_history.duplicate(true)


func _show_scan_panel() -> void:
	_ensure_cashier_panel()
	_set_store_os_app(STORE_OS_APP_POS)
	_clear_container(_item_list)
	_clear_container(_action_row)
	_lock_player_actions()

	_cashier_panel.visible = true
	_panel_title.text = "CHECKOUT"
	_customer_label.text = "Customer: %s" % _get_scanned_customer_name()
	_request_label.text = _get_ask_again_panel_text()
	_set_panel_guidance_once(
		"scan",
		"Select an item, add it to cart, then confirm."
	)

	var store_items: Array[ItemData] = ItemDatabase.get_all_items()

	for item in store_items:
		if item == null:
			continue

		var button := Button.new()
		button.text = "%s  %dG" % [item.display_name, item.sell_price]
		button.custom_minimum_size = Vector2(0, CASHIER_BUTTON_MIN_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_configure_button_guidance(button, "Select this item before adding it to the cart.")
		button.toggle_mode = true
		button.button_pressed = item.item_id == _pending_item_id
		button.pressed.connect(Callable(self, "_on_scan_item_pressed").bind(item.item_id))
		_item_list.add_child(button)

	var add_button := Button.new()
	add_button.text = "Add Item"
	add_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_configure_button_guidance(add_button, "Add the selected item to the cart.")
	add_button.pressed.connect(_on_add_item_pressed)
	_action_row.add_child(add_button)

	_add_cart_rows_to_panel()

	var confirm_button := Button.new()
	confirm_button.text = "Confirm Cart"
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_configure_button_guidance(confirm_button, "Check the cart against the customer's request.")
	confirm_button.pressed.connect(_on_confirm_scan_pressed)
	_action_row.add_child(confirm_button)

	var ask_button := Button.new()
	ask_button.text = "Ask Again %d/3" % _ask_again_count
	ask_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_configure_button_guidance(ask_button, "Repeat the customer's request. After 3 asks, they leave.")
	ask_button.pressed.connect(_on_ask_again_pressed)
	_action_row.add_child(ask_button)

	var cancel_button := Button.new()
	cancel_button.text = "Close Checkout"
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_configure_button_guidance(cancel_button, "Close this panel without finishing checkout.")
	cancel_button.pressed.connect(_hide_cashier_panel)
	_action_row.add_child(cancel_button)

	_update_selected_label()


func _add_cart_rows_to_panel() -> void:
	var pending_label := Label.new()
	pending_label.text = "Selected Item: %s" % _get_pending_item_label()
	pending_label.add_theme_font_size_override("font_size", CASHIER_BUTTON_FONT_SIZE)
	pending_label.clip_text = true
	pending_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_action_row.add_child(pending_label)

	var cart_title := Label.new()
	cart_title.text = "Cart"
	cart_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cart_title.add_theme_font_size_override("font_size", CASHIER_BUTTON_FONT_SIZE)
	_action_row.add_child(cart_title)

	if _selected_item_ids.is_empty():
		var empty_label := Label.new()
		empty_label.text = "(empty)"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", CASHIER_BUTTON_FONT_SIZE)
		_action_row.add_child(empty_label)
	else:
		for i in range(_selected_item_ids.size()):
			_action_row.add_child(_create_cart_row(i, _selected_item_ids[i]))

	var total_label := Label.new()
	total_label.text = "Total: %dG" % _calculate_selected_total()
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_label.add_theme_font_size_override("font_size", CASHIER_BUTTON_FONT_SIZE)
	_action_row.add_child(total_label)


func _create_cart_row(index: int, item_id: String) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 3)

	var item_label := Label.new()
	item_label.text = _get_item_display_label(item_id)
	item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_label.add_theme_font_size_override("font_size", CASHIER_BUTTON_FONT_SIZE)
	item_label.clip_text = true
	item_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(item_label)

	var delete_button := Button.new()
	delete_button.text = "Del"
	delete_button.custom_minimum_size = Vector2(34, CASHIER_BUTTON_MIN_HEIGHT)
	delete_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_configure_button_guidance(delete_button, "Remove this item from the cart.")
	delete_button.pressed.connect(Callable(self, "_on_delete_cart_item_pressed").bind(index))
	row.add_child(delete_button)

	return row


func _show_paid_panel() -> void:
	if _is_story_gift_checkout():
		_show_gooby_choice_panel()
		return

	_ensure_cashier_panel()
	_set_store_os_app(STORE_OS_APP_POS)
	_clear_container(_item_list)
	_clear_container(_action_row)
	_lock_player_actions()

	_cashier_panel.visible = true
	_panel_title.text = "PAID"
	_customer_label.text = "Customer: %s" % _get_scanned_customer_name()
	_request_label.text = _get_ask_again_panel_text()
	_selected_label.text = "Cart: %s | Total %dG" % [_scanned_item_label, _scanned_total]
	_set_panel_guidance_once(
		"paid",
		"Receive Payment finishes this paid checkout. Back to Scan lets you correct the selected item."
	)

	var paid_button := Button.new()
	paid_button.text = "Receive Payment"
	paid_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_configure_button_guidance(paid_button, "Finish checkout and add this sale to revenue.")
	paid_button.pressed.connect(_process_paid)
	_action_row.add_child(paid_button)

	var back_button := Button.new()
	back_button.text = "Back to Scan Items"
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_configure_button_guidance(back_button, "Return to item selection and correct the scan.")
	back_button.pressed.connect(_show_scan_panel)
	_action_row.add_child(back_button)


func _show_gooby_choice_panel() -> void:
	_ensure_cashier_panel()
	_set_store_os_app(STORE_OS_APP_POS)
	_clear_container(_item_list)
	_clear_container(_action_row)
	_lock_player_actions()

	_cashier_panel.visible = true
	_panel_title.text = "GOOBY REQUEST"
	_customer_label.text = "Customer: %s" % _get_scanned_customer_name()
	_request_label.text = _get_ask_again_panel_text()
	_selected_label.text = "Item: %s | Revenue: 0G" % _scanned_item_label
	_set_panel_guidance_once(
		"gooby_choice",
		"Give Item improves trust with no gold. Refuse Sale returns the item and continues the night consequence."
	)

	var gift_button := Button.new()
	gift_button.text = "Give Item (+Trust, +0G)"
	gift_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_configure_button_guidance(gift_button, "Give Gooby the item, gain trust, and earn no revenue.")
	gift_button.pressed.connect(_process_gooby_gift)
	_action_row.add_child(gift_button)

	var refuse_button := Button.new()
	refuse_button.text = "Refuse Sale (Return Item)"
	refuse_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_configure_button_guidance(refuse_button, "Return the item and continue the night consequence.")
	refuse_button.pressed.connect(_process_gooby_refuse)
	_action_row.add_child(refuse_button)

	var back_button := Button.new()
	back_button.text = "Back to Scan Items"
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_configure_button_guidance(back_button, "Return to item selection before deciding.")
	back_button.pressed.connect(_show_scan_panel)
	_action_row.add_child(back_button)


func _on_scan_item_pressed(item_id: String) -> void:
	_pending_item_id = item_id

	_show_scan_panel()


func _on_add_item_pressed() -> void:
	if _pending_item_id == "":
		_show_notification("Select an item first.", 0.8)
		return

	_selected_item_ids.append(_pending_item_id)
	_pending_item_id = ""
	_update_selected_label()
	_show_scan_panel()


func _on_delete_cart_item_pressed(index: int) -> void:
	if index < 0 or index >= _selected_item_ids.size():
		return

	_selected_item_ids.remove_at(index)
	_update_selected_label()
	_show_scan_panel()


func _on_confirm_scan_pressed() -> void:
	if _selected_item_ids.is_empty():
		_show_notification("Add an item first.", 0.9)
		return

	if not _selection_matches_customer():
		_show_notification("This customer did not ask for that item.", 1.2)
		return

	_scanned_total = _calculate_selected_total()
	_scanned_item_label = _get_selected_item_label()
	_show_paid_panel()


func _on_ask_again_pressed() -> void:
	_ask_again_count += 1

	if _ask_again_count > 3:
		if _has_scanned_customer() and _scanned_npc.has_method("cancel_checkout_and_leave"):
			_scanned_npc.cancel_checkout_and_leave()

		_add_history(_scanned_npc, _scanned_item_label, 0, "LEFT")
		_show_notification("Customer left.", 1.2)
		_clear_scan()
		return

	_show_customer_request_bubble()

	_show_scan_panel()


func _get_scanned_customer_name() -> String:
	if not _has_scanned_customer() or _scanned_npc.npc_data == null:
		return "Customer"

	if _scanned_npc.npc_data.display_name == "":
		return "Customer"

	return _scanned_npc.npc_data.display_name


func _get_customer_request_line() -> String:
	if not _has_scanned_customer():
		return "I want %s." % _scanned_item_label

	var item_label := _scanned_npc.get_checkout_item_label() if _scanned_npc.has_method("get_checkout_item_label") else _scanned_item_label

	if item_label == "":
		item_label = _scanned_item_label

	return "I want %s." % item_label


func _get_ask_again_panel_text() -> String:
	return "Ask Again used: %d/3" % _ask_again_count


func _show_customer_request_bubble() -> void:
	if _has_scanned_customer() and _scanned_npc.has_method("repeat_checkout_request"):
		_scanned_npc.repeat_checkout_request()


func _on_pos_tab_pressed() -> void:
	_set_store_os_app(STORE_OS_APP_POS)

	if not _has_scanned_customer():
		_render_empty_pos_app()
	elif _scanned_total > 0:
		_show_paid_panel()
	else:
		_show_scan_panel()


func _on_restock_tab_pressed() -> void:
	_set_store_os_app(STORE_OS_APP_RESTOCK)
	_render_restock_app()


func _set_store_os_app(app_id: StringName) -> void:
	_active_store_os_app = app_id

	if _pos_tab_button != null:
		_pos_tab_button.button_pressed = app_id == STORE_OS_APP_POS

	if _restock_tab_button != null:
		_restock_tab_button.button_pressed = app_id == STORE_OS_APP_RESTOCK


func _render_empty_pos_app() -> void:
	_ensure_cashier_panel()
	_clear_container(_item_list)
	_clear_container(_action_row)
	_cashier_panel.visible = true
	_panel_title.text = "POS APP"
	_customer_label.text = "Customer: -"
	_request_label.text = "No customer at checkout."
	_selected_label.text = "Cart: - | Total 0G"
	_guide_label.visible = true
	_guide_label.text = "Wait for a customer, then press E at the cashier."


func _render_restock_app() -> void:
	_ensure_cashier_panel()
	_clear_container(_item_list)
	_clear_container(_action_row)
	_lock_player_actions()

	_cashier_panel.visible = true
	_panel_title.text = "RESTOCK APP"
	_customer_label.text = "Restock system draft"
	_request_label.text = "Default prices remain active for checkout."
	_selected_label.text = "Income %dG | Outcome 0G | Profit %dG" % [
		EconomyManager.daily_revenue,
		EconomyManager.daily_revenue
	]
	_guide_label.visible = true
	_guide_label.text = "Supplier/restock economy is placeholder."

	var store_items: Array[ItemData] = ItemDatabase.get_all_items()

	for item in store_items:
		if item == null:
			continue

		_item_list.add_child(_create_restock_item_card(item))

	var disabled_button := Button.new()
	disabled_button.text = "Restock Draft"
	disabled_button.disabled = true
	disabled_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_configure_button_guidance(disabled_button, "Restock economy is not implemented yet.")
	_action_row.add_child(disabled_button)

	var back_button := Button.new()
	back_button.text = "Back to POS"
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_configure_button_guidance(back_button, "Return to the POS app.")
	back_button.pressed.connect(_on_pos_tab_pressed)
	_action_row.add_child(back_button)


func _create_restock_item_card(item: ItemData) -> Control:
	var card := HBoxContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_constant_override("separation", 5)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(18, 14)
	swatch.color = Color(0.66, 0.48, 0.26, 1.0) if item.shelf_type == ItemData.ShelfType.HUMAN else Color(0.43, 0.32, 0.78, 1.0)
	card.add_child(swatch)

	var label := Label.new()
	label.text = "%s  %dG" % [item.display_name, item.sell_price]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", CASHIER_BUTTON_FONT_SIZE)
	card.add_child(label)

	return card


func _selection_matches_customer() -> bool:
	return CashierCheckoutService.selection_matches_customer(_selected_item_ids, _target_item_ids)


func _calculate_selected_total() -> int:
	return CashierCheckoutService.calculate_total(_selected_item_ids)


func _get_selected_item_label() -> String:
	return CashierCheckoutService.get_item_label(_selected_item_ids)


func _get_pending_item_label() -> String:
	if _pending_item_id == "":
		return "-"

	return _get_item_display_label(_pending_item_id)


func _get_item_display_label(item_id: String) -> String:
	var item := ItemDatabase.get_item(item_id)

	if item == null:
		return item_id

	return "%s %dG" % [item.display_name, item.sell_price]


func _update_selected_label() -> void:
	var total := _calculate_selected_total()
	var label := _get_selected_item_label()
	_selected_label.text = "Cart: %s | Total %dG" % [label if label != "" else "-", total]


func _is_story_gift_checkout() -> bool:
	if not _has_scanned_customer():
		return false

	if _scanned_npc.checkout_outcome != "reject_return":
		return false

	return _is_gooby_npc(_scanned_npc)


func _apply_story_interaction_trust(npc: NPC) -> int:
	if npc == null or npc.npc_data == null:
		return 0

	if npc.npc_data.npc_category != NPCData.NPCCategory.STORY:
		return 0

	RelationshipManager.add_trust(npc.npc_data.npc_id, STORY_INTERACTION_TRUST_GAIN)
	return STORY_INTERACTION_TRUST_GAIN


func _is_gooby_npc(npc: NPC) -> bool:
	return npc != null and npc.npc_data != null and npc.npc_data.npc_id == GOOBY_ID


func _request_gooby_slime_follow_up() -> void:
	if NPCScheduler.has_method("spawn_day_one_night_monster_customer"):
		NPCScheduler.spawn_day_one_night_monster_customer()


func _notify_store_gooby_resolved() -> void:
	var store := get_tree().get_first_node_in_group("store")

	if store != null and store.has_method("on_gooby_resolved"):
		store.call("on_gooby_resolved")


func _ensure_cashier_panel() -> void:
	if _cashier_layer != null and is_instance_valid(_cashier_layer):
		return

	var panel_nodes := CashierPanel.ensure(self)
	_cashier_layer = panel_nodes["layer"] as CanvasLayer
	_cashier_panel = panel_nodes["panel"] as ColorRect
	_panel_title = panel_nodes["title"] as Label
	_pos_tab_button = panel_nodes["pos_tab_button"] as Button
	_restock_tab_button = panel_nodes["restock_tab_button"] as Button
	_customer_label = panel_nodes["customer_label"] as Label
	_request_label = panel_nodes["request_label"] as Label
	_selected_label = panel_nodes["selected_label"] as Label
	_guide_label = panel_nodes["guide_label"] as Label
	_action_row = panel_nodes["action_row"] as Container
	_item_list = panel_nodes["item_list"] as VBoxContainer

	if _pos_tab_button != null and not _pos_tab_button.pressed.is_connected(_on_pos_tab_pressed):
		_pos_tab_button.pressed.connect(_on_pos_tab_pressed)

	if _restock_tab_button != null and not _restock_tab_button.pressed.is_connected(_on_restock_tab_pressed):
		_restock_tab_button.pressed.connect(_on_restock_tab_pressed)


func _set_panel_guidance_once(key: String, text: String) -> void:
	if _guide_label == null:
		return

	if _seen_panel_guidance.has(key):
		_guide_label.visible = false
		_guide_label.text = ""
		return

	_seen_panel_guidance[key] = true
	_guide_label.visible = true
	_guide_label.text = text


func _configure_button_guidance(button: Button, tooltip: String) -> void:
	if button == null:
		return

	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", CASHIER_BUTTON_FONT_SIZE)

	if button.custom_minimum_size.y < CASHIER_BUTTON_MIN_HEIGHT:
		button.custom_minimum_size.y = CASHIER_BUTTON_MIN_HEIGHT


func _hide_cashier_panel() -> void:
	if _cashier_panel != null:
		_cashier_panel.visible = false
	_unlock_player_actions()


func _clear_container(container: Container) -> void:
	CashierPanel.clear_container(container)


func _lock_player_actions() -> void:
	if _cashier_lock_active:
		return

	var hud := get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("begin_action_lock"):
		hud.call("begin_action_lock")
		_cashier_lock_active = true


func _unlock_player_actions() -> void:
	if not _cashier_lock_active:
		return

	var hud := get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("end_action_lock"):
		hud.call("end_action_lock")

	_cashier_lock_active = false


func _show_notification(text: String, duration: float = 2.0) -> void:
	var hud := get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_notification"):
		hud.call("show_notification", text, duration)


func _setup_cursor_hover() -> void:
	if interaction_area == null:
		return

	interaction_area.input_pickable = true
	var entered := Callable(self, "_on_cursor_mouse_entered")
	var exited := Callable(self, "_on_cursor_mouse_exited")

	if not interaction_area.mouse_entered.is_connected(entered):
		interaction_area.mouse_entered.connect(entered)

	if not interaction_area.mouse_exited.is_connected(exited):
		interaction_area.mouse_exited.connect(exited)


func _on_cursor_mouse_entered() -> void:
	var hud := get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_cursor_tooltip"):
		hud.call("show_cursor_tooltip", "Cashier")


func _on_cursor_mouse_exited() -> void:
	var hud := get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("hide_cursor_tooltip"):
		hud.call("hide_cursor_tooltip")
