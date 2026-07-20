extends "res://scripts/npc/runtime/NPCQueueFlow.gd"

const SOLO_CHECKOUT_EXIT_META: StringName = &"solo_checkout_exit"


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func start_queue_to_cashier(queue_index: int) -> void:
	_capture_checkout_lane()
	super.start_queue_to_cashier(queue_index)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func mark_checkout_ready() -> void:
	if not npc.has_meta(SOLO_CHECKOUT_EXIT_META):
		_capture_checkout_lane()

	super.mark_checkout_ready()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _capture_checkout_lane() -> void:
	NPCQueueSystem.prune_invalid(NPC.current_queue)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var has_waiting_customer := false

	for queued_variant in NPC.current_queue:
		if not (queued_variant is NPC):
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var queued_npc := queued_variant as NPC
		if queued_npc == npc:
			continue
		if not is_instance_valid(queued_npc):
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
