class_name StoreOpenCloseController
extends Node

const NORMAL_STOCK_REQUIRED: int = 4
const CUSTOMER_INTAKE_CLOSED_META: StringName = &"customer_intake_closed_today"

var store: Node = null


func setup(store_node: Node) -> void:
	store = store_node


func request_toggle_store_open() -> void:
	if store._store_open:
		close_store()
		return

	if is_customer_intake_closed_today():
		store._show_notification(
			"The store is closed for today.",
			1.5
		)
		update_store_status_board()
		return

	if not store._store_opened_today and not is_day_setup_complete():
		store._show_notification(
			"Set up the shelf and stock items before opening.",
			1.5
		)
		update_store_status_board()
		return

	open_store()


func is_day_setup_complete() -> bool:
	return (
		store._human_shelf_installed
		and store._human_items_placed >= NORMAL_STOCK_REQUIRED
	)


func open_store() -> void:
	if is_customer_intake_closed_today():
		store._show_notification(
			"The store is closed for today.",
			1.5
		)
		return

	store._store_open = true
	store._store_opened_today = true

	TimeManager.start_clock()
	NPCScheduler.set_store_open(true)
	update_store_status_board()
	store._show_status_notification("Store is OPEN.", 1.0)
	store._show_task_complete_notice(
		"store_opened",
		"Open sign flipped."
	)
	store._update_objective()
	store._update_end_day_tax_flow()


func close_store() -> void:
	store._store_open = false

	if store._store_opened_today:
		store.set_meta(CUSTOMER_INTAKE_CLOSED_META, true)

	NPCScheduler.set_store_open(false)
	NPCScheduler.close_customer_sessions_for_day()

	update_store_status_board()
	store._show_status_notification("Store is CLOSED.", 1.0)
	store._update_objective()
	store._update_end_day_tax_flow()


func is_customer_intake_closed_today() -> bool:
	if store == null:
		return false

	return bool(
		store.get_meta(
			CUSTOMER_INTAKE_CLOSED_META,
			false
		)
	)


func update_store_status_board(animated: bool = true) -> void:
	store.open_close_board = get_open_close_board()

	if (
		store.open_close_board != null
		and store.open_close_board.has_method("set_open_state")
	):
		store.open_close_board.call(
			"set_open_state",
			store._store_open,
			animated
		)


func get_open_close_board() -> Node:
	if store.open_close_board != null and is_instance_valid(store.open_close_board):
		return store.open_close_board

	var yard_board: Node = null

	if store._current_yard != null and is_instance_valid(store._current_yard):
		yard_board = store._current_yard.get_node_or_null("OpenCloseBoard")

	if yard_board != null:
		return yard_board

	var group_board := store.get_tree().get_first_node_in_group(
		"open_close_board"
	)

	if group_board != null:
		return group_board

	return store.get_node_or_null("OpenCloseBoard")
