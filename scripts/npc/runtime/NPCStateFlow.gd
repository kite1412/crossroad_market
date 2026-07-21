class_name NPCStateFlow
extends RefCounted

const NPCShoppingJobScript = preload("res://scripts/npc/runtime/NPCShoppingJob.gd")
const StoreRuntimeDebugProbeScript = preload("res://scripts/debug/StoreRuntimeDebugProbe.gd")
const PERF_SHELF_THRESHOLD_MSEC: float = 16.0
const OUT_OF_STOCK_WARNING_SECONDS: float = 10.0
const OUT_OF_STOCK_EXIT_SECONDS: float = 15.0
const SHELF_APPROACH_PROBE_COOLDOWN_MSEC: int = 650
const SHELF_APPROACH_ARRIVAL_DISTANCE: float = 6.0

var npc = null
var _next_shelf_approach_probe_msec: int = 0


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(npc_node) -> void:
	npc = npc_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_enter() -> void:
	npc._shopping_job.wanted_item = npc.item_to_buy
	npc._shopping_job.set_state(NPCShoppingJobScript.STATE_CHOOSING_ITEM)
	npc._enter_pause_timer += npc.get_process_delta_time()

	if npc._enter_pause_timer < npc.ENTER_PAUSE:
		return

	npc._choose_available_item_to_buy()
	npc._shopping_job.wanted_item = npc.item_to_buy
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
	npc._shopping_job.set_target_shelf(target_shelf)
	npc.target_position = visit_position
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route_info = get_route_travel_info(visit_position)
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
	var distance = 0.0
	if destination.is_finite():
		distance = npc.global_position.distance_to(destination)

	if npc.SPEED <= 0.0:
		return {
			"travel_seconds": 0.0,
			"route_points": 0,
			"route_distance": distance
		}

	return {
		"travel_seconds": distance / npc.SPEED,
		"route_points": 0,
		"route_distance": distance
	}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_walk_to_shelf() -> void:
	npc._shopping_job.set_state(NPCShoppingJobScript.STATE_MOVING_TO_SHELF)
	if not npc._is_target_shelf_valid():
		_record_shelf_probe(&"npc_shelf_target_invalid", {
			"reason": "walk_shelf_lost"
		})
		if _handle_shelf_wait_or_leave("walk_shelf_lost"):
			return

	var shelf_arrival_distance: float = _get_shelf_approach_arrival_distance()
	if (
		npc.global_position.distance_to(npc.target_position)
		<= shelf_arrival_distance
	):
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		npc._face_target_shelf()
		set_state(NPC.State.SEARCH_ITEM)
		return

	var arrived: bool = npc._move_to_with_arrival_threshold(
		npc.target_position,
		shelf_arrival_distance
	)
	_record_shelf_approach_probe(arrived)
	if arrived:
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
	var stocked_shelf = _find_reachable_stocked_shelf()

	if stocked_shelf != null:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var visit_position: Vector2 = npc._get_shelf_visit_position(stocked_shelf)

		if stocked_shelf != npc._target_shelf:
			npc._target_shelf = stocked_shelf
			npc._shopping_job.set_target_shelf(stocked_shelf)
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
	npc._shopping_job.set_state(NPCShoppingJobScript.STATE_PICKING_UP_ITEM)
	if not npc._is_target_shelf_valid() and not npc._has_taken_shelf_item:
		_record_shelf_probe(&"npc_shelf_target_invalid", {
			"reason": "take_shelf_lost"
		})
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
			npc._queue_egress_target_position = Vector2.INF

		npc._take_item_pause_timer = 0.0
		npc._enter_checkout_queue()
		return

	var shelf_action_distance: float = _get_shelf_approach_arrival_distance()
	if (
		npc.global_position.distance_to(npc.target_position)
		> shelf_action_distance
		and not npc._move_to_with_arrival_threshold(
			npc.target_position,
			shelf_action_distance
		)
	):
		_record_shelf_probe(&"npc_shelf_take_waiting_for_range", {
			"action_distance": shelf_action_distance
		})
		return

	npc._face_target_shelf()

	if npc._take_requested_items_from_shelves():
		_record_shelf_probe(&"npc_shelf_take_success", {})
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
func _record_shelf_approach_probe(arrived: bool) -> void:
	var now_msec := Time.get_ticks_msec()
	if now_msec < _next_shelf_approach_probe_msec:
		return

	_next_shelf_approach_probe_msec = now_msec + SHELF_APPROACH_PROBE_COOLDOWN_MSEC
	_record_shelf_probe(&"npc_shelf_approach", {
		"arrived": arrived
	})


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _record_shelf_probe(
	label: StringName,
	extra_context: Dictionary
) -> void:
	if npc == null:
		return

	var context: Dictionary = {
		"npc_id": npc.get_instance_id(),
		"state": int(npc.current_state),
		"position": _format_vector(npc.global_position),
		"target": _format_vector(npc.target_position),
		"target_distance": snappedf(
			npc.global_position.distance_to(npc.target_position),
			0.01
		),
		"route_points": npc._movement_route.size(),
		"item": npc.item_to_buy
	}

	if (
		npc._movement_route != null
		and not npc._movement_route.is_empty()
	):
		context["next_route_point"] = _format_vector(npc._movement_route[0])

	if npc._target_shelf != null and is_instance_valid(npc._target_shelf):
		context["shelf_id"] = String(npc._target_shelf.get_shelf_id())
		context["shelf_revision"] = npc._target_shelf.get_revision()
		context["shelf_position"] = _format_vector(
			npc._target_shelf.global_position
		)
		context["shelf_distance"] = snappedf(
			npc.global_position.distance_to(npc._target_shelf.global_position),
			0.01
		)
		context["npc_path_ready"] = bool(
			npc._target_shelf.get_meta("npc_path_ready", false)
		)
		var access_variant: Variant = npc._target_shelf.get_meta(
			&"npc_access_point",
			Vector2.INF
		)
		if access_variant is Vector2:
			context["npc_access_point"] = _format_vector(access_variant as Vector2)
		context["npc_access_source"] = str(
			npc._target_shelf.get_meta(&"npc_access_source", "")
		)
		context["npc_access_port_id"] = str(
			npc._target_shelf.get_meta(&"npc_access_port_id", "")
		)
		context["npc_access_checkout_source"] = str(
			npc._target_shelf.get_meta(&"npc_access_checkout_source", "")
		)

	for key in extra_context:
		context[key] = extra_context[key]

	StoreRuntimeDebugProbeScript.record(label, 0.0, context, 0.0)


func _format_vector(value: Vector2) -> String:
	return "%.1f,%.1f" % [value.x, value.y]


func _get_shelf_approach_arrival_distance() -> float:
	return maxf(
		SHELF_APPROACH_ARRIVAL_DISTANCE,
		maxf(
			npc.SHELF_VISIT_ARRIVAL_DISTANCE,
			npc.SHELF_ACTION_DISTANCE
		)
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_checkout(delta: float) -> void:
	npc._shopping_job.set_state(NPCShoppingJobScript.STATE_CHECKING_OUT)
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
	var store_provider = _get_store_provider()

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
			npc._shopping_job.set_target_shelf(replacement_shelf)
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
		var has_requested_stock = false
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
	npc._shopping_job.clear_target_shelf()
	npc._exit_after_checkout = true
	npc.target_position = npc._get_exit_position()
	set_state(NPC.State.EXIT)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _handle_shelf_wait_or_leave(wait_stage: String) -> bool:
	_begin_wait_for_shelf(wait_stage)
	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_state(new_state: int) -> void:
	_update_shopping_job_state(new_state)
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
		npc._shopping_job.clear_target_shelf()

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


func _update_shopping_job_state(new_state: int) -> void:
	if npc == null or npc._shopping_job == null:
		return

	match new_state:
		NPC.State.ENTER:
			npc._shopping_job.set_state(NPCShoppingJobScript.STATE_CHOOSING_ITEM)
		NPC.State.WALK_TO_SHELF:
			npc._shopping_job.set_state(NPCShoppingJobScript.STATE_MOVING_TO_SHELF)
		NPC.State.SEARCH_ITEM:
			npc._shopping_job.set_state(NPCShoppingJobScript.STATE_RESOLVING_SHELF)
		NPC.State.TAKE_ITEM:
			npc._shopping_job.set_state(NPCShoppingJobScript.STATE_PICKING_UP_ITEM)
		NPC.State.WAIT_IN_QUEUE:
			npc._shopping_job.set_state(NPCShoppingJobScript.STATE_WAITING_IN_QUEUE)
		NPC.State.CHECKOUT:
			npc._shopping_job.set_state(NPCShoppingJobScript.STATE_CHECKING_OUT)
		NPC.State.EXIT:
			npc._shopping_job.set_state(NPCShoppingJobScript.STATE_LEAVING_STORE)
		NPC.State.WAIT_FOR_SHELF:
			npc._shopping_job.set_state(NPCShoppingJobScript.STATE_RECOVERING)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_perf_npc_label() -> String:
	if (
		npc != null
		and npc.npc_data != null
		and npc.npc_data.npc_id != ""
	):
		return npc.npc_data.npc_id

	return npc.name if npc != null else "<none>"
