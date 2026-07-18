class_name NPCQueueFlow
extends RefCounted

var npc = null


func setup(npc_node) -> void:
	npc = npc_node


func process_wait_in_queue(_delta: float) -> void:
	var queue_index := NPC.current_queue.find(npc)

	if queue_index < 0:
		enter_checkout_queue()
		return

	if queue_index != npc._last_queue_index:
		npc._last_queue_index = queue_index
		npc._movement_route.clear()
		npc._movement_route_destination = Vector2.INF

	npc.target_position = get_queue_target()

	if npc.DEBUG_QUEUE_TARGET:
		print_queue_target_debug(queue_index)

	var arrived: bool = npc.global_position.distance_to(npc.target_position) <= npc.QUEUE_ACTION_DISTANCE

	if not arrived:
		arrived = npc._move_to(npc.target_position)

	if arrived and queue_index == 0:
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		npc._set_state(NPC.State.CHECKOUT)


func join_queue() -> void:
	NPCQueueSystem.join_queue(NPC.current_queue, npc)


func leave_queue() -> void:
	NPCQueueSystem.leave_queue(NPC.current_queue, npc)
	npc._last_queue_index = -1


func enter_checkout_queue() -> void:
	join_queue()
	npc._target_shelf = null
	npc._last_queue_index = NPC.current_queue.find(npc)
	npc.target_position = get_queue_target()
	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	npc._set_state(NPC.State.WAIT_IN_QUEUE)

	if npc.DEBUG_QUEUE_TARGET:
		print_queue_target_debug(npc._last_queue_index)


func is_ready_for_checkout_service() -> bool:
	if npc.is_queued_for_deletion():
		return false

	if NPC.current_queue.is_empty() or NPC.current_queue[0] != npc:
		return false

	if npc.current_state == NPC.State.CHECKOUT:
		return true

	if npc.current_state != NPC.State.WAIT_IN_QUEUE:
		return false

	var queue_target := get_queue_target()
	return npc.global_position.distance_to(queue_target) <= npc.QUEUE_ACTION_DISTANCE


func mark_checkout_ready() -> void:
	if not is_ready_for_checkout_service():
		return

	npc.velocity = Vector2.ZERO
	npc.target_position = get_queue_target()
	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	npc._set_state(NPC.State.CHECKOUT)


func get_queue_target() -> Vector2:
	var position_in_queue := NPC.current_queue.find(npc)

	if position_in_queue < 0:
		return NPC.counter_position

	var store: Node = npc._get_store_route_provider()

	if store != null and store.has_method("get_npc_queue_target"):
		var result: Variant = store.call("get_npc_queue_target", position_in_queue, NPC.counter_position)

		if result is Vector2:
			return result as Vector2

	return NPCQueueSystem.get_queue_target(NPC.current_queue, npc, NPC.counter_position)


func print_queue_target_debug(queue_index: int) -> void:
	var npc_id := ""
	var visit_phase := ""

	if npc.npc_data != null:
		npc_id = npc.npc_data.npc_id
		visit_phase = str(npc.npc_data.visit_phase)

	print(
		"NPC queue target [%s/%s]: index=%d pos=%s target=%s distance=%.2f" % [
			npc.name if npc_id == "" else npc_id,
			visit_phase,
			queue_index,
			str(npc.global_position),
			str(npc.target_position),
			npc.global_position.distance_to(npc.target_position)
		]
	)
