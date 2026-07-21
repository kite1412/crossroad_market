class_name CashierCheckoutFlow
extends RefCounted

var cashier: Cashier = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(cashier_node: Cashier) -> void:
	cashier = cashier_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_scan(npc: NPC) -> void:
	if not is_instance_valid(npc):
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item_id: String = npc.item_to_buy
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item_label: String = npc.get_checkout_item_label() if npc.has_method("get_checkout_item_label") else item_id
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var price: int = npc.get_checkout_total() if npc.has_method("get_checkout_total") else 0

	if price <= 0:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var item_data: ItemData = ItemDatabase.get_item(item_id)

		if item_data != null:
			price = item_data.sell_price
			item_label = item_data.display_name

	if price <= 0:
		pass
		return
	cashier._scanned_npc = npc
	cashier._scanned_item_id = item_id
	cashier._scanned_item_label = item_label
	cashier._scanned_total = 0
	cashier._target_item_ids = npc.get_cart_item_ids() if npc.has_method("get_cart_item_ids") else [item_id]
	cashier._cart_quantities.clear()
	cashier._pending_item_id = ""
	cashier._ask_again_count = 0

	show_customer_request_bubble()
	cashier._show_scan_panel()
	cashier._start_patience_timer()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_paid() -> void:
	if not cashier._has_scanned_customer():
		clear_scan()
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var npc: NPC = cashier._scanned_npc
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item_id: String = cashier._scanned_item_id
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item_label: String = cashier._scanned_item_label
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var price: int = cashier._scanned_total

	if price <= 0:
		cashier._show_notification("Scan items first.", 0.8)
		cashier._show_scan_panel()
		return

	npc.complete_checkout()

	if npc.checkout_outcome == "reject_return":
		if cashier._is_gooby_npc(npc):
			cashier._request_gooby_slime_follow_up()
			cashier._notify_store_gooby_resolved()
			cashier._show_notification(
				"Refused Gooby. Trust +0. The item returns to the shelf... something else is coming.",
				3.0
			)
		else:
			cashier._show_notification("Checkout rejected. The item returns to the shelf.", 2.0)
		add_history(npc, item_label, 0, "REJECTED")
		clear_scan()
		return

	cashier.checkout_done.emit(npc, item_id, price)
	add_history(npc, item_label, price, "PAID")
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var story_trust_gain := cashier._apply_story_interaction_trust(npc)
	if story_trust_gain > 0:
		cashier._show_notification("PAID | %s | +%dG | Trust +%d" % [item_label, price, story_trust_gain], 1.8)
	else:
		cashier._show_notification("PAID | %s | +%dG" % [item_label, price], 1.4)
	clear_scan()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_gooby_gift() -> void:
	if not cashier._has_scanned_customer():
		clear_scan()
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var npc := cashier._scanned_npc
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item_label := cashier._scanned_item_label

	if npc.has_method("complete_story_gift"):
		npc.complete_story_gift("You'd really give this to me...? Thank you.")
	else:
		npc.complete_checkout()

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var trust_gain := cashier._story_flow.apply_gooby_gift_trust(npc)
	cashier._notify_store_gooby_resolved()
	add_history(npc, item_label, 0, "GIFT")
	cashier._show_notification(
		"Gooby Trust +%d | No revenue gained. Phantom Ice Cream is gone." % trust_gain,
		2.4
	)
	clear_scan()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_gooby_refuse() -> void:
	if not cashier._has_scanned_customer():
		clear_scan()
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var npc := cashier._scanned_npc
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item_label := cashier._scanned_item_label

	if npc.has_method("reject_checkout_and_return_items"):
		npc.reject_checkout_and_return_items("Boo... I understand.")
	else:
		npc.complete_checkout()

	cashier._request_gooby_slime_follow_up()
	cashier._notify_store_gooby_resolved()

	add_history(npc, item_label, 0, "REFUSED")
	cashier._show_notification(
		"Refused Gooby. Trust +0. The item returns to the shelf... something else is coming.",
		3.0
	)
	clear_scan()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func has_scanned_customer() -> bool:
	return cashier._scanned_npc != null and is_instance_valid(cashier._scanned_npc)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func clear_scan() -> void:
	cashier._stop_patience_timer()
	cashier._scanned_npc = null
	cashier._scanned_item_id = ""
	cashier._scanned_item_label = ""
	cashier._scanned_total = 0
	cashier._target_item_ids.clear()
	cashier._cart_quantities.clear()
	cashier._pending_item_id = ""
	cashier._ask_again_count = 0
	cashier._hide_cashier_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func add_history(npc: NPC, item_label: String, total: int, status: String) -> void:
	CashierCheckoutHistory.add_entry(cashier._checkout_history, npc, item_label, total, status)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_checkout_history() -> Array[Dictionary]:
	return cashier._checkout_history.duplicate(true)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_ask_again_pressed() -> void:
	cashier._ask_again_count += 1

	if cashier._ask_again_count > 2:
		if cashier._has_scanned_customer() and cashier._scanned_npc.has_method("cancel_checkout_and_leave"):
			cashier._scanned_npc.cancel_checkout_and_leave()
		add_history(cashier._scanned_npc, cashier._scanned_item_label, 0, "LEFT")
		cashier._show_notification("Customer left.", 1.2)
		clear_scan()
		return

	show_customer_request_bubble()
	cashier._show_scan_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_scanned_customer_name() -> String:
	if not cashier._has_scanned_customer() or cashier._scanned_npc.npc_data == null:
		return "Customer"

	if cashier._scanned_npc.npc_data.display_name == "":
		return "Customer"

	return cashier._scanned_npc.npc_data.display_name


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_customer_request_line() -> String:
	if not cashier._has_scanned_customer():
		return "I want %s." % cashier._scanned_item_label

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item_label := cashier._scanned_npc.get_checkout_item_label() if cashier._scanned_npc.has_method("get_checkout_item_label") else cashier._scanned_item_label

	if item_label == "":
		item_label = cashier._scanned_item_label

	return "I want %s." % item_label


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_ask_again_panel_text() -> String:
	return "Ask Again used: %d/2" % cashier._ask_again_count


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_customer_request_bubble() -> void:
	if cashier._has_scanned_customer() and cashier._scanned_npc.has_method("repeat_checkout_request"):
		cashier._scanned_npc.repeat_checkout_request()
