class_name NPCStateFlow
extends RefCounted

const PERF_SHELF_THRESHOLD_MSEC: float = 16.0
const DEBUG_SHELF_FLOW: bool = true
const OUT_OF_STOCK_WARNING_SECONDS: float = 10.0
const OUT_OF_STOCK_EXIT_SECONDS: float = 15.0

var npc = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(npc_node) -> void:
	npc = npc_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_enter() -> void:
	npc._enter_pause_timer += npc.get_process_delta_time()

	if npc._enter_pause_timer < npc.ENTER_PAUSE:
		return

	npc._choose_available_item_to_buy()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var target_shelf: Shelf = npc._find_reachable_matching_shelf()

	if target_shelf == null:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var fallback_shelf: Shelf = npc._find_matching_shelf()
		if fallback_shelf != null:
			_begin_wait_for_shelf("enter_no_shelf_fallback")
		else:
			_begin_wait_for_shelf("enter_no_shelf")
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var visit_position: Vector2 = npc._get_shelf_visit_position(target_shelf)

	if not visit_position.is_finite():
		npc._show_dialog("I can't reach that shelf.")
		npc._dialog_timer = npc.DIALOG_DURATION
		npc._exit_after_checkout = false
		npc.target_position = npc._get_exit_position()
		set_state(NPC.State.EXIT)
		return

	npc._target_shelf = target_shelf
	npc.target_position = visit_position
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route_info := get_route_travel_info(visit_position)
	npc.shelf_route_ready.emit(
		npc,
		float(route_info.get("travel_seconds", 0.0))
	)
	set_state(NPC.State.WALK_TO_SHELF)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_route_travel_seconds(destination: Vector2) -> float:
	return float(
		get_route_travel_info(destination).get(
			"travel_seconds",
			0.0
		)
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_route_travel_info(destination: Vector2) -> Dictionary:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route: Array[Vector2] = npc._build_movement_route(destination)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var distance := 0.0
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var previous: Vector2 = npc.global_position

	for point in route:
		distance += previous.distance_to(point)
		previous = point

	if (
		route.is_empty()
		or previous.distance_to(destination) > npc.ARRIVAL_THRESHOLD
	):
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


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_walk_to_shelf() -> void:
	if not npc._is_target_shelf_valid():
		if _handle_shelf_wait_or_leave("walk_shelf_lost"):
			return

	if (
		npc.global_position.distance_to(npc.target_position)
		<= npc.SHELF_VISIT_ARRIVAL_DISTANCE
	):
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		npc._face_target_shelf()
		set_state(NPC.State.SEARCH_ITEM)
		return

	if npc._move_to(npc.target_position):
		npc._face_target_shelf()
		set_state(NPC.State.SEARCH_ITEM)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_search_item(delta: float) -> void:
	if not npc._is_target_shelf_valid():
		_handle_shelf_wait_or_leave("search_shelf_lost")
		return

	npc.velocity = Vector2.ZERO
	npc.move_and_slide()
	npc._search_timer += delta

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var stocked_shelf := _find_reachable_stocked_shelf()

	if stocked_shelf != null:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var visit_position: Vector2 = npc._get_shelf_visit_position(stocked_shelf)

		if stocked_shelf != npc._target_shelf:
			npc._target_shelf = stocked_shelf
			npc.target_position = visit_position
			set_state(NPC.State.WALK_TO_SHELF)
			return

		if npc._search_timer >= npc.SHELF_SEARCH_MIN_TIME:
			set_state(NPC.State.TAKE_ITEM)
		return

	if (
		npc._search_timer >= OUT_OF_STOCK_WARNING_SECONDS
		and not npc._search_announced
	):
		npc._search_announced = true
		npc._show_dialog(
			"This is taking a while... Are you going to restock it?"
		)

	if npc._search_timer < OUT_OF_STOCK_EXIT_SECONDS:
		return

	npc._show_dialog(
		"I'm disappointed. I'll shop somewhere else."
	)
	npc._dialog_timer = npc.DIALOG_DURATION
	npc._exit_after_checkout = false
	npc.target_position = npc._get_exit_position()
	set_state(NPC.State.EXIT)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_browse_item(delta: float) -> void:
	npc._search_timer += delta

	if npc._search_timer < 8.0:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var alt_item: String = npc._find_alternative_item()

	if alt_item != "":
		npc._browse_item = alt_item
		npc.item_to_buy = alt_item
		npc._show_dialog("This one will do!")
		set_state(NPC.State.TAKE_ITEM)
	else:
		npc._show_dialog("Nothing here for me...")
		npc._exit_after_checkout = false
		npc.target_position = npc._get_exit_position()
		set_state(NPC.State.EXIT)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_take_item() -> void:
	if not npc._is_target_shelf_valid() and not npc._has_taken_shelf_item:
		if _handle_shelf_wait_or_leave("take_shelf_lost"):
			return

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

	if (
		npc.global_position.distance_to(npc.target_position)
		> npc.SHELF_ACTION_DISTANCE
		and not npc._move_to(npc.target_position)
	):
		return

	npc._face_target_shelf()

	if npc._take_requested_items_from_shelves():
		npc._has_taken_shelf_item = true
		npc._take_item_pause_timer = 0.0
		npc._show_dialog("I'll take this.")
		return

	# Another NPC may have taken the final item between SEARCH_ITEM and
	# TAKE_ITEM. Return to the same hidden 15-second waiting behavior instead
	# of leaving immediately.
	npc._show_dialog("Someone must have taken it already.")
	set_state(NPC.State.SEARCH_ITEM)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_checkout(delta: float) -> void:
	if npc._checkout_timer == 0.0:
		npc._show_dialog(
			"I'd like to buy %s." % npc.get_checkout_item_label()
		)

	npc._checkout_timer += delta

	if (
		npc.npc_data.patience_type == NPCData.PatienceType.IMPATIENT
		and npc._checkout_timer >= npc.CHECKOUT_PATIENCE
	):
		@warning_ignore("static_called_on_instance")
		npc._show_dialog(
			BlueprintManager.get_checkout_wait_dialog(npc)
		)
		npc._leave_queue()
		npc._return_item_to_shelf()
		npc._exit_after_checkout = false
		npc.target_position = npc._get_exit_position()
		set_state(NPC.State.EXIT)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_exit() -> void:
	if (
		npc.global_position.distance_to(npc.target_position)
		<= npc.ARRIVAL_THRESHOLD
	):
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


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
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


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _begin_wait_for_shelf(_reason: String) -> void:
	npc._waiting_for_shelf_return = true
	npc._shelf_wait_timer = 0.0
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var store_provider := _get_store_provider()

	if (
		store_provider == null
		or not store_provider.has_method("get_npc_shelf_wait_position")
	):
		npc._exit_after_checkout = false
		npc.target_position = npc._get_exit_position()
		set_state(NPC.State.EXIT)
		return

	npc.target_position = store_provider.get_npc_shelf_wait_position(
		npc.get_instance_id() % 2
	)
	set_state(NPC.State.WAIT_FOR_SHELF)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_wait_for_shelf(delta: float) -> void:
	if (
		npc.global_position.distance_to(npc.target_position)
		> npc.ARRIVAL_THRESHOLD
	):
		npc._move_to(npc.target_position)
	else:
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()

	npc._shelf_wait_timer += delta

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var replacement_shelf: Shelf = npc._find_reachable_matching_shelf()
	if replacement_shelf != null:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var visit_position: Vector2 = npc._get_shelf_visit_position(
			replacement_shelf
		)
		if visit_position.is_finite():
			npc._target_shelf = replacement_shelf
			npc.target_position = visit_position
			npc._waiting_for_shelf_return = false
			npc._shelf_wait_timer = 0.0
			set_state(NPC.State.WALK_TO_SHELF)
			return

	if npc._shelf_wait_timer >= npc.SHELF_WAIT_GRACE_PERIOD:
		npc._waiting_for_shelf_return = false
		npc._shelf_wait_timer = 0.0
		npc._show_dialog("Where'd the shelf go?")
		npc._dialog_timer = npc.DIALOG_DURATION
		npc._exit_after_checkout = false
		npc.target_position = npc._get_exit_position()
		set_state(NPC.State.EXIT)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _find_reachable_stocked_shelf() -> Shelf:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var requested_items: Array[String] = npc._get_requested_items()

	for shelf in npc._get_matching_shelf_candidates():
		if shelf == null or not is_instance_valid(shelf):
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var has_requested_stock := false
		for item_id in requested_items:
			if shelf.has_item(item_id):
				has_requested_stock = true
				break

		if not has_requested_stock:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var visit_position: Vector2 = npc._get_shelf_visit_position(shelf)
		if visit_position.is_finite():
			return shelf

	return null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_store_provider() -> Node:
	return npc._get_store_route_provider()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func finish_checkout_and_exit() -> void:
	npc._dialog_timer = npc.DIALOG_DURATION
	npc._target_shelf = null
	npc._exit_after_checkout = true
	npc.target_position = npc._get_exit_position()
	set_state(NPC.State.EXIT)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _handle_shelf_wait_or_leave(debug_stage: String) -> bool:
	_begin_wait_for_shelf(debug_stage)
	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
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
		npc._target_shelf = null

	if new_state in [
		NPC.State.WALK_TO_SHELF,
		NPC.State.SEARCH_ITEM,
		NPC.State.TAKE_ITEM
	]:
		npc._waiting_for_shelf_return = false
		npc._shelf_wait_timer = 0.0

	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	npc._reset_stuck_watchdog()
	npc.current_state = new_state


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_perf_npc_label() -> String:
	if (
		npc != null
		and npc.npc_data != null
		and npc.npc_data.npc_id != ""
	):
		return npc.npc_data.npc_id

	return npc.name if npc != null else "<none>"
