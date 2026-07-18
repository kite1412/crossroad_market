class_name NPCStateFlow
extends RefCounted

var npc = null


func setup(npc_node) -> void:
	npc = npc_node


func process_enter() -> void:
	npc._enter_pause_timer += npc.get_process_delta_time()

	if npc._enter_pause_timer < npc.ENTER_PAUSE:
		return

	var choose_start := Time.get_ticks_usec()
	npc._choose_available_item_to_buy()
	var choose_duration := Time.get_ticks_usec() - choose_start

	var shelf_start := Time.get_ticks_usec()
	var target_shelf: Shelf = npc._find_reachable_matching_shelf()
	var shelf_duration := Time.get_ticks_usec() - shelf_start

	if target_shelf == null:
		var fallback_shelf: Shelf = npc._find_matching_shelf()
		if npc.DEBUG_ENTER_TIMING:
			print_enter_timing(choose_duration, shelf_duration, -1)
		npc._show_dialog("I can't reach that shelf." if fallback_shelf != null else "Nothing I need is on the shelves right now.")
		npc._dialog_timer = npc.DIALOG_DURATION
		npc.target_position = npc._get_exit_position()
		set_state(NPC.State.EXIT)
		return

	var visit_position: Vector2 = npc._get_shelf_visit_position(target_shelf)

	if not visit_position.is_finite():
		npc._show_dialog("I can't reach that shelf.")
		npc._dialog_timer = npc.DIALOG_DURATION
		npc.target_position = npc._get_exit_position()
		set_state(NPC.State.EXIT)
		return

	npc._target_shelf = target_shelf
	npc.target_position = visit_position

	if npc.DEBUG_ENTER_TIMING:
		var route_start := Time.get_ticks_usec()
		var store: Node = npc._get_store_route_provider()

		if store != null:
			npc._call_store_route(store, &"get_npc_entry_route_to_shelf", [visit_position, npc.global_position])
		else:
			npc._build_movement_route(visit_position)

		var route_duration := Time.get_ticks_usec() - route_start
		print_enter_timing(choose_duration, shelf_duration, route_duration)

	set_state(NPC.State.WALK_TO_SHELF)


func print_enter_timing(choose_duration_usec: int, shelf_duration_usec: int, route_duration_usec: int) -> void:
	var route_text := "n/a"

	if route_duration_usec >= 0:
		route_text = "%.2fms" % (float(route_duration_usec) / 1000.0)

	print(
		"NPC enter timing [%s]: choose=%.2fms shelf=%.2fms route=%s" % [
			npc.name,
			float(choose_duration_usec) / 1000.0,
			float(shelf_duration_usec) / 1000.0,
			route_text
		]
	)


func process_walk_to_shelf() -> void:
	if npc.global_position.distance_to(npc.target_position) <= npc.SHELF_VISIT_ARRIVAL_DISTANCE:
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		set_state(NPC.State.SEARCH_ITEM)
		return

	if npc._move_to(npc.target_position):
		set_state(NPC.State.SEARCH_ITEM)


func process_search_item(delta: float) -> void:
	npc._search_timer += delta

	if npc._has_any_requested_item_available():
		if npc._search_timer < npc.SHELF_SEARCH_MIN_TIME:
			return

		set_state(NPC.State.TAKE_ITEM)
		return

	var action := BlueprintManager.evaluate_no_item_action(npc)

	match action:
		BlueprintManager.Action.LEAVE:
			if not npc._search_announced:
				npc._show_dialog(BlueprintManager.get_item_not_found_dialog(npc))
				npc._search_announced = true

			if npc._search_timer >= npc.SEARCH_PATIENCE:
				npc.target_position = npc._get_exit_position()
				set_state(NPC.State.EXIT)

		BlueprintManager.Action.QUEUE:
			if not npc._search_announced:
				npc._show_dialog(BlueprintManager.get_item_not_found_dialog(npc))
				npc._search_announced = true

			if npc._search_timer >= npc.SEARCH_PATIENCE:
				npc._show_dialog("Is there any restock coming...? I'll wait here.")
				npc._search_timer = 0.0
				npc._search_announced = false
				npc._enter_checkout_queue()

		BlueprintManager.Action.BROWSE_BUY:
			if not npc._search_announced:
				npc._show_dialog(BlueprintManager.get_item_not_found_dialog(npc))
				npc._search_announced = true

			if npc._search_timer >= 5.0:
				var alt_item: String = npc._find_alternative_item()

				if alt_item != "":
					npc._browse_item = alt_item
					npc.item_to_buy = alt_item
					npc._search_timer = 0.0
					npc._search_announced = false
					npc._show_dialog("Oh? This looks good actually.")
					set_state(NPC.State.TAKE_ITEM)
				else:
					npc.target_position = npc._get_exit_position()
					set_state(NPC.State.EXIT)


func process_browse_item(delta: float) -> void:
	npc._search_timer += delta

	if npc._search_timer < 8.0:
		return

	var alt_item: String = npc._find_alternative_item()

	if alt_item != "":
		npc._browse_item = alt_item
		npc.item_to_buy = alt_item
		npc._show_dialog("This one will do!")
		set_state(NPC.State.TAKE_ITEM)
	else:
		npc._show_dialog("Nothing here for me...")
		npc.target_position = npc._get_exit_position()
		set_state(NPC.State.EXIT)


func process_take_item() -> void:
	if npc._has_taken_shelf_item:
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		npc._take_item_pause_timer += npc.get_process_delta_time()

		if npc._take_item_pause_timer < npc.SHELF_TAKE_PAUSE_TIME:
			return

		npc._enter_checkout_queue()
		return

	if npc.global_position.distance_to(npc.target_position) > npc.SHELF_ACTION_DISTANCE and not npc._move_to(npc.target_position):
		return

	npc._face_target_shelf()

	if npc._take_requested_items_from_shelves():
		npc._has_taken_shelf_item = true
		npc._take_item_pause_timer = 0.0
		npc._show_dialog("I'll take this.")
		return

	npc._show_dialog("Someone must have taken it already.")
	npc.target_position = npc._get_exit_position()
	set_state(NPC.State.EXIT)


func process_checkout(delta: float) -> void:
	if npc._checkout_timer == 0.0:
		npc._show_dialog("I'd like to buy %s." % npc.get_checkout_item_label())

	npc._checkout_timer += delta

	if npc.npc_data.patience_type == NPCData.PatienceType.IMPATIENT and npc._checkout_timer >= npc.CHECKOUT_PATIENCE:
		npc._show_dialog(BlueprintManager.get_checkout_wait_dialog(npc))
		npc._leave_queue()
		npc._return_item_to_shelf()
		npc.target_position = npc._get_exit_position()
		set_state(NPC.State.EXIT)


func process_exit() -> void:
	if npc.global_position.distance_to(npc.target_position) <= npc.ARRIVAL_THRESHOLD:
		npc.velocity = Vector2.ZERO
		complete_exit()
		return

	if npc._dialog_timer > 0.0:
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		return

	if npc._move_to(npc.target_position):
		complete_exit()


func complete_exit() -> void:
	if npc._exit_completed or npc.is_queued_for_deletion():
		return

	npc._exit_completed = true
	npc.velocity = Vector2.ZERO
	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	npc._reset_stuck_watchdog()
	npc.npc_exited.emit(npc)
	npc.queue_done()


func finish_checkout_and_exit() -> void:
	npc._dialog_timer = npc.DIALOG_DURATION
	npc._leave_queue()
	npc._target_shelf = null
	npc.target_position = npc._get_exit_position()
	set_state(NPC.State.EXIT)


func set_state(new_state: int) -> void:
	if new_state == NPC.State.ENTER:
		npc._enter_pause_timer = 0.0

	if new_state == NPC.State.SEARCH_ITEM:
		npc._search_timer = 0.0
		npc._search_announced = false

	if new_state == NPC.State.TAKE_ITEM:
		npc._take_item_pause_timer = 0.0
		npc._has_taken_shelf_item = false

	if new_state == NPC.State.CHECKOUT:
		npc._checkout_timer = 0.0

	if new_state == NPC.State.EXIT:
		npc._leave_queue()
		npc._target_shelf = null

	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	npc._reset_stuck_watchdog()
	npc.current_state = new_state
