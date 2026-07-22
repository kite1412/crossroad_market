class_name NPCQueueFlow
extends RefCounted

const DEBUG_QUEUE_TO_CASHIER: bool = true

var npc = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(npc_node) -> void:
	npc = npc_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_wait_in_queue(delta: float) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var queue_index := NPC.current_queue.find(npc)

	if queue_index < 0:
		enter_checkout_queue()
		return

	if queue_index != npc._last_queue_index:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var previous_index: int = npc._last_queue_index

		npc._last_queue_index = queue_index
		npc._movement_route.clear()
		npc._movement_route_destination = Vector2.INF
		npc._is_moving_from_queue_to_cashier = false
		npc._queue_back_facing_done = false
		npc._queue_back_facing_logged = false

		if previous_index > queue_index and previous_index >= 0:
			npc._queue_advance_delay_timer = npc.QUEUE_ADVANCE_DELAY
			npc._queue_advance_clear_wait_timer = npc.QUEUE_ADVANCE_CLEAR_WAIT
			npc._queue_advance_waiting_for_clear = true

	if npc._is_moving_from_queue_to_cashier:
		process_queue_to_cashier(queue_index)
		return

	npc.target_position = get_queue_target()

	if npc._queue_advance_delay_timer > 0.0:
		npc._queue_advance_delay_timer = maxf(0.0, npc._queue_advance_delay_timer - delta)
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		face_queue_forward(queue_index, "advance_delay")

		return

	if npc._queue_advance_waiting_for_clear:
		if is_queue_advance_path_clear(queue_index):
			npc._queue_advance_waiting_for_clear = false
		else:
			npc._queue_advance_clear_wait_timer = maxf(0.0, npc._queue_advance_clear_wait_timer - delta)

		if npc._queue_advance_waiting_for_clear and npc._queue_advance_clear_wait_timer > 0.0:
			npc.velocity = Vector2.ZERO
			npc.move_and_slide()
			face_queue_forward(queue_index, "waiting_path_clear")
			return

		if npc._queue_advance_waiting_for_clear:
			npc._queue_advance_waiting_for_clear = false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var arrived: bool = npc.global_position.distance_to(npc.target_position) <= npc.QUEUE_SLOT_ARRIVAL_DISTANCE

	if not arrived:
		arrived = npc._move_to_with_arrival_threshold(npc.target_position, npc.QUEUE_SLOT_ARRIVAL_DISTANCE)

	if arrived and queue_index == 0:
		pass
		start_queue_to_cashier(queue_index)
		return
	elif arrived:
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		if not npc._queue_back_facing_done:
			npc._queue_back_facing_done = true
		if not npc._queue_back_facing_logged:
			face_queue_forward(queue_index, "arrived_back")
			npc._queue_back_facing_logged = true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func join_queue() -> void:
	NPCQueueSystem.join_queue(NPC.current_queue, npc)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func leave_queue() -> void:
	NPCQueueSystem.leave_queue(NPC.current_queue, npc)
	npc._last_queue_index = -1
	npc._is_moving_from_queue_to_cashier = false
	npc._queue_entry_shelf = null
	npc._queue_egress_route_pending = false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func enter_checkout_queue() -> void:
	join_queue()
	npc._last_queue_index = NPC.current_queue.find(npc)
	npc._is_moving_from_queue_to_cashier = false
	npc.target_position = get_queue_target()
	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	npc._set_state(NPC.State.WAIT_IN_QUEUE)
	npc._target_shelf = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_ready_for_checkout_service() -> bool:
	if npc.is_queued_for_deletion():
		return false

	if NPC.current_queue.is_empty() or NPC.current_queue[0] != npc:
		return false

	if npc.current_state == NPC.State.CHECKOUT:
		return true

	if npc.current_state != NPC.State.WAIT_IN_QUEUE:
		return false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var cashier_target := get_cashier_target()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var ready: bool = npc.global_position.distance_to(cashier_target) <= npc.QUEUE_ACTION_DISTANCE
	pass
	return ready


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func mark_checkout_ready() -> void:
	if not is_ready_for_checkout_service():
		return

	npc.velocity = Vector2.ZERO
	npc._is_moving_from_queue_to_cashier = false
	npc.target_position = get_cashier_target()
	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	npc._set_state(NPC.State.CHECKOUT)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func start_queue_to_cashier(queue_index: int) -> void:
	npc.velocity = Vector2.ZERO
	npc.move_and_slide()
	face_queue_forward(queue_index, "arrived_front")
	npc._is_moving_from_queue_to_cashier = true
	npc.target_position = get_cashier_target()
	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	pass


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_queue_to_cashier(queue_index: int) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var cashier_target := get_cashier_target()
	npc.target_position = cashier_target

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var arrived: bool = npc.global_position.distance_to(cashier_target) <= npc.QUEUE_SLOT_ARRIVAL_DISTANCE

	if not arrived:
		arrived = npc._move_to_with_arrival_threshold(cashier_target, npc.QUEUE_SLOT_ARRIVAL_DISTANCE)

	if arrived:
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		face_queue_forward(queue_index, "arrived_cashier")
		npc._is_moving_from_queue_to_cashier = false
		pass
		npc._set_state(NPC.State.CHECKOUT)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_cashier_target() -> Vector2:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var store: Node = npc._get_store_route_provider()

	if store != null and store.has_method("get_npc_cashier_target"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var result: Variant = store.call("get_npc_cashier_target", NPC.counter_position)

		if result is Vector2:
			return result as Vector2

	return NPC.counter_position


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_cashier_face_target() -> Vector2:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	@warning_ignore("unused_variable")
	var standing_target := get_cashier_target()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var store: Node = npc._get_store_route_provider()

	if store != null and store.has_method("get_npc_cashier_face_target"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var result: Variant = store.call("get_npc_cashier_face_target", standing_target + Vector2(0.0, -24.0))

		if result is Vector2:
			return result as Vector2

	return standing_target + Vector2(0.0, -24.0)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_queue_target() -> Vector2:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var position_in_queue := NPC.current_queue.find(npc)

	if position_in_queue < 0:
		return NPC.counter_position

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var store: Node = npc._get_store_route_provider()

	if store != null and store.has_method("get_npc_queue_target"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var result: Variant = store.call("get_npc_queue_target", position_in_queue, NPC.counter_position)

		if result is Vector2:
			return result as Vector2

	return NPCQueueSystem.get_queue_target(NPC.current_queue, npc, NPC.counter_position)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
@warning_ignore("unused_parameter")
func face_queue_forward(queue_index: int, reason: String) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	@warning_ignore("unused_variable")
	var standing_target := get_queue_target()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var face_target := get_cashier_face_target()

	if not face_target.is_finite() or face_target == Vector2.ZERO:
		face_target = npc.target_position + Vector2(0.0, -24.0)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var direction: Vector2 = face_target - npc.global_position
	pass

	if direction.length() <= 0.1:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	@warning_ignore("unused_variable")
	var previous_direction: CharacterSprite.Direction = npc._move_direction
	npc._move_direction = npc._get_direction(direction)
	npc._update_character_sprite()
	pass


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_queue_advance_path_clear(queue_index: int) -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var store: Node = npc._get_store_route_provider()

	if store == null or not store.has_method("get_npc_route_to_queue_target_from"):
		return true

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route_variant: Variant = store.call("get_npc_route_to_queue_target_from", npc.global_position, queue_index)

	if not (route_variant is Array):
		return false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route := route_variant as Array
	return not route.is_empty()
