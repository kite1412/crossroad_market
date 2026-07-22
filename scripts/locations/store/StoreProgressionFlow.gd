class_name StoreProgressionFlow
extends Node


const NORMAL_STOCK_REQUIRED: int = 4
const PHANTOM_ICE_CREAM_ID: String = "phantom_ice_cream"

var store: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(store_node: Node) -> void:
	store = store_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_morning_intro() -> void:
	if store._intro_shown:
		return

	store._intro_shown = true
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var messages: Array[String] = [
		"Finally made it... Grandma's old shop.",
		"It's dusty, but it still feels like home.",
		"Go to the backroom and bring out the human shelf."
	]
	await StoreDialogBridge.show_player_sequence(store, messages)
	show_first_activity_board()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_first_activity_board() -> void:
	if store._first_activity_board_shown:
		return

	store._first_activity_board_shown = true

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var activity_board := store.get_node_or_null("ActivityBoard")

	if activity_board != null and activity_board.has_method("open_board"):
		activity_board.call("open_board")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_yard_intro() -> void:
	if store._yard_intro_shown:
		return

	store._yard_intro_shown = true
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var messages: Array[String] = [
		"Grandma's old shop is just ahead.",
		"Take a breath, then head inside.",
		"Press E at the shop door to enter."
	]
	await store._show_notification_sequence(messages)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_storage_mystery_discovered() -> void:
	store._mystery_discovered = true
	store._show_task_complete_notice("mystery_discovered", "Mystery corner discovered.")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_storage_mystery_item_taken(item_id: String) -> void:
	var was_new_item: bool = item_id != "" and item_id not in store._mystery_items_taken

	if item_id != "" and item_id not in store._mystery_items_taken:
		store._mystery_items_taken.append(item_id)

	if item_id == PHANTOM_ICE_CREAM_ID and was_new_item:
		var messages: Array[String] = [
			"What is this...?",
			"This box wasn’t in Grandma’s inventory list.",
			"Why is it glowing... and why does it feel ice cold?"
		]
		await StoreDialogBridge.show_player_sequence(store, messages)

		update_objective()
		show_hint(
			"phantom_return_store",
			"Take the Phantom Ice Cream back to the store and try it on the Human Shelf."
		)
		return

	update_objective()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_storage_mystery_supply_depleted() -> void:
	store._mystery_supply_depleted = true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func should_prioritize_phantom_for_human_shelf() -> bool:
	return (
		not store._phantom_human_shelf_attempted
		and PHANTOM_ICE_CREAM_ID in store._mystery_items_taken
		and Inventory.has_item(PHANTOM_ICE_CREAM_ID)
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_phantom_human_shelf_attempted() -> void:
	if store._phantom_human_shelf_attempted:
		return

	store._phantom_human_shelf_attempted = true
	update_objective()

	var messages: Array[String] = [
		"Huh? It keeps falling off from the shelf..."
	]
	await StoreDialogBridge.show_player_sequence(store, messages)

	show_hint(
		"phantom_return_storage",
		"Return to the storage and bring the strange Ghost Shelf to the store."
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_human_shelf_item_placed(_slot_index: int, item_id: String) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item := ItemDatabase.get_item(item_id)

	if item != null and item.shelf_type == ItemData.ShelfType.HUMAN:
		set_human_stock_count(StoreShelfController.get_shelf_stock_count(store.human_shelf))
		update_objective()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_human_shelf_item_removed(_slot_index: int, item_id: String) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item := ItemDatabase.get_item(item_id)

	if item != null and item.shelf_type == ItemData.ShelfType.HUMAN:
		set_human_stock_count(StoreShelfController.get_shelf_stock_count(store.human_shelf))
		update_objective()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_ghost_shelf_item_placed(_slot_index: int, item_id: String) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item := ItemDatabase.get_item(item_id)

	if item == null or item.shelf_type != ItemData.ShelfType.GHOST:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var became_ready := check_customer_spawning_ready(false)
	update_objective()
	store._show_task_complete_notice("ghost_shelf_stocked", "Ghost Shelf stocked.")

	if store._ghost_shelf_lesson_shown:
		if became_ready:
			show_customer_open_notification()
			update_objective()
		return

	store._ghost_shelf_lesson_shown = true
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var messages: Array[String] = [
		"Huh... so it only stays on this shelf?",
		"This shelf looks different too... What was Grandma keeping here?"
	]
	await StoreDialogBridge.show_player_sequence(store, messages)

	if became_ready:
		show_customer_open_notification()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func register_installed_shelf(object: Node2D) -> void:
	if object == null:
		return

	if not object.is_in_group("shelves"):
		object.add_to_group("shelves")

	if object.name == "ShelfHuman" and object is Shelf:
		store._human_shelf_installed = true
		store.human_shelf = object as Shelf

		connect_human_shelf_signals(store.human_shelf)
		set_human_stock_count(StoreShelfController.get_shelf_stock_count(store.human_shelf))
		update_objective()
		store._show_task_complete_notice("human_shelf_placed", "Human Shelf placed.")

		if store._human_items_placed < NORMAL_STOCK_REQUIRED:
			store._show_passive_notification("Now stock the human shelf with normal items.", 3.0)

	if object.name == "ShelfGhost" and object is Shelf:
		store._ghost_shelf_installed = true
		store.ghost_shelf = object as Shelf

		if not store.ghost_shelf.item_placed.is_connected(store._on_ghost_shelf_item_placed):
			store.ghost_shelf.item_placed.connect(store._on_ghost_shelf_item_placed)

		store.ghost_shelf.apply_ghost_glow(true)
		check_customer_spawning_ready()
		update_objective()
		store._show_task_complete_notice("ghost_shelf_placed", "Ghost Shelf placed.")

	store._setup_npc_static_data()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func register_human_stock_progress() -> void:
	set_human_stock_count(store._human_items_placed + 1)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func connect_human_shelf_signals(shelf: Shelf) -> void:
	if shelf == null:
		return

	if not shelf.item_placed.is_connected(store._on_human_shelf_item_placed):
		shelf.item_placed.connect(store._on_human_shelf_item_placed)

	if not shelf.item_removed.is_connected(store._on_human_shelf_item_removed):
		shelf.item_removed.connect(store._on_human_shelf_item_removed)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_human_stock_count(stock_count: int) -> void:
	store._human_items_placed = clampi(stock_count, 0, NORMAL_STOCK_REQUIRED)

	if store._human_items_placed >= NORMAL_STOCK_REQUIRED:
		store._show_task_complete_notice("human_shelf_stocked", "Human Shelf stocked.")

	if not StoreProgressionController.can_unlock_mystery_phase(
		store._human_items_placed,
		NORMAL_STOCK_REQUIRED,
		store._human_shelf_installed,
		store._mystery_phase_unlocked
	):
		return

	store._mystery_phase_unlocked = true
	store._show_notification("The dark corner in storage just opened.", 3.0)
	update_objective()

	if store._current_storage != null and store._current_storage.has_method("set_mystery_phase_unlocked"):
		store._current_storage.set_mystery_phase_unlocked(true)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func check_customer_spawning_ready(show_notice: bool = true) -> bool:
	if not StoreProgressionController.can_unlock_customer_spawning(
		store._customer_spawning_unlocked,
		store._ghost_shelf_installed,
		store.ghost_shelf
	):
		return false

	if store._customer_spawning_unlocked:
		return true

	store._customer_spawning_unlocked = true
	store._gooby_resolved = false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var should_start_day_one_customers_now := StoreProgressionController.should_start_day_one_customers_now()

	if show_notice:
		show_customer_open_notification()
	else:
		store._suppress_next_day_open_notification = should_start_day_one_customers_now

	NPCScheduler.unlock_spawning_now(false)
	update_objective()
	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_customer_open_notification() -> void:
	if store._customer_open_notification_shown:
		return

	store._customer_open_notification_shown = true
	store._show_notification("Store setup is ready. Flip the OPEN board when you want customers.", 2.5)
	update_objective()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func update_objective() -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var objective_text := get_current_objective_text()

	if objective_text == store._last_objective_text:
		return

	store._last_objective_text = objective_text

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	@warning_ignore("shadowed_variable")
	var hud := store.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("set_objective"):
		hud.call("set_objective", objective_text)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_activity_board_guidance() -> Dictionary:
	if store == null:
		return {
			"title": "Today's Work",
			"lines": ["[ ] Pick the Human Shelf at the Storage, and bring it to the Store"]
		}

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var activities := [
		{"text": "Pick the Human Shelf at the Storage, and bring it to the Store", "done": store._human_shelf_installed},
		{"text": "Take stock from the Storage and bring it to the Human Shelf", "done": store._completed_task_notices.has("human_shelf_stocked")},
		{"text": "Investigate the glowing box in the Storage", "done": store._mystery_discovered},
		{"text": "Take the Phantom Ice Cream from the box", "done": PHANTOM_ICE_CREAM_ID in store._mystery_items_taken},
		{"text": "Try the Phantom Ice Cream on the Human Shelf", "done": store._phantom_human_shelf_attempted},
		{"text": "Pick the Ghost Shelf at the Storage, and bring it to the Store", "done": store._completed_task_notices.has("ghost_shelf_placed")},
		{"text": "Stock the Ghost Shelf", "done": store._completed_task_notices.has("ghost_shelf_stocked")},
		{"text": "Flip the Open Sign outside the Store", "done": store._store_opened_today},
		{"text": "Serve customers at the Store cashier", "done": store._completed_task_notices.has("normal_customer_served")}
	]

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var lines: Array[String] = []
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var next_todo_index: int = -1

	for i in activities.size():
		if bool(activities[i]["done"]):
			lines.append("[x] %s" % [str(activities[i]["text"])])
		elif next_todo_index == -1:
			next_todo_index = i

	if next_todo_index != -1:
		lines.append("[ ] %s" % [str(activities[next_todo_index]["text"])])
	elif lines.is_empty():
		lines.append("[ ] Pick the Human Shelf at the Storage, and bring it to the Store")
	else:
		lines.append("All listed activities are complete.")

	return {
		"title": "Today's Work",
		"lines": lines
	}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_current_objective_text() -> String:
	if store == null:
		return ""

	if store._gooby_resolved:
		return ""

	if TimeManager.current_phase == TimeManager.Phase.NIGHT and store._customer_spawning_unlocked:
		return "Serve Gooby at the cashier."

	if store._store_opened_today:
		if not store._store_open:
			return "Flip the OPEN board when ready."

		if not store._mystery_phase_unlocked or not store._mystery_discovered:
			return "Investigate the glowing box in the dark storage corner."

		if PHANTOM_ICE_CREAM_ID not in store._mystery_items_taken:
			return "Take the Phantom Ice Cream from the glowing box."

		if not store._phantom_human_shelf_attempted:
			return "Try the Phantom Ice Cream on the Human Shelf."

		if not store._ghost_shelf_installed:
			return "Return to storage and bring the Ghost Shelf to the store."

		if store.ghost_shelf == null or not store.ghost_shelf.has_stock():
			return "Stock Phantom Ice Cream on ghost shelf."

		return "Serve customers at the cashier."

	if not store._human_shelf_installed:
		return "Bring the human shelf from storage."

	if store._human_items_placed < NORMAL_STOCK_REQUIRED:
		return "Stock the human shelf with normal items."

	if not store._mystery_phase_unlocked or not store._mystery_discovered:
		return "Investigate the glowing box in the dark storage corner."

	if PHANTOM_ICE_CREAM_ID not in store._mystery_items_taken:
		return "Take the Phantom Ice Cream from the glowing box."

	if not store._phantom_human_shelf_attempted:
		return "Try the Phantom Ice Cream on the Human Shelf."

	if not store._ghost_shelf_installed:
		return "Return to storage and bring the Ghost Shelf to the store."

	if store.ghost_shelf == null or not store.ghost_shelf.has_stock():
		return "Stock Phantom Ice Cream on ghost shelf."

	if not store._store_open:
		return "Flip the OPEN board when ready."

	if not store._is_day_setup_complete():
		return "Prepare the store for customers."

	return "Serve customers at the cashier."


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_hint(key: String, text: String) -> void:
	var hud: Node = store.get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_hint_dialog"):
		hud.call("show_hint_dialog", key, text)
