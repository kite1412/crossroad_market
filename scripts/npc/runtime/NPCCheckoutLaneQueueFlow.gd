extends "res://scripts/npc/runtime/NPCQueueFlow.gd"

const SOLO_CHECKOUT_EXIT_META: StringName = &"solo_checkout_exit"


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_wait_in_queue(delta: float) -> void:
	var queue_index := NPC.current_queue.find(npc)
	if queue_index < 0:
		enter_checkout_queue()
		return

	if queue_index != npc._last_queue_index:
		var previous_index: int = npc._last_queue_index
		npc._last_queue_index = queue_index
		npc._movement_route.clear()
		npc._movement_route_destination = Vector2.INF
		npc._is_moving_from_queue_to_cashier = false
		npc._queue_back_facing_done = false
		npc._queue_back_facing_logged = false

		if previous_index > queue_index and previous_index >= 0:
			npc._queue_advance_delay_timer = npc.QUEUE_ADVANCE_DELAY
			npc._queue_advance_clear_wait_timer = (
				npc.QUEUE_ADVANCE_CLEAR_WAIT
			)
			npc._queue_advance_waiting_for_clear = true

	if npc._is_moving_from_queue_to_cashier:
		process_queue_to_cashier(queue_index)
		return

	npc.target_position = get_queue_target()
	if npc._queue_advance_delay_timer > 0.0:
		npc._queue_advance_delay_timer = maxf(
			0.0,
			npc._queue_advance_delay_timer - delta
		)
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		face_queue_forward(queue_index, "advance_delay")
		return

	if npc._queue_advance_waiting_for_clear:
		if is_queue_advance_path_clear(queue_index):
			npc._queue_advance_waiting_for_clear = false
		else:
			npc._queue_advance_clear_wait_timer = maxf(
				0.0,
				npc._queue_advance_clear_wait_timer - delta
			)

		if (
			npc._queue_advance_waiting_for_clear
			and npc._queue_advance_clear_wait_timer > 0.0
		):
			npc.velocity = Vector2.ZERO
			npc.move_and_slide()
			face_queue_forward(queue_index, "waiting_path_clear")
			return
		npc._queue_advance_waiting_for_clear = false

	var arrived: bool = (
		npc.global_position.distance_to(npc.target_position)
		<= npc.QUEUE_SLOT_ARRIVAL_DISTANCE
	)
	if not arrived:
		arrived = npc._move_to_with_arrival_threshold(
			npc.target_position,
			npc.QUEUE_SLOT_ARRIVAL_DISTANCE
		)

	# Every customer must physically reach the assigned slot first. The old
	# single-customer shortcut switched to cashier movement while still beside
	# the shelf, bypassing shelf-aware egress and producing an unreachable target.
	if arrived and queue_index == 0:
		start_queue_to_cashier(queue_index)
		return

	if arrived:
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		if not npc._queue_back_facing_done:
			npc._queue_back_facing_done = true
		if not npc._queue_back_facing_logged:
			face_queue_forward(queue_index, "arrived_back")
			npc._queue_back_facing_logged = true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func start_queue_to_cashier(queue_index: int) -> void:
	_capture_checkout_lane()
	super.start_queue_to_cashier(queue_index)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func mark_checkout_ready() -> void:
	if not npc.has_meta(SOLO_CHECKOUT_EXIT_META):
		_capture_checkout_lane()

	super.mark_checkout_ready()
	if npc.current_state == NPC.State.CHECKOUT:
		face_queue_forward(0, "checkout_ready")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_cashier_face_target() -> Vector2:
	var fallback := super.get_cashier_face_target()
	var store: Node = npc._get_store_route_provider()
	if store == null:
		return fallback

	var route_provider_variant: Variant = store.get("npc_routes")
	if not is_instance_valid(route_provider_variant):
		return fallback
	if not (route_provider_variant is Node):
		return fallback

	var route_provider := route_provider_variant as Node
	if not route_provider.has_method("get_npc_cashier_face_target"):
		return fallback

	var result: Variant = route_provider.call(
		"get_npc_cashier_face_target",
		fallback
	)
	if result is Vector2:
		return result as Vector2
	return fallback


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _capture_checkout_lane() -> void:
	NPCQueueSystem.prune_invalid(NPC.current_queue)
	var has_waiting_customer := false

	for queued_variant in NPC.current_queue:
		if not is_instance_valid(queued_variant):
			continue
		if not (queued_variant is NPC):
			continue

		var queued_npc := queued_variant as NPC
		if queued_npc == npc:
			continue
		if queued_npc.is_queued_for_deletion():
			continue
		if queued_npc.current_state != NPC.State.WAIT_IN_QUEUE:
			continue

		has_waiting_customer = true
		break

	npc.set_meta(
		SOLO_CHECKOUT_EXIT_META,
		not has_waiting_customer
	)
