class_name NPCStateFlow
extends RefCounted

const PERF_SHELF_THRESHOLD_MSEC: float = 16.0
const DEBUG_SHELF_FLOW: bool = true

var npc = null


func setup(npc_node) -> void:
	npc = npc_node


func process_enter() -> void:
	npc._enter_pause_timer += npc.get_process_delta_time()

	if npc._enter_pause_timer < npc.ENTER_PAUSE:
		return

	var enter_start_usec := Time.get_ticks_usec()
	npc._choose_available_item_to_buy()

	var target_shelf: Shelf = npc._find_reachable_matching_shelf()

	if target_shelf == null:
		var fallback_shelf: Shelf = npc._find_matching_shelf()
		print_shelf_flow_debug("enter_no_reachable_shelf", fallback_shelf, Vector2.INF, {})
		npc._show_dialog("I can't reach that shelf." if fallback_shelf != null else "Nothing I need is on the shelves right now.")
		npc._dialog_timer = npc.DIALOG_DURATION
		npc.target_position = npc._get_exit_position()
		set_state(NPC.State.EXIT)
		return

	var visit_position: Vector2 = npc._get_shelf_visit_position(target_shelf)
	print_shelf_flow_debug("enter_visit_position", target_shelf, visit_position, {})

	if not visit_position.is_finite():
		print_shelf_flow_debug("enter_visit_invalid", target_shelf, visit_position, {})
		npc._show_dialog("I can't reach that shelf.")
		npc._dialog_timer = npc.DIALOG_DURATION
		npc.target_position = npc._get_exit_position()
		set_state(NPC.State.EXIT)
		return

	npc._target_shelf = target_shelf
	npc.target_position = visit_position
	var route_info := get_route_travel_info(visit_position)
	npc.shelf_route_ready.emit(npc, float(route_info.get("travel_seconds", 0.0)))
	print_shelf_flow_debug("enter_route_ready", target_shelf, visit_position, route_info)
	_print_perf_shelf_if_slow("npc_enter_route", enter_start_usec, route_info)

	set_state(NPC.State.WALK_TO_SHELF)


func get_route_travel_seconds(destination: Vector2) -> float:
	return float(get_route_travel_info(destination).get("travel_seconds", 0.0))


func get_route_travel_info(destination: Vector2) -> Dictionary:
	var route: Array[Vector2] = npc._build_movement_route(destination)
	var distance := 0.0
	var previous: Vector2 = npc.global_position

	for point in route:
		distance += previous.distance_to(point)
		previous = point

	if route.is_empty() or previous.distance_to(destination) > npc.ARRIVAL_THRESHOLD:
		distance += previous.distance_to(destination)

	if npc.SPEED <= 0.0:
		return {
			"travel_seconds": 0.0,
			"route_points": route.size(),
			"route_distance": distance
		}

	return {
		"travel_seconds": distance / npc.SPEED,
		"route_points": route.size(),
		"route_distance": distance
	}


func process_walk_to_shelf() -> void:
	if npc.global_position.distance_to(npc.target_position) <= npc.SHELF_VISIT_ARRIVAL_DISTANCE:
		print_shelf_flow_debug("walk_arrived_threshold", npc._target_shelf, npc.target_position, {})
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		npc._face_target_shelf()
		set_state(NPC.State.SEARCH_ITEM)
		return

	if npc._move_to(npc.target_position):
		print_shelf_flow_debug("walk_move_to_arrived", npc._target_shelf, npc.target_position, {})
		npc._face_target_shelf()
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

		if npc._target_shelf != null and is_instance_valid(npc._target_shelf):
			npc._queue_entry_shelf = npc._target_shelf
			npc._queue_egress_route_pending = true

		npc._enter_checkout_queue()
		return

	if npc.global_position.distance_to(npc.target_position) > npc.SHELF_ACTION_DISTANCE and not npc._move_to(npc.target_position):
		return

	print_shelf_flow_debug("take_before_face", npc._target_shelf, npc.target_position, {})
	npc._face_target_shelf()

	if npc._take_requested_items_from_shelves():
		npc._has_taken_shelf_item = true
		npc._take_item_pause_timer = 0.0
		npc._show_dialog("I'll take this.")
		print_shelf_flow_debug("take_success", npc._target_shelf, npc.target_position, {})
		return

	npc._show_dialog("Someone must have taken it already.")
	print_shelf_flow_debug("take_failed_missing_item", npc._target_shelf, npc.target_position, {})
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

	if npc in NPC.current_queue:
		npc._leave_queue()

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
	if npc in NPC.current_queue:
		npc._leave_queue()
	npc.queue_done()


func finish_checkout_and_exit() -> void:
	npc._dialog_timer = npc.DIALOG_DURATION
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


func _print_perf_shelf_if_slow(stage: String, start_usec: int, route_info: Dictionary) -> void:
	var elapsed_msec := float(Time.get_ticks_usec() - start_usec) / 1000.0

	if elapsed_msec < PERF_SHELF_THRESHOLD_MSEC:
		return

	print(
		"[DEBUG][PERF_SHELF] stage=%s npc=%s item=%s shelf=%s npc_pos=%s target_pos=%s route_points=%d route_distance=%.2f travel_seconds=%.2f elapsed_ms=%.2f" % [
			stage,
			_get_perf_npc_label(),
			npc.item_to_buy,
			npc._target_shelf.name if npc._target_shelf != null else "<null>",
			str(npc.global_position),
			str(npc.target_position),
			int(route_info.get("route_points", 0)),
			float(route_info.get("route_distance", 0.0)),
			float(route_info.get("travel_seconds", 0.0)),
			elapsed_msec
		]
	)


func print_shelf_flow_debug(stage: String, shelf: Shelf, visit_position: Vector2, route_info: Dictionary) -> void:
	if not DEBUG_SHELF_FLOW:
		return

	var expected_direction := ""

	if shelf != null and is_instance_valid(shelf):
		expected_direction = "UP" if npc.global_position.y >= shelf.global_position.y else "DOWN"

	print(
		"[DEBUG][SHELF_TAKE_POSITION] stage=%s npc=%s item=%s state=%s shelf=%s shelf_pos=%s visit_pos=%s npc_pos=%s target_pos=%s distance_to_target=%s distance_to_shelf=%s shelf_action_distance=%.2f shelf_visit_arrival_distance=%.2f expected_facing=%s actual_facing=%s route_points=%d route_distance=%.2f travel_seconds=%.2f access_point=%s access_side=%s graph_node=%s checkout_source=%s" % [
			stage,
			_get_perf_npc_label(),
			npc.item_to_buy,
			str(npc.current_state),
			shelf.name if shelf != null else "<null>",
			str(shelf.global_position if shelf != null and is_instance_valid(shelf) else Vector2.INF),
			str(visit_position),
			str(npc.global_position),
			str(npc.target_position),
			str(npc.global_position.distance_to(visit_position) if visit_position.is_finite() else INF),
			str(npc.global_position.distance_to(shelf.global_position) if shelf != null and is_instance_valid(shelf) else INF),
			npc.SHELF_ACTION_DISTANCE,
			npc.SHELF_VISIT_ARRIVAL_DISTANCE,
			expected_direction,
			str(npc._move_direction),
			int(route_info.get("route_points", 0)),
			float(route_info.get("route_distance", 0.0)),
			float(route_info.get("travel_seconds", 0.0)),
			str(shelf.get_meta(&"npc_access_point") if shelf != null and shelf.has_meta(&"npc_access_point") else Vector2.INF),
			str(shelf.get_meta(&"npc_access_side") if shelf != null and shelf.has_meta(&"npc_access_side") else ""),
			str(shelf.get_meta(&"npc_access_graph_node") if shelf != null and shelf.has_meta(&"npc_access_graph_node") else ""),
			str(shelf.get_meta(&"npc_access_checkout_source") if shelf != null and shelf.has_meta(&"npc_access_checkout_source") else "")
		]
	)


func _get_perf_npc_label() -> String:
	if npc != null and npc.npc_data != null and npc.npc_data.npc_id != "":
		return npc.npc_data.npc_id

	return npc.name if npc != null else "<none>"
