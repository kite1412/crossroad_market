class_name StoreTaxFlow
extends Node

const MIDNIGHT_BLACK_HOLD_DURATION: float = 3.0
const RESTOCK_CLOSE_TAX_CHECK_DELAY: float = 3.0
const RESTOCK_TAX_RETRY_INTERVAL: float = 0.25

var store: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(store_node: Node) -> void:
	store = store_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_storage_restock_order_purchased(order_items: Array) -> void:
	if store == null or order_items.is_empty():
		return

	store._restock_delivery_counter += 1
	store._pending_restock_deliveries.append({
		"id": store._restock_delivery_counter,
		"items": duplicate_restock_items(order_items)
	})
	store._restock_ordered_today = true
	sync_restock_deliveries_to_yard()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_storage_restock_panel_opened() -> void:
	if store == null:
		return

	store._restock_panel_open = true
	store._tax_waiting_for_restock_close = false
	store._tax_ready_after_restock_close = false
	store._tax_restock_close_ready_at_msec = 0
	store._tax_restock_retry_token += 1


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_storage_restock_panel_closed(had_checkout: bool = false) -> void:
	if store == null:
		return

	store._restock_panel_open = false

	if not had_checkout:
		return

	if TimeManager.current_phase != TimeManager.Phase.NIGHT:
		return

	if store._store_open:
		return

	if store._tax_paid_today or store._tax_panel_showing:
		return

	store._restock_ordered_today = true
	store._tax_waiting_for_restock_close = true
	store._tax_ready_after_restock_close = true
	store._tax_restock_close_ready_at_msec = Time.get_ticks_msec() + int(RESTOCK_CLOSE_TAX_CHECK_DELAY * 1000.0)
	schedule_restock_tax_retry()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func schedule_restock_tax_retry() -> void:
	if store == null:
		return

	store._tax_restock_retry_token += 1
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var retry_token: int = int(store._tax_restock_retry_token)
	defer_restock_tax_retry(retry_token)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func defer_restock_tax_retry(retry_token: int) -> void:
	if store == null:
		return

	while retry_token == store._tax_restock_retry_token and should_continue_restock_tax_retry():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var remaining_msec: int = int(store._tax_restock_close_ready_at_msec) - Time.get_ticks_msec()

		if remaining_msec > 0:
			await store.get_tree().create_timer(float(remaining_msec) / 1000.0).timeout
		else:
			if try_show_tax_panel():
				return

			await store.get_tree().create_timer(RESTOCK_TAX_RETRY_INTERVAL).timeout


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func should_continue_restock_tax_retry() -> bool:
	return (
		store != null
		and store._tax_waiting_for_restock_close
		and store._tax_ready_after_restock_close
		and not store._tax_paid_today
		and not store._tax_panel_showing
		and not store._end_day_transition_started
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_storage_restock_item_purchased(item_id: String, quantity: int) -> void:
	if item_id == "" or quantity <= 0:
		return

	on_storage_restock_order_purchased([{
		"item_id": item_id,
		"quantity": quantity
	}])


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func duplicate_restock_items(order_items: Array) -> Array[Dictionary]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var items: Array[Dictionary] = []

	for item in order_items:
		if not (item is Dictionary):
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var data := item as Dictionary
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var item_id := str(data.get("item_id", ""))
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var quantity := int(data.get("quantity", 0))

		if item_id == "" or quantity <= 0:
			continue

		items.append({
			"item_id": item_id,
			"quantity": quantity
		})

	return items


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_yard_restock_delivery_collected(delivery_id: int) -> void:
	if store == null:
		return

	if delivery_id < 0:
		store._pending_restock_deliveries.clear()
		return

	for i in range(store._pending_restock_deliveries.size() - 1, -1, -1):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var delivery: Dictionary = store._pending_restock_deliveries[i]

		if int(delivery.get("id", -1)) == delivery_id:
			store._pending_restock_deliveries.remove_at(i)
			return


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func sync_restock_deliveries_to_yard() -> void:
	if store == null:
		return

	if store._current_yard == null or not is_instance_valid(store._current_yard):
		return

	if not store._current_yard.has_method("set_restock_deliveries"):
		return

	store._current_yard.call("set_restock_deliveries", store._pending_restock_deliveries)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func update_end_day_tax_flow() -> void:
	if store == null:
		return

	if store._end_day_transition_started:
		return

	if store._tax_paid_today:
		return

	if store._tax_waiting_for_restock_close:
		if not store._tax_ready_after_restock_close:
			return

		if Time.get_ticks_msec() < store._tax_restock_close_ready_at_msec:
			return

	if store._restock_panel_open:
		return

	try_show_tax_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func try_show_tax_panel() -> bool:
	if store == null:
		return false

	if not can_show_tax_panel():
		return false

	store._tax_pending = true
	store._tax_notice_active = true
	store._latest_daily_report = EconomyManager.get_daily_report()
	store._connect_hud_signals()

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	@warning_ignore("shadowed_variable")
	var hud := store.get_tree().get_first_node_in_group("hud")

	if hud == null or not hud.has_method("show_tax_notice"):
		return false

	hud.call("show_tax_notice", store._latest_daily_report, "")

	store._tax_waiting_for_restock_close = false
	store._tax_ready_after_restock_close = false
	store._tax_restock_close_ready_at_msec = 0
	store._tax_restock_retry_token += 1
	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func can_show_tax_panel() -> bool:
	if store == null:
		return false

	if store._tax_notice_active:
		return false

	if store._restock_panel_open:
		return false

	if TimeManager.current_phase != TimeManager.Phase.NIGHT:
		return false

	if store._store_open:
		return false

	if not store._restock_ordered_today:
		return false

	if store._has_blocking_overlay_for_tax():
		return false

	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_tax_panel(warning: String = "") -> bool:
	if store == null:
		return false

	store._connect_hud_signals()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	@warning_ignore("shadowed_variable")
	var hud := store.get_tree().get_first_node_in_group("hud")

	if hud == null or not hud.has_method("show_tax_notice"):
		return false
	
	if warning != "":
		hud.call("show_tax_notice", store._latest_daily_report, warning)

	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_tax_ignore_requested() -> void:
	if store == null:
		return

	if not store._tax_notice_active:
		return

	store._tax_ignored_today = true
	store._tax_notice_active = false
	store._tax_pending = false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	@warning_ignore("shadowed_variable")
	var hud := store.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("hide_tax_notice"):
		hud.call("hide_tax_notice")
		
	if hud != null and hud.has_method("hide_tax_report"):
		hud.call("hide_tax_report")

	store._show_notification("Tax payment ignored.", 1.5)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_player_entered_home() -> void:
	if store == null:
		return

	if store._tax_paid_today:
		return

	if not store._tax_ignored_today:
		return

	if store._tax_home_warning_shown:
		return

	store._tax_home_warning_shown = true
	store._show_notification("You went to sleep without paying tax. Penalties may apply.", 3.0)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_tax_payment_requested() -> void:
	if store == null:
		return

	if not store._tax_notice_active:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var tax := EconomyManager.get_daily_tax()

	if EconomyManager.gold < tax:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		@warning_ignore("shadowed_variable")
		var hud1 := store.get_tree().get_first_node_in_group("hud")
		if hud1 != null and hud1.has_method("show_tax_notice"):
			hud1.call("show_tax_notice", store._latest_daily_report, "Not enough gold to pay today's tax.")
		return

	if not EconomyManager.pay_tax():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		@warning_ignore("shadowed_variable")
		var hud2 := store.get_tree().get_first_node_in_group("hud")
		if hud2 != null and hud2.has_method("show_tax_notice"):
			hud2.call("show_tax_notice", store._latest_daily_report, "Not enough gold to pay today's tax.")
		return

	store._tax_pending = false
	store._tax_paid_today = true
	store._tax_notice_active = false
	store._tax_panel_showing = false
	store._tax_waiting_for_restock_close = false
	store._tax_ready_after_restock_close = false
	store._tax_restock_close_ready_at_msec = 0
	store._tax_restock_retry_token += 1

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	@warning_ignore("shadowed_variable")
	var hud3 := store.get_tree().get_first_node_in_group("hud")

	if hud3 != null and hud3.has_method("hide_tax_notice"):
		hud3.call("hide_tax_notice")
	if hud3 != null and hud3.has_method("hide_tax_report"):
		hud3.call("hide_tax_report")

	store._show_notification("Tax paid.", 1.0)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func start_midnight_to_morning_transition() -> void:
	if store == null:
		return

	if store._end_day_transition_started:
		return

	if not TimeManager.can_sleep():
		return

	store._end_day_transition_started = true
	store.call_deferred("_run_midnight_to_morning_transition")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func run_midnight_to_morning_transition() -> void:
	if store == null:
		return

	store._is_transitioning = true
	await store._fade_to_black()
	await store.get_tree().create_timer(MIDNIGHT_BLACK_HOLD_DURATION).timeout
	TimeManager.start_next_day()
	await store._fade_from_black()
	store._is_transitioning = false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func reset_day_state() -> void:
	if store == null:
		return

	store._tax_pending = false
	store._tax_paid_today = false
	store._tax_panel_showing = false
	store._restock_panel_open = false
	store._tax_waiting_for_restock_close = false
	store._tax_ready_after_restock_close = false
	store._tax_restock_close_ready_at_msec = 0
	store._tax_restock_retry_token += 1
	store._restock_ordered_today = false
	store._latest_daily_report.clear()
	store._tax_ignored_today = false
	store._tax_notice_active = false
	store._tax_home_warning_shown = false
