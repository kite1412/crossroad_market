class_name StoreDayRuntime
extends Node

const NORMAL_STOCK_REQUIRED: int = 4
const CUSTOMER_INTAKE_CLOSED_META: StringName = &"customer_intake_closed_today"

var store: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(store_node: Node) -> void:
	store = store_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_normal_item_taken() -> void:
	store._normal_items_taken = min(store._normal_items_taken + 1, NORMAL_STOCK_REQUIRED)
	store._update_objective()

	if store._normal_items_taken >= NORMAL_STOCK_REQUIRED:
		store._normal_supply_depleted = true
		store._show_notification("Bring the human shelf to the store and stock it.", 3.0)
		store._update_objective()
		return


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_human_item_placed() -> void:
	store._register_human_stock_progress()
	store._update_objective()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_gooby_resolved() -> void:
	store._gooby_resolved = true
	store._show_task_complete_notice("gooby_resolved", "Gooby branch resolved.")
	store._update_objective()


func show_day_one_close_store_hint() -> void:
	if TimeManager.current_day != 1:
		return

	var hud: Node = store.get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_notification"):
		hud.call(
			"show_notification",
			"The night is over. Flip the OPEN board to close the store.",
			3.0,
			false,
			true
		)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func can_player_sleep() -> Dictionary:
	if TimeManager.current_phase != TimeManager.Phase.NIGHT:
		return {
			"allowed": false,
			"message": "It's too early to sleep."
		}

	if store._store_open:
		return {
			"allowed": false,
			"message": "Close the store before sleeping."
		}

	if store._get_carried_object_from_player() != null:
		return {
			"allowed": false,
			"message": "Put down the shelf first."
		}

	if not store._tax_paid_today and not store._tax_ignored_today:
		return {
			"allowed": false,
			"message": "Pay today's tax first."
		}

	return {
		"allowed": true,
		"message": ""
	}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_phase_changed(phase) -> void:
	match phase:
		TimeManager.Phase.DAY:
			if store._is_day_setup_complete():
				if store._suppress_next_day_open_notification:
					store._suppress_next_day_open_notification = false
				else:
					store._show_customer_open_notification()
			else:
				store._show_notification("Finish setting up before customers arrive.", 3.0)
		TimeManager.Phase.NIGHT:
			if store._customer_spawning_unlocked:
				store._show_notification("Night falls. Strange customers may arrive.", 3.0)
			else:
				store._show_notification("Night falls, but the ghost shelf is not ready.", 3.0)
	store._update_objective()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_target_reached() -> void:
	store._show_notification("Daily target achieved.", 2.5)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_daily_report(report: Dictionary) -> void:
	store._latest_daily_report = report.duplicate()
	store._update_end_day_tax_flow()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_day_ended(_day: int) -> void:
	store._show_notification("Close the store, restock, and pay today's tax.", 3.0)
	store._update_end_day_tax_flow()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_day_started(_day: int) -> void:
	store._store_open = false
	store._store_opened_today = false
	store.set_meta(CUSTOMER_INTAKE_CLOSED_META, false)
	if store.tax_flow != null:
		store.tax_flow.reset_day_state()
	store._customer_open_notification_shown = false
	NPCScheduler.set_store_open(false)
	NPCScheduler.stop_normal_customer_spawning()
	store._update_store_status_board(false)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	@warning_ignore("shadowed_variable")
	var hud := store.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("hide_tax_report"):
		hud.call("hide_tax_report")

	if not store._pending_store_intro_after_yard:
		store._update_objective()
